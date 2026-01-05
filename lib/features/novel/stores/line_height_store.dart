import 'package:signals/signals.dart' as signals;
import 'package:wild/src/rust/api/database.dart';

class LineHeightStore {
  static const double defaultLineHeight = 1.3;
  static const String _key = 'line_height';

  LineHeightStore() : _state = signals.signal(defaultLineHeight);

  final signals.Signal<double> _state;
  double get state => _state.value;
  signals.Signal<double> get signal => _state;

  Future<void> loadLineHeight() async {
    try {
      final savedValue = await loadProperty(key: _key);
      if (savedValue.isNotEmpty) {
        _state.value = double.parse(savedValue);
      }
    } catch (e) {
      // 如果加载失败，使用默认值
      _state.value = defaultLineHeight;
    }
  }

  Future<void> updateLineHeight(double height) async {
    try {
      await saveProperty(key: _key, value: height.toString());
      _state.value = height;
    } catch (e) {
      // 如果保存失败，仍然更新状态
      _state.value = height;
    }
  }
}
