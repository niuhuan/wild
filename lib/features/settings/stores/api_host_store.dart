import 'package:signals/signals.dart' as signals;
import 'package:wild/src/rust/api/wenku8.dart';

class ApiHostStore {
  ApiHostStore() : _state = signals.signal('') {
    _loadApiHost();
  }

  final signals.Signal<String> _state;
  String get state => _state.value;
  signals.Signal<String> get signal => _state;

  Future<void> _loadApiHost() async {
    try {
      final apiHost = await getApiHost();
      _state.value = apiHost;
    } catch (e) {
      // 如果获取失败，使用默认值
      _state.value = '';
    }
  }

  Future<void> updateApiHost(String apiHost) async {
    try {
      await setApiHost(apiHost: apiHost);
      _state.value = apiHost;
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
