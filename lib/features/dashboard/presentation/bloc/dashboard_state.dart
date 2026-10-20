part of 'dashboard_bloc.dart';

@immutable
sealed class DashboardState {}

final class DashboardInitial extends DashboardState {}

final class DashboardLoading extends DashboardState {}

final class DashboardLoaded extends DashboardState {
  final List<TransactionListResponseModel> transactionList;
  final double totalIncome;
  final double totalExpense;
  DashboardLoaded({required this.transactionList, required this.totalIncome, required this.totalExpense});
}

final class DashboardError extends DashboardState {
  final String message;
  DashboardError({required this.message});
}
