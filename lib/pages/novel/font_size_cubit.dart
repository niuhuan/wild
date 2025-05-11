import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/src/rust/api/database.dart';

class FontSizeCubit extends Cubit<double> {
  static const double defaultFontSize = 18.0;
  static const String _key = 'font_size';

  FontSizeCubit() : super(defaultFontSize);

  Future<void> loadFontSize() async {
    try {
      final savedValue = await loadProperty(key: _key);
      if (savedValue.isNotEmpty) {
        emit(double.parse(savedValue));
      }
    } catch (e) {
      // 如果加载失败，使用默认值
      emit(defaultFontSize);
    }
  }

  Future<void> updateFontSize(double size) async {
    try {
      await saveProperty(key: _key, value: size.toString());
      emit(size);
    } catch (e) {
      // 如果保存失败，仍然更新状态
      emit(size);
    }
  }
} 