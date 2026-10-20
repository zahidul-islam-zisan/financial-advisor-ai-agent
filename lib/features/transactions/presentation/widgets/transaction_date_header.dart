import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';

class TransactionDateHeader extends StatelessWidget {
  final DateTime date;
  final double totalAmount; // Total for that day, can be calculated

  const TransactionDateHeader({
    super.key,
    required this.date,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('d MMMM, yyyy').format(date);
    final isPositive = totalAmount >= 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            formattedDate,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Divider(
                color: AppColors.grey600.withAlpha(30),
                thickness: 1,
              ),
            ),
          ),
          Row(
            children: [
              Text(
                "Total",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Text(
                totalAmount.abs().toStringAsFixed(0),
                style: TextStyle(
                  color: isPositive
                      ? AppColors.primary
                      : AppColors.red, // Design uses specific colors for totals
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                totalAmount < 0
                    ? "-"
                    : totalAmount > 0
                    ? ""
                    : "", // show negative sign if less than 0
                style: TextStyle(
                  color: isPositive ? AppColors.primary : AppColors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),

              // Assuming input/output totals from image: "Total 5,800 0" -> this might be Income vs Expense total
              // For simplicity, implementing a single Net Total for now as simpler representation.
              // If the design requires separate totals (green and red numbers), we need to pass those in.
            ],
          ),
        ],
      ),
    );
  }
}
