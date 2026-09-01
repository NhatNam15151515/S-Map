import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

/// Default S-Map map palette. Add another implementation or preset here when
/// the visual language changes; MapLibre widgets do not need to change.
class DefaultMapStyleThemeProvider implements IMapStyleThemeProvider {
  static const MapStylePalette light = MapStylePalette(
    mapBackground: '#F7F9FC',
    landWood: '#DCEBD7',
    landGrass: '#E7F1DE',
    landScrub: '#EEF2DF',
    landWetland: '#DDEEF0',
    landDefault: '#EEF2F6',
    landResidential: '#F0F2F5',
    landCommercial: '#F8EBDD',
    landIndustrial: '#E8EAF0',
    landCemetery: '#E1EFDF',
    landMilitary: '#E8E4EF',
    landuseDefault: '#EEF1F4',
    parkFill: '#DCEED8',
    parkOutline: '#B9D9B4',
    waterFill: '#BFDFF1',
    waterOutline: '#9CC9E4',
    waterwayLine: '#8FC7E6',
    boundaryLine: '#AAB7C6',
    aerowayFill: '#E6E8ED',
    aerowayLine: '#B4BBC7',
    buildingFill: '#D9DFE8',
    buildingOutline: '#C0C9D5',
    roadCasing: '#C8D2DD',
    roadSurface: '#FFFFFF',
    roadCasingOpacity: 0.94,
    roadSurfaceOpacity: 1.0,
    placeDot: '#6C7B8A',
    placeStroke: '#FFFFFF',
    poiDot: '#607D8B',
    poiStroke: '#FFFFFF',
    houseNumberDot: '#7B8794',
    labelPrimary: '#374151',
    labelSecondary: '#596579',
    labelWater: '#2E759C',
    labelPoi: '#4B5563',
    labelHalo: '#F7F9FC',
  );

  static const MapStylePalette dark = MapStylePalette(
    // Xanh than nâng nhẹ để khu dân cư không bị chìm vào nền.
    mapBackground: '#1D293A',
    landWood: '#294B40',
    landGrass: '#315047',
    landScrub: '#3B5149',
    landWetland: '#2A5264',
    landDefault: '#28374A',
    landResidential: '#2E3D50',
    landCommercial: '#493C40',
    landIndustrial: '#3D4050',
    landCemetery: '#334B42',
    landMilitary: '#403B52',
    landuseDefault: '#2F3D50',
    parkFill: '#2C523F',
    parkOutline: '#42765B',
    waterFill: '#23536C',
    waterOutline: '#347696',
    waterwayLine: '#4F91AA',
    boundaryLine: '#708BA0',
    aerowayFill: '#3E4858',
    aerowayLine: '#6A7E91',
    buildingFill: '#3B4A5C',
    buildingOutline: '#4C5F74',
    // Đường dùng xám xanh trầm và alpha thấp hơn để không lấn át nền.
    roadCasing: '#29394D',
    roadSurface: '#72879B',
    roadCasingOpacity: 0.62,
    roadSurfaceOpacity: 0.54,
    placeDot: '#A4B3C1',
    placeStroke: '#25354A',
    poiDot: '#89A2B4',
    poiStroke: '#233247',
    houseNumberDot: '#8DA1B3',
    labelPrimary: '#CBD6E0',
    labelSecondary: '#A9B9C8',
    labelWater: '#78B1C9',
    labelPoi: '#B8C7D3',
    labelHalo: '#1D293A',
  );

  @override
  MapStylePalette paletteFor({required bool isDarkMode}) =>
      isDarkMode ? dark : light;
}
