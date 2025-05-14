import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:wild/src/rust/api/wenku8.dart';
import 'package:wild/src/rust/wenku8/models.dart';

enum BookshelfStatus { initial, loading, loaded, error }

class BookshelfState extends Equatable {
  final BookshelfStatus status;
  final List<Bookcase> bookcases;
  final String? currentCaseId;
  final List<BookcaseItem>? currentBooks;
  final String? errorMessage;

  const BookshelfState({
    this.status = BookshelfStatus.initial,
    this.bookcases = const [],
    this.currentCaseId,
    this.currentBooks,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [status, bookcases, currentCaseId, currentBooks, errorMessage];

  BookshelfState copyWith({
    BookshelfStatus? status,
    List<Bookcase>? bookcases,
    String? currentCaseId,
    List<BookcaseItem>? currentBooks,
    String? errorMessage,
  }) {
    return BookshelfState(
      status: status ?? this.status,
      bookcases: bookcases ?? this.bookcases,
      currentCaseId: currentCaseId,
      currentBooks: currentBooks,
      errorMessage: errorMessage,
    );
  }
}

class BookshelfCubit extends Cubit<BookshelfState> {
  BookshelfCubit() : super(const BookshelfState());

  Future<void> loadBookshelf() async {
    try {
      emit(state.copyWith(status: BookshelfStatus.loading));
      final bookcases = await bookcaseList();
      emit(state.copyWith(
        status: BookshelfStatus.loaded,
        bookcases: bookcases,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: BookshelfStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> loadBookcaseContent(String caseId) async {
    try {
      final books = await bookInCase(caseId: caseId);
      emit(state.copyWith(
        currentCaseId: caseId,
        currentBooks: books,
      ));
    } catch (e) {
      emit(state.copyWith(
        errorMessage: e.toString(),
      ));
    }
  }
} 