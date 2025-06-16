import 'package:flutter_bloc/flutter_bloc.dart';

class AutoScrollCubit extends Cubit<bool> {
  AutoScrollCubit() : super(false);

  void toggle() => emit(!state);
  void start() => emit(true);
  void stop() => emit(false);
} 