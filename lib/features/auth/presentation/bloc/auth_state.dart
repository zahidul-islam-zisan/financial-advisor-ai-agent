part of 'auth_bloc.dart';

@immutable
sealed class AuthState {}

final class AuthInitial extends AuthState {}

class RegisterLoading extends AuthState {}

class RegisterSuccess extends AuthState {
  final RegistrationModel user;

  RegisterSuccess({required this.user});
}

class RegisterFailure extends AuthState {
  final String failure;

  RegisterFailure({required this.failure});
}

class LoginLoading extends AuthState {}

class LoginSuccess extends AuthState {
  final bool success;
  LoginSuccess({required this.success});
}

class LoginFailure extends AuthState {
  final String failure;
  LoginFailure({required this.failure});
}