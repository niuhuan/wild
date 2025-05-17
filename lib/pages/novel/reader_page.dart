import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/pages/novel/paragraph_spacing_cubit.dart';
import 'package:wild/pages/novel/reader_cubit.dart';
import 'package:wild/pages/novel/theme_cubit.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:wild/widgets/cached_image.dart';

import '../../src/rust/wenku8/models.dart';
import 'font_size_cubit.dart';
import 'line_height_cubit.dart';

class ReaderPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    print('ReaderPage building with initialPage: $initialPage');
    final fontSizeCubit = context.read<FontSizeCubit>();
    final paragraphSpacingCubit = context.read<ParagraphSpacingCubit>();
    final lineHeightCubit = context.read<LineHeightCubit>();

    return BlocProvider(
      create: (context) => ReaderCubit(
        novelInfo: novelInfo,
        initialAid: aid,
        initialCid: cid,
        initialVolumes: volumes,
        fontSizeCubit: fontSizeCubit,
        paragraphSpacingCubit: paragraphSpacingCubit,
        lineHeightCubit: lineHeightCubit,
      )..loadChapter(initialPage: initialPage),
      child: BlocBuilder<ReaderCubit, ReaderState>(
        builder: (context, state) {
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
                      onPressed:
                          () => context.read<ReaderCubit>().loadChapter(),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state is ReaderLoaded) {
            return _ReaderView(state: state, title: state.title);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ReaderView extends StatefulWidget {
  final ReaderLoaded state;
  final String title;

  const _ReaderView({required this.state, required this.title});

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
  }

  @override
  void dispose() {
    _pageController.dispose();
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
            context.read<ReaderCubit>().goToPreviousChapter();
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
          context.read<ReaderCubit>().goToNextChapter();
        }
      }
    } else {
      // 点击中央区域，切换菜单栏显示状态
      context.read<ReaderCubit>().toggleControls();
    }
  }

  void _showChapterList() {
    final readerCubit = context.read<ReaderCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return BlocProvider.value(
          value: readerCubit,
          child: DraggableScrollableSheet(
            initialChildSize: 0.9,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            builder:
                (context, scrollController) => _ChapterList(
                  volumes: widget.state.volumes,
                  currentAid: widget.state.aid,
                  currentCid: widget.state.cid,
                  onChapterSelected: (aid, cid) {
                    Navigator.pop(context);
                    readerCubit.loadChapter(aid: aid, cid: cid);
                  },
                ),
          ),
        );
      },
    );
  }

  void _showSettings() {
    final readerCubit = context.read<ReaderCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return _ReaderSettings(readerCubit);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    final ThemeCubit themeCubit = context.read<ThemeCubit>();
    bool isDarkMode;
    if (themeCubit.state.themeMode == ReaderThemeMode.dark) {
      isDarkMode = true;
    } else if (themeCubit.state.themeMode == ReaderThemeMode.light) {
      isDarkMode = false;
    } else {
      isDarkMode = mediaQuery.platformBrightness == Brightness.dark;
    }
    final backgroundColor =
        isDarkMode
            ? themeCubit.state.darkBackgroundColor
            : themeCubit.state.lightBackgroundColor;
    final textColor =
        isDarkMode
            ? themeCubit.state.darkTextColor
            : themeCubit.state.lightTextColor;

    var viewer = BlocBuilder<ReaderCubit, ReaderState>(
      builder: (BuildContext context, state) {
        return Scaffold(
          backgroundColor: backgroundColor,
          body: Stack(
            children: [
              // 阅读内容
              Positioned.fill(
                child: GestureDetector(
                  onTapDown: _handleTap,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.state.pages.length,
                    onPageChanged: (index) {
                      context.read<ReaderCubit>().onPageChanged(index);
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
              // 控制栏
              if (state.showControls) ...[
                // 顶部栏
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
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
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
                          icon: const Icon(
                            Icons.menu_book,
                            color: Colors.white,
                          ),
                          onPressed: _showChapterList,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.settings,
                            color: Colors.white,
                          ),
                          onPressed: _showSettings,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
    return viewer;
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
    final screenWidth =
        MediaQueryData.fromView(WidgetsBinding.instance.window).size.width;
    final screenHeight =
        MediaQueryData.fromView(WidgetsBinding.instance.window).size.height;
    final topPadding =
        MediaQueryData.fromView(WidgetsBinding.instance.window).padding.top;
    final bottomPadding =
        MediaQueryData.fromView(WidgetsBinding.instance.window).padding.bottom;
    final topBarHeight = 56.0;
    final bottomBarHeight = 56.0;
    final leftAndRightPadding = 32.0;
    final canvasWidth = screenWidth - leftAndRightPadding;
    final canvasHeight =
        screenHeight -
        topPadding -
        bottomPadding -
        topBarHeight -
        bottomBarHeight;

    return BlocBuilder<FontSizeCubit, double>(
      builder: (context, fontSize) {
        return BlocBuilder<ParagraphSpacingCubit, double>(
          builder: (context, spacing) {
            return BlocBuilder<LineHeightCubit, double>(
              builder: (context, lineHeight) {
                var texts = content.split("\n");
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
              },
            );
          },
        );
      },
    );
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
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;
    final topBarHeight = 56.0;
    final bottomBarHeight = 56.0;
    final availableHeight =
        screenHeight -
        topPadding -
        bottomPadding -
        topBarHeight -
        bottomBarHeight;

    return Column(
      children: [
        Container(height: topPadding + topBarHeight),
        SizedBox(
          width: screenWidth - 32,
          height: availableHeight,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: availableHeight,
                maxWidth: screenWidth - 32,
              ),
              child: CachedImage(
                url: imageUrl,
                fit: BoxFit.contain,
                width: screenWidth - 32,
                height: availableHeight,
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
  final ReaderCubit readerCubit;

  const _ReaderSettings(this.readerCubit);

  @override
  State<_ReaderSettings> createState() => _ReaderSettingsState();
}

class _ReaderSettingsState extends State<_ReaderSettings> {
  late final paragraphSpacingCubit = context.read<ParagraphSpacingCubit>();
  late final fontSizeCubit = context.read<FontSizeCubit>();
  late final lineHeightCubit = context.read<LineHeightCubit>();

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
    return BlocBuilder<ThemeCubit, ReaderTheme>(
      builder: (context, theme) {
        return Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '设置',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // 字体大小设置
              BlocBuilder<FontSizeCubit, double>(
                builder: (context, fontSize) {
                  return Row(
                    children: [
                      Text('字体大小'),
                      Expanded(
                        child: Slider(
                          value: fontSize,
                          min: 14,
                          max: 24,
                          divisions: 10,
                          label: fontSize.round().toString(),
                          onChanged: (value) async {
                            await fontSizeCubit.updateFontSize(value);
                            await widget.readerCubit.reloadCurrentPage();
                          },
                        ),
                      ),
                      Text('${fontSize.round()}', style: TextStyle()),
                    ],
                  );
                },
              ),
              // 段落间距设置
              BlocBuilder<ParagraphSpacingCubit, double>(
                builder: (context, spacing) {
                  return Row(
                    children: [
                      Text('段落间距', style: TextStyle()),
                      Expanded(
                        child: Slider(
                          value: spacing,
                          min: 16,
                          max: 32,
                          divisions: 8,
                          label: spacing.round().toString(),
                          onChanged: (value) async {
                            await paragraphSpacingCubit.updateSpacing(value);
                            await widget.readerCubit.reloadCurrentPage();
                          },
                        ),
                      ),
                      Text('${spacing.round()}', style: TextStyle()),
                    ],
                  );
                },
              ),
              // 行高设置
              BlocBuilder<LineHeightCubit, double>(
                builder: (context, lineHeight) {
                  return Row(
                    children: [
                      Text('行高', style: TextStyle()),
                      Expanded(
                        child: Slider(
                          value: lineHeight,
                          min: 1.0,
                          max: 2.0,
                          divisions: 20,
                          label: lineHeight.toStringAsFixed(1),
                          onChanged: (value) async {
                            await lineHeightCubit.updateLineHeight(value);
                            await widget.readerCubit.reloadCurrentPage();
                          },
                        ),
                      ),
                      Text(lineHeight.toStringAsFixed(1), style: TextStyle()),
                    ],
                  );
                },
              ),
              const Divider(),
              // 主题模式选择
              Row(
                children: [
                  Text('主题模式', style: TextStyle()),
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
                        await context.read<ThemeCubit>().setThemeMode(
                          modes.first,
                        );
                        await widget.readerCubit.reloadCurrentPage();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 浅色主题颜色设置
              Row(
                children: [
                  Text('浅色主题', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: theme.lightBackgroundColor,
                          border: Border.all(color: Colors.grey),
                          shape: BoxShape.circle,
                        ),
                      ),
                      label: const Text('背景颜色'),
                      onPressed:
                          () => _showColorPicker(
                            context,
                            theme.lightBackgroundColor,
                            (color) async {
                              await context
                                  .read<ThemeCubit>()
                                  .updateLightBackgroundColor(color);
                              await widget.readerCubit.reloadCurrentPage();
                            },
                          ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: theme.lightTextColor,
                          border: Border.all(color: Colors.grey),
                          shape: BoxShape.circle,
                        ),
                      ),
                      label: const Text('文字颜色'),
                      onPressed:
                          () => _showColorPicker(
                            context,
                            theme.lightTextColor,
                            (color) async {
                              await context
                                  .read<ThemeCubit>()
                                  .updateLightTextColor(color);
                              await widget.readerCubit.reloadCurrentPage();
                            },
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 深色主题颜色设置
              Row(
                children: [
                  Text('深色主题', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: theme.darkBackgroundColor,
                          border: Border.all(color: Colors.grey),
                          shape: BoxShape.circle,
                        ),
                      ),
                      label: const Text('背景颜色'),
                      onPressed:
                          () => _showColorPicker(
                            context,
                            theme.darkBackgroundColor,
                            (color) async {
                              await context
                                  .read<ThemeCubit>()
                                  .updateDarkBackgroundColor(color);
                              await widget.readerCubit.reloadCurrentPage();
                            },
                          ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: theme.darkTextColor,
                          border: Border.all(color: Colors.grey),
                          shape: BoxShape.circle,
                        ),
                      ),
                      label: const Text('文字颜色'),
                      onPressed:
                          () => _showColorPicker(context, theme.darkTextColor, (
                            color,
                          ) async {
                            await context
                                .read<ThemeCubit>()
                                .updateDarkTextColor(color);
                            await widget.readerCubit.reloadCurrentPage();
                          }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 重置按钮
              TextButton(
                onPressed: () async {
                  await context.read<ThemeCubit>().resetToDefault();
                  await widget.readerCubit.reloadCurrentPage();
                },
                child: const Text('重置为默认'),
              ),
            ],
          ),
        );
      },
    );
  }
}
