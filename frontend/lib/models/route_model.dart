import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteInfo {
  final String summary;
  final String encodedPolyline;
  final int distanceMeters;
  final int durationSeconds;
  final List<LatLng> points;
  final List<RouteStep> steps;
  final LatLng startLocation;
  final LatLng endLocation;
  final RouteBounds bounds;

  RouteInfo({
    required this.summary,
    required this.encodedPolyline,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
    required this.steps,
    required this.startLocation,
    required this.endLocation,
    required this.bounds,
  });

  factory RouteInfo.fromJson(Map<String, dynamic> json) {
    final overviewPolyline = json['overview_polyline']?['points'] ?? '';
    final legs = json['legs'] as List? ?? [];
    
    int totalDistance = 0;
    int totalDuration = 0;
    List<RouteStep> allSteps = [];
    LatLng? start;
    LatLng? end;

    for (var leg in legs) {
      totalDistance += (leg['distance']?['value'] ?? 0) as int;
      totalDuration += (leg['duration']?['value'] ?? 0) as int;
      
      if (start == null && leg['start_location'] != null) {
        start = LatLng(
          leg['start_location']['lat'].toDouble(),
          leg['start_location']['lng'].toDouble(),
        );
      }
      
      if (leg['end_location'] != null) {
        end = LatLng(
          leg['end_location']['lat'].toDouble(),
          leg['end_location']['lng'].toDouble(),
        );
      }

      final steps = leg['steps'] as List? ?? [];
      for (var step in steps) {
        allSteps.add(RouteStep.fromJson(step));
      }
    }

    final boundsData = json['bounds'];
    final bounds = RouteBounds(
      northeast: LatLng(
        boundsData['northeast']['lat'].toDouble(),
        boundsData['northeast']['lng'].toDouble(),
      ),
      southwest: LatLng(
        boundsData['southwest']['lat'].toDouble(),
        boundsData['southwest']['lng'].toDouble(),
      ),
    );

    return RouteInfo(
      summary: json['summary'] ?? '',
      encodedPolyline: overviewPolyline,
      distanceMeters: totalDistance,
      durationSeconds: totalDuration,
      points: [], // Will be decoded separately
      steps: allSteps,
      startLocation: start ?? const LatLng(0, 0),
      endLocation: end ?? const LatLng(0, 0),
      bounds: bounds,
    );
  }

  /// Factory constructor for Routes API v2 JSON response
  factory RouteInfo.fromRoutesApiJson(Map<String, dynamic> json) {
    final polylineData = json['polyline'];
    final encodedPolyline = polylineData?['encodedPolyline'] ?? '';
    
    // Extract distance (in meters)
    final distanceMeters = json['distanceMeters'] ?? 0;
    
    // Extract duration (format: "123s")
    final durationStr = json['duration'] ?? '0s';
    final durationSeconds = int.parse(durationStr.replaceAll('s', ''));
    
    // Extract legs and steps
    final legs = json['legs'] as List? ?? [];
    List<RouteStep> allSteps = [];
    LatLng? start;
    LatLng? end;

    for (var leg in legs) {
      if (start == null && leg['startLocation'] != null) {
        final latLng = leg['startLocation']['latLng'];
        start = LatLng(
          latLng['latitude'].toDouble(),
          latLng['longitude'].toDouble(),
        );
      }
      
      if (leg['endLocation'] != null) {
        final latLng = leg['endLocation']['latLng'];
        end = LatLng(
          latLng['latitude'].toDouble(),
          latLng['longitude'].toDouble(),
        );
      }

      final steps = leg['steps'] as List? ?? [];
      for (var step in steps) {
        allSteps.add(RouteStep.fromRoutesApiJson(step));
      }
    }

    // Calculate bounds from polyline or use start/end locations
    final bounds = _calculateBounds(start, end);

    return RouteInfo(
      summary: json['description'] ?? 'Route',
      encodedPolyline: encodedPolyline,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      points: [], // Will be decoded separately
      steps: allSteps,
      startLocation: start ?? const LatLng(0, 0),
      endLocation: end ?? const LatLng(0, 0),
      bounds: bounds,
    );
  }

  static RouteBounds _calculateBounds(LatLng? start, LatLng? end) {
    if (start == null || end == null) {
      return RouteBounds(
        northeast: const LatLng(0, 0),
        southwest: const LatLng(0, 0),
      );
    }

    final double minLat = start.latitude < end.latitude ? start.latitude : end.latitude;
    final double maxLat = start.latitude > end.latitude ? start.latitude : end.latitude;
    final double minLng = start.longitude < end.longitude ? start.longitude : end.longitude;
    final double maxLng = start.longitude > end.longitude ? start.longitude : end.longitude;

    return RouteBounds(
      northeast: LatLng(maxLat, maxLng),
      southwest: LatLng(minLat, minLng),
    );
  }

  String get distanceText {
    if (distanceMeters < 1000) {
      return '$distanceMeters m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  String get durationText {
    final minutes = durationSeconds ~/ 60;
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '$hours hr ${remainingMinutes} min';
  }

  double get distanceKm => distanceMeters / 1000;
  double get durationMinutes => durationSeconds / 60;
}

class RouteStep {
  final String instruction;
  final String maneuver;
  final int distanceMeters;
  final int durationSeconds;
  final LatLng startLocation;
  final LatLng endLocation;
  final String encodedPolyline;

  RouteStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.startLocation,
    required this.endLocation,
    required this.encodedPolyline,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    return RouteStep(
      instruction: _stripHtml(json['html_instructions'] ?? ''),
      maneuver: json['maneuver'] ?? '',
      distanceMeters: json['distance']?['value'] ?? 0,
      durationSeconds: json['duration']?['value'] ?? 0,
      startLocation: LatLng(
        json['start_location']['lat'].toDouble(),
        json['start_location']['lng'].toDouble(),
      ),
      endLocation: LatLng(
        json['end_location']['lat'].toDouble(),
        json['end_location']['lng'].toDouble(),
      ),
      encodedPolyline: json['polyline']?['points'] ?? '',
    );
  }

  /// Factory constructor for Routes API v2 JSON response
  factory RouteStep.fromRoutesApiJson(Map<String, dynamic> json) {
    // Extract distance (in meters)
    final distanceMeters = json['distanceMeters'] ?? 0;
    
    // Extract duration (format: "123s")
    final durationStr = json['staticDuration'] ?? json['duration'] ?? '0s';
    final durationSeconds = int.parse(durationStr.replaceAll('s', ''));
    
    // Extract navigation instruction
    final navigationInstruction = json['navigationInstruction'];
    final instruction = navigationInstruction?['instructions'] ?? '';
    final maneuver = navigationInstruction?['maneuver'] ?? '';
    
    // Extract locations
    final startLatLng = json['startLocation']?['latLng'];
    final endLatLng = json['endLocation']?['latLng'];
    
    final startLocation = LatLng(
      startLatLng?['latitude']?.toDouble() ?? 0.0,
      startLatLng?['longitude']?.toDouble() ?? 0.0,
    );
    
    final endLocation = LatLng(
      endLatLng?['latitude']?.toDouble() ?? 0.0,
      endLatLng?['longitude']?.toDouble() ?? 0.0,
    );
    
    // Extract polyline
    final polylineData = json['polyline'];
    final encodedPolyline = polylineData?['encodedPolyline'] ?? '';
    
    return RouteStep(
      instruction: instruction,
      maneuver: maneuver,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      startLocation: startLocation,
      endLocation: endLocation,
      encodedPolyline: encodedPolyline,
    );
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"');
  }

  String get distanceText {
    if (distanceMeters < 1000) {
      return '$distanceMeters m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
}

class RouteBounds {
  final LatLng northeast;
  final LatLng southwest;

  RouteBounds({
    required this.northeast,
    required this.southwest,
  });

  LatLngBounds toLatLngBounds() {
    return LatLngBounds(
      southwest: southwest,
      northeast: northeast,
    );
  }
}

class NavigationInfo {
  final RouteInfo route;
  final double currentLat;
  final double currentLng;
  final int currentStepIndex;
  final double distanceToNextTurn;
  final String nextInstruction;

  NavigationInfo({
    required this.route,
    required this.currentLat,
    required this.currentLng,
    this.currentStepIndex = 0,
    this.distanceToNextTurn = 0,
    this.nextInstruction = '',
  });

  RouteStep? get currentStep {
    if (currentStepIndex < route.steps.length) {
      return route.steps[currentStepIndex];
    }
    return null;
  }

  RouteStep? get nextStep {
    if (currentStepIndex + 1 < route.steps.length) {
      return route.steps[currentStepIndex + 1];
    }
    return null;
  }

  double get remainingDistance {
    double distance = 0;
    for (int i = currentStepIndex; i < route.steps.length; i++) {
      distance += route.steps[i].distanceMeters;
    }
    return distance / 1000; // Convert to km
  }

  int get remainingDuration {
    int duration = 0;
    for (int i = currentStepIndex; i < route.steps.length; i++) {
      duration += route.steps[i].durationSeconds;
    }
    return duration;
  }

  String get remainingDurationText {
    final minutes = remainingDuration ~/ 60;
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '$hours hr ${remainingMinutes} min';
  }
}
