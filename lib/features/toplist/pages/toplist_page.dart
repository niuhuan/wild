import 'package:flutter/material.dart';
import 'package:wild/src/rust/api/database.dart';
import 'package:wild/src/rust/api/wenku8.dart';
import 'package:wild/src/rust/wenku8/models.dart';
import 'package:wild/widgets/novel_cover_card.dart';

class ToplistPage extends StatefulWidget {
  const ToplistPage({super.key});

  @override
  State<ToplistPage> createState() => _ToplistPageState();
}

class _ToplistPageState extends State<ToplistPage> {
  static const _sortOptions = [
    ('更新', 'lastupdate'),
    ('发布', 'postdate'),
    ('总访问', 'allvisit'),
    ('总推荐', 'allvote'),
    ('总收藏', 'goodnum'),
    ('日访问', 'dayvisit'),
    ('日推荐', 'dayvote'),
    ('月访问', 'monthvisit'),
    ('月推荐', 'monthvote'),
    ('周访问', 'weekvisit'),
    ('周推荐', 'weekvote'),
    ('字数', 'size'),
    ('动画', 'anime'),
  ];

  String _selectedSort = 'lastupdate';
  PageStatsNovelCover? _currentPage;
  bool _isLoading = false;
  String? _errorMessage;
  static const _keySort = 'toplist_page_sort';

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    try {
      final savedSort = await loadProperty(key: _keySort);
      if (savedSort.isNotEmpty) {
        setState(() {
          _selectedSort = savedSort;
        });
      }
    } catch (e) {
      // ignore
    } finally {
      _loadToplist(refresh: true);
    }
  }

  Future<void> _saveState() async {
    try {
      await saveProperty(key: _keySort, value: _selectedSort);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadToplist({bool refresh = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      if (refresh) {
        _currentPage = null;
        _errorMessage = null;
      }
    });

    try {
      final page = await toplist(
        sort: _selectedSort,
        page: refresh ? 1 : (_currentPage?.currentPage ?? 0) + 1,
      );
      setState(() {
        if (refresh) {
          _currentPage = page;
        } else {
          _currentPage = PageStatsNovelCover(
            currentPage: page.currentPage,
            maxPage: page.maxPage,
            records: [..._currentPage!.records, ...page.records],
          );
        }
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _sortOptions.map((option) {
                final (label, value) = option;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label),
                    selected: _selectedSort == value,
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() {
                        _selectedSort = value;
                        _errorMessage = null;
                      });
                      _loadToplist(refresh: true);
                      _saveState();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: _errorMessage != null
              ? RefreshIndicator(
                  onRefresh: () => _loadToplist(refresh: true),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height - 100,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '加载失败 (下拉刷新)',
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
                    ],
                  ),
                )
              : _currentPage == null
                  ? const Center(child: CircularProgressIndicator())
                  : NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollEndNotification &&
                            notification.metrics.pixels >=
                                notification.metrics.maxScrollExtent - 200 &&
                            !_isLoading &&
                            _currentPage!.currentPage < _currentPage!.maxPage) {
                          _loadToplist();
                        }
                        return true;
                      },
                      child: GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 207 / 307,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _currentPage!.records.length +
                            (_currentPage!.currentPage < _currentPage!.maxPage
                                ? 1
                                : 0),
                        itemBuilder: (context, index) {
                          if (index >= _currentPage!.records.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          final novel = _currentPage!.records[index] as NovelCover;
                          return NovelCoverCard(novel: novel);
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

