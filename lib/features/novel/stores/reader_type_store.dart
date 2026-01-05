import 'package:signals/signals.dart' as signals;
import 'package:wild/src/rust/api/database.dart';

enum ReaderType { normal, html }

class ReaderTypeStore {
  static const String _key = 'reader_type';
  static const ReaderType _defaultType = ReaderType.normal;

  ReaderTypeStore() : _state = signals.signal(_defaultType);

  final signals.Signal<ReaderType> _state;
  ReaderType get state => _state.value;
  signals.Signal<ReaderType> get signal => _state;

  Future<void> loadType() async {
    try {
      final savedValue = await loadProperty(key: _key);
      if (savedValue.isNotEmpty) {
        _state.value = ReaderType.values.firstWhere(
          (type) => type.toString() == savedValue,
          orElse: () => _defaultType,
        );
      }
    } catch (e) {
      // 如果加载失败，使用默认值
      _state.value = _defaultType;
    }
  }

  Future<void> updateType(ReaderType type) async {
    try {
      await saveProperty(key: _key, value: type.toString());
      _state.value = type;
    } catch (e) {
      // 如果保存失败，仍然更新状态
      _state.value = type;
    }
  }
} 
