import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker_app/core/constants/app_colors.dart';
import 'package:expense_tracker_app/core/widgets/custom_date_time_picker.dart';
import 'package:expense_tracker_app/core/widgets/custom_snackbar.dart';
import 'package:expense_tracker_app/core/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/route/app_routes.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../category/data/models/category_list_response_model.dart';
import '../../../dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../../transactions/presentation/bloc/transaction_bloc.dart';
import '../../../transactions/data/models/transaction_list_response_model.dart';
import '../../data/models/add_income_expense_request_model.dart';
import '../bloc/add_income_expense_bloc.dart';

class AddIncomeExpensePage extends StatefulWidget {
  final TransactionListResponseModel? transaction;
  const AddIncomeExpensePage({super.key, this.transaction});

  @override
  State<AddIncomeExpensePage> createState() => _AddIncomeExpensePageState();
}

class _AddIncomeExpensePageState extends State<AddIncomeExpensePage> {
  bool isIncome = true;
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();

  final TextEditingController amountController = TextEditingController();
  final TextEditingController? descriptionController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  TextEditingController? categoryController = TextEditingController();
  String? selectedCategoryId;
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      isIncome = widget.transaction!.isIncome;
      selectedDate = DateTime.tryParse(widget.transaction!.date) ?? DateTime.now();
      // selectedTime handling might need parsing if it's a string like "10:30 AM"
      // Assuming DateTimeUtils or DateFormat can handle it if needed
      // For now, we'll keep the current time or try to parse
      selectedTime = DateTimeUtils.parseTimeString(widget.transaction!.time);

      amountController.text = widget.transaction!.amount.toString();
      descriptionController?.text = widget.transaction!.description ?? "";
      categoryController?.text = widget.transaction!.categoryName;
      selectedCategoryId = widget.transaction!.categoryId;
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    descriptionController?.dispose();
    searchController.dispose();
    categoryController?.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (picked != null && picked != selectedTime) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.transaction != null ? 'Edit Transaction' : 'New Transaction',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: BlocListener<AddIncomeExpenseBloc, AddIncomeExpenseState>(
          listener: (context, state) {
            log("add income expense bloc state : $state");
            if (state is AddIncomeExpenseAddSuccess) {
              context.read<TransactionBloc>().add(GetTransactionListEvent());
              context.read<DashboardBloc>().add(
                GetTransactionSummeryEvent(status: "Monthly"),
              );
              CustomSnackbar.showSuccess(
                context: context,
                message: widget.transaction != null
                    ? "Updated successfully"
                    : "Added successfully",
              );
              // context.read<TransactionBloc>().add(GetTransactionListEvent());

              Navigator.pop(context, true);
            } else if (state is AddIncomeExpenseAddFailure) {
              CustomSnackbar.showError(context: context, message: state.error);
            }
          },
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reusable Date and Time pickers
                CustomDateTimePicker(
                  selectedDate: selectedDate,
                  selectedTime: selectedTime,
                  onSelectDate: () => _selectDate(context),
                  onSelectTime: () => _selectTime(context),
                ),
                const SizedBox(height: 24),

                // Income/Expense Toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => isIncome = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isIncome
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Center(
                              child: Text(
                                'Income',
                                style: TextStyle(
                                  color: isIncome
                                      ? Colors.white
                                      : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => isIncome = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !isIncome
                                  ? AppColors.red
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Center(
                              child: Text(
                                'Expense',
                                style: TextStyle(
                                  color: !isIncome
                                      ? Colors.white
                                      : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Category Field
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TextField(
                    readOnly: true,
                    onTap: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        AppRoutes.catagoryList,
                      );
                      if (result != null &&
                          result is CategoryListResponseModel) {
                        setState(() {
                          categoryController?.text = result.name;
                          selectedCategoryId = result.id;
                        });
                      }
                    },
                    controller: categoryController,
                    decoration: InputDecoration(
                      hintText: 'Category',
                      hintStyle: TextStyle(color: Colors.white70, fontSize: 14),
                      //style:  TextStyle(color: Colors.white),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Amount Input
                CustomTextField(
                  controller: amountController,
                  hintText: 'Amount',
                  prefixIcon: Icons.money,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter amount';
                    }
                    final cleanVal = value.trim().replaceAll(',', '');
                    final parsed = double.tryParse(cleanVal);
                    if (parsed == null) {
                      return 'Please enter a valid numeric amount';
                    }
                    if (parsed <= 0) {
                      return 'Amount must be greater than zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description Input
                CustomTextField(
                  controller: descriptionController ?? TextEditingController(),
                  hintText: 'Description (Optional)',
                  prefixIcon: Icons.description_outlined,
                ),
                const SizedBox(height: 32),

                BlocBuilder<AddIncomeExpenseBloc, AddIncomeExpenseState>(
                  builder: (context, state) {
                    return SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: state is AddIncomeExpenseAddLoading
                            ? null
                            : () {
                                if (formKey.currentState!.validate()) {
                                  final cleanAmountStr = amountController.text
                                      .trim()
                                      .replaceAll(',', '');
                                  final amountVal =
                                      double.tryParse(cleanAmountStr) ?? 0.0;

                                  if (widget.transaction != null) {
                                    context.read<AddIncomeExpenseBloc>().add(
                                      AddIncomeExpenseEventUpdateIncomeExpense(
                                        transactionId: widget.transaction!.id!,
                                        incomeExpense: AddIncomeExpenseRequestModel(
                                          date:
                                              DateTimeUtils.formatToDateString(
                                                selectedDate,
                                              ),
                                          time:
                                              DateTimeUtils.formatToTimeString(
                                                selectedTime,
                                              ),
                                          amount: amountVal,
                                          description:
                                              descriptionController?.text ?? "",
                                          categoryId: selectedCategoryId ?? "",
                                          categoryName:
                                              categoryController?.text ??
                                              "Other",
                                          isIncome: isIncome,
                                          createdAt:
                                              widget.transaction!.createdAt,
                                        ),
                                      ),
                                    );
                                  } else {
                                    context.read<AddIncomeExpenseBloc>().add(
                                      AddIncomeExpenseEventAddIncomeExpense(
                                        incomeExpense: AddIncomeExpenseRequestModel(
                                          date:
                                              DateTimeUtils.formatToDateString(
                                                selectedDate,
                                              ),
                                          time:
                                              DateTimeUtils.formatToTimeString(
                                                selectedTime,
                                              ),
                                          amount: amountVal,
                                          description:
                                              descriptionController?.text ?? "",
                                          categoryId: selectedCategoryId ?? "",
                                          categoryName:
                                              categoryController?.text ??
                                              "Other",
                                          isIncome: isIncome,
                                          createdAt: Timestamp.now(),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isIncome
                              ? AppColors.primary
                              : AppColors.red,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: state is AddIncomeExpenseAddLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                widget.transaction != null ? 'Update' : 'Add',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
