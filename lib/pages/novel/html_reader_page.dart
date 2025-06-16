import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../src/rust/wenku8/models.dart';
import 'html_reader_cubit.dart';
import 'package:wild/pages/novel/top_bar_height_cubit.dart';
import 'package:wild/pages/novel/bottom_bar_height_cubit.dart';
import 'package:wild/pages/novel/font_size_cubit.dart';
import 'package:wild/pages/novel/line_height_cubit.dart';
import 'package:wild/pages/novel/paragraph_spacing_cubit.dart';
import 'package:wild/pages/novel/theme_cubit.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:wild/widgets/cached_image.dart';
import 'package:wild/pages/novel/fullscreen_cubit.dart';
import 'package:wild/cubits/screen_keep_on.dart';
import 'package:wild/pages/novel/auto_scroll_cubit.dart';
import 'dart:async';

class HtmlReaderPage extends StatelessWidget {
  final NovelInfo novelInfo;
  final String initialAid;
  final String initialCid;
  final List<Volume> volumes;

  const HtmlReaderPage({
    super.key,
    required this.novelInfo,
    required this.initialAid,
    required this.initialCid,
    required this.volumes,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => HtmlReaderCubit(
            novelInfo: novelInfo,
            initialAid: initialAid,
            initialCid: initialCid,
            initialVolumes: volumes,
          )..loadChapter(),
        ),
        BlocProvider(create: (context) => FullscreenCubit()),
        BlocProvider(create: (context) => AutoScrollCubit()),
      ],
      child: const _HtmlReaderViewWrapper(),
    );
  }
}

class _HtmlReaderViewWrapper extends StatefulWidget {
  const _HtmlReaderViewWrapper();

  @override
  State<_HtmlReaderViewWrapper> createState() => _HtmlReaderViewWrapperState();
}

class _HtmlReaderViewWrapperState extends State<_HtmlReaderViewWrapper> {
  late final ScrollController _scrollController;
  Timer? _autoScrollTimer;
  static const _scrollSpeed = 1.0; // pixels per frame

  @override
  void initState() {
    super.initState();
    setKeepScreenUpOnReading(true);
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    setKeepScreenUpOnReading(false);
    setKeepScreenUpOnScroll(false);
    _scrollController.dispose();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _showSettings(BuildContext context) {
    final fontSizeCubit = context.read<FontSizeCubit>();
    final lineHeightCubit = context.read<LineHeightCubit>();
    final paragraphSpacingCubit = context.read<ParagraphSpacingCubit>();
    final themeCubit = context.read<ThemeCubit>();
    final topBarHeightCubit = context.read<TopBarHeightCubit>();
    final bottomBarHeightCubit = context.read<BottomBarHeightCubit>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: fontSizeCubit),
            BlocProvider.value(value: lineHeightCubit),
            BlocProvider.value(value: paragraphSpacingCubit),
            BlocProvider.value(value: themeCubit),
            BlocProvider.value(value: topBarHeightCubit),
            BlocProvider.value(value: bottomBarHeightCubit),
          ],
          child: _ReaderSettings(),
        );
      },
    );
  }

  void _toggleAutoScroll(BuildContext context) {
    final autoScrollCubit = context.read<AutoScrollCubit>();
    final fullscreenCubit = context.read<FullscreenCubit>();
    
    if (!autoScrollCubit.state) {
      // Start auto-scroll
      fullscreenCubit.toggle();
      autoScrollCubit.start();
      _startAutoScroll();
    } else {
      // Stop auto-scroll
      autoScrollCubit.stop();
      _stopAutoScroll();
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.offset;
        
        if (currentScroll >= maxScroll) {
          // Reached the end, stop auto-scroll
          context.read<AutoScrollCubit>().stop();
          _stopAutoScroll();
          return;
        }
        
        _scrollController.jumpTo(currentScroll + _scrollSpeed);
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HtmlReaderCubit>();
    return BlocBuilder<ThemeCubit, ReaderTheme>(
      builder: (context, theme) {
        final mediaQuery = MediaQuery.of(context);
        bool isDarkMode;
        if (theme.themeMode == ReaderThemeMode.dark) {
          isDarkMode = true;
        } else if (theme.themeMode == ReaderThemeMode.light) {
          isDarkMode = false;
        } else {
          isDarkMode = mediaQuery.platformBrightness == Brightness.dark;
        }

        final backgroundColor =
            isDarkMode ? theme.darkBackgroundColor : theme.lightBackgroundColor;
        final textColor =
            isDarkMode ? theme.darkTextColor : theme.lightTextColor;

        return BlocBuilder<HtmlReaderCubit, HtmlReaderState>(
          builder: (context, state) {
            return BlocBuilder<FullscreenCubit, bool>(
              builder: (context, isFullscreen) {
                return BlocListener<FullscreenCubit, bool>(
                  listener: (context, isFullscreen) {
                    if (!isFullscreen) {
                      // Exit fullscreen, stop auto-scroll
                      context.read<AutoScrollCubit>().stop();
                      _stopAutoScroll();
                    }
                  },
                  child: Scaffold(
                    backgroundColor: backgroundColor,
                    extendBodyBehindAppBar: true,
                    appBar: isFullscreen
                        ? null
                        : AppBar(
                            backgroundColor: backgroundColor.withOpacity(0.8),
                            elevation: 0,
                            title: state is HtmlReaderLoaded
                                ? Text(state.title)
                                : const Text('加载中...'),
                            actions: [
                              BlocBuilder<AutoScrollCubit, bool>(
                                builder: (context, isAutoScrolling) {
                                  return IconButton(
                                    icon: Icon(
                                      isAutoScrolling
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                    ),
                                    onPressed: () => _toggleAutoScroll(context),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.settings),
                                onPressed: () => _showSettings(context),
                              ),
                              IconButton(
                                icon: const Icon(Icons.menu),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    builder:
                                        (context) => BlocProvider.value(
                                          value: cubit,
                                          child: _ChapterList(
                                            volumes: cubit.initialVolumes,
                                            currentAid: cubit.initialAid,
                                            currentCid: cubit.initialCid,
                                            onChapterSelected: (aid, cid) {
                                              cubit.loadChapter(
                                                aid: aid,
                                                cid: cid,
                                              );
                                              Navigator.pop(context);
                                            },
                                          ),
                                        ),
                                  );
                                },
                              ),
                            ],
                          ),
                    body: Stack(
                      children: [
                        // 底层内容
                        GestureDetector(
                          onTap: () {
                            context.read<FullscreenCubit>().toggle();
                          },
                          child:
                              state is HtmlReaderLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : state is HtmlReaderError
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            state.error,
                                            style: TextStyle(color: textColor),
                                          ),
                                          const SizedBox(height: 16),
                                          ElevatedButton(
                                            onPressed: () {
                                              context
                                                  .read<HtmlReaderCubit>()
                                                  .loadChapter();
                                            },
                                            child: const Text('重试'),
                                          ),
                                        ],
                                      ),
                                    )
                                  : state is HtmlReaderLoaded
                                  ? _ReaderContent(
                                      parsedContent: state.parsedContent,
                                      onPreviousChapter: () {
                                        context
                                            .read<HtmlReaderCubit>()
                                            .goToPreviousChapter();
                                      },
                                      onNextChapter: () {
                                        context
                                            .read<HtmlReaderCubit>()
                                            .goToNextChapter();
                                      },
                                      scrollController: _scrollController,
                                    )
                                  : const SizedBox.shrink(),
                        ),
                        // 顶部和底部导航按钮（仅在隐藏 AppBar 时显示）
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ReaderContent extends StatelessWidget {
  final List<ParsedContent> parsedContent;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
  final ScrollController scrollController;

  const _ReaderContent({
    required this.parsedContent,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.scrollController,
  });

  List<Widget> _buildContentWidgets(
    BuildContext context, {
    required double fontSize,
    required double lineHeight,
    required double paragraphSpacing,
    required Color textColor,
  }) {
    final widgets = <Widget>[];

    for (var content in parsedContent) {
      if (content is ParsedText) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: paragraphSpacing),
            child: Text(
              content.text,
              style: TextStyle(
                fontSize: fontSize,
                height: lineHeight,
                color: textColor,
              ),
            ),
          ),
        );
      } else if (content is ParsedImage) {
        widgets.add(
          LayoutBuilder(
            builder: (context, constraints) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: paragraphSpacing),
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: AspectRatio(
                    aspectRatio: 4 / 3, // 默认图片比例
                    child: Image(
                      image: CachedImageProvider(content.imageUrl),
                      width: constraints.maxWidth,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: constraints.maxWidth,
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: constraints.maxWidth,
                          color: Colors.grey[200],
                          child: const Center(child: Text('图片加载失败')),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ReaderTheme>(
      builder: (context, theme) {
        final mediaQuery = MediaQuery.of(context);
        bool isDarkMode;
        if (theme.themeMode == ReaderThemeMode.dark) {
          isDarkMode = true;
        } else if (theme.themeMode == ReaderThemeMode.light) {
          isDarkMode = false;
        } else {
          isDarkMode = mediaQuery.platformBrightness == Brightness.dark;
        }

        final backgroundColor =
            isDarkMode ? theme.darkBackgroundColor : theme.lightBackgroundColor;
        final textColor =
            isDarkMode ? theme.darkTextColor : theme.lightTextColor;

        return BlocBuilder<FontSizeCubit, double>(
          builder: (context, fontSize) {
            return BlocBuilder<LineHeightCubit, double>(
              builder: (context, lineHeight) {
                return BlocBuilder<ParagraphSpacingCubit, double>(
                  builder: (context, paragraphSpacing) {
                    return BlocBuilder<TopBarHeightCubit, double>(
                      builder: (context, topBarHeight) {
                        return BlocBuilder<BottomBarHeightCubit, double>(
                          builder: (context, bottomBarHeight) {
                            return BlocBuilder<FullscreenCubit, bool>(
                              builder: (context, isFullscreen) {
                                final topPad =
                                    MediaQueryData.fromView(
                                      WidgetsBinding.instance.window,
                                    ).padding.top;
                                final bottomPad =
                                    MediaQueryData.fromView(
                                      WidgetsBinding.instance.window,
                                    ).padding.bottom;

                                final col = [
                                  ..._buildContentWidgets(
                                    context,
                                    fontSize: fontSize,
                                    lineHeight: lineHeight,
                                    paragraphSpacing: paragraphSpacing,
                                    textColor: textColor,
                                  ),
                                  ...[
                                    const SizedBox(height: 32),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        TextButton(
                                          onPressed: onPreviousChapter,
                                          child: Text(
                                            '上一章',
                                            style: TextStyle(color: textColor),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: onNextChapter,
                                          child: Text(
                                            '下一章',
                                            style: TextStyle(color: textColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                  ],
                                ];

                                return ListView(
                                  controller: scrollController,
                                  padding: EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    top: topBarHeight + topPad,
                                    bottom: bottomBarHeight + bottomPad,
                                  ),
                                  children: col,
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ReaderSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final fontSizeCubit = context.read<FontSizeCubit>();
    final paragraphSpacingCubit = context.read<ParagraphSpacingCubit>();
    final lineHeightCubit = context.read<LineHeightCubit>();
    final themeCubit = context.read<ThemeCubit>();
    final topBarHeightCubit = context.read<TopBarHeightCubit>();
    final bottomBarHeightCubit = context.read<BottomBarHeightCubit>();

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
                          onChanged: (value) {
                            fontSizeCubit.updateFontSize(value);
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
                      Text('段落间距'),
                      Expanded(
                        child: Slider(
                          value: spacing,
                          min: 16,
                          max: 32,
                          divisions: 8,
                          label: spacing.round().toString(),
                          onChanged: (value) {
                            paragraphSpacingCubit.updateSpacing(value);
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
                      Text('行高'),
                      Expanded(
                        child: Slider(
                          value: lineHeight,
                          min: 1.0,
                          max: 2.0,
                          divisions: 20,
                          label: lineHeight.toStringAsFixed(1),
                          onChanged: (value) {
                            lineHeightCubit.updateLineHeight(value);
                          },
                        ),
                      ),
                      Text(lineHeight.toStringAsFixed(1), style: TextStyle()),
                    ],
                  );
                },
              ),
              // 边距设置
              BlocBuilder<TopBarHeightCubit, double>(
                builder: (context, topBarHeight) {
                  return BlocBuilder<BottomBarHeightCubit, double>(
                    builder: (context, bottomBarHeight) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Text('顶部边距'),
                              Expanded(
                                child: Slider(
                                  value: topBarHeight,
                                  min: 0,
                                  max: 100,
                                  divisions: 20,
                                  label: topBarHeight.round().toString(),
                                  onChanged: (value) {
                                    topBarHeightCubit.updateHeight(value);
                                  },
                                ),
                              ),
                              Text(
                                '${topBarHeight.round()}',
                                style: TextStyle(),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text('底部边距'),
                              Expanded(
                                child: Slider(
                                  value: bottomBarHeight,
                                  min: 0,
                                  max: 100,
                                  divisions: 20,
                                  label: bottomBarHeight.round().toString(),
                                  onChanged: (value) {
                                    bottomBarHeightCubit.updateHeight(value);
                                  },
                                ),
                              ),
                              Text(
                                '${bottomBarHeight.round()}',
                                style: TextStyle(),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const Divider(),
              // 主题模式选择
              Row(
                children: [
                  Text('主题模式'),
                  const SizedBox(width: 16),
                  Expanded(
                    child: BlocBuilder<ThemeCubit, ReaderTheme>(
                      builder: (context, theme) {
                        return SegmentedButton<ReaderThemeMode>(
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
                          onSelectionChanged: (Set<ReaderThemeMode> modes) {
                            themeCubit.setThemeMode(modes.first);
                          },
                        );
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
                    child: BlocBuilder<ThemeCubit, ReaderTheme>(
                      builder: (context, theme) {
                        return OutlinedButton.icon(
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
                                (color) {
                                  themeCubit.updateLightBackgroundColor(color);
                                },
                              ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: BlocBuilder<ThemeCubit, ReaderTheme>(
                      builder: (context, theme) {
                        return OutlinedButton.icon(
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
                                (color) {
                                  themeCubit.updateLightTextColor(color);
                                },
                              ),
                        );
                      },
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
                    child: BlocBuilder<ThemeCubit, ReaderTheme>(
                      builder: (context, theme) {
                        return OutlinedButton.icon(
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
                                (color) {
                                  themeCubit.updateDarkBackgroundColor(color);
                                },
                              ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: BlocBuilder<ThemeCubit, ReaderTheme>(
                      builder: (context, theme) {
                        return OutlinedButton.icon(
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
                              () => _showColorPicker(
                                context,
                                theme.darkTextColor,
                                (color) {
                                  themeCubit.updateDarkTextColor(color);
                                },
                              ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 重置按钮
              TextButton(
                onPressed: () async {
                  await themeCubit.resetToDefault();
                  await topBarHeightCubit.updateHeight(56);
                  await bottomBarHeightCubit.updateHeight(56);
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
    _currentChapterGlobalIndex = _calculateCurrentChapterIndex();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        const estimatedItemHeight = 56.0;
        const estimatedVolumeTitleHeight = 48.0;
        const estimatedSpacing = 16.0;

        double targetScroll =
            _currentChapterGlobalIndex *
            (estimatedItemHeight + estimatedSpacing);
        for (var i = 0; i < widget.volumes.length; i++) {
          if (i < _findCurrentVolumeIndex()) {
            targetScroll += estimatedVolumeTitleHeight + estimatedSpacing;
          } else {
            break;
          }
        }

        _scrollController.animateTo(
          targetScroll - 100,
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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        children: [
          AppBar(
            title: const Text('目录'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
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
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    ...volume.chapters.map((chapter) {
                      final isSelected =
                          chapter.aid == widget.currentAid &&
                          chapter.cid == widget.currentCid;
                      return ListTile(
                        title: Text(
                          chapter.title,
                          style: TextStyle(
                            color:
                                isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                          ),
                        ),
                        selected: isSelected,
                        onTap:
                            () => widget.onChapterSelected(
                              chapter.aid,
                              chapter.cid,
                            ),
                      );
                    }).toList(),
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
