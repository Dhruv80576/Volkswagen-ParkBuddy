class AppConfig {
  // Backend Configuration
  // Change this based on your environment:
  
  // For Android Emulator
  static const String androidEmulatorBackend = 'http://10.76.239.235:8080';
  
  // For iOS Simulator
  static const String iosSimulatorBackend = 'http://10.76.239.235:8080';
  
  // For Physical Device (replace with your computer's IP)
  static const String physicalDeviceBackend = 'http://10.76.239.235:8080';
  
  // For Production
  static const String productionBackend = 'https://your-domain.com';
  
  // Active backend URL - Change this to switch environments
  static const String backendUrl = androidEmulatorBackend;
  
  // ML Pricing API Configuration
  // For Android Emulator
  static const String androidEmulatorPricingApi = 'http://10.0.2.2:5000';
  static const String androidEmulatorAvailabilityApi = 'http://10.76.239.235:5001';

  
  // For iOS Simulator
  static const String iosSimulatorPricingApi = 'http://localhost:5000';
  
  // For Physical Device (replace with your computer's IP)
  static const String physicalDevicePricingApi = 'http://10.76.239.235:5000';
  
  // Active pricing API URL
  static const String pricingApiUrl = androidEmulatorPricingApi;
  
  // Google Maps Configuration
  static const String googleMapsApiKey = 'AIzaSyA4L8tGKjp2XZXks2VghgWWDFOhERwrAzs';
  
  // H3 Configuration
  static const int defaultResolution = 9;  // ~700m hexagons
  static const int minResolution = 7;      // ~5km hexagons
  static const int maxResolution = 12;     // ~9m hexagons
  static const int defaultSearchRadius = 2; // Number of rings for nearby search
  
  // Map Configuration
  static const double defaultZoom = 14.0;
  static const double defaultLatitude = 37.7749;  // San Francisco
  static const double defaultLongitude = -122.4194;
}
