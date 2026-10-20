import 'package:flutter/material.dart';

class AppErrorMessage extends StatelessWidget {
  const AppErrorMessage({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
    
      children: [
        const Icon(Icons.error, color: Colors.red),
        Text(message, style: const TextStyle(color: Colors.red)),
      ],
    );
  }
}
