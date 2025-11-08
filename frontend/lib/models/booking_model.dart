class BookingModel {
  final String id;
  final String userId;
  final String slotId;
  final String city;
  final String area;
  final double latitude;
  final double longitude;
  final String parkingType;
  final DateTime bookingTime;
  final DateTime startTime;
  final DateTime endTime;
  final double pricePerHour;
  final double totalPrice;
  final String status; // pending, confirmed, active, completed, cancelled
  final bool isEVCharging;
  final bool isHandicap;
  
  // Availability prediction
  final double? availabilityProbability;
  final String? availabilityConfidence;
  
  // Additional details
  final String? vehicleNumber;
  final String? vehicleModel;
  final String? specialRequests;
  final DateTime? checkinTime;
  final DateTime? checkoutTime;

  BookingModel({
    required this.id,
    required this.userId,
    required this.slotId,
    required this.city,
    required this.area,
    required this.latitude,
    required this.longitude,
    required this.parkingType,
    required this.bookingTime,
    required this.startTime,
    required this.endTime,
    required this.pricePerHour,
    required this.totalPrice,
    required this.status,
    required this.isEVCharging,
    required this.isHandicap,
    this.availabilityProbability,
    this.availabilityConfidence,
    this.vehicleNumber,
    this.vehicleModel,
    this.specialRequests,
    this.checkinTime,
    this.checkoutTime,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      slotId: json['slotId'] ?? '',
      city: json['city'] ?? '',
      area: json['area'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      parkingType: json['parkingType'] ?? '',
      bookingTime: json['bookingTime'] != null 
          ? DateTime.parse(json['bookingTime']) 
          : DateTime.now(),
      startTime: json['startTime'] != null 
          ? DateTime.parse(json['startTime']) 
          : DateTime.now(),
      endTime: json['endTime'] != null 
          ? DateTime.parse(json['endTime']) 
          : DateTime.now(),
      pricePerHour: (json['pricePerHour'] ?? 0.0).toDouble(),
      totalPrice: (json['totalPrice'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'pending',
      isEVCharging: json['isEVCharging'] ?? false,
      isHandicap: json['isHandicap'] ?? false,
      availabilityProbability: json['availabilityProbability']?.toDouble(),
      availabilityConfidence: json['availabilityConfidence'],
      vehicleNumber: json['vehicleNumber'],
      vehicleModel: json['vehicleModel'],
      specialRequests: json['specialRequests'],
      checkinTime: json['checkinTime'] != null 
          ? DateTime.parse(json['checkinTime']) 
          : null,
      checkoutTime: json['checkoutTime'] != null 
          ? DateTime.parse(json['checkoutTime']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'slotId': slotId,
      'city': city,
      'area': area,
      'latitude': latitude,
      'longitude': longitude,
      'parkingType': parkingType,
      'bookingTime': bookingTime.toIso8601String(),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'pricePerHour': pricePerHour,
      'totalPrice': totalPrice,
      'status': status,
      'isEVCharging': isEVCharging,
      'isHandicap': isHandicap,
      if (availabilityProbability != null) 
        'availabilityProbability': availabilityProbability,
      if (availabilityConfidence != null) 
        'availabilityConfidence': availabilityConfidence,
      if (vehicleNumber != null) 'vehicleNumber': vehicleNumber,
      if (vehicleModel != null) 'vehicleModel': vehicleModel,
      if (specialRequests != null) 'specialRequests': specialRequests,
      if (checkinTime != null) 'checkinTime': checkinTime!.toIso8601String(),
      if (checkoutTime != null) 'checkoutTime': checkoutTime!.toIso8601String(),
    };
  }

  // Calculate duration in hours
  double get durationHours {
    return endTime.difference(startTime).inMinutes / 60.0;
  }

  // Check if booking is active
  bool get isActive {
    final now = DateTime.now();
    return status == 'active' || 
           (status == 'confirmed' && now.isAfter(startTime) && now.isBefore(endTime));
  }

  // Check if booking is upcoming
  bool get isUpcoming {
    final now = DateTime.now();
    return status == 'confirmed' && now.isBefore(startTime);
  }

  // Check if booking is completed
  bool get isCompleted {
    return status == 'completed' || 
           (DateTime.now().isAfter(endTime) && status != 'cancelled');
  }

  // Get status color
  String get statusColor {
    switch (status) {
      case 'pending':
        return '#FFA500'; // Orange
      case 'confirmed':
        return '#4CAF50'; // Green
      case 'active':
        return '#2196F3'; // Blue
      case 'completed':
        return '#9E9E9E'; // Grey
      case 'cancelled':
        return '#F44336'; // Red
      default:
        return '#000000'; // Black
    }
  }

  // Get status display text
  String get statusText {
    switch (status) {
      case 'pending':
        return 'Pending Confirmation';
      case 'confirmed':
        return 'Confirmed';
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  // Create a copy with updated fields
  BookingModel copyWith({
    String? id,
    String? userId,
    String? slotId,
    String? city,
    String? area,
    double? latitude,
    double? longitude,
    String? parkingType,
    DateTime? bookingTime,
    DateTime? startTime,
    DateTime? endTime,
    double? pricePerHour,
    double? totalPrice,
    String? status,
    bool? isEVCharging,
    bool? isHandicap,
    double? availabilityProbability,
    String? availabilityConfidence,
    String? vehicleNumber,
    String? vehicleModel,
    String? specialRequests,
    DateTime? checkinTime,
    DateTime? checkoutTime,
  }) {
    return BookingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      slotId: slotId ?? this.slotId,
      city: city ?? this.city,
      area: area ?? this.area,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      parkingType: parkingType ?? this.parkingType,
      bookingTime: bookingTime ?? this.bookingTime,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      isEVCharging: isEVCharging ?? this.isEVCharging,
      isHandicap: isHandicap ?? this.isHandicap,
      availabilityProbability: availabilityProbability ?? this.availabilityProbability,
      availabilityConfidence: availabilityConfidence ?? this.availabilityConfidence,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      specialRequests: specialRequests ?? this.specialRequests,
      checkinTime: checkinTime ?? this.checkinTime,
      checkoutTime: checkoutTime ?? this.checkoutTime,
    );
  }
}

// Place search result from Google Places API
class PlaceSearchResult {
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? vicinity;
  final List<String>? types;
  
  PlaceSearchResult({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.vicinity,
    this.types,
  });

  factory PlaceSearchResult.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'];
    final location = geometry['location'];
    
    return PlaceSearchResult(
      placeId: json['place_id'] ?? '',
      name: json['name'] ?? json['formatted_address'] ?? '',
      address: json['formatted_address'] ?? '',
      latitude: (location['lat'] ?? 0.0).toDouble(),
      longitude: (location['lng'] ?? 0.0).toDouble(),
      vicinity: json['vicinity'],
      types: json['types'] != null 
          ? List<String>.from(json['types']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'placeId': placeId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      if (vicinity != null) 'vicinity': vicinity,
      if (types != null) 'types': types,
    };
  }
}

// Availability prediction result
class AvailabilityPrediction {
  final bool isAvailable;
  final double availabilityProbability;
  final double occupancyProbability;
  final double confidence;
  final DateTime predictionTime;
  final Map<String, dynamic>? featuresUsed;

  AvailabilityPrediction({
    required this.isAvailable,
    required this.availabilityProbability,
    required this.occupancyProbability,
    required this.confidence,
    required this.predictionTime,
    this.featuresUsed,
  });

  factory AvailabilityPrediction.fromJson(Map<String, dynamic> json) {
    return AvailabilityPrediction(
      isAvailable: json['is_available'] ?? false,
      availabilityProbability: (json['availability_probability'] ?? 0.0).toDouble(),
      occupancyProbability: (json['occupancy_probability'] ?? 0.0).toDouble(),
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      predictionTime: json['prediction_time'] != null
          ? DateTime.parse(json['prediction_time'])
          : DateTime.now(),
      featuresUsed: json['features_used'],
    );
  }

  // Get confidence level as text
  String get confidenceLevel {
    if (confidence >= 0.9) return 'Very High';
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.7) return 'Medium';
    if (confidence >= 0.6) return 'Low';
    return 'Very Low';
  }

  // Get availability status text
  String get statusText {
    if (isAvailable) {
      if (availabilityProbability >= 0.8) {
        return 'Highly Likely Available';
      } else if (availabilityProbability >= 0.6) {
        return 'Likely Available';
      } else {
        return 'Possibly Available';
      }
    } else {
      if (occupancyProbability >= 0.8) {
        return 'Highly Likely Occupied';
      } else if (occupancyProbability >= 0.6) {
        return 'Likely Occupied';
      } else {
        return 'Possibly Occupied';
      }
    }
  }
}
