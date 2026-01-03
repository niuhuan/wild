import 'package:wild/src/rust/api/wenku8.dart';
import 'package:signals/signals.dart' as signals;

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

class NovelDownloadStore {
  NovelDownloadStore() : _state = signals.signal(NovelDownloadState());

  final signals.Signal<NovelDownloadState> _state;
  NovelDownloadState get state => _state.value;
  signals.Signal<NovelDownloadState> get signal => _state;

  Future<void> loadDownloads() async {
    _state.value = state.copyWith(isLoading: true, error: null);
    try {
      final downloads = await allDownloads();
      _state.value = state.copyWith(downloads: downloads, isLoading: false);
    } catch (e) {
      _state.value = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
} 
