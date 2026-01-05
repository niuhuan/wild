import 'dart:io';

import 'package:signals/signals.dart' as signals;
import 'package:wild/src/rust/api/database.dart';

class VolumeControlStore {
  VolumeControlStore() : _state = signals.signal(false);

  static const String _key = "_volumeControlProperty";

  final signals.Signal<bool> _state;
  bool get state => _state.value;
  signals.Signal<bool> get signal => _state;

  Future<void> init() async {
    if (!Platform.isAndroid) {
      // 非安卓平台默认为 false
      _state.value = false;
      return;
    }

    try {
      final value = await loadProperty(key: _key);
      if (value.isNotEmpty) {
        final parsed = bool.tryParse(value);
        if (parsed != null) {
          _state.value = parsed;
        } else {
          _state.value = false;
        }
      } else {
        _state.value = false;
      }
    } catch (e) {
      _state.value = false;
    }
  }

  Future<void> updateVolumeControl(bool enabled) async {
    if (!Platform.isAndroid) {
      return; // 非安卓平台不支持
    }

    try {
      await saveProperty(key: _key, value: enabled.toString());
      _state.value = enabled;
    } catch (e) {
      // 保存失败，保持原状态
    }
  }

  bool get isEnabled => state;
}
