import 'cmd_signature_exceptions.dart';

/// Opens [url] in a browser and completes with the callback URL the
/// authorization server redirects to.
///
/// An interface, not an implementation: the package takes no dependency on a
/// web-auth plugin so each app can keep the one it already ships. A typical
/// adapter is a few lines over `flutter_web_auth`:
///
/// ```dart
/// class FlutterWebAuthAuthenticator implements WebAuthenticator {
///   @override
///   Future<String> authenticate({
///     required String url,
///     required String callbackUrlScheme,
///   }) async {
///     try {
///       return await FlutterWebAuth.authenticate(
///         url: url,
///         callbackUrlScheme: callbackUrlScheme,
///         preferEphemeral: true,
///       );
///     } on PlatformException catch (e) {
///       if (e.code == 'CANCELED') throw const CmdSignatureCancelledException();
///       rethrow;
///     }
///   }
/// }
/// ```
///
/// Prefer an ephemeral session where the platform supports it, so signing does
/// not silently reuse a browser cookie from an unrelated login.
///
/// Implementations should throw [CmdSignatureCancelledException] when the user
/// dismisses the flow, so callers can tell "went back" from "went wrong".
abstract class WebAuthenticator {
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
  });
}
