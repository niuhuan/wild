import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

enum AutoScrollState {
  stopped,
  scrolling,
}

class AutoScrollCubit extends Cubit<AutoScrollState> {
  AutoScrollCubit() : super(AutoScrollState.stopped);

  void startScrolling() {
    emit(AutoScrollState.scrolling);
  }

  void stopScrolling() {
    emit(AutoScrollState.stopped);
  }
} 