import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/route/app_routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../data/models/transaction_list_response_model.dart';
import '../bloc/transaction_bloc.dart';

class TransactionCard extends StatelessWidget {
  final TransactionListResponseModel transaction;
  final VoidCallback? onTap;

  const TransactionCard({super.key, required this.transaction, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Determine color and sign based on transaction type
    final isIncome = transaction.isIncome;
    final amountColor = isIncome ? AppColors.primary : AppColors.red;

    // Use the pre-formatted time from the model if available, otherwise format the timestamp
    final formattedTime = transaction.time.isNotEmpty
        ? DateTimeUtils.formatToDisplayTime(transaction.time)
        : DateFormat('h:mm a').format(transaction.createdAt.toDate());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.1), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side: Title and Category/Time chip
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (transaction.description?.isNotEmpty ?? false)
                      ? transaction.description!
                      : (transaction.isIncome ? 'Income' : 'Expense'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                // Pill/Chip for time and icon
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isIncome
                        ? AppColors.primary.withOpacity(0.1)
                        : AppColors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isIncome ? Icons.add : Icons.remove,
                        size: 14,
                        color: amountColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formattedTime,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Right side: Amount and Category Tag
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    transaction.amount.toStringAsFixed(
                      0,
                    ), // Removed currency symbol based on image, or add if needed
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white70,
                      size: 20,
                    ),
                    itemBuilder: (context) {
                      return [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ];
                    },
                    onSelected: (value) async {
                      if (value == 'edit') {
                        final result = await Navigator.pushNamed(
                          context,
                          AppRoutes.addIncomeExpense,
                          arguments: transaction,
                        );
                        if (result == true) {
                          context.read<TransactionBloc>().add(
                            GetTransactionListEvent(),
                          );
                        }
                      } else if (value == 'delete') {
                        // Handle delete action
                        context.read<TransactionBloc>().add(
                          DeleteTransactionEvent(docId: transaction.id ?? ""),
                        );
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 8),
              // Optional category text if available, or just alignment
              if (transaction.categoryName.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    transaction.categoryName,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
