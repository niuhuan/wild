import 'package:signals/signals.dart' as signals;
import 'package:wild/src/rust/api/wenku8.dart' as wenku8;
import 'package:wild/src/rust/wenku8/models.dart';

enum AccountStatus { initial, loading, loaded, error }

class AccountState {
  final AccountStatus status;
  final UserDetail? userDetail;
  final String? errorMessage;

  const AccountState({
    this.status = AccountStatus.initial,
    this.userDetail,
    this.errorMessage,
  });

  AccountState copyWith({
    AccountStatus? status,
    UserDetail? userDetail,
    String? errorMessage,
  }) {
    return AccountState(
      status: status ?? this.status,
      userDetail: userDetail ?? this.userDetail,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AccountStore {
  AccountStore() : _state = signals.signal(const AccountState());

  final signals.Signal<AccountState> _state;
  AccountState get state => _state.value;
  signals.Signal<AccountState> get signal => _state;

  Future<void> loadUserDetail() async {
    if (state.status == AccountStatus.loaded && state.userDetail != null) {
      return;
    }

    _state.value = state.copyWith(status: AccountStatus.loading);

    try {
      // Implement user detail loading from Rust
      final userDetail = await wenku8.userDetail();
      _state.value =
          state.copyWith(status: AccountStatus.loaded, userDetail: userDetail);
    } catch (e) {
      _state.value = state.copyWith(
        status: AccountStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}
