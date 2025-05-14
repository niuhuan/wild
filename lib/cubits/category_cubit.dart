import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../src/rust/api/wenku8.dart';
import '../src/rust/wenku8/models.dart';
import '../methods.dart';

// State
abstract class CategoryState extends Equatable {
  const CategoryState();

  @override
  List<Object?> get props => [];
}

class CategoryInitial extends CategoryState {}

class CategoryLoading extends CategoryState {}

class CategoryLoaded extends CategoryState {
  final List<Novel> novels;
  final List<TagGroup> tagGroups;
  final String? selectedTag;
  final String viewMode;
  final bool hasMore;
  final int currentPage;

  const CategoryLoaded({
    required this.novels,
    required this.tagGroups,
    this.selectedTag,
    this.viewMode = "0",
    this.hasMore = true,
    this.currentPage = 1,
  });

  @override
  List<Object?> get props => [novels, tagGroups, selectedTag, viewMode, hasMore, currentPage];

  CategoryLoaded copyWith({
    List<Novel>? novels,
    List<TagGroup>? tagGroups,
    String? selectedTag,
    String? viewMode,
    bool? hasMore,
    int? currentPage,
  }) {
    return CategoryLoaded(
      novels: novels ?? this.novels,
      tagGroups: tagGroups ?? this.tagGroups,
      selectedTag: selectedTag ?? this.selectedTag,
      viewMode: viewMode ?? this.viewMode,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class CategoryError extends CategoryState {
  final String message;

  const CategoryError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class CategoryCubit extends Cubit<CategoryState> {
  CategoryCubit() : super(CategoryInitial());

  Future<void> loadTags() async {
    try {
      final tagGroups = await tags();
      if (state is CategoryLoaded) {
        emit((state as CategoryLoaded).copyWith(tagGroups: tagGroups));
      } else {
        emit(CategoryLoaded(novels: [], tagGroups: tagGroups));
      }
    } catch (e) {
      emit(CategoryError(e.toString()));
    }
  }

  void setViewMode(String viewMode) {
    if (state is CategoryLoaded) {
      final currentState = state as CategoryLoaded;
      if (currentState.viewMode != viewMode) {
        emit(currentState.copyWith(
          viewMode: viewMode,
          novels: [],
          currentPage: 1,
          hasMore: true,
        ));
        loadNovels(refresh: true);
      }
    }
  }

  Future<void> loadNovels({bool refresh = false}) async {
    if (state is! CategoryLoaded) return;
    final currentState = state as CategoryLoaded;

    if (refresh) {
      emit(currentState.copyWith(novels: [], currentPage: 1, hasMore: true));
    }

    if (!currentState.hasMore && !refresh) return;

    try {
      final page = refresh ? 1 : currentState.currentPage;
      final selectedTag = currentState.selectedTag;
      
      if (selectedTag == null) {
        emit(CategoryError('请先选择一个标签'));
        return;
      }

      final result = await tagPage(
        tag: selectedTag,
        v: currentState.viewMode,
        pageNumber: page,
      );

      final novels = result.records.map((cover) => Novel(
        id: cover.aid,
        title: cover.title,
        author: '',
        coverUrl: cover.img,
        lastChapter: '',
        tags: [],
      )).toList();
      final hasMore = novels.isNotEmpty;

      if (state is CategoryLoaded) {
        final currentState = state as CategoryLoaded;
        final updatedNovels = refresh ? novels : [...currentState.novels, ...novels];
        emit(currentState.copyWith(
          novels: updatedNovels,
          currentPage: page + 1,
          hasMore: hasMore,
        ));
      } else {
        emit(CategoryLoaded(
          novels: novels,
          tagGroups: currentState.tagGroups,
          selectedTag: selectedTag,
          currentPage: page + 1,
          hasMore: hasMore,
        ));
      }
    } catch (e) {
      emit(CategoryError(e.toString()));
    }
  }

  void selectTag(String tag) {
    if (state is CategoryLoaded) {
      final currentState = state as CategoryLoaded;
      if (currentState.selectedTag != tag) {
        emit(currentState.copyWith(
          selectedTag: tag,
          novels: [],
          currentPage: 1,
          hasMore: true,
        ));
        loadNovels(refresh: true);
      }
    }
  }
} 