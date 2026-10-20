import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:expense_tracker_app/core/services/agent_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AgentService Error Mapping and HTTP Flow Tests', () {
    test('Returns "Please log in again" when user is not authenticated', () async {
      final service = AgentService(
        client: MockClient((_) async => http.Response('{}', 200)),
        tokenProvider: ({forceRefresh = false}) async => null,
      );

      final result = await service.sendMessage(message: "Hello");

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, "Please log in again"),
        (_) => fail("Should have failed with auth error"),
      );
    });

    test('Retries with refreshed token on 401 and succeeds', () async {
      int callCount = 0;
      final service = AgentService(
        client: MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            expect(request.headers['Authorization'], 'Bearer initial_token');
            return http.Response('{"error": "Unauthorized"}', 401);
          } else {
            expect(request.headers['Authorization'], 'Bearer refreshed_token');
            return http.Response(
              jsonEncode({
                'reply': 'Hello after refresh!',
                'toolCalls': [],
                'pendingAction': null,
                'isOffline': false,
              }),
              200,
            );
          }
        }),
        tokenProvider: ({forceRefresh = false}) async {
          return forceRefresh ? 'refreshed_token' : 'initial_token';
        },
      );

      final result = await service.sendMessage(message: "Hello");

      expect(result.isRight(), isTrue);
      expect(callCount, 2);
      result.fold(
        (f) => fail("Should have succeeded"),
        (data) => expect(data['reply'], 'Hello after refresh!'),
      );
    });

    test('Maps 429 status code to "Too many requests, wait a minute"', () async {
      final service = AgentService(
        client: MockClient((_) async => http.Response('{"error": "Rate limited"}', 429)),
        tokenProvider: ({forceRefresh = false}) async => 'test_token',
      );

      final result = await service.sendMessage(message: "Hello");

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, "Too many requests, wait a minute"),
        (_) => fail("Should have failed with 429"),
      );
    });

    test('Maps 409 status code to "This action was already processed"', () async {
      final service = AgentService(
        client: MockClient((_) async => http.Response('{"error": "Replay blocked"}', 409)),
        tokenProvider: ({forceRefresh = false}) async => 'test_token',
      );

      final result = await service.confirm("action_123");

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, "This action was already processed"),
        (_) => fail("Should have failed with 409"),
      );
    });

    test('Maps 410 status code to expired action message', () async {
      final service = AgentService(
        client: MockClient((_) async => http.Response('{"error": "Action expired"}', 410)),
        tokenProvider: ({forceRefresh = false}) async => 'test_token',
      );

      final result = await service.confirm("action_expired");

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, contains("expired")),
        (_) => fail("Should have failed with 410"),
      );
    });

    test('Maps TimeoutException to friendly timeout message', () async {
      final service = AgentService(
        client: MockClient((_) async {
          throw TimeoutException("Connection timed out");
        }),
        tokenProvider: ({forceRefresh = false}) async => 'test_token',
      );

      final result = await service.sendMessage(message: "Hello");

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, contains("timed out")),
        (_) => fail("Should have failed with timeout"),
      );
    });

    test('Maps SocketException to network error message', () async {
      final service = AgentService(
        client: MockClient((_) async {
          throw const SocketException("Failed host lookup");
        }),
        tokenProvider: ({forceRefresh = false}) async => 'test_token',
      );

      final result = await service.sendMessage(message: "Hello");

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, contains("Network error")),
        (_) => fail("Should have failed with network error"),
      );
    });

    test('Confirm sends actionId to /api/confirm and returns summary on success', () async {
      final service = AgentService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/confirm');
          final body = jsonDecode(request.body);
          expect(body['actionId'], 'act_budget_99');
          return http.Response(
            jsonEncode({
              'success': true,
              'summary': "Budget for 'Food' successfully set to ৳5000.00/month.",
              'auditLogId': 'log_abc_123',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
        tokenProvider: ({forceRefresh = false}) async => 'valid_token',
      );

      final result = await service.confirm("act_budget_99");

      result.fold(
        (f) => fail("Should have succeeded but failed with: ${f.message}"),
        (data) {
          expect(data['success'], isTrue);
          expect(data['summary'], contains("Food"));
          expect(data['auditLogId'], 'log_abc_123');
        },
      );
    });

    test('Cancel sends actionId to /api/cancel and returns success', () async {
      final service = AgentService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/cancel');
          final body = jsonDecode(request.body);
          expect(body['actionId'], 'act_cancel_456');
          return http.Response(jsonEncode({'success': true}), 200);
        }),
        tokenProvider: ({forceRefresh = false}) async => 'valid_token',
      );

      final result = await service.cancel("act_cancel_456");

      expect(result.isRight(), isTrue);
      result.fold(
        (f) => fail("Should have succeeded"),
        (data) => expect(data['success'], isTrue),
      );
    });
  });
}
