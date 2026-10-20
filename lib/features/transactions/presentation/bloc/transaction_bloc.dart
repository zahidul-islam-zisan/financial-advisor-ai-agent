import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

import '../../data/data_sources/transaction_remote_data_source.dart';
import '../../data/models/transaction_list_response_model.dart';

part 'transaction_event.dart';
part 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  TransactionBloc() : super(TransactionInitial()) {
on<GetTransactionListEvent>(getTransactionList);
on<DeleteTransactionEvent>(deleteTransaction);
  }

Future<void> getTransactionList(
    GetTransactionListEvent event,
    Emitter<TransactionState> emit,
  ) async {
    emit(TransactionListLoading());
    final result = await TransactionRemoteDataSource().getTransactionList();
    result.fold(
      (failure) => emit(TransactionListError(message: failure.message)),
      (transactionList) => emit(TransactionListLoaded(transactionList: transactionList)),
    );
  }

Future<void> deleteTransaction(
    DeleteTransactionEvent event,
    Emitter<TransactionState> emit,
  ) async {
    emit(TransactionDeleteLoading());
    final result = await TransactionRemoteDataSource().deleteTransaction(event.docId);
    result.fold(
      (failure) => emit(TransactionDeleteError(message: failure.message)),
      (unit) => emit(TransactionDeleteSuccess()),
    );
  }
}
