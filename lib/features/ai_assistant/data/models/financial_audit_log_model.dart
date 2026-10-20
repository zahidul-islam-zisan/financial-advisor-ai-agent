import 'package:cloud_firestore/cloud_firestore.dart';

class FinancialAuditLogModel {
  final String id;
  final String uid;
  final String docId;
  final String actionId;
  final String actionType;
  final String status; // 'SUCCESS', 'REJECTED', 'FAILED'
  final String summary;
  final Map<String, dynamic> details;
  final DateTime timestamp;

  FinancialAuditLogModel({
    required this.id,
    required this.uid,
    required this.docId,
    required this.actionId,
    required this.actionType,
    required this.status,
    required this.summary,
    required this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'docId': docId,
      'actionId': actionId,
      'actionType': actionType,
      'status': status,
      'summary': summary,
      'details': details,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory FinancialAuditLogModel.fromJson(
    String id,
    Map<String, dynamic> json,
  ) {
    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return FinancialAuditLogModel(
      id: id,
      uid: json['uid'] as String? ?? '',
      docId: json['docId'] as String? ?? '',
      actionId: json['actionId'] as String? ?? '',
      actionType: json['actionType'] as String? ?? '',
      status: json['status'] as String? ?? 'SUCCESS',
      summary: json['summary'] as String? ?? '',
      details: Map<String, dynamic>.from(json['details'] as Map? ?? {}),
      timestamp: parseTime(json['timestamp']),
    );
  }
}
