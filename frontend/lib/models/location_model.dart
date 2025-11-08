class LocationData {
  final double latitude;
  final double longitude;
  final String h3Index;
  final int h3IndexInt;
  final int resolution;
  final double centerLat;
  final double centerLng;
  final List<List<dynamic>> boundary;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.h3Index,
    required this.h3IndexInt,
    required this.resolution,
    required this.centerLat,
    required this.centerLng,
    required this.boundary,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      h3Index: json['h3Index'] ?? '',
      h3IndexInt: json['h3IndexInt'] ?? 0,
      resolution: json['resolution'] ?? 9,
      centerLat: json['centerLat']?.toDouble() ?? 0.0,
      centerLng: json['centerLng']?.toDouble() ?? 0.0,
      boundary:
          (json['boundary'] as List<dynamic>?)
              ?.map(
                (e) => (e as List<dynamic>)
                    .map((coord) => coord.toDouble())
                    .toList(),
              )
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'h3Index': h3Index,
      'h3IndexInt': h3IndexInt,
      'resolution': resolution,
      'centerLat': centerLat,
      'centerLng': centerLng,
      'boundary': boundary,
    };
  }
}

class NearbyDriversData {
  final String currentCell;
  final List<String> nearbyCells;
  final int totalCells;

  NearbyDriversData({
    required this.currentCell,
    required this.nearbyCells,
    required this.totalCells,
  });

  factory NearbyDriversData.fromJson(Map<String, dynamic> json) {
    return NearbyDriversData(
      currentCell: json['currentCell'] ?? '',
      nearbyCells:
          (json['nearbyCells'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      totalCells: json['totalCells'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentCell': currentCell,
      'nearbyCells': nearbyCells,
      'totalCells': totalCells,
    };
  }
}
