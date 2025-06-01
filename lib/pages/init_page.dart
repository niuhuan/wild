import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/pages/auth_cubit.dart';
import 'package:wild/pages/novel/font_size_cubit.dart';
import 'package:wild/pages/novel/paragraph_spacing_cubit.dart';
import 'package:wild/pages/novel/line_height_cubit.dart';
import 'package:wild/pages/novel/theme_cubit.dart';
import 'package:wild/src/rust/api/system.dart';
import 'package:wild/pages/novel/top_bar_height_cubit.dart';
import 'package:wild/pages/novel/bottom_bar_height_cubit.dart';

import '../methods.dart';

class InitPage extends StatefulWidget {
  const InitPage({super.key});

  @override
  State<StatefulWidget> createState() => _InitPageState();
}

class _InitPageState extends State<InitPage> {
  Future<void> _initializeCubits() async {
    String root;
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      root = await desktopRoot();
    } else {
      root = await dataRoot();
    }
    if (kDebugMode) {
      print('root: $root');
    }
    await init(root: root);

    // 初始化所有 Cubit
    final fontSizeCubit = context.read<FontSizeCubit>();
    final paragraphSpacingCubit = context.read<ParagraphSpacingCubit>();
    final lineHeightCubit = context.read<LineHeightCubit>();
    final themeCubit = context.read<ThemeCubit>();
    final authCubit = context.read<AuthCubit>();
    final topBarHeightCubit = context.read<TopBarHeightCubit>();
    final bottomBarHeightCubit = context.read<BottomBarHeightCubit>();

    // 等待所有 Cubit 初始化完成
    await Future.wait([
      fontSizeCubit.loadFontSize(),
      paragraphSpacingCubit.loadSpacing(),
      lineHeightCubit.loadLineHeight(),
      themeCubit.loadTheme(),
      authCubit.init(),
      topBarHeightCubit.loadHeight(),
      bottomBarHeightCubit.loadHeight(),
    ]);

    if (authCubit.state.status == AuthStatus.authenticated) {
      // 如果已经登录，跳转到首页
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // 如果未登录，跳转到登录页
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeCubits();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ConstrainedBox(
        constraints: const BoxConstraints.expand(),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            var width = 1080;
            var height = 1920;
            var min = constraints.maxWidth > constraints.maxHeight 
                ? constraints.maxHeight 
                : constraints.maxWidth;
            var newHeight = min;
            var newWidth = min * (width / height);
            
            return Stack(
              children: [
                Center(
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black,
                          Colors.black,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.95, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'lib/assets/startup.png',
                      width: newWidth,
                      height: newHeight,
                    ),
                  ),
                ),
                // 加载指示器
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 48,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
