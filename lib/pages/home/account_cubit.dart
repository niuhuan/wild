import 'package:flutter_bloc/flutter_bloc.dart';
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

class AccountCubit extends Cubit<AccountState> {
  AccountCubit() : super(const AccountState());

  Future<void> loadUserDetail() async {
    if (state.status == AccountStatus.loaded && state.userDetail != null) {
      return;
    }

    emit(state.copyWith(status: AccountStatus.loading));

    try {
      // Implement user detail loading from Rust
      final userDetail = await wenku8.userDetail();
      emit(
        state.copyWith(status: AccountStatus.loaded, userDetail: userDetail),
      );
    } catch (e) {
      emit(
        state.copyWith(status: AccountStatus.error, errorMessage: e.toString()),
      );
    }
  }
}
