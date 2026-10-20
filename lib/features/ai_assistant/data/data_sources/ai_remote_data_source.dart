import 'dart:convert';
import 'dart:developer';
import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/ai_config.dart';
import '../../../../core/error/failure.dart';
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
  final AgentActionDataSource _actionDataSource = AgentActionDataSource();

  // Tool definitions for Gemini 2.5 Flash Function Calling
  static final List<Map<String, dynamic>> _agentTools = [
    {
      "function_declarations": [
        {
          "name": "get_summary",
          "description": "Calculates total income, total expenses, net savings, savings rate, and category spending breakdown for a specific month.",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "month": {
                "type": "STRING",
                "description": "The month in YYYY-MM format, e.g. '2026-10'. Leave blank for current month."
              }
            }
          }
        },
        {
          "name": "get_transactions",
          "description": "Retrieves recent transactions recorded by the user.",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "limit": {
                "type": "INTEGER",
                "description": "Number of transactions to return (default 10)"
              }
            }
          }
        },
        {
          "name": "find_unusual_spending",
          "description": "Scans expenses and detects transactions that are unusually high or spike above category averages.",
          "parameters": {
            "type": "OBJECT",
            "properties": {}
          }
        },
        {
          "name": "create_budget",
          "description": "Proposes setting a monthly spending limit for a specific category. Requires user confirmation before execution.",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "category": {
                "type": "STRING",
                "description": "Category name to budget (e.g., Food, Dining, Shopping, Utilities)"
              },
              "limit": {
                "type": "NUMBER",
                "description": "Monthly limit amount in dollars (must be greater than 0)"
              }
            },
            "required": ["category", "limit"]
          }
        },
        {
          "name": "create_savings_goal",
          "description": "Proposes creating a savings goal over a period of months. Requires user confirmation before execution.",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "goalName": {
                "type": "STRING",
                "description": "Name or purpose of the savings goal (e.g., Emergency Fund, New Laptop)"
              },
              "targetAmount": {
                "type": "NUMBER",
                "description": "Total amount to save in dollars (must be greater than 0)"
              },
              "targetMonths": {
                "type": "INTEGER",
                "description": "Number of months to achieve goal (1 to 120)"
              }
            },
            "required": ["targetAmount", "targetMonths"]
          }
        }
      ]
    }
  ];

  Future<Either<Failure, AgentResponseResult>> sendMessage({
    required String prompt,
    required List<AiMessageModel> history,
    String? financialContext,
    String? customApiKey,
  }) async {
    final apiKey = (customApiKey != null && customApiKey.trim().isNotEmpty)
        ? customApiKey.trim()
        : AiConfig.activeApiKey.trim();

    // If no API key is provided, execute deterministic offline rule engine
    if (apiKey.isEmpty || apiKey == "YOUR_GEMINI_API_KEY_HERE") {
      final offlineResult = await _generateOfflineResponse(
        prompt: prompt,
        financialContext: financialContext,
      );
      return Right(offlineResult);
    }

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/${AiConfig.modelName}:generateContent?key=$apiKey',
      );

      final List<Map<String, dynamic>> contents = [];

      final validHistory = history
          .where((m) => !m.isLoading && !m.isError && m.text.isNotEmpty)
          .toList();

      final recentHistory = validHistory.length > 8
          ? validHistory.sublist(validHistory.length - 8)
          : validHistory;

      for (var msg in recentHistory) {
        contents.add({
          "role": msg.isUser ? "user" : "model",
          "parts": [
            {"text": msg.text}
          ],
        });
      }

      contents.add({
        "role": "user",
        "parts": [
          {"text": prompt}
        ],
      });

      String systemPrompt = AiConfig.systemInstruction;
      if (financialContext != null && financialContext.trim().isNotEmpty) {
        systemPrompt += "\n\n--- USER SNAPSHOT ---\n$financialContext\n---------------------";
      }

      final initialRequestBody = jsonEncode({
        "system_instruction": {
          "parts": [
            {"text": systemPrompt}
          ]
        },
        "contents": contents,
        "tools": _agentTools,
        "generationConfig": {
          "temperature": 0.4,
          "maxOutputTokens": 1024,
        },
      });

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: initialRequestBody,
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final candidates = responseData['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final candidate = candidates[0];
          final content = candidate['content'];
          final parts = content['parts'] as List?;

          if (parts != null && parts.isNotEmpty) {
            // Check if Gemini invoked a tool / functionCall
            Map<String, dynamic>? functionCallPart;
            String? directText;

            for (var p in parts) {
              if (p is Map<String, dynamic>) {
                if (p.containsKey('functionCall')) {
                  functionCallPart = p['functionCall'] as Map<String, dynamic>;
                } else if (p.containsKey('text')) {
                  directText = p['text'] as String;
                }
              }
            }

            // If a tool function call was made:
            if (functionCallPart != null) {
              return await _handleFunctionCall(
                functionCall: functionCallPart,
                contents: contents,
                systemPrompt: systemPrompt,
                apiKey: apiKey,
              );
            }

            // Otherwise, direct text answer
            if (directText != null && directText.trim().isNotEmpty) {
              return Right(AgentResponseResult(text: directText.trim(), isOffline: false));
            }
          }
        }
        return Right(AgentResponseResult(
          text: "I analyzed your request, but could not produce a response. Please try again.",
          isOffline: false,
        ));
      } else if (response.statusCode == 400 || response.statusCode == 403) {
        log("Gemini API Key authorization issue (${response.statusCode}): ${response.body}");
        final offlineResult = await _generateOfflineResponse(
          prompt: prompt,
          financialContext: financialContext,
          apiKeyError: true,
        );
        return Right(offlineResult);
      } else {
        log("Gemini error status ${response.statusCode}: ${response.body}");
        final offlineResult = await _generateOfflineResponse(
          prompt: prompt,
          financialContext: financialContext,
          networkError: true,
        );
        return Right(offlineResult);
      }
    } catch (e) {
      log("Error contacting Gemini API: $e. Falling back to deterministic rule engine.");
      final offlineResult = await _generateOfflineResponse(
        prompt: prompt,
        financialContext: financialContext,
        networkError: true,
      );
      return Right(offlineResult);
    }
  }

  /// Executes approved tool deterministically and returns human explanation with any pending action
  Future<Either<Failure, AgentResponseResult>> _handleFunctionCall({
    required Map<String, dynamic> functionCall,
    required List<Map<String, dynamic>> contents,
    required String systemPrompt,
    required String apiKey,
  }) async {
    final name = functionCall['name'] as String;
    final args = Map<String, dynamic>.from(functionCall['args'] as Map? ?? {});
    log("Executing agent tool: $name with args: $args");

    Map<String, dynamic> toolResult = {};
    PendingFinancialActionModel? pendingAction;
    String fallbackExplanation = "";

    try {
      if (name == 'get_summary') {
        final res = await _actionDataSource.getSummary(month: args['month'] as String?);
        res.fold(
          (f) => toolResult = {'error': f.message},
          (data) {
            toolResult = data;
            fallbackExplanation = "📊 **Monthly Financial Summary (${data['month']}):**\n"
                "• **Total Income:** \$${(data['totalIncome'] as double).toStringAsFixed(2)}\n"
                "• **Total Expenses:** \$${(data['totalExpense'] as double).toStringAsFixed(2)}\n"
                "• **Net Savings:** \$${(data['netSavings'] as double).toStringAsFixed(2)} (${(data['savingsRate'] as double).toStringAsFixed(1)}% savings rate)\n"
                "• **Transactions:** ${data['transactionCount']} logged this month.";
          },
        );
      } else if (name == 'get_transactions') {
        final limit = (args['limit'] as num?)?.toInt() ?? 10;
        final res = await _actionDataSource.getTransactions(limit: limit);
        res.fold(
          (f) => toolResult = {'error': f.message},
          (data) {
            toolResult = {'transactions': data};
            final buffer = StringBuffer("📋 **Recent Transactions:**\n");
            for (var t in data.take(5)) {
              final type = t['isIncome'] == true ? 'Income' : 'Expense';
              buffer.writeln("• ${t['date']}: [$type] ${t['categoryName']} - \$${t['amount']} (${t['description'] ?? ''})");
            }
            fallbackExplanation = buffer.toString();
          },
        );
      } else if (name == 'find_unusual_spending') {
        final res = await _actionDataSource.findUnusualSpending();
        res.fold(
          (f) => toolResult = {'error': f.message},
          (anomalies) {
            toolResult = {'anomalies': anomalies};
            if (anomalies.isEmpty) {
              fallbackExplanation = "✅ **No unusual spending spikes detected!** Your spending patterns appear consistent with your category averages.";
            } else {
              final buffer = StringBuffer("⚠️ **Detected Unusual Spending Spikes:**\n");
              for (var a in anomalies) {
                buffer.writeln("• **${a['category']}** on ${a['date']}: \$${a['amount']} (${a['reason']})");
              }
              fallbackExplanation = buffer.toString();
            }
          },
        );
      } else if (name == 'create_budget') {
        final category = args['category'] as String? ?? 'General';
        final limit = (args['limit'] as num?)?.toDouble() ?? 0.0;
        final res = await _actionDataSource.proposeBudget(category: category, limit: limit);
        res.fold(
          (f) => toolResult = {'error': f.message},
          (action) {
            pendingAction = action;
            toolResult = {
              'status': 'PROPOSED',
              'actionId': action.id,
              'category': category,
              'limit': limit,
              'message': 'Budget proposal created. Awaiting human confirmation.',
            };
            fallbackExplanation = "I have prepared a proposal to set a monthly budget for **$category** at **\$${limit.toStringAsFixed(2)}**.\n\nPlease review and confirm below before this takes effect.";
          },
        );
      } else if (name == 'create_savings_goal') {
        final goalName = args['goalName'] as String? ?? 'Savings Goal';
        final targetAmount = (args['targetAmount'] as num?)?.toDouble() ?? 0.0;
        final targetMonths = (args['targetMonths'] as num?)?.toInt() ?? 12;
        final res = await _actionDataSource.proposeSavingsGoal(
          goalName: goalName,
          targetAmount: targetAmount,
          targetMonths: targetMonths,
        );
        res.fold(
          (f) => toolResult = {'error': f.message},
          (action) {
            pendingAction = action;
            final monthly = targetAmount / targetMonths;
            toolResult = {
              'status': 'PROPOSED',
              'actionId': action.id,
              'goalName': goalName,
              'targetAmount': targetAmount,
              'targetMonths': targetMonths,
              'monthlyContribution': monthly,
              'message': 'Savings goal proposal created. Awaiting human confirmation.',
            };
            fallbackExplanation = "I have prepared a proposal for your savings goal: **$goalName** (\$${targetAmount.toStringAsFixed(2)} over $targetMonths months — **\$${monthly.toStringAsFixed(2)}/month**).\n\nPlease review and confirm below to add this goal.";
          },
        );
      } else {
        toolResult = {'error': 'Unknown tool: $name'};
      }
    } catch (e) {
      log("Error executing tool $name: $e");
      toolResult = {'error': e.toString()};
    }

    // Now request Gemini to synthesize the natural response with toolResult
    try {
      final followUpUrl = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/${AiConfig.modelName}:generateContent?key=$apiKey',
      );

      final updatedContents = List<Map<String, dynamic>>.from(contents);
      updatedContents.add({
        "role": "model",
        "parts": [
          {
            "functionCall": {
              "name": name,
              "args": args,
            }
          }
        ]
      });

      updatedContents.add({
        "role": "function",
        "parts": [
          {
            "functionResponse": {
              "name": name,
              "response": {"name": name, "content": toolResult}
            }
          }
        ]
      });

      final followUpBody = jsonEncode({
        "system_instruction": {
          "parts": [
            {"text": systemPrompt}
          ]
        },
        "contents": updatedContents,
        "generationConfig": {
          "temperature": 0.4,
          "maxOutputTokens": 1024,
        },
      });

      final followUpResponse = await http
          .post(
            followUpUrl,
            headers: {'Content-Type': 'application/json'},
            body: followUpBody,
          )
          .timeout(const Duration(seconds: 20));

      if (followUpResponse.statusCode == 200) {
        final decoded = jsonDecode(followUpResponse.body);
        final candidates = decoded['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text'] as String?;
            if (text != null && text.trim().isNotEmpty) {
              return Right(AgentResponseResult(
                text: text.trim(),
                pendingAction: pendingAction,
                isOffline: false,
              ));
            }
          }
        }
      }
    } catch (followUpErr) {
      log("Warning in tool follow-up synthesis: $followUpErr. Using fallback explanation.");
    }

    return Right(AgentResponseResult(
      text: fallbackExplanation.isNotEmpty ? fallbackExplanation : "Executed tool $name successfully.",
      pendingAction: pendingAction,
      isOffline: false,
    ));
  }

  /// Deterministic offline rule engine that guarantees functional tools even without Gemini API
  Future<AgentResponseResult> _generateOfflineResponse({
    required String prompt,
    String? financialContext,
    bool networkError = false,
    bool apiKeyError = false,
  }) async {
    final lower = prompt.toLowerCase();
    PendingFinancialActionModel? pendingAction;
    final buffer = StringBuffer();

    if (networkError) {
      buffer.writeln("⚠️ *Network disconnected. Running deterministic offline engine.*\n");
    } else if (apiKeyError) {
      buffer.writeln("🔑 *Gemini API key is unconfigured. Running deterministic offline engine.*\n");
    } else {
      buffer.writeln("🤖 **Pulse AI (Deterministic Offline Engine)**\n");
    }

    // 1. Tool Trigger: Budget Proposal
    if (lower.contains("budget") && (lower.contains("set") || lower.contains("create") || lower.contains("limit") || lower.contains("plan"))) {
      final numbers = RegExp(r'\d+(\.\d+)?').allMatches(lower).map((m) => double.tryParse(m.group(0) ?? '')).whereType<double>().toList();
      final limit = numbers.isNotEmpty ? numbers.first : 300.0;
      String category = "Dining & Food";

      if (lower.contains("grocer")) {
        category = "Groceries";
      } else if (lower.contains("shop")) {
        category = "Shopping";
      } else if (lower.contains("transport") || lower.contains("car")) {
        category = "Transportation";
      } else if (lower.contains("entertainment")) {
        category = "Entertainment";
      }

      final res = await _actionDataSource.proposeBudget(category: category, limit: limit);
      res.fold(
        (f) => buffer.writeln("Could not create budget proposal: ${f.message}"),
        (action) {
          pendingAction = action;
          buffer.writeln("🎯 **Proposed Monthly Budget:**");
          buffer.writeln("I have prepared a proposal to cap **$category** spending at **\$${limit.toStringAsFixed(2)}/month**.");
          buffer.writeln("\n*Please confirm below to save this budget:*");
        },
      );
    }
    // 2. Tool Trigger: Savings Goal Proposal
    else if (lower.contains("goal") || (lower.contains("save") && RegExp(r'\d+').hasMatch(lower))) {
      final numbers = RegExp(r'\d+(\.\d+)?').allMatches(lower).map((m) => double.tryParse(m.group(0) ?? '')).whereType<double>().toList();
      final targetAmount = numbers.isNotEmpty ? numbers.first : 1200.0;
      final targetMonths = numbers.length > 1 ? numbers[1].toInt() : 6;
      final monthly = targetAmount / (targetMonths > 0 ? targetMonths : 1);

      final res = await _actionDataSource.proposeSavingsGoal(
        goalName: "Emergency Fund",
        targetAmount: targetAmount,
        targetMonths: targetMonths,
      );
      res.fold(
        (f) => buffer.writeln("Could not create savings goal proposal: ${f.message}"),
        (action) {
          pendingAction = action;
          buffer.writeln("💰 **Proposed Savings Goal:**");
          buffer.writeln("• **Goal:** Emergency Fund");
          buffer.writeln("• **Target:** \$${targetAmount.toStringAsFixed(2)} over $targetMonths months");
          buffer.writeln("• **Monthly Contribution:** \$${monthly.toStringAsFixed(2)}/month");
          buffer.writeln("\n*Please confirm below to establish this savings goal:*");
        },
      );
    }
    // 3. Tool Trigger: Unusual Spending Detection
    else if (lower.contains("unusual") || lower.contains("spike") || lower.contains("anomaly") || lower.contains("anomalies")) {
      final res = await _actionDataSource.findUnusualSpending();
      res.fold(
        (f) => buffer.writeln("Failed to scan expenses: ${f.message}"),
        (anomalies) {
          if (anomalies.isEmpty) {
            buffer.writeln("✅ **Spending Health Check:**");
            buffer.writeln("No unusual spending spikes found. Your spending is consistent with historical category averages.");
          } else {
            buffer.writeln("⚠️ **Detected Unusual Spending Spikes:**");
            for (var a in anomalies) {
              buffer.writeln("• **${a['category']}** on ${a['date']}: \$${a['amount']} (${a['reason']})");
            }
          }
        },
      );
    }
    // 4. Tool Trigger: Monthly Summary & Spending Breakdown
    else if (lower.contains("summary") || lower.contains("how am i") || lower.contains("spending") || lower.contains("breakdown")) {
      final res = await _actionDataSource.getSummary();
      res.fold(
        (f) => buffer.writeln("Could not fetch summary: ${f.message}"),
        (data) {
          buffer.writeln("📊 **Current Month Snapshot (${data['month']}):**");
          buffer.writeln("• **Total Income:** \$${(data['totalIncome'] as double).toStringAsFixed(2)}");
          buffer.writeln("• **Total Expenses:** \$${(data['totalExpense'] as double).toStringAsFixed(2)}");
          buffer.writeln("• **Net Balance:** \$${(data['netSavings'] as double).toStringAsFixed(2)} (${(data['savingsRate'] as double).toStringAsFixed(1)}% savings rate)");

          final breakdown = data['categoryBreakdown'] as Map<String, double>;
          if (breakdown.isNotEmpty) {
            buffer.writeln("\n**Category Breakdown:**");
            breakdown.forEach((cat, amt) {
              final pct = data['totalExpense'] > 0 ? (amt / data['totalExpense'] * 100).toStringAsFixed(1) : "0";
              buffer.writeln("• $cat: \$${amt.toStringAsFixed(2)} ($pct%)");
            });
          }
        },
      );
    }
    // 5. General Financial Principles (50/30/20 Rule, Debt Reduction, Savings Tips)
    else if (lower.contains("50/30/20")) {
      buffer.writeln("📊 **The 50/30/20 Budgeting Rule:**");
      buffer.writeln("• **50% Needs:** Housing, groceries, utilities, transportation.");
      buffer.writeln("• **30% Wants:** Dining out, entertainment, hobbies, streaming.");
      buffer.writeln("• **20% Savings:** Emergency fund, retirement, debt reduction.");
      buffer.writeln("\nAsk me: *'Set a budget for dining \$300'* to configure a category limit!");
    } else {
      buffer.writeln("💡 **Pulse AI Financial Assistant:**");
      buffer.writeln("I can help you analyze your finances and automate your budgeting:");
      buffer.writeln("• *'How am I spending my money?'* (Summary & Category Breakdown)");
      buffer.writeln("• *'Find unusual spending'* (Anomaly Detection)");
      buffer.writeln("• *'Set a monthly budget for Food 400'* (2-Step Human Confirmation)");
      buffer.writeln("• *'Create a savings goal 1000 for 5 months'* (Automated Savings Target)");
    }

    return AgentResponseResult(
      text: buffer.toString(),
      pendingAction: pendingAction,
      isOffline: true,
    );
  }
}
