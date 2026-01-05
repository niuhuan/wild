import 'package:flutter/material.dart';
import 'package:wild/features/novel/stores/reader_store.dart';
import 'package:wild/features/novel/stores/reader_type_store.dart';
import 'package:wild/features/novel/stores/theme_store.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:wild/widgets/cached_image.dart';
import 'package:wild/features/settings/screen/screen_keep_on.dart';
import 'package:wild/utils/controller_event.dart';
import 'dart:io';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:wild/state/app_state.dart' as app;

import 'package:wild/src/rust/wenku8/models.dart';

class ReaderPage extends StatefulWidget {
  final String aid;
  final String cid;
  final String initialTitle;
  final List<Volume> volumes;
  final NovelInfo novelInfo;
  final int? initialPage;

  const ReaderPage({
    super.key,
    required this.aid,
    required this.cid,
    required this.initialTitle,
    required this.volumes,
    required this.novelInfo,
    this.initialPage,
  });

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late final ReaderStore _readerStore;

  @override
  void initState() {
    super.initState();
    _readerStore = ReaderStore(
      novelInfo: widget.novelInfo,
      initialAid: widget.aid,
      initialCid: widget.cid,
      initialVolumes: widget.volumes,
      fontSizeStore: app.fontSize,
      paragraphSpacingStore: app.paragraphSpacing,
      lineHeightStore: app.lineHeight,
      topBarHeightStore: app.topBarHeight,
      bottomBarHeightStore: app.bottomBarHeight,
      leftPaddingStore: app.leftPadding,
      rightPaddingStore: app.rightPadding,
    )..loadChapter(initialPage: widget.initialPage);
  }

  @override
  Widget build(BuildContext context) {
    print('ReaderPage building with initialPage: ${widget.initialPage}');
    return Watch((context) {
      final state = _readerStore.signal.watch(context);
      if (state is ReaderLoading) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      if (state is ReaderError) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(state.error),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _readerStore.loadChapter(),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        );
      }
      if (state is ReaderLoaded) {
        return _ReaderView(state: state, title: state.title, store: _readerStore);
      }
      return const SizedBox.shrink();
    });
  }
}

class _ReaderView extends StatefulWidget {
  final ReaderLoaded state;
  final String title;

  final ReaderStore store;

  const _ReaderView({
    required this.state,
    required this.title,
    required this.store,
  });

  @override
  State<_ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<_ReaderView> {
  late PageController _pageController;
  var preTime = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.state.currentPageIndex,
    );
    setKeepScreenUpOnReading(true);
    
    // 监听音量键事件
    if (Platform.isAndroid) {
      if (app.volumeControl.isEnabled) {
        addVolumeListen();
        readerControllerEvent.subscribe(_onController);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    setKeepScreenUpOnReading(false);
    setKeepScreenUpOnScroll(false);
    
    // 取消音量键事件监听
    if (Platform.isAndroid) {
      delVolumeListen();
      readerControllerEvent.unsubscribe(_onController);
    }
    
    super.dispose();
  }

  void _handleTap(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final tapX = details.globalPosition.dx;
    final tapY = details.globalPosition.dy;

    // 将屏幕分为左、中、右三个区域
    final leftArea = screenWidth * 0.3;
    final rightArea = screenWidth * 0.7;
    // 将屏幕分为上、中、下三个区域
    final topArea = screenHeight * 0.3;
    final bottomArea = screenHeight * 0.7;

    if (tapX < leftArea || tapY < topArea) {
      // 点击左侧或上方区域，上一页
      if (widget.state.currentPageIndex > 0) {
        // _pageController.previousPage(
        //   duration: const Duration(milliseconds: 300),
        //   curve: Curves.easeInOut,
        // );
        _pageController.jumpToPage(widget.state.currentPageIndex - 1);
      } else {
        // 如果是第一页，尝试加载上一章
        final currentVolumeIndex = _findCurrentVolumeIndex();
        final currentChapterIndex = _findCurrentChapterIndex();
        if (currentChapterIndex > 0 || currentVolumeIndex > 0) {
          var now = DateTime.now().millisecondsSinceEpoch;
          if (now - preTime > 2000) {
            preTime = now;
            // 显示提示信息
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('再次点击加载上一章'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.only(bottom: 16),
              ),
            );
          } else {
            preTime = 0;
            widget.store.goToPreviousChapter();
          }
        }
      }
    } else if (tapX > rightArea || tapY > bottomArea) {
      // 点击右侧或下方区域，下一页
      if (widget.state.currentPageIndex < widget.state.pages.length - 1) {
        // _pageController.nextPage(
        //   duration: const Duration(milliseconds: 300),
        //   curve: Curves.easeInOut,
        // );
        _pageController.jumpToPage(widget.state.currentPageIndex + 1);
      } else {
        // 如果是最后一页，尝试加载下一章
        final currentVolumeIndex = _findCurrentVolumeIndex();
        final currentChapterIndex = _findCurrentChapterIndex();
        final volume = widget.state.volumes[currentVolumeIndex];
        if (currentChapterIndex < volume.chapters.length - 1 ||
            currentVolumeIndex < widget.state.volumes.length - 1) {
          widget.store.goToNextChapter();
        }
      }
    } else {
      // 点击中央区域，切换菜单栏显示状态
      widget.store.toggleControls();
    }
  }

  void _showChapterList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (context, scrollController) => _ChapterList(
            volumes: widget.state.volumes,
            currentAid: widget.state.aid,
            currentCid: widget.state.cid,
            onChapterSelected: (aid, cid) {
              Navigator.pop(context);
              widget.store.loadChapter(aid: aid, cid: cid);
            },
          ),
        );
      },
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return _ReaderSettings(widget.store);
      },
    );
  }

  void _onController(ReaderControllerEventArgs args) {
    if (args.key == "UP") {
      // 音量上键 - 上一页
      if (widget.state.currentPageIndex > 0) {
        _pageController.jumpToPage(widget.state.currentPageIndex - 1);
      } else {
        // 如果是第一页，尝试加载上一章
        final currentVolumeIndex = _findCurrentVolumeIndex();
        final currentChapterIndex = _findCurrentChapterIndex();
        if (currentChapterIndex > 0 || currentVolumeIndex > 0) {
          widget.store.goToPreviousChapter();
        }
      }
    } else if (args.key == "DOWN") {
      // 音量下键 - 下一页
      if (widget.state.currentPageIndex < widget.state.pages.length - 1) {
        _pageController.jumpToPage(widget.state.currentPageIndex + 1);
      } else {
        // 如果是最后一页，尝试加载下一章
        final currentVolumeIndex = _findCurrentVolumeIndex();
        final currentChapterIndex = _findCurrentChapterIndex();
        final volume = widget.state.volumes[currentVolumeIndex];
        if (currentChapterIndex < volume.chapters.length - 1 ||
            currentVolumeIndex < widget.state.volumes.length - 1) {
          widget.store.goToNextChapter();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final mediaQuery = MediaQuery.of(context);
      final topPadding = mediaQuery.padding.top;

      final theme = app.theme.signal.watch(context);
      final backgroundState = app.readerBackground.signal.watch(context);

      final bool isDarkMode;
      if (theme.themeMode == ReaderThemeMode.dark) {
        isDarkMode = true;
      } else if (theme.themeMode == ReaderThemeMode.light) {
        isDarkMode = false;
      } else {
        isDarkMode = mediaQuery.platformBrightness == Brightness.dark;
      }

      final backgroundColor =
          isDarkMode ? theme.darkBackgroundColor : theme.lightBackgroundColor;
      final textColor = isDarkMode ? theme.darkTextColor : theme.lightTextColor;

      String? backgroundImagePath;
      if (isDarkMode && backgroundState.darkBackgroundExists) {
        backgroundImagePath = app.readerBackground.getDarkBackgroundPath();
      } else if (!isDarkMode && backgroundState.lightBackgroundExists) {
        backgroundImagePath = app.readerBackground.getLightBackgroundPath();
      }

      return Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          children: [
            if (backgroundImagePath != null)
              Positioned.fill(
                child: Image.file(
                  File(backgroundImagePath),
                  fit: BoxFit.cover,
                  opacity: AlwaysStoppedAnimation(backgroundState.opacity),
                ),
              ),
            Positioned.fill(
              child: GestureDetector(
                onTapDown: _handleTap,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.state.pages.length,
                  onPageChanged: (index) {
                    widget.store.onPageChanged(index);
                  },
                  itemBuilder: (context, index) {
                    final page = widget.state.pages[index];
                    if (page.isImage) {
                      return _ImagePage(
                        imageUrl: page.content,
                        textColor: textColor,
                        pageNumber: widget.state.currentPageIndex + 1,
                        pageCount: widget.state.pages.length,
                      );
                    }
                    return _TextPage(
                      content: page.content,
                      textColor: textColor,
                      pageNumber: widget.state.currentPageIndex + 1,
                      pageCount: widget.state.pages.length,
                    );
                  },
                ),
              ),
            ),
            if (widget.state.showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.menu_book, color: Colors.white),
                        onPressed: _showChapterList,
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white),
                        onPressed: _showSettings,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  int _findCurrentVolumeIndex() {
    for (var i = 0; i < widget.state.volumes.length; i++) {
      final volume = widget.state.volumes[i];
      if (volume.chapters.any(
        (chapter) =>
            chapter.aid == widget.state.aid && chapter.cid == widget.state.cid,
      )) {
        return i;
      }
    }
    return -1;
  }

  int _findCurrentChapterIndex() {
    final volumeIndex = _findCurrentVolumeIndex();
    if (volumeIndex == -1) return -1;
    final volume = widget.state.volumes[volumeIndex];
    for (var i = 0; i < volume.chapters.length; i++) {
      final chapter = volume.chapters[i];
      if (chapter.aid == widget.state.aid && chapter.cid == widget.state.cid) {
        return i;
      }
    }
    return -1;
  }
}

class _TextPage extends StatelessWidget {
  final String content;
  final Color textColor;
  final int pageNumber;
  final int pageCount;

  const _TextPage({
    required this.content,
    required this.textColor,
    required this.pageNumber,
    required this.pageCount,
  });

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final fontSize = app.fontSize.signal.watch(context);
      final spacing = app.paragraphSpacing.signal.watch(context);
      final lineHeight = app.lineHeight.signal.watch(context);
      final topBarHeight = app.topBarHeight.signal.watch(context);
      final bottomBarHeight = app.bottomBarHeight.signal.watch(context);
      final leftPadding = app.leftPadding.signal.watch(context);
      final rightPadding = app.rightPadding.signal.watch(context);

      final media = MediaQueryData.fromView(WidgetsBinding.instance.window);
      final screenWidth = media.size.width;
      final topPadding = media.padding.top;
      final bottomPadding = media.padding.bottom;

      final leftAndRightPadding = leftPadding + rightPadding;
      final canvasWidth = screenWidth - leftAndRightPadding;

      final texts = content.split("\n");
      return Column(
        children: [
          Container(height: topPadding),
          Container(height: topBarHeight),
          for (var i = 0; i < texts.length; i++) ...[
            SizedBox(
              width: canvasWidth,
              child: Text.rich(
                strutStyle: StrutStyle(height: lineHeight),
                TextSpan(
                  text: texts[i],
                  style: TextStyle(
                    fontSize: fontSize,
                    height: lineHeight,
                    letterSpacing: 0.5,
                    color: textColor,
                  ),
                ),
              ),
            ),
            if (i < texts.length - 1) Container(height: spacing),
          ],
          Expanded(child: Container()),
          SizedBox(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Opacity(
                opacity: 0.3,
                child: Text(
                  '$pageNumber/$pageCount',
                  style: TextStyle(fontSize: 10, color: textColor),
                ),
              ),
            ),
          ),
          Container(height: bottomPadding),
        ],
      );
    });
  }
}

class _ImagePage extends StatelessWidget {
  final String imageUrl;
  final Color textColor;
  final int pageNumber;
  final int pageCount;

  const _ImagePage({
    required this.imageUrl,
    required this.textColor,
    required this.pageNumber,
    required this.pageCount,
  });

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final topBarHeight = app.topBarHeight.signal.watch(context);
      final bottomBarHeight = app.bottomBarHeight.signal.watch(context);
      final leftPadding = app.leftPadding.signal.watch(context);
      final rightPadding = app.rightPadding.signal.watch(context);

      final mediaQuery = MediaQuery.of(context);
      final screenHeight = mediaQuery.size.height;
      final screenWidth = mediaQuery.size.width;
      final topPadding = mediaQuery.padding.top;
      final bottomPadding = mediaQuery.padding.bottom;
      final leftAndRightPadding = leftPadding + rightPadding;
      final availableHeight =
          screenHeight - topPadding - bottomPadding - topBarHeight - bottomBarHeight;

      return Column(
        children: [
          Container(height: topPadding + topBarHeight),
          SizedBox(
            width: screenWidth - leftAndRightPadding,
            height: availableHeight,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: availableHeight,
                  maxWidth: screenWidth - leftAndRightPadding,
                ),
                child: Image(
                  image: CachedImageProvider(imageUrl),
                  width: screenWidth - leftAndRightPadding,
                  height: availableHeight,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: screenWidth - leftAndRightPadding,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: screenWidth - leftAndRightPadding,
                      color: Colors.grey[200],
                      child: const Center(child: Text('图片加载失败')),
                    );
                  },
                ),
              ),
            ),
          ),
          Expanded(child: Container()),
          SizedBox(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Opacity(
                opacity: 0.3,
                child: Text(
                  '$pageNumber/$pageCount',
                  style: TextStyle(fontSize: 10, color: textColor),
                ),
              ),
            ),
          ),
          Container(height: bottomPadding),
        ],
      );
    });
  }
}

class _ChapterList extends StatefulWidget {
  final List<Volume> volumes;
  final String currentAid;
  final String currentCid;
  final Function(String aid, String cid) onChapterSelected;

  const _ChapterList({
    required this.volumes,
    required this.currentAid,
    required this.currentCid,
    required this.onChapterSelected,
  });

  @override
  State<_ChapterList> createState() => _ChapterListState();
}

class _ChapterListState extends State<_ChapterList> {
  late ScrollController _scrollController;
  int _currentChapterGlobalIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // 计算当前章节的全局索引
    _currentChapterGlobalIndex = _calculateCurrentChapterIndex();
    // 在下一帧滚动到当前章节
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // 估算每个章节的高度（包括标题和间距）
        const estimatedItemHeight = 56.0; // ListTile 的默认高度
        const estimatedVolumeTitleHeight = 48.0; // 卷标题的高度
        const estimatedSpacing = 16.0; // 间距

        // 计算目标滚动位置
        double targetScroll =
            _currentChapterGlobalIndex *
            (estimatedItemHeight + estimatedSpacing);
        // 加上之前所有卷标题的高度
        int volumeIndex = 0;
        for (var i = 0; i < widget.volumes.length; i++) {
          if (i < _findCurrentVolumeIndex()) {
            targetScroll += estimatedVolumeTitleHeight + estimatedSpacing;
            volumeIndex = i;
          } else {
            break;
          }
        }

        // 滚动到目标位置，并稍微向上偏移一点以显示上下文
        _scrollController.animateTo(
          targetScroll - 100, // 向上偏移100像素，显示一些上下文
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _findCurrentVolumeIndex() {
    for (var i = 0; i < widget.volumes.length; i++) {
      final volume = widget.volumes[i];
      if (volume.chapters.any(
        (chapter) =>
            chapter.aid == widget.currentAid &&
            chapter.cid == widget.currentCid,
      )) {
        return i;
      }
    }
    return -1;
  }

  int _calculateCurrentChapterIndex() {
    int globalIndex = 0;
    for (var volume in widget.volumes) {
      for (var chapter in volume.chapters) {
        if (chapter.aid == widget.currentAid &&
            chapter.cid == widget.currentCid) {
          return globalIndex;
        }
        globalIndex++;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book),
                const SizedBox(width: 8),
                const Text(
                  '目录',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('关闭'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: widget.volumes.length,
              itemBuilder: (context, volumeIndex) {
                final volume = widget.volumes[volumeIndex];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        volume.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...volume.chapters.map((chapter) {
                      final isSelected =
                          chapter.aid == widget.currentAid &&
                          chapter.cid == widget.currentCid;
                      return Container(
                        color:
                            isSelected
                                ? Colors.grey.withAlpha(80)
                                : Colors.transparent,
                        child: ListTile(
                          onTap:
                              () => widget.onChapterSelected(
                                chapter.aid,
                                chapter.cid,
                              ),
                          title: Text(
                            chapter.title,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderSettings extends StatefulWidget {
  final ReaderStore readerStore;

  const _ReaderSettings(this.readerStore);

  @override
  State<_ReaderSettings> createState() => _ReaderSettingsState();
}

class _ReaderSettingsState extends State<_ReaderSettings> {
  void _showColorPicker(
    BuildContext context,
    Color initialColor,
    Function(Color) onColorChanged,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        Color pickerColor = initialColor;
        return AlertDialog(
          title: const Text('选择颜色'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (Color color) {
                pickerColor = color;
              },
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false,
              labelTypes: const [],
              displayThumbColor: true,
              showLabel: false,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('确定'),
              onPressed: () async {
                onColorChanged(pickerColor);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final theme = app.theme.signal.watch(context);
      final readerType = app.readerType.signal.watch(context);
      final fontSize = app.fontSize.signal.watch(context);
      final spacing = app.paragraphSpacing.signal.watch(context);
      final lineHeight = app.lineHeight.signal.watch(context);
      final topBarHeight = app.topBarHeight.signal.watch(context);
      final bottomBarHeight = app.bottomBarHeight.signal.watch(context);
      final leftPadding = app.leftPadding.signal.watch(context);
      final rightPadding = app.rightPadding.signal.watch(context);
      final backgroundState = app.readerBackground.signal.watch(context);

      return Container(
        height: MediaQuery.of(context).size.height / 3 * 2,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: ListView(
          children: [
            const Text(
              '设置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('阅读器类型'),
                const SizedBox(width: 16),
                Expanded(
                  child: SegmentedButton<ReaderType>(
                    segments: const [
                      ButtonSegment<ReaderType>(
                        value: ReaderType.normal,
                        label: Text('普通阅读器'),
                        icon: Icon(Icons.book),
                      ),
                      ButtonSegment<ReaderType>(
                        value: ReaderType.html,
                        label: Text('HTML阅读器'),
                        icon: Icon(Icons.html),
                      ),
                    ],
                    selected: {readerType},
                    onSelectionChanged: (Set<ReaderType> types) async {
                      await app.readerType.updateType(types.first);
                    },
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                const Text('字体大小'),
                Expanded(
                  child: Slider(
                    value: fontSize,
                    min: 14,
                    max: 24,
                    divisions: 10,
                    label: fontSize.round().toString(),
                    onChanged: (value) async {
                      await app.fontSize.updateFontSize(value);
                      await widget.readerStore.reloadCurrentPage();
                    },
                  ),
                ),
                Text('${fontSize.round()}'),
              ],
            ),
            Row(
              children: [
                const Text('段落间距'),
                Expanded(
                  child: Slider(
                    value: spacing,
                    min: 2,
                    max: 32,
                    divisions: 30,
                    label: spacing.round().toString(),
                    onChanged: (value) async {
                      await app.paragraphSpacing.updateSpacing(value);
                      await widget.readerStore.reloadCurrentPage();
                    },
                  ),
                ),
                Text('${spacing.round()}'),
              ],
            ),
            Row(
              children: [
                const Text('行高'),
                Expanded(
                  child: Slider(
                    value: lineHeight,
                    min: 1.0,
                    max: 2.0,
                    divisions: 20,
                    label: lineHeight.toStringAsFixed(1),
                    onChanged: (value) async {
                      await app.lineHeight.updateLineHeight(value);
                      await widget.readerStore.reloadCurrentPage();
                    },
                  ),
                ),
                Text(lineHeight.toStringAsFixed(1)),
              ],
            ),
            Row(
              children: [
                const Text('顶部边距'),
                Expanded(
                  child: Slider(
                    value: topBarHeight,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: topBarHeight.round().toString(),
                    onChanged: (value) async {
                      await app.topBarHeight.updateHeight(value);
                      await widget.readerStore.reloadCurrentPage();
                    },
                  ),
                ),
                Text('${topBarHeight.round()}'),
              ],
            ),
            Row(
              children: [
                const Text('底部边距'),
                Expanded(
                  child: Slider(
                    value: bottomBarHeight,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: bottomBarHeight.round().toString(),
                    onChanged: (value) async {
                      await app.bottomBarHeight.updateHeight(value);
                      await widget.readerStore.reloadCurrentPage();
                    },
                  ),
                ),
                Text('${bottomBarHeight.round()}'),
              ],
            ),
            Row(
              children: [
                const Text('左边距'),
                Expanded(
                  child: Slider(
                    value: leftPadding,
                    min: 0,
                    max: 50,
                    divisions: 25,
                    label: leftPadding.round().toString(),
                    onChanged: (value) async {
                      await app.leftPadding.updatePadding(value);
                      await widget.readerStore.reloadCurrentPage();
                    },
                  ),
                ),
                Text('${leftPadding.round()}'),
              ],
            ),
            Row(
              children: [
                const Text('右边距'),
                Expanded(
                  child: Slider(
                    value: rightPadding,
                    min: 0,
                    max: 50,
                    divisions: 25,
                    label: rightPadding.round().toString(),
                    onChanged: (value) async {
                      await app.rightPadding.updatePadding(value);
                      await widget.readerStore.reloadCurrentPage();
                    },
                  ),
                ),
                Text('${rightPadding.round()}'),
              ],
            ),
            const Divider(),
            Row(
              children: [
                const Text('主题模式'),
                const SizedBox(width: 16),
                Expanded(
                  child: SegmentedButton<ReaderThemeMode>(
                    segments: const [
                      ButtonSegment<ReaderThemeMode>(
                        value: ReaderThemeMode.auto,
                        label: Text('自动'),
                        icon: Icon(Icons.brightness_auto),
                      ),
                      ButtonSegment<ReaderThemeMode>(
                        value: ReaderThemeMode.light,
                        label: Text('浅色'),
                        icon: Icon(Icons.light_mode),
                      ),
                      ButtonSegment<ReaderThemeMode>(
                        value: ReaderThemeMode.dark,
                        label: Text('深色'),
                        icon: Icon(Icons.dark_mode),
                      ),
                    ],
                    selected: {theme.themeMode},
                    onSelectionChanged: (Set<ReaderThemeMode> modes) async {
                      await app.theme.setThemeMode(modes.first);
                      await widget.readerStore.reloadCurrentPage();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: const [
                Text('背景透明度', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: backgroundState.opacity,
                    min: 0.0,
                    max: 1.0,
                    divisions: 25,
                    label: '${(backgroundState.opacity * 100).round()}%',
                    onChanged: (value) async {
                      await app.readerBackground.updateOpacity(value);
                      await widget.readerStore.reloadCurrentPage();
                    },
                  ),
                ),
                Text('${(backgroundState.opacity * 100).round()}%'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: const [
                Text('背景图片设置', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(
                      backgroundState.lightBackgroundExists
                          ? Icons.image
                          : Icons.add_photo_alternate,
                    ),
                    label: Text(
                      backgroundState.lightBackgroundExists
                          ? '更新浅色背景'
                          : '设置浅色背景',
                    ),
                    onPressed: () async {
                      await app.readerBackground.updateLightBackground();
                      await widget.readerStore.reloadCurrentPage();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (backgroundState.lightBackgroundExists)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('删除'),
                    onPressed: () async {
                      await app.readerBackground.deleteLightBackground();
                      await widget.readerStore.reloadCurrentPage();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(
                      backgroundState.darkBackgroundExists
                          ? Icons.image
                          : Icons.add_photo_alternate,
                    ),
                    label: Text(
                      backgroundState.darkBackgroundExists
                          ? '更新深色背景'
                          : '设置深色背景',
                    ),
                    onPressed: () async {
                      await app.readerBackground.updateDarkBackground();
                      await widget.readerStore.reloadCurrentPage();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (backgroundState.darkBackgroundExists)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('删除'),
                    onPressed: () async {
                      await app.readerBackground.deleteDarkBackground();
                      await widget.readerStore.reloadCurrentPage();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                await app.theme.resetToDefault();
                await app.topBarHeight.updateHeight(56);
                await app.bottomBarHeight.updateHeight(56);
                await app.leftPadding.updatePadding(16);
                await app.rightPadding.updatePadding(16);
                await widget.readerStore.reloadCurrentPage();
              },
              child: const Text('重置为默认'),
            ),
          ],
        ),
      );
    });
  }
}
