import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/src/rust/api/wenku8.dart';

class ApiHostCubit extends Cubit<String> {
  ApiHostCubit() : super('') {
    _loadApiHost();
  }

  Future<void> _loadApiHost() async {
    try {
      final apiHost = await getApiHost();
      emit(apiHost);
    } catch (e) {
      // 如果获取失败，使用默认值
      emit('');
    }
  }

  Future<void> updateApiHost(String apiHost) async {
    try {
      await setApiHost(apiHost: apiHost);
      emit(apiHost);
    } catch (e) {
      // 如果设置失败，重新加载当前值
      await _loadApiHost();
      rethrow;
    }
  }

  Future<void> resetToDefault() async {
    try {
      await setApiHost(apiHost: '');
      await _loadApiHost();
    } catch (e) {
      // 如果重置失败，重新加载当前值
      await _loadApiHost();
      rethrow;
    }
  }
}
