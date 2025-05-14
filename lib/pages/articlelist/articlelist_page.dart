import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubits/articlelist_cubit.dart';
import '../../src/rust/wenku8/models.dart';
import '../../widgets/cached_image.dart';
import 'package:wild/widgets/novel_card.dart';

class ArticlelistPage extends StatefulWidget {
  const ArticlelistPage({super.key});

  @override
  State<ArticlelistPage> createState() => _ArticlelistPageState();
}

class _ArticlelistPageState extends State<ArticlelistPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    context.read<ArticlelistCubit>().loadNovels();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ArticlelistCubit>().loadNovels();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ArticlelistCubit, ArticlelistState>(
      builder: (context, state) {
        if (state is ArticlelistInitial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is ArticlelistError) {
          return Center(child: Text(state.message));
        }

        if (state is ArticlelistLoaded) {
          return RefreshIndicator(
            onRefresh: () async {
              await context.read<ArticlelistCubit>().loadNovels(refresh: true);
            },
            child: GridView.builder(
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
                    child: CircularProgressIndicator(),
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
      },
    );
  }
} 