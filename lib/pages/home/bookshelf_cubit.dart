import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:wild/src/rust/api/wenku8.dart';
import 'package:wild/src/rust/frb_generated.dart';
import 'package:wild/src/rust/wenku8/models.dart';

enum BookshelfStatus {
  initial,
  loading,
  loaded,
  error,
}

class BookshelfState extends Equatable {
  final BookshelfStatus status;
  final List<BookshelfItem> items;
  final String? errorMessage;

  const BookshelfState({
    this.status = BookshelfStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  @override
  List<Object?> get props => [status, items, errorMessage];
}

class BookshelfCubit extends Cubit<BookshelfState> {
  BookshelfCubit() : super(const BookshelfState());

  Future<void> loadBookshelf() async {
    try {
      emit(BookshelfState(status: BookshelfStatus.loading));
      final items = await wenku8GetBookshelf();
      emit(BookshelfState(
        status: BookshelfStatus.loaded,
        items: items,
      ));
    } catch (e) {
      emit(BookshelfState(
        status: BookshelfStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
} 