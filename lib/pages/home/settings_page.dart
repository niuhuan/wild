import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/cubits/screen_up_on_reading_property.dart';
import 'package:wild/cubits/screen_up_on_scroll_property.dart';
import 'package:wild/pages/auth_cubit.dart';
import 'package:wild/pages/novel/font_size_cubit.dart';
import 'package:wild/pages/novel/line_height_cubit.dart';
import 'package:wild/pages/novel/paragraph_spacing_cubit.dart';
import 'package:wild/pages/novel/theme_cubit.dart';
import 'package:wild/pages/novel/top_bar_height_cubit.dart';
import 'package:wild/pages/novel/bottom_bar_height_cubit.dart';
import 'package:wild/pages/novel/reader_type_cubit.dart';
import 'package:wild/src/rust/api/wenku8.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: BlocBuilder<ThemeCubit, ReaderTheme>(
        builder: (context, theme) {
          return ListView(
            children: [
              const SizedBox(height: 8),
              // 阅读器设置
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        '阅读器设置',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    BlocBuilder<ReaderTypeCubit, ReaderType>(
                      builder: (context, type) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('阅读器类型'),
                              const SizedBox(height: 8),
                              SegmentedButton<ReaderType>(
                                segments: const [
                                  ButtonSegment<ReaderType>(
                                    value: ReaderType.normal,
                                    label: Text('普通阅读器'),
                                    icon: Icon(Icons.book),
                                  ),
                                  ButtonSegment<ReaderType>(
                                    value: ReaderType.html,
                                    label: Text('HTML阅读器'),
                                    icon: Icon(Icons.html),
                                  ),
                                ],
                                selected: {type},
                                onSelectionChanged: (
                                  Set<ReaderType> types,
                                ) async {
                                  await context
                                      .read<ReaderTypeCubit>()
                                      .updateType(types.first);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    if (Platform.isAndroid || Platform.isIOS) ...[
                      screenUpOnReadingSetting(),
                      screenUpOnScrollSetting(),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
              // 主题设置
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        '主题设置',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    RadioListTile<ReaderThemeMode>(
                      title: const Text('跟随系统'),
                      value: ReaderThemeMode.auto,
                      groupValue: theme.themeMode,
                      onChanged: (value) {
                        if (value != null) {
                          context.read<ThemeCubit>().setThemeMode(value);
                        }
                      },
                    ),
                    RadioListTile<ReaderThemeMode>(
                      title: const Text('浅色'),
                      value: ReaderThemeMode.light,
                      groupValue: theme.themeMode,
                      onChanged: (value) {
                        if (value != null) {
                          context.read<ThemeCubit>().setThemeMode(value);
                        }
                      },
                    ),
                    RadioListTile<ReaderThemeMode>(
                      title: const Text('深色'),
                      value: ReaderThemeMode.dark,
                      groupValue: theme.themeMode,
                      onChanged: (value) {
                        if (value != null) {
                          context.read<ThemeCubit>().setThemeMode(value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              // 缓存设置
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        '缓存设置',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.cleaning_services_outlined),
                      title: const Text('清除接口缓存'),
                      subtitle: const Text('清除所有网络请求的缓存数据'),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('清除缓存'),
                                content: const Text('确定要清除所有接口缓存吗？'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      try {
                                        await cleanAllWebCache();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('缓存已清除'),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('清除缓存失败: $e'),
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: const Text('确定'),
                                  ),
                                ],
                              ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // 退出登录
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    '退出登录',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('退出登录'),
                            content: const Text('确定要退出登录吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await logout();
                                  if (context.mounted) {
                                    // 更新 AuthCubit 状态
                                    context.read<AuthCubit>().logout();
                                    // 清空导航栈并跳转到登录页
                                    Navigator.of(
                                      context,
                                    ).pushNamedAndRemoveUntil(
                                      '/login',
                                      (route) => false,
                                    );
                                  }
                                },
                                child: const Text('确定'),
                              ),
                            ],
                          ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
