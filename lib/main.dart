import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/pages/auth_cubit.dart';
import 'package:wild/pages/init_page.dart';
import 'package:wild/pages/login_page.dart';
import 'package:wild/pages/home_page.dart';
import 'package:wild/pages/novel/line_height_cubit.dart';
import 'package:wild/pages/novel/novel_info_page.dart';
import 'package:wild/pages/novel/reader_page.dart';
import 'package:wild/pages/novel/font_size_cubit.dart';
import 'package:wild/pages/novel/paragraph_spacing_cubit.dart';
import 'package:wild/pages/novel/theme_cubit.dart';
import 'package:wild/src/rust/frb_generated.dart';
import 'package:wild/src/rust/wenku8/models.dart';
import 'package:wild/pages/home/bookshelf_cubit.dart';
import 'package:wild/pages/home/history_cubit.dart';
import 'package:wild/pages/category/category_page.dart';
import 'package:wild/pages/toplist/toplist_page.dart';
import 'package:wild/pages/articlelist/articlelist_page.dart';
import 'package:wild/pages/recommend/recommend_page.dart';
import 'package:wild/pages/home/more_page.dart';

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
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => AuthCubit()),
        BlocProvider(create: (context) => BookshelfCubit()..loadBookcases()),
        BlocProvider(create: (context) => ThemeCubit()),
        BlocProvider(create: (context) => FontSizeCubit()),
        BlocProvider(create: (context) => LineHeightCubit()),
        BlocProvider(create: (context) => ParagraphSpacingCubit()),
      ],
      child: YourApp(),
    );
  }
}

class YourApp extends StatelessWidget {
  const YourApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ReaderTheme>(
      builder: (context, theme) {
        return MaterialApp(
          title: '轻小说文库',
          theme:
          theme.themeMode == ReaderThemeMode.dark
                  ? darkTheme
                  : lightTheme,
          darkTheme:
              theme.themeMode ==
                      ReaderThemeMode.light
                  ? lightTheme
                  : darkTheme,
          initialRoute: '/init',
          routes: {
            '/init': (context) => const InitPage(),
            '/login': (context) => const LoginPage(),
            '/home': (context) => const HomePage(),
            '/novel/info': (context) {
              final novelId =
                  ModalRoute.of(context)!.settings.arguments as String;
              return NovelInfoPage(novelId: novelId);
            },
            '/novel/reader': (context) {
              final args =
                  ModalRoute.of(context)!.settings.arguments
                      as Map<String, dynamic>;
              return MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: context.read<FontSizeCubit>()),
                  BlocProvider.value(
                    value: context.read<ParagraphSpacingCubit>(),
                  ),
                  BlocProvider.value(value: context.read<LineHeightCubit>()),
                  BlocProvider.value(value: context.read<ThemeCubit>()),
                ],
                child: ReaderPage(
                  aid: args['novelId'] as String,
                  cid: args['chapterId'] as String,
                  initialTitle: args['title'] as String,
                  volumes: (args['volumes'] as List).cast<Volume>(),
                  novelInfo: args['novelInfo'] as NovelInfo,
                ),
              );
            },
            '/category': (context) => const CategoryPage(),
            '/toplist': (context) => const ToplistPage(),
            '/articlelist': (context) => const ArticlelistPage(),
            '/recommend': (context) => const RecommendPage(),
            '/more': (context) => const MorePage(),
          },
        );
      },
    );
  }
}
