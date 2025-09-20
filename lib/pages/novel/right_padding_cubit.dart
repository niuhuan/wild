import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/src/rust/api/database.dart';

class RightPaddingCubit extends Cubit<double> {
  static const double defaultPadding = 16.0;
  static const String _key = 'right_padding';

  RightPaddingCubit() : super(defaultPadding);

  Future<void> loadPadding() async {
    try {
      final savedValue = await loadProperty(key: _key);
      if (savedValue.isNotEmpty) {
        emit(double.parse(savedValue));
      }
    } catch (e) {
      // 如果加载失败，使用默认值
      emit(defaultPadding);
    }
  }

  Future<void> updatePadding(double padding) async {
    try {
      await saveProperty(key: _key, value: padding.toString());
      emit(padding);
    } catch (e) {
      // 如果保存失败，仍然更新状态
      emit(padding);
    }
  }
}
