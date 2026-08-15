package com.vnsmap.app.routing

object RoutingConstants {
    // File & Folder conventions
    const val GHZ_EXTENSION = ".ghz"
    const val EXTRACTED_DIR_SUFFIX = "_extracted"
    const val BUFFER_SIZE = 8192

    // GraphHopper Configuration Keys
    const val CONFIG_GRAPH_DATAACCESS = "graph.dataaccess"
    const val CONFIG_GRAPH_LOCATION = "graph.location"
    const val CONFIG_DATAREADER_FILE = "datareader.file"
    const val CONFIG_IMPORT_OSM_IGNORED_HIGHWAYS = "import.osm.ignored_highways"

    // Storage Modes
    const val STORAGE_DAT_MMAP = "DAT_MMAP"

    // Default Routing Profiles
    const val DEFAULT_PROFILE = "car"
    const val PROFILE_MOTORCYCLE = "motorcycle"
    const val PROFILE_MOPED = "moped"
    const val PROFILE_BIKE = "bike"
    const val PROFILE_FOOT = "foot"

    // Instruction Defaults & Strings
    const val DEFAULT_INSTRUCTION_TEXT = "Đi thẳng"

    // Error Messages
    const val ERR_SERVICE_NOT_INITIALIZED = "GraphHopper service is not initialized"
    const val ERR_NO_ROUTE_FOUND = "No route found"
    const val ERR_ROUTING_EXCEPTION = "Exception during routing: "
    const val ERR_ROUTING_PREFIX = "Routing error: "
    const val ERR_INVALID_GRAPH_DIR = "Invalid or non-existent graph directory"
    const val ERR_ZIP_SLIP_ATTEMPT = "Zip entry is outside of target directory: "
}
