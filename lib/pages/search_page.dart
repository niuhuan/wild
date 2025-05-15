import 'package:flutter/material.dart';
import '../src/rust/api/wenku8.dart';
import '../src/rust/wenku8/models.dart';
import '../widgets/cached_image.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  String _searchType = 'articlename';
  PageStatsNovelCover? _searchResults;
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search({bool refresh = false}) async {
    if (_searchController.text.isEmpty) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _searchResults = null;
      }
    });

    try {
      final results = await search(
        searchType: _searchType,
        searchKey: _searchController.text,
        page: refresh ? 1 : (_searchResults?.currentPage ?? 0) + 1,
      );

      setState(() {
        if (refresh) {
          _searchResults = results;
        } else {
          _searchResults = PageStatsNovelCover(
            currentPage: results.currentPage,
            maxPage: results.maxPage,
            records: [..._searchResults!.records, ...results.records],
          );
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
        actions: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'articlename', label: Text('书名')),
              ButtonSegment(value: 'author', label: Text('作者')),
            ],
            selected: {_searchType},
            onSelectionChanged: (Set<String> selection) {
              setState(() {
                _searchType = selection.first;
              });
              if (_searchController.text.isNotEmpty) {
                _search(refresh: true);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索小说或作者',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (_) => _search(refresh: true),
            ),
          ),
          // 搜索结果
          if (_searchResults != null)
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollEndNotification &&
                      notification.metrics.pixels >=
                          notification.metrics.maxScrollExtent - 200 &&
                      !_isLoading &&
                      _searchResults!.currentPage < _searchResults!.maxPage) {
                    _search();
                  }
                  return true;
                },
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 207 / 307,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _searchResults!.records.length +
                      (_searchResults!.currentPage < _searchResults!.maxPage
                          ? 1
                          : 0),
                  itemBuilder: (context, index) {
                    if (index >= _searchResults!.records.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final novel = _searchResults!.records[index];
                    return _NovelCoverCard(novel: novel);
                  },
                ),
              ),
            )
          // 空状态
          else
            const Expanded(
              child: Center(
                child: Text('输入关键词开始搜索'),
              ),
            ),
        ],
      ),
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
            child: CachedImage(
              url: novel.img,
              fit: BoxFit.cover,
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