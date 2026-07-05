import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/place_provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';
import '../widgets/custom_header.dart';

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  bool _showMap = false;
  MapLibreMapController? _mapController;
  final List<Symbol> _symbols = [];
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.user != null) {
      context.read<PlaceProvider>().setUserId(auth.user!.uid);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<PlaceProvider>().loadPlaces(auth.user!.uid);
      });
    }
    _requestLocationPermission();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Geolocator.requestPermission();
    if (!mounted) return;
    if (status == LocationPermission.denied ||
        status == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Location permission is required to track visited places.'),
        ),
      );
    }
  }

  Future<void> _clearSymbols() async {
    for (final symbol in _symbols) {
      try {
        await _mapController?.removeSymbol(symbol);
      } catch (e) {
        debugPrint('Error removing symbol: $e');
      }
    }
    _symbols.clear();
  }

  Future<void> _updateMarkers() async {
    if (_mapController == null || !_isMapReady) return;

    await _clearSymbols();

    if (!mounted) return;

    final placeProvider = context.read<PlaceProvider>();
    final places = placeProvider.visitedPlaces;
    final currentPos = placeProvider.currentPosition;

    if (currentPos != null) {
      try {
        final symbol = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: LatLng(currentPos.latitude, currentPos.longitude),
            iconImage: 'circle',
            iconColor: '#EF4444',
            iconSize: 1.8,
          ),
        );
        _symbols.add(symbol);
      } catch (e) {
        debugPrint('Error adding current position symbol: $e');
      }
    }

    for (final place in places) {
      try {
        final symbol = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: LatLng(place.latitude, place.longitude),
            iconImage: 'circle',
            iconColor: '#3B82F6',
            iconSize: 1.5,
          ),
        );
        if (!mounted) return;
        _symbols.add(symbol);
      } catch (e) {
        debugPrint('Error adding place symbol: $e');
      }
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  void _onStyleLoaded() {
    _isMapReady = true;
    _updateMarkers();
  }

  @override
  Widget build(BuildContext context) {
    final placeProvider = context.watch<PlaceProvider>();
    final places = placeProvider.visitedPlaces;
    final currentPos = placeProvider.currentPosition;

    LatLng target;
    if (currentPos != null) {
      target = LatLng(currentPos.latitude, currentPos.longitude);
    } else if (places.isNotEmpty) {
      target = LatLng(places.last.latitude, places.last.longitude);
    } else {
      target = const LatLng(3.1390, 101.6869);
    }

    return Scaffold(
      appBar: null,
      body: Column(
        children: [
          const CustomHeader(title: 'Places Visited', showBack: true),
          if (!placeProvider.hasPermission)
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_off, color: Colors.red),
                title: const Text('Location Permission Required'),
                subtitle: const Text('Grant access to track visited places.'),
                trailing: ElevatedButton(
                  onPressed: () => placeProvider.requestPermissions(),
                  child: const Text('Grant'),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: ElevatedButton.icon(
              onPressed: placeProvider.isTracking
                  ? placeProvider.stopTracking
                  : placeProvider.startTracking,
              icon: Icon(placeProvider.isTracking
                  ? Icons.stop
                  : Icons.my_location),
              label: Text(placeProvider.isTracking
                  ? 'Stop Tracking'
                  : 'Start Tracking'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('List'),
                selected: !_showMap,
                onSelected: (_) => setState(() => _showMap = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Map'),
                selected: _showMap,
                onSelected: (_) => setState(() => _showMap = true),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: IndexedStack(
              index: _showMap ? 1 : 0,
              children: [
                _buildListView(placeProvider),
                RepaintBoundary(
                  child: _buildMapView(target, currentPos),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapView(LatLng target, Position? currentPos) {
    return Stack(
      children: [
        MapLibreMap(
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          styleString: 'https://tiles.openfreemap.org/styles/positron',
          initialCameraPosition: CameraPosition(target: target, zoom: 14),
          myLocationEnabled: !kIsWeb,
          myLocationTrackingMode: !kIsWeb ? MyLocationTrackingMode.tracking : MyLocationTrackingMode.none,
          compassEnabled: false,
          rotateGesturesEnabled: false,
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            mini: true,
            onPressed: () {
              if (currentPos != null) {
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(currentPos.latitude, currentPos.longitude),
                      zoom: 15,
                    ),
                  ),
                );
              }
            },
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }

  Widget _buildListView(PlaceProvider provider) {
    final places = provider.visitedPlaces;
    final isLoading = provider.isLoading;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (places.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          const Center(
            child: Text(
              'No places logged yet.\nStay in one location for 15 minutes to log it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: places.length,
      itemBuilder: (context, index) {
        final place = places[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.place, color: AppTheme.primaryColor),
            title: Text(
              '${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Text('Visited: ${place.visitedAt.toLocal()}'),
            trailing: Text(
              _timeAgo(place.visitedAt),
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        );
      },
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
