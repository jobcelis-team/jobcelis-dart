import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jobcelis/jobcelis.dart';
import 'package:test/test.dart';

/// Builds a client that answers every request with [body] and records the requests.
JobcelisClient _client(List<http.Request> requests, [Map<String, dynamic> body = const {}]) {
  final mock = MockClient((request) async {
    requests.add(request);
    return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
  });
  return JobcelisClient(apiKey: 'key', httpClient: mock, maxRetries: 0);
}

Map<String, dynamic> _body(http.Request request) => jsonDecode(request.body) as Map<String, dynamic>;

void main() {
  test('restrictProcessing sends the password', () async {
    final requests = <http.Request>[];
    await _client(requests).restrictProcessing('secret');
    expect(_body(requests.single)['password'], 'secret');
  });

  test('status reads the JSON health endpoint', () async {
    final requests = <http.Request>[];
    final status = await _client(requests, {'status': 'healthy'}).status();
    expect(status['status'], 'healthy');
    expect(requests.single.url.path, '/health');
  });

  test('addMember defaults to the viewer role', () async {
    final requests = <http.Request>[];
    await _client(requests).addMember('proj_1', 'a@example.com');
    expect(_body(requests.single)['role'], 'viewer');
  });

  test('testPipeline wraps the payload', () async {
    final requests = <http.Request>[];
    await _client(requests).testPipeline('pipe_1', {'id': '1'});
    expect(_body(requests.single)['payload'], {'id': '1'});
  });

  test('updateRetentionPolicy wraps the policy', () async {
    final requests = <http.Request>[];
    await _client(requests).updateRetentionPolicy({'events_days': 30});
    expect(_body(requests.single)['retention_policy'], {'events_days': 30});
  });

  test('createPipeline sends the webhook id', () async {
    final requests = <http.Request>[];
    await _client(requests).createPipeline('p', ['a'], [], webhookId: 'wh_1');
    expect(_body(requests.single)['webhook_id'], 'wh_1');
  });

  test('path parameters are percent-encoded', () async {
    final requests = <http.Request>[];
    await _client(requests).getEvent('a/b?c');
    expect(requests.single.url.toString(), 'https://jobcelis.com/api/v1/events/a%2Fb%3Fc');
  });

  test('an attempt that runs out of time throws TimeoutException', () async {
    final mock = MockClient((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return http.Response('{}', 200);
    });
    final client = JobcelisClient(
      apiKey: 'key',
      httpClient: mock,
      maxRetries: 0,
      timeout: const Duration(milliseconds: 20),
    );
    await expectLater(client.health(), throwsA(isA<TimeoutException>()));
  });
}
