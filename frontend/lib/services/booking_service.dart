import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:volkswagen_hck/config/app_config.dart';
import '../models/booking_model.dart';
import '../models/parking_model.dart';

class BookingService {
  static const String backendUrl = AppConfig.backendUrl;
  static const String availabilityApiUrl = AppConfig.androidEmulatorAvailabilityApi;

  /// Predict availability for a parking slot at a specific time
  Future<AvailabilityPrediction?> predictAvailability({
    required String city,
    required String area,
    required String parkingType,
    required DateTime timestamp,
    bool isEVCharging = false,
    bool isHandicap = false,
    double pricePerHour = 20.0,
    int nearbySlotsCount = 10,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$availabilityApiUrl/api/predict-availability'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'city': city,
          'area': area,
          'parking_type': parkingType,
          'timestamp': timestamp.toIso8601String(),
          'is_ev_charging': isEVCharging,
          'is_handicap': isHandicap,
          'price_per_hour': pricePerHour,
          'nearby_slots_count': nearbySlotsCount,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return AvailabilityPrediction.fromJson(data);
        }
      }
      
      print('Failed to predict availability: ${response.statusCode}');
      return null;
    } catch (e) {
      print('Error predicting availability: $e');
      return null;
    }
  }

  /// Predict availability for multiple slots
  Future<List<AvailabilityPrediction>> batchPredictAvailability(
    List<Map<String, dynamic>> predictions,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$availabilityApiUrl/api/batch-predict-availability'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'predictions': predictions,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final results = data['predictions'] as List;
          return results
              .map((p) => AvailabilityPrediction.fromJson(p))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error in batch prediction: $e');
      return [];
    }
  }

  /// Create a new booking
  Future<BookingModel?> createBooking({
    required String userId,
    required String slotId,
    required DateTime startTime,
    required DateTime endTime,
    String? vehicleNumber,
    String? vehicleModel,
    String? specialRequests,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/booking/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'slotId': slotId,
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
          'vehicleNumber': vehicleNumber,
          'vehicleModel': vehicleModel,
          'specialRequests': specialRequests,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return BookingModel.fromJson(data);
      }
      
      print('Failed to create booking: ${response.statusCode}');
      return null;
    } catch (e) {
      print('Error creating booking: $e');
      return null;
    }
  }

  /// Get user's bookings
  Future<List<BookingModel>> getUserBookings(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/api/booking/user/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final bookings = data['bookings'] as List;
        return bookings.map((b) => BookingModel.fromJson(b)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error getting bookings: $e');
      return [];
    }
  }

  /// Get booking by ID
  Future<BookingModel?> getBooking(String bookingId) async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/api/booking/$bookingId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return BookingModel.fromJson(data);
      }
      
      return null;
    } catch (e) {
      print('Error getting booking: $e');
      return null;
    }
  }

  /// Cancel a booking
  Future<bool> cancelBooking(String bookingId) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/booking/cancel/$bookingId'),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error cancelling booking: $e');
      return false;
    }
  }

  /// Confirm a booking
  Future<bool> confirmBooking(String bookingId) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/booking/confirm/$bookingId'),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error confirming booking: $e');
      return false;
    }
  }

  /// Check in to a booking
  Future<bool> checkinBooking(String bookingId) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/booking/checkin/$bookingId'),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error checking in: $e');
      return false;
    }
  }

  /// Check out from a booking
  Future<bool> checkoutBooking(String bookingId) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/booking/checkout/$bookingId'),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error checking out: $e');
      return false;
    }
  }

  /// Search for available parking near a location with time-based availability prediction
  Future<List<ParkingSlot>> searchParkingWithAvailability({
    required double latitude,
    required double longitude,
    required DateTime desiredTime,
    int? resolution,
    bool? requireEVCharging,
    bool? requireHandicap,
  }) async {
    try {
      print("Searching ");
      // First, search for parking slots
      final response = await http.post(
        Uri.parse('$backendUrl/api/parking/search'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'latitude': latitude,
          'longitude': longitude,
          'resolution': resolution ?? 9,
        }),
      );

      if (response.statusCode != 200) {
        print('Failed to search parking: ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body);
      List<ParkingSlot> slots = [];
      
      if (data['slots'] != null) {
        final slotsData = data['slots'] as List;
        slots = slotsData.map((s) => ParkingSlot.fromJson(s)).toList();
      }

      // Filter by requirements
      if (requireEVCharging == true) {
        slots = slots.where((s) => s.isEVCharging).toList();
      }
      
      if (requireHandicap == true) {
        slots = slots.where((s) => s.isHandicap).toList();
      }

      // Predict availability for each slot
      final predictions = await Future.wait(
        slots.map((slot) => predictAvailability(
          city: slot.city,
          area: slot.area,
          parkingType: slot.type,
          timestamp: desiredTime,
          isEVCharging: slot.isEVCharging,
          isHandicap: slot.isHandicap,
          pricePerHour: slot.pricePerHour,
        )),
      );

      // Add availability data to slots
      for (int i = 0; i < slots.length && i < predictions.length; i++) {
        final prediction = predictions[i];
        if (prediction != null) {
          // You can add availability info to the slot if needed
          // For now, we'll just filter out likely unavailable slots
        }
      }

      // Sort by availability probability (if predictions available)
      // Then by distance (already sorted by backend)
      
      return slots;
    } catch (e) {
      print('Error searching parking with availability: $e');
      return [];
    }
  }

  /// Get recommended time slots for a location
  Future<List<Map<String, dynamic>>> getRecommendedTimeSlots({
    required String city,
    required String area,
    required String parkingType,
    required DateTime startDate,
    int hoursToCheck = 24,
  }) async {
    try {
      final timeSlots = <Map<String, dynamic>>[];
      
      for (int i = 0; i < hoursToCheck; i++) {
        final checkTime = startDate.add(Duration(hours: i));
        
        final prediction = await predictAvailability(
          city: city,
          area: area,
          parkingType: parkingType,
          timestamp: checkTime,
        );

        if (prediction != null) {
          timeSlots.add({
            'time': checkTime,
            'hour': checkTime.hour,
            'availability_probability': prediction.availabilityProbability,
            'is_available': prediction.isAvailable,
            'confidence': prediction.confidence,
          });
        }
      }

      // Sort by availability probability (highest first)
      timeSlots.sort((a, b) => 
        (b['availability_probability'] as double)
            .compareTo(a['availability_probability'] as double)
      );

      return timeSlots;
    } catch (e) {
      print('Error getting recommended time slots: $e');
      return [];
    }
  }
}
