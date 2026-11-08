import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jobcelis/jobcelis.dart';
import 'package:test/test.dart';

/// Builds a client whose HTTP layer answers with [handler] and records every request.
JobcelisClient _client(
  List<http.Request> requests,
  Future<http.Response> Function(http.Request request, int attempt) handler, {
  int? maxRetries,
}) {
  final mock = MockClient((request) {
    requests.add(request);
    return handler(request, requests.length);
  });
  return maxRetries == null
      ? JobcelisClient(apiKey: 'key', httpClient: mock, retryBaseDelay: const Duration(milliseconds: 1))
      : JobcelisClient(
          apiKey: 'key',
          httpClient: mock,
          maxRetries: maxRetries,
          retryBaseDelay: const Duration(milliseconds: 1),
        );
}

http.Response _json(int status, [Map<String, dynamic> body = const {}, Map<String, String> headers = const {}]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json', ...headers});

void main() {
  test('GET is retried on 503 until it succeeds', () async {
    final requests = <http.Request>[];
    final client = _client(requests, (_, attempt) async => attempt < 3 ? _json(503) : _json(200, {'id': 'evt_1'}));

    final event = await client.getEvent('evt_1');

    expect(event['id'], 'evt_1');
    expect(requests, hasLength(3));
  });

  test('429 with Retry-After is retried', () async {
    final requests = <http.Request>[];
    final client = _client(
      requests,
      (_, attempt) async => attempt == 1 ? _json(429, {}, {'retry-after': '0'}) : _json(200, {'ok': true}),
    );

    final result = await client.listEvents();

    expect(result['ok'], true);
    expect(requests, hasLength(2));
  });

  test('sendEvent sends the same generated X-Idempotency-Key on every attempt', () async {
    final requests = <http.Request>[];
    final client = _client(requests, (_, attempt) async => attempt < 3 ? _json(502) : _json(202, {'id': 'evt_1'}));

    await client.sendEvent('order.created', {'order_id': '1'});

    expect(requests, hasLength(3));
    final keys = requests.map((r) => r.headers['X-Idempotency-Key']).toSet();
    expect(keys, hasLength(1));
    expect(
      keys.single,
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
    );
  });

  test('sendEvent keeps a caller-supplied idempotency key', () async {
    final requests = <http.Request>[];
    final client = _client(requests, (_, attempt) async => attempt == 1 ? _json(503) : _json(202));

    await client.sendEvent('order.created', {'order_id': '1'}, idempotencyKey: 'my-key');

    expect(requests, hasLength(2));
    expect(requests.map((r) => r.headers['X-Idempotency-Key']), everyElement('my-key'));
  });

  test('sendEvent is retried on a network error', () async {
    final requests = <http.Request>[];
    final client = _client(requests, (_, attempt) async {
      if (attempt == 1) throw http.ClientException('Connection reset');
      return _json(202);
    });

    await client.sendEvent('order.created', {'order_id': '1'});

    expect(requests, hasLength(2));
    expect(requests[0].headers['X-Idempotency-Key'], requests[1].headers['X-Idempotency-Key']);
  });

  test('sendEvents adds idempotency_key to items that lack one and keeps existing ones', () async {
    final requests = <http.Request>[];
    final client = _client(requests, (_, attempt) async => attempt == 1 ? _json(503) : _json(202));

    await client.sendEvents([
      {'topic': 'a', 'payload': {}},
      {'topic': 'b', 'payload': {}, 'idempotency_key': 'existing'},
    ]);

    expect(requests, hasLength(2));
    List<dynamic> items(http.Request r) => (jsonDecode(r.body) as Map<String, dynamic>)['events'] as List<dynamic>;
    final first = items(requests[0]);
    expect(first[0]['idempotency_key'], isA<String>());
    expect((first[0]['idempotency_key'] as String).length, 36);
    expect(first[1]['idempotency_key'], 'existing');
    expect(items(requests[1]), first, reason: 'the same body is sent on retries');
  });

  test('POST of a non-event resource is not retried on a network error', () async {
    final requests = <http.Request>[];
    final client = _client(requests, (_, __) async => throw http.ClientException('Connection refused'));

    await expectLater(client.createWebhook('https://example.com/hook'), throwsA(isA<http.ClientException>()));
    expect(requests, hasLength(1));
  });

  test('POST of a non-event resource is retried on 503', () async {
    final requests = <http.Request>[];
    final client = _client(requests, (_, attempt) async => attempt == 1 ? _json(503) : _json(201, {'id': 'wh_1'}));

    final webhook = await client.createWebhook('https://example.com/hook');

    expect(webhook['id'], 'wh_1');
    expect(requests, hasLength(2));
  });

  test('maxRetries = 0 makes exactly one request', () async {
    final requests = <http.Request>[];
    final client = _client(requests, (_, __) async => _json(503), maxRetries: 0);

    await expectLater(
      client.getEvent('evt_1'),
      throwsA(isA<JobcelisException>().having((e) => e.statusCode, 'statusCode', 503)),
    );
    expect(requests, hasLength(1));
  });

  test('gives up after maxRetries and throws the last error', () async {
    final requests = <http.Request>[];
    final client = _client(requests, (_, __) async => _json(504), maxRetries: 2);

    await expectLater(
      client.getEvent('evt_1'),
      throwsA(isA<JobcelisException>().having((e) => e.statusCode, 'statusCode', 504)),
    );
    expect(requests, hasLength(3));
  });

  for (final status in [400, 500]) {
    test('status $status is not retried', () async {
      final requests = <http.Request>[];
      final client = _client(requests, (_, __) async => _json(status, {'error': 'nope'}));

      await expectLater(
        client.getEvent('evt_1'),
        throwsA(isA<JobcelisException>().having((e) => e.statusCode, 'statusCode', status)),
      );
      expect(requests, hasLength(1));
    });
  }
}
