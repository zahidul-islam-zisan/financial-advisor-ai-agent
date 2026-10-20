part of 'transaction_bloc.dart';

@immutable
sealed class TransactionState {}

final class TransactionInitial extends TransactionState {}

final class TransactionListLoading extends TransactionState {}

final class TransactionListLoaded extends TransactionState {
  final List<TransactionListResponseModel> transactionList;

  TransactionListLoaded({required this.transactionList});
}

final class TransactionListError extends TransactionState {
  final String message;

  TransactionListError({required this.message});
}

final class TransactionDeleteLoading extends TransactionState {}

final class TransactionDeleteSuccess extends TransactionState {}

final class TransactionDeleteError extends TransactionState {
  final String message;

  TransactionDeleteError({required this.message});
}
