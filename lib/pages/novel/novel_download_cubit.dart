import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/src/rust/api/wenku8.dart';

class NovelDownloadState {
  final List<NovelDownload> downloads;
  final bool isLoading;
  final String? error;

  NovelDownloadState({
    this.downloads = const [],
    this.isLoading = false,
    this.error,
  });

  NovelDownloadState copyWith({
    List<NovelDownload>? downloads,
    bool? isLoading,
    String? error,
  }) {
    return NovelDownloadState(
      downloads: downloads ?? this.downloads,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class NovelDownloadCubit extends Cubit<NovelDownloadState> {
  NovelDownloadCubit() : super(NovelDownloadState());

  Future<void> loadDownloads() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final downloads = await allDownloads();
      emit(state.copyWith(downloads: downloads, isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }
} 