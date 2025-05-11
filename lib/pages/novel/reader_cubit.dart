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
    var currentPage = StringBuffer();
    var currentHeight = 0.0;
    final screenWidth = MediaQueryData.fromView(WidgetsBinding.instance.window).size.width - 32;
    final screenHeight = MediaQueryData.fromView(WidgetsBinding.instance.window).size.height;
    final topPadding = MediaQueryData.fromView(WidgetsBinding.instance.window).padding.top;
    final bottomPadding = MediaQueryData.fromView(WidgetsBinding.instance.window).padding.bottom;
    final topBarHeight = 56.0;
    final bottomBarHeight = 56.0;
    final canvasHeight = screenHeight - topPadding - bottomPadding - topBarHeight - bottomBarHeight - 4;

    final currentFontSize = state is ReaderLoaded ? (state as ReaderLoaded).fontSize : 18.0;

    TextStyle getTextStyle(double fontSize) => TextStyle(
      fontSize: fontSize,
      height: 1.5,
      letterSpacing: 0.5,
    );

    String _splitText(String text, double maxHeight) {
      if (text.isEmpty) return '';
      
      // 如果整个文本都能放入一页，直接返回
      _textPainter.text = TextSpan(
        text: text,
        style: getTextStyle(currentFontSize),
      );
      _textPainter.layout(maxWidth: screenWidth);
      if (_textPainter.height <= maxHeight) {
        return text;
      }

      var start = 0;
      var end = text.length;
      var lastValidEnd = 0;
      
      // 最多尝试 log2(text.length) 次
      var maxAttempts = (text.length.bitLength + 1);
      var attempts = 0;
      
      while (start < end && attempts < maxAttempts) {
        attempts++;
        var mid = (start + end) ~/ 2;
        
        // 找到下一个合适的分割点（标点符号或空格）
        while (mid < text.length && 
               text[mid].isNotEmpty && 
               !RegExp(r'[\s,，.。!！?？]').hasMatch(text[mid])) {
          mid++;
        }
        if (mid >= text.length) {
          mid = text.length - 1;
        }
        
        final testText = text.substring(0, mid + 1);
        _textPainter.text = TextSpan(
          text: testText,
          style: getTextStyle(currentFontSize),
        );
        _textPainter.layout(maxWidth: screenWidth);

        if (_textPainter.height <= maxHeight) {
          lastValidEnd = mid + 1;
          start = mid + 1;
          // 如果已经到达文本末尾，直接返回
          if (start >= text.length) {
            return text;
          }
        } else {
          end = mid;
        }
      }
      
      // 如果没有找到合适的分割点，强制在中间分割
      if (lastValidEnd == 0) {
        // 尝试在最后一个完整字符处分割
        var splitPoint = text.length ~/ 2;
        while (splitPoint > 0 && 
               text[splitPoint].isNotEmpty && 
               !RegExp(r'[\s,，.。!！?？]').hasMatch(text[splitPoint])) {
          splitPoint--;
        }
        if (splitPoint == 0) {
          // 如果找不到标点符号，就在中间强制分割
          splitPoint = text.length ~/ 2;
        }
        return text.substring(0, splitPoint + 1);
      }
      
      return text.substring(0, lastValidEnd);
    }

    for (var paragraph in paragraphs) {
      if (paragraph.trim().isEmpty) {
        if (currentPage.isNotEmpty) {
          currentPage.write('\n');
          currentHeight += 24;
        }
        continue;
      }

      // 处理段落，限制最多2行
      final lines = paragraph.split('\n');
      final processedParagraph = lines.length > 2 
          ? '${lines[0]}\n${lines[1]}'
          : paragraph;

      _textPainter.text = TextSpan(
        text: processedParagraph,
        style: getTextStyle(currentFontSize),
      );
      _textPainter.layout(maxWidth: screenWidth);

      if (currentHeight + _textPainter.height > canvasHeight) {
        if (currentPage.isNotEmpty) {
          pages.add(ReaderPage(
            content: currentPage.toString(),
            isImage: false,
          ));
          currentPage.clear();
          currentHeight = 0.0;
        }

        if (_textPainter.height > canvasHeight) {
          var remainingText = processedParagraph;
          while (remainingText.isNotEmpty) {
            final pageText = _splitText(remainingText, canvasHeight);
            if (pageText.isEmpty) break; // 防止死循环
            
            pages.add(ReaderPage(
              content: pageText,
              isImage: false,
            ));
            
            remainingText = remainingText.substring(pageText.length);
            if (remainingText.isNotEmpty && remainingText[0] == '\n') {
              remainingText = remainingText.substring(1);
            }
          }
        } else {
          currentPage.write(processedParagraph);
          currentHeight = _textPainter.height;
        }
      } else {
        if (currentPage.isNotEmpty) {
          currentPage.write('\n');
          currentHeight += 24;
        }
        currentPage.write(processedParagraph);
        currentHeight += _textPainter.height;
      }
    }

    if (currentPage.isNotEmpty) {
      pages.add(ReaderPage(
        content: currentPage.toString(),
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