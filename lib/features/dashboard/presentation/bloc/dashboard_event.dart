part of 'dashboard_bloc.dart';

@immutable
sealed class DashboardEvent {}

final class GetTransactionSummeryEvent extends DashboardEvent {
  final String? status;
  GetTransactionSummeryEvent({this.status});
}