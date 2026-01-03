import 'package:flutter/material.dart';
import 'package:wild/models/reader_page.dart';
import 'package:flutter/rendering.dart';
import 'package:wild/src/rust/api/wenku8.dart';
import 'package:wild/features/novel/stores/bottom_bar_height_store.dart';
import 'package:wild/features/novel/stores/font_size_store.dart';
import 'package:wild/features/novel/stores/left_padding_store.dart';
import 'package:wild/features/novel/stores/line_height_store.dart';
import 'package:wild/features/novel/stores/paragraph_spacing_store.dart';
import 'package:wild/features/novel/stores/right_padding_store.dart';
import 'package:wild/features/novel/stores/top_bar_height_store.dart';
import 'package:signals/signals.dart' as signals;
import 'package:wild/src/rust/wenku8/models.dart';

class ReaderStore {
  final NovelInfo novelInfo;
  String initialAid;
  String initialCid;
  final List<Volume> initialVolumes;
  final FontSizeStore fontSizeStore;
  final ParagraphSpacingStore paragraphSpacingStore;
  final LineHeightStore lineHeightStore;
  final TopBarHeightStore topBarHeightStore;
  final BottomBarHeightStore bottomBarHeightStore;
  final LeftPaddingStore leftPaddingStore;
  final RightPaddingStore rightPaddingStore;

  ReaderStore({
    required this.novelInfo,
    required this.initialAid,
    required this.initialCid,
    required this.initialVolumes,
    required this.fontSizeStore,
    required this.paragraphSpacingStore,
    required this.lineHeightStore,
    required this.topBarHeightStore,
    required this.bottomBarHeightStore,
    required this.leftPaddingStore,
    required this.rightPaddingStore,
  }) : _state = signals.signal<ReaderState>(ReaderInitial());

  final signals.Signal<ReaderState> _state;
  ReaderState get state => _state.value;
  signals.Signal<ReaderState> get signal => _state;

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

  Volume _findVolume(String aid, String cid) {
    for (final volume in initialVolumes) {
      for (final chapter in volume.chapters) {
        if (chapter.aid == aid && chapter.cid == cid) {
          return volume;
        }
      }
    }
    throw Exception('Volume not found');
  }

  Future<void> loadChapter({String? aid, String? cid, int? initialPage}) async {
    try {
      _state.value = ReaderLoading(state.showControls);
      initialAid = aid ?? initialAid;
      initialCid = cid ?? initialCid;

      final targetAid = initialAid;
      final targetCid = initialCid;

      final chapterTitle = _findChapterTitle(targetAid, targetCid);
      final volume = _findVolume(targetAid, targetCid);
      final content = await chapterContent(aid: targetAid, cid: targetCid);

      final fontSize = fontSizeStore.state;
      final paragraphSpacing = paragraphSpacingStore.state;
      final lineHeight = lineHeightStore.state;

      // 分页内容
      final pages = _paginateContent(
        targetAid,
        targetCid,
        chapterTitle,
        content,
        fontSize,
        paragraphSpacing,
        lineHeight,
      );

      // 验证并设置初始页码
      int pageIndex = 0;
      if (initialPage != null) {
        if (initialPage >= 0 && initialPage < pages.length) {
          pageIndex = initialPage;
        }
      }

      // 计算从第一页到当前页的累计字数
      final characterCount = _calculateCharacterCountUpToPage(pages, pageIndex);
      
      // 更新阅读历史
      await updateHistory(
        novelId: targetAid,
        novelName: novelInfo.title,
        volumeId: volume.id,
        volumeName: volume.title,
        chapterId: targetCid,
        chapterTitle: chapterTitle,
        progress: characterCount,
        progressPage: pageIndex,
        cover: novelInfo.imgUrl,
        author: novelInfo.author,
      );

      _state.value = ReaderLoaded(
        aid: targetAid,
        cid: targetCid,
        title: chapterTitle,
        volumes: initialVolumes,
        pages: pages,
        currentPageIndex: pageIndex,
        showControls: state.showControls,
      );
    } catch (e) {
      _state.value = ReaderError(e.toString());
    }
  }

  Future reloadCurrentPage() async {
    try {
      var currentPageIndex =
          state is ReaderLoaded ? (state as ReaderLoaded).currentPageIndex
              : 0;
      // emit(ReaderLoading());

      final targetAid = initialAid;
      final targetCid = initialCid;

      final chapterTitle = _findChapterTitle(targetAid, targetCid);
      final content = await chapterContent(aid: targetAid, cid: targetCid);

      final fontSize = fontSizeStore.state;
      final paragraphSpacing = paragraphSpacingStore.state;
      final lineHeight = lineHeightStore.state;

      final pages = _paginateContent(
        targetAid,
        targetCid,
        chapterTitle,
        content,
        fontSize,
        paragraphSpacing,
        lineHeight,
      );

      if (currentPageIndex >= pages.length) {
        currentPageIndex = pages.length - 1;
      }

      _state.value = ReaderLoaded(
        aid: targetAid,
        cid: targetCid,
        title: chapterTitle,
        volumes: initialVolumes,
        pages: pages,
        currentPageIndex: currentPageIndex,
        showControls: state.showControls,
      );
    } catch (e) {
      _state.value = ReaderError(e.toString());
    }
  }

  void onPageChanged(int index) {
    if (state is ReaderLoaded) {
      final currentState = state as ReaderLoaded;
      _state.value = currentState.copyWith(currentPageIndex: index);
      
      // 计算从第一页到当前页的累计字数
      final characterCount = _calculateCharacterCountUpToPage(currentState.pages, index);
      
      // 更新阅读历史中的页码
      updateHistory(
        novelId: currentState.aid,
        novelName: novelInfo.title,
        volumeId: _findVolume(currentState.aid, currentState.cid).id,
        volumeName: _findVolume(currentState.aid, currentState.cid).title,
        chapterId: currentState.cid,
        chapterTitle: currentState.title,
        progress: characterCount,
        progressPage: index,
        cover: novelInfo.imgUrl,
        author: novelInfo.author,
      );
    }
  }

  Future goToPreviousChapter() async {
    if (!_canGoPrevious()) return;

    final currentVolumeIndex = _findCurrentVolumeIndex();
    final currentChapterIndex = _findCurrentChapterIndex();

    Volume volume;
    Chapter chapter;
    if (currentChapterIndex > 0) {
      // 同一卷的上一章
      volume = initialVolumes[currentVolumeIndex];
      chapter = initialVolumes[currentVolumeIndex].chapters[currentChapterIndex - 1];
      await loadChapter(aid: chapter.aid, cid: chapter.cid, initialPage: 0);
    } else if (currentVolumeIndex > 0) {
      // 上一卷的最后一章
      volume = initialVolumes[currentVolumeIndex - 1];
      chapter = volume.chapters.last;
      await loadChapter(aid: chapter.aid, cid: chapter.cid, initialPage: 0);
    } else {
      // 已经是第一章
      return;
    }
  }

  void goToNextChapter() async {
    if (!_canGoNext()) return;

    final currentVolumeIndex = _findCurrentVolumeIndex();
    final currentChapterIndex = _findCurrentChapterIndex();

    Volume volume;
    Chapter chapter;
    if (currentChapterIndex < initialVolumes[currentVolumeIndex].chapters.length - 1) {
      // 同一卷的下一章
      volume = initialVolumes[currentVolumeIndex];
      chapter = initialVolumes[currentVolumeIndex].chapters[currentChapterIndex + 1];
      await loadChapter(aid: chapter.aid, cid: chapter.cid, initialPage: 0);
    } else if (currentVolumeIndex < initialVolumes.length - 1) {
      // 下一卷的第一章
      volume = initialVolumes[currentVolumeIndex + 1];
      chapter = volume.chapters.first;
      await loadChapter(aid: chapter.aid, cid: chapter.cid, initialPage: 0);
    } else {
      // 已经是最后一章
      return;
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
    return currentChapterIndex <
            initialVolumes[currentVolumeIndex].chapters.length - 1 ||
        currentVolumeIndex < initialVolumes.length - 1;
  }

  int _findCurrentVolumeIndex() {
    for (var i = 0; i < initialVolumes.length; i++) {
      final volume = initialVolumes[i];
      if (volume.chapters.any(
        (chapter) => chapter.aid == initialAid && chapter.cid == initialCid,
      )) {
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

  /// 计算从第一页到指定页码的累计字数
  int _calculateCharacterCountUpToPage(List<ReaderPage> pages, int pageIndex) {
    int totalCharacters = 0;
    for (int i = 0; i <= pageIndex && i < pages.length; i++) {
      final page = pages[i];
      if (!page.isImage) {
        // 只计算文本页面的字数，排除图片页面
        totalCharacters += page.content.length;
      }
    }
    return totalCharacters;
  }

  List<ReaderPage> _paginateContent(
    String aid,
    String cid,
    String title,
    String content,
    double fontSize,
    double paragraphSpacing,
    double lineHeight,
  ) {
    final pages = <ReaderPage>[];
    final paragraphs = content.split('\n');
    final screenWidth =
        MediaQueryData.fromView(WidgetsBinding.instance.window).size.width;
    final screenHeight =
        MediaQueryData.fromView(WidgetsBinding.instance.window).size.height;
    final topPadding =
        MediaQueryData.fromView(WidgetsBinding.instance.window).padding.top;
    final bottomPadding =
        MediaQueryData.fromView(WidgetsBinding.instance.window).padding.bottom;
    final topBarHeight = topBarHeightStore.state;
    final bottomBarHeight = bottomBarHeightStore.state;
    final leftPadding = leftPaddingStore.state;
    final rightPadding = rightPaddingStore.state;
    final leftAndRightPadding = leftPadding + rightPadding;
    final canvasWidth = screenWidth - leftAndRightPadding;
    final canvasHeight =
        screenHeight -
        topPadding -
        bottomPadding -
        topBarHeight -
        bottomBarHeight;

    var currentPage = StringBuffer();
    var pageFreeHeight = canvasHeight;

    void putParagraph(String paragraph) {
      while (paragraph.isNotEmpty) {
        var textPainter = TextPainter(
          textDirection: TextDirection.ltr,
          maxLines: null,
        );
        textPainter.strutStyle = StrutStyle(height: lineHeight);
        final textStyle = TextStyle(
          fontSize: fontSize,
          height: lineHeight,
          letterSpacing: 0.5,
        );
        textPainter.text = TextSpan(text: paragraph, style: textStyle);
        textPainter.layout(maxWidth: canvasWidth);
        var textHeight = textPainter.height;

        if (textHeight > pageFreeHeight) {
          // 当前段落超出页面高度，分割段落
          var splitIndex =
              textPainter
                  .getPositionForOffset(Offset(0, pageFreeHeight))
                  .offset;
          var splitParagraph = paragraph.substring(0, splitIndex);
          currentPage.write(splitParagraph);
          pages.add(
            ReaderPage(content: currentPage.toString(), isImage: false),
          );
          currentPage.clear();
          paragraph = paragraph.substring(splitIndex);
          pageFreeHeight = canvasHeight;
        } else {
          // 当前段落可以放入当前页面
          currentPage.write(paragraph);
          currentPage.write("\n");
          pageFreeHeight -= textHeight + paragraphSpacing;
          break;
        }
      }
    }

    endWrite() {
      if (currentPage.isNotEmpty) {
        pages.add(ReaderPage(content: currentPage.toString(), isImage: false));
        currentPage.clear();
      }
    }

    void putImage(String imageUrl) {
      endWrite();
      pages.add(ReaderPage(content: imageUrl, isImage: true));
    }

    for (var paragraph in paragraphs) {
      RegExp regex = RegExp("\<\!\-\-image\-\-\>([^\<]+)\<\!\-\-image\-\-\>");
      if (regex.hasMatch(paragraph)) {
        while (regex.hasMatch(paragraph)) {
          var match = regex.firstMatch(paragraph)!;
          if (match.start > 0) {
            var per = paragraph.substring(0, match.start).trim();
            if (per.isNotEmpty) {
              putParagraph(per);
            }
            putImage(match.group(1)!);
            paragraph = paragraph.substring(match.end);
          }
        }
        paragraph = paragraph.trim();
        if (paragraph.isNotEmpty) {
          putParagraph(paragraph);
        }
      } else {
        putParagraph(paragraph);
      }
    }

    endWrite();

    return pages;
  }

  void toggleControls() {
    if (state is ReaderLoaded) {
      final currentState = state as ReaderLoaded;
      _state.value =
          currentState.copyWith(showControls: !currentState.showControls);
    }
  }
}

abstract class ReaderState {
  bool get showControls;
}

class ReaderInitial extends ReaderState {
  @override
  get showControls => false;
}

class ReaderLoading extends ReaderState {
  @override
  final bool showControls;

  ReaderLoading(this.showControls);
}

class ReaderError extends ReaderState {
  final String error;

  ReaderError(this.error);

  @override
  get showControls => false;
}

class ReaderLoaded extends ReaderState {
  final String aid;
  final String cid;
  final String title;
  final List<ReaderPage> pages;
  final List<Volume> volumes;
  final int currentPageIndex;
  @override
  final bool showControls;

  ReaderLoaded({
    required this.aid,
    required this.cid,
    required this.title,
    required this.volumes,
    required this.pages,
    required this.currentPageIndex,
    required this.showControls,
  });

  ReaderLoaded copyWith({
    String? aid,
    String? cid,
    String? title,
    List<ReaderPage>? pages,
    List<Volume>? volumes,
    int? currentPageIndex,
    bool? showControls,
  }) {
    return ReaderLoaded(
      aid: aid ?? this.aid,
      cid: cid ?? this.cid,
      title: title ?? this.title,
      volumes: volumes ?? this.volumes,
      pages: pages ?? this.pages,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      showControls: showControls ?? this.showControls,
    );
  }
}
