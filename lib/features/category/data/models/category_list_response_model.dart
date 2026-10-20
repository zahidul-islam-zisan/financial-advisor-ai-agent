import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryListResponseModel {
  final String? id;
  final String name;
  final Timestamp createdAt;

  CategoryListResponseModel({
    this.id,
    required this.name,
    required this.createdAt,
  });

  factory CategoryListResponseModel.fromJson(
    String id,
    Map<String, dynamic> json,
  ) {
    return CategoryListResponseModel(
      id: id,
      name: json['name'],
      createdAt: json['createdAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {"name": name, "createdAt": createdAt};
  }

  @override
  String toString() {
    return 'CategoryListResponseModel(id: $id, name: $name, createdAt: $createdAt)';
  }
}
