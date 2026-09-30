import 'dart:convert';
import 'dart:typed_data';

import 'package:cv_document_signature/cv_document_signature.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fakes.dart';

void main() {
  final document = Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46, 1, 2, 3]);
  final signed = Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46, 9, 9]);

  late List<http.Request> requests;

  CmdSignatureClient clientWith(
    Future<http.Response> Function(http.Request) handler, {
    void Function(String)? onError,
    Duration? signTimeout,
  }) =>
      CmdSignatureClient(
        config: testConfig(signTimeout: signTimeout),
        webAuthenticator: FakeWebAuthenticator(),
        httpClient: MockClient((request) {
          requests.add(request);
          return handler(request);
        }),
        onError: onError,
      );

  Future<Uint8List> signWith(CmdSignatureClient client) => client.sign(
        accessToken: 'the-token',
        pin: '123456',
        documentBytes: document,
        page: 2,
        x: 100.5,
        y: 42.25,
      );

  http.Response okSigned() => http.Response(
        jsonEncode(<String, dynamic>{
          'failed': false,
          'document': base64Encode(signed),
        }),
        200,
      );

  setUp(() => requests = <http.Request>[]);

  group('request', () {
    test('posts the exact payload the service expects', () async {
      final client = clientWith((_) async => okSigned());

      await signWith(client);

      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['page'], 2);
      expect(body['pin'], '123456');
      expect(body['visible'], true);
      expect(body['document'], base64Encode(document));
      expect(body['coordinates'], <String, dynamic>{'x': 100.5, 'y': 42.25});
      expect(body['filename'], endsWith('.pdf'));
    });

    test('sends the bearer token and a JSON content type', () async {
      final client = clientWith((_) async => okSigned());

      await signWith(client);

      expect(requests.single.headers['Authorization'], 'Bearer the-token');
      expect(
        requests.single.headers['Content-Type'],
        contains('application/json'),
      );
    });

    test('sends the original bytes, untouched', () async {
      // The service does the signing and draws the visible signature; if this
      // ever stops being the raw input, something started modifying the PDF.
      final client = clientWith((_) async => okSigned());

      await signWith(client);

      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(base64Decode(body['document'] as String), document);
    });

    test('does not send the rectangle extent', () async {
      final client = clientWith((_) async => okSigned());

      await signWith(client);

      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body.containsKey('width'), isFalse);
      expect(body.containsKey('height'), isFalse);
      expect(
        (body['coordinates'] as Map<String, dynamic>).keys,
        unorderedEquals(<String>['x', 'y']),
      );
    });

    test('uses a fresh filename each time', () async {
      final client = clientWith((_) async => okSigned());

      await signWith(client);
      await signWith(client);

      final names = requests
          .map((r) => (jsonDecode(r.body) as Map<String, dynamic>)['filename'])
          .toSet();
      expect(names.length, 2);
    });
  });

  group('response', () {
    test('returns the decoded signed document', () async {
      final client = clientWith((_) async => okSigned());

      expect(await signWith(client), signed);
    });

    test('treats failed:true as an error despite a 200', () async {
      final client = clientWith(
        (_) async => http.Response(
          jsonEncode(<String, dynamic>{'failed': true}),
          200,
        ),
      );

      expect(signWith(client), throwsA(isA<CmdSignatureException>()));
    });

    test('maps the not-active marker to its own exception', () async {
      final client = clientWith(
        (_) async => http.Response(
          '{"message":"Digital signature not active for the user"}',
          200,
        ),
      );

      expect(
        signWith(client),
        throwsA(isA<CmdSignatureNotActiveException>()),
      );
    });

    test('detects the not-active marker even behind an error status', () async {
      final client = clientWith(
        (_) async => http.Response(
          '{"message":"Digital signature not active for the user"}',
          500,
        ),
      );

      expect(
        signWith(client),
        throwsA(isA<CmdSignatureNotActiveException>()),
      );
    });

    test('rejects a non-2xx response', () async {
      final client = clientWith((_) async => http.Response('boom', 502));

      expect(signWith(client), throwsA(isA<CmdSignatureException>()));
    });

    test('rejects a response with no document', () async {
      final client = clientWith(
        (_) async => http.Response(
          jsonEncode(<String, dynamic>{'failed': false}),
          200,
        ),
      );

      expect(signWith(client), throwsA(isA<CmdSignatureException>()));
    });

    test('rejects a document that is not valid base64', () async {
      final client = clientWith(
        (_) async => http.Response(
          jsonEncode(<String, dynamic>{'document': 'not base64 !!!'}),
          200,
        ),
      );

      expect(signWith(client), throwsA(isA<CmdSignatureException>()));
    });

    test('rejects a non-JSON response', () async {
      final client = clientWith((_) async => http.Response('<html>', 200));

      expect(signWith(client), throwsA(isA<CmdSignatureException>()));
    });
  });

  group('timeout', () {
    test('gives up after the configured signing timeout', () {
      fakeAsync((async) {
        final client = clientWith(
          (_) => Future<http.Response>.delayed(
            const Duration(seconds: 200),
            okSigned,
          ),
          signTimeout: const Duration(seconds: 120),
        );

        Object? thrown;
        signWith(client).catchError((Object e) {
          thrown = e;
          return Uint8List(0);
        });

        async.elapse(const Duration(seconds: 119));
        expect(thrown, isNull, reason: 'must not give up early');

        async.elapse(const Duration(seconds: 2));
        expect(thrown, isA<CmdSignatureException>());
      });
    });

    test('defaults to 120 seconds', () {
      expect(
        CmdSignatureConfig.defaultSignTimeout,
        const Duration(seconds: 120),
      );
      expect(testConfig().signTimeout, const Duration(seconds: 120));
    });
  });

  group('the PIN never leaks', () {
    test('is absent from the log sink on a transport failure', () async {
      final logs = <String>[];
      final client = clientWith(
        (_) async => throw Exception('connection reset'),
        onError: logs.add,
      );

      await expectLater(
        signWith(client),
        throwsA(isA<CmdSignatureException>()),
      );
      expect(logs, isNotEmpty, reason: 'the failure should be logged at all');
      expect(logs.join('\n'), isNot(contains('123456')));
    });

    test('is absent from the log sink on an error status', () async {
      final logs = <String>[];
      final client = clientWith(
        (_) async => http.Response('server said no', 500),
        onError: logs.add,
      );

      await expectLater(
        signWith(client),
        throwsA(isA<CmdSignatureException>()),
      );
      expect(logs.join('\n'), isNot(contains('123456')));
    });

    test('is absent from the exception message', () async {
      final client = clientWith((_) async => http.Response('boom', 502));

      try {
        await signWith(client);
        fail('expected a CmdSignatureException');
      } on CmdSignatureException catch (e) {
        expect(e.toString(), isNot(contains('123456')));
      }
    });
  });
}
