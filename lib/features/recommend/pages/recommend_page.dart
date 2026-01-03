import 'package:flutter/material.dart';
import 'package:wild/src/rust/wenku8/models.dart' as w8;
import 'package:wild/widgets/novel_card.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:wild/features/recommend/stores/recommend_store.dart';

class RecommendPage extends StatefulWidget {
  const RecommendPage({super.key});

  @override
  State<RecommendPage> createState() => _RecommendPageState();
}

class _RecommendPageState extends State<RecommendPage> {
  late final RecommendStore _store;

  @override
  void initState() {
    super.initState();
    _store = RecommendStore()..load();
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final state = _store.signal.watch(context);
        if (state is RecommendLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is RecommendError) {
          return RefreshIndicator(
            onRefresh: () => _store.load(),
            child: ListView(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height - 100,
                  child: Center(
                    child: Text('加载失败 (下拉刷新): ${state.message}'),
                  ),
                ),
              ],
            ),
          );
        }

        if (state is RecommendLoaded) {
          return RefreshIndicator(
            onRefresh: () => _store.load(),
            child: ListView.builder(
              itemCount: state.blocks.length,
              itemBuilder: (context, index) {
                final block = state.blocks[index];
                return _HomeBlockWidget(block: block);
              },
            ),
          );
        }

        return const SizedBox.shrink();
    });
  }
}

class _HomeBlockWidget extends StatelessWidget {
  final w8.HomeBlock block;

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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
              return NovelCard.fromNovelCover(
                novel: novel,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/novel/info',
                    arguments: novel.aid,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
} 
