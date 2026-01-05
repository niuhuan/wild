import 'package:signals/signals.dart' as signals;
import 'package:wild/src/rust/api/database.dart';

class FontSizeStore {
  static const double defaultFontSize = 18.0;
  static const String _key = 'font_size';

  FontSizeStore() : _state = signals.signal(defaultFontSize);

  final signals.Signal<double> _state;
  double get state => _state.value;
  signals.Signal<double> get signal => _state;

  Future<void> loadFontSize() async {
    try {
      final savedValue = await loadProperty(key: _key);
      if (savedValue.isNotEmpty) {
        _state.value = double.parse(savedValue);
      }
    } catch (e) {
      // 如果加载失败，使用默认值
      _state.value = defaultFontSize;
    }
  }

  Future<void> updateFontSize(double size) async {
    try {
      await saveProperty(key: _key, value: size.toString());
      _state.value = size;
    } catch (e) {
      // 如果保存失败，仍然更新状态
      _state.value = size;
    }
  }
} 
