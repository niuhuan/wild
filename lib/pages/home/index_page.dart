import 'package:flutter/material.dart';

import '../../src/rust/api/database.dart';
import '../../src/rust/api/wenku8.dart';
import '../../src/rust/wenku8/models.dart';
import '../../widgets/cached_image.dart';
import 'recommend_page.dart';
import '../search_page.dart';

class IndexPage extends StatefulWidget {
  const IndexPage({super.key});

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('轻小说文库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '推荐'),
            Tab(text: '分类'),
            Tab(text: '排行'),
            Tab(text: '完结'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          RecommendPage(),
          CategoryPage(),
          ToplistPage(),
          ArticlelistPage(),
        ],
      ),
    );
  }
}

class _HomeBlockWidget extends StatelessWidget {
  final HomeBlock block;

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
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
              return _NovelCoverCard(novel: novel);
            },
          ),
        ),
      ],
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

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  List<TagGroup>? _tagGroups;
  String? _selectedTag;
  String _viewMode = "0"; // 默认按更新查看
  PageStatsNovelCover? _currentPage;
  bool _isLoading = false;
  String? _errorMessage;
  static const _keyTag = 'category_page_selected_tag';
  static const _keyViewMode = 'category_page_view_mode';

  @override
  void initState() {
    super.initState();
    _loadSavedState();
    _loadTags();
  }

  Future<void> _loadSavedState() async {
    try {
      final savedTag = await loadProperty(key: _keyTag);
      final savedViewMode = await loadProperty(key: _keyViewMode);
      setState(() {
        if (savedTag.isNotEmpty) {
          _selectedTag = savedTag;
        }
        if (savedViewMode.isNotEmpty) {
          _viewMode = savedViewMode;
        }
      });
      if (_selectedTag != null) {
        _loadTagPage(_selectedTag!, refresh: true);
      }
    } catch (e) {
      // 如果加载失败，使用默认值
    }
  }

  Future<void> _saveState() async {
    try {
      if (_selectedTag != null) {
        await saveProperty(key: _keyTag, value: _selectedTag!);
      }
      await saveProperty(key: _keyViewMode, value: _viewMode);
    } catch (e) {
      // 如果保存失败，继续使用当前状态
    }
  }

  Future<void> _loadTags() async {
    try {
      final tagGroups = await tags();
      setState(() {
        _tagGroups = tagGroups;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadTagPage(String tag, {bool refresh = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      if (refresh) {
        _currentPage = null;
        _errorMessage = null;
      }
    });

    try {
      final page = await tagPage(
        tag: tag,
        v: _viewMode,
        pageNumber: refresh ? 1 : (_currentPage?.currentPage ?? 0) + 1,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载小说列表失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top bar with view mode and category selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // View mode selector
              Expanded(
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: "0", label: Text('更新')),
                    ButtonSegment(value: "1", label: Text('热门')),
                    ButtonSegment(value: "2", label: Text('完结')),
                    ButtonSegment(value: "3", label: Text('动画')),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (Set<String> selection) {
                    _saveState();
                    setState(() {
                      _viewMode = selection.first;
                      if (_selectedTag != null) {
                        _loadTagPage(_selectedTag!, refresh: true);
                      }
                    });
                  },
                ),
              ),
              // Category selector
              if (_tagGroups != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: PopupMenuButton<String>(
                    tooltip: '分类',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedTag ?? '分类',
                            style: TextStyle(
                              color: _selectedTag != null
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              fontWeight: _selectedTag != null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                    itemBuilder: (context) {
                      final items = <PopupMenuEntry<String>>[];
                      for (final group in _tagGroups!) {
                        items.add(
                          PopupMenuItem<String>(
                            enabled: false,
                            child: Text(
                              group.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                        for (final tag in group.tags) {
                          items.add(
                            PopupMenuItem<String>(
                              value: tag,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _selectedTag == tag
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                    fontWeight: _selectedTag == tag
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        if (group != _tagGroups!.last) {
                          items.add(const PopupMenuDivider());
                        }
                      }
                      return items;
                    },
                    onSelected: (tag) async {
                      setState(() {
                        _selectedTag = tag;
                      });
                      _loadTagPage(tag, refresh: true);
                      _saveState();
                    },
                  ),
                ),
            ],
          ),
        ),
        // Novel grid or error state
        Expanded(
          child: _selectedTag == null
              ? const Center(child: Text('请选择分类'))
              : _errorMessage != null
                  ? RefreshIndicator(
                      onRefresh: () => _loadTagPage(_selectedTag!, refresh: true),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height - 100,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
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
                              _loadTagPage(_selectedTag!);
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
                              return _NovelCoverCard(novel: novel);
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

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
        _loadToplist(refresh: true);
      } else {
        _loadToplist(refresh: true);
      }
    } catch (e) {
      // 如果加载失败，使用默认值
      _loadToplist(refresh: true);
    }
  }

  Future<void> _saveState() async {
    try {
      await saveProperty(key: _keySort, value: _selectedSort);
    } catch (e) {
      // 如果保存失败，继续使用当前状态
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
        // Sort selector
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
                      if (selected) {
                        setState(() {
                          _selectedSort = value;
                          _errorMessage = null;
                        });
                        _loadToplist(refresh: true);
                        _saveState();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // Novel grid or error state
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
                            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
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
                          return _NovelCoverCard(novel: novel);
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

class ArticlelistPage extends StatefulWidget {
  const ArticlelistPage({super.key});

  @override
  State<ArticlelistPage> createState() => _ArticlelistPageState();
}

class _ArticlelistPageState extends State<ArticlelistPage> {
  PageStatsNovelCover? _currentPage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadArticlelist(refresh: true);
  }

  Future<void> _loadArticlelist({bool refresh = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      if (refresh) {
        _currentPage = null;
      }
    });

    try {
      final page = await articlelist(
        fullflag: 1,
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
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载完结小说失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _currentPage == null
        ? const Center(child: CircularProgressIndicator())
        : NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification &&
                  notification.metrics.pixels >=
                      notification.metrics.maxScrollExtent - 200 &&
                  !_isLoading &&
                  _currentPage!.currentPage < _currentPage!.maxPage) {
                _loadArticlelist();
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
              itemCount: _currentPage!.records.length +
                  (_currentPage!.currentPage < _currentPage!.maxPage ? 1 : 0),
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
                return _NovelCoverCard(novel: novel);
              },
            ),
          );
  }
}
