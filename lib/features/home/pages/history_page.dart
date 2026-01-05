import 'package:flutter/material.dart';
import 'package:wild/src/rust/api/wenku8.dart' as w8;
import 'package:wild/widgets/cached_image.dart';
import 'package:intl/intl.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:wild/features/home/stores/history_store.dart';

class HistoryPage extends StatelessWidget {
  final HistoryStore history;

  const HistoryPage({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('阅读历史'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('清空历史'),
                      content: const Text('确定要清空所有阅读历史吗？此操作不可恢复。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('确定'),
                        ),
                      ],
                    ),
              );
              if (confirm == true) {
                await w8.deleteAllHistory();
                // 重新加载历史
                history.load();
              }
            },
          ),
        ],
      ),
      body: Watch((context) {
        final state = history.signal.watch(context);
          if (state is HistoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is HistoryError) {
            return Center(child: Text('加载失败: ${state.message}'));
          }
          if (state is HistoryLoaded) {
            if (state.histories.isEmpty) {
              return const Center(child: Text('暂无阅读历史'));
            }
            return RefreshIndicator(
              onRefresh: () => history.load(),
              child: ListView.builder(
                itemCount: state.histories.length,
                itemBuilder: (context, index) {
                  final history = state.histories[index];
                  return _HistoryItem(history: history, historyCubit: this.history);
                },
              ),
            );
          }
          return const SizedBox.shrink();
      }),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final w8.ReadingHistory history;
  final HistoryStore historyCubit;

  const _HistoryItem({required this.history, required this.historyCubit});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    int _asMsInt(Object? v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is BigInt) return v.toInt();     // 轉成 int 給 DateTime 用
      if (v is String) return int.parse(v);  // 以防是字串
      throw ArgumentError('Unsupported type for timestamp: ${v.runtimeType}');
    }

    final lastReadAt = DateTime.fromMillisecondsSinceEpoch(_asMsInt(history.lastReadAt));
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () async {
          await Navigator.pushNamed(
            context,
            '/novel/info',
            arguments: history.novelId,
          );
          if (context.mounted) {
            historyCubit.load();
          }
        },
        onLongPress: () {
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('删除历史记录'),
              content: Text('确定要删除《${history.novelName}》的阅读历史吗？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    try {
                      await historyCubit.deleteHistory(history.novelId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已删除阅读历史'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (e) {
                      print("$e");
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('删除失败: $e'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CachedImage(
                url: history.cover,
                width: 80,
                height: 120,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      history.novelName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '作者：${history.author}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '最后阅读：${dateFormat.format(lastReadAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        try {
                          // 获取小说信息和章节信息
                          final novelInfo = await w8.novelInfo(aid: history.novelId);
                          final volumes = await w8.novelReader(aid: history.novelId);
                          
                          if (!context.mounted) return;
                          
                          await Navigator.pushNamed(
                            context,
                            '/novel/reader',
                            arguments: {
                              'novelId': history.novelId,
                              'chapterId': history.chapterId,
                              'title': history.chapterTitle,
                              'volumes': volumes,
                              'novelInfo': novelInfo,
                              'initialPage': history.progressPage,
                            },
                          );
                          // 返回后更新历史记录
                          if (context.mounted) {
                            historyCubit.load();
                          }
                        } catch (e) {
                          if (!context.mounted) return;
                          // 显示错误提示
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('加载失败: $e'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.only(bottom: 16),
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: RichText(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Icon(
                                  Icons.book,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const TextSpan(text: ' '),
                              TextSpan(
                                text: '继续阅读 - ${history.chapterTitle}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: colorScheme.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
