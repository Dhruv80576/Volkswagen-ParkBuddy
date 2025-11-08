import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../config/app_config.dart';
import '../models/route_model.dart';

class RouteService {
  final String _apiKey = AppConfig.googleMapsApiKey;
  final PolylinePoints _polylinePoints = PolylinePoints();

  /// Get route using Google Routes API (newer, more powerful)
  /// This is the recommended API for new implementations
  Future<RouteInfo?> getRouteV2({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String travelMode = 'DRIVE',
    bool computeAlternativeRoutes = false,
    String routingPreference = 'TRAFFIC_AWARE',
  }) async {
    try {
      final url = Uri.parse(
        'https://routes.googleapis.com/directions/v2:computeRoutes',
      );

      final body = jsonEncode({
        'origin': {
          'location': {
            'latLng': {
              'latitude': originLat,
              'longitude': originLng,
            }
          }
        },
        'destination': {
          'location': {
            'latLng': {
              'latitude': destLat,
              'longitude': destLng,
            }
          }
        },
        'travelMode': travelMode,
        'routingPreference': routingPreference,
        'computeAlternativeRoutes': computeAlternativeRoutes,
        'routeModifiers': {
          'avoidTolls': false,
          'avoidHighways': false,
          'avoidFerries': false,
        },
        'languageCode': 'en-US',
        'units': 'METRIC',
      });

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs,routes.description',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          print("Routes API: Route found successfully");
          return RouteInfo.fromRoutesApiJson(data['routes'][0]);
        } else {
          print('Routes API: No routes found');
        }
      } else {
        print('Routes API Error: ${response.statusCode} - ${response.body}');
        // Fallback to Directions API
        return getRoute(
          originLat: originLat,
          originLng: originLng,
          destLat: destLat,
          destLng: destLng,
        );
      }
      return null;
    } catch (e) {
      print('Error getting route v2: $e');
      // Fallback to Directions API
      return getRoute(
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
      );
    }
  }

  /// Get route from origin to destination using Google Directions API
  /// Fallback method for compatibility
  Future<RouteInfo?> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String mode = 'driving',
    bool alternatives = false,
  }) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$originLat,$originLng'
        '&destination=$destLat,$destLng'
        '&mode=$mode'
        '&alternatives=${alternatives ? 'true' : 'false'}'
        '&key=$_apiKey'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'OK' && data['routes'] != null && data['routes'].isNotEmpty) {
          return RouteInfo.fromJson(data['routes'][0]);
        } else {
          print('Directions API Error: ${data['status']}');
          if (data['error_message'] != null) {
            print('Error message: ${data['error_message']}');
          }
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      print('Error getting route: $e');
      return null;
    }
  }

  /// Get route with waypoints
  Future<RouteInfo?> getRouteWithWaypoints({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required List<LatLng> waypoints,
    String mode = 'driving',
  }) async {
    try {
      final waypointsStr = waypoints
          .map((point) => '${point.latitude},${point.longitude}')
          .join('|');

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$originLat,$originLng'
        '&destination=$destLat,$destLng'
        '&waypoints=$waypointsStr'
        '&mode=$mode'
        '&key=$_apiKey'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'OK' && data['routes'] != null && data['routes'].isNotEmpty) {
          return RouteInfo.fromJson(data['routes'][0]);
        }
      }
      return null;
    } catch (e) {
      print('Error getting route with waypoints: $e');
      return null;
    }
  }

  /// Decode polyline string to list of LatLng points
  Future<List<LatLng>> decodePolyline(String encodedPolyline) async {
    try {
      List<PointLatLng> result = _polylinePoints.decodePolyline(encodedPolyline);
      return result.map((point) => LatLng(point.latitude, point.longitude)).toList();
    } catch (e) {
      print('Error decoding polyline: $e');
      return [];
    }
  }

  /// Create a Polyline object from route info
  Future<Polyline> createPolyline({
    required String polylineId,
    required String encodedPolyline,
    Color color = Colors.black,
    int width = 5,
    List<PatternItem>? patterns,
  }) async {
    final points = await decodePolyline(encodedPolyline);
    
    return Polyline(
      polylineId: PolylineId(polylineId),
      points: points,
      color: color,
      width: width,
      patterns: patterns ?? [],
      geodesic: true,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    );
  }

  /// Get multiple route options
  Future<List<RouteInfo>> getMultipleRoutes({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String mode = 'driving',
  }) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$originLat,$originLng'
        '&destination=$destLat,$destLng'
        '&mode=$mode'
        '&alternatives=true'
        '&key=$_apiKey'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'OK' && data['routes'] != null) {
          return (data['routes'] as List)
              .map((route) => RouteInfo.fromJson(route))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getting multiple routes: $e');
      return [];
    }
  }

  /// Calculate distance between two points (Haversine formula)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(_degreesToRadians(lat1)) *
            Math.cos(_degreesToRadians(lat2)) *
            Math.sin(dLon / 2) *
            Math.sin(dLon / 2);
    
    final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * Math.pi / 180;
  }
}

// Simple Math class for trigonometric functions
class Math {
  static const double pi = 3.14159265358979323846;
  
  static double sin(double x) => x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  static double cos(double x) => 1 - (x * x) / 2 + (x * x * x * x) / 24;
  static double sqrt(double x) {
    if (x == 0) return 0;
    double guess = x;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
  static double atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + pi;
    if (x < 0 && y < 0) return _atan(y / x) - pi;
    if (x == 0 && y > 0) return pi / 2;
    if (x == 0 && y < 0) return -pi / 2;
    return 0;
  }
  static double _atan(double x) {
    if (x.abs() <= 1) {
      return x - (x * x * x) / 3 + (x * x * x * x * x) / 5;
    }
    return pi / 2 - _atan(1 / x);
  }
}
