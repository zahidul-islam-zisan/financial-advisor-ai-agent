import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

import '../../../transactions/data/models/transaction_list_response_model.dart';
import '../../data/data_sources/dashboard_remote_data_source.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc() : super(DashboardInitial()) {
    on<GetTransactionSummeryEvent>(_onGetTransactionSummeryEvent);
  }

  Future<void> _onGetTransactionSummeryEvent(
    GetTransactionSummeryEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());
    final result = await DashboardRemoteDataSource().getDashboardData(event.status);
    result.fold(
      (failure) => emit(DashboardError(message: failure.message)),
      (transactionList) {
        double totalIncome = 0;
        double totalExpense = 0;
        for (var transaction in transactionList) {
          if (transaction.isIncome == true) {
            totalIncome += transaction.amount;
          } else {
            totalExpense += transaction.amount;
          }
        }
        emit(DashboardLoaded(transactionList: transactionList, totalIncome: totalIncome, totalExpense: totalExpense));
      },
    );
  }
}
