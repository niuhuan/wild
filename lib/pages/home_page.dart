import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/pages/home/more_page.dart';
import 'package:wild/pages/home/index_page.dart';
import 'package:wild/pages/home/history_cubit.dart';
import 'package:wild/pages/home/bookshelf_cubit.dart';
import 'package:wild/pages/update_cubit.dart';
import 'package:wild/src/rust/api/wenku8.dart';

import 'home/bookshelf_page.dart';
import 'home/history_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late final HistoryCubit _historyCubit;

  @override
  void initState() {
    super.initState();
    _historyCubit = HistoryCubit()..load();
    // 加载书架数据
    context.read<BookshelfCubit>().loadBookcases();
    // 自动签到
    _autoSign();
  }

  Future<void> _autoSign() async {
    try {
      final signed = await autoSign();
      if (signed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('今日已自动签到'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('签到失败: $e'),
        //     duration: const Duration(seconds: 2),
        //   ),
        // );
      }
    }
  }

  @override
  void dispose() {
    _historyCubit.close();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      // 切换到历史页面时刷新数据
      if (index == 2) {
        _historyCubit.load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _historyCubit,
      child: BlocBuilder<UpdateCubit, UpdateState>(
        builder: (context, state) {
          return Scaffold(
            body: IndexedStack(
              index: _currentIndex,
              children: const [
                IndexPage(),
                BookshelfPage(),
                HistoryPage(),
                MorePage(),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onDestinationSelected,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: '首页',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.book_outlined),
                  selectedIcon: Icon(Icons.book),
                  label: '书架',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: '历史',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: state.updateInfo != null,
                    label: const Text('新'),
                    child: const Icon(Icons.more_horiz_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: state.updateInfo != null,
                    label: const Text('新'),
                    child: const Icon(Icons.more_horiz),
                  ),
                  label: '更多',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} 