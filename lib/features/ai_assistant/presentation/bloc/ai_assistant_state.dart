import 'package:flutter/foundation.dart';
import '../../data/models/ai_message_model.dart';

@immutable
class AiAssistantState {
  final List<AiMessageModel> messages;
  final bool isLoading;
  final String? errorMessage;
  final String? financialContext;
  final String apiKey;

  const AiAssistantState({
    required this.messages,
    this.isLoading = false,
    this.errorMessage,
    this.financialContext,
    this.apiKey = '',
  });

  factory AiAssistantState.initial() {
    return AiAssistantState(
      messages: [
        AiMessageModel(
          id: 'welcome_1',
          text:
              "👋 Hi! I am **Pulse AI**, your personal financial assistant.\n\nAsk me anything about budgeting, saving money, analyzing your recent transactions, or reducing expenses!",
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ],
      isLoading: false,
      financialContext: null,
      apiKey: '',
    );
  }

  AiAssistantState copyWith({
    List<AiMessageModel>? messages,
    bool? isLoading,
    String? errorMessage,
    String? financialContext,
    String? apiKey,
  }) {
    return AiAssistantState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      financialContext: financialContext ?? this.financialContext,
      apiKey: apiKey ?? this.apiKey,
    );
  }
}
