part of 'transaction_bloc.dart';

@immutable
sealed class TransactionEvent {}

final class GetTransactionListEvent extends TransactionEvent {}
final class DeleteTransactionEvent extends TransactionEvent {
  final String docId;
  DeleteTransactionEvent({required this.docId});
}
