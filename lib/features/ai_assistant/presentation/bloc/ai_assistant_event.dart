import 'package:flutter/foundation.dart';

@immutable
abstract class AiAssistantEvent {}

class SendAiMessageEvent extends AiAssistantEvent {
  final String prompt;
  SendAiMessageEvent(this.prompt);
}

class LoadFinancialContextEvent extends AiAssistantEvent {}

class ClearChatEvent extends AiAssistantEvent {}

class UpdateApiKey extends AiAssistantEvent {
  final String apiKey;
  UpdateApiKey(this.apiKey);
}

class ConfirmPendingActionEvent extends AiAssistantEvent {
  final String actionId;
  ConfirmPendingActionEvent(this.actionId);
}

class RejectPendingActionEvent extends AiAssistantEvent {
  final String actionId;
  RejectPendingActionEvent(this.actionId);
}
