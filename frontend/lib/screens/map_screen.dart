import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/h3_service.dart';
import '../models/location_model.dart';
import 'booking_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final H3Service _h3Service = H3Service();
  
  Position? _currentPosition;
  LocationData? _locationData;
  NearbyDriversData? _nearbyDriversData;
  
  final Set<Marker> _markers = {};
  final Set<Polygon> _polygons = {};
  final Set<Circle> _circles = {};
  
  bool _isLoading = false;
  int _resolution = 9;
  bool _showNearbyCells = false;
  bool _backendConnected = false;

  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(37.7749, -122.4194), // San Francisco
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _checkBackendConnection();
    _requestLocationPermission();
  }

  Future<void> _checkBackendConnection() async {
    final isConnected = await _h3Service.checkHealth();
    setState(() {
      _backendConnected = isConnected;
    });
    if (!isConnected) {
      _showSnackBar('⚠️ Backend not connected. Please start the Go server.');
    }
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      await _getCurrentLocation();
    } else {
      _showSnackBar('Location permission is required');
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentPosition = position;
      });

      // Move camera to current location
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 14.0,
          ),
        ),
      );

      // Get H3 cell data
      await _getH3CellData(position.latitude, position.longitude);
    } catch (e) {
      _showSnackBar('Error getting location: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getH3CellData(double lat, double lng) async {
    if (!_backendConnected) {
      _showSnackBar('Backend not connected');
      return;
    }

    final locationData = await _h3Service.getH3Cell(
      latitude: lat,
      longitude: lng,
      resolution: _resolution,
    );

    if (locationData != null) {
      setState(() {
        _locationData = locationData;
        _updateMapMarkers();
        _drawH3Cell(locationData);
      });

      if (_showNearbyCells) {
        await _getNearbyDrivers(lat, lng);
      }
    }
  }

  Future<void> _getNearbyDrivers(double lat, double lng) async {
    final nearbyData = await _h3Service.getNearbyDrivers(
      latitude: lat,
      longitude: lng,
      resolution: _resolution,
      radius: 2,
    );

    if (nearbyData != null) {
      setState(() {
        _nearbyDriversData = nearbyData;
        _drawNearbyCells();
      });
    }
  }

  void _updateMapMarkers() {
    _markers.clear();
    
    if (_currentPosition != null) {
      // User location marker
      _markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    if (_locationData != null) {
      // H3 cell center marker
      _markers.add(
        Marker(
          markerId: const MarkerId('h3_center'),
          position: LatLng(_locationData!.centerLat, _locationData!.centerLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'H3 Cell Center',
            snippet: 'Index: ${_locationData!.h3Index}',
          ),
        ),
      );
    }
  }

  void _drawH3Cell(LocationData data) {
    _polygons.clear();
    
    if (data.boundary.isNotEmpty) {
      _polygons.add(
        Polygon(
          polygonId: PolygonId(data.h3Index),
          points: data.boundary.map((coord) => LatLng(coord[0], coord[1])).toList(),
          strokeColor: Colors.blue,
          strokeWidth: 3,
          fillColor: Colors.blue.withOpacity(0.2),
        ),
      );
    }
  }

  void _drawNearbyCells() {
    _circles.clear();
    
    if (_currentPosition != null) {
      // Draw a circle around the user for visual reference
      _circles.add(
        Circle(
          circleId: const CircleId('search_radius'),
          center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          radius: 2000, // 2km radius
          strokeColor: Colors.orange,
          strokeWidth: 2,
          fillColor: Colors.orange.withOpacity(0.1),
        ),
      );
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Volkswagen H3 App'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_backendConnected ? Icons.cloud_done : Icons.cloud_off),
            onPressed: _checkBackendConnection,
            tooltip: _backendConnected ? 'Backend Connected' : 'Backend Disconnected',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _defaultPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: _markers,
            polygons: _polygons,
            circles: _circles,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onTap: (LatLng position) async {
              await _getH3CellData(position.latitude, position.longitude);
            },
          ),
          
          // Top info card
          if (_locationData != null)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: _buildInfoCard(),
            ),
          
          // Bottom controls
          Positioned(
            bottom: 20,
            left: 10,
            right: 10,
            child: _buildControlPanel(),
          ),

          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      // floatingActionButton: Column(
      //   mainAxisAlignment: MainAxisAlignment.end,
      //   children: [
      //     FloatingActionButton.extended(
      //       onPressed: () {
      //         Navigator.push(
      //           context,
      //           MaterialPageRoute(builder: (context) => const BookingScreen()),
      //         );
      //       },
      //       icon: const Icon(Icons.calendar_today),
      //       label: const Text('Book Parking'),
      //       backgroundColor: Colors.blue[700],
      //     ),
      //     const SizedBox(height: 16),
      //     FloatingActionButton(
      //       onPressed: _getCurrentLocation,
      //       child: const Icon(Icons.my_location),
      //     ),
      //   ],
      // ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      margin: const EdgeInsets.all(0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'H3 Cell Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text('Index: ${_locationData!.h3Index}'),
            Text('Resolution: ${_locationData!.resolution}'),
            Text('Center: ${_locationData!.centerLat.toStringAsFixed(6)}, ${_locationData!.centerLng.toStringAsFixed(6)}'),
            if (_nearbyDriversData != null) ...[
              const Divider(),
              Text('Nearby Cells: ${_nearbyDriversData!.totalCells}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('Resolution:'),
                Expanded(
                  child: Slider(
                    value: _resolution.toDouble(),
                    min: 7,
                    max: 12,
                    divisions: 5,
                    label: _resolution.toString(),
                    onChanged: (value) {
                      setState(() {
                        _resolution = value.toInt();
                      });
                      if (_currentPosition != null) {
                        _getH3CellData(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        );
                      }
                    },
                  ),
                ),
                Text(_resolution.toString()),
              ],
            ),
            SwitchListTile(
              title: const Text('Show Nearby Cells'),
              value: _showNearbyCells,
              onChanged: (value) {
                setState(() {
                  _showNearbyCells = value;
                });
                if (value && _currentPosition != null) {
                  _getNearbyDrivers(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  );
                } else {
                  setState(() {
                    _nearbyDriversData = null;
                    _circles.clear();
                  });
                }
              },
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}
