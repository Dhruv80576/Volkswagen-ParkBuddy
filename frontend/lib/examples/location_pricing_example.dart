import '../services/pricing_service.dart';

/// Example: How to get dynamic pricing for a specific location
/// Location: 10.7681657, 78.8183062 (Srirangam area, Trichy)
class LocationPricingExample {
  final PricingService _pricingService = PricingService();

  /// Example 1: Get pricing for the specific location with default parameters
  Future<void> exampleBasicLocationPricing() async {
    print('\n🎯 Example 1: Basic Location Pricing\n');
    
    final prediction = await _pricingService.predictPriceForLocation(
      latitude: 10.7681657,
      longitude: 78.8183062,
      parkingType: 'commercial', // Options: 'airport', 'mall', 'commercial', 'street', 'residential'
      basePrice: 25.0, // Base price in ₹/hour
    );

    if (prediction != null) {
      print('✅ Dynamic Price: ₹${prediction.predictedPrice.toStringAsFixed(2)}/hr');
      print('   Base Price: ₹${prediction.basePrice.toStringAsFixed(2)}/hr');
      print('   Multiplier: ${prediction.priceMultiplier.toStringAsFixed(2)}x');
      print('   Confidence: ${prediction.confidence}');
      
      if (prediction.isHighDemand) {
        print('   🔴 HIGH DEMAND - Surge pricing active');
      } else if (prediction.isPeakPricing) {
        print('   🟠 PEAK HOURS - Moderate surge');
      } else if (prediction.isDiscounted) {
        print('   💚 DISCOUNT - Low demand pricing');
      }
    } else {
      print('❌ Failed to get pricing');
    }
  }

  /// Example 2: Get pricing with all parameters (high demand scenario)
  Future<void> exampleHighDemandPricing() async {
    print('\n🎯 Example 2: High Demand Scenario (Evening Rush)\n');
    
    final prediction = await _pricingService.predictPriceForLocation(
      latitude: 10.7681657,
      longitude: 78.8183062,
      parkingType: 'mall', // Mall parking
      basePrice: 30.0,
      isEVCharging: true, // Has EV charging (+20% premium)
      isHandicap: false,
      demandScore: 85.0, // High demand (0-100 scale)
      occupancyRate: 0.9, // 90% occupied (high occupancy)
      weather: 'rain', // Rainy weather increases demand
      isEvent: true, // Special event nearby
    );

    if (prediction != null) {
      print('✅ Dynamic Price: ₹${prediction.predictedPrice.toStringAsFixed(2)}/hr');
      print('   Base Price: ₹${prediction.basePrice.toStringAsFixed(2)}/hr');
      print('   Multiplier: ${prediction.priceMultiplier.toStringAsFixed(2)}x');
      print('   Price Increase: +${((prediction.priceMultiplier - 1) * 100).toStringAsFixed(1)}%');
      print('   Confidence: ${prediction.confidence}');
      
      print('\n   Factors Applied:');
      print('   • Mall location: +80% base');
      print('   • High demand (85/100): +50-80%');
      print('   • High occupancy (90%): +50%');
      print('   • EV charging: +20%');
      print('   • Rainy weather: +15%');
      print('   • Special event: +30%');
    }
  }

  /// Example 3: Get pricing for low demand scenario (late night)
  Future<void> exampleLowDemandPricing() async {
    print('\n🎯 Example 3: Low Demand Scenario (Late Night)\n');
    
    final prediction = await _pricingService.predictPriceForLocation(
      latitude: 10.7681657,
      longitude: 78.8183062,
      parkingType: 'street', // Street parking
      basePrice: 20.0,
      demandScore: 15.0, // Low demand
      occupancyRate: 0.25, // 25% occupied
      weather: 'clear', // Good weather
      isEvent: false, // No events
    );

    if (prediction != null) {
      print('✅ Dynamic Price: ₹${prediction.predictedPrice.toStringAsFixed(2)}/hr');
      print('   Base Price: ₹${prediction.basePrice.toStringAsFixed(2)}/hr');
      print('   Multiplier: ${prediction.priceMultiplier.toStringAsFixed(2)}x');
      
      if (prediction.isDiscounted) {
        final discount = ((1 - prediction.priceMultiplier) * 100);
        print('   💚 DISCOUNT: ${discount.toStringAsFixed(1)}% off!');
      }
      
      print('\n   Factors Applied:');
      print('   • Street parking: baseline');
      print('   • Low demand (15/100): -15%');
      print('   • Low occupancy (25%): no surge');
      print('   • Late night discount: -20%');
    }
  }

  /// Example 4: Compare different parking types at the same location
  Future<void> exampleCompareTypes() async {
    print('\n🎯 Example 4: Compare Parking Types at Same Location\n');
    
    final types = ['residential', 'street', 'commercial', 'mall', 'airport'];
    final basePrices = [15.0, 20.0, 25.0, 30.0, 50.0];
    
    print('Location: 10.7681657, 78.8183062 (Srirangam, Trichy)');
    print('Time: Current time with medium demand\n');
    
    for (int i = 0; i < types.length; i++) {
      final prediction = await _pricingService.predictPriceForLocation(
        latitude: 10.7681657,
        longitude: 78.8183062,
        parkingType: types[i],
        basePrice: basePrices[i],
        demandScore: 60.0, // Medium demand
        occupancyRate: 0.65, // 65% occupied
      );

      if (prediction != null) {
        final type = types[i].padRight(12);
        final price = prediction.predictedPrice.toStringAsFixed(2).padLeft(7);
        final multiplier = prediction.priceMultiplier.toStringAsFixed(2);
        print('$type: ₹$price/hr (${multiplier}x)');
      }
    }
  }

  /// Example 5: Enable simulation mode for testing without API
  Future<void> exampleSimulationMode() async {
    print('\n🎯 Example 5: Using Simulation Mode\n');
    
    // Enable simulation mode (useful when ML API is not running)
    _pricingService.setSimulationMode(true);
    
    final prediction = await _pricingService.predictPriceForLocation(
      latitude: 10.7681657,
      longitude: 78.8183062,
      parkingType: 'commercial',
      basePrice: 25.0,
      demandScore: 70.0,
    );

    if (prediction != null) {
      print('✅ Simulated Dynamic Price: ₹${prediction.predictedPrice.toStringAsFixed(2)}/hr');
      print('   (Using local simulation, no API call made)');
      print('   Base Price: ₹${prediction.basePrice.toStringAsFixed(2)}/hr');
      print('   Multiplier: ${prediction.priceMultiplier.toStringAsFixed(2)}x');
    }
    
    // Disable simulation mode to use real API
    _pricingService.setSimulationMode(false);
  }

  /// Example 6: Get demand info for the location
  Future<void> exampleDemandCalculation() async {
    print('\n🎯 Example 6: Calculate Demand for Location\n');
    
    final demandInfo = await _pricingService.calculateDemand(
      city: 'Trichy',
      parkingType: 'commercial',
      availableSlots: 25,
      totalSlots: 100,
      recentRequests: 45, // 45 requests in recent period
    );

    if (demandInfo != null) {
      print('📊 Demand Analysis:');
      print('   Score: ${demandInfo.demandScore.toStringAsFixed(1)}/100');
      print('   Level: ${demandInfo.demandLevel.toUpperCase()}');
      print('   Occupancy: ${(demandInfo.occupancyRate * 100).toStringAsFixed(1)}%');
      print('   Available: 25/100 slots');
      
      if (demandInfo.isHighDemand) {
        print('   ⚠️  High demand - Expect surge pricing');
      } else if (demandInfo.isLowDemand) {
        print('   ✅ Low demand - Good time for discounts');
      }
    }
  }

  /// Run all examples
  Future<void> runAllExamples() async {
    print('═══════════════════════════════════════════════════════════');
    print('   DYNAMIC PRICING EXAMPLES FOR LOCATION');
    print('   Coordinates: 10.7681657, 78.8183062');
    print('   Area: Srirangam, Trichy, Tamil Nadu');
    print('═══════════════════════════════════════════════════════════');

    await exampleBasicLocationPricing();
    await exampleHighDemandPricing();
    await exampleLowDemandPricing();
    await exampleCompareTypes();
    await exampleSimulationMode();
    await exampleDemandCalculation();

    print('\n═══════════════════════════════════════════════════════════');
    print('   All examples completed! ✨');
    print('═══════════════════════════════════════════════════════════\n');
  }
}

/// Quick test function to run from your app
Future<void> testLocationPricing() async {
  final example = LocationPricingExample();
  await example.runAllExamples();
}

/// Quick single test for the specific location
Future<void> quickTest() async {
  print('Testing dynamic pricing for 10.7681657, 78.8183062...\n');
  
  final pricingService = PricingService();
  
  final prediction = await pricingService.predictPriceForLocation(
    latitude: 10.7681657,
    longitude: 78.8183062,
    parkingType: 'commercial',
    basePrice: 25.0,
    demandScore: 65.0,
  );

  if (prediction != null) {
    print('✅ SUCCESS!');
    print('   Dynamic Price: ₹${prediction.predictedPrice.toStringAsFixed(2)}/hr');
    print('   Multiplier: ${prediction.priceMultiplier.toStringAsFixed(2)}x');
  } else {
    print('❌ Failed to get pricing');
  }
}
