import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'pricing_simulator.dart';

/// Service for dynamic parking pricing predictions using ML model
class PricingService {
  static String baseUrl = AppConfig.pricingApiUrl;
  final PricingSimulator _simulator = PricingSimulator();
  
  // Enable simulation mode when API is unavailable
  bool _useSimulation = false;
  
  /// Enable or disable simulation mode
  void setSimulationMode(bool enabled) {
    _useSimulation = enabled;
    print(_useSimulation 
      ? '🎭 Simulation mode enabled' 
      : '🌐 Using real ML API');
  }

  /// Check if pricing API is available
  Future<bool> isHealthy() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'healthy';
      }
      return false;
    } catch (e) {
      print('Pricing API health check failed: $e');
      // Auto-enable simulation if API fails
      _useSimulation = true;
      print('🎭 Auto-enabled simulation mode');
      return false;
    }
  }

  /// Get dynamic price prediction for a parking slot
  Future<PricePrediction?> predictPrice({
    required String city,
    String? area,
    required String parkingType,
    required double basePrice,
    bool isEVCharging = false,
    bool isHandicap = false,
    double? demandScore,
    double? occupancyRate,
    String? weather,
    bool isEvent = false,
    int? hour,
    int? dayOfWeek,
    int? month,
  }) async {
    // Use simulation if enabled
    if (_useSimulation) {
      return _simulator.simulatePricePrediction(
        city: city,
        area: area,
        parkingType: parkingType,
        basePrice: basePrice,
        isEVCharging: isEVCharging,
        isHandicap: isHandicap,
        demandScore: demandScore,
        occupancyRate: occupancyRate,
        weather: weather,
        isEvent: isEvent,
        hour: hour,
        dayOfWeek: dayOfWeek,
        month: month,
      );
    }
    
    try {
      final requestBody = {
        'city': city,
        if (area != null) 'area': area,
        'parking_type': parkingType,
        'base_price': basePrice,
        'is_ev_charging': isEVCharging,
        'is_handicap': isHandicap,
        if (demandScore != null) 'demand_score': demandScore,
        if (occupancyRate != null) 'occupancy_rate': occupancyRate,
        if (weather != null) 'weather': weather,
        'is_event': isEvent,
        if (hour != null) 'hour': hour,
        if (dayOfWeek != null) 'day_of_week': dayOfWeek,
        if (month != null) 'month': month,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/predict-price'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PricePrediction.fromJson(data);
      } else {
        print('Error predicting price: ${response.statusCode} - ${response.body}');
        // Fallback to simulation
        return _simulator.simulatePricePrediction(
          city: city,
          area: area,
          parkingType: parkingType,
          basePrice: basePrice,
          isEVCharging: isEVCharging,
          isHandicap: isHandicap,
          demandScore: demandScore,
          occupancyRate: occupancyRate,
          weather: weather,
          isEvent: isEvent,
          hour: hour,
          dayOfWeek: dayOfWeek,
          month: month,
        );
      }
    } catch (e) {
      print('Error in predictPrice: $e');
      // Fallback to simulation
      return _simulator.simulatePricePrediction(
        city: city,
        area: area,
        parkingType: parkingType,
        basePrice: basePrice,
        isEVCharging: isEVCharging,
        isHandicap: isHandicap,
        demandScore: demandScore,
        occupancyRate: occupancyRate,
        weather: weather,
        isEvent: isEvent,
        hour: hour,
        dayOfWeek: dayOfWeek,
        month: month,
      );
    }
  }

  /// Get dynamic prices for multiple parking slots (batch)
  Future<List<SlotPricePrediction>> batchPredictPrices({
    required List<Map<String, dynamic>> slots,
    Map<String, dynamic>? commonFeatures,
  }) async {
    // Use simulation if enabled
    if (_useSimulation) {
      return _simulator.simulateBatchPredictions(
        slots: slots,
        commonFeatures: commonFeatures,
      );
    }
    
    try {
      final requestBody = {
        'slots': slots,
        if (commonFeatures != null) 'common_features': commonFeatures,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/batch-predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final predictions = data['predictions'] as List;
        return predictions.map((p) => SlotPricePrediction.fromJson(p)).toList();
      } else {
        print('Error batch predicting: ${response.statusCode} - ${response.body}');
        // Fallback to simulation
        return _simulator.simulateBatchPredictions(
          slots: slots,
          commonFeatures: commonFeatures,
        );
      }
    } catch (e) {
      print('Error in batchPredictPrices: $e');
      // Fallback to simulation
      return _simulator.simulateBatchPredictions(
        slots: slots,
        commonFeatures: commonFeatures,
      );
    }
  }

  /// Calculate demand score based on current conditions
  Future<DemandInfo?> calculateDemand({
    required String city,
    required String parkingType,
    required int availableSlots,
    required int totalSlots,
    int recentRequests = 0,
    int? hour,
    int? dayOfWeek,
  }) async {
    // Use simulation if enabled
    if (_useSimulation) {
      return _simulator.simulateDemandCalculation(
        city: city,
        parkingType: parkingType,
        availableSlots: availableSlots,
        totalSlots: totalSlots,
        recentRequests: recentRequests,
        hour: hour,
        dayOfWeek: dayOfWeek,
      );
    }
    
    try {
      final requestBody = {
        'city': city,
        'parking_type': parkingType,
        'available_slots': availableSlots,
        'total_slots': totalSlots,
        'recent_requests': recentRequests,
        if (hour != null) 'hour': hour,
        if (dayOfWeek != null) 'day_of_week': dayOfWeek,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/calculate-demand'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DemandInfo.fromJson(data);
      } else {
        print('Error calculating demand: ${response.statusCode} - ${response.body}');
        // Fallback to simulation
        return _simulator.simulateDemandCalculation(
          city: city,
          parkingType: parkingType,
          availableSlots: availableSlots,
          totalSlots: totalSlots,
          recentRequests: recentRequests,
          hour: hour,
          dayOfWeek: dayOfWeek,
        );
      }
    } catch (e) {
      print('Error in calculateDemand: $e');
      // Fallback to simulation
      return _simulator.simulateDemandCalculation(
        city: city,
        parkingType: parkingType,
        availableSlots: availableSlots,
        totalSlots: totalSlots,
        recentRequests: recentRequests,
        hour: hour,
        dayOfWeek: dayOfWeek,
      );
    }
  }

  /// Get model information
  Future<ModelInfo?> getModelInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/model-info'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ModelInfo.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error getting model info: $e');
      return null;
    }
  }

  /// Get dynamic pricing for a specific location by coordinates
  /// This is a convenience method for location-based pricing
  Future<PricePrediction?> predictPriceForLocation({
    required double latitude,
    required double longitude,
    required String parkingType,
    required double basePrice,
    String? city,
    String? area,
    bool isEVCharging = false,
    bool isHandicap = false,
    double? demandScore,
    double? occupancyRate,
    String? weather,
    bool isEvent = false,
  }) async {
    // Determine city from coordinates if not provided
    final locationCity = city ?? _getCityFromCoordinates(latitude, longitude);
    final locationArea = area ?? _getAreaFromCoordinates(latitude, longitude, locationCity);

    print('📍 Getting dynamic price for location:');
    print('   Coordinates: ($latitude, $longitude)');
    print('   City: $locationCity, Area: $locationArea');
    print('   Type: $parkingType, Base: ₹$basePrice/hr');

    return predictPrice(
      city: locationCity,
      area: locationArea,
      parkingType: parkingType,
      basePrice: basePrice,
      isEVCharging: isEVCharging,
      isHandicap: isHandicap,
      demandScore: demandScore,
      occupancyRate: occupancyRate,
      weather: weather,
      isEvent: isEvent,
    );
  }

  /// Determine city from coordinates
  String _getCityFromCoordinates(double lat, double lon) {
    // Trichy area: ~10.7-10.9 lat, 78.6-78.9 lon
    if (lat >= 10.7 && lat <= 10.9 && lon >= 78.6 && lon <= 78.9) {
      return 'Trichy';
    }
    // Mumbai area: ~18.9-19.3 lat, 72.8-73.0 lon
    if (lat >= 18.9 && lat <= 19.3 && lon >= 72.8 && lon <= 73.0) {
      return 'Mumbai';
    }
    // Delhi area: ~28.4-28.9 lat, 76.8-77.3 lon
    if (lat >= 28.4 && lat <= 28.9 && lon >= 76.8 && lon <= 77.3) {
      return 'Delhi';
    }
    // Bangalore area: ~12.8-13.2 lat, 77.4-77.8 lon
    if (lat >= 12.8 && lat <= 13.2 && lon >= 77.4 && lon <= 77.8) {
      return 'Bangalore';
    }
    // Chennai area: ~12.9-13.2 lat, 80.1-80.3 lon
    if (lat >= 12.9 && lat <= 13.2 && lon >= 80.1 && lon <= 80.3) {
      return 'Chennai';
    }
    
    // Default to closest city or generic
    return 'Trichy'; // Default for unknown coordinates
  }

  /// Determine area from coordinates within a city
  String _getAreaFromCoordinates(double lat, double lon, String city) {
    if (city == 'Trichy') {
      // Specific area mapping for Trichy based on coordinates
      // 10.7681657, 78.8183062 is in the eastern part of Trichy
      if (lon >= 78.8 && lon <= 78.85) {
        return 'Srirangam'; // Eastern area near the temple
      } else if (lon >= 78.75 && lon < 78.8) {
        return 'Cantonment';
      } else if (lon >= 78.7 && lon < 78.75) {
        return 'Airport Area';
      } else if (lat >= 10.79 && lat <= 10.82) {
        return 'Thillai Nagar';
      }
      return 'City Center';
    }
    
    // Generic area for other cities
    return city + ' Central';
  }
}

/// Model for price prediction response
class PricePrediction {
  final double predictedPrice;
  final double basePrice;
  final double priceMultiplier;
  final String confidence;
  final DateTime timestamp;
  final Map<String, dynamic> featuresUsed;

  PricePrediction({
    required this.predictedPrice,
    required this.basePrice,
    required this.priceMultiplier,
    required this.confidence,
    required this.timestamp,
    required this.featuresUsed,
  });

  factory PricePrediction.fromJson(Map<String, dynamic> json) {
    return PricePrediction(
      predictedPrice: (json['predicted_price'] ?? 0.0).toDouble(),
      basePrice: (json['base_price'] ?? 0.0).toDouble(),
      priceMultiplier: (json['price_multiplier'] ?? 1.0).toDouble(),
      confidence: json['confidence'] ?? 'medium',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      featuresUsed: json['features_used'] ?? {},
    );
  }

  bool get isHighDemand => priceMultiplier > 1.5;
  bool get isDiscounted => priceMultiplier < 0.9;
  bool get isPeakPricing => priceMultiplier > 1.2 && priceMultiplier <= 1.5;
}

/// Model for batch prediction result
class SlotPricePrediction {
  final String slotId;
  final double predictedPrice;
  final double basePrice;
  final double priceMultiplier;

  SlotPricePrediction({
    required this.slotId,
    required this.predictedPrice,
    required this.basePrice,
    required this.priceMultiplier,
  });

  factory SlotPricePrediction.fromJson(Map<String, dynamic> json) {
    return SlotPricePrediction(
      slotId: json['slot_id'] ?? '',
      predictedPrice: (json['predicted_price'] ?? 0.0).toDouble(),
      basePrice: (json['base_price'] ?? 0.0).toDouble(),
      priceMultiplier: (json['price_multiplier'] ?? 1.0).toDouble(),
    );
  }
}

/// Model for demand calculation response
class DemandInfo {
  final double demandScore;
  final double occupancyRate;
  final String demandLevel;

  DemandInfo({
    required this.demandScore,
    required this.occupancyRate,
    required this.demandLevel,
  });

  factory DemandInfo.fromJson(Map<String, dynamic> json) {
    return DemandInfo(
      demandScore: (json['demand_score'] ?? 50.0).toDouble(),
      occupancyRate: (json['occupancy_rate'] ?? 0.5).toDouble(),
      demandLevel: json['demand_level'] ?? 'medium',
    );
  }

  bool get isHighDemand => demandLevel == 'high';
  bool get isLowDemand => demandLevel == 'low';
}

/// Model for ML model information
class ModelInfo {
  final String modelType;
  final String trainedAt;
  final int trainingSamples;
  final Map<String, dynamic> performanceMetrics;
  final List<String> features;

  ModelInfo({
    required this.modelType,
    required this.trainedAt,
    required this.trainingSamples,
    required this.performanceMetrics,
    required this.features,
  });

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      modelType: json['model_type'] ?? 'unknown',
      trainedAt: json['trained_at'] ?? '',
      trainingSamples: json['training_samples'] ?? 0,
      performanceMetrics: json['performance_metrics'] ?? {},
      features: (json['features'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  double? get testR2 => performanceMetrics['test_r2']?.toDouble();
  double? get testRMSE => performanceMetrics['test_rmse']?.toDouble();
  double? get testMAE => performanceMetrics['test_mae']?.toDouble();
}
