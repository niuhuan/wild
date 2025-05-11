import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/models/reader_page.dart';

import '../../src/rust/api/wenku8.dart';
import '../../src/rust/wenku8/models.dart';

class ReaderCubit extends Cubit<ReaderState> {
  final String initialAid;
  final String initialCid;
  final List<Volume> initialVolumes;
  String _currentAid;
  String _currentCid;
  List<ReaderPage> _pages = [];
  int _currentPage = 0;
  double _fontSize = 18.0;

  ReaderCubit({
    required this.initialAid,
    required this.initialCid,
    required this.initialVolumes,
  })  : _currentAid = initialAid,
        _currentCid = initialCid,
        super(ReaderInitial());

  Future<void> loadChapter({String? aid, String? cid}) async {
    if (aid != null && cid != null) {
      _currentAid = aid;
      _currentCid = cid;
    }

    emit(ReaderLoading());

    try {
      // 加载章节内容
      final content = await chapterContent(
        aid: _currentAid,
        cid: _currentCid,
      );
      _pages = _parseContent(content);
      _currentPage = 0;

      emit(ReaderLoaded(
        aid: _currentAid,
        cid: _currentCid,
        volumes: initialVolumes,
        pages: _pages,
        currentPage: _currentPage,
        fontSize: _fontSize,
        canGoPrevious: _canGoPrevious(),
        canGoNext: _canGoNext(),
      ));
    } catch (e) {
      emit(ReaderError(e.toString()));
    }
  }

  void onPageChanged(int index) {
    if (state is ReaderLoaded) {
      _currentPage = index;
      emit((state as ReaderLoaded).copyWith(
        currentPage: index,
        canGoPrevious: _canGoPrevious(),
        canGoNext: _canGoNext(),
      ));
    }
  }

  void updateFontSize(double size) {
    if (state is ReaderLoaded) {
      _fontSize = size;
      emit((state as ReaderLoaded).copyWith(fontSize: size));
    }
  }

  void goToPreviousChapter() {
    if (!_canGoPrevious()) return;

    final currentVolumeIndex = _findCurrentVolumeIndex();
    final currentChapterIndex = _findCurrentChapterIndex();
    
    if (currentChapterIndex > 0) {
      // 同一卷的上一章
      final chapter = initialVolumes[currentVolumeIndex].chapters[currentChapterIndex - 1];
      loadChapter(aid: chapter.aid, cid: chapter.cid);
    } else if (currentVolumeIndex > 0) {
      // 上一卷的最后一章
      final prevVolume = initialVolumes[currentVolumeIndex - 1];
      final chapter = prevVolume.chapters.last;
      loadChapter(aid: chapter.aid, cid: chapter.cid);
    }
  }

  void goToNextChapter() {
    if (!_canGoNext()) return;

    final currentVolumeIndex = _findCurrentVolumeIndex();
    final currentChapterIndex = _findCurrentChapterIndex();
    
    if (currentChapterIndex < initialVolumes[currentVolumeIndex].chapters.length - 1) {
      // 同一卷的下一章
      final chapter = initialVolumes[currentVolumeIndex].chapters[currentChapterIndex + 1];
      loadChapter(aid: chapter.aid, cid: chapter.cid);
    } else if (currentVolumeIndex < initialVolumes.length - 1) {
      // 下一卷的第一章
      final nextVolume = initialVolumes[currentVolumeIndex + 1];
      final chapter = nextVolume.chapters.first;
      loadChapter(aid: chapter.aid, cid: chapter.cid);
    }
  }

  bool _canGoPrevious() {
    if (initialVolumes.isEmpty) return false;
    final currentVolumeIndex = _findCurrentVolumeIndex();
    final currentChapterIndex = _findCurrentChapterIndex();
    return currentChapterIndex > 0 || currentVolumeIndex > 0;
  }

  bool _canGoNext() {
    if (initialVolumes.isEmpty) return false;
    final currentVolumeIndex = _findCurrentVolumeIndex();
    final currentChapterIndex = _findCurrentChapterIndex();
    return currentChapterIndex < initialVolumes[currentVolumeIndex].chapters.length - 1 ||
        currentVolumeIndex < initialVolumes.length - 1;
  }

  int _findCurrentVolumeIndex() {
    for (var i = 0; i < initialVolumes.length; i++) {
      final volume = initialVolumes[i];
      if (volume.chapters.any((chapter) => chapter.aid == _currentAid && chapter.cid == _currentCid)) {
        return i;
      }
    }
    return -1;
  }

  int _findCurrentChapterIndex() {
    final volumeIndex = _findCurrentVolumeIndex();
    if (volumeIndex == -1) return -1;
    final volume = initialVolumes[volumeIndex];
    for (var i = 0; i < volume.chapters.length; i++) {
      final chapter = volume.chapters[i];
      if (chapter.aid == _currentAid && chapter.cid == _currentCid) {
        return i;
      }
    }
    return -1;
  }

  List<ReaderPage> _parseContent(String content) {
    final pages = <ReaderPage>[];
    final lines = content.split('\n');
    var currentPage = StringBuffer();
    var inImage = false;
    var imageUrl = '';

    for (var line in lines) {
      if (line.contains('<!--image-->')) {
        if (!inImage) {
          // 开始图片标记
          if (currentPage.isNotEmpty) {
            pages.add(ReaderPage(
              content: currentPage.toString().trim(),
              isImage: false,
            ));
            currentPage.clear();
          }
          inImage = true;
          imageUrl = line.replaceAll('<!--image-->', '').trim();
        } else {
          // 结束图片标记
          pages.add(ReaderPage(
            content: imageUrl,
            isImage: true,
          ));
          inImage = false;
          imageUrl = '';
        }
      } else if (!inImage) {
        currentPage.writeln(line);
        // 每1000个字符分一页
        if (currentPage.length > 1000) {
          pages.add(ReaderPage(
            content: currentPage.toString().trim(),
            isImage: false,
          ));
          currentPage.clear();
        }
      }
    }

    // 添加最后一页
    if (currentPage.isNotEmpty) {
      pages.add(ReaderPage(
        content: currentPage.toString().trim(),
        isImage: false,
      ));
    }

    return pages;
  }
}

abstract class ReaderState {}

class ReaderInitial extends ReaderState {}

class ReaderLoading extends ReaderState {}

class ReaderError extends ReaderState {
  final String error;

  ReaderError(this.error);
}

class ReaderLoaded extends ReaderState {
  final String aid;
  final String cid;
  final List<Volume> volumes;
  final List<ReaderPage> pages;
  final int currentPage;
  final double fontSize;
  final bool canGoPrevious;
  final bool canGoNext;

  ReaderLoaded({
    required this.aid,
    required this.cid,
    required this.volumes,
    required this.pages,
    required this.currentPage,
    required this.fontSize,
    required this.canGoPrevious,
    required this.canGoNext,
  });

  ReaderLoaded copyWith({
    String? aid,
    String? cid,
    List<Volume>? volumes,
    List<ReaderPage>? pages,
    int? currentPage,
    double? fontSize,
    bool? canGoPrevious,
    bool? canGoNext,
  }) {
    return ReaderLoaded(
      aid: aid ?? this.aid,
      cid: cid ?? this.cid,
      volumes: volumes ?? this.volumes,
      pages: pages ?? this.pages,
      currentPage: currentPage ?? this.currentPage,
      fontSize: fontSize ?? this.fontSize,
      canGoPrevious: canGoPrevious ?? this.canGoPrevious,
      canGoNext: canGoNext ?? this.canGoNext,
    );
  }
}