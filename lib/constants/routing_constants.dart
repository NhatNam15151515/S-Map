class RoutingConstants {
  RoutingConstants._();

  // MethodChannel Configurations
  static const String channelName = 'com.smap/routing';
  static const String methodInitGraphHopper = 'initGraphHopper';
  static const String methodGetRoute = 'getRoute';
  static const String methodIsInitialized = 'isInitialized';
  static const String methodDisposeGraphHopper = 'disposeGraphHopper';

  // MethodChannel Arguments
  static const String argGraphPath = 'graphPath';
  static const String argFromLat = 'fromLat';
  static const String argFromLon = 'fromLon';
  static const String argToLat = 'toLat';
  static const String argToLon = 'toLon';
  static const String argVehicleProfile = 'vehicleProfile';

  // Vehicle Profiles
  static const String profileMopedVn = 'moped_vn';
  static const String profileMotorcycle = 'motorcycle';
  static const String profileMoped = 'moped';
  static const String profileCar = 'car';
  static const String defaultProfile = profileMopedVn;

  // Error Messages
  static const String errServiceNotInitialized = 'Routing service has not been initialized';
  static const String errNoRouteFound = 'No valid route found between given coordinates';
  static const String errInvalidCoordinates = 'Invalid coordinates provided';
  static const String errPlatformChannel = 'Platform channel communication error';

  // Polyline & Route Display Constants
  static const double routeCasingLineWidth = 7.0;
  static const double routeMainLineWidth = 5.0;
  static const double routeCasingOpacity = 0.85;
  static const double routeMainOpacity = 1.0;
  static const String routeLineJoin = 'round';
  static const String markerImageKey = 'red_marker';

  static const double routeFitPaddingLeft = 48.0;
  static const double routeFitPaddingTop = 120.0;
  static const double routeFitPaddingRight = 48.0;
  static const double routeFitPaddingBottom = 240.0;
  static const double minDistanceForFitBoundsKm = 0.05;
  static const double closeDistanceZoomLevel = 16.0;

  // Turn-by-turn Navigation Thresholds
  static const double defaultAdvanceThresholdMeters = 30.0;
  static const double defaultPreAnnounceThresholdMeters = 200.0;
  static const double defaultArrivalThresholdMeters = 20.0;
  static const double defaultOffRouteThresholdMeters = 50.0;
  static const double fallbackSpeedKmh = 30.0;
}
