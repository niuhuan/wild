import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/src/rust/wenku8/models.dart';

import '../../src/rust/api/wenku8.dart';

enum IndexStatus { initial, loading, loaded, error }

class IndexState {
  final IndexStatus status;
  final List<HomeBlock>? blocks;
  final String? errorMessage;

  const IndexState({
    this.status = IndexStatus.initial,
    this.blocks,
    this.errorMessage,
  });

  IndexState copyWith({
    IndexStatus? status,
    List<HomeBlock>? blocks,
    String? errorMessage,
  }) {
    return IndexState(
      status: status ?? this.status,
      blocks: blocks ?? this.blocks,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class IndexCubit extends Cubit<IndexState> {
  IndexCubit() : super(const IndexState());

  Future<void> loadIndex() async {
    if (state.status == IndexStatus.loaded && state.blocks != null) {
      return;
    }

    emit(state.copyWith(status: IndexStatus.loading));

    try {
      final blocks = await index();
      emit(state.copyWith(
        status: IndexStatus.loaded,
        blocks: blocks,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: IndexStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
} 