import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/src/rust/api/database.dart';

class TopBarHeightCubit extends Cubit<double> {
  static const double defaultHeight = 56.0;
  static const String _key = 'top_bar_height';

  TopBarHeightCubit() : super(defaultHeight);

  Future<void> loadHeight() async {
    try {
      final savedValue = await loadProperty(key: _key);
      if (savedValue.isNotEmpty) {
        emit(double.parse(savedValue));
      }
    } catch (e) {
      // 如果加载失败，使用默认值
      emit(defaultHeight);
    }
  }

  Future<void> updateHeight(double height) async {
    try {
      await saveProperty(key: _key, value: height.toString());
      emit(height);
    } catch (e) {
      // 如果保存失败，仍然更新状态
      emit(height);
    }
  }
} 