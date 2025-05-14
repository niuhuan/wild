import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../src/rust/api/wenku8.dart';
import '../src/rust/wenku8/models.dart';
import '../methods.dart';

// State
abstract class ToplistState extends Equatable {
  const ToplistState();

  @override
  List<Object?> get props => [];
}

class ToplistInitial extends ToplistState {}

class ToplistLoading extends ToplistState {}

class ToplistLoaded extends ToplistState {
  final List<Novel> novels;
  final String sort;
  final bool hasMore;
  final int currentPage;

  const ToplistLoaded({
    required this.novels,
    this.sort = 'lastupdate',
    this.hasMore = true,
    this.currentPage = 1,
  });

  @override
  List<Object?> get props => [novels, sort, hasMore, currentPage];

  ToplistLoaded copyWith({
    List<Novel>? novels,
    String? sort,
    bool? hasMore,
    int? currentPage,
  }) {
    return ToplistLoaded(
      novels: novels ?? this.novels,
      sort: sort ?? this.sort,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class ToplistError extends ToplistState {
  final String message;

  const ToplistError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class ToplistCubit extends Cubit<ToplistState> {
  ToplistCubit() : super(ToplistInitial());

  void setSort(String sort) {
    if (state is ToplistLoaded) {
      final currentState = state as ToplistLoaded;
      if (currentState.sort != sort) {
        emit(currentState.copyWith(
          sort: sort,
          novels: [],
          currentPage: 1,
          hasMore: true,
        ));
        loadNovels(refresh: true);
      }
    }
  }

  Future<void> loadNovels({bool refresh = false}) async {
    if (state is! ToplistLoaded) {
      emit(ToplistLoading());
    } else if (refresh) {
      emit((state as ToplistLoaded).copyWith(
        novels: [],
        currentPage: 1,
        hasMore: true,
      ));
    }

    final currentState = state;
    if (currentState is! ToplistLoaded) return;

    if (!currentState.hasMore && !refresh) return;

    try {
      final page = refresh ? 1 : currentState.currentPage;
      final result = await toplist(
        sort: currentState.sort,
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

      if (state is ToplistLoaded) {
        final currentState = state as ToplistLoaded;
        final updatedNovels = refresh ? novels : [...currentState.novels, ...novels];
        emit(currentState.copyWith(
          novels: updatedNovels,
          currentPage: page + 1,
          hasMore: hasMore,
        ));
      } else {
        emit(ToplistLoaded(
          novels: novels,
          currentPage: page + 1,
          hasMore: hasMore,
        ));
      }
    } catch (e) {
      emit(ToplistError(e.toString()));
    }
  }
} 