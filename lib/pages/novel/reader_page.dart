import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/pages/novel/reader_cubit.dart';

import '../../src/rust/wenku8/models.dart';

class ReaderPage extends StatelessWidget {
  final String aid;
  final String cid;
  final String title;
  final List<Volume> volumes;

  const ReaderPage({
    super.key,
    required this.aid,
    required this.cid,
    required this.title,
    required this.volumes,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReaderCubit(
        initialAid: aid,
        initialCid: cid,
        initialVolumes: volumes,
      )..loadChapter(),
      child: BlocBuilder<ReaderCubit, ReaderState>(
        builder: (context, state) {
          if (state is ReaderLoading) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
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
                      onPressed: () => context.read<ReaderCubit>().loadChapter(),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state is ReaderLoaded) {
            return _ReaderView(
              state: state,
              title: title,
            );
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

  const _ReaderView({
    required this.state,
    required this.title,
  });

  @override
  State<_ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<_ReaderView> {
  late PageController _pageController;
  late double _fontSize;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fontSize = widget.state.fontSize;
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
            builder: (context, scrollController) => _ChapterList(
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
      builder: (BuildContext context) {
        return BlocProvider.value(
          value: readerCubit,
          child: _ReaderSettings(
            fontSize: _fontSize,
            onFontSizeChanged: (size) {
              setState(() {
                _fontSize = size;
              });
              readerCubit.updateFontSize(size);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    return Scaffold(
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
                return _TextPage(
                  content: page.content,
                  fontSize: _fontSize,
                );
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
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                        onPressed: widget.state.canGoPrevious
                            ? () => context.read<ReaderCubit>().goToPreviousChapter()
                            : null,
                      ),
                      Text(
                        '${widget.state.currentPage + 1}/${widget.state.pages.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                        onPressed: widget.state.canGoNext
                            ? () => context.read<ReaderCubit>().goToNextChapter()
                            : null,
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
  }
}

class _TextPage extends StatelessWidget {
  final String content;
  final double fontSize;

  const _TextPage({
    required this.content,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top + 72; // 顶部栏高度
    final bottomPadding = mediaQuery.padding.bottom + 72; // 底部栏高度

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, bottomPadding),
      child: SingleChildScrollView(
        child: Text(
          content,
          style: TextStyle(
            fontSize: fontSize,
            height: 1.5,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _ImagePage extends StatelessWidget {
  final String imageUrl;

  const _ImagePage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.error_outline, size: 48, color: Colors.red),
            );
          },
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
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.menu_book),
                SizedBox(width: 8),
                Text(
                  '目录',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
                          chapter.aid == currentAid && chapter.cid == currentCid;
                      return ListTile(
                        title: Text(
                          chapter.title,
                          style: TextStyle(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : null,
                            fontWeight:
                                isSelected ? FontWeight.bold : null,
                          ),
                        ),
                        onTap: () => onChapterSelected(chapter.aid, chapter.cid),
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

class _ReaderSettings extends StatelessWidget {
  final double fontSize;
  final Function(double) onFontSizeChanged;

  const _ReaderSettings({
    required this.fontSize,
    required this.onFontSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReaderCubit, ReaderState>(
      builder: (context, state) {
        final currentFontSize = state is ReaderLoaded ? state.fontSize : fontSize;
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '设置',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('字体大小'),
                  Expanded(
                    child: Slider(
                      value: currentFontSize,
                      min: 14,
                      max: 24,
                      divisions: 10,
                      label: currentFontSize.round().toString(),
                      onChanged: onFontSizeChanged,
                    ),
                  ),
                  Text('${currentFontSize.round()}'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
} 