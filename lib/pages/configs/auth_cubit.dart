import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:wild/src/rust/api/wenku8.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthState extends Equatable {
  final AuthStatus status;
  final String? username;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.username,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [status, username, errorMessage];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(const AuthState());

  Future<void> login(String username, String password) async {
    try {
      emit(AuthState(status: AuthStatus.loading));

      await wenku8Login(username: username, password: password);

      emit(AuthState(status: AuthStatus.authenticated, username: username));
    } catch (e) {
      emit(AuthState(status: AuthStatus.error, errorMessage: e.toString()));
    }
  }

  void logout() {
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> init() async {}
}
