import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/src/rust/api/database.dart';

class LineHeightCubit extends Cubit<double> {
  static const double defaultLineHeight = 1.3;
  static const String _key = 'line_height';

  LineHeightCubit() : super(defaultLineHeight);

  Future<void> loadLineHeight() async {
    try {
      final savedValue = await loadProperty(key: _key);
      if (savedValue.isNotEmpty) {
        emit(double.parse(savedValue));
      }
    } catch (e) {
      // 如果加载失败，使用默认值
      emit(defaultLineHeight);
    }
  }

  Future<void> updateLineHeight(double height) async {
    try {
      await saveProperty(key: _key, value: height.toString());
      emit(height);
    } catch (e) {
      // 如果保存失败，仍然更新状态
      emit(height);
    }
  }
}
