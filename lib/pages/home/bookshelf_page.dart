import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/pages/auth_cubit.dart';
import 'package:wild/pages/home/bookshelf_cubit.dart';
import 'package:wild/src/rust/wenku8/models.dart';
import 'package:wild/widgets/cached_image.dart';
import 'package:wild/widgets/novel_card.dart';

class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key});

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> with TickerProviderStateMixin {
  late TabController _tabController;
  BookshelfCubit? _cubit;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange(BuildContext context) {
    if (!_tabController.indexIsChanging) return;
    final state = _cubit?.state;
    if (state?.status == BookshelfStatus.loaded) {
      final bookcase = state!.bookcases[_tabController.index];
      _cubit?.loadBookcaseContent(bookcase.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        _cubit = BookshelfCubit()..loadBookshelf();
        return _cubit!;
      },
      child: BlocBuilder<BookshelfCubit, BookshelfState>(
        builder: (context, state) {
          if (state.status == BookshelfStatus.loaded && 
              state.bookcases.length != _tabController.length) {
            final oldIndex = _tabController.index;
            _tabController.dispose();
            _tabController = TabController(
              length: state.bookcases.length,
              vsync: this,
              initialIndex: oldIndex < state.bookcases.length ? oldIndex : 0,
            );
            
            // 加载当前标签页的内容
            if (state.bookcases.isNotEmpty) {
              final bookcase = state.bookcases[_tabController.index];
              _cubit?.loadBookcaseContent(bookcase.id);
            }
          }

          // 确保在每次构建时都重新设置监听器
          _tabController.removeListener(() => _handleTabChange(context));
          _tabController.addListener(() => _handleTabChange(context));

          return Scaffold(
            appBar: AppBar(
              title: const Text('我的书架'),
              bottom: state.status == BookshelfStatus.loaded
                  ? TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabs: state.bookcases
                          .map((bookcase) => Tab(text: bookcase.title))
                          .toList(),
                    )
                  : null,
            ),
            body: _buildBody(context, state),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, BookshelfState state) {
    switch (state.status) {
      case BookshelfStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case BookshelfStatus.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(state.errorMessage ?? '加载失败'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  context.read<BookshelfCubit>().loadBookshelf();
                },
                child: const Text('重试'),
              ),
            ],
          ),
        );
      case BookshelfStatus.loaded:
        if (state.bookcases.isEmpty) {
          return const Center(child: Text('书架为空'));
        }
        return TabBarView(
          controller: _tabController,
          children: state.bookcases.map((bookcase) {
            final isCurrentCase = state.currentCaseId == bookcase.id;
            final books = isCurrentCase ? state.currentBooks : null;
            
            return RefreshIndicator(
              onRefresh: () async {
                await context.read<BookshelfCubit>().loadBookcaseContent(bookcase.id);
              },
              child: books == null
                  ? const Center(child: CircularProgressIndicator())
                  : books.isEmpty
                      ? const Center(child: Text('书架为空'))
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 207 / 307,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: books.length,
                          itemBuilder: (context, index) {
                            final book = books[index];
                            return _BookCard(item: book);
                          },
                        ),
            );
          }).toList(),
        );
      default:
        return const SizedBox();
    }
  }
}

class _BookcaseSection extends StatelessWidget {
  final String title;
  final List<BookcaseItem> books;

  const _BookcaseSection({
    required this.title,
    required this.books,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (books.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('书架为空')),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2/3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return _BookCard(item: book);
            },
          ),
        const SizedBox(height: 16),
      ],
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