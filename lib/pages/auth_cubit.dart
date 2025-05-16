import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:wild/src/rust/api/wenku8.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }
enum CheckcodeStatus { initial, loading, success, error }

class AuthState extends Equatable {
  final AuthStatus status;
  final String? username;
  final String? errorMessage;
  final Uint8List? checkcode;
  final CheckcodeStatus checkcodeStatus;

  const AuthState({
    this.status = AuthStatus.initial,
    this.username,
    this.errorMessage,
    this.checkcode,
    this.checkcodeStatus = CheckcodeStatus.initial,
  });

  @override
  List<Object?> get props => [status, username, errorMessage, checkcode, checkcodeStatus];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(const AuthState());

  Future<void> login(String username, String password, String checkcode) async {
    try {
      emit(AuthState(status: AuthStatus.loading));

      await wenku8Login(
        username: username,
        password: password,
        checkcode: checkcode,
      );

      emit(AuthState(status: AuthStatus.authenticated, username: username));
    } catch (e) {
      emit(AuthState(status: AuthStatus.error, errorMessage: e.toString()));
    }
  }

  void logout() {
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> init() async {
    if (await preLoginState()) {
      emit(AuthState(status: AuthStatus.authenticated));
    } else {
      emit(const AuthState(status: AuthStatus.unauthenticated));
    }
  }

  Future loadCheckcode() async {
    emit(AuthState(
      status: state.status,
      checkcode: Uint8List(0),
      checkcodeStatus: CheckcodeStatus.loading,
    ));
    try {
      final checkcode = await downloadCheckcode();
      emit(AuthState(
        status: state.status,
        checkcode: checkcode,
        checkcodeStatus: CheckcodeStatus.success,
      ));
      print("checkcode loaded : ${checkcode}");
    } catch (e, s) {
      print("2");
      print("${e}\n${s}");
      emit(
        AuthState(
          status: state.status,
          checkcode: null,
          checkcodeStatus: CheckcodeStatus.error,
          errorMessage: "无法成功获取验证码，请检查网络",
        ),
      );
    }
  }
}
