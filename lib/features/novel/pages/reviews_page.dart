import 'package:flutter/material.dart';
import 'package:wild/src/rust/api/wenku8.dart';
import 'package:wild/src/rust/wenku8/models.dart';
import 'package:wild/widgets/cached_image.dart' show CachedImage;
import 'package:intl/intl.dart';

class ReviewsPage extends StatefulWidget {
  final String aid;
  final String title;

  const ReviewsPage({
    super.key,
    required this.aid,
    required this.title,
  });

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  PageStatsReviews? _currentPage;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReviews(refresh: true);
  }

  Future<void> _loadReviews({bool refresh = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      if (refresh) {
        _currentPage = null;
        _errorMessage = null;
      }
    });

    try {
      final page = await reviews(
        aid: widget.aid,
        pageNumber: refresh ? 1 : (_currentPage?.currentPage ?? 0) + 1,
      );
      setState(() {
        if (refresh) {
          _currentPage = page;
        } else {
          _currentPage = PageStatsReviews(
            currentPage: page.currentPage,
            maxPage: page.maxPage,
            records: [..._currentPage!.records, ...page.records],
          );
        }
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title} - 评论'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadReviews(refresh: true),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_currentPage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentPage!.records.isEmpty) {
      return const Center(child: Text('暂无评论'));
    }

    return RefreshIndicator(
      onRefresh: () => _loadReviews(refresh: true),
      child: ListView.builder(
        itemCount: _currentPage!.records.length + (_currentPage!.currentPage < _currentPage!.maxPage ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _currentPage!.records.length) {
            if (!_isLoading && _currentPage!.currentPage < _currentPage!.maxPage) {
              Future.microtask(() => _loadReviews());
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return const SizedBox.shrink();
          }

          final review = _currentPage!.records[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        child: const Icon(Icons.person),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              review.uname,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              review.time,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    review.content,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
} 
