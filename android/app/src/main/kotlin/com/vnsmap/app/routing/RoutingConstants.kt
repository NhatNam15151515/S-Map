package com.vnsmap.app.routing

object RoutingConstants {
    // MethodChannel Configurations
    const val CHANNEL_NAME = "com.smap/routing"
    const val METHOD_INIT_GRAPH_HOPPER = "initGraphHopper"
    const val METHOD_GET_ROUTE = "getRoute"
    const val METHOD_SNAP_TO_ROAD = "snapToRoad"
    const val METHOD_IS_INITIALIZED = "isInitialized"
    const val METHOD_DISPOSE_GRAPH_HOPPER = "disposeGraphHopper"

    // MethodChannel Arguments
    const val ARG_GRAPH_PATH = "graphPath"
    const val ARG_FROM_LAT = "fromLat"
    const val ARG_FROM_LON = "fromLon"
    const val ARG_TO_LAT = "toLat"
    const val ARG_TO_LON = "toLon"
    const val ARG_LAT = "lat"
    const val ARG_LON = "lon"
    const val ARG_VEHICLE_PROFILE = "vehicleProfile"

    // GraphHopper Engine Configurations
    const val CONFIG_GRAPH_DATAACCESS = "graph.dataaccess"
    const val CONFIG_GRAPH_LOCATION = "graph.location"
    const val CONFIG_DATAREADER_FILE = "datareader.file"
    const val CONFIG_IMPORT_OSM_IGNORED_HIGHWAYS = "import.osm.ignored_highways"

    // Storage Modes
    const val STORAGE_DAT_MMAP = "DAT_MMAP"

    // Supported Vehicle Profiles
    const val PROFILE_MOPED_VN = "moped_vn"
    const val PROFILE_MOTORCYCLE = "motorcycle"
    const val PROFILE_MOPED = "moped"
    const val PROFILE_CAR = "car"
    const val DEFAULT_PROFILE = PROFILE_MOPED_VN

    // File Extensions & Suffixes
    const val GHZ_EXTENSION = ".ghz"
    const val EXTRACTED_DIR_SUFFIX = "_extracted"
    const val STAGING_DIR_SUFFIX = "_staging_"
    const val BACKUP_DIR_SUFFIX = "_backup_"
    const val SUCCESS_MARKER = ".extracted_success"

    // Buffer & I/O
    const val BUFFER_SIZE = 8192

    // Default Values
    const val DEFAULT_INSTRUCTION_TEXT = "Đi thẳng"
    const val DEFAULT_LOCALE = "vi"

    // Error Messages & Codes
    const val ERR_CODE_INVALID_ARGUMENTS = "INVALID_ARGUMENTS"
    const val ERR_CODE_ROUTING_FAILED = "ROUTING_FAILED"
    const val ERR_CODE_UNKNOWN_METHOD = "NOT_IMPLEMENTED"
    const val ERR_SERVICE_NOT_INITIALIZED = "Routing service has not been initialized"
    const val ERR_NO_ROUTE_FOUND = "No valid route found between given coordinates"
    const val ERR_NO_ROAD_FOUND = "No valid road found near the given coordinate"
    const val ERR_ROUTING_PREFIX = "Routing error: "
    const val ERR_ROUTING_EXCEPTION = "Routing calculation failed: "
    const val ERR_SNAP_EXCEPTION = "Snap calculation failed: "
    const val ERR_ZIP_SLIP_ATTEMPT = "Security Exception: Zip Slip detected for entry "
    const val ERR_GRAPH_DATA_INCOMPLETE = "Graph data is missing or incomplete"
}
