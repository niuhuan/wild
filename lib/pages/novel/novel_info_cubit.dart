import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/src/rust/api/wenku8.dart' as w8;

import '../../src/rust/wenku8/models.dart';

abstract class NovelInfoState {}

class NovelInfoInitial extends NovelInfoState {}

class NovelInfoLoading extends NovelInfoState {}

class NovelInfoLoaded extends NovelInfoState {
  final NovelInfo novelInfo;
  final List<Volume> volumes;

  NovelInfoLoaded({
    required this.novelInfo,
    required this.volumes,
  });
}

class NovelInfoError extends NovelInfoState {
  final String message;

  NovelInfoError(this.message);
}

class NovelInfoCubit extends Cubit<NovelInfoState> {
  final String novelId;

  NovelInfoCubit(this.novelId) : super(NovelInfoInitial());

  Future<void> load() async {
    emit(NovelInfoLoading());
    try {
      final novelInfo = await w8.novelInfo(aid: novelId);
      final volumes = await w8.novelReader(aid: novelId);
      emit(NovelInfoLoaded(
        novelInfo: novelInfo,
        volumes: volumes,
      ));
    } catch (e) {
      emit(NovelInfoError(e.toString()));
    }
  }
} 