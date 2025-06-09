import 'package:flutter/material.dart';
import 'package:wild/src/rust/api/database.dart';
import 'package:wild/src/rust/api/wenku8.dart';
import 'package:wild/src/rust/wenku8/models.dart';
import 'package:wild/widgets/novel_cover_card.dart';

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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedTag ?? '分类',
                            style: TextStyle(
                              color:
                                  _selectedTag != null
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                              fontWeight:
                                  _selectedTag != null
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
                                    color:
                                        _selectedTag == tag
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                            : null,
                                    fontWeight:
                                        _selectedTag == tag
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
                )
              else if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                      _loadTags();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试加载分类'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
        // Novel grid or error state
        Expanded(
          child:
              _selectedTag == null
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
                      itemCount:
                          _currentPage!.records.length +
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
                        final novel =
                            _currentPage!.records[index] as NovelCover;
                        return NovelCoverCard(novel: novel);
                      },
                    ),
                  ),
        ),
      ],
    );
  }
}
