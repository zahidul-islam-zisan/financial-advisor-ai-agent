import 'package:flutter/material.dart';

class EmptyListWidget extends StatelessWidget {
  final String? header;
  final String? message;
  const EmptyListWidget({super.key, this.header, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 50, color: Colors.grey),
          SizedBox(height: 10),
          Text(
            header ?? "",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          Text(
            message ?? "",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
