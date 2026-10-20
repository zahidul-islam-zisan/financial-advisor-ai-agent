import 'package:cloud_firestore/cloud_firestore.dart';




class TransactionListResponseModel {
  final String? id;
  final num amount;
  final String categoryId;
  final String categoryName;
  final Timestamp createdAt;
  final String date;
  final String ?description;
  final bool isIncome;
  final String time;

  TransactionListResponseModel({
    this.id,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.createdAt,
    required this.date,
    required this.description,
    required this.isIncome,
    required this.time,
  });

  factory TransactionListResponseModel.fromJson(
    String id,
    Map<String, dynamic> json,
  ) {
    return TransactionListResponseModel(
      id: id,
      amount: json['amount'] ?? 0,
      categoryId: json['category_id'] ?? '',
      categoryName: json['category_name'] ?? '',
      createdAt: json['createdAt'] ?? Timestamp.now(),
      date: json['date'] ?? '',
      description: json['description'] ?? '',
      isIncome: json['isIncome'] ?? false,
      time: json['time'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "amount": amount,
      "category_id": categoryId,
      "category_name": categoryName,
      "createdAt": createdAt,
      "date": date,
      "description": description,
      "isIncome": isIncome,
      "time": time,
    };
  }

  @override
  String toString() {
    return '''
TransactionListResponseModel(
  id: $id,
  amount: $amount,
  categoryId: $categoryId,
  categoryName: $categoryName,
  createdAt: $createdAt,
  date: $date,
  description: $description,
  isIncome: $isIncome,
  time: $time
)
''';
  }
}
