import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/pages/configs/auth_cubit.dart';

class InitPage extends StatefulWidget {
  const InitPage({super.key});

  @override
  State<StatefulWidget> createState() => _InitPageState();
}

class _InitPageState extends State<InitPage> {
  Future<void> _initializeCubits() async {
    final authCubit = context.read<AuthCubit>();
    // 初始化所有 Cubit
    await Future.wait([authCubit.init()]);

    if (authCubit.state == AuthStatus.authenticated) {
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
    return Scaffold(body: Center(child: Text('Loading')));
  }
}
