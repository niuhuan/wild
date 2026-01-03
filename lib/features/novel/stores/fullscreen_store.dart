import 'package:signals/signals.dart' as signals;

class FullscreenStore {
  FullscreenStore() : _state = signals.signal(false);

  final signals.Signal<bool> _state;
  bool get state => _state.value;
  signals.Signal<bool> get signal => _state;

  void toggle() {
    _state.value = !state;
  }
} 
