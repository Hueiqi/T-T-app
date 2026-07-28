import 'dart:convert';
import 'package:http/http.dart' as http;

class FoodApiService {
  static const String baseUrl = 'https://world.openfoodfacts.org/api/v0/product/';
  static const String searchUrl = 'https://world.openfoodfacts.org/cgi/search.pl';

  /// Open Food Facts rejects requests from unidentified clients with HTTP 503.
  /// The `http` package's default agent ("Dart/x.y (dart:io)") is blocked, so
  /// every request must send an identifying User-Agent per their API policy.
  static const Map<String, String> _headers = {
    'User-Agent': 'TnTFitness/1.0 (https://github.com/Hueiqi/T-T-app)',
  };

  /// Open Food Facts intermittently answers 503 ("Page temporarily
  /// unavailable") when under load, even for queries that have thousands of
  /// matches. Retrying briefly turns most of those transient failures into
  /// results instead of surfacing "search failed" to the user.
  static Future<http.Response> _getWithRetry(Uri uri) async {
    const maxAttempts = 3;
    http.Response? response;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      response = await http.get(uri, headers: _headers);
      if (response.statusCode != 503) return response;
      if (attempt < maxAttempts) {
        await Future.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    return response!;
  }

  /// Search for products by name (returns a list of product names & barcodes).
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final uri = Uri.parse(
      '$searchUrl?search_terms=${Uri.encodeQueryComponent(query)}'
      '&search_simple=1&action=process&json=1&page_size=20',
    );
    final response = await _getWithRetry(uri);
    if (response.statusCode != 200) {
      throw Exception('Search unavailable (HTTP ${response.statusCode})');
    }
    final json = jsonDecode(response.body);
    final products = json['products'] as List? ?? [];
    return products.map((p) => {
      'name': p['product_name'] ?? 'Unknown',
      'barcode': p['code'] ?? '',
      'image': p['image_front_url'] ?? '',
    }).toList();
  }

  /// Get full product details (including nutrition) by barcode.
  Future<Map<String, dynamic>> getProductByBarcode(String barcode) async {
    final uri = Uri.parse('$baseUrl$barcode.json');
    final response = await _getWithRetry(uri);
    if (response.statusCode != 200) throw Exception('Product not found');
    final json = jsonDecode(response.body);
    if (json['status'] != 1) throw Exception('Product not found');
    final product = json['product'] as Map<String, dynamic>;
    return _extractNutrition(product);
  }

  Map<String, dynamic> _extractNutrition(Map<String, dynamic> product) {
    final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};
    return {
      'name': product['product_name'] ?? 'Unknown',
      'brand': product['brands'] ?? '',
      'image': product['image_front_url'] ?? '',
      'calories': (nutriments['energy-kcal_100g'] ?? nutriments['energy_100g'] ?? 0).toDouble(),
      'protein': (nutriments['proteins_100g'] ?? 0).toDouble(),
      'carbs': (nutriments['carbohydrates_100g'] ?? 0).toDouble(),
      'fat': (nutriments['fat_100g'] ?? 0).toDouble(),
      'fiber': (nutriments['fiber_100g'] ?? 0).toDouble(),
      'sugar': (nutriments['sugars_100g'] ?? 0).toDouble(),
      'sodium': (nutriments['sodium_100g'] ?? 0).toDouble(),
      'servingSize': (nutriments['serving_size'] ?? 100).toDouble(),
    };
  }
}