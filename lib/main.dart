import 'dart:io';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:wild/features/app/pages/init_page.dart';
import 'package:wild/features/auth/pages/login_page.dart';
import 'package:wild/features/home/pages/home_page.dart';
import 'package:wild/features/novel/pages/html_reader_page.dart';
import 'package:wild/features/novel/pages/novel_downloading_page.dart';
import 'package:wild/features/novel/pages/novel_info_page.dart';
import 'package:wild/features/novel/pages/reader_page.dart';
import 'package:wild/features/novel/pages/reviews_page.dart';
import 'package:wild/features/novel/stores/reader_type_store.dart';
import 'package:wild/features/novel/stores/theme_store.dart';
import 'package:wild/src/rust/frb_generated.dart';
import 'package:wild/src/rust/wenku8/models.dart';
import 'package:wild/features/category/pages/category_page.dart';
import 'package:wild/features/articlelist/pages/articlelist_page.dart';
import 'package:wild/features/recommend/pages/recommend_page.dart';
import 'package:wild/features/home/pages/more_page.dart';
import 'package:wild/features/search/pages/search_page.dart';
import 'package:wild/features/home/pages/about_page.dart';
import 'package:wild/utils/app_info.dart';
import 'package:wild/widgets/update_checker.dart';
import 'package:wild/state/app_state.dart' as app;

final lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  useMaterial3: true,
);
final darkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
);

Future<void> main() async {
  HttpOverrides.global = _LoggingHttpOverrides();  // ← 新增這行
  WidgetsFlutterBinding.ensureInitialized();
  await AppInfo.init();
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const YourApp();
  }
}

class YourApp extends StatelessWidget {
  const YourApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final theme = app.theme.signal.watch(context);
      return MaterialApp(
        title: '轻小说文库',
        theme: theme.themeMode == ReaderThemeMode.dark ? darkTheme : lightTheme,
        darkTheme:
            theme.themeMode == ReaderThemeMode.light ? lightTheme : darkTheme,
        initialRoute: '/init',
        routes: {
          '/init': (context) => const InitPage(),
          '/login': (context) => const UpdateChecker(child: LoginPage()),
          '/home': (context) => const UpdateChecker(child: HomePage()),
          '/novel/info': (context) {
            final args = ModalRoute.of(context)!.settings.arguments;
            if (args is Map<String, dynamic>) {
              return NovelInfoPage(novelId: args['novelId'] as String);
            }
            return NovelInfoPage(novelId: args as String);
          },
          '/novel/reviews': (context) {
            final args =
                ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
            return ReviewsPage(
              aid: args['aid'] as String,
              title: args['title'] as String,
            );
          },
          '/novel/downloading': (context) {
            final args =
                ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
            return NovelDownloadingPage(
              novelId: args['novelId'] as String,
              existsDownload: args['existsDownload'],
              novelInfo: args['novelInfo'] as NovelInfo,
              volumes: (args['volumes'] as List).cast<Volume>(),
            );
          },
          '/novel/reader': (context) {
            final args =
                ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
            final readerType = app.readerType.state;

            if (readerType == ReaderType.html) {
              return HtmlReaderPage(
                novelInfo: args['novelInfo'] as NovelInfo,
                initialAid: args['novelId'] as String,
                initialCid: args['chapterId'] as String,
                volumes: (args['volumes'] as List).cast<Volume>(),
              );
            }
            return ReaderPage(
              aid: args['novelId'] as String,
              cid: args['chapterId'] as String,
              initialTitle: args['title'] as String,
              volumes: (args['volumes'] as List).cast<Volume>(),
              novelInfo: args['novelInfo'] as NovelInfo,
              initialPage: args['initialPage'] as int?,
            );
          },
          '/category': (context) {
            final args = ModalRoute.of(context)!.settings.arguments;
            if (args is Map<String, dynamic> && args.containsKey('tag')) {
              return Scaffold(
                appBar: AppBar(title: Text("分类")),
                body: CategoryPage(initialTag: args['tag'] as String),
              );
            }
            return const CategoryPage();
          },
          '/articlelist': (context) => const ArticlelistPage(),
          '/recommend': (context) => const RecommendPage(),
          '/more': (context) => const MorePage(),
          '/search': (context) {
            final args = ModalRoute.of(context)!.settings.arguments;
            if (args is Map<String, dynamic>) {
              return SearchPage(
                initialSearchType: args['searchType'] as String?,
                initialSearchKey: args['searchKey'] as String?,
              );
            }
            return const SearchPage();
          },
          '/about': (context) => const AboutPage(),
        },
      );
    });
  }
}

class _LoggingHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final base = super.createHttpClient(context);
    return _LoggingHttpClient(base);
  }
}

class _LoggingHttpClient implements HttpClient {
  final HttpClient _inner;
  _LoggingHttpClient(this._inner);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final startedAt = DateTime.now();
    print('[HTTP][$method] $url');
    try {
      final req = await _inner.openUrl(method, url);
      return _LoggingHttpClientRequest(req, url, method, startedAt);
    } catch (e) {
      print('[HTTP][ERR][$method] $url -> $e');
      rethrow;
    }
  }

  // 其他方法交給原本的 client
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LoggingHttpClientRequest implements HttpClientRequest {
  final HttpClientRequest _inner;
  final Uri url;
  final String method;
  final DateTime startedAt;
  _LoggingHttpClientRequest(this._inner, this.url, this.method, this.startedAt);

  @override
  Future<HttpClientResponse> close() async {
    final resp = await _inner.close();
    final ms = DateTime.now().difference(startedAt).inMilliseconds;
    print('[HTTP][RESP ${resp.statusCode}] $method $url (${ms}ms)');
    return resp;
  }

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
