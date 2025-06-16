import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/src/rust/api/database.dart';

class AutoScrollConfigCubit extends Cubit<AutoScrollConfig> {
  static const double defaultScrollSpeed = 1.0;
  static const int defaultScrollInterval = 16;
  static const String _scrollSpeedKey = 'auto_scroll_speed';
  static const String _scrollIntervalKey = 'auto_scroll_interval';

  AutoScrollConfigCubit()
      : super(AutoScrollConfig(
          scrollSpeed: defaultScrollSpeed,
          scrollInterval: defaultScrollInterval,
        ));

  Future<void> loadConfig() async {
    try {
      final savedSpeed = await loadProperty(key: _scrollSpeedKey);
      final savedInterval = await loadProperty(key: _scrollIntervalKey);
      
      double scrollSpeed = defaultScrollSpeed;
      int scrollInterval = defaultScrollInterval;

      if (savedSpeed.isNotEmpty) {
        scrollSpeed = double.parse(savedSpeed);
      }
      if (savedInterval.isNotEmpty) {
        scrollInterval = int.parse(savedInterval);
      }

      emit(AutoScrollConfig(
        scrollSpeed: scrollSpeed,
        scrollInterval: scrollInterval,
      ));
    } catch (e) {
      // 如果加载失败，使用默认值
      emit(AutoScrollConfig(
        scrollSpeed: defaultScrollSpeed,
        scrollInterval: defaultScrollInterval,
      ));
    }
  }

  Future<void> updateScrollSpeed(double speed) async {
    try {
      await saveProperty(key: _scrollSpeedKey, value: speed.toString());
      emit(state.copyWith(scrollSpeed: speed));
    } catch (e) {
      // 如果保存失败，仍然更新状态
      emit(state.copyWith(scrollSpeed: speed));
    }
  }

  Future<void> updateScrollInterval(int interval) async {
    try {
      await saveProperty(key: _scrollIntervalKey, value: interval.toString());
      emit(state.copyWith(scrollInterval: interval));
    } catch (e) {
      // 如果保存失败，仍然更新状态
      emit(state.copyWith(scrollInterval: interval));
    }
  }
}

class AutoScrollConfig {
  final double scrollSpeed;
  final int scrollInterval;

  const AutoScrollConfig({
    required this.scrollSpeed,
    required this.scrollInterval,
  });

  AutoScrollConfig copyWith({
    double? scrollSpeed,
    int? scrollInterval,
  }) {
    return AutoScrollConfig(
      scrollSpeed: scrollSpeed ?? this.scrollSpeed,
      scrollInterval: scrollInterval ?? this.scrollInterval,
    );
  }
} 