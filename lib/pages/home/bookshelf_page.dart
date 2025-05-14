import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/pages/home/bookshelf_cubit.dart';
import 'package:wild/widgets/novel_card.dart';
import 'package:wild/src/rust/wenku8/models.dart';

class BookshelfPage extends StatelessWidget {
  const BookshelfPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookshelfCubit, BookshelfState>(
      builder: (context, state) {
        if (state.status == BookshelfStatus.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.status == BookshelfStatus.error) {
          return Scaffold(
            body: Center(child: Text('加载失败: ${state.errorMessage}')),
          );
        }

        if (state.bookcases.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('暂无书架')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('我的书架'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: state.bookcases.map((bookcase) {
                    final isSelected = bookcase.id == state.currentCaseId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(bookcase.title),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            context.read<BookshelfCubit>().selectBookcase(bookcase.id);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          body: state.getCurrentBooks()?.isEmpty ?? true
              ? const Center(child: Text('书架为空'))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: state.getCurrentBooks()?.length ?? 0,
                  itemBuilder: (context, index) {
                    final item = state.getCurrentBooks()![index];
                    return _BookCard(item: item);
                  },
                ),
        );
      },
    );
  }
}

class _BookCard extends StatelessWidget {
  final BookcaseItem item;

  const _BookCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return NovelCard(
      title: item.title,
      coverUrl: _getCoverUrl(item.aid),
      onTap: () {
        Navigator.pushNamed(
          context,
          '/novel/info',
          arguments: item.aid,
        );
      },
      padding: const EdgeInsets.all(8.0),
      showAuthor: false,
    );
  }

  String _getCoverUrl(String aid) {
    try {
      final id = int.parse(aid);
      return 'https://img.wenku8.com/image/${id ~/ 1000}/$aid/${aid}s.jpg';
    } catch (e) {
      return 'https://img.wenku8.com/image/0/0/0s.jpg';
    }
  }
} 