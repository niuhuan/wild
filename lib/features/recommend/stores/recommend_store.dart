import 'package:signals/signals.dart' as signals;
import 'package:wild/src/rust/api/wenku8.dart' as w8;
import 'package:wild/src/rust/wenku8/models.dart' as w8;

abstract class RecommendState {}

class RecommendInitial extends RecommendState {}

class RecommendLoading extends RecommendState {}

class RecommendLoaded extends RecommendState {
  final List<w8.HomeBlock> blocks;

  RecommendLoaded(this.blocks);
}

class RecommendError extends RecommendState {
  final String message;

  RecommendError(this.message);
}

class RecommendStore {
  RecommendStore() : _state = signals.signal<RecommendState>(RecommendInitial());

  final signals.Signal<RecommendState> _state;
  RecommendState get state => _state.value;
  signals.Signal<RecommendState> get signal => _state;

  Future<void> load() async {
    _state.value = RecommendLoading();
    try {
      final blocks = await w8.index();
      _state.value = RecommendLoaded(blocks);
    } catch (e) {
      _state.value = RecommendError(e.toString());
    }
  }
} 
