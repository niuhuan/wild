import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/models/reader_page.dart';
import 'package:flutter/rendering.dart';
import 'package:wild/src/rust/api/wenku8.dart';

import '../../src/rust/wenku8/models.dart';

class ReaderCubit extends Cubit<ReaderState> {
  final String initialAid;
  final String initialCid;
  final List<Volume> initialVolumes;
  final _textPainter = TextPainter(
    textDirection: TextDirection.ltr,
    maxLines: null,
  );

  ReaderCubit({
    required this.initialAid,
    required this.initialCid,
    required this.initialVolumes,
  }) : super(ReaderInitial());

  String _findChapterTitle(String aid, String cid) {
    for (final volume in initialVolumes) {
      for (final chapter in volume.chapters) {
        if (chapter.aid == aid && chapter.cid == cid) {
          return chapter.title;
        }
      }
    }
    return '';
  }

  Future<void> loadChapter({String? aid, String? cid}) async {
    final targetAid = aid ?? initialAid;
    final targetCid = cid ?? initialCid;
    emit(ReaderLoading());
    try {
      final content = await chapterContent(aid: targetAid, cid: targetCid);
      final title = _findChapterTitle(targetAid, targetCid);
      final pages = _splitIntoPages(content, targetAid);
      emit(ReaderLoaded(
        aid: targetAid,
        cid: targetCid,
        title: title,
        content: content,
        pages: pages,
        volumes: initialVolumes,
        fontSize: 18.0,
        currentPageIndex: 0,
      ));
    } catch (e) {
      emit(ReaderError(e.toString()));
    }
  }

  void onPageChanged(int index) {
    if (state is ReaderLoaded) {
      emit((state as ReaderLoaded).copyWith(
        currentPageIndex: index,
      ));
    }
  }

  void updateFontSize(double size) {
    if (state is ReaderLoaded) {
      final currentState = state as ReaderLoaded;
      // 保存当前页码
      final currentPageIndex = currentState.currentPageIndex;
      // 重新计算分页
      final pages = _splitIntoPages(currentState.content, currentState.aid);
      // 确保新的页码索引有效
      final newPageIndex = currentPageIndex < pages.length ? currentPageIndex : 0;
      
      emit(ReaderLoaded(
        aid: currentState.aid,
        cid: currentState.cid,
        title: currentState.title,
        content: currentState.content,
        pages: pages,
        volumes: currentState.volumes,
        fontSize: size,
        currentPageIndex: newPageIndex,
      ));
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
      if (volume.chapters.any((chapter) => chapter.aid == initialAid && chapter.cid == initialCid)) {
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
      if (chapter.aid == initialAid && chapter.cid == initialCid) {
        return i;
      }
    }
    return -1;
  }

  List<ReaderPage> _splitIntoPages(String content, String aid) {
    final pages = <ReaderPage>[];
    final paragraphs = content.split('\n');
    final screenWidth = MediaQueryData.fromView(WidgetsBinding.instance.window).size.width - 32;
    final screenHeight = MediaQueryData.fromView(WidgetsBinding.instance.window).size.height;
    final topPadding = MediaQueryData.fromView(WidgetsBinding.instance.window).padding.top;
    final bottomPadding = MediaQueryData.fromView(WidgetsBinding.instance.window).padding.bottom;
    final topBarHeight = 56.0;
    final bottomBarHeight = 56.0;
    final canvasHeight = screenHeight - topPadding - bottomPadding - topBarHeight - bottomBarHeight + 16;

    final currentFontSize = state is ReaderLoaded ? (state as ReaderLoaded).fontSize : 18.0;
    final textStyle = TextStyle(
      fontSize: currentFontSize,
      height: 1.5,
      letterSpacing: 0.5,
    );

    _textPainter.textDirection = TextDirection.ltr;

    var currentPage = StringBuffer();
    var currentHeight = 0.0;
    var lastParagraphHeight = 0.0;
    var isFirstParagraph = true;

    for (var paragraph in paragraphs) {
      if (paragraph.trim().isEmpty) {
        if (currentPage.isNotEmpty) {
          currentPage.write('\n');
          currentHeight += 24; // 段落间距
        }
        continue;
      }

      // 测量当前段落的高度
      _textPainter.text = TextSpan(text: paragraph, style: textStyle);
      _textPainter.layout(maxWidth: screenWidth);
      lastParagraphHeight = _textPainter.height;

      // 如果是新页面的第一个段落，直接添加
      if (currentPage.isEmpty) {
        currentPage.write(paragraph);
        currentHeight = lastParagraphHeight;
        isFirstParagraph = false;
        continue;
      }

      // 如果添加这个段落后会超过画布高度，且当前页面已经有内容，则创建新页面
      if (currentHeight + 24 + lastParagraphHeight > canvasHeight) {
        // 只有当当前页面内容超过画布高度的一半时才创建新页面
        if (currentHeight > canvasHeight * 0.5) {
          pages.add(ReaderPage(
            content: currentPage.toString(),
            isImage: false,
          ));
          currentPage.clear();
          currentHeight = 0.0;
          isFirstParagraph = true;
          // 重新处理当前段落
          continue;
        }
      }

      // 添加段落到当前页面
      currentPage.write('\n');
      currentPage.write(paragraph);
      currentHeight += 24 + lastParagraphHeight; // 段落间距 + 段落高度
      isFirstParagraph = false;
    }

    // 添加最后一页
    if (currentPage.isNotEmpty) {
      // 如果最后一页内容太少，尝试合并到前一页
      if (pages.isNotEmpty && currentHeight < canvasHeight * 0.3) {
        final lastPage = pages.removeLast();
        final combinedContent = lastPage.content + '\n' + currentPage.toString();
        pages.add(ReaderPage(
          content: combinedContent,
          isImage: false,
        ));
      } else {
        pages.add(ReaderPage(
          content: currentPage.toString(),
          isImage: false,
        ));
      }
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
  final String title;
  final String content;
  final List<ReaderPage> pages;
  final List<Volume> volumes;
  final double fontSize;
  final int currentPageIndex;

  ReaderLoaded({
    required this.aid,
    required this.cid,
    required this.title,
    required this.content,
    required this.pages,
    required this.volumes,
    required this.fontSize,
    required this.currentPageIndex,
  });

  ReaderLoaded copyWith({
    String? aid,
    String? cid,
    String? title,
    String? content,
    List<ReaderPage>? pages,
    List<Volume>? volumes,
    double? fontSize,
    int? currentPageIndex,
  }) {
    return ReaderLoaded(
      aid: aid ?? this.aid,
      cid: cid ?? this.cid,
      title: title ?? this.title,
      content: content ?? this.content,
      pages: pages ?? this.pages,
      volumes: volumes ?? this.volumes,
      fontSize: fontSize ?? this.fontSize,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
    );
  }
}