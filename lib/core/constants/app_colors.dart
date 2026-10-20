import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2CB978);
  static const Color primaryLight = Color(0xFF63D398);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textLight = Color(0xFFF8FAFC);
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color grey = Colors.grey;
  static const Color red = Colors.red;

  // Gradient Colors
  static const Color bgGradientStart = Color.fromARGB(255, 9, 8, 28);
  static const Color bgGradientEnd = Color.fromARGB(255, 12, 11, 45);
  static const Color gridColor = Color(0x0DFFFFFF); // Subtle white grid

  static const Color grey600 = Color(0xFF606060);

  static BoxShadow boxShadowColor = BoxShadow(
    color: AppColors.black.withAlpha(20),
    blurRadius: 2,
    offset: Offset(0, 0),
  );
}
