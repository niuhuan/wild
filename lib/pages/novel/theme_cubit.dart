import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../src/rust/api/database.dart';

enum ReaderThemeMode { auto, light, dark }

ReaderThemeMode readerThemeModeFromString(String mode) {
  for (final value in ReaderThemeMode.values) {
    if (value.toString() == mode) {
      return value;
    }
  }
  return ReaderThemeMode.auto;
}

class ThemeCubit extends Cubit<ReaderTheme> {
  static const String _keyThemeMode = 'reader_theme_mode';
  static const String _keyLightBackgroundColor =
      'reader_light_background_color';
  static const String _keyLightTextColor = 'reader_light_text_color';
  static const String _keyDarkBackgroundColor = 'reader_dark_background_color';
  static const String _keyDarkTextColor = 'reader_dark_text_color';

  ThemeCubit() : super(ReaderTheme.defaultTheme());

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

    emit(
      ReaderTheme(
        themeMode: themeMode,
        lightBackgroundColor: Color(int.parse(lightBackgroundColor)),
        lightTextColor: Color(int.parse(lightTextColor)),
        darkBackgroundColor: Color(int.parse(darkBackgroundColor)),
        darkTextColor: Color(int.parse(darkTextColor)),
      ),
    );
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