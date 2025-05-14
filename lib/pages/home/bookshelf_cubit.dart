import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:wild/src/rust/api/wenku8.dart';
import 'package:wild/src/rust/wenku8/models.dart';

enum BookshelfStatus { initial, loading, loaded, error }

class BookshelfState extends Equatable {
  final BookshelfStatus status;
  final List<Bookcase> bookcases;
  final Map<String, List<BookcaseItem>> booksMap;
  final String? currentCaseId;
  final String? errorMessage;

  const BookshelfState({
    this.status = BookshelfStatus.initial,
    this.bookcases = const [],
    this.booksMap = const {},
    this.currentCaseId,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [status, bookcases, booksMap, currentCaseId, errorMessage];

  BookshelfState copyWith({
    BookshelfStatus? status,
    List<Bookcase>? bookcases,
    Map<String, List<BookcaseItem>>? booksMap,
    String? currentCaseId,
    String? errorMessage,
  }) {
    return BookshelfState(
      status: status ?? this.status,
      bookcases: bookcases ?? this.bookcases,
      booksMap: booksMap ?? this.booksMap,
      currentCaseId: currentCaseId,
      errorMessage: errorMessage,
    );
  }

  List<BookcaseItem>? getCurrentBooks() {
    if (currentCaseId == null) return null;
    return booksMap[currentCaseId];
  }
}

class BookshelfCubit extends Cubit<BookshelfState> {
  BookshelfCubit() : super(const BookshelfState());

  Future<void> loadBookshelf() async {
    try {
      emit(state.copyWith(status: BookshelfStatus.loading));
      
      final bookcases = await bookcaseList();
      
      final booksMap = <String, List<BookcaseItem>>{};
      for (final bookcase in bookcases) {
        try {
          final books = await bookInCase(caseId: bookcase.id);
          booksMap[bookcase.id] = books;
        } catch (e) {
          print('Failed to load bookcase ${bookcase.id}: $e');
        }
      }

      emit(state.copyWith(
        status: BookshelfStatus.loaded,
        bookcases: bookcases,
        booksMap: booksMap,
        currentCaseId: bookcases.isNotEmpty ? bookcases.first.id : null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: BookshelfStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void selectBookcase(String caseId) {
    if (state.booksMap.containsKey(caseId)) {
      emit(state.copyWith(currentCaseId: caseId));
    }
  }
} 