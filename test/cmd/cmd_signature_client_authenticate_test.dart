import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cv_document_signature/cv_document_signature.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fakes.dart';

void main() {
  late List<http.Request> requests;

  MockClient tokenClient(http.Response Function(http.Request) handler) =>
      MockClient((request) async {
        requests.add(request);
        return handler(request);
      });

  http.Response okToken([String token = 'the-token']) => http.Response(
        jsonEncode(<String, dynamic>{'access_token': token}),
        200,
      );

  setUp(() => requests = <http.Request>[]);

  group('authorize request', () {
    test('sends the PKCE parameters and the signing scope', () async {
      final webAuth = FakeWebAuthenticator(callbackBuilder: echoStateCallback);
      final client = CmdSignatureClient(
        config: testConfig(),
        webAuthenticator: webAuth,
        httpClient: tokenClient((_) => okToken()),
      );

      await client.authenticate();

      final query = webAuth.lastUrl!.queryParameters;
      expect(query['response_type'], 'code');
      expect(query['client_id'], 'test-client');
      expect(query['code_challenge_method'], 'S256');
      expect(query['redirect_uri'], 'app://oauth');
      expect(query['scope'], 'openid profile phone cmd');
      expect(query['state'], isNotEmpty);
      expect(query['code_challenge'], isNotEmpty);
      expect(webAuth.lastCallbackUrlScheme, 'app');
    });

    test('the code challenge is unpadded base64url of SHA-256', () async {
      final webAuth = FakeWebAuthenticator(callbackBuilder: echoStateCallback);
      final client = CmdSignatureClient(
        config: testConfig(),
        webAuthenticator: webAuth,
        httpClient: tokenClient((_) => okToken()),
      );

      await client.authenticate();

      final challenge = webAuth.lastUrl!.queryParameters['code_challenge']!;
      expect(challenge, isNot(contains('=')));
      expect(challenge, isNot(contains('+')));
      expect(challenge, isNot(contains('/')));
      // SHA-256 is 32 bytes; unpadded base64 of 32 bytes is 43 characters.
      expect(challenge.length, 43);
    });

    test('a fresh state and verifier are generated per attempt', () async {
      final seen = <String>{};
      for (var i = 0; i < 3; i++) {
        final webAuth =
            FakeWebAuthenticator(callbackBuilder: echoStateCallback);
        final client = CmdSignatureClient(
          config: testConfig(),
          webAuthenticator: webAuth,
          httpClient: tokenClient((_) => okToken()),
        );
        await client.authenticate();
        seen.add(webAuth.lastUrl!.queryParameters['code_challenge']!);
      }

      expect(seen.length, 3);
    });
  });

  group('token exchange', () {
    test('returns the access token', () async {
      final client = CmdSignatureClient(
        config: testConfig(),
        webAuthenticator:
            FakeWebAuthenticator(callbackBuilder: echoStateCallback),
        httpClient: tokenClient((_) => okToken('abc123')),
      );

      expect(await client.authenticate(), 'abc123');
    });

    test('NEVER sends a client_secret — this is a public client', () async {
      final client = CmdSignatureClient(
        config: testConfig(),
        webAuthenticator:
            FakeWebAuthenticator(callbackBuilder: echoStateCallback),
        httpClient: tokenClient((_) => okToken()),
      );

      await client.authenticate();

      expect(requests.single.body, isNot(contains('client_secret')));
    });

    test('sends the PKCE verifier and the authorization code', () async {
      final client = CmdSignatureClient(
        config: testConfig(),
        webAuthenticator:
            FakeWebAuthenticator(callbackBuilder: echoStateCallback),
        httpClient: tokenClient((_) => okToken()),
      );

      await client.authenticate();

      final body = Uri.splitQueryString(requests.single.body);
      expect(body['grant_type'], 'authorization_code');
      expect(body['code'], 'the-code');
      expect(body['client_id'], 'test-client');
      expect(body['redirect_uri'], 'app://oauth');
      expect(body['code_verifier'], hasLength(128));
    });

    test('the verifier it sends matches the challenge it sent', () async {
      final webAuth = FakeWebAuthenticator(callbackBuilder: echoStateCallback);
      final client = CmdSignatureClient(
        config: testConfig(),
        webAuthenticator: webAuth,
        httpClient: tokenClient((_) => okToken()),
      );

      await client.authenticate();

      final verifier = Uri.splitQueryString(requests.single.body)['code_verifier']!;
      final expected = base64Url
          .encode(sha256.convert(ascii.encode(verifier)).bytes)
          .replaceAll('=', '');
      expect(webAuth.lastUrl!.queryParameters['code_challenge'], expected);
    });

    test('rejects a non-2xx response', () async {
      final client = CmdSignatureClient(
        config: testConfig(),
        webAuthenticator:
            FakeWebAuthenticator(callbackBuilder: echoStateCallback),
        httpClient: tokenClient((_) => http.Response('nope', 401)),
      );

      expect(client.authenticate(), throwsA(isA<CmdSignatureException>()));
    });

    test('rejects a response with no access token', () async {
      final client = CmdSignatureClient(
        config: testConfig(),
        webAuthenticator:
            FakeWebAuthenticator(callbackBuilder: echoStateCallback),
        httpClient: tokenClient((_) => http.Response('{}', 200)),
      );

      expect(client.authenticate(), throwsA(isA<CmdSignatureException>()));
    });

    test('rejects a non-JSON response', () async {
      final client = CmdSignatureClient(
        config: testConfig(),
        webAuthenticator:
            FakeWebAuthenticator(callbackBuilder: echoStateCallback),
        httpClient: tokenClient((_) => http.Response('<html>', 200)),
      );

      expect(client.authenticate(), throwsA(isA<CmdSignatureException>()));
    });

    test('surfaces a transport failure as CmdSignatureException', () async {
      final client = CmdSignatureClient(
        config: testConfig(),
        webAuthenticator:
            FakeWebAuthenticator(callbackBuilder: echoStateCallback),
        httpClient: MockClient((_) => throw const SocketLikeError()),
      );

      expect(client.authenticate(), throwsA(isA<CmdSignatureException>()));
    });
  });

  group('callback validation', () {
    test('rejects a mismatched state and never reaches the token endpoint',
        () async {
      final client = CmdSignatureClient(
        config: testConfig(),
        webAuthenticator: FakeWebAuthenticator(
          callbackBuilder: (_) => 'app://oauth?code=c&state=not-the-state',
        ),
        httpClient: tokenClient((_) => okToken()),
      );

      await expectLater(
        client.authenticate(),
        throwsA(isA<CmdSignatureException>()),
      );
      expect(requests, isEmpty);
    });

    test('rejects a callback with no authorization code', () async {
      final client = CmdSignatureClient(
        config: testConfig(),
        webAuthenticator: FakeWebAuthenticator(
          callbackBuilder: (url) =>
              'app://oauth?state=${url.queryParameters['state']}',
        ),
        httpClient: tokenClient((_) => okToken()),
      );

      expect(client.authenticate(), throwsA(isA<CmdSignatureException>()));
    });

    test('never logs the state values on a mismatch', () async {
      final logs = <String>[];
      final client = CmdSignatureClient(
        config: testConfig(),
        webAuthenticator: FakeWebAuthenticator(
          callbackBuilder: (_) => 'app://oauth?code=c&state=leaky-state-value',
        ),
        httpClient: tokenClient((_) => okToken()),
        onError: logs.add,
      );

      await expectLater(
        client.authenticate(),
        throwsA(isA<CmdSignatureException>()),
      );
      expect(logs.join('\n'), isNot(contains('leaky-state-value')));
    });

    test('propagates cancellation from the web authenticator', () async {
      final client = CmdSignatureClient(
        config: testConfig(),
        webAuthenticator: FakeWebAuthenticator(
          error: const CmdSignatureCancelledException(),
        ),
        httpClient: tokenClient((_) => okToken()),
      );

      expect(
        client.authenticate(),
        throwsA(isA<CmdSignatureCancelledException>()),
      );
    });
  });
}

class SocketLikeError implements Exception {
  const SocketLikeError();
}
