import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/pages/auth_cubit.dart';
import 'package:wild/pages/init_page.dart';
import 'package:wild/pages/login_page.dart';
import 'package:wild/pages/home_page.dart';
import 'package:wild/pages/novel/novel_info_page.dart';
import 'package:wild/pages/novel/reader_page.dart';
import 'package:wild/src/rust/frb_generated.dart';
import 'package:wild/src/rust/wenku8/models.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [BlocProvider(create: (context) => AuthCubit())],
      child: MaterialApp(
        title: '轻小说文库',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        initialRoute: '/init',
        routes: {
          '/init': (context) => const InitPage(),
          '/login': (context) => const LoginPage(),
          '/home': (context) => const HomePage(),
          '/novel/info': (context) {
            final novelId = ModalRoute.of(context)!.settings.arguments as String;
            return NovelInfoPage(novelId: novelId);
          },
          '/novel/reader': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
            return ReaderPage(
              aid: args['novelId'] as String,
              cid: args['chapterId'] as String,
              initialTitle: args['title'] as String,
              volumes: (args['volumes'] as List).cast<Volume>(),
            );
          },
        },
      ),
    );
  }
}
