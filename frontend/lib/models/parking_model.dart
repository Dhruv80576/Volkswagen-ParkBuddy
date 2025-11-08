class ParkingSlot {
  final String id;
  final double latitude;
  final double longitude;
  final String h3Index;
  final String city;
  final String area;
  final String type;
  final String status;
  final double pricePerHour;
  final bool isEVCharging;
  final bool isHandicap;
  
  // Dynamic pricing fields
  double? dynamicPrice;
  double? priceMultiplier;
  String? pricingConfidence;
  double? demandScore;
  String? demandLevel;

  ParkingSlot({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.h3Index,
    required this.city,
    required this.area,
    required this.type,
    required this.status,
    required this.pricePerHour,
    required this.isEVCharging,
    required this.isHandicap,
    this.dynamicPrice,
    this.priceMultiplier,
    this.pricingConfidence,
    this.demandScore,
    this.demandLevel,
  });

  factory ParkingSlot.fromJson(Map<String, dynamic> json) {
    return ParkingSlot(
      id: json['id'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      h3Index: json['h3Index'] ?? '',
      city: json['city'] ?? '',
      area: json['area'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? 'available',
      pricePerHour: (json['pricePerHour'] ?? 0.0).toDouble(),
      isEVCharging: json['isEVCharging'] ?? false,
      isHandicap: json['isHandicap'] ?? false,
      dynamicPrice: json['dynamicPrice']?.toDouble(),
      priceMultiplier: json['priceMultiplier']?.toDouble(),
      pricingConfidence: json['pricingConfidence'],
      demandScore: json['demandScore']?.toDouble(),
      demandLevel: json['demandLevel'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'h3Index': h3Index,
      'city': city,
      'area': area,
      'type': type,
      'status': status,
      'pricePerHour': pricePerHour,
      'isEVCharging': isEVCharging,
      'isHandicap': isHandicap,
      if (dynamicPrice != null) 'dynamicPrice': dynamicPrice,
      if (priceMultiplier != null) 'priceMultiplier': priceMultiplier,
      if (pricingConfidence != null) 'pricingConfidence': pricingConfidence,
      if (demandScore != null) 'demandScore': demandScore,
      if (demandLevel != null) 'demandLevel': demandLevel,
    };
  }
  
  // Get the effective price (dynamic if available, otherwise base)
  double get effectivePrice => dynamicPrice ?? pricePerHour;
  
  // Check if dynamic pricing is applied
  bool get hasDynamicPricing => dynamicPrice != null && dynamicPrice != pricePerHour;
  
  // Check if price is discounted
  bool get isDiscounted => priceMultiplier != null && priceMultiplier! < 0.9;
  
  // Check if price has surge
  bool get hasSurge => priceMultiplier != null && priceMultiplier! > 1.2;
  
  // Check if it's peak pricing
  bool get isPeakPricing => priceMultiplier != null && priceMultiplier! > 1.2 && priceMultiplier! <= 1.5;
  
  // Check if it's high surge
  bool get isHighSurge => priceMultiplier != null && priceMultiplier! > 1.5;

  String get typeIcon {
    switch (type) {
      case 'mall':
        return '🛍️';
      case 'street':
        return '🚗';
      case 'residential':
        return '🏠';
      case 'commercial':
        return '🏢';
      case 'airport':
        return '✈️';
      default:
        return '🅿️';
    }
  }
}

class ParkingMatch {
  final String requestId;
  final ParkingSlot parkingSlot;
  final double distance;
  final double score;
  final double travelTime;
  final DateTime matchedAt;

  ParkingMatch({
    required this.requestId,
    required this.parkingSlot,
    required this.distance,
    required this.score,
    required this.travelTime,
    required this.matchedAt,
  });

  factory ParkingMatch.fromJson(Map<String, dynamic> json) {
    return ParkingMatch(
      requestId: json['requestId'] ?? '',
      parkingSlot: ParkingSlot.fromJson(json['parkingSlot'] ?? {}),
      distance: (json['distance'] ?? 0.0).toDouble(),
      score: (json['score'] ?? 0.0).toDouble(),
      travelTime: (json['travelTime'] ?? 0.0).toDouble(),
      matchedAt: json['matchedAt'] != null 
        ? DateTime.parse(json['matchedAt'])
        : DateTime.now(),
    );
  }

  String get distanceText {
    if (distance < 1) {
      return '${(distance * 1000).toInt()}m';
    }
    return '${distance.toStringAsFixed(1)}km';
  }

  String get travelTimeText {
    if (travelTime < 1) {
      return '< 1 min';
    }
    return '${travelTime.toInt()} min';
  }
}

class SearchRequest {
  final String? id;
  final double userLat;
  final double userLng;
  final double maxDistance;
  final double maxPrice;
  final bool requiresEV;
  final bool requiresHandicap;
  final List<String> preferredTypes;
  final double priority;

  SearchRequest({
    this.id,
    required this.userLat,
    required this.userLng,
    this.maxDistance = 5.0,
    this.maxPrice = 100.0,
    this.requiresEV = false,
    this.requiresHandicap = false,
    this.preferredTypes = const [],
    this.priority = 1.0,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'userLat': userLat,
      'userLng': userLng,
      'maxDistance': maxDistance,
      'maxPrice': maxPrice,
      'requiresEV': requiresEV,
      'requiresHandicap': requiresHandicap,
      'preferredTypes': preferredTypes,
      'priority': priority,
    };
  }
}

class ParkingStats {
  final int availableSlots;
  final int totalSlots;
  final DateTime timestamp;

  ParkingStats({
    required this.availableSlots,
    required this.totalSlots,
    required this.timestamp,
  });

  factory ParkingStats.fromJson(Map<String, dynamic> json) {
    return ParkingStats(
      availableSlots: json['availableSlots'] ?? 0,
      totalSlots: json['totalSlots'] ?? 0,
      timestamp: json['timestamp'] != null 
        ? DateTime.parse(json['timestamp'])
        : DateTime.now(),
    );
  }

  double get occupancyRate {
    if (totalSlots == 0) return 0.0;
    return ((totalSlots - availableSlots) / totalSlots) * 100;
  }
}
