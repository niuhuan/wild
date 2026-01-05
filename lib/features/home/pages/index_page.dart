import 'package:flutter/material.dart';
import 'package:wild/features/articlelist/pages/articlelist_page.dart';
import 'package:wild/features/category/pages/category_page.dart';
import 'package:wild/features/recommend/pages/recommend_page.dart';
import 'package:wild/features/search/pages/search_page.dart';
import 'package:wild/features/toplist/pages/toplist_page.dart';

class IndexPage extends StatefulWidget {
  const IndexPage({super.key});

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage>
    with SingleTickerProviderStateMixin {
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

