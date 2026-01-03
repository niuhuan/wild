import 'package:signals/signals.dart' as signals;
import 'package:wild/src/rust/api/database.dart';

class ParagraphSpacingStore {
  static const double defaultSpacing = 24.0;
  static const String _key = 'paragraph_spacing';

  ParagraphSpacingStore() : _state = signals.signal(defaultSpacing);

  final signals.Signal<double> _state;
  double get state => _state.value;
  signals.Signal<double> get signal => _state;

  Future<void> loadSpacing() async {
    try {
      final savedValue = await loadProperty(key: _key);
      if (savedValue.isNotEmpty) {
        _state.value = double.parse(savedValue);
      }
    } catch (e) {
      // 如果加载失败，使用默认值
      _state.value = defaultSpacing;
    }
  }

  Future<void> updateSpacing(double spacing) async {
    try {
      await saveProperty(key: _key, value: spacing.toString());
      _state.value = spacing;
    } catch (e) {
      // 如果保存失败，仍然更新状态
      _state.value = spacing;
    }
  }
} 
