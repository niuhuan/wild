import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../src/rust/api/wenku8.dart';
import '../src/rust/wenku8/models.dart';

// State
abstract class RecommendState extends Equatable {
  const RecommendState();

  @override
  List<Object?> get props => [];
}

class RecommendInitial extends RecommendState {}

class RecommendLoading extends RecommendState {}

class RecommendLoaded extends RecommendState {
  final List<HomeBlock> blocks;

  const RecommendLoaded(this.blocks);

  @override
  List<Object?> get props => [blocks];
}

class RecommendError extends RecommendState {
  final String message;

  const RecommendError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
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