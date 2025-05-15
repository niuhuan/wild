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
  final Set<String> selectedBids; // 选中的书籍 bid 集合
  final bool isSelecting; // 是否处于多选模式

  BookshelfState({
    required this.status,
    required this.bookcases,
    this.currentCaseId,
    required this.bookcaseContents,
    this.errorMessage,
    this.selectedBids = const {},
    this.isSelecting = false,
  });

  BookshelfState copyWith({
    BookshelfStatus? status,
    List<Bookcase>? bookcases,
    String? currentCaseId,
    Map<String, List<BookcaseItem>>? bookcaseContents,
    String? errorMessage,
    Set<String>? selectedBids,
    bool? isSelecting,
  }) {
    return BookshelfState(
      status: status ?? this.status,
      bookcases: bookcases ?? this.bookcases,
      currentCaseId: currentCaseId ?? this.currentCaseId,
      bookcaseContents: bookcaseContents ?? this.bookcaseContents,
      errorMessage: errorMessage,
      selectedBids: selectedBids ?? this.selectedBids,
      isSelecting: isSelecting ?? this.isSelecting,
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

  bool isBookSelected(String bid) => selectedBids.contains(bid);
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

  void toggleSelectMode() {
    emit(state.copyWith(
      isSelecting: !state.isSelecting,
      selectedBids: state.isSelecting ? {} : state.selectedBids,
    ));
  }

  void toggleBookSelection(String bid) {
    final newSelectedBids = Set<String>.from(state.selectedBids);
    if (newSelectedBids.contains(bid)) {
      newSelectedBids.remove(bid);
    } else {
      newSelectedBids.add(bid);
    }
    emit(state.copyWith(selectedBids: newSelectedBids));
  }

  Future<void> moveSelectedBooks(String toBookcaseId) async {
    if (state.selectedBids.isEmpty || state.currentCaseId == null) return;

    try {
      await moveBookcase(
        bidList: state.selectedBids.toList(),
        fromBookcaseId: state.currentCaseId!,
        toBookcaseId: toBookcaseId,
      );

      // 刷新源书架
      final fromBooks = await bookInCase(caseId: state.currentCaseId!);
      final newContents = Map<String, List<BookcaseItem>>.from(state.bookcaseContents);
      newContents[state.currentCaseId!] = fromBooks;

      // 如果目标不是删除（-1），则刷新目标书架
      if (toBookcaseId != '-1') {
        final toBooks = await bookInCase(caseId: toBookcaseId);
        newContents[toBookcaseId] = toBooks;
      }

      emit(state.copyWith(
        bookcaseContents: newContents,
        selectedBids: {},
        isSelecting: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: BookshelfStatus.error,
        errorMessage: e.toString(),
      ));
    }
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