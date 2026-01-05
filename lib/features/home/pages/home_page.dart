import 'package:flutter/material.dart';
import 'package:wild/features/home/pages/more_page.dart';
import 'package:wild/features/home/pages/index_page.dart';
import 'package:wild/features/home/stores/history_store.dart';
import 'package:wild/src/rust/api/wenku8.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:wild/state/app_state.dart' as app;

import 'package:wild/features/home/pages/bookshelf_page.dart';
import 'package:wild/features/home/pages/history_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late final HistoryStore _historyStore;

  @override
  void initState() {
    super.initState();
    _historyStore = HistoryStore()..load();
    // 加载书架数据
    app.bookshelf.loadBookcases();
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
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      // 切换到历史页面时刷新数据
      if (index == 2) {
        _historyStore.load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final state = app.update.signal.watch(context);
      return Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            const IndexPage(),
            const BookshelfPage(),
            HistoryPage(history: _historyStore),
            const MorePage(),
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
    });
  }
}
