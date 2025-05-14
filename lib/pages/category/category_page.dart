import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/cubits/category_cubit.dart';
import 'package:wild/widgets/novel_card.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final _scrollController = ScrollController();
  bool _isSidebarExpanded = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    context.read<CategoryCubit>().loadTags();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<CategoryCubit>().loadNovels();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CategoryCubit, CategoryState>(
      builder: (context, state) {
        if (state is CategoryInitial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is CategoryError) {
          return Center(child: Text(state.message));
        }

        if (state is CategoryLoaded) {
          return Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isSidebarExpanded ? 200 : 50,
                child: Card(
                  margin: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      ListTile(
                        leading: IconButton(
                          icon: Icon(
                            _isSidebarExpanded
                                ? Icons.chevron_left
                                : Icons.chevron_right,
                          ),
                          onPressed: () {
                            setState(() {
                              _isSidebarExpanded = !_isSidebarExpanded;
                            });
                          },
                        ),
                        title: _isSidebarExpanded
                            ? const Text('标签')
                            : null,
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: state.tagGroups.length,
                          itemBuilder: (context, groupIndex) {
                            final group = state.tagGroups[groupIndex];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_isSidebarExpanded)
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      group.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                  ),
                                ...group.tags.map((tag) {
                                  final isSelected =
                                      state.selectedTag == tag;
                                  return ListTile(
                                    selected: isSelected,
                                    title: _isSidebarExpanded
                                        ? Text(tag)
                                        : null,
                                    leading: _isSidebarExpanded
                                        ? null
                                        : Text(tag[0]),
                                    onTap: () {
                                      context
                                          .read<CategoryCubit>()
                                          .selectTag(tag);
                                    },
                                  );
                                }).toList(),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: state.novels.isEmpty
                    ? const Center(child: Text('请选择一个标签'))
                    : RefreshIndicator(
                        onRefresh: () async {
                          await context
                              .read<CategoryCubit>()
                              .loadNovels(refresh: true);
                        },
                        child: GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: state.novels.length +
                              (state.hasMore ? 1 : 0),
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
                      ),
              ),
            ],
          );
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }
} 