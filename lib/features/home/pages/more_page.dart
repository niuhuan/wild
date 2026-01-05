import 'package:flutter/material.dart';
import 'package:wild/features/home/pages/account_page.dart';
import 'package:wild/features/home/pages/settings_page.dart';
import 'package:wild/features/novel/pages/novel_download_page.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:wild/state/app_state.dart' as app;

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final state = app.update.signal.watch(context);
      return Scaffold(
        appBar: AppBar(
          title: const Text('更多'),
        ),
        body: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('下载'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NovelDownloadPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('账户'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AccountPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('设置'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('关于'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.updateInfo != null)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '新版本',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () {
                Navigator.pushNamed(context, '/about');
              },
            ),
          ],
        ),
      );
    });
  }
} 
