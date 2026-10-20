import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateTimeUtils {
  /// Formats DateTime to 'yyyy-MM-dd' for database storage
  static String formatToDateString(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Formats TimeOfDay to 'HH:mm' for database storage
  static String formatToTimeString(TimeOfDay time) {
    return DateFormat(
      'HH:mm',
    ).format(DateTime(0, 0, 0, time.hour, time.minute));
  }

  /// Parses 'HH:mm' string back to TimeOfDay
  static TimeOfDay parseTimeString(String timeString) {
    try {
      final dateTime = DateFormat('HH:mm').parse(timeString);
      return TimeOfDay.fromDateTime(dateTime);
    } catch (e) {
      // Fallback for legacy format or unexpected strings
      try {
        final dateTime = DateFormat('h:mm a').parse(timeString);
        return TimeOfDay.fromDateTime(dateTime);
      } catch (_) {
        return TimeOfDay.now();
      }
    }
  }

  /// Formats 'HH:mm' string to 'h:mm a' for display
  static String formatToDisplayTime(String timeString) {
    if (timeString.isEmpty) return "";
    try {
      // Try parsing from 24h format
      final dateTime = DateFormat('HH:mm').parse(timeString);
      return DateFormat('h:mm a').format(dateTime);
    } catch (e) {
      // If already in 12h format or something else, return as is or try to reformat
      return timeString;
    }
  }

  /// Formats DateTime to 'dd MMM, yyyy' for display
  static String formatToDisplayDate(DateTime date) {
    return DateFormat('dd MMM, yyyy').format(date);
  }
}
