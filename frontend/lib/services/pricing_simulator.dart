import 'dart:math';
import 'pricing_service.dart';

/// Simulates dynamic pricing locally without needing the ML API
/// Useful for testing and demos when ML API is unavailable
class PricingSimulator {
  final Random _random = Random();
  
  /// Simulate price prediction based on realistic factors
  PricePrediction simulatePricePrediction({
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
  }) {
    final now = DateTime.now();
    final currentHour = hour ?? now.hour;
    final currentDayOfWeek = dayOfWeek ?? now.weekday;
    
    // Calculate multiplier based on various factors
    double multiplier = 1.0;
    
    // 1. Parking type factor
    multiplier *= _getParkingTypeMultiplier(parkingType);
    
    // 2. Time of day factor (peak hours)
    multiplier *= _getTimeMultiplier(currentHour);
    
    // 3. Day of week factor
    multiplier *= _getDayOfWeekMultiplier(currentDayOfWeek);
    
    // 4. City factor
    multiplier *= _getCityMultiplier(city);
    
    // 5. Demand score factor (most important)
    if (demandScore != null) {
      multiplier *= _getDemandMultiplier(demandScore);
    } else {
      // Generate realistic demand based on time and location
      final simulatedDemand = _simulateDemandScore(
        city: city,
        parkingType: parkingType,
        hour: currentHour,
        dayOfWeek: currentDayOfWeek,
      );
      multiplier *= _getDemandMultiplier(simulatedDemand);
    }
    
    // 6. Occupancy factor
    if (occupancyRate != null) {
      multiplier *= _getOccupancyMultiplier(occupancyRate);
    }
    
    // 7. Weather factor
    if (weather != null) {
      multiplier *= _getWeatherMultiplier(weather);
    }
    
    // 8. Event factor
    if (isEvent) {
      multiplier *= 1.3;
    }
    
    // 9. EV charging premium
    if (isEVCharging) {
      multiplier *= 1.15;
    }
    
    // 10. Add small random variation (±5%)
    multiplier *= (0.95 + _random.nextDouble() * 0.1);
    
    // Apply constraints (0.5x to 3.0x)
    multiplier = multiplier.clamp(0.5, 3.0);
    
    // Calculate final price
    final predictedPrice = basePrice * multiplier;
    
    // Determine confidence based on how much data we have
    String confidence;
    if (demandScore != null && occupancyRate != null) {
      confidence = 'high';
    } else if (demandScore != null || occupancyRate != null) {
      confidence = 'medium';
    } else {
      confidence = 'low';
    }
    
    return PricePrediction(
      predictedPrice: predictedPrice,
      basePrice: basePrice,
      priceMultiplier: multiplier,
      confidence: confidence,
      timestamp: DateTime.now(),
      featuresUsed: {
        'city': city,
        'parking_type': parkingType,
        'hour': currentHour,
        'day_of_week': currentDayOfWeek,
        'simulated': true,
      },
    );
  }
  
  /// Simulate demand calculation
  DemandInfo simulateDemandCalculation({
    required String city,
    required String parkingType,
    required int availableSlots,
    required int totalSlots,
    int recentRequests = 0,
    int? hour,
    int? dayOfWeek,
  }) {
    final now = DateTime.now();
    final currentHour = hour ?? now.hour;
    
    // Calculate occupancy rate
    final occupancyRate = (totalSlots - availableSlots) / totalSlots;
    
    // Base demand from occupancy
    double demandScore = occupancyRate * 60;
    
    // Add demand from recent requests
    demandScore += (recentRequests.clamp(0, 50) * 0.8);
    
    // Adjust for time factors
    demandScore *= _getTimeMultiplier(currentHour);
    
    // Adjust for city
    demandScore *= _getCityMultiplier(city);
    
    // Adjust for parking type
    demandScore *= _getParkingTypeMultiplier(parkingType);
    
    // Clamp between 0 and 100
    demandScore = demandScore.clamp(0.0, 100.0);
    
    // Determine level
    String demandLevel;
    if (demandScore > 70) {
      demandLevel = 'high';
    } else if (demandScore > 40) {
      demandLevel = 'medium';
    } else {
      demandLevel = 'low';
    }
    
    return DemandInfo(
      demandScore: demandScore,
      occupancyRate: occupancyRate,
      demandLevel: demandLevel,
    );
  }
  
  /// Simulate batch predictions
  List<SlotPricePrediction> simulateBatchPredictions({
    required List<Map<String, dynamic>> slots,
    Map<String, dynamic>? commonFeatures,
  }) {
    return slots.map((slot) {
      final prediction = simulatePricePrediction(
        city: slot['city'] ?? 'Mumbai',
        area: slot['area'],
        parkingType: slot['parking_type'] ?? 'street',
        basePrice: (slot['base_price'] ?? 20.0).toDouble(),
        isEVCharging: slot['is_ev_charging'] ?? false,
        isHandicap: slot['is_handicap'] ?? false,
        demandScore: commonFeatures?['demand_score']?.toDouble(),
        occupancyRate: commonFeatures?['occupancy_rate']?.toDouble(),
        weather: commonFeatures?['weather'],
        isEvent: commonFeatures?['is_event'] ?? false,
      );
      
      return SlotPricePrediction(
        slotId: slot['slot_id'] ?? 'unknown',
        predictedPrice: prediction.predictedPrice,
        basePrice: prediction.basePrice,
        priceMultiplier: prediction.priceMultiplier,
      );
    }).toList();
  }
  
  // Helper methods for calculating multipliers
  
  double _getParkingTypeMultiplier(String type) {
    switch (type.toLowerCase()) {
      case 'airport':
        return 2.5;
      case 'commercial':
        return 1.5;
      case 'mall':
        return 1.8;
      case 'street':
        return 1.0;
      case 'residential':
        return 0.8;
      default:
        return 1.0;
    }
  }
  
  double _getTimeMultiplier(int hour) {
    // Morning rush (7-10 AM)
    if (hour >= 7 && hour < 10) return 1.4;
    
    // Lunch (12-2 PM)
    if (hour >= 12 && hour < 14) return 1.2;
    
    // Evening rush (5-8 PM)
    if (hour >= 17 && hour < 20) return 1.6;
    
    // Night (8 PM - 11 PM)
    if (hour >= 20 && hour < 23) return 1.3;
    
    // Late night (11 PM - 6 AM)
    if (hour >= 23 || hour < 6) return 0.7;
    
    // Normal hours
    return 1.0;
  }
  
  double _getDayOfWeekMultiplier(int dayOfWeek) {
    // Monday-Thursday
    if (dayOfWeek >= 1 && dayOfWeek <= 4) return 1.2;
    
    // Friday
    if (dayOfWeek == 5) return 1.5;
    
    // Saturday
    if (dayOfWeek == 6) return 1.3;
    
    // Sunday
    return 0.9;
  }
  
  double _getCityMultiplier(String city) {
    switch (city.toLowerCase()) {
      case 'mumbai':
        return 1.2;
      case 'delhi':
        return 1.15;
      case 'bangalore':
        return 1.1;
      case 'chennai':
        return 1.0;
      case 'trichy':
        return 0.9;
      default:
        return 1.0;
    }
  }
  
  double _getDemandMultiplier(double demandScore) {
    // Convert 0-100 demand score to multiplier (1.0 to 1.8)
    return 1.0 + (demandScore / 100) * 0.8;
  }
  
  double _getOccupancyMultiplier(double occupancyRate) {
    if (occupancyRate > 0.8) return 1.4;
    if (occupancyRate > 0.6) return 1.2;
    if (occupancyRate < 0.3) return 0.85;
    return 1.0;
  }
  
  double _getWeatherMultiplier(String weather) {
    switch (weather.toLowerCase()) {
      case 'rainy':
        return 1.3;
      case 'stormy':
        return 1.5;
      case 'foggy':
        return 1.1;
      case 'clear':
      case 'cloudy':
      default:
        return 1.0;
    }
  }
  
  double _simulateDemandScore({
    required String city,
    required String parkingType,
    required int hour,
    required int dayOfWeek,
  }) {
    // Base demand varies by city
    double demand = {
      'Mumbai': 75.0,
      'Delhi': 70.0,
      'Bangalore': 68.0,
      'Chennai': 60.0,
      'Trichy': 45.0,
    }[city] ?? 50.0;
    
    // Adjust for time
    if ((hour >= 7 && hour < 10) || (hour >= 17 && hour < 20)) {
      demand *= 1.5; // Peak hours
    } else if (hour >= 12 && hour < 14) {
      demand *= 1.2; // Lunch hours
    } else if (hour >= 0 && hour < 6) {
      demand *= 0.3; // Late night
    }
    
    // Adjust for day
    if (dayOfWeek >= 6) {
      demand *= 0.9; // Weekend
    }
    
    // Adjust for parking type
    demand *= _getParkingTypeMultiplier(parkingType) / 1.5;
    
    // Add randomness (±10)
    demand += (_random.nextDouble() * 20 - 10);
    
    return demand.clamp(0.0, 100.0);
  }
}
