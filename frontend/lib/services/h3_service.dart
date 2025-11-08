import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/location_model.dart';
import '../config/app_config.dart';

class H3Service {
  // Backend URL from configuration
  static String baseUrl = AppConfig.backendUrl;
  
  // Method to update base URL dynamically if needed
  static void setBaseUrl(String url) {
    baseUrl = url;
  }
  
  // For Android Emulator, use: http://10.0.2.2:8080
  // For iOS Simulator, use: http://localhost:8080
  // For physical device, use your computer's IP: http://192.168.x.x:8080

  /// Get H3 cell information for a given location
  Future<LocationData?> getH3Cell({
    required double latitude,
    required double longitude,
    int resolution = 9,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/location/h3'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'resolution': resolution,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return LocationData.fromJson(data);
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting H3 cell: $e');
      return null;
    }
  }

  /// Get nearby cells for finding drivers
  Future<NearbyDriversData?> getNearbyDrivers({
    required double latitude,
    required double longitude,
    int resolution = 9,
    int radius = 2,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/location/nearby'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'resolution': resolution,
          'radius': radius,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return NearbyDriversData.fromJson(data);
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting nearby drivers: $e');
      return null;
    }
  }

  /// Get H3 cell boundary
  Future<Map<String, dynamic>?> getH3Boundary(String h3Index) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/h3/boundary/$h3Index'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting H3 boundary: $e');
      return null;
    }
  }

  /// Check backend health
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      print('Backend health check failed: $e');
      return false;
    }
  }
}
