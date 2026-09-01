/// Color tokens consumed by the offline MapLibre style.
///
/// Keeping these values outside of the JSON and map widgets lets us introduce
/// another visual preset without touching the renderer or map interaction
/// code.
class MapStylePalette {
  final String mapBackground;
  final String landWood;
  final String landGrass;
  final String landScrub;
  final String landWetland;
  final String landDefault;
  final String landResidential;
  final String landCommercial;
  final String landIndustrial;
  final String landCemetery;
  final String landMilitary;
  final String landuseDefault;
  final String parkFill;
  final String parkOutline;
  final String waterFill;
  final String waterOutline;
  final String waterwayLine;
  final String boundaryLine;
  final String aerowayFill;
  final String aerowayLine;
  final String buildingFill;
  final String buildingOutline;
  final String roadCasing;
  final String roadSurface;
  final double roadCasingOpacity;
  final double roadSurfaceOpacity;
  final String placeDot;
  final String placeStroke;
  final String poiDot;
  final String poiStroke;
  final String houseNumberDot;
  final String labelPrimary;
  final String labelSecondary;
  final String labelWater;
  final String labelPoi;
  final String labelHalo;

  const MapStylePalette({
    required this.mapBackground,
    required this.landWood,
    required this.landGrass,
    required this.landScrub,
    required this.landWetland,
    required this.landDefault,
    required this.landResidential,
    required this.landCommercial,
    required this.landIndustrial,
    required this.landCemetery,
    required this.landMilitary,
    required this.landuseDefault,
    required this.parkFill,
    required this.parkOutline,
    required this.waterFill,
    required this.waterOutline,
    required this.waterwayLine,
    required this.boundaryLine,
    required this.aerowayFill,
    required this.aerowayLine,
    required this.buildingFill,
    required this.buildingOutline,
    required this.roadCasing,
    required this.roadSurface,
    required this.roadCasingOpacity,
    required this.roadSurfaceOpacity,
    required this.placeDot,
    required this.placeStroke,
    required this.poiDot,
    required this.poiStroke,
    required this.houseNumberDot,
    required this.labelPrimary,
    required this.labelSecondary,
    required this.labelWater,
    required this.labelPoi,
    required this.labelHalo,
  });

  /// Token names intentionally match the placeholders in
  /// `assets/map/offline_style.json`.
  Map<String, String> get tokens => {
        '__MAP_BACKGROUND__': mapBackground,
        '__LAND_WOOD__': landWood,
        '__LAND_GRASS__': landGrass,
        '__LAND_SCRUB__': landScrub,
        '__LAND_WETLAND__': landWetland,
        '__LAND_DEFAULT__': landDefault,
        '__LAND_RESIDENTIAL__': landResidential,
        '__LAND_COMMERCIAL__': landCommercial,
        '__LAND_INDUSTRIAL__': landIndustrial,
        '__LAND_CEMETERY__': landCemetery,
        '__LAND_MILITARY__': landMilitary,
        '__LANDUSE_DEFAULT__': landuseDefault,
        '__PARK_FILL__': parkFill,
        '__PARK_OUTLINE__': parkOutline,
        '__WATER_FILL__': waterFill,
        '__WATER_OUTLINE__': waterOutline,
        '__WATERWAY_LINE__': waterwayLine,
        '__BOUNDARY_LINE__': boundaryLine,
        '__AEROWAY_FILL__': aerowayFill,
        '__AEROWAY_LINE__': aerowayLine,
        '__BUILDING_FILL__': buildingFill,
        '__BUILDING_OUTLINE__': buildingOutline,
        '__ROAD_CASING__': roadCasing,
        '__ROAD_SURFACE__': roadSurface,
        '__ROAD_CASING_OPACITY__': roadCasingOpacity.toString(),
        '__ROAD_SURFACE_OPACITY__': roadSurfaceOpacity.toString(),
        '__PLACE_DOT__': placeDot,
        '__PLACE_STROKE__': placeStroke,
        '__POI_DOT__': poiDot,
        '__POI_STROKE__': poiStroke,
        '__HOUSE_NUMBER_DOT__': houseNumberDot,
        '__LABEL_PRIMARY__': labelPrimary,
        '__LABEL_SECONDARY__': labelSecondary,
        '__LABEL_WATER__': labelWater,
        '__LABEL_POI__': labelPoi,
        '__LABEL_HALO__': labelHalo,
      };
}
