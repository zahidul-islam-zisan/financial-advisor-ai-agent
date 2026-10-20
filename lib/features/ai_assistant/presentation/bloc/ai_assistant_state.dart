import 'package:flutter/foundation.dart';
import '../../data/models/ai_message_model.dart';

@immutable
class AiAssistantState {
  final List<AiMessageModel> messages;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final String? financialContext;
  final String? operatingActionId;
  final String apiKey;

  const AiAssistantState({
    required this.messages,
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.financialContext,
    this.operatingActionId,
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
      errorMessage: null,
      successMessage: null,
      financialContext: null,
      operatingActionId: null,
      apiKey: '',
    );
  }

  AiAssistantState copyWith({
    List<AiMessageModel>? messages,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    String? financialContext,
    String? operatingActionId,
    String? apiKey,
    bool clearOperatingAction = false,
    bool clearMessages = false,
  }) {
    return AiAssistantState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
      financialContext: financialContext ?? this.financialContext,
      operatingActionId: clearOperatingAction
          ? null
          : (operatingActionId ?? this.operatingActionId),
      apiKey: apiKey ?? this.apiKey,
    );
  }
}
