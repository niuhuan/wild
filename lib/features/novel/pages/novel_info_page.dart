import 'package:flutter/material.dart';
import 'package:wild/src/rust/api/wenku8.dart' as w8;
import 'package:wild/widgets/cached_image.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:wild/features/home/stores/bookshelf_store.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:wild/state/app_state.dart' as app;

import 'package:wild/src/rust/wenku8/models.dart';
import 'package:wild/features/novel/stores/novel_info_store.dart';

class NovelInfoPage extends StatefulWidget {
  final String novelId;

  const NovelInfoPage({super.key, required this.novelId});

  @override
  State<NovelInfoPage> createState() => _NovelInfoPageState();
}

class _NovelInfoPageState extends State<NovelInfoPage> {
  late final NovelInfoStore _store;

  @override
  void initState() {
    super.initState();
    _store = NovelInfoStore(widget.novelId)..load();
  }

  Future<void> _navigateToDownload(BuildContext context) async {
    final state = _store.state;
    if (state is! NovelInfoLoaded) return;

    try {
      final downloadInfo = await w8.existsDownload(novelId: widget.novelId);
      if (!context.mounted) return;

      await Navigator.pushNamed(
        context,
        '/novel/downloading',
        arguments: {
          'novelId': widget.novelId,
          'existsDownload': downloadInfo,
          'novelInfo': state.novelInfo,
          'volumes': state.volumes,
        },
      );
    } catch (e) {
      print('获取下载信息失败: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('获取下载信息失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final state = _store.signal.watch(context);
      final bookshelfState = app.bookshelf.signal.watch(context);
      final isInBookshelf = bookshelfState.isBookInBookshelf(widget.novelId);

      return Scaffold(
        appBar: AppBar(
          title: const Text('小说详情'),
          actions: [
            if (state is NovelInfoLoaded)
              IconButton(
                icon: const Icon(Icons.download_outlined),
                onPressed: () => _navigateToDownload(context),
              ),
            if (bookshelfState.status == BookshelfStatus.loading)
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: Icon(
                  isInBookshelf ? Icons.bookmark : Icons.bookmark_border,
                  color: isInBookshelf
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                onPressed: () async {
                  try {
                    if (isInBookshelf) {
                      await app.bookshelf.removeFromBookshelf(widget.novelId);
                    } else {
                      await app.bookshelf.addToBookshelf(widget.novelId);
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('操作失败: $e')));
                  }
                },
              ),
          ],
        ),
        body: switch (state) {
          NovelInfoLoading() => const Center(child: CircularProgressIndicator()),
          NovelInfoError() =>
            Center(child: Text('加载失败: ${(state as NovelInfoError).message}')),
          NovelInfoLoaded() => _NovelInfoContent(
              novelInfo: (state as NovelInfoLoaded).novelInfo,
              volumes: (state as NovelInfoLoaded).volumes,
              novelId: widget.novelId,
              readingHistory: (state as NovelInfoLoaded).readingHistory,
              store: _store,
            ),
          _ => const SizedBox.shrink(),
        },
      );
    });
  }
}

class _NovelInfoContent extends StatelessWidget {
  final NovelInfo novelInfo;
  final List<Volume> volumes;
  final String novelId;
  final w8.ReadingHistory? readingHistory;
  final NovelInfoStore store;

  const _NovelInfoContent({
    required this.novelInfo,
    required this.volumes,
    required this.novelId,
    required this.readingHistory,
    required this.store,
  });

  Future<void> _navigateToReader(
    BuildContext context,
    String novelId,
    String chapterId,
    String title,
  ) async {
    // 获取阅读历史中的页码
    int? initialPage;
    if (readingHistory != null && readingHistory!.chapterId == chapterId) {
      initialPage = readingHistory!.progressPage;
    }

    print('Navigating to reader with initialPage: $initialPage');

    await Navigator.pushNamed(
      context,
      '/novel/reader',
      arguments: {
        'novelId': novelId,
        'chapterId': chapterId,
        'title': title,
        'volumes': volumes,
        'novelInfo': novelInfo,
        'initialPage': initialPage,
      },
    );
    // 返回后更新历史记录
    store.loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _NovelHeader(novelInfo: novelInfo, onReturn: store.loadHistory),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatItem(
                  icon: Icons.update,
                  label: '更新',
                  value: novelInfo.finUpdate,
                ),
                _StatItem(
                  icon: Icons.comment,
                  label: '评论',
                  value: '',
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      '/novel/reviews',
                      arguments: { 'aid': novelId, 'title': novelInfo.title },
                    );
                  },
                ),
                // _StatItem(
                //   icon: Icons.local_fire_department,
                //   label: '热度',
                //   value: novelInfo.heat,
                // ),
                // _StatItem(
                //   icon: Icons.trending_up,
                //   label: '趋势',
                //   value: novelInfo.trending,
                // ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _NovelTags(tags: novelInfo.tags)),
        // 添加继续阅读按钮
        if (readingHistory != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 24,
                bottom: 16,
                left: 16,
                right: 16,
              ),
              child: ElevatedButton.icon(
                onPressed:
                    () => _navigateToReader(
                      context,
                      readingHistory!.novelId,
                      readingHistory!.chapterId,
                      readingHistory!.novelName,
                    ),
                icon: const Icon(Icons.book),
                label: Text('继续阅读 - ${readingHistory!.chapterTitle}'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: _NovelDescription(description: novelInfo.introduce),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final volume = volumes[index];
            return _VolumeItem(
              volume: volume,
              onChapterTap:
                  (chapter) => _navigateToReader(
                    context,
                    chapter.aid,
                    chapter.cid,
                    chapter.title,
                  ),
            );
          }, childCount: volumes.length),
        ),

        SliverToBoxAdapter(child: SafeArea(top: false, child: Container())),
      ],
    );
  }
}

class _NovelHeader extends StatelessWidget {
  final NovelInfo novelInfo;
  final VoidCallback? onReturn;

  const _NovelHeader({required this.novelInfo, this.onReturn});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CachedImage(
            url: novelInfo.imgUrl,
            width: 120,
            height: 160,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  novelInfo.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    await Navigator.pushNamed(
                      context,
                      '/search',
                      arguments: {
                        'searchType': 'author',
                        'searchKey': novelInfo.author,
                      },
                    );
                    onReturn?.call();
                  },
                  child: Text(
                    '作者：${novelInfo.author}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '状态：${novelInfo.status}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (novelInfo.isAnimated)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '动画化',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        value != ''
            ? Text(
                '$label: $value',
                style: Theme.of(context).textTheme.bodySmall,
              )
            : Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        child: row,
      );
    }
    return row;
  }
}

class _NovelDescription extends StatelessWidget {
  final String description;

  const _NovelDescription({required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('简介', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Html(
            data: description,
            style: {
              'body': Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                fontSize: FontSize(14),
                color: Theme.of(context).colorScheme.onSurface,
              ),
              'p': Style(margin: Margins.only(bottom: 8)),
              'br': Style(margin: Margins.only(bottom: 8)),
            },
          ),
        ],
      ),
    );
  }
}

class _NovelTags extends StatelessWidget {
  final List<String> tags;

  const _NovelTags({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            tags.map((tag) {
              return InkWell(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/category',
                    arguments: {'tag': tag},
                  );
                },
                child: Chip(
                  label: Text(tag),
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _VolumeItem extends StatelessWidget {
  final Volume volume;
  final Function(Chapter) onChapterTap;

  const _VolumeItem({required this.volume, required this.onChapterTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              volume.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          ...volume.chapters.map((chapter) {
            return InkWell(
              onTap: () => onChapterTap(chapter),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        chapter.title,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
