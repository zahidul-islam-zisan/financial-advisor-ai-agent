part of 'category_bloc.dart';

@immutable
sealed class CategoryState {}

final class CategoryInitial extends CategoryState {}

final class CategoryAddLoading extends CategoryState {}

final class CategoryAddSuccess extends CategoryState {
}

final class CategoryAddError extends CategoryState {
  final String message;
  CategoryAddError({required this.message});
}

final class CategoryGetLoading extends CategoryState {}

final class CategoryGetSuccess extends CategoryState {
  final List<CategoryListResponseModel> categories;
  CategoryGetSuccess({required this.categories});
}

final class CategoryGetError extends CategoryState {
  final String message;
  CategoryGetError({required this.message});
}
