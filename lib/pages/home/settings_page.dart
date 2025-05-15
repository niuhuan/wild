import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/pages/novel/theme_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: BlocBuilder<ThemeCubit, ReaderTheme>(
        builder: (context, theme) {
          return ListView(
            children: [
              const SizedBox(height: 8),
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
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
            ],
          );
        },
      ),
    );
  }
} 