import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/parking_model.dart';
import '../config/app_config.dart';
import 'pricing_service.dart';

class ParkingService {
  static String baseUrl = AppConfig.backendUrl;
  final PricingService _pricingService = PricingService();
  
  bool _pricingApiAvailable = false;

  /// Check if pricing API is available
  Future<void> checkPricingAvailability() async {
    _pricingApiAvailable = await _pricingService.isHealthy();
    if (_pricingApiAvailable) {
      print('✓ Dynamic pricing enabled');
    } else {
      print('⚠ Dynamic pricing unavailable, using base prices');
    }
  }
  
  /// Enrich parking match with dynamic pricing
  Future<ParkingMatch> enrichWithDynamicPricing(ParkingMatch match) async {
    if (!_pricingApiAvailable) {
      return match; // Return as-is if pricing API not available
    }
    
    try {
      final prediction = await _pricingService.predictPrice(
        city: match.parkingSlot.city,
        area: match.parkingSlot.area,
        parkingType: match.parkingSlot.type,
        basePrice: match.parkingSlot.pricePerHour,
        isEVCharging: match.parkingSlot.isEVCharging,
        isHandicap: match.parkingSlot.isHandicap,
      );
      
      if (prediction != null) {
        match.parkingSlot.dynamicPrice = prediction.predictedPrice;
        match.parkingSlot.priceMultiplier = prediction.priceMultiplier;
        match.parkingSlot.pricingConfidence = prediction.confidence;
      }
    } catch (e) {
      print('Error enriching with dynamic pricing: $e');
    }
    
    return match;
  }
  
  /// Enrich multiple matches with dynamic pricing (batch)
  Future<List<ParkingMatch>> enrichBatchWithDynamicPricing(List<ParkingMatch> matches) async {
    if (!_pricingApiAvailable || matches.isEmpty) {
      return matches;
    }
    
    try {
      final slots = matches.map((m) => {
        'slot_id': m.parkingSlot.id,
        'city': m.parkingSlot.city,
        'area': m.parkingSlot.area,
        'parking_type': m.parkingSlot.type,
        'base_price': m.parkingSlot.pricePerHour,
        'is_ev_charging': m.parkingSlot.isEVCharging,
        'is_handicap': m.parkingSlot.isHandicap,
      }).toList();
      
      final predictions = await _pricingService.batchPredictPrices(slots: slots);
      
      // Map predictions to matches
      for (var match in matches) {
        final pred = predictions.firstWhere(
          (p) => p.slotId == match.parkingSlot.id,
          orElse: () => SlotPricePrediction(
            slotId: match.parkingSlot.id,
            predictedPrice: match.parkingSlot.pricePerHour,
            basePrice: match.parkingSlot.pricePerHour,
            priceMultiplier: 1.0,
          ),
        );
        
        match.parkingSlot.dynamicPrice = pred.predictedPrice;
        match.parkingSlot.priceMultiplier = pred.priceMultiplier;
      }
    } catch (e) {
      print('Error batch enriching with dynamic pricing: $e');
    }
    
    return matches;
  }

  /// Search for a single parking slot
  Future<ParkingMatch?> searchParking({
    required double latitude,
    required double longitude,
    double maxDistance = 5.0,
    double maxPrice = 100.0,
    bool requiresEV = false,
    bool requiresHandicap = false,
    List<String> preferredTypes = const [],
    double priority = 1.0,
  }) async {
    try {
      final request = SearchRequest(
        userLat: latitude,
        userLng: longitude,
        maxDistance: maxDistance,
        maxPrice: maxPrice,
        requiresEV: requiresEV,
        requiresHandicap: requiresHandicap,
        preferredTypes: preferredTypes,
        priority: priority,
      );

      final response = await http.post(
        Uri.parse('$baseUrl/api/parking/search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['match'] != null) {
          var match = ParkingMatch.fromJson(data['match']);
          // Enrich with dynamic pricing
          match = await enrichWithDynamicPricing(match);
          return match;
        }
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      print('Error searching parking: $e');
      return null;
    }
  }

  /// Batch search for parking slots (Bipartite matching)
  Future<List<ParkingMatch>> batchSearchParking({
    required List<SearchRequest> requests,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/parking/batch-search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requests.map((r) => r.toJson()).toList()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['result'] != null) {
          final matches = data['result']['matches'] as List;
          var matchList = matches.map((m) => ParkingMatch.fromJson(m)).toList();
          // Enrich with dynamic pricing
          matchList = await enrichBatchWithDynamicPricing(matchList);
          return matchList;
        }
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
      }
      return [];
    } catch (e) {
      print('Error batch searching parking: $e');
      return [];
    }
  }

  /// Get parking statistics
  Future<ParkingStats?> getParkingStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/parking/stats'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return ParkingStats.fromJson(data);
        }
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      print('Error getting parking stats: $e');
      return null;
    }
  }

  /// Mark parking slot as occupied
  Future<bool> markParkingOccupied(String slotId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/parking/mark-occupied/$slotId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error marking parking occupied: $e');
      return false;
    }
  }

  /// Mark parking slot as available
  Future<bool> markParkingAvailable(String slotId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/parking/mark-available/$slotId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error marking parking available: $e');
      return false;
    }
  }
}
