import 'package:signals/signals.dart' as signals;

enum AutoScrollState {
  stopped,
  scrolling,
}

class AutoScrollStateStore {
  AutoScrollStateStore() : _state = signals.signal(AutoScrollState.stopped);

  final signals.Signal<AutoScrollState> _state;
  AutoScrollState get state => _state.value;
  signals.Signal<AutoScrollState> get signal => _state;

  void startScrolling() {
    _state.value = AutoScrollState.scrolling;
  }

  void stopScrolling() {
    _state.value = AutoScrollState.stopped;
  }
} 
