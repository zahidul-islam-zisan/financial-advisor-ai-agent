import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

ThemeData appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  primaryColor: AppColors.primary,
  fontFamily: 'Poppins',
  colorScheme: ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.primaryLight,
    surface: Colors.white10,
    onSurface: Colors.white,
  ),
  scaffoldBackgroundColor: Colors.transparent,
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    scrolledUnderElevation: 0,
    iconTheme: const IconThemeData(color: Colors.white),
    titleTextStyle: const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 18,
      color: Colors.white,
    ),
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: Color.fromARGB(255, 9, 28, 60),
    surfaceTintColor: Color.fromARGB(255, 9, 28, 60),
  ),
  popupMenuTheme: const PopupMenuThemeData(
    color: Color.fromARGB(255, 9, 28, 60),
    surfaceTintColor: Color.fromARGB(255, 9, 28, 60),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Color.fromARGB(255, 9, 28, 60),
    surfaceTintColor: Color.fromARGB(255, 9, 28, 60),
  ),
  datePickerTheme: const DatePickerThemeData(
    backgroundColor: Color.fromARGB(255, 9, 28, 60),
    surfaceTintColor: Colors.transparent,
  ),
  timePickerTheme: const TimePickerThemeData(backgroundColor: Colors.black),
  cardTheme: CardThemeData(
    color: AppColors.primary.withOpacity(0.1),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
      side: BorderSide(color: AppColors.primary.withOpacity(0.2), width: 1),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.grey;
        }
        return AppColors.primary;
      }),
      foregroundColor: const WidgetStatePropertyAll(Colors.white),
      fixedSize: const WidgetStatePropertyAll(Size(double.maxFinite, 50)),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      ),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
    ),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.white),
    bodyMedium: TextStyle(color: Colors.white),
    titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
  ),
);
