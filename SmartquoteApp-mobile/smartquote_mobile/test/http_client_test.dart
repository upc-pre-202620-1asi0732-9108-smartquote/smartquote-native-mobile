import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartquote_mobile/shared/infrastructure/api_client.dart';
import 'package:smartquote_mobile/shared/domain/api_contract.dart';
import 'package:smartquote_mobile/identity_access/infrastructure/http_identity_repository.dart';
import 'package:smartquote_mobile/identity_access/application/session_controller.dart';

import 'support/fixtures.dart';

void main() {
  test('Real local HTTP transport sends JWT, multipart and refresh cookie, retrying only a 401', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var sessions = 0, protectedCalls = 0;
    final cookies = <String>[], authHeaders = <String>[], paths = <String>[];
    String? uploadType;
    server.listen((request) async {
      final path = request.uri.path;
      paths.add(path);
      request.response.headers.contentType = ContentType.json;
      if (path.endsWith('/login') || path.endsWith('/refresh')) {
        if (path.endsWith('/refresh')) {
          cookies.add(request.headers.value('cookie') ?? '');
        }
        sessions++;
        await utf8.decoder.bind(request).join();
        request.response.headers.add(
          'set-cookie',
          'smartquote_refresh=test-refresh-$sessions; Path=/api/v1/iam/auth; HttpOnly',
        );
        request.response.write(
          jsonEncode({
            ...sessionFixture('PurchaseAnalyst'),
            'accessToken': 'test-token-$sessions',
          }),
        );
      } else if (path.endsWith('/logout')) {
        cookies.add(request.headers.value('cookie') ?? '');
        request.response.statusCode = 204;
      } else if (path.endsWith('/protected')) {
        protectedCalls++;
        authHeaders.add(request.headers.value('authorization') ?? '');
        if (protectedCalls == 1) {
          request.response.statusCode = 401;
        } else {
          request.response.write(jsonEncode({'ok': true}));
        }
      } else if (path.endsWith('/upload')) {
        uploadType = request.headers.contentType?.mimeType;
        final body = await utf8.decoder.bind(request).join();
        expect(body, contains('name="file"'));
        expect(body, contains('filename="cotizacion.pdf"'));
        expect(body, contains('name="expectedVersion"'));
        request.response.write(jsonEncode({'ok': true}));
      } else {
        request.response.statusCode = 422;
        request.response.write(
          jsonEncode({
            'detail': 'Required fields unresolved',
            'code': 'domain_rule_violation',
            'traceId': 'test-trace',
          }),
        );
      }
      await request.response.close();
    });
    final client = ApiClient('http://127.0.0.1:${server.port}/api/v1');
    final session = SessionController(HttpIdentityRepository(client), client);
    addTearDown(session.dispose);
    await session.login('demo@example.com', 'TestOnly!12345');
    expect(await client.request('/protected'), {'ok': true});
    expect(protectedCalls, 2);
    expect(sessions, 2);
    expect(authHeaders, ['Bearer test-token-1', 'Bearer test-token-2']);
    expect(cookies.single, contains('smartquote_refresh=test-refresh-1'));
    await client.request(
      '/upload',
      method: 'POST',
      body: MultipartPayload(
        {'expectedVersion': 4},
        {
          'file': [fileFixture()],
        },
      ),
    );
    expect(uploadType, 'multipart/form-data');
    await expectLater(
      client.request('/bad', method: 'POST'),
      throwsA(
        isA<ApiFailure>()
            .having((e) => e.status, 'status', 422)
            .having((e) => e.traceId, 'trace', 'test-trace'),
      ),
    );
    expect(paths.where((p) => p.endsWith('/bad')).length, 1);
    await session.logout();
    expect(client.accessToken, null);
    expect(cookies.last, contains('smartquote_refresh=test-refresh-2'));
    await expectLater(
      client.request('/protected'),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 401)),
    );
  });
}
