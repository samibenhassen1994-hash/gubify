import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/push_notifications/models/push_event.dart';
import 'package:gubify/modules/push_notifications/services/push_event_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const endpoint = 'https://push.example.test/api/push/events';
  const token = 'secret-firebase-token';

  group('PushEventClient request contract', () {
    final cases = <({PushEvent event, String body})>[
      (
        event: PushEvent.taskAssigned(gubId: 'gub-1', taskId: 'task-1'),
        body: '{"type":"task_assigned","gubId":"gub-1","taskId":"task-1"}',
      ),
      (
        event: PushEvent.proposalCreated(
          gubId: 'gub-2',
          proposalId: 'proposal-1',
        ),
        body:
            '{"type":"proposal_created","gubId":"gub-2","proposalId":"proposal-1"}',
      ),
      (
        event: PushEvent.communityAnswerCreated(
          communityId: 'community-1',
          askId: 'ask-1',
          answerId: 'answer-1',
        ),
        body:
            '{"type":"community_answer_created","communityId":"community-1","askId":"ask-1","answerId":"answer-1"}',
      ),
      (
        event: PushEvent.communityBestAnswerSelected(
          communityId: 'community-2',
          askId: 'ask-2',
          answerId: 'answer-2',
        ),
        body:
            '{"type":"community_best_answer_selected","communityId":"community-2","askId":"ask-2","answerId":"answer-2"}',
      ),
      (
        event: PushEvent.communityJoinRequestCreated(
          communityId: 'community-3',
          requesterUid: 'requester-1',
        ),
        body:
            '{"type":"community_join_request_created","communityId":"community-3","requesterUid":"requester-1"}',
      ),
      (
        event: PushEvent.communityJoinRequestResolved(
          communityId: 'community-4',
          requesterUid: 'requester-2',
        ),
        body:
            '{"type":"community_join_request_resolved","communityId":"community-4","requesterUid":"requester-2"}',
      ),
    ];

    for (final testCase in cases) {
      test('sends exact ${jsonDecode(testCase.body)['type']} JSON', () async {
        late http.Request captured;
        final client = PushEventClient.forTesting(
          endpoint: endpoint,
          getIdToken: () async => token,
          httpClient: MockClient((request) async {
            captured = request;
            return http.Response('', 202);
          }),
        );

        await client.submit(testCase.event);

        expect(captured.method, 'POST');
        expect(captured.url, Uri.parse(endpoint));
        expect(captured.headers['authorization'], 'Bearer $token');
        expect(captured.headers['content-type'], 'application/json');
        expect(captured.body, testCase.body);
        final body = jsonDecode(captured.body) as Map<String, dynamic>;
        expect(
          body.keys,
          isNot(
            contains(
              anyOf(
                'recipientId',
                'recipientIds',
                'title',
                'body',
                'requestedAt',
              ),
            ),
          ),
        );
      });
    }

    test('gets a fresh Firebase ID token for every submission', () async {
      var tokenCalls = 0;
      final authorizationHeaders = <String?>[];
      final client = PushEventClient.forTesting(
        endpoint: endpoint,
        getIdToken: () async => 'token-${++tokenCalls}',
        httpClient: MockClient((request) async {
          authorizationHeaders.add(request.headers['authorization']);
          return http.Response('', 204);
        }),
      );

      const event = PushEvent.taskAssigned(gubId: 'gub', taskId: 'task');
      await client.submit(event);
      await client.submit(event);

      expect(tokenCalls, 2);
      expect(authorizationHeaders, ['Bearer token-1', 'Bearer token-2']);
    });
  });

  test('does nothing when the compile-time endpoint is missing', () async {
    var tokenCalls = 0;
    var httpCalls = 0;
    final logs = <String>[];
    final client = PushEventClient(
      getIdToken: () async {
        tokenCalls++;
        return token;
      },
      httpClient: MockClient((_) async {
        httpCalls++;
        return http.Response('', 200);
      }),
      logger: logs.add,
    );

    await client.submit(
      const PushEvent.proposalCreated(gubId: 'gub', proposalId: 'proposal'),
    );

    expect(tokenCalls, 0);
    expect(httpCalls, 0);
    expect(logs, isEmpty);
  });

  test('swallows non-2xx responses and logs only coarse status', () async {
    final logs = <String>[];
    final client = PushEventClient.forTesting(
      endpoint: endpoint,
      getIdToken: () async => token,
      httpClient: MockClient(
        (_) async => http.Response('server echoed $token', 503),
      ),
      logger: logs.add,
    );

    await expectLater(
      client.submit(const PushEvent.taskAssigned(gubId: 'gub', taskId: 'task')),
      completes,
    );

    expect(logs, ['Push event delivery failed (HTTP 503).']);
    expect(logs.join(), isNot(contains(token)));
  });

  test('swallows timeouts without logging token-bearing errors', () async {
    final logs = <String>[];
    final client = PushEventClient.forTesting(
      endpoint: endpoint,
      getIdToken: () async => token,
      httpClient: MockClient((_) => Completer<http.Response>().future),
      requestTimeout: const Duration(milliseconds: 1),
      logger: logs.add,
    );

    await expectLater(
      client.submit(
        const PushEvent.proposalCreated(gubId: 'gub', proposalId: 'proposal'),
      ),
      completes,
    );

    expect(logs, ['Push event delivery timed out.']);
    expect(logs.join(), isNot(contains(token)));
  });

  test('swallows auth and transport errors without exposing tokens', () async {
    final logs = <String>[];
    final authFailure = PushEventClient.forTesting(
      endpoint: endpoint,
      getIdToken: () async => throw StateError('failed with $token'),
      httpClient: MockClient((_) async => http.Response('', 200)),
      logger: logs.add,
    );
    final transportFailure = PushEventClient.forTesting(
      endpoint: endpoint,
      getIdToken: () async => token,
      httpClient: MockClient((_) async => throw Exception(token)),
      logger: logs.add,
    );

    await expectLater(
      authFailure.submit(
        const PushEvent.communityJoinRequestCreated(
          communityId: 'community',
          requesterUid: 'requester',
        ),
      ),
      completes,
    );
    await expectLater(
      transportFailure.submit(
        const PushEvent.communityJoinRequestResolved(
          communityId: 'community',
          requesterUid: 'requester',
        ),
      ),
      completes,
    );

    expect(logs, [
      'Push event delivery failed during authentication.',
      'Push event delivery failed.',
    ]);
    expect(logs.join(), isNot(contains(token)));
  });

  test('does not send when no authenticated token is available', () async {
    var httpCalls = 0;
    final logs = <String>[];
    final client = PushEventClient.forTesting(
      endpoint: endpoint,
      getIdToken: () async => null,
      httpClient: MockClient((_) async {
        httpCalls++;
        return http.Response('', 200);
      }),
      logger: logs.add,
    );

    await client.submit(
      const PushEvent.communityAnswerCreated(
        communityId: 'community',
        askId: 'ask',
        answerId: 'answer',
      ),
    );

    expect(httpCalls, 0);
    expect(logs, ['Push event delivery skipped: no authenticated user.']);
  });

  test('a throwing logger cannot fail the domain action', () async {
    final client = PushEventClient.forTesting(
      endpoint: endpoint,
      getIdToken: () async => token,
      httpClient: MockClient((_) async => http.Response('', 500)),
      logger: (_) => throw StateError('logger failed'),
    );

    await expectLater(
      client.submit(const PushEvent.taskAssigned(gubId: 'gub', taskId: 'task')),
      completes,
    );
  });
}
