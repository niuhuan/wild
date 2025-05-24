import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/pages/novel/novel_download_cubit.dart';

class NovelDownloadPage extends StatelessWidget {
  const NovelDownloadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NovelDownloadCubit()..loadDownloads(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('下载'),
        ),
        body: BlocBuilder<NovelDownloadCubit, NovelDownloadState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(state.error!),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<NovelDownloadCubit>().loadDownloads();
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              );
            }

            if (state.downloads.isEmpty) {
              return const Center(
                child: Text('暂无下载内容'),
              );
            }

            return ListView.builder(
              itemCount: state.downloads.length,
              itemBuilder: (context, index) {
                final download = state.downloads[index];
                return ListTile(
                  leading: Image.network(
                    download.coverUrl,
                    width: 48,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 48,
                        height: 64,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported),
                      );
                    },
                  ),
                  title: Text(download.novelName),
                  subtitle: Text(
                    '${download.downloadChapterCount}/${download.chooseChapterCount} 章节',
                  ),
                  trailing: _buildStatusIcon(download.downloadStatus),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusIcon(int status) {
    switch (status) {
      case 0: // DOWNLOAD_STATUS_NOT_DOWNLOAD
        return const Icon(Icons.download_outlined);
      case 1: // DOWNLOAD_STATUS_SUCCESS
        return const Icon(Icons.check_circle_outline, color: Colors.green);
      case 2: // DOWNLOAD_STATUS_FAILED
        return const Icon(Icons.error_outline, color: Colors.red);
      case 3: // DOWNLOAD_STATUS_DELETING
        return const Icon(Icons.delete_outline, color: Colors.orange);
      default:
        return const Icon(Icons.help_outline);
    }
  }
} 