import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../src/rust/wenku8/models.dart';
import 'html_reader_cubit.dart';
import 'package:wild/pages/novel/top_bar_height_cubit.dart';
import 'package:wild/pages/novel/bottom_bar_height_cubit.dart';

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
    return BlocProvider(
      create: (context) => HtmlReaderCubit(
        novelInfo: novelInfo,
        initialAid: initialAid,
        initialCid: initialCid,
        initialVolumes: volumes,
      )..loadChapter(),
      child: const _HtmlReaderView(),
    );
  }
}

class _HtmlReaderView extends StatelessWidget {
  const _HtmlReaderView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<HtmlReaderCubit, HtmlReaderState>(
          builder: (context, state) {
            if (state is HtmlReaderLoaded) {
              return Text(state.title);
            }
            return const Text('加载中...');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => _ChapterList(
                  volumes: context.read<HtmlReaderCubit>().initialVolumes,
                  currentAid: context.read<HtmlReaderCubit>().initialAid,
                  currentCid: context.read<HtmlReaderCubit>().initialCid,
                  onChapterSelected: (aid, cid) {
                    context.read<HtmlReaderCubit>().loadChapter(aid: aid, cid: cid);
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<HtmlReaderCubit, HtmlReaderState>(
        builder: (context, state) {
          if (state is HtmlReaderLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is HtmlReaderError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.error),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<HtmlReaderCubit>().loadChapter();
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }
          if (state is HtmlReaderLoaded) {
            return _ReaderContent(
              content: state.content,
              onPreviousChapter: () {
                context.read<HtmlReaderCubit>().goToPreviousChapter();
              },
              onNextChapter: () {
                context.read<HtmlReaderCubit>().goToNextChapter();
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ReaderContent extends StatelessWidget {
  final String content;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;

  const _ReaderContent({
    required this.content,
    required this.onPreviousChapter,
    required this.onNextChapter,
  });

  @override
  Widget build(BuildContext context) {
    final topBarHeight = context.read<TopBarHeightCubit>().state;
    final bottomBarHeight = context.read<BottomBarHeightCubit>().state;

    return Column(
      children: [
        SizedBox(height: topBarHeight),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Html(
                  data: content,
                  style: {
                    'body': Style(
                      fontSize: FontSize(16),
                      lineHeight: LineHeight(1.8),
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                    ),
                    'p': Style(
                      margin: Margins.only(bottom: 16),
                    ),
                  },
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: onPreviousChapter,
                      child: const Text('上一章'),
                    ),
                    TextButton(
                      onPressed: onNextChapter,
                      child: const Text('下一章'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        SizedBox(height: bottomBarHeight),
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
    _currentChapterGlobalIndex = _calculateCurrentChapterIndex();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        const estimatedItemHeight = 56.0;
        const estimatedVolumeTitleHeight = 48.0;
        const estimatedSpacing = 16.0;

        double targetScroll = _currentChapterGlobalIndex * (estimatedItemHeight + estimatedSpacing);
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
        (chapter) => chapter.aid == widget.currentAid && chapter.cid == widget.currentCid,
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
        if (chapter.aid == widget.currentAid && chapter.cid == widget.currentCid) {
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
                      final isSelected = chapter.aid == widget.currentAid && chapter.cid == widget.currentCid;
                      return ListTile(
                        title: Text(
                          chapter.title,
                          style: TextStyle(
                            color: isSelected ? Theme.of(context).colorScheme.primary : null,
                          ),
                        ),
                        selected: isSelected,
                        onTap: () => widget.onChapterSelected(chapter.aid, chapter.cid),
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