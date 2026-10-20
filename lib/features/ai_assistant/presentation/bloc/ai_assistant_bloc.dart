import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/agent_service.dart';
import '../../../dashboard/data/data_sources/dashboard_remote_data_source.dart';
import '../../data/data_sources/ai_remote_data_source.dart';
import '../../data/models/ai_message_model.dart';
import 'ai_assistant_event.dart';
import 'ai_assistant_state.dart';

class AiAssistantBloc extends Bloc<AiAssistantEvent, AiAssistantState> {
  final AiRemoteDataSource _aiRemoteDataSource;
  final AgentService _agentService;
  final DashboardRemoteDataSource? _dashboardRemoteDataSource;

  DashboardRemoteDataSource get _effectiveDashboard =>
      _dashboardRemoteDataSource ?? DashboardRemoteDataSource();

  AiAssistantBloc({
    AiRemoteDataSource? aiRemoteDataSource,
    AgentService? agentService,
    DashboardRemoteDataSource? dashboardRemoteDataSource,
  })  : _agentService = agentService ?? AgentService(),
        _aiRemoteDataSource = aiRemoteDataSource ??
            AiRemoteDataSource(agentService: agentService ?? AgentService()),
        _dashboardRemoteDataSource = dashboardRemoteDataSource,
        super(AiAssistantState.initial()) {
    on<SendAiMessageEvent>(_onSendAiMessage);
    on<LoadFinancialContextEvent>(_onLoadFinancialContext);
    on<ClearChatEvent>(_onClearChat);
    on<ConfirmPendingActionEvent>(_onConfirmPendingAction);
    on<RejectPendingActionEvent>(_onRejectPendingAction);
  }

  Future<void> _onSendAiMessage(
    SendAiMessageEvent event,
    Emitter<AiAssistantState> emit,
  ) async {
    final trimmedPrompt = event.prompt.trim();
    if (trimmedPrompt.isEmpty) return;

    final userMessage = AiMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: trimmedPrompt,
      isUser: true,
      timestamp: DateTime.now(),
    );

    final loadingMessage = AiMessageModel(
      id: 'loading_${DateTime.now().millisecondsSinceEpoch}',
      text: 'Analyzing your financial request...',
      isUser: false,
      timestamp: DateTime.now(),
      isLoading: true,
    );

    final updatedMessages = List<AiMessageModel>.from(state.messages)
      ..add(userMessage)
      ..add(loadingMessage);

    emit(
      state.copyWith(
        messages: updatedMessages,
        isLoading: true,
        errorMessage: null,
        successMessage: null,
      ),
    );

    final result = await _aiRemoteDataSource.sendMessage(
      prompt: trimmedPrompt,
      history: state.messages,
      financialContext: state.financialContext,
    );

    result.fold(
      (failure) {
        final filteredList = state.messages
            .where((msg) => msg.id != loadingMessage.id)
            .toList();

        final errorMessage = AiMessageModel(
          id: 'error_${DateTime.now().millisecondsSinceEpoch}',
          text: "⚠️ ${failure.message}",
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        );

        emit(
          state.copyWith(
            messages: [...filteredList, errorMessage],
            isLoading: false,
            errorMessage: failure.message,
          ),
        );
      },
      (agentResult) {
        final filteredList = state.messages
            .where((msg) => msg.id != loadingMessage.id)
            .toList();

        final assistantMessage = AiMessageModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: agentResult.text,
          isUser: false,
          timestamp: DateTime.now(),
          isOffline: agentResult.isOffline,
          pendingAction: agentResult.pendingAction,
        );

        emit(
          state.copyWith(
            messages: [...filteredList, assistantMessage],
            isLoading: false,
            errorMessage: null,
          ),
        );
      },
    );
  }

  Future<void> _onConfirmPendingAction(
    ConfirmPendingActionEvent event,
    Emitter<AiAssistantState> emit,
  ) async {
    emit(state.copyWith(
      isLoading: true,
      operatingActionId: event.actionId,
      errorMessage: null,
      successMessage: null,
    ));

    final result = await _agentService.confirm(event.actionId);

    await result.fold(
      (failure) async {
        final errorMsg = AiMessageModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: "❌ Confirmation Failed: ${failure.message}",
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        );
        emit(state.copyWith(
          messages: [...state.messages, errorMsg],
          isLoading: false,
          clearOperatingAction: true,
          errorMessage: failure.message,
        ));
      },
      (data) async {
        final successSummary = data['summary'] as String? ??
            "Financial action confirmed and executed.";

        // Update the message containing this pending action to show CONFIRMED
        final updatedList = state.messages.map((m) {
          if (m.pendingAction?.id == event.actionId) {
            return m.copyWith(
              pendingAction: m.pendingAction!.copyWith(status: 'CONFIRMED'),
            );
          }
          return m;
        }).toList();

        final confirmMsg = AiMessageModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              "✅ **Action Confirmed & Executed!**\n\n$successSummary\n\n*(Verified and logged via Secure Agent API)*",
          isUser: false,
          timestamp: DateTime.now(),
        );

        // Refresh dashboard data so updated budgets/goals reflect in UI
        try {
          await _effectiveDashboard.getDashboardData('Monthly');
        } catch (_) {}

        emit(state.copyWith(
          messages: [...updatedList, confirmMsg],
          isLoading: false,
          clearOperatingAction: true,
          successMessage: successSummary,
        ));
      },
    );
  }

  Future<void> _onRejectPendingAction(
    RejectPendingActionEvent event,
    Emitter<AiAssistantState> emit,
  ) async {
    emit(state.copyWith(
      isLoading: true,
      operatingActionId: event.actionId,
      errorMessage: null,
      successMessage: null,
    ));

    final result = await _agentService.cancel(event.actionId);

    result.fold(
      (failure) {
        emit(state.copyWith(
          isLoading: false,
          clearOperatingAction: true,
          errorMessage: failure.message,
        ));
      },
      (_) {
        final updatedList = state.messages.map((m) {
          if (m.pendingAction?.id == event.actionId) {
            return m.copyWith(
              pendingAction: m.pendingAction!.copyWith(status: 'REJECTED'),
            );
          }
          return m;
        }).toList();

        final cancelMsg = AiMessageModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: "🚫 Proposed action was cancelled.",
          isUser: false,
          timestamp: DateTime.now(),
        );

        emit(state.copyWith(
          messages: [...updatedList, cancelMsg],
          isLoading: false,
          clearOperatingAction: true,
          successMessage: "Action cancelled successfully.",
        ));
      },
    );
  }

  Future<void> _onLoadFinancialContext(
    LoadFinancialContextEvent event,
    Emitter<AiAssistantState> emit,
  ) async {
    try {
      final result =
          await _effectiveDashboard.getDashboardData('Monthly');
      result.fold(
        (failure) {},
        (transactions) {
          if (transactions.isEmpty) {
            emit(
              state.copyWith(
                financialContext:
                    "User has no transactions recorded yet for this month.",
              ),
            );
            return;
          }

          double totalIncome = 0;
          double totalExpense = 0;
          final Map<String, double> categoryExpenseMap = {};

          for (var t in transactions) {
            if (t.isIncome == true) {
              totalIncome += t.amount;
            } else {
              totalExpense += t.amount;
              final cat =
                  t.categoryName.isNotEmpty ? t.categoryName : 'Other';
              categoryExpenseMap[cat] =
                  (categoryExpenseMap[cat] ?? 0) + t.amount;
            }
          }

          final buffer = StringBuffer();
          buffer.writeln("Monthly Summary:");
          buffer.writeln("- Total Income: ৳${totalIncome.toStringAsFixed(2)}");
          buffer.writeln("- Total Expenses: ৳${totalExpense.toStringAsFixed(2)}");
          buffer.writeln(
              "- Net Balance: ৳${(totalIncome - totalExpense).toStringAsFixed(2)}");

          if (categoryExpenseMap.isNotEmpty) {
            buffer.writeln("\nExpense by Category:");
            categoryExpenseMap.forEach((cat, amt) {
              final pct = totalExpense > 0
                  ? (amt / totalExpense * 100).toStringAsFixed(1)
                  : "0";
              buffer.writeln("- $cat: ৳${amt.toStringAsFixed(2)} ($pct%)");
            });
          }

          final recent = transactions.take(5).toList();
          if (recent.isNotEmpty) {
            buffer.writeln("\nRecent Transactions:");
            for (var t in recent) {
              final type = t.isIncome ? "Income" : "Expense";
              buffer.writeln(
                "- ${t.date}: [$type] ${t.categoryName} - ৳${t.amount} (${t.description ?? ''})",
              );
            }
          }

          emit(state.copyWith(financialContext: buffer.toString()));
        },
      );
    } catch (_) {}
  }

  void _onClearChat(ClearChatEvent event, Emitter<AiAssistantState> emit) {
    emit(
      AiAssistantState.initial().copyWith(
        financialContext: state.financialContext,
      ),
    );
  }
}
