import 'package:flutter/material.dart';

import '../../src/rust/api/wenku8.dart';
import '../../src/rust/wenku8/models.dart';
import '../../widgets/cached_image.dart';
import 'recommend_page.dart';

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
          Center(child: Text('排行页面')), // TODO: 实现排行页面
          Center(child: Text('完结页面')), // TODO: 实现完结页面
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

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    try {
      final tagGroups = await tags();
      setState(() {
        _tagGroups = tagGroups;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载标签失败: $e')),
        );
      }
    }
  }

  Future<void> _loadTagPage(String tag, {bool refresh = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      if (refresh) {
        _currentPage = null;
      }
    });

    try {
      final page = await tagPage(
        tag: tag,
        v: _viewMode,
        pageNumber: refresh ? 1 : (_currentPage?.currentPage ?? 0) + 1,
      );
      setState(() {
        _currentPage = page;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
        // View mode selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text('查看方式：'),
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: "0", label: Text('更新')),
                    ButtonSegment(value: "1", label: Text('热门')),
                    ButtonSegment(value: "2", label: Text('完结')),
                    ButtonSegment(value: "3", label: Text('动画化')),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (Set<String> selection) {
                    setState(() {
                      _viewMode = selection.first;
                      if (_selectedTag != null) {
                        _loadTagPage(_selectedTag!, refresh: true);
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        // Tag groups and novel list
        Expanded(
          child: Row(
            children: [
              // Tag groups sidebar
              if (_tagGroups != null)
                Container(
                  width: 120,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                  child: ListView.builder(
                    itemCount: _tagGroups!.length,
                    itemBuilder: (context, index) {
                      final group = _tagGroups![index];
                      return ExpansionTile(
                        title: Text(
                          group.title,
                          style: const TextStyle(fontSize: 14),
                        ),
                        children: group.tags.map((tag) {
                          return ListTile(
                            title: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 12,
                                color: _selectedTag == tag
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                            selected: _selectedTag == tag,
                            onTap: () {
                              setState(() {
                                _selectedTag = tag;
                              });
                              _loadTagPage(tag, refresh: true);
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              // Novel grid
              Expanded(
                child: _selectedTag == null
                    ? const Center(child: Text('请选择分类'))
                    : _currentPage == null
                        ? const Center(child: CircularProgressIndicator())
                        : NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification is ScrollEndNotification &&
                                  notification.metrics.pixels >=
                                      notification.metrics.maxScrollExtent - 200 &&
                                  !_isLoading &&
                                  _currentPage!.currentPage <
                                      _currentPage!.maxPage) {
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
          ),
        ),
      ],
    );
  }
}
