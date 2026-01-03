import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wild/utils/app_info.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:wild/state/app_state.dart' as app;

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final state = app.update.signal.watch(context);
      return Scaffold(
          appBar: AppBar(
            title: const Text('关于'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 24),
              // 应用图标
              Center(
                child: Icon(
                  Icons.book,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              // 应用名称
              Center(
                child: Text(
                  AppInfo.appName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              // 版本号
              Center(
                child: Text(
                  '版本 ${AppInfo.fullVersion}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(height: 32),
              // 更新按钮
              if (state.updateInfo != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FilledButton.icon(
                    onPressed: () async {
                      try {
                        await _launchUrl(state.updateInfo!.url);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('无法打开下载链接')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.system_update),
                    label: Text('发现新版本 ${state.updateInfo!.version}，点击下载'),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      app.update.checkUpdate(force: true);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('检查更新'),
                  ),
                ),
              const SizedBox(height: 32),
              // 其他信息
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '关于 Wild',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Wild 是一个使用 Flutter 开发的轻小说文库客户端，提供流畅的阅读体验和丰富的功能。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '开源协议',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '本项目采用 GNU General Public License v3.0 (GPLv3) 协议开源。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      );
    });
  }
}
