import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:wild/features/novel/stores/html_reader_store.dart';
import 'package:wild/features/novel/stores/theme_store.dart';
import 'package:wild/state/app_state.dart' as app;
import 'package:wild/widgets/cached_image.dart';

import 'package:wild/src/rust/wenku8/models.dart';

class HtmlReaderPage extends StatefulWidget {
  final NovelInfo novelInfo;
  final String initialAid;
  final String initialCid;
  final List<Volume> volumes;

  const HtmlReaderPage({
    super.key,
    required this.novelInfo,
    required this.initialAid,
    required this.initialCid,
    required this.volumes,
  });

  @override
  State<HtmlReaderPage> createState() => _HtmlReaderPageState();
}

class _HtmlReaderPageState extends State<HtmlReaderPage> {
  late final HtmlReaderStore _store;

  @override
  void initState() {
    super.initState();
    _store = HtmlReaderStore(
      novelInfo: widget.novelInfo,
      initialAid: widget.initialAid,
      initialCid: widget.initialCid,
      initialVolumes: widget.volumes,
    )..loadChapter();
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final theme = app.theme.signal.watch(context);
      final fontSize = app.fontSize.signal.watch(context);
      final lineHeight = app.lineHeight.signal.watch(context);
      final paragraphSpacing = app.paragraphSpacing.signal.watch(context);
      final leftPadding = app.leftPadding.signal.watch(context);
      final rightPadding = app.rightPadding.signal.watch(context);
      final state = _store.signal.watch(context);

      bool isDarkMode;
      if (theme.themeMode == ReaderThemeMode.dark) {
        isDarkMode = true;
      } else if (theme.themeMode == ReaderThemeMode.light) {
        isDarkMode = false;
      } else {
        isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
      }

      final backgroundColor =
          isDarkMode ? theme.darkBackgroundColor : theme.lightBackgroundColor;
      final textColor = isDarkMode ? theme.darkTextColor : theme.lightTextColor;

      if (state is HtmlReaderLoading) {
        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(title: const Text('加载中...')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      if (state is HtmlReaderError) {
        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(title: const Text('加载失败')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(state.error, style: TextStyle(color: textColor)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _store.loadChapter(),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        );
      }

      if (state is! HtmlReaderLoaded) {
        return const SizedBox.shrink();
      }

      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text(state.title),
          actions: [
            IconButton(
              tooltip: '上一章',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _store.goToPreviousChapter(),
            ),
            IconButton(
              tooltip: '下一章',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _store.goToNextChapter(),
            ),
          ],
        ),
        body: ListView.separated(
          padding: EdgeInsets.fromLTRB(leftPadding, 16, rightPadding, 16),
          itemCount: state.parsedContent.length,
          separatorBuilder: (_, __) => SizedBox(height: paragraphSpacing),
          itemBuilder: (context, index) {
            final item = state.parsedContent[index];
            if (item is ParsedImage) {
              return Center(
                child: CachedImage(
                  url: item.imageUrl,
                  fit: BoxFit.contain,
                ),
              );
            }
            if (item is ParsedText) {
              return Text(
                item.text,
                style: TextStyle(
                  fontSize: fontSize,
                  height: lineHeight,
                  color: textColor,
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      );
    });
  }
}
