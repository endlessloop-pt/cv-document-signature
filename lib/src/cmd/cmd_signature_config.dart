import 'package:meta/meta.dart';

/// Endpoints and client identity for the CMD signing flow.
///
/// These are per-app and per-environment — the two apps have different OAuth
/// clients — so the package holds none of them and takes them all from the
/// host.
@immutable
class CmdSignatureConfig {
  const CmdSignatureConfig({
    required this.authorizeUrl,
    required this.tokenUrl,
    required this.signUrl,
    required this.clientId,
    required this.redirectUri,
    this.scope = defaultScope,
    this.signTimeout = defaultSignTimeout,
  });

  /// The scope the CMD signing client is provisioned for. Note `cmd` — the
  /// plain sign-in clients in both apps use `openid` alone and will not work
  /// here.
  static const String defaultScope = 'openid profile phone cmd';

  /// Signing is slow server-side: the API validates the PIN, signs and returns
  /// the whole document. The native Android app uses 120 s and so do we.
  static const Duration defaultSignTimeout = Duration(seconds: 120);

  final Uri authorizeUrl;
  final Uri tokenUrl;
  final Uri signUrl;

  /// OAuth client id. This is a **public** client: no secret is sent, and the
  /// flow relies on PKCE instead.
  final String clientId;

  /// Must carry the custom scheme registered in the app's AndroidManifest and
  /// Info.plist, or the callback never comes back.
  final String redirectUri;

  final String scope;
  final Duration signTimeout;

  /// The scheme [redirectUri] starts with, which is what the web-auth
  /// implementation listens on.
  String get callbackUrlScheme => Uri.parse(redirectUri).scheme;
}
