import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/src/rust/api/wenku8.dart' as w8;
import 'package:wild/widgets/cached_image.dart';
import 'package:intl/intl.dart';

import 'history_cubit.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

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
                if (context.mounted) {
                  context.read<HistoryCubit>().load();
                }
              }
            },
          ),
        ],
      ),
      body: BlocBuilder<HistoryCubit, HistoryState>(
        builder: (context, state) {
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
              onRefresh: () => context.read<HistoryCubit>().load(),
              child: ListView.builder(
                itemCount: state.histories.length,
                itemBuilder: (context, index) {
                  final history = state.histories[index];
                  return _HistoryItem(history: history);
                },
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final w8.ReadingHistory history;

  const _HistoryItem({required this.history});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final lastReadAt = DateTime.fromMillisecondsSinceEpoch(history.lastReadAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/novel/info',
            arguments: history.novelId,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
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
              const SizedBox(width: 16),
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
                      '最近阅读：${history.chapterTitle}',
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // const SizedBox(height: 4),
                    // Text(
                    //   '阅读进度：${history.progress}%',
                    //   style: Theme.of(context).textTheme.bodyMedium,
                    // ),
                    const SizedBox(height: 4),
                    Text(
                      '最后阅读：${dateFormat.format(lastReadAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/novel/info',
                    arguments: {
                      'novelId': history.novelId,
                      'chapterId': history.chapterId,
                      'title': history.chapterTitle,
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
