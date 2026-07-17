import 'dart:convert';
import 'package:http/http.dart' as http;

class FoodApiService {
  static const String baseUrl = 'https://world.openfoodfacts.org/api/v0/product/';
  static const String searchUrl = 'https://world.openfoodfacts.org/cgi/search.pl';

  /// Search for products by name (returns a list of product names & barcodes).
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final uri = Uri.parse(
      '$searchUrl?search_terms=$query&search_simple=1&action=process&json=1&page_size=20',
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('Search failed');
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
    final response = await http.get(uri);
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