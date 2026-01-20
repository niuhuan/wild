import 'package:pinyin/pinyin.dart';
import 'package:signals/signals.dart' as signals;
import 'package:wild/src/rust/api/database.dart';

enum ChineseConversionMode { none, toSimplified, toTraditional }

class ChineseConversionStore {
  ChineseConversionStore() : _state = signals.signal(ChineseConversionMode.none);

  static const String _key = '_chineseConversionMode';

  final signals.Signal<ChineseConversionMode> _state;
  ChineseConversionMode get state => _state.value;
  signals.Signal<ChineseConversionMode> get signal => _state;

  Future<void> init() async {
    try {
      final value = await loadProperty(key: _key);
      _state.value = _parse(value) ?? ChineseConversionMode.none;
    } catch (e) {
      _state.value = ChineseConversionMode.none;
    }
  }

  Future<void> updateMode(ChineseConversionMode mode) async {
    try {
      await saveProperty(key: _key, value: _encode(mode));
      _state.value = mode;
    } catch (e) {
      // 保存失败则保持原状态
    }
  }

  String convert(String input) {
    switch (state) {
      case ChineseConversionMode.none:
        return input;
      case ChineseConversionMode.toSimplified:
        return ChineseHelper.convertToSimplifiedChinese(input);
      case ChineseConversionMode.toTraditional:
        return ChineseHelper.convertToTraditionalChinese(input);
    }
  }

  static ChineseConversionMode? _parse(String value) {
    switch (value) {
      case 'none':
        return ChineseConversionMode.none;
      case 'toSimplified':
        return ChineseConversionMode.toSimplified;
      case 'toTraditional':
        return ChineseConversionMode.toTraditional;
      default:
        return null;
    }
  }

  static String _encode(ChineseConversionMode mode) {
    switch (mode) {
      case ChineseConversionMode.none:
        return 'none';
      case ChineseConversionMode.toSimplified:
        return 'toSimplified';
      case ChineseConversionMode.toTraditional:
        return 'toTraditional';
    }
  }
}

