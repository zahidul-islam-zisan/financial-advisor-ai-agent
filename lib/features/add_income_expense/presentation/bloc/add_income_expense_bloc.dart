import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

import '../../data/data_sources/add_income_expense_data_source.dart';
import '../../data/models/add_income_expense_request_model.dart';

part 'add_income_expense_event.dart';
part 'add_income_expense_state.dart';

class AddIncomeExpenseBloc extends Bloc<AddIncomeExpenseEvent, AddIncomeExpenseState> {
  AddIncomeExpenseBloc() : super(AddIncomeExpenseInitial()) {
    on<AddIncomeExpenseEventAddIncomeExpense>(_onAddIncomeExpense);
    on<AddIncomeExpenseEventUpdateIncomeExpense>(_onUpdateIncomeExpense);
  }

  Future<void> _onAddIncomeExpense(
    AddIncomeExpenseEventAddIncomeExpense event,
    Emitter<AddIncomeExpenseState> emit,
  ) async {
    emit(AddIncomeExpenseAddLoading());
    final result = await AddIncomeExpenseDataSource().addIncomeExpense(
      event.incomeExpense,
    );
    result.fold(
      (failure) => emit(AddIncomeExpenseAddFailure(error: failure.message)),
      (success) => emit(AddIncomeExpenseAddSuccess()),
    );
  }

  Future<void> _onUpdateIncomeExpense(
    AddIncomeExpenseEventUpdateIncomeExpense event,
    Emitter<AddIncomeExpenseState> emit,
  ) async {
    emit(AddIncomeExpenseAddLoading());
    final result = await AddIncomeExpenseDataSource().updateIncomeExpense(
      event.transactionId,
      event.incomeExpense,
    );
    result.fold(
      (failure) => emit(AddIncomeExpenseAddFailure(error: failure.message)),
      (success) => emit(AddIncomeExpenseAddSuccess()),
    );
  }
}
