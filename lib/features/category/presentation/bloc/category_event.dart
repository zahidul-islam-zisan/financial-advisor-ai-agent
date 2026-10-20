part of 'category_bloc.dart';

@immutable
sealed class CategoryEvent {}

final class CategoryAddEvent extends CategoryEvent {
  final CategoryAddRequestModel category;
  CategoryAddEvent({required this.category});
}

final class CategoryAddDefaultEvent extends CategoryEvent {}

final class CategoryGetEvent extends CategoryEvent {}
