import 'package:flutter/material.dart';
import 'package:wild/src/rust/api/wenku8.dart';
import 'package:wild/src/rust/wenku8/models.dart';
import 'package:wild/widgets/cached_image.dart';

class SearchPage extends StatefulWidget {
  final String? initialSearchType;
  final String? initialSearchKey;

  const SearchPage({
    super.key,
    this.initialSearchType,
    this.initialSearchKey,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  late String _searchType;
  PageStatsNovelCover? _searchResults;
  bool _isLoading = false;
  List<SearchHistory>? _searchHistories;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchType = widget.initialSearchType ?? 'articlename';
    if (widget.initialSearchKey != null) {
      _searchController.text = widget.initialSearchKey!;
      _search(refresh: true);
    }
    _loadSearchHistories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistories() async {
    try {
      final histories = await searchHistories();
      setState(() {
        _searchHistories = histories;
      });
    } catch (e) {
      // 忽略加载历史记录失败
    }
  }

  Future<void> _search({bool refresh = false}) async {
    if (_searchController.text.isEmpty) {
      setState(() {
        _errorMessage = null;
        _searchResults = null;
      });
      return;
    }
    if (_isLoading) return;

    print('开始搜索: type=${_searchType}, key=${_searchController.text}, refresh=$refresh');

    setState(() {
      _isLoading = true;
      if (refresh) {
        _searchResults = null;
        _errorMessage = null;
      }
    });

    try {
      final results = await search(
        searchType: _searchType,
        searchKey: _searchController.text,
        page: refresh ? 1 : (_searchResults?.currentPage ?? 0) + 1,
      );

      print('搜索成功: 找到 ${results.records.length} 条结果');

      if (!mounted) return;

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
        _errorMessage = null;
      });

      // 刷新搜索历史
      _loadSearchHistories();
    } catch (e) {
      print('搜索失败: $e');
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
        _searchResults = null;  // 确保清除搜索结果
      });
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
                _searchController.clear();
                _searchResults = null;
                _errorMessage = null;
              });
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
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜索小说或作者',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _search(refresh: true);
                }
              },
            ),
          ),
          // 搜索结果或搜索历史
          if (_searchController.text.isEmpty && _searchHistories != null && _searchHistories!.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _searchHistories!.length,
                itemBuilder: (context, index) {
                  final history = _searchHistories![index];
                  return ListTile(
                    leading: Icon(
                      history.searchType == 'articlename'
                          ? Icons.book
                          : Icons.person,
                      color: history.searchType == 'articlename'
                          ? Colors.blue
                          : Colors.green,
                    ),
                    title: Text(
                      history.searchKey,
                      style: TextStyle(
                        color: history.searchType == 'articlename'
                            ? Colors.blue
                            : Colors.green,
                      ),
                    ),
                    subtitle: Text(
                      history.searchType == 'articlename' ? '书名搜索' : '作者搜索',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      _searchController.text = history.searchKey;
                      setState(() {
                        _searchType = history.searchType;
                      });
                      _search(refresh: true);
                    },
                  );
                },
              ),
            )
          // 错误状态
          else if (_errorMessage != null)
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _search(refresh: true),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height - 100,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              '搜索失败 (下拉刷新)',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.start,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          // 搜索结果
          else if (_searchResults != null)
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
