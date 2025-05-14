import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../src/rust/api/wenku8.dart';
import '../src/rust/wenku8/models.dart';
import '../methods.dart';

// State
abstract class ArticlelistState extends Equatable {
  const ArticlelistState();

  @override
  List<Object?> get props => [];
}

class ArticlelistInitial extends ArticlelistState {}

class ArticlelistLoading extends ArticlelistState {}

class ArticlelistLoaded extends ArticlelistState {
  final List<Novel> novels;
  final bool hasMore;
  final int currentPage;

  const ArticlelistLoaded({
    required this.novels,
    this.hasMore = true,
    this.currentPage = 1,
  });

  @override
  List<Object?> get props => [novels, hasMore, currentPage];

  ArticlelistLoaded copyWith({
    List<Novel>? novels,
    bool? hasMore,
    int? currentPage,
  }) {
    return ArticlelistLoaded(
      novels: novels ?? this.novels,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class ArticlelistError extends ArticlelistState {
  final String message;

  const ArticlelistError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class ArticlelistCubit extends Cubit<ArticlelistState> {
  ArticlelistCubit() : super(ArticlelistInitial());

  Future<void> loadNovels({bool refresh = false}) async {
    if (state is! ArticlelistLoaded) {
      emit(ArticlelistLoaded(novels: []));
    } else if (refresh) {
      emit((state as ArticlelistLoaded).copyWith(
        novels: [],
        currentPage: 1,
        hasMore: true,
      ));
    }

    final currentState = state;
    if (currentState is! ArticlelistLoaded) return;

    if (!currentState.hasMore && !refresh) return;

    try {
      final page = refresh ? 1 : currentState.currentPage;
      final result = await articlelist(
        fullflag: 1, // 1 表示完本小说
        page: page,
      );
      final novels = result.records.map((cover) => Novel(
        id: cover.aid,
        title: cover.title,
        author: '', // 需要从 novelInfo 获取
        coverUrl: cover.img,
        lastChapter: '', // 需要从 novelInfo 获取
        tags: [], // 需要从 novelInfo 获取
      )).toList();
      final hasMore = novels.isNotEmpty;

      if (state is ArticlelistLoaded) {
        final currentState = state as ArticlelistLoaded;
        final updatedNovels = refresh ? novels : [...currentState.novels, ...novels];
        emit(currentState.copyWith(
          novels: updatedNovels,
          currentPage: page + 1,
          hasMore: hasMore,
        ));
      } else {
        emit(ArticlelistLoaded(
          novels: novels,
          currentPage: page + 1,
          hasMore: hasMore,
        ));
      }
    } catch (e) {
      emit(ArticlelistError(e.toString()));
    }
  }
} 