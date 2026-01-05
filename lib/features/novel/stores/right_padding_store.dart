import 'package:signals/signals.dart' as signals;
import 'package:wild/src/rust/api/database.dart';

class RightPaddingStore {
  static const double defaultPadding = 16.0;
  static const String _key = 'right_padding';

  RightPaddingStore() : _state = signals.signal(defaultPadding);

  final signals.Signal<double> _state;
  double get state => _state.value;
  signals.Signal<double> get signal => _state;

  Future<void> loadPadding() async {
    try {
      final savedValue = await loadProperty(key: _key);
      if (savedValue.isNotEmpty) {
        _state.value = double.parse(savedValue);
      }
    } catch (e) {
      // 如果加载失败，使用默认值
      _state.value = defaultPadding;
    }
  }

  Future<void> updatePadding(double padding) async {
    try {
      await saveProperty(key: _key, value: padding.toString());
      _state.value = padding;
    } catch (e) {
      // 如果保存失败，仍然更新状态
      _state.value = padding;
    }
  }
}
