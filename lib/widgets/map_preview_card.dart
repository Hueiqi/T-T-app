import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import '../providers/place_provider.dart';
import '../config/theme.dart';

class MapPreviewCard extends StatefulWidget {
  const MapPreviewCard({super.key});

  @override
  State<MapPreviewCard> createState() => _MapPreviewCardState();
}

class _MapPreviewCardState extends State<MapPreviewCard> {
  MapLibreMapController? _mapController;
  final List<Symbol> _symbols = [];
  Timer? _markerTimer;
  PlaceProvider? _placeProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newProvider = context.read<PlaceProvider>();
    if (newProvider != _placeProvider) {
      _placeProvider?.removeListener(_onPlaceChanged);
      newProvider.addListener(_onPlaceChanged);
      _placeProvider = newProvider;
    }
  }

  @override
  void initState() {
    super.initState();
    _markerTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateMarkers();
    });
  }

  @override
  void dispose() {
    _markerTimer?.cancel();
    _placeProvider?.removeListener(_onPlaceChanged);
    super.dispose();
  }

  void _onPlaceChanged() {
    if (mounted) _updateMarkers();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    if (mounted) _updateMarkers();
  }

  Future<void> _updateMarkers() async {
    if (!mounted) return;
    if (_mapController == null) return;

    final placeProvider = context.read<PlaceProvider>();
    final places = placeProvider.visitedPlaces;
    final currentPos = placeProvider.currentPosition;

    for (final symbol in _symbols) {
      await _mapController!.removeSymbol(symbol);
    }
    _symbols.clear();

    if (currentPos != null) {
      final symbol = await _mapController!.addSymbol(
        SymbolOptions(
          geometry: LatLng(currentPos.latitude, currentPos.longitude),
          iconImage: 'circle',
          iconColor: '#EF4444',
          iconSize: 1.8,
        ),
      );
      _symbols.add(symbol);
    }

    for (final place in places) {
      final symbol = await _mapController!.addSymbol(
        SymbolOptions(
          geometry: LatLng(place.latitude, place.longitude),
          iconImage: 'circle',
          iconColor: '#3B82F6',
          iconSize: 1.5,
        ),
      );
      _symbols.add(symbol);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitedPlaces = context.select((PlaceProvider p) => p.visitedPlaces);
    final currentPos = context.select((PlaceProvider p) => p.currentPosition);

    LatLng target;
    if (currentPos != null) {
      target = LatLng(currentPos.latitude, currentPos.longitude);
    } else if (visitedPlaces.isNotEmpty) {
      target = LatLng(visitedPlaces.first.latitude, visitedPlaces.first.longitude);
    } else {
      target = const LatLng(3.1390, 101.6869);
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/places'),
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 200,
                width: double.infinity,
                child: MapLibreMap(
                  onMapCreated: _onMapCreated,
                  onStyleLoadedCallback: _updateMarkers,
                  styleString: 'https://tiles.openfreemap.org/styles/positron',
                  initialCameraPosition: CameraPosition(target: target, zoom: 14),
                  myLocationEnabled: true,
                  myLocationTrackingMode: MyLocationTrackingMode.tracking,
                  compassEnabled: false,
                  logoViewMargins: const Point(0, 0),
                  attributionButtonMargins: const Point(0, 0),
                  dragEnabled: false,
                  scrollGesturesEnabled: false,
                  zoomGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          '${visitedPlaces.length} places · ${currentPos != null ? "Live" : "No GPS"}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/places'),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('View All'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
