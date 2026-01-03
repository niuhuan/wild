import 'package:flutter/material.dart';
import 'package:wild/widgets/novel_card.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:wild/features/articlelist/stores/articlelist_store.dart';

class ArticlelistPage extends StatefulWidget {
  const ArticlelistPage({super.key});

  @override
  State<ArticlelistPage> createState() => _ArticlelistPageState();
}

class _ArticlelistPageState extends State<ArticlelistPage> {
  final _scrollController = ScrollController();
  late final ArticlelistStore _store;

  @override
  void initState() {
    super.initState();
    _store = ArticlelistStore();
    _scrollController.addListener(_onScroll);
    _store.loadNovels();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _store.loadNovels();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final state = _store.signal.watch(context);
        if (state is ArticlelistError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(state.message),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _store.loadNovels(refresh: true),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        if (state is ArticlelistLoaded) {
          return RefreshIndicator(
            onRefresh: () => _store.loadNovels(refresh: true),
            child: state.novels.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: state.novels.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.novels.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final novel = state.novels[index];
                      return NovelCard.fromNovel(
                        novel: novel,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/novel/info',
                            arguments: novel.id,
                          );
                        },
                      );
                    },
                  ),
          );
        }

        return const Center(child: CircularProgressIndicator());
    });
  }
} 
