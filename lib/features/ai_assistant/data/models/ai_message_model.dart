import 'pending_financial_action_model.dart';

class AiMessageModel {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final bool isLoading;
  final bool isOffline;
  final PendingFinancialActionModel? pendingAction;

  AiMessageModel({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.isLoading = false,
    this.isOffline = false,
    this.pendingAction,
  });

  AiMessageModel copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    bool? isError,
    bool? isLoading,
    bool? isOffline,
    PendingFinancialActionModel? pendingAction,
  }) {
    return AiMessageModel(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      isError: isError ?? this.isError,
      isLoading: isLoading ?? this.isLoading,
      isOffline: isOffline ?? this.isOffline,
      pendingAction: pendingAction ?? this.pendingAction,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'isError': isError,
      'isLoading': isLoading,
      'isOffline': isOffline,
      if (pendingAction != null) 'pendingAction': pendingAction!.toJson(),
    };
  }

  factory AiMessageModel.fromJson(Map<String, dynamic> json) {
    return AiMessageModel(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isError: json['isError'] as bool? ?? false,
      isLoading: json['isLoading'] as bool? ?? false,
      isOffline: json['isOffline'] as bool? ?? false,
      pendingAction: json['pendingAction'] != null
          ? PendingFinancialActionModel.fromJson(
              (json['pendingAction'] as Map)['id'] as String? ?? '',
              Map<String, dynamic>.from(json['pendingAction'] as Map),
            )
          : null,
    );
  }
}
