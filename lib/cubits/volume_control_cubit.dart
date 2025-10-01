import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/src/rust/api/database.dart';

class VolumeControlCubit extends Cubit<bool> {
  VolumeControlCubit() : super(false);

  static const String _key = "_volumeControlProperty";

  Future<void> init() async {
    if (!Platform.isAndroid) {
      // 非安卓平台默认为 false
      emit(false);
      return;
    }

    try {
      final value = await loadProperty(key: _key);
      if (value.isNotEmpty) {
        final parsed = bool.tryParse(value);
        if (parsed != null) {
          emit(parsed);
        } else {
          emit(false);
        }
      } else {
        emit(false);
      }
    } catch (e) {
      emit(false);
    }
  }

  Future<void> updateVolumeControl(bool enabled) async {
    if (!Platform.isAndroid) {
      return; // 非安卓平台不支持
    }

    try {
      await saveProperty(key: _key, value: enabled.toString());
      emit(enabled);
    } catch (e) {
      // 保存失败，保持原状态
    }
  }

  bool get isEnabled => state;
}
