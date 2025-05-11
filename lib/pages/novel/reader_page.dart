import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/pages/novel/paragraph_spacing_cubit.dart';
import 'package:wild/pages/novel/reader_cubit.dart';
import 'package:wild/pages/novel/theme_cubit.dart';

import '../../src/rust/wenku8/models.dart';
import 'font_size_cubit.dart';
import 'line_height_cubit.dart';

class ReaderPage extends StatelessWidget {
  final String aid;
  final String cid;
  final String initialTitle;
  final List<Volume> volumes;

  const ReaderPage({
    super.key,
    required this.aid,
    required this.cid,
    required this.initialTitle,
    required this.volumes,
  });

  @override
  Widget build(BuildContext context) {
    final fontSizeCubit = context.read<FontSizeCubit>();
    final paragraphSpacingCubit = context.read<ParagraphSpacingCubit>();
    final lineHeightCubit = context.read<LineHeightCubit>();

    return BlocProvider(
      create:
          (context) => ReaderCubit(
            initialAid: aid,
            initialCid: cid,
            initialVolumes: volumes,
            fontSizeCubit: fontSizeCubit,
            paragraphSpacingCubit: paragraphSpacingCubit,
            lineHeightCubit: lineHeightCubit,
          )..loadChapter(),
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
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
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

    var viewer = Scaffold(
      backgroundColor: backgroundColor,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // 阅读内容
            PageView.builder(
              controller: _pageController,
              itemCount: widget.state.pages.length,
              onPageChanged: (index) {
                context.read<ReaderCubit>().onPageChanged(index);
              },
              itemBuilder: (context, index) {
                final page = widget.state.pages[index];
                if (page.isImage) {
                  return _ImagePage(imageUrl: page.content);
                }
                return _TextPage(content: page.content, textColor: textColor);
              },
            ),
            // 控制栏
            if (_showControls) ...[
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
              // 底部栏
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          final currentVolumeIndex = _findCurrentVolumeIndex();
                          final currentChapterIndex =
                              _findCurrentChapterIndex();
                          if (currentChapterIndex > 0 ||
                              currentVolumeIndex > 0) {
                            context.read<ReaderCubit>().goToPreviousChapter();
                          }
                        },
                      ),
                      Text(
                        '${widget.state.currentPageIndex + 1}/${widget.state.pages.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          final currentVolumeIndex = _findCurrentVolumeIndex();
                          final currentChapterIndex =
                              _findCurrentChapterIndex();
                          final volume =
                              widget.state.volumes[currentVolumeIndex];
                          if (currentChapterIndex <
                                  volume.chapters.length - 1 ||
                              currentVolumeIndex <
                                  widget.state.volumes.length - 1) {
                            context.read<ReaderCubit>().goToNextChapter();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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

  const _TextPage({required this.content, required this.textColor});

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

  const _ImagePage({required this.imageUrl});

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

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16,
        topPadding + topBarHeight,
        16,
        bottomPadding + bottomBarHeight,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: availableHeight,
            maxWidth: screenWidth - 32,
          ),
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value:
                      loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '图片加载失败\n$error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              );
            },
            // 添加缓存和内存管理选项
            cacheWidth:
                (screenWidth * MediaQuery.of(context).devicePixelRatio).round(),
            cacheHeight:
                (availableHeight * MediaQuery.of(context).devicePixelRatio)
                    .round(),
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: child,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChapterList extends StatelessWidget {
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
            child: const Row(
              children: [
                Icon(Icons.menu_book),
                SizedBox(width: 8),
                Text(
                  '目录',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: volumes.length,
              itemBuilder: (context, volumeIndex) {
                final volume = volumes[volumeIndex];
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
                          chapter.aid == currentAid &&
                          chapter.cid == currentCid;
                      return ListTile(
                        title: Text(
                          chapter.title,
                          style: TextStyle(
                            color:
                                isSelected
                                    ? Theme.of(context).primaryColor
                                    : null,
                            fontWeight: isSelected ? FontWeight.bold : null,
                          ),
                        ),
                        onTap:
                            () => onChapterSelected(chapter.aid, chapter.cid),
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
                  Text(
                    '主题模式',
                    style: TextStyle(
                    ),
                  ),
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
              const SizedBox(height: 8),
              // 浅色主题颜色设置
              ExpansionTile(
                title: Text(
                  '浅色主题颜色',
                  style: TextStyle(
                  ),
                ),
                children: [
                  // 浅色背景颜色选择
                  Row(
                    children: [
                      Text('背景颜色', style: TextStyle()),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ColorOption(
                              color: Colors.white,
                              isSelected:
                                  theme.lightBackgroundColor == Colors.white,
                              onTap: () async {
                                await context
                                    .read<ThemeCubit>()
                                    .updateLightBackgroundColor(Colors.white);
                                await widget.readerCubit.reloadCurrentPage();
                              },
                            ),
                            _ColorOption(
                              color: const Color(0xFFF5F5F5),
                              isSelected:
                                  theme.lightBackgroundColor ==
                                  const Color(0xFFF5F5F5),
                              onTap: () async {
                                await context
                                    .read<ThemeCubit>()
                                    .updateLightBackgroundColor(
                                      const Color(0xFFF5F5F5),
                                    );
                                await widget.readerCubit.reloadCurrentPage();
                              },
                            ),
                            _ColorOption(
                              color: const Color(0xFFF0F0F0),
                              isSelected:
                                  theme.lightBackgroundColor ==
                                  const Color(0xFFF0F0F0),
                              onTap: () async {
                                await context
                                    .read<ThemeCubit>()
                                    .updateLightBackgroundColor(
                                      const Color(0xFFF0F0F0),
                                    );
                                await widget.readerCubit.reloadCurrentPage();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 浅色文字颜色选择
                  Row(
                    children: [
                      Text('文字颜色', style: TextStyle()),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ColorOption(
                              color: Colors.black87,
                              isSelected:
                                  theme.lightTextColor == Colors.black87,
                              onTap: () async {
                                await context
                                    .read<ThemeCubit>()
                                    .updateLightTextColor(Colors.black87);
                                await widget.readerCubit.reloadCurrentPage();
                              },
                            ),
                            _ColorOption(
                              color: const Color(0xFF424242),
                              isSelected:
                                  theme.lightTextColor ==
                                  const Color(0xFF424242),
                              onTap: () async {
                                await context
                                    .read<ThemeCubit>()
                                    .updateLightTextColor(
                                      const Color(0xFF424242),
                                    );
                                await widget.readerCubit.reloadCurrentPage();
                              },
                            ),
                            _ColorOption(
                              color: const Color(0xFF616161),
                              isSelected:
                                  theme.lightTextColor ==
                                  const Color(0xFF616161),
                              onTap: () async {
                                await context
                                    .read<ThemeCubit>()
                                    .updateLightTextColor(
                                      const Color(0xFF616161),
                                    );
                                await widget.readerCubit.reloadCurrentPage();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // 深色主题颜色设置
              ExpansionTile(
                title: Text(
                  '深色主题颜色',
                  style: TextStyle(
                  ),
                ),
                children: [
                  // 深色背景颜色选择
                  Row(
                    children: [
                      Text('背景颜色', style: TextStyle()),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ColorOption(
                              color: const Color(0xFF1A1A1A),
                              isSelected:
                                  theme.darkBackgroundColor ==
                                  const Color(0xFF1A1A1A),
                              onTap: () async {
                                await context
                                    .read<ThemeCubit>()
                                    .updateDarkBackgroundColor(
                                      const Color(0xFF1A1A1A),
                                    );
                                await widget.readerCubit.reloadCurrentPage();
                              },
                            ),
                            _ColorOption(
                              color: const Color(0xFF2C2C2C),
                              isSelected:
                                  theme.darkBackgroundColor ==
                                  const Color(0xFF2C2C2C),
                              onTap: () async {
                                await context
                                    .read<ThemeCubit>()
                                    .updateDarkBackgroundColor(
                                      const Color(0xFF2C2C2C),
                                    );
                                await widget.readerCubit.reloadCurrentPage();
                              },
                            ),
                            _ColorOption(
                              color: const Color(0xFF121212),
                              isSelected:
                                  theme.darkBackgroundColor ==
                                  const Color(0xFF121212),
                              onTap: () async {
                                await context
                                    .read<ThemeCubit>()
                                    .updateDarkBackgroundColor(
                                      const Color(0xFF121212),
                                    );
                                await widget.readerCubit.reloadCurrentPage();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 深色文字颜色选择
                  Row(
                    children: [
                      Text('文字颜色', style: TextStyle()),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ColorOption(
                              color: const Color(0xFFE0E0E0),
                              isSelected:
                                  theme.darkTextColor ==
                                  const Color(0xFFE0E0E0),
                              onTap: () async {
                                await context
                                    .read<ThemeCubit>()
                                    .updateDarkTextColor(
                                      const Color(0xFFE0E0E0),
                                    );
                                await widget.readerCubit.reloadCurrentPage();
                              },
                            ),
                            _ColorOption(
                              color: const Color(0xFFBDBDBD),
                              isSelected:
                                  theme.darkTextColor ==
                                  const Color(0xFFBDBDBD),
                              onTap: () async {
                                await context
                                    .read<ThemeCubit>()
                                    .updateDarkTextColor(
                                      const Color(0xFFBDBDBD),
                                    );
                                await widget.readerCubit.reloadCurrentPage();
                              },
                            ),
                            _ColorOption(
                              color: const Color(0xFF9E9E9E),
                              isSelected:
                                  theme.darkTextColor ==
                                  const Color(0xFF9E9E9E),
                              onTap: () async {
                                await context
                                    .read<ThemeCubit>()
                                    .updateDarkTextColor(
                                      const Color(0xFF9E9E9E),
                                    );
                                await widget.readerCubit.reloadCurrentPage();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 重置按钮
              TextButton(
                onPressed: () async {
                  await context.read<ThemeCubit>().resetToDefault();
                  await widget.readerCubit.reloadCurrentPage();
                },
                child: Text(
                  '重置为默认',
                  style: TextStyle(
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ColorOption extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorOption({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey,
            width: isSelected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}
