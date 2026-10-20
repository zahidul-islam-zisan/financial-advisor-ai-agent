import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryAddRequestModel {
  final String? id;
  final String name;
  final Timestamp createdAt;

  CategoryAddRequestModel({
    this.id,
    required this.name,
    required this.createdAt,
  });

  factory CategoryAddRequestModel.fromJson(String id, Map<String, dynamic> json) {
    return CategoryAddRequestModel(
      id: id,
      name: json['name'],
      createdAt: json['createdAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "createdAt": createdAt,
    };
  }
}
