import 'dart:developer';
import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/services/agent_service.dart';
import '../models/ai_message_model.dart';
import '../models/pending_financial_action_model.dart';
import 'agent_action_data_source.dart';

class AgentResponseResult {
  final String text;
  final PendingFinancialActionModel? pendingAction;
  final bool isOffline;

  AgentResponseResult({
    required this.text,
    this.pendingAction,
    this.isOffline = false,
  });
}

class AiRemoteDataSource {
  final AgentService _agentService;
  final AgentActionDataSource _actionDataSource;

  AiRemoteDataSource({
    AgentService? agentService,
    AgentActionDataSource? actionDataSource,
  })  : _agentService = agentService ?? AgentService(),
        _actionDataSource = actionDataSource ?? AgentActionDataSource();

  /// Sends user message to the secure Vercel agent-api backend.
  /// Falls back to deterministic offline rule engine if network request fails.
  Future<Either<Failure, AgentResponseResult>> sendMessage({
    required String prompt,
    required List<AiMessageModel> history,
    String? financialContext,
    String? customApiKey,
  }) async {
    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty) {
      return Left(Failure("Message cannot be empty."));
    }

    // Prepare history payload for serverless agent
    final validHistory = history
        .where((m) => !m.isLoading && !m.isError && m.text.isNotEmpty)
        .toList();

    final recentHistory = validHistory.length > 10
        ? validHistory.sublist(validHistory.length - 10)
        : validHistory;

    final historyPayload = recentHistory.map((m) {
      return {
        'text': m.text,
        'isUser': m.isUser,
      };
    }).toList();

    // Call AgentService (POST /api/chat)
    final result = await _agentService.sendMessage(
      message: trimmedPrompt,
      history: historyPayload,
    );

    return result.fold(
      (failure) async {
        log("AgentService request failed: ${failure.message}. Falling back to offline rule engine.");

        // If the error indicates authentication failure, return it directly so the user can log in
        if (failure.message.toLowerCase().contains("log in")) {
          return Left(failure);
        }

        // Otherwise, fall back to the deterministic offline rule engine
        final offlineResult = await _generateOfflineResponse(
          prompt: trimmedPrompt,
          financialContext: financialContext,
          networkError: true,
        );
        return Right(offlineResult);
      },
      (data) {
        final reply = data['reply'] as String? ?? '';
        final isOffline = data['isOffline'] == true;
        final pendingActionJson = data['pendingAction'] as Map<String, dynamic>?;

        PendingFinancialActionModel? pendingAction;
        if (pendingActionJson != null && pendingActionJson['id'] != null) {
          pendingAction = PendingFinancialActionModel.fromJson(
            pendingActionJson['id'] as String,
            pendingActionJson,
          );
        }

        return Right(AgentResponseResult(
          text: reply,
          pendingAction: pendingAction,
          isOffline: isOffline,
        ));
      },
    );
  }

  /// Deterministic offline rule engine: reads local transactions to provide calculations
  /// without attempting any client-side Firestore writes.
  Future<AgentResponseResult> _generateOfflineResponse({
    required String prompt,
    String? financialContext,
    bool networkError = false,
  }) async {
    final lower = prompt.toLowerCase();
    final buffer = StringBuffer();

    if (networkError) {
      buffer.writeln("⚠️ *Offline Mode: Running local analysis engine.*\n");
    } else {
      buffer.writeln("🤖 **Pulse AI (Offline Mode)**\n");
    }

    // 1. Unusual Spending Detection
    if (lower.contains("unusual") ||
        lower.contains("spike") ||
        lower.contains("anomaly") ||
        lower.contains("anomalies")) {
      final res = await _actionDataSource.findUnusualSpending();
      res.fold(
        (f) => buffer.writeln("Could not scan transactions: ${f.message}"),
        (anomalies) {
          if (anomalies.isEmpty) {
            buffer.writeln("✅ **Spending Health Check:**");
            buffer.writeln("No unusual spending spikes found. Your spending is consistent with historical category averages.");
          } else {
            buffer.writeln("⚠️ **Detected Unusual Spending Spikes:**");
            for (var a in anomalies) {
              buffer.writeln("• **${a['category']}** on ${a['date']}: ৳${(a['amount'] as num).toDouble().toStringAsFixed(2)} (${a['reason']})");
            }
          }
        },
      );
    }
    // 2. Budget or Goal Inquiries while offline
    else if (lower.contains("budget") || lower.contains("save") || lower.contains("goal")) {
      buffer.writeln("💡 **Budget & Savings Suggestion:**");
      buffer.writeln("To establish new monthly budgets or savings goals, an active connection to Pulse AI Agent is required so proposals can be securely authenticated.");
      buffer.writeln("\nGeneral Rule of Thumb (50/30/20):");
      buffer.writeln("• 50% Needs (housing, groceries, utilities)");
      buffer.writeln("• 30% Wants (dining, hobbies, shopping)");
      buffer.writeln("• 20% Savings (emergency fund, investments)");
    }
    // 3. Default: Monthly Financial Summary
    else {
      final res = await _actionDataSource.getSummary();
      res.fold(
        (f) => buffer.writeln("Could not calculate summary: ${f.message}"),
        (data) {
          buffer.writeln("📊 **Current Month Snapshot (${data['month']}):**");
          buffer.writeln("• **Total Income:** ৳${(data['totalIncome'] as double).toStringAsFixed(2)}");
          buffer.writeln("• **Total Expenses:** ৳${(data['totalExpense'] as double).toStringAsFixed(2)}");
          buffer.writeln("• **Net Balance:** ৳${(data['netSavings'] as double).toStringAsFixed(2)} (${(data['savingsRate'] as double).toStringAsFixed(1)}% savings rate)");

          final breakdown = data['categoryBreakdown'] as Map<String, double>?;
          if (breakdown != null && breakdown.isNotEmpty) {
            buffer.writeln("\n**Category Breakdown:**");
            breakdown.forEach((cat, amt) {
              buffer.writeln("• $cat: ৳${amt.toStringAsFixed(2)}");
            });
          }
        },
      );
    }

    buffer.writeln("\n*This is a suggestion, not professional financial advice.*");

    return AgentResponseResult(
      text: buffer.toString(),
      pendingAction: null,
      isOffline: true,
    );
  }
}
