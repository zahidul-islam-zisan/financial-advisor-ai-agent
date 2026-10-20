import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

import '../../data/data_sources/category_remote_data_source.dart';
import '../../data/models/category_add_request_model.dart';
import '../../data/models/category_list_response_model.dart';

part 'category_event.dart';
part 'category_state.dart';

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  CategoryBloc() : super(CategoryInitial()) {
    on<CategoryAddEvent>(_onCategoryAdd);
    on<CategoryAddDefaultEvent>(_onCategoryAddDefault);
    on<CategoryGetEvent>(_onCategoryGet);
  }

  Future<void> _onCategoryAdd(CategoryAddEvent event, Emitter<CategoryState> emit) async {
    emit(CategoryAddLoading());
    final result = await CategoryRemoteDataSource().addCategory(event.category);
    result.fold(
      (failure) => emit(CategoryAddError(message: failure.message)),
      (success) => emit(CategoryAddSuccess()),
    );
  }

  Future<void> _onCategoryAddDefault(CategoryAddDefaultEvent event, Emitter<CategoryState> emit) async {
    emit(CategoryAddLoading());
    final result = await CategoryRemoteDataSource().addDefaultCategories();
    result.fold(
      (failure) => emit(CategoryAddError(message: failure.message)),
      (success) => emit(CategoryAddSuccess()),
    );
  }

  Future<void> _onCategoryGet(CategoryGetEvent event, Emitter<CategoryState> emit) async {
    emit(CategoryGetLoading());
    final result = await CategoryRemoteDataSource().getCategories();
    result.fold(
      (failure) => emit(CategoryGetError(message: failure.message)),
      (success) => emit(CategoryGetSuccess(categories: success)),
    );
  }
}
