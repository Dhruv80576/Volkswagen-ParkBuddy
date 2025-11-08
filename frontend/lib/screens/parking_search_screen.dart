import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../services/parking_service.dart';
import '../services/route_service.dart';
import '../models/parking_model.dart';
import '../models/route_model.dart';
import '../widgets/parking_bottom_sheet.dart';
import '../widgets/search_filters_sheet.dart';
import 'booking_screen.dart';

class ParkingSearchScreen extends StatefulWidget {
  const ParkingSearchScreen({super.key});

  @override
  State<ParkingSearchScreen> createState() => _ParkingSearchScreenState();
}

class _ParkingSearchScreenState extends State<ParkingSearchScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  final ParkingService _parkingService = ParkingService();
  final RouteService _routeService = RouteService();

  Position? _currentPosition;
  ParkingMatch? _selectedMatch;
  ParkingStats? _stats;
  RouteInfo? _currentRoute;
  List<RouteInfo> _alternativeRoutes = [];
  bool _isBookingConfirmed = false;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};

  bool _isSearching = false;
  bool _isLoadingRoute = false;

  // Search filters
  double _maxDistance = 5.0;
  double _maxPrice = 100.0;
  bool _requiresEV = false;
  bool _requiresHandicap = false;
  List<String> _preferredTypes = [];

  late AnimationController _animationController;

  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(10.7905, 78.7047), // Trichy
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _requestLocationPermission();
    _loadParkingStats();
    _initializePricingService();
  }
  
  Future<void> _initializePricingService() async {
    await _parkingService.checkPricingAvailability();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      await _getCurrentLocation();
    } else {
      _showSnackBar('Location permission required', isError: true);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _addUserMarker(position);
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 14.0,
          ),
        ),
      );
    } catch (e) {
      _showSnackBar('Error getting location: $e', isError: true);
    }
  }

  Future<void> _loadParkingStats() async {
    final stats = await _parkingService.getParkingStats();
    if (stats != null && mounted) {
      setState(() {
        _stats = stats;
      });
    }
  }

  void _addUserMarker(Position position) {
    _markers.add(
      Marker(
        markerId: const MarkerId('user_location'),
        position: LatLng(position.latitude, position.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Your Location'),
        zIndex: 1,
      ),
    );

    // Add search radius circle
    _circles.add(
      Circle(
        circleId: const CircleId('search_radius'),
        center: LatLng(position.latitude, position.longitude),
        radius: _maxDistance * 1000,
        strokeColor: const Color(0xFF00D563),
        strokeWidth: 2,
        fillColor: const Color(0xFF00D563).withOpacity(0.1),
      ),
    );
  }

  Future<void> _searchParking() async {
    if (_currentPosition == null) {
      _showSnackBar('Please enable location', isError: true);
      return;
    }

    setState(() {
      _isSearching = true;
      _selectedMatch = null;
    });

    _animationController.forward();

    try {
      print("latitude: ${_currentPosition!.latitude}" + "longitude: ${_currentPosition!.longitude}");
      final match = await _parkingService.searchParking(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        maxDistance: _maxDistance,
        maxPrice: _maxPrice,
        requiresEV: _requiresEV,
        requiresHandicap: _requiresHandicap,
        preferredTypes: _preferredTypes,
        priority: 1.0,
      );

      await Future.delayed(const Duration(milliseconds: 800)); // Smooth UX

      if (match != null && mounted) {
        setState(() {
          _selectedMatch = match;
          _addParkingMarker(match);
        });

        // Draw route asynchronously
        await _drawRoute(match);

        _showParkingDetails(match);
        _focusOnRoute(match);
      } else {
        _showSnackBar(
          'No parking found. Try adjusting filters.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Search failed: $e', isError: true);
    } finally {
      setState(() {
        _isSearching = false;
      });
      _animationController.reverse();
    }
  }

  void _addParkingMarker(ParkingMatch match) {
    _markers.removeWhere((m) => m.markerId.value == 'parking_slot');

    _markers.add(
      Marker(
        markerId: const MarkerId('parking_slot'),
        position: LatLng(
          match.parkingSlot.latitude,
          match.parkingSlot.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: '${match.parkingSlot.typeIcon} ${match.parkingSlot.area}',
          snippet:
              '₹${match.parkingSlot.pricePerHour.toStringAsFixed(0)}/hr • ${match.distanceText}',
        ),
        zIndex: 2,
        onTap: () => _showParkingDetails(match),
      ),
    );
  }

  Future<void> _drawRoute(ParkingMatch match) async {
    if (_currentPosition == null) return;

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      // Try to get route from Google Routes API v2 (newer and better)
      RouteInfo? route = await _routeService.getRouteV2(
        originLat: _currentPosition!.latitude,
        originLng: _currentPosition!.longitude,
        destLat: match.parkingSlot.latitude,
        destLng: match.parkingSlot.longitude,
        travelMode: 'DRIVE',
        routingPreference: 'TRAFFIC_AWARE',
      );

      // Fallback to Directions API if Routes API fails
      if (route == null) {
        route = await _routeService.getRoute(
          originLat: _currentPosition!.latitude,
          originLng: _currentPosition!.longitude,
          destLat: match.parkingSlot.latitude,
          destLng: match.parkingSlot.longitude,
          mode: 'driving',
        );
      }

      if (route != null) {
        setState(() {
          _currentRoute = route;
        });

        // Create polyline from route
        _polylines.clear();
        final polyline = await _routeService.createPolyline(
          polylineId: 'route_to_parking',
          encodedPolyline: route.encodedPolyline,
          color: const Color(0xFF1E88E5), // Blue color for route
          width: 6,
        );

        setState(() {
          _polylines.add(polyline);
        });

        // Animate camera to show the entire route
        _focusOnRoute(match);
      } else {
        // Fallback to straight line if all APIs fail
        _drawStraightLineRoute(match);
      }
    } catch (e) {
      print('Error drawing route: $e');
      _drawStraightLineRoute(match);
    } finally {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  void _drawStraightLineRoute(ParkingMatch match) {
    if (_currentPosition == null) return;

    _polylines.clear();
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: [
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          LatLng(match.parkingSlot.latitude, match.parkingSlot.longitude),
        ],
        color: const Color(0xFF000000),
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    );
  }

  void _focusOnRoute(ParkingMatch match) {
    if (_currentPosition == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        _currentPosition!.latitude < match.parkingSlot.latitude
            ? _currentPosition!.latitude
            : match.parkingSlot.latitude,
        _currentPosition!.longitude < match.parkingSlot.longitude
            ? _currentPosition!.longitude
            : match.parkingSlot.longitude,
      ),
      northeast: LatLng(
        _currentPosition!.latitude > match.parkingSlot.latitude
            ? _currentPosition!.latitude
            : match.parkingSlot.latitude,
        _currentPosition!.longitude > match.parkingSlot.longitude
            ? _currentPosition!.longitude
            : match.parkingSlot.longitude,
      ),
    );

    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  void _showParkingDetails(ParkingMatch match) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ParkingBottomSheet(
        match: match,
        route: _currentRoute,
        onConfirm: () => _confirmParking(match),
        onCancel: () => Navigator.pop(context),
        onNavigate: _currentRoute != null
            ? () => _startNavigation(match)
            : null,
      ),
    );
  }

  void _startNavigation(ParkingMatch match) {
    Navigator.pop(context); // Close bottom sheet

    // You can implement turn-by-turn navigation here
    // For now, we'll open Google Maps navigation
    _openGoogleMapsNavigation(match);
  }

  Future<void> _openGoogleMapsNavigation(ParkingMatch match) async {
    if (_currentPosition == null) return;

    try {
      // Import url_launcher package if you want to open Google Maps
      // For now, show a dialog with navigation info
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.navigation, color: Colors.blue),
              SizedBox(width: 8),
              Text('Navigation'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Navigating to ${match.parkingSlot.area}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (_currentRoute != null) ...[
                Text('Distance: ${_currentRoute!.distanceText}'),
                Text('Duration: ${_currentRoute!.durationText}'),
                const SizedBox(height: 12),
                const Text(
                  'Turn-by-turn navigation coming soon!',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // Here you can add URL launcher to open Google Maps
                // final url = 'google.navigation:q=${match.parkingSlot.latitude},${match.parkingSlot.longitude}';
                _showSnackBar('Navigation feature will open Google Maps');
              },
              icon: const Icon(Icons.map),
              label: const Text('Open Maps'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      _showSnackBar('Error opening navigation: $e', isError: true);
    }
  }

  Future<void> _confirmParking(ParkingMatch match) async {
    Navigator.pop(context);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Parking'),
        content: Text(
          'Reserve parking at ${match.parkingSlot.area} for ₹${match.parkingSlot.pricePerHour}/hr?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF000000),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _parkingService.markParkingOccupied(
        match.parkingSlot.id,
      );
      if (success && mounted) {
        setState(() {
          _isBookingConfirmed = true;
        });
        _showSnackBar('Parking reserved successfully! 🎉');
        _loadParkingStats();
        
        // Keep the route visible and show navigation options
        if (_currentRoute != null) {
          _showBookingSuccessDialog(match);
        }
      }
    }
  }

  /// Show success dialog with navigation options after booking
  Future<void> _showBookingSuccessDialog(ParkingMatch match) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Booking Confirmed!',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your parking at ${match.parkingSlot.area} has been reserved.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          match.parkingSlot.area,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.directions_car, size: 18, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        '${_currentRoute!.distanceText} • ${_currentRoute!.durationText}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.attach_money, size: 18, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        '₹${match.parkingSlot.pricePerHour}/hr',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ready to navigate to your parking?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showNavigationSteps();
            },
            icon: const Icon(Icons.navigation, size: 20),
            label: const Text('Start Navigation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
        actionsAlignment: MainAxisAlignment.spaceBetween,
      ),
    );
  }

  void _showFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SearchFiltersSheet(
        maxDistance: _maxDistance,
        maxPrice: _maxPrice,
        requiresEV: _requiresEV,
        requiresHandicap: _requiresHandicap,
        preferredTypes: _preferredTypes,
        onApply: (distance, price, ev, handicap, types) {
          setState(() {
            _maxDistance = distance;
            _maxPrice = price;
            _requiresEV = ev;
            _requiresHandicap = handicap;
            _preferredTypes = types;
            _circles.clear();
            if (_currentPosition != null) {
              _addUserMarker(_currentPosition!);
            }
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF00D563),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show turn-by-turn navigation instructions
  void _showNavigationSteps() {
    if (_currentRoute == null || _currentRoute!.steps.isEmpty) {
      _showSnackBar('No navigation steps available', isError: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.navigation, color: Color(0xFF1E88E5), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Turn-by-Turn Directions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_currentRoute!.distanceText} • ${_currentRoute!.durationText}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // Steps list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _currentRoute!.steps.length,
                  itemBuilder: (context, index) {
                    final step = _currentRoute!.steps[index];
                    return _buildNavigationStepCard(step, index + 1);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show alternative route options
  Future<void> _showRouteAlternatives() async {
    if (_currentPosition == null || _selectedMatch == null) return;

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      // Get multiple route alternatives
      final routes = await _routeService.getMultipleRoutes(
        originLat: _currentPosition!.latitude,
        originLng: _currentPosition!.longitude,
        destLat: _selectedMatch!.parkingSlot.latitude,
        destLng: _selectedMatch!.parkingSlot.longitude,
        mode: 'driving',
      );

      if (routes.isEmpty) {
        _showSnackBar('No alternative routes available', isError: true);
        return;
      }

      setState(() {
        _alternativeRoutes = routes;
      });

      if (!mounted) return;

      // Show bottom sheet with route options
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.alt_route, color: Color(0xFF1E88E5)),
                  const SizedBox(width: 12),
                  const Text(
                    'Choose Your Route',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Route options
              ...routes.asMap().entries.map((entry) {
                final index = entry.key;
                final route = entry.value;
                final isSelected = _currentRoute == route;

                return InkWell(
                  onTap: () {
                    _selectRoute(route);
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getRouteColor(index).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Route ${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getRouteColor(index),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                route.summary.isEmpty ? 'Via main roads' : route.summary,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${route.distanceText} • ${route.durationText}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: Colors.blue),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      );
    } catch (e) {
      print('Error getting alternative routes: $e');
      _showSnackBar('Failed to load alternative routes', isError: true);
    } finally {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  void _selectRoute(RouteInfo route) async {
    setState(() {
      _currentRoute = route;
      _isLoadingRoute = true;
    });

    try {
      // Create polyline for selected route
      _polylines.clear();
      final polyline = await _routeService.createPolyline(
        polylineId: 'route_to_parking',
        encodedPolyline: route.encodedPolyline,
        color: const Color(0xFF1E88E5),
        width: 6,
      );

      setState(() {
        _polylines.add(polyline);
      });

      // Animate camera to show the route
      if (_selectedMatch != null) {
        _focusOnRoute(_selectedMatch!);
      }
    } catch (e) {
      print('Error selecting route: $e');
    } finally {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  Color _getRouteColor(int index) {
    final colors = [
      const Color(0xFF1E88E5), // Blue
      const Color(0xFF43A047), // Green
      const Color(0xFFE53935), // Red
      const Color(0xFFFB8C00), // Orange
    ];
    return colors[index % colors.length];
  }

  Widget _buildNavigationStepCard(RouteStep step, int stepNumber) {
    IconData icon = Icons.arrow_upward;
    
    // Map maneuver types to icons
    switch (step.maneuver.toLowerCase()) {
      case 'turn-left':
        icon = Icons.turn_left;
        break;
      case 'turn-right':
        icon = Icons.turn_right;
        break;
      case 'turn-slight-left':
        icon = Icons.turn_slight_left;
        break;
      case 'turn-slight-right':
        icon = Icons.turn_slight_right;
        break;
      case 'turn-sharp-left':
        icon = Icons.turn_sharp_left;
        break;
      case 'turn-sharp-right':
        icon = Icons.turn_sharp_right;
        break;
      case 'uturn-left':
      case 'uturn-right':
        icon = Icons.u_turn_left;
        break;
      case 'merge':
        icon = Icons.merge;
        break;
      case 'roundabout-left':
      case 'roundabout-right':
        icon = Icons.roundabout_left;
        break;
      case 'ramp-left':
      case 'ramp-right':
        icon = Icons.ramp_left;
        break;
      case 'fork-left':
      case 'fork-right':
        icon = Icons.call_split;
        break;
      default:
        icon = Icons.arrow_upward;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number and icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$stepNumber',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E88E5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Instruction details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.instruction.isEmpty ? 'Continue straight' : step.instruction,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.straighten, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      step.distanceText,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${step.durationSeconds ~/ 60} min',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: _defaultPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: _markers,
            polylines: _polylines,
            circles: _circles,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            style: '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#f5f5f5"}]
  },
  {
    "elementType": "labels.icon",
    "stylers": [{"visibility": "off"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#616161"}]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#f5f5f5"}]
  }
]
            ''',
          ),

          // Top bar with stats
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo/Title
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Text('🅿️', style: TextStyle(fontSize: 24)),
                        SizedBox(width: 8),
                        Text(
                          'ParkBuddy',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stats
                  if (_stats != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_parking,
                            size: 16,
                            color: Color(0xFF00D563),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_stats!.availableSlots}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Text(
                            ' available',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Route info banner
          if (_currentRoute != null && _selectedMatch != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.directions,
                            color: Colors.blue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedMatch!.parkingSlot.area,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_isBookingConfirmed) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Booked',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_currentRoute!.distanceText} • ${_currentRoute!.durationText}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            if (_isBookingConfirmed) {
                              // Show confirmation dialog before clearing route
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  title: const Text('Clear Route?'),
                                  content: const Text(
                                    'Your parking is still reserved. Are you sure you want to clear the route?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        setState(() {
                                          _currentRoute = null;
                                          _selectedMatch = null;
                                          _isBookingConfirmed = false;
                                          _polylines.clear();
                                          _markers.removeWhere(
                                            (m) => m.markerId.value == 'parking_slot',
                                          );
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Clear'),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              // No booking, just clear the route
                              setState(() {
                                _currentRoute = null;
                                _selectedMatch = null;
                                _polylines.clear();
                                _markers.removeWhere(
                                  (m) => m.markerId.value == 'parking_slot',
                                );
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    if (_currentRoute!.steps.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _showNavigationSteps,
                              icon: const Icon(Icons.list, size: 18),
                              label: const Text('Directions'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E88E5),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showRouteAlternatives,
                              icon: const Icon(Icons.alt_route, size: 18),
                              label: const Text('Alternatives'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1E88E5),
                                minimumSize: const Size(0, 40),
                                side: const BorderSide(color: Color(0xFF1E88E5)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Loading indicator for route
          if (_isLoadingRoute)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Calculating best route...',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          // Search button and filters
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).padding.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                // mainAxisSize: MainAxisSize.min,
                children: [
                  // Filters row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          icon: Icons.tune,
                          label: 'Filters',
                          onTap: _showFiltersBottomSheet,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          icon: Icons.near_me,
                          label: '${_maxDistance.toStringAsFixed(0)}km',
                          isActive: true,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          icon: Icons.currency_rupee,
                          label: '₹${_maxPrice.toStringAsFixed(0)}',
                          isActive: true,
                        ),
                        if (_requiresEV) ...[
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            icon: Icons.ev_station,
                            label: 'EV',
                            isActive: true,
                          ),
                        ],
                        if (_requiresHandicap) ...[
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            icon: Icons.accessible,
                            label: 'Handicap',
                            isActive: true,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF000000),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: _isSearching ? null : _searchParking,
                      child: _isSearching
                          ? const Center(
                              child: SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  strokeWidth: 3,
                                ),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Find Parking',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  // Main search button
                  // ScaleTransition(
                  //   scale: _scaleAnimation,
                  //   child: InkWell(
                  //     onTap: _isSearching ? null : _searchParking,
                  //     child: Container(
                  //       width: double.infinity,
                  //       padding: const EdgeInsets.symmetric(vertical: 18),
                  //       decoration: BoxDecoration(
                  //         color: const Color(0xFF000000),
                  //         borderRadius: BorderRadius.circular(16),
                  //         boxShadow: [
                  //           BoxShadow(
                  //             color: Colors.black.withOpacity(0.2),
                  //             blurRadius: 15,
                  //             offset: const Offset(0, 5),
                  //           ),
                  //         ],
                  //       ),
                  //       child: _isSearching
                  //           ? const Center(
                  //               child: SizedBox(
                  //                 height: 24,
                  //                 width: 24,
                  //                 child: CircularProgressIndicator(
                  //                   valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  //                   strokeWidth: 3,
                  //                 ),
                  //               ),
                  //             )
                  //           : const Row(
                  //               mainAxisAlignment: MainAxisAlignment.center,
                  //               children: [
                  //                 Icon(Icons.search, color: Colors.black, size: 24),
                  //                 SizedBox(width: 12),
                  //                 Text(
                  //                   'Find Parking',
                  //                   style: TextStyle(
                  //                     color: Colors.black,
                  //                     fontSize: 18,
                  //                     fontWeight: FontWeight.bold,
                  //                     letterSpacing: 0.5,
                  //                   ),
                  //                 ),
                  //               ],
                  //             ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),

          // Recenter button
          Positioned(
            right: 16,
            bottom: 200,
            child: FloatingActionButton(
              heroTag: 'recenter_button',
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _getCurrentLocation,
              child: const Icon(Icons.my_location, color: Colors.black),
            ),
          ),

          // Book Parking Button
          Positioned(
            right: 16,
            bottom: 130,
            child: FloatingActionButton.extended(
              heroTag: 'book_parking_button',
              backgroundColor: Colors.blue[700],
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BookingScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.calendar_today, color: Colors.white),
              label: const Text(
                'Book',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.black : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isActive ? Colors.white : Colors.black),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
