import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubits/toplist_cubit.dart';
import '../../src/rust/wenku8/models.dart';
import '../../widgets/cached_image.dart';
import 'package:wild/widgets/novel_card.dart';

class ToplistPage extends StatefulWidget {
  const ToplistPage({super.key});

  @override
  State<ToplistPage> createState() => _ToplistPageState();
}

class _ToplistPageState extends State<ToplistPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    context.read<ToplistCubit>().loadNovels();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ToplistCubit>().loadNovels();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ToplistCubit, ToplistState>(
      builder: (context, state) {
        if (state is ToplistError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(state.message),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.read<ToplistCubit>().loadNovels(refresh: true),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        if (state is ToplistLoaded) {
          return RefreshIndicator(
            onRefresh: () => context.read<ToplistCubit>().loadNovels(refresh: true),
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
      },
    );
  }
} 