part of 'add_income_expense_bloc.dart';

@immutable
sealed class AddIncomeExpenseEvent {}

class AddIncomeExpenseEventAddIncomeExpense extends AddIncomeExpenseEvent {
  final AddIncomeExpenseRequestModel incomeExpense;
  AddIncomeExpenseEventAddIncomeExpense({required this.incomeExpense});
}

class AddIncomeExpenseEventUpdateIncomeExpense extends AddIncomeExpenseEvent {
  final String transactionId;
  final AddIncomeExpenseRequestModel incomeExpense;
  AddIncomeExpenseEventUpdateIncomeExpense({
    required this.transactionId,
    required this.incomeExpense,
  });
}
