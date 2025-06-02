import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/src/rust/api/database.dart';

enum ReaderType { normal, html }

class ReaderTypeCubit extends Cubit<ReaderType> {
  static const String _key = 'reader_type';
  static const ReaderType _defaultType = ReaderType.normal;

  ReaderTypeCubit() : super(_defaultType);

  Future<void> loadType() async {
    try {
      final savedValue = await loadProperty(key: _key);
      if (savedValue.isNotEmpty) {
        emit(ReaderType.values.firstWhere(
          (type) => type.toString() == savedValue,
          orElse: () => _defaultType,
        ));
      }
    } catch (e) {
      // 如果加载失败，使用默认值
      emit(_defaultType);
    }
  }

  Future<void> updateType(ReaderType type) async {
    try {
      await saveProperty(key: _key, value: type.toString());
      emit(type);
    } catch (e) {
      // 如果保存失败，仍然更新状态
      emit(type);
    }
  }
} 