import 'dart:io';

import 'package:flutter/material.dart';
import 'package:wild/features/settings/screen/screen_up_on_reading_property.dart';
import 'package:wild/features/settings/screen/screen_up_on_scroll_property.dart';
import 'package:wild/features/novel/stores/theme_store.dart';
import 'package:wild/features/novel/stores/reader_type_store.dart';
import 'package:wild/src/rust/api/wenku8.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:wild/state/app_state.dart' as app;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Watch((context) {
        final theme = app.theme.signal.watch(context);
        final readerType = app.readerType.signal.watch(context);
        final apiHost = app.apiHost.signal.watch(context);
        final isVolumeControlEnabled = app.volumeControl.signal.watch(context);
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
                    Padding(
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
                            selected: {readerType},
                            onSelectionChanged: (Set<ReaderType> types) async {
                              await app.readerType.updateType(types.first);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (Platform.isAndroid || Platform.isIOS) ...[
                      screenUpOnReadingSetting(),
                      screenUpOnScrollSetting(),
                      const SizedBox(height: 16),
                    ],
                    // 音量键控制设置（仅安卓）
                    if (Platform.isAndroid) ...[
                      SwitchListTile(
                        title: const Text('音量键翻页'),
                        value: isVolumeControlEnabled,
                        onChanged: (value) {
                          app.volumeControl.updateVolumeControl(value);
                        },
                      ),
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
                          app.theme.setThemeMode(value);
                        }
                      },
                    ),
                    RadioListTile<ReaderThemeMode>(
                      title: const Text('浅色'),
                      value: ReaderThemeMode.light,
                      groupValue: theme.themeMode,
                      onChanged: (value) {
                        if (value != null) {
                          app.theme.setThemeMode(value);
                        }
                      },
                    ),
                    RadioListTile<ReaderThemeMode>(
                      title: const Text('深色'),
                      value: ReaderThemeMode.dark,
                      groupValue: theme.themeMode,
                      onChanged: (value) {
                        if (value != null) {
                          app.theme.setThemeMode(value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              // API Host 设置
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'API Host 设置',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('API 主机地址'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: TextEditingController(text: apiHost),
                            decoration: const InputDecoration(
                              hintText: '留空使用默认地址',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.link),
                            ),
                            onSubmitted: (value) async {
                              try {
                                await app.apiHost.updateApiHost(value);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('API Host 已更新'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('更新失败: $e'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    try {
                                      await app.apiHost.resetToDefault();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('已重置为默认地址'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('重置失败: $e'),
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('重置为默认'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
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
                                    // 更新 AuthStore 状态
                                    app.auth.logout();
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
      }),
    );
  }
}
