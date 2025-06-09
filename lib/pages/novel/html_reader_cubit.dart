import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../src/rust/wenku8/models.dart';
import '../../src/rust/api/wenku8.dart' as w8;

// 状态基类
abstract class HtmlReaderState extends Equatable {
  const HtmlReaderState();

  @override
  List<Object?> get props => [];
}

// 加载中状态
class HtmlReaderLoading extends HtmlReaderState {
  const HtmlReaderLoading();
}

// 错误状态
class HtmlReaderError extends HtmlReaderState {
  final String error;

  const HtmlReaderError(this.error);

  @override
  List<Object?> get props => [error];
}

// 解析后的内容类型
abstract class ParsedContent extends Equatable {
  const ParsedContent();
}

class ParsedText extends ParsedContent {
  final String text;

  const ParsedText(this.text);

  @override
  List<Object?> get props => [text];
}

class ParsedImage extends ParsedContent {
  final String imageUrl;

  const ParsedImage(this.imageUrl);

  @override
  List<Object?> get props => [imageUrl];
}

// 加载完成状态
class HtmlReaderLoaded extends HtmlReaderState {
  final String aid;
  final String cid;
  final String title;
  final String rawContent;
  final List<ParsedContent> parsedContent;
  final List<Volume> volumes;

  const HtmlReaderLoaded({
    required this.aid,
    required this.cid,
    required this.title,
    required this.rawContent,
    required this.parsedContent,
    required this.volumes,
  });

  HtmlReaderLoaded copyWith({
    String? aid,
    String? cid,
    String? title,
    String? rawContent,
    List<ParsedContent>? parsedContent,
    List<Volume>? volumes,
  }) {
    return HtmlReaderLoaded(
      aid: aid ?? this.aid,
      cid: cid ?? this.cid,
      title: title ?? this.title,
      rawContent: rawContent ?? this.rawContent,
      parsedContent: parsedContent ?? this.parsedContent,
      volumes: volumes ?? this.volumes,
    );
  }

  @override
  List<Object?> get props => [aid, cid, title, rawContent, parsedContent, volumes];
}

class HtmlReaderCubit extends Cubit<HtmlReaderState> {
  final NovelInfo novelInfo;
  final String initialAid;
  final String initialCid;
  final List<Volume> initialVolumes;

  HtmlReaderCubit({
    required this.novelInfo,
    required this.initialAid,
    required this.initialCid,
    required this.initialVolumes,
  }) : super(const HtmlReaderLoading());

  Volume _findVolume(String aid, String cid) {
    for (final volume in initialVolumes) {
      for (final chapter in volume.chapters) {
        if (chapter.aid == aid && chapter.cid == cid) {
          return volume;
        }
      }
    }
    throw Exception('Volume not found');
  }

  Future<void> _updateHistory(String aid, String cid, String title) async {
    final volume = _findVolume(aid, cid);
    await w8.updateHistory(
      novelId: aid,
      novelName: novelInfo.title,
      volumeId: volume.id,
      volumeName: volume.title,
      chapterId: cid,
      chapterTitle: title,
      progress: 0,
      progressPage: 0,
      cover: novelInfo.imgUrl,
      author: novelInfo.author,
    );
  }

  List<ParsedContent> _parseContent(String content) {
    final parsedContent = <ParsedContent>[];
    final paragraphs = content.split('\n');

    for (var paragraph in paragraphs) {
      if (paragraph.trim().isEmpty) continue;

      // 检查是否包含图片标签
      RegExp regex = RegExp("\<\!\-\-image\-\-\>([^\<]+)\<\!\-\-image\-\-\>");
      if (regex.hasMatch(paragraph)) {
        var currentText = paragraph;
        while (regex.hasMatch(currentText)) {
          var match = regex.firstMatch(currentText)!;

          // 处理图片前的文本
          if (match.start > 0) {
            var text = currentText.substring(0, match.start).trim();
            if (text.isNotEmpty) {
              parsedContent.add(ParsedText(text));
            }
          }

          // 处理图片
          final imageUrl = match.group(1)!;
          parsedContent.add(ParsedImage(imageUrl));

          // 更新剩余文本
          currentText = currentText.substring(match.end);
        }

        // 处理最后剩余的文本
        if (currentText.trim().isNotEmpty) {
          parsedContent.add(ParsedText(currentText.trim()));
        }
      } else {
        // 普通文本段落
        parsedContent.add(ParsedText(paragraph));
      }
    }

    return parsedContent;
  }

  Future<void> loadChapter({String? aid, String? cid}) async {
    try {
      emit(const HtmlReaderLoading());
      final targetAid = aid ?? initialAid;
      final targetCid = cid ?? initialCid;

      // 查找章节信息
      String? chapterTitle;
      for (var volume in initialVolumes) {
        for (var chapter in volume.chapters) {
          if (chapter.aid == targetAid && chapter.cid == targetCid) {
            chapterTitle = chapter.title;
            break;
          }
        }
        if (chapterTitle != null) break;
      }

      if (chapterTitle == null) {
        emit(const HtmlReaderError('章节不存在'));
        return;
      }

      // 加载章节内容
      final rawContent = await w8.chapterContent(aid: targetAid, cid: targetCid);
      final parsedContent = _parseContent(rawContent);
      
      // 更新阅读历史
      await _updateHistory(targetAid, targetCid, chapterTitle);

      emit(HtmlReaderLoaded(
        aid: targetAid,
        cid: targetCid,
        title: chapterTitle,
        rawContent: rawContent,
        parsedContent: parsedContent,
        volumes: initialVolumes,
      ));
    } catch (e) {
      emit(HtmlReaderError(e.toString()));
    }
  }

  Future<void> goToNextChapter() async {
    if (state is! HtmlReaderLoaded) return;
    final currentState = state as HtmlReaderLoaded;

    // 查找当前章节索引
    int currentVolumeIndex = -1;
    int currentChapterIndex = -1;
    for (var i = 0; i < currentState.volumes.length; i++) {
      final volume = currentState.volumes[i];
      for (var j = 0; j < volume.chapters.length; j++) {
        final chapter = volume.chapters[j];
        if (chapter.aid == currentState.aid && chapter.cid == currentState.cid) {
          currentVolumeIndex = i;
          currentChapterIndex = j;
          break;
        }
      }
      if (currentVolumeIndex != -1) break;
    }

    if (currentVolumeIndex == -1 || currentChapterIndex == -1) return;

    // 尝试获取下一章
    String? nextAid;
    String? nextCid;
    if (currentChapterIndex < currentState.volumes[currentVolumeIndex].chapters.length - 1) {
      // 当前卷的下一章
      final nextChapter = currentState.volumes[currentVolumeIndex].chapters[currentChapterIndex + 1];
      nextAid = nextChapter.aid;
      nextCid = nextChapter.cid;
    } else if (currentVolumeIndex < currentState.volumes.length - 1) {
      // 下一卷的第一章
      final nextChapter = currentState.volumes[currentVolumeIndex + 1].chapters[0];
      nextAid = nextChapter.aid;
      nextCid = nextChapter.cid;
    }

    if (nextAid != null && nextCid != null) {
      await loadChapter(aid: nextAid, cid: nextCid);
    }
  }

  Future<void> goToPreviousChapter() async {
    if (state is! HtmlReaderLoaded) return;
    final currentState = state as HtmlReaderLoaded;

    // 查找当前章节索引
    int currentVolumeIndex = -1;
    int currentChapterIndex = -1;
    for (var i = 0; i < currentState.volumes.length; i++) {
      final volume = currentState.volumes[i];
      for (var j = 0; j < volume.chapters.length; j++) {
        final chapter = volume.chapters[j];
        if (chapter.aid == currentState.aid && chapter.cid == currentState.cid) {
          currentVolumeIndex = i;
          currentChapterIndex = j;
          break;
        }
      }
      if (currentVolumeIndex != -1) break;
    }

    if (currentVolumeIndex == -1 || currentChapterIndex == -1) return;

    // 尝试获取上一章
    String? prevAid;
    String? prevCid;
    if (currentChapterIndex > 0) {
      // 当前卷的上一章
      final prevChapter = currentState.volumes[currentVolumeIndex].chapters[currentChapterIndex - 1];
      prevAid = prevChapter.aid;
      prevCid = prevChapter.cid;
    } else if (currentVolumeIndex > 0) {
      // 上一卷的最后一章
      final prevVolume = currentState.volumes[currentVolumeIndex - 1];
      final prevChapter = prevVolume.chapters[prevVolume.chapters.length - 1];
      prevAid = prevChapter.aid;
      prevCid = prevChapter.cid;
    }

    if (prevAid != null && prevCid != null) {
      await loadChapter(aid: prevAid, cid: prevCid);
    }
  }
} 