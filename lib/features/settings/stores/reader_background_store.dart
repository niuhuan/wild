import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:signals/signals.dart' as signals;

class ReaderBackgroundStore {
  String? _rootPath;
  
  ReaderBackgroundStore() : _state = signals.signal(const ReaderBackgroundState());

  final signals.Signal<ReaderBackgroundState> _state;
  ReaderBackgroundState get state => _state.value;
  signals.Signal<ReaderBackgroundState> get signal => _state;

  Future<void> init(String root) async {
    _rootPath = root;
    await _checkBackgroundImages();
  }

  Future<void> _checkBackgroundImages() async {
    if (_rootPath == null) return;
    
    final lightPath = '$_rootPath/light_reader_background.png';
    final darkPath = '$_rootPath/dark_reader_background.png';
    
    final lightExists = await File(lightPath).exists();
    final darkExists = await File(darkPath).exists();
    
    _state.value = ReaderBackgroundState(
      lightBackgroundExists: lightExists,
      darkBackgroundExists: darkExists,
    );
  }

  Future<void> updateLightBackground() async {
    if (_rootPath == null) return;
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        final file = File('$_rootPath/light_reader_background.png');
        await file.writeAsBytes(bytes);
        
        _state.value = state.copyWith(lightBackgroundExists: true);
      }
    } catch (e) {
      // 处理错误
      print('Error updating light background: $e');
    }
  }

  Future<void> updateDarkBackground() async {
    if (_rootPath == null) return;
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        final file = File('$_rootPath/dark_reader_background.png');
        await file.writeAsBytes(bytes);
        
        _state.value = state.copyWith(darkBackgroundExists: true);
      }
    } catch (e) {
      // 处理错误
      print('Error updating dark background: $e');
    }
  }

  Future<void> deleteLightBackground() async {
    if (_rootPath == null) return;
    
    try {
      final file = File('$_rootPath/light_reader_background.png');
      if (await file.exists()) {
        await file.delete();
      }
      
      _state.value = state.copyWith(lightBackgroundExists: false);
    } catch (e) {
      // 处理错误
      print('Error deleting light background: $e');
    }
  }

  Future<void> deleteDarkBackground() async {
    if (_rootPath == null) return;
    
    try {
      final file = File('$_rootPath/dark_reader_background.png');
      if (await file.exists()) {
        await file.delete();
      }
      
      _state.value = state.copyWith(darkBackgroundExists: false);
    } catch (e) {
      // 处理错误
      print('Error deleting dark background: $e');
    }
  }

  String? getLightBackgroundPath() {
    if (_rootPath == null || !state.lightBackgroundExists) return null;
    return '$_rootPath/light_reader_background.png';
  }

  String? getDarkBackgroundPath() {
    if (_rootPath == null || !state.darkBackgroundExists) return null;
    return '$_rootPath/dark_reader_background.png';
  }

  Future<void> updateOpacity(double opacity) async {
    _state.value = state.copyWith(opacity: opacity);
  }
}

class ReaderBackgroundState {
  final bool lightBackgroundExists;
  final bool darkBackgroundExists;
  final double opacity;

  const ReaderBackgroundState({
    this.lightBackgroundExists = false,
    this.darkBackgroundExists = false,
    this.opacity = 0.1,
  });

  ReaderBackgroundState copyWith({
    bool? lightBackgroundExists,
    bool? darkBackgroundExists,
    double? opacity,
  }) {
    return ReaderBackgroundState(
      lightBackgroundExists: lightBackgroundExists ?? this.lightBackgroundExists,
      darkBackgroundExists: darkBackgroundExists ?? this.darkBackgroundExists,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderBackgroundState &&
          runtimeType == other.runtimeType &&
          lightBackgroundExists == other.lightBackgroundExists &&
          darkBackgroundExists == other.darkBackgroundExists &&
          opacity == other.opacity;

  @override
  int get hashCode =>
      lightBackgroundExists.hashCode ^ 
      darkBackgroundExists.hashCode ^ 
      opacity.hashCode;
}
