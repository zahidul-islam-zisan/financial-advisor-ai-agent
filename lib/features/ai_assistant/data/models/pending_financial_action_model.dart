import 'package:cloud_firestore/cloud_firestore.dart';

class PendingFinancialActionModel {
  final String id;
  final String uid;
  final String docId;
  final String actionType;
  final String title;
  final Map<String, dynamic> parameters;
  final String status; // 'PENDING', 'CONFIRMED', 'REJECTED', 'EXPIRED'
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? executedAt;
  final String? auditLogId;

  PendingFinancialActionModel({
    required this.id,
    required this.uid,
    required this.docId,
    required this.actionType,
    required this.title,
    required this.parameters,
    this.status = 'PENDING',
    required this.createdAt,
    required this.expiresAt,
    this.executedAt,
    this.auditLogId,
  });

  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isRejected => status == 'REJECTED';
  bool get isExpired =>
      status == 'EXPIRED' || DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'docId': docId,
      'actionType': actionType,
      'title': title,
      'parameters': parameters,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      if (executedAt != null) 'executedAt': Timestamp.fromDate(executedAt!),
      if (auditLogId != null) 'auditLogId': auditLogId,
    };
  }

  factory PendingFinancialActionModel.fromJson(
    String id,
    Map<String, dynamic> json,
  ) {
    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return PendingFinancialActionModel(
      id: id,
      uid: json['uid'] as String? ?? '',
      docId: json['docId'] as String? ?? '',
      actionType: json['actionType'] as String? ?? '',
      title: json['title'] as String? ?? '',
      parameters: Map<String, dynamic>.from(json['parameters'] as Map? ?? {}),
      status: json['status'] as String? ?? 'PENDING',
      createdAt: parseTime(json['createdAt']),
      expiresAt: parseTime(json['expiresAt']),
      executedAt:
          json['executedAt'] != null ? parseTime(json['executedAt']) : null,
      auditLogId: json['auditLogId'] as String?,
    );
  }

  PendingFinancialActionModel copyWith({
    String? id,
    String? uid,
    String? docId,
    String? actionType,
    String? title,
    Map<String, dynamic>? parameters,
    String? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? executedAt,
    String? auditLogId,
  }) {
    return PendingFinancialActionModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      docId: docId ?? this.docId,
      actionType: actionType ?? this.actionType,
      title: title ?? this.title,
      parameters: parameters ?? this.parameters,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      executedAt: executedAt ?? this.executedAt,
      auditLogId: auditLogId ?? this.auditLogId,
    );
  }
}
