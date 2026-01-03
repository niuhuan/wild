import 'package:wild/src/rust/api/wenku8.dart' as w8;
import 'package:wild/src/rust/wenku8/models.dart';
import 'package:signals/signals.dart' as signals;

abstract class NovelDownloadInfoState {}

class NovelDownloadInfoInitial extends NovelDownloadInfoState {}

class NovelDownloadInfoLoading extends NovelDownloadInfoState {}

class NovelDownloadInfoLoaded extends NovelDownloadInfoState {
  final w8.ExistsDownload download;
  final List<Volume> volumes;
  final w8.ReadingHistory? readingHistory;

  NovelDownloadInfoLoaded({
    required this.download,
    required this.volumes,
    this.readingHistory,
  });
}

class NovelDownloadInfoError extends NovelDownloadInfoState {
  final String message;

  NovelDownloadInfoError(this.message);
}

class NovelDownloadInfoStore {
  final String novelId;
  List<Volume> _volumes = [];

  NovelDownloadInfoStore(this.novelId)
      : _state =
            signals.signal<NovelDownloadInfoState>(NovelDownloadInfoInitial());

  final signals.Signal<NovelDownloadInfoState> _state;
  NovelDownloadInfoState get state => _state.value;
  signals.Signal<NovelDownloadInfoState> get signal => _state;

  List<Volume> get volumes => _volumes;

  Future<void> load() async {
    try {
      final download = await w8.existsDownload(novelId: novelId);
      if (download == null) {
        _state.value = NovelDownloadInfoError('未找到下载信息');
        return;
      }

      // 从下载数据构建卷和章节列表
      final volumes = download.novelDownloadVolume
          .map((volume) {
            final chapters = download.novelDownloadChapter
                .where((chapter) => chapter.volumeId == volume.id)
                .map((chapter) => Chapter(
                      aid: chapter.aid,
                      cid: chapter.id,
                      title: chapter.title,
                      url: chapter.url,
                    ))
                .toList();
            // 只返回有章节的卷
            if (chapters.isEmpty) return null;
            return Volume(
              id: volume.id,
              title: volume.title,
              chapters: chapters,
            );
          })
          .where((volume) => volume != null) // 过滤掉 null
          .map((volume) => volume!) // 将非空的卷转换为非空类型
          .toList();

      final history = await w8.novelHistoryById(novelId: novelId);
      _state.value = NovelDownloadInfoLoaded(
        download: download,
        volumes: volumes,
        readingHistory: history,
      );
    } catch (e) {
      _state.value = NovelDownloadInfoError(e.toString());
    }
  }

  Future<void> loadHistory() async {
    final readingHistory = await w8.novelHistoryById(novelId: novelId);
    if (state is NovelDownloadInfoLoaded) {
      final currentState = state as NovelDownloadInfoLoaded;
      _state.value = NovelDownloadInfoLoaded(
        download: currentState.download,
        volumes: currentState.volumes,
        readingHistory: readingHistory,
      );
    }
  }

  Future<void> deleteDownload() async {
    try {
      await w8.deleteDownload(novelId: novelId);
    } catch (e) {
      if (state is NovelDownloadInfoLoaded) {
        _state.value = NovelDownloadInfoError(e.toString());
      }
    }
  }
} 
