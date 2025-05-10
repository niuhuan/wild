import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/pages/home/index_cubit.dart';
import 'package:wild/src/rust/wenku8/models.dart';
import 'package:wild/src/rust/api/wenku8.dart';

class IndexPage extends StatelessWidget {
  const IndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => IndexCubit()..loadIndex(),
      child: Scaffold(
        appBar: AppBar(title: const Text('首页')),
        body: BlocBuilder<IndexCubit, IndexState>(
          builder: (context, state) {
            switch (state.status) {
              case IndexStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case IndexStatus.error:
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(state.errorMessage ?? '加载失败'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          context.read<IndexCubit>().loadIndex();
                        },
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                );
              case IndexStatus.loaded:
                final blocks = state.blocks;
                if (blocks == null || blocks.isEmpty) {
                  return const Center(child: Text('暂无数据'));
                }
                return RefreshIndicator(
                  onRefresh: () => context.read<IndexCubit>().loadIndex(),
                  child: ListView.builder(
                    itemCount: blocks.length,
                    itemBuilder: (context, index) {
                      final block = blocks[index];
                      return _HomeBlockWidget(block: block);
                    },
                  ),
                );
              default:
                return const SizedBox();
            }
          },
        ),
      ),
    );
  }
}

class _HomeBlockWidget extends StatelessWidget {
  final HomeBlock block;

  const _HomeBlockWidget({required this.block});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            block.title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 207 / 307,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: block.list.length,
            itemBuilder: (context, index) {
              final novel = block.list[index];
              return _NovelCoverCard(novel: novel);
            },
          ),
        ),
      ],
    );
  }
}

class _NovelCoverCard extends StatelessWidget {
  final NovelCover novel;

  const _NovelCoverCard({required this.novel});

  @override
  Widget build(BuildContext context) {
    var card = Card(
      clipBehavior: Clip.antiAlias,
      elevation: .5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FutureBuilder<List<int>>(
              future: downloadImage(url: novel.img),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image),
                  );
                }
                return Image.memory(
                  Uint8List.fromList(snapshot.data!),
                  fit: BoxFit.cover,
                  width: double.infinity,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              novel.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/novel/info', arguments: novel.aid);
      },
      child: card,
    );
  }
}
