import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:expense_tracker_app/core/error/failure.dart';
import 'package:expense_tracker_app/core/services/agent_service.dart';
import 'package:expense_tracker_app/features/ai_assistant/data/models/ai_message_model.dart';
import 'package:expense_tracker_app/features/ai_assistant/data/models/pending_financial_action_model.dart';
import 'package:expense_tracker_app/features/ai_assistant/presentation/bloc/ai_assistant_bloc.dart';
import 'package:expense_tracker_app/features/ai_assistant/presentation/bloc/ai_assistant_event.dart';
import 'package:expense_tracker_app/features/ai_assistant/presentation/bloc/ai_assistant_state.dart';
import 'package:expense_tracker_app/features/dashboard/data/data_sources/dashboard_remote_data_source.dart';
import 'package:expense_tracker_app/features/transactions/data/models/transaction_list_response_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeDashboardRemoteDataSource extends DashboardRemoteDataSource {
  int refreshCallCount = 0;

  @override
  Future<Either<Failure, List<TransactionListResponseModel>>> getDashboardData(String? filter) async {
    refreshCallCount++;
    return const Right([]);
  }
}

void main() {
  group('AiAssistantBloc Confirm & Cancel Flow Tests', () {
    test('ConfirmPendingActionEvent successfully confirms action, updates state, and appends confirmation message', () async {
      final fakeDashboard = FakeDashboardRemoteDataSource();
      final mockAgentService = AgentService(
        client: MockClient((request) async {
          if (request.url.path == '/api/confirm') {
            return http.Response(
              jsonEncode({
                'success': true,
                'summary': "Budget for 'Dining' successfully set to ৳4000.00/month.",
                'auditLogId': 'audit_123',
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response('{}', 404);
        }),
        tokenProvider: ({forceRefresh = false}) async => 'token',
      );

      final bloc = AiAssistantBloc(
        agentService: mockAgentService,
        dashboardRemoteDataSource: fakeDashboard,
      );

      // Seed initial state with a pending action
      final pendingAction = PendingFinancialActionModel(
        id: 'act_101',
        uid: 'user_1',
        docId: 'doc_1',
        actionType: 'CREATE_BUDGET',
        title: 'Set Monthly Budget for Dining: ৳4,000.00',
        parameters: {'category': 'Dining', 'limit': 4000.0},
        status: 'PENDING',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      );

      final messageWithAction = AiMessageModel(
        id: 'msg_proposal',
        text: 'I have prepared a proposal:',
        isUser: false,
        timestamp: DateTime.now(),
        pendingAction: pendingAction,
      );

      bloc.emit(AiAssistantState(messages: [messageWithAction]));

      final expectedStates = <AiAssistantState>[];
      bloc.stream.listen(expectedStates.add);

      bloc.add(ConfirmPendingActionEvent('act_101'));

      await untilCalled(() => fakeDashboard.refreshCallCount > 0);

      expect(expectedStates.isNotEmpty, isTrue);
      final finalState = expectedStates.last;

      expect(finalState.isLoading, isFalse);
      expect(finalState.successMessage, contains("Dining"));
      expect(finalState.operatingActionId, isNull);

      // Verify pending action in messages was updated to CONFIRMED
      final proposalMsg = finalState.messages.firstWhere((m) => m.id == 'msg_proposal');
      expect(proposalMsg.pendingAction!.status, 'CONFIRMED');

      // Verify confirmation message was appended
      expect(finalState.messages.any((m) => m.text.contains("Action Confirmed & Executed")), isTrue);

      // Verify dashboard data refresh was triggered
      expect(fakeDashboard.refreshCallCount, 1);
    });

    test('ConfirmPendingActionEvent failure emits error message and keeps action PENDING', () async {
      final mockAgentService = AgentService(
        client: MockClient((_) async => http.Response('{"error": "This action was already processed"}', 409)),
        tokenProvider: ({forceRefresh = false}) async => 'token',
      );

      final bloc = AiAssistantBloc(
        agentService: mockAgentService,
        dashboardRemoteDataSource: FakeDashboardRemoteDataSource(),
      );

      final pendingAction = PendingFinancialActionModel(
        id: 'act_102',
        uid: 'user_1',
        docId: 'doc_1',
        actionType: 'CREATE_BUDGET',
        title: 'Set Monthly Budget for Dining: ৳4,000.00',
        parameters: {'category': 'Dining', 'limit': 4000.0},
        status: 'PENDING',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      );

      bloc.emit(AiAssistantState(messages: [
        AiMessageModel(
          id: 'msg_102',
          text: 'Proposal',
          isUser: false,
          timestamp: DateTime.now(),
          pendingAction: pendingAction,
        ),
      ]));

      bloc.add(ConfirmPendingActionEvent('act_102'));

      await pumpEventQueue();

      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.errorMessage, "This action was already processed");

      // Verify action was not confirmed
      final msg = bloc.state.messages.firstWhere((m) => m.id == 'msg_102');
      expect(msg.pendingAction!.status, 'PENDING');
    });

    test('RejectPendingActionEvent cancels action and updates status to REJECTED', () async {
      final mockAgentService = AgentService(
        client: MockClient((request) async {
          if (request.url.path == '/api/cancel') {
            return http.Response(jsonEncode({'success': true}), 200);
          }
          return http.Response('{}', 404);
        }),
        tokenProvider: ({forceRefresh = false}) async => 'token',
      );

      final bloc = AiAssistantBloc(
        agentService: mockAgentService,
        dashboardRemoteDataSource: FakeDashboardRemoteDataSource(),
      );

      final pendingAction = PendingFinancialActionModel(
        id: 'act_103',
        uid: 'user_1',
        docId: 'doc_1',
        actionType: 'CREATE_SAVINGS_GOAL',
        title: 'Create Savings Goal',
        parameters: {'targetAmount': 10000.0},
        status: 'PENDING',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      );

      bloc.emit(AiAssistantState(messages: [
        AiMessageModel(
          id: 'msg_103',
          text: 'Savings Proposal',
          isUser: false,
          timestamp: DateTime.now(),
          pendingAction: pendingAction,
        ),
      ]));

      bloc.add(RejectPendingActionEvent('act_103'));

      await pumpEventQueue();

      expect(bloc.state.isLoading, isFalse);
      final msg = bloc.state.messages.firstWhere((m) => m.id == 'msg_103');
      expect(msg.pendingAction!.status, 'REJECTED');
      expect(bloc.state.messages.any((m) => m.text.contains("cancelled")), isTrue);
    });
  });
}

Future<void> untilCalled(bool Function() condition, {int timeoutMs = 1000}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition()) {
    await Future.delayed(const Duration(milliseconds: 20));
    if (stopwatch.elapsedMilliseconds > timeoutMs) {
      fail("Timed out waiting for condition");
    }
  }
}
