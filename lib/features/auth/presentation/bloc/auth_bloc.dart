import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

import '../../data/data_sources/auth_remote_data_source.dart';
import '../../data/model/registration_model.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthInitial()) {
    on<RegisterEvent>(_onRegister);
    on<LoginEvent>(_onLogin);
  }

  Future<void> _onRegister(RegisterEvent event, Emitter<AuthState> emit) async {
    emit(RegisterLoading());
    final result = await AuthRemoteDataSource().registerUser(event.email, event.password);
    result.fold(
      (failure) => emit(RegisterFailure(failure: failure.message)),
      (user) => emit(RegisterSuccess(user: user)),
    );
  }

  Future<void> _onLogin(LoginEvent event, Emitter<AuthState> emit) async {
    emit(LoginLoading());
    final result = await AuthRemoteDataSource().loginUser(event.email, event.password);
    result.fold(
      (failure) => emit(LoginFailure(failure: failure.message)),
      (success) => emit(LoginSuccess(success: success)),
    );
  }
}
