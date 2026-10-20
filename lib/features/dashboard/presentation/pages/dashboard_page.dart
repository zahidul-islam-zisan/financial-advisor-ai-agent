import 'dart:developer';

import 'package:expense_tracker_app/core/constants/app_value.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/route/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/update_service.dart';
import '../../../add_income_expense/presentation/pages/add_income_expense_page.dart';
import '../../../menu/presentation/pages/menu_page.dart';
import '../../../transactions/data/models/transaction_list_response_model.dart';
import '../../../transactions/presentation/bloc/transaction_bloc.dart';
import '../../../transactions/presentation/widgets/transaction_card.dart';
import '../../../transactions/presentation/widgets/transaction_date_header.dart';
import '../bloc/dashboard_bloc.dart';
import '../widget/empty_list_widget.dart';
import '../widget/shimmer_effect_widger.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? currentMonth;
  DateTime? _selectedDate;
  ValueNotifier<bool> isChartHide = ValueNotifier(false);
  @override
  void initState() {
    super.initState();
    currentStatus = 'Monthly';
    context.read<DashboardBloc>().add(
      GetTransactionSummeryEvent(status: currentStatus),
    );
    context.read<TransactionBloc>().add(GetTransactionListEvent());
    currentMonth = DateFormat('MMMM').format(DateTime.now());
    UpdateService.checkForUpdate();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String? currentStatus;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Image.asset(AppAssets.logo, width: 40, height: 40),
        ),
        title: Row(
          children: [
            Text(
              AppValue.appName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.aiAssistant);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.auto_awesome, color: AppColors.primary, size: 14),
                    SizedBox(width: 4),
                    Text(
                      "AI Chat",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MenuPage()),
                );
              },
              child: const Icon(Icons.settings, color: AppColors.primary),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              // AI Assistant Quick Banner
              InkWell(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.aiAssistant);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.25),
                        const Color.fromARGB(255, 18, 22, 50),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Pulse AI Financial Assistant",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              "Tap to analyze your expenses & ask budgeting tips",
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: AppColors.primary,
                        size: 13,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 175,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26.withAlpha(20),
                      blurRadius: 2,
                      offset: Offset(0, 0),
                    ),
                  ],
                ),
                child: DefaultTabController(
                  length: 2,

                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 12),

                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: AppColors.primary.withOpacity(0.15),
                          ),
                          child: TabBar(
                            dividerColor: Colors.transparent,
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicator: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: AppColors.primary,
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.white70,
                            onTap: (v) {
                              if (v == 0) {
                                currentStatus = 'Monthly';
                              } else {
                                currentStatus = 'Total';
                              }
                              context.read<DashboardBloc>().add(
                                GetTransactionSummeryEvent(
                                  status: currentStatus,
                                ),
                              );
                            },
                            tabs: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Tab(text: currentMonth),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Tab(text: 'Total'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        /// Summary Content
                        Expanded(
                          child: BlocBuilder<DashboardBloc, DashboardState>(
                            builder: (context, state) {
                              log("0000000000DASHBOARD STATE000000000: $state");
                              if (state is DashboardLoading ||
                                  state is DashboardInitial) {
                                return ShimmerEffectWidger.shimmerEffectSummary();
                              }
                              if (state is DashboardError) {
                                return Center(child: Text(state.message));
                              }
                              if (state is DashboardLoaded) {
                                return TabBarView(
                                  children: [
                                    _summarySection(
                                      income: state.totalIncome,
                                      expense: state.totalExpense,
                                    ),
                                    _summarySection(
                                      income: state.totalIncome,
                                      expense: state.totalExpense,
                                    ),
                                  ],
                                );
                              }
                              return TabBarView(
                                children: [
                                  _summarySection(income: 5000, expense: 2000),
                                  _summarySection(income: 5000, expense: 2000),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),

              //spending breakdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Spending Breakdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                  ValueListenableBuilder(
                    valueListenable: isChartHide,
                    builder: (context, value, child) {
                      return IconButton(
                        icon: Icon(
                          isChartHide.value
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: AppColors.primary,
                        ),
                        onPressed: () {
                          isChartHide.value = !isChartHide.value;
                        },
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: 10),
              ValueListenableBuilder(
                valueListenable: isChartHide,
                builder: (context, value, child) {
                  return !isChartHide.value
                      ? SizedBox(
                          height: 250,
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 2,
                                  offset: Offset(0, 0),
                                ),
                              ],
                            ),
                            child: BlocBuilder<DashboardBloc, DashboardState>(
                              builder: (context, state) {
                                if (state is DashboardLoaded) {
                                  final distribution = _getCategoryDistribution(
                                    state.transactionList,
                                  );

                                  if (distribution.isEmpty) {
                                    return EmptyListWidget(
                                      header: DateFormat(
                                        'MMMM , yyyy',
                                      ).format(DateTime.now()),
                                      message: "No transactions this month",
                                    );
                                  }

                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: PieChart(
                                          PieChartData(
                                            borderData: FlBorderData(
                                              show: false,
                                            ),
                                            sectionsSpace: 2,
                                            centerSpaceRadius: 40,
                                            sections: distribution.entries
                                                .toList()
                                                .asMap()
                                                .entries
                                                .map((entry) {
                                                  final index = entry.key;
                                                  final category =
                                                      entry.value.key;
                                                  final percentage =
                                                      entry.value.value;

                                                  return PieChartSectionData(
                                                    color:
                                                        _chartColors[index %
                                                            _chartColors
                                                                .length],
                                                    value: percentage,
                                                    title:
                                                        '${percentage.toStringAsFixed(0)}%',
                                                    radius: 50,
                                                    titleStyle: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  );
                                                })
                                                .toList(),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: distribution.entries
                                                .toList()
                                                .asMap()
                                                .entries
                                                .map((entry) {
                                                  final index = entry.key;
                                                  final category =
                                                      entry.value.key;

                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 4,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 10,
                                                          height: 10,
                                                          decoration: BoxDecoration(
                                                            color:
                                                                _chartColors[index %
                                                                    _chartColors
                                                                        .length],
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                        ),
                                                        SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            category,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                })
                                                .toList(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                return ShimmerEffectWidger.shimmerEffectChart();
                              },
                            ),
                          ),
                        )
                      : Container();
                },
              ),
              //recent transactions
              Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),

              SizedBox(
                height: 400,
                child: DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TabBar(
                                isScrollable: true,
                                tabAlignment: TabAlignment.start,
                                dividerColor: Colors.transparent,
                                indicatorSize: TabBarIndicatorSize.tab,
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                indicator: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: AppColors.primary.withAlpha(50),
                                ),
                                labelColor: AppColors.primary,
                                unselectedLabelColor: AppColors.grey,
                                labelStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                unselectedLabelStyle: const TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: 13,
                                ),
                                tabs: const [
                                  Tab(text: 'All'),
                                  Tab(text: 'Income'),
                                  Tab(text: 'Expense'),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                _selectDate(context);
                              },
                              icon: Icon(
                                Icons.calendar_month_outlined,
                                color: _selectedDate != null
                                    ? AppColors.primary
                                    : AppColors.grey,
                              ),
                            ),
                            if (_selectedDate != null)
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedDate = null;
                                  });
                                },
                                icon: const Icon(
                                  Icons.clear,
                                  color: AppColors.primary,
                                ),
                              ),
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(
                                Icons.category_outlined,
                                color: AppColors.grey,
                              ),
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(
                                Icons.more_vert,
                                color: AppColors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: BlocConsumer<TransactionBloc, TransactionState>(
                          listener: (context, state) {
                            if (state is TransactionDeleteSuccess) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Transaction deleted successfully',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              // Refresh the list
                              context.read<TransactionBloc>().add(
                                GetTransactionListEvent(),
                              );
                              // Refresh the summary
                              context.read<DashboardBloc>().add(
                                GetTransactionSummeryEvent(
                                  status: currentStatus,
                                ),
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
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            } else if (state is TransactionListError) {
                              return Center(child: Text(state.message));
                            } else if (state is TransactionListLoaded) {
                              // Filter by Date (Exact Day) if selected
                              log(
                                "state.transactionList ${state.transactionList.length.toString()}",
                              );
                              final dateFilteredTransactions = state
                                  .transactionList
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

                              final incomeTransactions =
                                  dateFilteredTransactions
                                      .where((t) => t.isIncome)
                                      .toList();
                              final expenseTransactions =
                                  dateFilteredTransactions
                                      .where((t) => !t.isIncome)
                                      .toList();
                              log(
                                "dateFilteredTransactions ${dateFilteredTransactions.length.toString()}",
                              );
                              log(
                                "incomeTransactions ${incomeTransactions.length.toString()}",
                              );
                              log(
                                "expenseTransactions ${expenseTransactions.length.toString()}",
                              );
                              return TabBarView(
                                children: [
                                  _buildTransactionList(
                                    dateFilteredTransactions,
                                  ),
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
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddIncomeExpensePage()),
          );

          if (result == true && mounted) {
            context.read<DashboardBloc>().add(
              GetTransactionSummeryEvent(status: currentStatus),
            );
          }
        },
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.add, color: AppColors.white),
      ),
    );
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

  Widget _buildTransactionList(
    List<TransactionListResponseModel> transactions,
  ) {
    if (transactions.isEmpty) {
      return EmptyListWidget(header: 'No transactions found');
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

  Map<String, double> _getCategoryDistribution(
    List<TransactionListResponseModel> transactions,
  ) {
    Map<String, double> distribution = {};
    double totalExpense = 0;

    for (var transaction in transactions) {
      if (!transaction.isIncome) {
        totalExpense += transaction.amount;
        final category = transaction.categoryName.isEmpty
            ? 'Other'
            : transaction.categoryName;
        distribution[category] =
            (distribution[category] ?? 0) + transaction.amount;
      }
    }

    if (totalExpense == 0) return {};

    // Convert amounts to percentages
    distribution.updateAll((key, value) => (value / totalExpense) * 100);

    return distribution;
  }

  final List<Color> _chartColors = [
    Colors.orange,
    Colors.blue,
    Colors.red,
    Colors.purple,
    Colors.amber,
    Colors.indigo,
    Colors.pink,
    Colors.deepPurple,
  ];
}

Widget _summarySection({required double income, required double expense}) {
  double balance = income - expense;

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _summaryItem("Income", income, Colors.green),
      _summaryItem("Expense", expense, Colors.red),
      _summaryItem("Balance", balance, Colors.blue),
    ],
  );
}

Widget _summaryItem(String title, double amount, Color color) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.white70,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    ],
  );
}
