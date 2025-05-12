import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/src/rust/api/wenku8.dart' as w8;

import '../../src/rust/wenku8/models.dart';
import '../../src/rust/api/database.dart';

abstract class NovelInfoState {}

class NovelInfoInitial extends NovelInfoState {}

class NovelInfoLoading extends NovelInfoState {}

class NovelInfoLoaded extends NovelInfoState {
  final NovelInfo novelInfo;
  final List<Volume> volumes;
  final w8.ReadingHistory? readingHistory;

  NovelInfoLoaded({
    required this.novelInfo,
    required this.volumes,
    this.readingHistory,
  });
}

class NovelInfoError extends NovelInfoState {
  final String message;

  NovelInfoError(this.message);
}

class NovelInfoCubit extends Cubit<NovelInfoState> {
  final String novelId;
  List<Volume> _volumes = [];

  NovelInfoCubit(this.novelId) : super(NovelInfoInitial());

  List<Volume> get volumes => _volumes;

  Future<void> load() async {
    emit(NovelInfoLoading());
    try {
      final novelInfo = await w8.novelInfo(aid: novelId);
      _volumes = await w8.novelReader(aid: novelId);
      final readingHistory = await w8.novelHistoryById(novelId: novelId);
      emit(NovelInfoLoaded(
        novelInfo: novelInfo,
        volumes: _volumes,
        readingHistory: readingHistory,
      ));
    } catch (e) {
      emit(NovelInfoError(e.toString()));
    }
  }

  Future<void> loadHistory() async {
    final readingHistory = await w8.novelHistoryById(novelId: novelId);
    if (state is NovelInfoLoaded) {
      final currentState = state as NovelInfoLoaded;
      emit(NovelInfoLoaded(
        novelInfo: currentState.novelInfo,
        volumes: currentState.volumes,
        readingHistory: readingHistory,
      ));
    }
  }
} 