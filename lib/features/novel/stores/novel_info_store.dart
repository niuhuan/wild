import 'package:wild/src/rust/api/wenku8.dart' as w8;
import 'package:signals/signals.dart' as signals;

import 'package:wild/src/rust/wenku8/models.dart';

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

class NovelInfoStore {
  final String novelId;
  List<Volume> _volumes = [];

  NovelInfoStore(this.novelId)
      : _state = signals.signal<NovelInfoState>(NovelInfoInitial());

  final signals.Signal<NovelInfoState> _state;
  NovelInfoState get state => _state.value;
  signals.Signal<NovelInfoState> get signal => _state;

  List<Volume> get volumes => _volumes;

  Future<void> load() async {
    _state.value = NovelInfoLoading();
    try {
      final novelInfo = await w8.novelInfo(aid: novelId);
      _volumes = await w8.novelReader(aid: novelId);
      final readingHistory = await w8.novelHistoryById(novelId: novelId);
      _state.value = NovelInfoLoaded(
        novelInfo: novelInfo,
        volumes: _volumes,
        readingHistory: readingHistory,
      );
    } catch (e) {
      _state.value = NovelInfoError(e.toString());
    }
  }

  Future<void> loadHistory() async {
    final readingHistory = await w8.novelHistoryById(novelId: novelId);
    if (state is NovelInfoLoaded) {
      final currentState = state as NovelInfoLoaded;
      _state.value = NovelInfoLoaded(
        novelInfo: currentState.novelInfo,
        volumes: currentState.volumes,
        readingHistory: readingHistory,
      );
    }
  }
} 
