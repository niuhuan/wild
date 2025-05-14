import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:wild/src/rust/api/wenku8.dart';
import 'package:wild/src/rust/wenku8/models.dart';

enum BookshelfStatus { initial, loading, success, error }

class BookshelfState {
  final BookshelfStatus status;
  final List<Bookcase> bookcases;
  final String? currentCaseId;
  final Map<String, List<BookcaseItem>> bookcaseContents;
  final String? errorMessage;

  BookshelfState({
    required this.status,
    required this.bookcases,
    this.currentCaseId,
    required this.bookcaseContents,
    this.errorMessage,
  });

  BookshelfState copyWith({
    BookshelfStatus? status,
    List<Bookcase>? bookcases,
    String? currentCaseId,
    Map<String, List<BookcaseItem>>? bookcaseContents,
    String? errorMessage,
  }) {
    return BookshelfState(
      status: status ?? this.status,
      bookcases: bookcases ?? this.bookcases,
      currentCaseId: currentCaseId ?? this.currentCaseId,
      bookcaseContents: bookcaseContents ?? this.bookcaseContents,
      errorMessage: errorMessage,
    );
  }

  List<BookcaseItem>? getCurrentBooks() {
    if (currentCaseId == null) return null;
    return bookcaseContents[currentCaseId];
  }

  bool isBookInBookshelf(String aid) {
    for (final books in bookcaseContents.values) {
      if (books.any((book) => book.aid == aid)) {
        return true;
      }
    }
    return false;
  }

  String? getBookBid(String aid) {
    for (final books in bookcaseContents.values) {
      final book = books.firstWhere(
        (book) => book.aid == aid,
        orElse: () => BookcaseItem(
          aid: '',
          bid: '',
          title: '',
          author: '',
          cid: '',
          chapterName: '',
        ),
      );
      if (book.bid.isNotEmpty) {
        return book.bid;
      }
    }
    return null;
  }
}

class BookshelfCubit extends Cubit<BookshelfState> {
  BookshelfCubit() : super(BookshelfState(
    status: BookshelfStatus.initial,
    bookcases: const [],
    bookcaseContents: const {},
  ));

  Future<void> loadBookcases() async {
    try {
      emit(state.copyWith(status: BookshelfStatus.loading));
      final bookcases = await bookcaseList();
      if (bookcases.isEmpty) {
        emit(state.copyWith(
          status: BookshelfStatus.success,
          bookcases: const [],
          bookcaseContents: const {},
        ));
        return;
      }

      final contents = <String, List<BookcaseItem>>{};
      for (final bookcase in bookcases) {
        contents[bookcase.id] = await bookInCase(caseId: bookcase.id);
      }

      emit(state.copyWith(
        status: BookshelfStatus.success,
        bookcases: bookcases,
        currentCaseId: bookcases.first.id,
        bookcaseContents: contents,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: BookshelfStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void selectBookcase(String caseId) {
    emit(state.copyWith(currentCaseId: caseId));
  }

  Future<void> addToBookshelf(String aid) async {
    try {
      await addBookshelf(aid: aid);
      // 添加到第一个书架
      if (state.bookcases.isNotEmpty) {
        final firstCaseId = state.bookcases.first.id;
        final books = await bookInCase(caseId: firstCaseId);
        final newContents = Map<String, List<BookcaseItem>>.from(state.bookcaseContents);
        newContents[firstCaseId] = books;
        emit(state.copyWith(bookcaseContents: newContents));
      }
    } catch (e) {
      emit(state.copyWith(
        status: BookshelfStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> removeFromBookshelf(String aid) async {
    try {
      final bid = state.getBookBid(aid);
      if (bid == null) return;

      await deleteBookcase(bid: bid);
      // 重新加载所有书架内容
      final contents = <String, List<BookcaseItem>>{};
      for (final bookcase in state.bookcases) {
        contents[bookcase.id] = await bookInCase(caseId: bookcase.id);
      }
      emit(state.copyWith(bookcaseContents: contents));
    } catch (e) {
      emit(state.copyWith(
        status: BookshelfStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
} 