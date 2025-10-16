/// Job Location Picker Widget
///
/// PURPOSE:
/// Interactive map picker for setting job site locations
/// Integrates with Google Places API for address autocomplete
///
/// FEATURES:
/// - Google Maps with draggable marker
/// - Address search with autocomplete
/// - Geocoding (address ↔ coordinates)
/// - Save location as GeoPoint
/// - Show accuracy circle
///
/// HAIKU TODO:
/// - Add google_maps_flutter dependency
/// - Implement Google Places autocomplete
/// - Add geocoding Cloud Function
/// - Wire up marker drag events
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sierra_painting/design/tokens.dart';

class JobLocationPicker extends StatefulWidget {
  final GeoPoint? initialLocation;
  final String? initialAddress;
  final Function(GeoPoint location, String address) onLocationSelected;

  const JobLocationPicker({
    super.key,
    this.initialLocation,
    this.initialAddress,
    required this.onLocationSelected,
  });

  @override
  State<JobLocationPicker> createState() => _JobLocationPickerState();
}

class _JobLocationPickerState extends State<JobLocationPicker> {
  late TextEditingController _searchController;
  late GoogleMapController _mapController;
  GeoPoint? _selectedLocation;
  String? _selectedAddress;
  bool _isSearching = false;

  // Marker and circle for map visualization
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  // Default center (San Francisco)
  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(37.7749, -122.4194),
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialAddress);
    _selectedLocation = widget.initialLocation;
    _selectedAddress = widget.initialAddress;

    // Initialize map with location if provided
    if (widget.initialLocation != null) {
      _updateMarkerAndCircle(widget.initialLocation!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Job Location'),
        actions: [
          TextButton(
            onPressed: _selectedLocation == null ? null : _handleSave,
            child: const Text('SAVE'),
          ),
        ],
      ),
      body: Column(
        children: [
          // HAIKU TODO: Address search bar with autocomplete
          _buildSearchBar(),

          // HAIKU TODO: Google Map widget
          Expanded(child: _buildMapPlaceholder()),

          // HAIKU TODO: Selected location info card
          if (_selectedLocation != null) _buildLocationInfo(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spaceMD),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search for address...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _isSearching
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        DesignTokens.dsierraRed,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: () {
                    // Could integrate with geolocator here
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Current location feature coming soon'),
                      ),
                    );
                  },
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            _geocodeAddress(value);
          }
        },
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    return GoogleMap(
      onMapCreated: (controller) {
        _mapController = controller;
      },
      initialCameraPosition: widget.initialLocation != null
          ? CameraPosition(
              target: LatLng(
                widget.initialLocation!.latitude,
                widget.initialLocation!.longitude,
              ),
              zoom: 16,
            )
          : _defaultPosition,
      markers: _markers,
      circles: _circles,
      onTap: (LatLng latLng) {
        // Allow tapping on map to set location
        final geopoint = GeoPoint(latLng.latitude, latLng.longitude);
        setState(() {
          _selectedLocation = geopoint;
          _updateMarkerAndCircle(geopoint);
        });
        _reverseGeocodeLocation(geopoint);
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
    );
  }

  /// Update marker and geofence circle visualization
  void _updateMarkerAndCircle(GeoPoint location) {
    final latLng = LatLng(location.latitude, location.longitude);

    setState(() {
      // Update marker (draggable)
      _markers = {
        Marker(
          markerId: const MarkerId('job-location'),
          position: latLng,
          draggable: true,
          infoWindow: const InfoWindow(title: 'Job Location'),
          onDragEnd: (newPosition) {
            final geopoint = GeoPoint(newPosition.latitude, newPosition.longitude);
            setState(() {
              _selectedLocation = geopoint;
            });
            _reverseGeocodeLocation(geopoint);
          },
        ),
      };

      // Add geofence circle (75 meter radius)
      _circles = {
        Circle(
          circleId: const CircleId('geofence'),
          center: latLng,
          radius: 75, // meters
          fillColor: DesignTokens.dsierraRed.withValues(alpha: 0.1),
          strokeColor: DesignTokens.dsierraRed,
          strokeWidth: 2,
        ),
      };
    });
  }

  /// Reverse geocode coordinates to get address
  Future<void> _reverseGeocodeLocation(GeoPoint location) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('geocodeAddress')
          .call({
            'lat': location.latitude,
            'lng': location.longitude,
            'reverse': true,
          });

      if (mounted) {
        setState(() {
          _selectedAddress = result.data['formattedAddress'] as String?;
          _searchController.text = _selectedAddress ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    }
  }

  Widget _buildLocationInfo() {
    return Card(
      margin: const EdgeInsets.all(DesignTokens.spaceMD),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected Location',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (_selectedAddress != null)
              Text(_selectedAddress!),
            const SizedBox(height: 4),
            Text(
              'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, '
              'Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// Geocode address string to coordinates
  Future<void> _geocodeAddress(String address) async {
    setState(() => _isSearching = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('geocodeAddress')
          .call({
            'address': address,
          });

      final geopoint = GeoPoint(
        result.data['lat'] as double,
        result.data['lng'] as double,
      );

      if (mounted) {
        setState(() {
          _selectedLocation = geopoint;
          _selectedAddress = result.data['formattedAddress'] as String?;
          _updateMarkerAndCircle(geopoint);
        });

        // Animate camera to new location
        await _mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(geopoint.latitude, geopoint.longitude),
              zoom: 16,
            ),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location found')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Could not find location'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Error geocoding address: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _handleSave() {
    if (_selectedLocation != null && _selectedAddress != null) {
      widget.onLocationSelected(_selectedLocation!, _selectedAddress!);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }
}
