import 'package:flutter/material.dart';
import 'package:signals/signals.dart' as signals;
import 'package:wild/src/rust/api/database.dart';

enum ReaderThemeMode { auto, light, dark }

ReaderThemeMode readerThemeModeFromString(String mode) {
  for (final value in ReaderThemeMode.values) {
    if (value.toString() == mode) {
      return value;
    }
  }
  return ReaderThemeMode.auto;
}

class ThemeStore {
  static const String _keyThemeMode = 'reader_theme_mode';
  static const String _keyLightBackgroundColor =
      'reader_light_background_color';
  static const String _keyLightTextColor = 'reader_light_text_color';
  static const String _keyDarkBackgroundColor = 'reader_dark_background_color';
  static const String _keyDarkTextColor = 'reader_dark_text_color';

  ThemeStore() : _state = signals.signal(ReaderTheme.defaultTheme());

  final signals.Signal<ReaderTheme> _state;
  ReaderTheme get state => _state.value;
  signals.Signal<ReaderTheme> get signal => _state;

  Future<void> loadTheme() async {
    final themeModeStr = await loadProperty(key: _keyThemeMode);
    final ReaderThemeMode themeMode;
    if (themeModeStr.isEmpty) {
      themeMode = ReaderThemeMode.auto;
    } else {
      themeMode = readerThemeModeFromString(themeModeStr);
    }

    var lightBackgroundColor = await loadProperty(
      key: _keyLightBackgroundColor,
    );
    var lightTextColor = await loadProperty(key: _keyLightTextColor);
    var darkBackgroundColor = await loadProperty(key: _keyDarkBackgroundColor);
    var darkTextColor = await loadProperty(key: _keyDarkTextColor);

    if (lightBackgroundColor.isEmpty) {
      lightBackgroundColor = Colors.white.value.toString();
    }

    if (lightTextColor.isEmpty) {
      lightTextColor = Colors.black87.value.toString();
    }

    if (darkBackgroundColor.isEmpty) {
      darkBackgroundColor = const Color(0xFF1A1A1A).value.toString();
    }

    if (darkTextColor.isEmpty) {
      darkTextColor = const Color(0xFFE0E0E0).value.toString();
    }

    _state.value = ReaderTheme(
      themeMode: themeMode,
      lightBackgroundColor: Color(int.parse(lightBackgroundColor)),
      lightTextColor: Color(int.parse(lightTextColor)),
      darkBackgroundColor: Color(int.parse(darkBackgroundColor)),
      darkTextColor: Color(int.parse(darkTextColor)),
    );
  }

  Future<void> updateLightBackgroundColor(Color color) async {
    try {
      await saveProperty(key: _keyLightBackgroundColor, value: color.value.toString());
      _state.value = ReaderTheme(
        themeMode: state.themeMode,
        lightBackgroundColor: color,
        lightTextColor: state.lightTextColor,
        darkBackgroundColor: state.darkBackgroundColor,
        darkTextColor: state.darkTextColor,
      );
    } catch (e) {
      // 如果保存失败，仍然更新状态
      _state.value = ReaderTheme(
        themeMode: state.themeMode,
        lightBackgroundColor: color,
        lightTextColor: state.lightTextColor,
        darkBackgroundColor: state.darkBackgroundColor,
        darkTextColor: state.darkTextColor,
      );
    }
  }

  Future<void> updateLightTextColor(Color color) async {
    try {
      await saveProperty(key: _keyLightTextColor, value: color.value.toString());
      _state.value = ReaderTheme(
        themeMode: state.themeMode,
        lightBackgroundColor: state.lightBackgroundColor,
        lightTextColor: color,
        darkBackgroundColor: state.darkBackgroundColor,
        darkTextColor: state.darkTextColor,
      );
    } catch (e) {
      // 如果保存失败，仍然更新状态
      _state.value = ReaderTheme(
        themeMode: state.themeMode,
        lightBackgroundColor: state.lightBackgroundColor,
        lightTextColor: color,
        darkBackgroundColor: state.darkBackgroundColor,
        darkTextColor: state.darkTextColor,
      );
    }
  }

  Future<void> updateDarkBackgroundColor(Color color) async {
    try {
      await saveProperty(key: _keyDarkBackgroundColor, value: color.value.toString());
      _state.value = ReaderTheme(
        themeMode: state.themeMode,
        lightBackgroundColor: state.lightBackgroundColor,
        lightTextColor: state.lightTextColor,
        darkBackgroundColor: color,
        darkTextColor: state.darkTextColor,
      );
    } catch (e) {
      // 如果保存失败，仍然更新状态
      _state.value = ReaderTheme(
        themeMode: state.themeMode,
        lightBackgroundColor: state.lightBackgroundColor,
        lightTextColor: state.lightTextColor,
        darkBackgroundColor: color,
        darkTextColor: state.darkTextColor,
      );
    }
  }

  Future<void> updateDarkTextColor(Color color) async {
    try {
      await saveProperty(key: _keyDarkTextColor, value: color.value.toString());
      _state.value = ReaderTheme(
        themeMode: state.themeMode,
        lightBackgroundColor: state.lightBackgroundColor,
        lightTextColor: state.lightTextColor,
        darkBackgroundColor: state.darkBackgroundColor,
        darkTextColor: color,
      );
    } catch (e) {
      // 如果保存失败，仍然更新状态
      _state.value = ReaderTheme(
        themeMode: state.themeMode,
        lightBackgroundColor: state.lightBackgroundColor,
        lightTextColor: state.lightTextColor,
        darkBackgroundColor: state.darkBackgroundColor,
        darkTextColor: color,
      );
    }
  }

  Future<void> setThemeMode(ReaderThemeMode mode) async {
    try {
      await saveProperty(key: _keyThemeMode, value: mode.toString());
      _state.value = ReaderTheme(
        themeMode: mode,
        lightBackgroundColor: state.lightBackgroundColor,
        lightTextColor: state.lightTextColor,
        darkBackgroundColor: state.darkBackgroundColor,
        darkTextColor: state.darkTextColor,
      );
    } catch (e) {
      // 如果保存失败，仍然更新状态
      _state.value = ReaderTheme(
        themeMode: mode,
        lightBackgroundColor: state.lightBackgroundColor,
        lightTextColor: state.lightTextColor,
        darkBackgroundColor: state.darkBackgroundColor,
        darkTextColor: state.darkTextColor,
      );
    }
  }

  Future<void> resetToDefault() async {
    try {
      await saveProperty(key: _keyThemeMode, value: ReaderThemeMode.auto.toString());
      await saveProperty(key: _keyLightBackgroundColor, value: Colors.white.value.toString());
      await saveProperty(key: _keyLightTextColor, value: Colors.black87.value.toString());
      await saveProperty(key: _keyDarkBackgroundColor, value: const Color(0xFF1A1A1A).value.toString());
      await saveProperty(key: _keyDarkTextColor, value: const Color(0xFFE0E0E0).value.toString());
    } catch (e) {
      // 如果保存失败，仍然重置状态
    }
    _state.value = ReaderTheme.defaultTheme();
  }
}

class ReaderTheme {
  final ReaderThemeMode themeMode;
  final Color lightBackgroundColor;
  final Color lightTextColor;
  final Color darkBackgroundColor;
  final Color darkTextColor;

  ReaderTheme({
    required this.themeMode,
    required this.lightBackgroundColor,
    required this.lightTextColor,
    required this.darkBackgroundColor,
    required this.darkTextColor,
  });

  static ReaderTheme defaultTheme() {
    return ReaderTheme(
      themeMode: ReaderThemeMode.auto,
      lightBackgroundColor: Colors.white,
      lightTextColor: Colors.black87,
      darkBackgroundColor: const Color(0xFF1A1A1A),
      darkTextColor: const Color(0xFFE0E0E0),
    );
  }
}
