import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:signals/signals.dart' as signals;
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

class AuthStore {
  AuthStore() : _state = signals.signal(const AuthState());

  final signals.Signal<AuthState> _state;
  AuthState get state => _state.value;
  signals.Signal<AuthState> get signal => _state;

  Future<void> login(String username, String password, String checkcode) async {
    try {
      _state.value = const AuthState(status: AuthStatus.loading);

      await wenku8Login(
        username: username,
        password: password,
        checkcode: checkcode,
      );

      _state.value =
          AuthState(status: AuthStatus.authenticated, username: username);
    } catch (e) {
      _state.value =
          AuthState(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  void logout() {
    _state.value = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> init() async {
    if (await preLoginState()) {
      _state.value = const AuthState(status: AuthStatus.authenticated);
    } else {
      _state.value = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future loadCheckcode() async {
    _state.value = AuthState(
      status: state.status,
      checkcode: Uint8List(0),
      checkcodeStatus: CheckcodeStatus.loading,
    );
    try {
      final checkcode = await downloadCheckcode();
      _state.value = AuthState(
        status: state.status,
        checkcode: checkcode,
        checkcodeStatus: CheckcodeStatus.success,
      );
      print("checkcode loaded : ${checkcode}");
    } catch (e, s) {
      print("2");
      print("${e}\n${s}");
      _state.value = AuthState(
        status: state.status,
        checkcode: null,
        checkcodeStatus: CheckcodeStatus.error,
        errorMessage: "无法成功获取验证码，请检查网络",
      );
    }
  }
}
