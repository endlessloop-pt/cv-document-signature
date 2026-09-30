import 'package:cv_document_signature/cv_document_signature.dart';

/// A [WebAuthenticator] that returns a canned callback URL, and records what it
/// was asked to open.
class FakeWebAuthenticator implements WebAuthenticator {
  FakeWebAuthenticator({this.callbackBuilder, this.error});

  /// Builds the callback URL from the authorize URL the client passed, so a
  /// test can echo back the real `state`.
  final String Function(Uri authorizeUrl)? callbackBuilder;

  /// Thrown instead of returning, to simulate cancellation or failure.
  final Object? error;

  Uri? lastUrl;
  String? lastCallbackUrlScheme;
  int calls = 0;

  @override
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
  }) async {
    calls++;
    final parsed = Uri.parse(url);
    lastUrl = parsed;
    lastCallbackUrlScheme = callbackUrlScheme;
    if (error != null) throw error!;
    final build = callbackBuilder;
    if (build != null) return build(parsed);
    return 'app://oauth?code=the-code&state=${parsed.queryParameters['state']}';
  }
}

/// Echoes back the `state` the client sent, which is what a well-behaved
/// authorization server does.
String echoStateCallback(Uri authorizeUrl) =>
    'app://oauth?code=the-code&state=${authorizeUrl.queryParameters['state']}';

CmdSignatureConfig testConfig({
  String clientId = 'test-client',
  String redirectUri = 'app://oauth',
  Duration? signTimeout,
}) =>
    CmdSignatureConfig(
      authorizeUrl: Uri.parse('https://idp.example/oauth2/authorize'),
      tokenUrl: Uri.parse('https://idp.example/oauth2/token'),
      signUrl: Uri.parse('https://sign.example/api/v1/signature/sign'),
      clientId: clientId,
      redirectUri: redirectUri,
      signTimeout: signTimeout ?? const Duration(seconds: 120),
    );
