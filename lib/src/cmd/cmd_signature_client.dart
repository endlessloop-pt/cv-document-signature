import 'dart:convert'
    show ascii, base64Decode, base64Encode, base64Url, jsonDecode, jsonEncode;
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'cmd_signature_config.dart';
import 'cmd_signature_exceptions.dart';
import 'web_authenticator.dart';

/// Talks to the Autentika Chave Móvel Digital signing service: an OAuth
/// authorization-code + PKCE exchange for an access token, then a JSON request
/// that returns an already-signed PDF.
///
/// **There is no client-side cryptography here beyond PKCE.** The service signs
/// the document and draws the visible signature itself; this client uploads the
/// original bytes and a position and downloads the result. Nothing computes a
/// hash, builds a PKCS#7 blob or touches the PDF.
///
/// This is intentionally *not* the same as either app's ordinary sign-in
/// client: the signing client is public (no `client_secret`), uses the `cmd`
/// scope, has authorize and token endpoints on different hosts, and returns a
/// token to the caller rather than establishing an app session.
class CmdSignatureClient {
  CmdSignatureClient({
    required this.config,
    required WebAuthenticator webAuthenticator,
    http.Client? httpClient,
    void Function(String message)? onError,
    String Function()? newId,
    Random? random,
  })  : _webAuth = webAuthenticator,
        _http = httpClient ?? http.Client(),
        _onError = onError,
        _newId = newId ?? const Uuid().v4,
        _random = random ?? Random.secure();

  final CmdSignatureConfig config;
  final WebAuthenticator _webAuth;
  final http.Client _http;
  final void Function(String message)? _onError;
  final String Function() _newId;
  final Random _random;

  /// The service reports this in the response body rather than in a status
  /// code, so a substring match is the only way to spot it.
  static const String _notActiveMarker =
      'Digital signature not active for the user';

  /// RFC 7636 §4.1 unreserved characters.
  static const String _verifierAlphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  /// Runs the authorization-code + PKCE flow and returns a CMD access token.
  ///
  /// Throws [CmdSignatureCancelledException] if the user dismissed the browser
  /// (the web-auth adapter's job to signal), or [CmdSignatureException] for
  /// anything else.
  Future<String> authenticate() async {
    final state = _newId();
    final codeVerifier = _randomVerifier(128);
    final codeChallenge = _s256Challenge(codeVerifier);

    final authorizeUrl = config.authorizeUrl.replace(
      queryParameters: <String, String>{
        'response_type': 'code',
        'client_id': config.clientId,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'redirect_uri': config.redirectUri,
        'state': state,
        'scope': config.scope,
      },
    );

    final callback = await _webAuth.authenticate(
      url: authorizeUrl.toString(),
      callbackUrlScheme: config.callbackUrlScheme,
    );

    final params = Uri.parse(callback).queryParameters;
    if (params['state'] != state) {
      // Do not log either value: echoing them back makes the log itself a way
      // to learn what we expected.
      _log("CMD OAuth: returned state doesn't match the state we sent");
      throw const CmdSignatureException('State mismatch');
    }
    final code = params['code'];
    if (code == null || code.isEmpty) {
      throw const CmdSignatureException('Missing authorization code');
    }

    final http.Response response;
    try {
      response = await _http.post(
        config.tokenUrl,
        body: <String, String>{
          // No client_secret: this is a public client and PKCE is what proves
          // the exchange belongs to the same app that started the flow.
          'client_id': config.clientId,
          'redirect_uri': config.redirectUri,
          'grant_type': 'authorization_code',
          'code': code,
          'code_verifier': codeVerifier,
        },
      );
    } catch (e) {
      _log('CMD OAuth token exchange failed: $e');
      throw const CmdSignatureException('Token exchange failed');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _log('CMD OAuth token exchange returned ${response.statusCode}');
      throw const CmdSignatureException('Token exchange failed');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const CmdSignatureException('Invalid token response');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const CmdSignatureException('Invalid token response');
    }
    final token = decoded['access_token'];
    if (token is! String || token.isEmpty) {
      throw const CmdSignatureException('Missing access token');
    }
    return token;
  }

  /// Sends the **original, unmodified** PDF to be signed and returns the signed
  /// bytes.
  ///
  /// [page] is 1-based and [x]/[y] are the signature rectangle's bottom-left
  /// corner in PDF points — use `cmdPositionFor` to derive all three rather
  /// than assembling them by hand. The rectangle's width and height are not
  /// sent; the service sizes the visible signature itself.
  ///
  /// [pin] is the user's CMD signing PIN. It is never logged, and no failure
  /// path here includes the request body in a message — check that before
  /// adding logging.
  Future<Uint8List> sign({
    required String accessToken,
    required String pin,
    required Uint8List documentBytes,
    required int page,
    required double x,
    required double y,
  }) async {
    final requestBody = jsonEncode(<String, dynamic>{
      'filename': '${_newId()}.pdf',
      'page': page,
      'pin': pin,
      'document': base64Encode(documentBytes),
      'visible': true,
      'coordinates': <String, double>{'x': x, 'y': y},
    });

    final http.Response response;
    try {
      response = await _http
          .post(
            config.signUrl,
            headers: <String, String>{
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: requestBody,
          )
          .timeout(config.signTimeout);
    } catch (e) {
      // Deliberately logs only the error, never the request — the body holds
      // the PIN and the whole document.
      _log('CMD sign request failed: $e');
      throw const CmdSignatureException('Sign request failed');
    }

    // Checked before the status code: the service has been seen to report this
    // with a 2xx as well as with an error status.
    if (response.body.contains(_notActiveMarker)) {
      throw const CmdSignatureNotActiveException();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _log('CMD sign request returned ${response.statusCode}');
      throw const CmdSignatureException('Sign request failed');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const CmdSignatureException('Invalid sign response');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const CmdSignatureException('Invalid sign response');
    }

    // A successful HTTP status is not a successful signature.
    if (decoded['failed'] == true) {
      throw const CmdSignatureException('Sign failed');
    }

    final signed = decoded['document'];
    if (signed is! String || signed.isEmpty) {
      throw const CmdSignatureException('Missing signed document');
    }
    try {
      return base64Decode(signed);
    } on FormatException {
      throw const CmdSignatureException('Signed document is not valid base64');
    }
  }

  /// Closes the underlying HTTP client. Only call this if the client owns it.
  void dispose() => _http.close();

  String _randomVerifier(int length) => String.fromCharCodes(
        Iterable<int>.generate(
          length,
          (_) => _verifierAlphabet
              .codeUnitAt(_random.nextInt(_verifierAlphabet.length)),
        ),
      );

  /// base64url of SHA-256(verifier), unpadded — RFC 7636 §4.2.
  String _s256Challenge(String codeVerifier) => base64Url
      .encode(sha256.convert(ascii.encode(codeVerifier)).bytes)
      .replaceAll('=', '');

  void _log(String message) => _onError?.call(message);
}
