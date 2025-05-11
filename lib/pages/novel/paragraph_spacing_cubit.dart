import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/src/rust/api/database.dart';

class ParagraphSpacingCubit extends Cubit<double> {
  static const double defaultSpacing = 24.0;
  static const String _key = 'paragraph_spacing';

  ParagraphSpacingCubit() : super(defaultSpacing);

  Future<void> loadSpacing() async {
    try {
      final savedValue = await loadProperty(key: _key);
      if (savedValue.isNotEmpty) {
        emit(double.parse(savedValue));
      }
    } catch (e) {
      // 如果加载失败，使用默认值
      emit(defaultSpacing);
    }
  }

  Future<void> updateSpacing(double spacing) async {
    try {
      await saveProperty(key: _key, value: spacing.toString());
      emit(spacing);
    } catch (e) {
      // 如果保存失败，仍然更新状态
      emit(spacing);
    }
  }
} 