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

// 加载完成状态
class HtmlReaderLoaded extends HtmlReaderState {
  final String aid;
  final String cid;
  final String title;
  final String content;
  final List<Volume> volumes;

  const HtmlReaderLoaded({
    required this.aid,
    required this.cid,
    required this.title,
    required this.content,
    required this.volumes,
  });

  HtmlReaderLoaded copyWith({
    String? aid,
    String? cid,
    String? title,
    String? content,
    List<Volume>? volumes,
  }) {
    return HtmlReaderLoaded(
      aid: aid ?? this.aid,
      cid: cid ?? this.cid,
      title: title ?? this.title,
      content: content ?? this.content,
      volumes: volumes ?? this.volumes,
    );
  }

  @override
  List<Object?> get props => [aid, cid, title, content, volumes];
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
      final content = await w8.chapterContent(aid: targetAid, cid: targetCid);
      emit(HtmlReaderLoaded(
        aid: targetAid,
        cid: targetCid,
        title: chapterTitle,
        content: content,
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