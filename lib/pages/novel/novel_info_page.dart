import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/src/rust/api/wenku8.dart';
import 'package:wild/src/rust/frb_generated.dart';
import 'package:wild/widgets/cached_image.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../src/rust/wenku8/models.dart';
import 'novel_info_cubit.dart';

class NovelInfoPage extends StatelessWidget {
  final String novelId;

  const NovelInfoPage({super.key, required this.novelId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NovelInfoCubit(novelId)..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('小说详情')),
        body: BlocBuilder<NovelInfoCubit, NovelInfoState>(
          builder: (context, state) {
            if (state is NovelInfoLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is NovelInfoError) {
              return Center(child: Text('加载失败: ${state.message}'));
            }
            if (state is NovelInfoLoaded) {
              return _NovelInfoContent(
                novelInfo: state.novelInfo,
                volumes: state.volumes,
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _NovelInfoContent extends StatelessWidget {
  final NovelInfo novelInfo;
  final List<Volume> volumes;

  const _NovelInfoContent({required this.novelInfo, required this.volumes});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _NovelHeader(novelInfo: novelInfo)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatItem(
                  icon: Icons.update,
                  label: '更新',
                  value: novelInfo.finUpdate,
                ),
                _StatItem(
                  icon: Icons.local_fire_department,
                  label: '热度',
                  value: novelInfo.heat,
                ),
                _StatItem(
                  icon: Icons.trending_up,
                  label: '趋势',
                  value: novelInfo.trending,
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _NovelTags(tags: novelInfo.tags),
        ),
        SliverToBoxAdapter(
          child: _NovelDescription(description: novelInfo.introduce),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final volume = volumes[index];
            return _VolumeItem(volume: volume);
          }, childCount: volumes.length),
        ),
      ],
    );
  }
}

class _NovelHeader extends StatelessWidget {
  final NovelInfo novelInfo;

  const _NovelHeader({required this.novelInfo});

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
                Text(
                  '作者：${novelInfo.author}',
                  style: Theme.of(context).textTheme.bodyMedium,
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
        Text(
          '$label: $value',
          style: Theme.of(context).textTheme.bodySmall,
        ),
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
              'p': Style(
                margin: Margins.only(bottom: 8),
              ),
              'br': Style(
                margin: Margins.only(bottom: 8),
              ),
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
        children: tags.map((tag) {
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

  const _VolumeItem({required this.volume});

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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const Divider(height: 1),
          ...volume.chapters.map((chapter) {
            return InkWell(
              onTap: () {
                final volumes = context.read<NovelInfoCubit>().volumes;
                if (volumes == null) return;
                Navigator.pushNamed(
                  context,
                  '/novel/reader',
                  arguments: {
                    'novelId': chapter.aid,
                    'chapterId': chapter.cid,
                    'title': chapter.title,
                    'volumes': volumes,
                  },
                );
              },
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
