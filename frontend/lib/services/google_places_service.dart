import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:volkswagen_hck/config/app_config.dart';
import '../models/booking_model.dart';

class GooglePlacesService {
  // TODO: Replace with your Google Places API key
  // Get it from: https://console.cloud.google.com/
  static const String _apiKey = AppConfig.googleMapsApiKey;
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';

  /// Search for places using text query
  /// 
  /// Example: searchPlaces("Bandra West Mumbai")
  Future<List<PlaceSearchResult>> searchPlaces(String query) async {
    if (_apiKey == 'YOUR_GOOGLE_PLACES_API_KEY') {
      print('⚠️ Google Places API key not configured');
      return _getMockPlaces(query);
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/place/textsearch/json?query=$query&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          return results
              .map((place) => PlaceSearchResult.fromJson(place))
              .toList();
        } else {
          print('Places API error: ${data['status']}');
          return [];
        }
      } else {
        print('HTTP error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error searching places: $e');
      return [];
    }
  }

  /// Search for places nearby a location
  /// 
  /// radius: in meters (default 1000m = 1km)
  Future<List<PlaceSearchResult>> searchNearbyPlaces({
    required double latitude,
    required double longitude,
    int radius = 1000,
    String? type,
    String? keyword,
  }) async {
    if (_apiKey == 'YOUR_GOOGLE_PLACES_API_KEY') {
      print('⚠️ Google Places API key not configured');
      return _getMockNearbyPlaces(latitude, longitude);
    }

    try {
      var url = '$_baseUrl/place/nearbysearch/json?'
          'location=$latitude,$longitude'
          '&radius=$radius'
          '&key=$_apiKey';

      if (type != null) {
        url += '&type=$type';
      }

      if (keyword != null) {
        url += '&keyword=$keyword';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          return results
              .map((place) => PlaceSearchResult.fromJson(place))
              .toList();
        } else {
          print('Places API error: ${data['status']}');
          return [];
        }
      } else {
        print('HTTP error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error searching nearby places: $e');
      return [];
    }
  }

  /// Get place details by place ID
  Future<PlaceSearchResult?> getPlaceDetails(String placeId) async {
    if (_apiKey == 'YOUR_GOOGLE_PLACES_API_KEY') {
      print('⚠️ Google Places API key not configured');
      return null;
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/place/details/json?place_id=$placeId&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          return PlaceSearchResult.fromJson(data['result']);
        } else {
          print('Place details error: ${data['status']}');
          return null;
        }
      } else {
        print('HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting place details: $e');
      return null;
    }
  }

  /// Autocomplete place predictions
  Future<List<Map<String, dynamic>>> getAutocompletePredictions(
    String input, {
    double? latitude,
    double? longitude,
    int radius = 50000, // 50km
  }) async {
    if (_apiKey == 'YOUR_GOOGLE_PLACES_API_KEY') {
      print('⚠️ Google Places API key not configured');
      return _getMockAutocomplete(input);
    }

    try {
      var url = '$_baseUrl/place/autocomplete/json?'
          'input=$input'
          '&key=$_apiKey';

      if (latitude != null && longitude != null) {
        url += '&location=$latitude,$longitude&radius=$radius';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          return List<Map<String, dynamic>>.from(data['predictions']);
        } else {
          print('Autocomplete error: ${data['status']}');
          return [];
        }
      } else {
        print('HTTP error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error in autocomplete: $e');
      return [];
    }
  }

  // Mock data for testing without API key
  List<PlaceSearchResult> _getMockPlaces(String query) {
    return [
      PlaceSearchResult(
        placeId: 'mock-1',
        name: 'Bandra West, Mumbai',
        address: 'Bandra West, Mumbai, Maharashtra, India',
        latitude: 19.0596,
        longitude: 72.8295,
        vicinity: 'Bandra West',
        types: ['locality', 'political'],
      ),
      PlaceSearchResult(
        placeId: 'mock-2',
        name: 'Phoenix Marketcity, Mumbai',
        address: 'Kamani Junction, LBS Marg, Kurla West, Mumbai',
        latitude: 19.0883,
        longitude: 72.8914,
        vicinity: 'Kurla West',
        types: ['shopping_mall', 'point_of_interest'],
      ),
      PlaceSearchResult(
        placeId: 'mock-3',
        name: 'Chhatrapati Shivaji Maharaj International Airport',
        address: 'Mumbai Airport, Andheri East, Mumbai',
        latitude: 19.0896,
        longitude: 72.8656,
        vicinity: 'Andheri East',
        types: ['airport', 'point_of_interest'],
      ),
    ];
  }

  List<PlaceSearchResult> _getMockNearbyPlaces(double lat, double lng) {
    return [
      PlaceSearchResult(
        placeId: 'nearby-1',
        name: 'Nearby Location 1',
        address: 'Near ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
        latitude: lat + 0.001,
        longitude: lng + 0.001,
      ),
      PlaceSearchResult(
        placeId: 'nearby-2',
        name: 'Nearby Location 2',
        address: 'Near ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
        latitude: lat - 0.001,
        longitude: lng - 0.001,
      ),
    ];
  }

  List<Map<String, dynamic>> _getMockAutocomplete(String input) {
    return [
      {
        'description': 'Bandra West, Mumbai, Maharashtra, India',
        'place_id': 'mock-auto-1',
      },
      {
        'description': 'Bandra East, Mumbai, Maharashtra, India',
        'place_id': 'mock-auto-2',
      },
    ];
  }
}
