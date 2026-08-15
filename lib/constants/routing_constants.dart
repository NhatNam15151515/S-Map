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
}
