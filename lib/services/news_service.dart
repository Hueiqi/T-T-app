import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';
import '../models/news_article.dart';

class NewsService {
  static const String _apiKey = ApiKeys.newsApi;
  static const String _baseUrl = 'https://newsapi.org/v2/top-headlines';

  Future<List<NewsArticle>> fetchHealthNews({int pageSize = 10}) async {
    final url = Uri.parse(
      '$_baseUrl?category=health&language=en&pageSize=$pageSize&apiKey=$_apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final articles = data['articles'] as List? ?? [];
        return articles
            .map((json) => NewsArticle.fromJson(json))
            .where((a) => a.title != '[Removed]')
            .toList();
      } else {
        throw Exception('Failed to fetch news: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
