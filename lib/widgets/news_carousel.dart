import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/news_article.dart';
import '../providers/news_provider.dart';
import '../config/theme.dart';

class NewsCarousel extends StatelessWidget {
  const NewsCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NewsProvider>(
      builder: (context, newsProvider, _) {
        final articles = newsProvider.articles;
        final isLoading = newsProvider.isLoading;
        final error = newsProvider.error;

        if (isLoading && articles.isEmpty) {
          return const Card(
            child: SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (error != null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.errorColor),
                  const SizedBox(height: 8),
                  const Text(
                    'Could not load health news',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    error,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => newsProvider.fetchNews(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (articles.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No health news available right now.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                'Health News',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              height: 260,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: articles.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final article = articles[index];
                  return _NewsCard(article: article);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsArticle article;
  const _NewsCard({required this.article});

  Future<void> _openArticle() async {
    final url = Uri.parse(article.url);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: _openArticle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: article.imageUrl.isNotEmpty
                    ? Image.network(
                        article.imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, size: 40),
                        ),
                        loadingBuilder: (_, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        child: const Icon(Icons.health_and_safety, size: 40),
                      ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            article.sourceName,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            article.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            article.description,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _timeAgo(article.publishedAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) return '${diff.inDays ~/ 7}w ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'now';
  }
}
