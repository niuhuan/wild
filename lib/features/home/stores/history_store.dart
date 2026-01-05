import 'package:signals/signals.dart' as signals;
import 'package:wild/src/rust/api/wenku8.dart' as w8;

abstract class HistoryState {}

class HistoryInitial extends HistoryState {}

class HistoryLoading extends HistoryState {}

class HistoryLoaded extends HistoryState {
  final List<w8.ReadingHistory> histories;

  HistoryLoaded(this.histories);
}

class HistoryError extends HistoryState {
  final String message;

  HistoryError(this.message);
}

class HistoryStore {
  HistoryStore() : _state = signals.signal<HistoryState>(HistoryInitial());

  final signals.Signal<HistoryState> _state;
  HistoryState get state => _state.value;
  signals.Signal<HistoryState> get signal => _state;

  Future<void> load() async {
    _state.value = HistoryLoading();
    try {
      final histories = await w8.listReadingHistory(offset: 0, limit: 100);
      _state.value = HistoryLoaded(histories);
    } catch (e) {
      _state.value = HistoryError(e.toString());
    }
  }

  Future<void> deleteHistory(String novelId) async {
    if (state is! HistoryLoaded) return;
    
    try {
      await w8.deleteHistoryByNovelId(novelId: novelId);
      final currentState = state as HistoryLoaded;
      final updatedHistories = currentState.histories.where((h) => h.novelId != novelId).toList();
      _state.value = HistoryLoaded(updatedHistories);
    } catch (e) {
      _state.value = HistoryError(e.toString());
    }
  }
} 
