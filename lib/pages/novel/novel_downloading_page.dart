import 'package:flutter/material.dart';
import 'package:wild/src/rust/api/wenku8.dart' as w8;
import 'package:wild/src/rust/wenku8/models.dart';
import 'package:wild/widgets/cached_image.dart';

class NovelDownloadingPage extends StatefulWidget {
  final String novelId;
  final w8.ExistsDownload? existsDownload;
  final NovelInfo novelInfo;
  final List<Volume> volumes;

  const NovelDownloadingPage({
    super.key,
    required this.novelId,
    required this.existsDownload,
    required this.novelInfo,
    required this.volumes,
  });

  @override
  State<NovelDownloadingPage> createState() => _NovelDownloadingPageState();
}

class _NovelDownloadingPageState extends State<NovelDownloadingPage> {
  final Set<String> _selectedChapters = {};
  bool _isSelectingAll = false;

  @override
  void initState() {
    super.initState();
    // 如果有已下载的章节，初始化选中状态
    if (widget.existsDownload != null) {
      for (final chapter in widget.existsDownload!.novelDownloadChapter) {
        if (chapter.downloadStatus == 0) { // DOWNLOAD_STATUS_NOT_DOWNLOAD
          _selectedChapters.add(chapter.id);
        }
      }
    }
  }

  void _toggleChapterSelection(String chapterId) {
    setState(() {
      if (_selectedChapters.contains(chapterId)) {
        _selectedChapters.remove(chapterId);
      } else {
        _selectedChapters.add(chapterId);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_isSelectingAll) {
        _selectedChapters.clear();
      } else {
        _selectedChapters.clear();
        for (final volume in widget.volumes) {
          for (final chapter in volume.chapters) {
            // 只选择未下载的章节
            if (widget.existsDownload == null ||
                !widget.existsDownload!.novelDownloadChapter
                    .any((c) => c.id == chapter.cid && c.downloadStatus != 0)) { // DOWNLOAD_STATUS_NOT_DOWNLOAD
              _selectedChapters.add(chapter.cid);
            }
          }
        }
      }
      _isSelectingAll = !_isSelectingAll;
    });
  }

  Future<void> _startDownload() async {
    if (_selectedChapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择要下载的章节')),
      );
      return;
    }

    try {
      await w8.downloadNovel(
        aid: widget.novelId,
        cidList: _selectedChapters.toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('开始下载')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择下载章节'),
        actions: [
          IconButton(
            icon: Icon(_isSelectingAll ? Icons.check_box : Icons.check_box_outline_blank),
            onPressed: _toggleSelectAll,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _startDownload,
          ),
        ],
      ),
      body: Column(
        children: [
          // 小说信息卡片
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CachedImage(
                    url: widget.novelInfo.imgUrl,
                    width: 80,
                    height: 120,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.novelInfo.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '作者：${widget.novelInfo.author}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '状态：${widget.novelInfo.status}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (widget.existsDownload != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '已下载：${widget.existsDownload!.novelDownload.downloadChapterCount}/${widget.existsDownload!.novelDownload.chooseChapterCount}章',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 章节列表
          Expanded(
            child: ListView.builder(
              itemCount: widget.volumes.length,
              itemBuilder: (context, volumeIndex) {
                final volume = widget.volumes[volumeIndex];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          volume.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ...volume.chapters.map((chapter) {
                        final isDownloaded = widget.existsDownload?.novelDownloadChapter
                            .any((c) => c.id == chapter.cid && c.downloadStatus != 0) ?? false; // DOWNLOAD_STATUS_NOT_DOWNLOAD
                        final isSelected = _selectedChapters.contains(chapter.cid);

                        return ListTile(
                          title: Text(chapter.title),
                          trailing: isDownloaded
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : Checkbox(
                                  value: isSelected,
                                  onChanged: isDownloaded ? null : (_) => _toggleChapterSelection(chapter.cid),
                                ),
                          onTap: isDownloaded ? null : () => _toggleChapterSelection(chapter.cid),
                        );
                      }).toList(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 