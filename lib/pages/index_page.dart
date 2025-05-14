import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/category_cubit.dart';
import '../cubits/toplist_cubit.dart';
import '../cubits/articlelist_cubit.dart';
import 'category/category_page.dart';
import 'toplist/toplist_page.dart';
import 'articlelist/articlelist_page.dart';
import 'recommend/recommend_page.dart';

class IndexPage extends StatelessWidget {
  const IndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => CategoryCubit()),
        BlocProvider(create: (context) => ToplistCubit()),
        BlocProvider(create: (context) => ArticlelistCubit()),
      ],
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('轻小说文库'),
            bottom: const TabBar(
              tabs: [
                Tab(text: '推荐'),
                Tab(text: '分类'),
                Tab(text: '排行'),
                Tab(text: '完结'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              const RecommendPage(),
              const CategoryPage(),
              const ToplistPage(),
              const ArticlelistPage(),
            ],
          ),
        ),
      ),
    );
  }
} 