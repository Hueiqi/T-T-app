import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Turns coordinates into a human-readable street/area label using Nominatim
/// (OpenStreetMap's free reverse geocoder) — the same data family behind the
/// OpenFreeMap tiles the app already renders, so no extra API key is needed.
///
/// Nominatim's usage policy requires an identifying User-Agent and allows at
/// most ~1 request/second, so lookups are throttled and cached per ~100 m
/// grid cell. During a run that means roughly one request per block, not one
/// per GPS tick.
class ReverseGeocodeService {
  static const String _endpoint = 'https://nominatim.openstreetmap.org/reverse';

  static const Map<String, String> _headers = {
    'User-Agent': 'TnTFitness/1.0 (https://github.com/Hueiqi/T-T-app)',
  };

  /// Nominatim asks for no more than one request per second.
  static const Duration _minInterval = Duration(seconds: 2);

  final Map<String, StreetInfo> _cache = {};
  DateTime? _lastRequest;
  String? _inFlightKey;

  /// ~3 decimal places ≈ 110 m, so we only re-query when the runner has
  /// actually moved a meaningful distance.
  String _cellKey(double lat, double lon) =>
      '${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)}';

  /// Returns a cached result immediately when available, otherwise fetches.
  /// Returns null if throttled or on failure — callers should keep showing
  /// whatever label they already had rather than flicker to empty.
  Future<StreetInfo?> lookup(double lat, double lon) async {
    final key = _cellKey(lat, lon);

    final cached = _cache[key];
    if (cached != null) return cached;

    // Avoid stacking duplicate requests for the same cell.
    if (_inFlightKey == key) return null;

    final now = DateTime.now();
    if (_lastRequest != null && now.difference(_lastRequest!) < _minInterval) {
      return null;
    }

    _inFlightKey = key;
    _lastRequest = now;

    try {
      final uri = Uri.parse(
        '$_endpoint?format=jsonv2&lat=$lat&lon=$lon&zoom=17&addressdetails=1',
      );
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final address = body['address'] as Map<String, dynamic>? ?? {};

      final street = (address['road'] ??
              address['pedestrian'] ??
              address['footway'] ??
              address['path'] ??
              address['cycleway'] ??
              address['residential']) as String?;

      final area = (address['suburb'] ??
              address['neighbourhood'] ??
              address['quarter'] ??
              address['village'] ??
              address['town'] ??
              address['city_district']) as String?;

      final city =
          (address['city'] ?? address['town'] ?? address['state']) as String?;

      final info = StreetInfo(
        street: street,
        area: area,
        city: city,
      );
      _cache[key] = info;
      return info;
    } catch (e) {
      debugPrint('ReverseGeocode failed: $e');
      return null;
    } finally {
      _inFlightKey = null;
    }
  }
}

class StreetInfo {
  final String? street;
  final String? area;
  final String? city;

  const StreetInfo({this.street, this.area, this.city});

  /// e.g. "Jalan Damansara" — the headline the runner reads at a glance.
  String get primary => street ?? area ?? city ?? 'Unknown road';

  /// e.g. "Bangsar, Kuala Lumpur" — context under the street name.
  String get secondary {
    final parts = <String>[];
    if (street != null && area != null) parts.add(area!);
    if (city != null && city != area) parts.add(city!);
    return parts.join(', ');
  }

  bool get isEmpty => street == null && area == null && city == null;
}
