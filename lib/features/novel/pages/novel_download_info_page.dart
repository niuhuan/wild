import 'package:flutter/material.dart';
import 'package:wild/src/rust/api/wenku8.dart';
import 'package:wild/widgets/cached_image.dart';
import 'package:wild/features/novel/stores/novel_download_info_store.dart';
import 'package:wild/features/novel/pages/reader_page.dart';
import 'package:wild/src/rust/wenku8/models.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:signals_flutter/signals_flutter.dart';

class NovelDownloadInfoPage extends StatefulWidget {
  final String novelId;

  const NovelDownloadInfoPage({super.key, required this.novelId});

  @override
  State<NovelDownloadInfoPage> createState() => _NovelDownloadInfoPageState();
}

class _NovelDownloadInfoPageState extends State<NovelDownloadInfoPage> {
  late final NovelDownloadInfoStore _store;

  @override
  void initState() {
    super.initState();
    _store = NovelDownloadInfoStore(widget.novelId)..load();
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final state = _store.signal.watch(context);
      return Scaffold(
        appBar: AppBar(
          title: const Text('下载详情'),
          actions: [
            if (state is NovelDownloadInfoLoaded)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('确认删除'),
                      content: const Text('确定要删除这本小说的下载内容吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await _store.deleteDownload();
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  }
                },
              ),
          ],
        ),
        body: switch (state) {
          NovelDownloadInfoLoading() =>
            const Center(child: CircularProgressIndicator()),
          NovelDownloadInfoError() => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text((state as NovelDownloadInfoError).message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _store.load();
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          NovelDownloadInfoLoaded() => _NovelDownloadInfoContent(
              download: (state as NovelDownloadInfoLoaded).download.novelDownload,
              volumes: (state as NovelDownloadInfoLoaded).volumes,
              readingHistory: (state as NovelDownloadInfoLoaded).readingHistory,
              store: _store,
            ),
          _ => const SizedBox.shrink(),
        },
      );
    });
  }
}

class _NovelDownloadInfoContent extends StatelessWidget {
  final NovelDownload download;
  final List<Volume> volumes;
  final ReadingHistory? readingHistory;
  final NovelDownloadInfoStore store;

  const _NovelDownloadInfoContent({
    required this.download,
    required this.volumes,
    this.readingHistory,
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

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ReaderPage(
              aid: novelId,
              cid: chapterId,
              initialTitle: title,
              volumes: volumes,
              novelInfo: NovelInfo(
                title: download.novelName,
                author: download.author,
                status: download.status,
                imgUrl: download.coverUrl,
                introduce: download.introduce,
                finUpdate: download.finUpdate,
                isAnimated: download.isAnimated,
                tags: download.tags.split(','),
                trending: download.trending,
                heat: '',
              ),
              initialPage: initialPage,
            ),
      ),
    );
    // 返回后更新历史记录
    store.loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _NovelHeader(download: download)),
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
                  value: download.finUpdate,
                ),
                _StatItem(
                  icon: Icons.local_fire_department,
                  label: '热度',
                  value: download.trending,
                ),
                _StatItem(
                  icon: Icons.download,
                  label: '下载进度',
                  value:
                      '${download.downloadChapterCount}/${download.chooseChapterCount}',
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _NovelTags(tags: download.tags.split(','))),
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
          child: _NovelDescription(description: download.introduce),
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
      ],
    );
  }
}

class _NovelHeader extends StatelessWidget {
  final NovelDownload download;

  const _NovelHeader({required this.download});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedImage(
              url: download.coverUrl,
              width: 120,
              height: 160,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  download.novelName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '作者：${download.author}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '状态：${download.status}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (download.isAnimated)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '动画化',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                _buildDownloadStatus(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadStatus(BuildContext context) {
    final statusColor = _getStatusColor(download.downloadStatus);
    final statusText = _getStatusText(download.downloadStatus);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        statusText,
        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0: // DOWNLOAD_STATUS_NOT_DOWNLOAD
        return Colors.blue;
      case 1: // DOWNLOAD_STATUS_SUCCESS
        return Colors.green;
      case 2: // DOWNLOAD_STATUS_FAILED
        return Colors.red;
      case 3: // DOWNLOAD_STATUS_DELETING
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(int status) {
    switch (status) {
      case 0: // DOWNLOAD_STATUS_NOT_DOWNLOAD
        return '等待下载';
      case 1: // DOWNLOAD_STATUS_SUCCESS
        return '下载完成';
      case 2: // DOWNLOAD_STATUS_FAILED
        return '下载失败';
      case 3: // DOWNLOAD_STATUS_DELETING
        return '正在删除';
      default:
        return '未知状态';
    }
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Text('$label: $value', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
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
              return Chip(
                label: Text(tag),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
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
