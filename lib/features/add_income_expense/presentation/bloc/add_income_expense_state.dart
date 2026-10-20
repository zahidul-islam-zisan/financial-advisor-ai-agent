part of 'add_income_expense_bloc.dart';

@immutable
sealed class AddIncomeExpenseState {}

final class AddIncomeExpenseInitial extends AddIncomeExpenseState {}

final class AddIncomeExpenseAddLoading extends AddIncomeExpenseState {}

final class AddIncomeExpenseAddSuccess extends AddIncomeExpenseState {}

final class AddIncomeExpenseAddFailure extends AddIncomeExpenseState {
  final String error;
  AddIncomeExpenseAddFailure({required this.error});
}

