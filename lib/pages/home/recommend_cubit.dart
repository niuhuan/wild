import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/src/rust/api/wenku8.dart';
import 'package:wild/src/rust/wenku8/models.dart';

abstract class RecommendState {}

class RecommendInitial extends RecommendState {}

class RecommendLoading extends RecommendState {}

class RecommendLoaded extends RecommendState {
  final List<HomeBlock> blocks;

  RecommendLoaded(this.blocks);
}

class RecommendError extends RecommendState {
  final String message;

  RecommendError(this.message);
}

class RecommendCubit extends Cubit<RecommendState> {
  RecommendCubit() : super(RecommendInitial());

  Future<void> load() async {
    emit(RecommendLoading());
    try {
      final blocks = await index();
      emit(RecommendLoaded(blocks));
    } catch (e) {
      emit(RecommendError(e.toString()));
    }
  }
} 