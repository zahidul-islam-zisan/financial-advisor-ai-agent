import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class MeshBackground extends StatelessWidget {
  final Widget child;

  const MeshBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Clean Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.bgGradientStart,
                  AppColors.bgGradientEnd,
                ],
              ),
            ),
          ),
          // Content
          child,
        ],
      ),
    );
  }
}
