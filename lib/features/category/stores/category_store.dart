import 'package:equatable/equatable.dart';
import 'package:signals/signals.dart' as signals;
import 'package:wild/src/rust/api/wenku8.dart';
import 'package:wild/src/rust/wenku8/models.dart';

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

// Store
class CategoryStore {
  CategoryStore() : _state = signals.signal<CategoryState>(CategoryInitial());

  final signals.Signal<CategoryState> _state;
  CategoryState get state => _state.value;
  signals.Signal<CategoryState> get signal => _state;

  Future<void> loadTags() async {
    try {
      final tagGroups = await tags();
      if (state is CategoryLoaded) {
        _state.value = (state as CategoryLoaded).copyWith(tagGroups: tagGroups);
      } else {
        _state.value = CategoryLoaded(novels: [], tagGroups: tagGroups);
      }
    } catch (e) {
      _state.value = CategoryError(e.toString());
    }
  }

  void setViewMode(String viewMode) {
    if (state is CategoryLoaded) {
      final currentState = state as CategoryLoaded;
      if (currentState.viewMode != viewMode) {
        _state.value = currentState.copyWith(
          viewMode: viewMode,
          novels: [],
          currentPage: 1,
          hasMore: true,
        );
        loadNovels(refresh: true);
      }
    }
  }

  Future<void> loadNovels({bool refresh = false}) async {
    if (state is! CategoryLoaded) return;
    final currentState = state as CategoryLoaded;

    if (refresh) {
      _state.value =
          currentState.copyWith(novels: [], currentPage: 1, hasMore: true);
    }

    if (!currentState.hasMore && !refresh) return;

    try {
      final page = refresh ? 1 : currentState.currentPage;
      final selectedTag = currentState.selectedTag;
      
      if (selectedTag == null) {
        _state.value = CategoryError('请先选择一个标签');
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
        _state.value = currentState.copyWith(
          novels: updatedNovels,
          currentPage: page + 1,
          hasMore: hasMore,
        );
      } else {
        _state.value = CategoryLoaded(
          novels: novels,
          tagGroups: currentState.tagGroups,
          selectedTag: selectedTag,
          currentPage: page + 1,
          hasMore: hasMore,
        );
      }
    } catch (e) {
      _state.value = CategoryError(e.toString());
    }
  }

  void selectTag(String tag) {
    if (state is CategoryLoaded) {
      final currentState = state as CategoryLoaded;
      if (currentState.selectedTag != tag) {
        _state.value = currentState.copyWith(
          selectedTag: tag,
          novels: [],
          currentPage: 1,
          hasMore: true,
        );
        loadNovels(refresh: true);
      }
    }
  }
} 
