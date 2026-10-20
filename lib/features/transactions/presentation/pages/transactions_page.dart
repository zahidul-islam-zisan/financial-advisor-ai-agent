import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../dashboard/presentation/widget/empty_list_widget.dart';
import '../../data/models/transaction_list_response_model.dart';
import '../bloc/transaction_bloc.dart';
import '../widgets/transaction_card.dart';
import '../widgets/transaction_date_header.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    context.read<TransactionBloc>().add(GetTransactionListEvent());
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Map<String, List<TransactionListResponseModel>> _groupTransactions(
    List<TransactionListResponseModel> transactions,
  ) {
    final Map<String, List<TransactionListResponseModel>> grouped = {};
    for (var transaction in transactions) {
      final date = DateTime.tryParse(transaction.date) ?? DateTime.now();
      final dateKey = DateTime(
        date.year,
        date.month,
        date.day,
      ).toIso8601String();

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(transaction);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        //backgroundColor: Colors.white,
        appBar: AppBar(
          //backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Transactions',
            //style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                Icons.calendar_month,
                color: _selectedDate != null
                    ? AppColors.primary
                    : AppColors.primary,
              ),
              onPressed: () => _selectDate(context),
            ),
            if (_selectedDate != null)
              IconButton(
                icon: const Icon(Icons.clear, color: AppColors.primary),
                onPressed: () => setState(() => _selectedDate = null),
              ),
          ],
        ),
        body: Column(
          children: [
            // Custom Segmented Tab Bar
            Container(
              height: 45,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.primary.withAlpha(40),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.grey,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Income'),
                  Tab(text: 'Expense'),
                ],
              ),
            ),
            Expanded(
              child: BlocConsumer<TransactionBloc, TransactionState>(
                listener: (context, state) {
                  if (state is TransactionDeleteSuccess) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Transaction deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    context.read<TransactionBloc>().add(
                      GetTransactionListEvent(),
                    );
                  } else if (state is TransactionDeleteError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: AppColors.red,
                      ),
                    );
                  }
                },
                buildWhen: (previous, current) {
                  return current is TransactionListLoading ||
                      current is TransactionListError ||
                      current is TransactionListLoaded;
                },
                builder: (context, state) {
                  log("+===transation state=== $state");
                  if (state is TransactionListLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is TransactionListError) {
                    return Center(child: Text(state.message));
                  } else if (state is TransactionListLoaded) {
                    // Filter by Date (Exact Day) if selected
                    final dateFilteredTransactions = state.transactionList
                        .where((t) {
                          if (_selectedDate == null) return true;
                          DateTime date;
                          try {
                            date = DateTime.parse(t.date);
                          } catch (_) {
                            return false;
                          }
                          return date.year == _selectedDate!.year &&
                              date.month == _selectedDate!.month &&
                              date.day == _selectedDate!.day;
                        })
                        .toList();

                    final incomeTransactions = dateFilteredTransactions
                        .where((t) => t.isIncome)
                        .toList();
                    final expenseTransactions = dateFilteredTransactions
                        .where((t) => !t.isIncome)
                        .toList();

                    return TabBarView(
                      children: [
                        _buildTransactionList(dateFilteredTransactions),
                        _buildTransactionList(incomeTransactions),
                        _buildTransactionList(expenseTransactions),
                      ],
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(
    List<TransactionListResponseModel> transactions,
  ) {
    if (transactions.isEmpty) {
      return const EmptyListWidget(header: "No transactions found");
    }

    final grouped = _groupTransactions(transactions);
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedKeys[index];
        final transactionsForDay = grouped[dateKey]!;
        final date = DateTime.parse(dateKey);

        double dailyTotal = 0;
        for (var t in transactionsForDay) {
          if (t.isIncome) {
            dailyTotal += t.amount;
          } else {
            dailyTotal -= t.amount;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TransactionDateHeader(date: date, totalAmount: dailyTotal),
            ...transactionsForDay.map(
              (transaction) => TransactionCard(transaction: transaction),
            ),
          ],
        );
      },
    );
  }
}
