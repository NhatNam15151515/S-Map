class RoutingConstants {
  RoutingConstants._();

  // MethodChannel Configurations
  static const String channelName = 'com.smap/routing';
  static const String methodInitGraphHopper = 'initGraphHopper';
  static const String methodGetRoute = 'getRoute';
  static const String methodSnapToRoad = 'snapToRoad';
  static const String methodIsInitialized = 'isInitialized';
  static const String methodDisposeGraphHopper = 'disposeGraphHopper';

  // MethodChannel Arguments
  static const String argGraphPath = 'graphPath';
  static const String argFromLat = 'fromLat';
  static const String argFromLon = 'fromLon';
  static const String argToLat = 'toLat';
  static const String argToLon = 'toLon';
  static const String argLat = 'lat';
  static const String argLon = 'lon';
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
  static const String errNoRoadFound = 'No valid road found near the given coordinate';
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

  // Navigation Camera & Polyline Dimming Constants
  static const double navCameraTilt = 50.0;
  static const double navLowSpeedThresholdKmh = 15.0;
  static const double navHighSpeedThresholdKmh = 40.0;
  static const double navZoomLowSpeed = 18.0;
  static const double navZoomMidSpeed = 17.0;
  static const double navZoomHighSpeed = 16.0;
  static const double navDimmedPolylineOpacity = 0.4;

  // GPS Tracking & Unit Conversion Constants
  static const double maxGpsAccuracyMeters = 35.0;
  static const double minGpsMovementDeltaMeters = 1.0;
  static const double maxGpsJumpDeltaMeters = 200.0;
  static const double msToKmhFactor = 3.6;
  static const double metersPerKm = 1000.0;
  static const double msPerHour = 3600000.0;

  static const double routeDimmedLineWidth = 4.0;
  static const double routeDimmedOpacity = 0.55;

  // Active Trip Persistence Constants
  static const Duration maxActiveSessionAge = Duration(hours: 24);
}
