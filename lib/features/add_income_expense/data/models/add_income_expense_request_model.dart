import 'package:cloud_firestore/cloud_firestore.dart';

class AddIncomeExpenseRequestModel {
  String? id;
  String date;
  String time;
  double amount;
  String description;
  String categoryId;
  String categoryName;
  bool isIncome;
  final Timestamp createdAt;

  AddIncomeExpenseRequestModel({
    this.id,
    required this.date,
    required this.time,
    required this.amount,
    required this.description,
    required this.categoryId,
    required this.categoryName,
    required this.isIncome,
    required this.createdAt,
  });

  factory AddIncomeExpenseRequestModel.fromJson(
    String id,
    Map<String, dynamic> json,
  ) {
    return AddIncomeExpenseRequestModel(
      id: id,
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : (double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0),
      description: json['description'] ?? '',
      categoryId: json['category_id'] ?? json['categoryId'] ?? '',
      categoryName: json['category_name'] ?? json['categoryName'] ?? '',
      isIncome: json['isIncome'] ?? false,
      createdAt: json['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "date": date,
      "time": time,
      "amount": amount,
      "description": description,
      "category_id": categoryId,
      "category_name": categoryName,
      "isIncome": isIncome,
      "createdAt": createdAt,
    };
  }

  AddIncomeExpenseRequestModel copyWith({
    String? id,
    String? date,
    String? time,
    double? amount,
    String? description,
    String? categoryId,
    String? categoryName,
    bool? isIncome,
    Timestamp? createdAt,
  }) {
    return AddIncomeExpenseRequestModel(
      id: id ?? this.id,
      date: date ?? this.date,
      time: time ?? this.time,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      isIncome: isIncome ?? this.isIncome,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
