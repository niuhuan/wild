import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

class ReaderBackgroundCubit extends Cubit<ReaderBackgroundState> {
  String? _rootPath;
  
  ReaderBackgroundCubit() : super(const ReaderBackgroundState());

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
    
    emit(ReaderBackgroundState(
      lightBackgroundExists: lightExists,
      darkBackgroundExists: darkExists,
    ));
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
        
        emit(state.copyWith(lightBackgroundExists: true));
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
        
        emit(state.copyWith(darkBackgroundExists: true));
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
      
      emit(state.copyWith(lightBackgroundExists: false));
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
      
      emit(state.copyWith(darkBackgroundExists: false));
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
}

class ReaderBackgroundState {
  final bool lightBackgroundExists;
  final bool darkBackgroundExists;

  const ReaderBackgroundState({
    this.lightBackgroundExists = false,
    this.darkBackgroundExists = false,
  });

  ReaderBackgroundState copyWith({
    bool? lightBackgroundExists,
    bool? darkBackgroundExists,
  }) {
    return ReaderBackgroundState(
      lightBackgroundExists: lightBackgroundExists ?? this.lightBackgroundExists,
      darkBackgroundExists: darkBackgroundExists ?? this.darkBackgroundExists,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderBackgroundState &&
          runtimeType == other.runtimeType &&
          lightBackgroundExists == other.lightBackgroundExists &&
          darkBackgroundExists == other.darkBackgroundExists;

  @override
  int get hashCode =>
      lightBackgroundExists.hashCode ^ darkBackgroundExists.hashCode;
}
