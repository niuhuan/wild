import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/pages/novel/novel_download_cubit.dart';
import 'package:wild/widgets/cached_image.dart';
import 'package:wild/pages/novel/novel_download_info_page.dart';

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
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NovelDownloadInfoPage(
                            novelId: download.novelId,
                          ),
                        ),
                      );
                      if (context.mounted) {
                        context.read<NovelDownloadCubit>().loadDownloads();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedImage(
                              url: download.coverUrl,
                              width: 80,
                              height: 120,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  download.novelName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  download.author,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.book_outlined,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${download.downloadChapterCount}/${download.chooseChapterCount} 章节',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.download_outlined,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getStatusText(download.downloadStatus),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _getStatusColor(download.downloadStatus),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusIcon(download.downloadStatus),
                        ],
                      ),
                    ),
                  ),
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

  String _getStatusText(int status) {
    switch (status) {
      case 0: // DOWNLOAD_STATUS_NOT_DOWNLOAD
        return '等待下载';
      case 1: // DOWNLOAD_STATUS_SUCCESS
        return '下载完成';
      case 2: // DOWNLOAD_STATUS_FAILED
        return '下载失败';
      case 3: // DOWNLOAD_STATUS_DELETING
        return '正在删除';
      default:
        return '未知状态';
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0: // DOWNLOAD_STATUS_NOT_DOWNLOAD
        return Colors.blue;
      case 1: // DOWNLOAD_STATUS_SUCCESS
        return Colors.green;
      case 2: // DOWNLOAD_STATUS_FAILED
        return Colors.red;
      case 3: // DOWNLOAD_STATUS_DELETING
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
} 