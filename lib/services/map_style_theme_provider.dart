import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

/// Default S-Map map palette. Add another implementation or preset here when
/// the visual language changes; MapLibre widgets do not need to change.
class DefaultMapStyleThemeProvider implements IMapStyleThemeProvider {
  static const MapStylePalette light = MapStylePalette(
    // ─── Nền bản đồ ───
    mapBackground: '#F7F9FC', // Màu nền canvas bản đồ
    // ─── Thảm thực vật & Tự nhiên (Landcover) ───
    landWood: '#DCEBD7', // Rừng cây, rừng rậm
    landGrass: '#E7F1DE', // Đồng cỏ, bãi cỏ
    landScrub: '#EEF2DF', // Thảm cây bụi, đất hoang sơ
    landWetland: '#DDEEF0', // Đất ngập nước, đầm lầy
    landDefault: '#EEF2F6', // Đất nền tự nhiên mặc định
    // ─── Quy hoạch sử dụng đất (Landuse) ───
    landResidential: '#F0F2F5', // Khu dân cư, khu nhà ở
    landCommercial: '#F8EBDD', // Khu thương mại, dịch vụ
    landIndustrial: '#E8EAF0', // Khu công nghiệp, nhà máy
    landCemetery: '#E1EFDF', // Nghĩa trang, hoa viên
    landMilitary: '#E8E4EF', // Khu vực quân sự, an ninh
    landuseDefault: '#EEF1F4', // Đất quy hoạch mặc định
    // ─── Công viên & Cảnh quan xanh (Parks) ───
    parkFill: '#DCEED8', // Lòng công viên, vườn hoa công cộng
    parkOutline: '#B9D9B4', // Đường viền bao quanh công viên
    // ─── Sông ngòi & Nguồn nước (Water) ───
    waterFill: '#BFDFF1', // Lòng sông, hồ, biển, kênh rạch lớn
    waterOutline: '#9CC9E4', // Viền bờ sông, mép nước
    waterwayLine: '#8FC7E6', // Nét vẽ suối nhỏ, kênh dẫn nước
    // ─── Ranh giới & Hàng không ───
    boundaryLine: '#AAB7C6', // Ranh giới hành chính, biên giới
    aerowayFill: '#E6E8ED', // Bề mặt khu vực sân bay, bãi đáp
    aerowayLine: '#B4BBC7', // Đường kẻ tim đường băng sân bay
    // ─── Tòa nhà & Công trình (Buildings) ───
    buildingFill: '#D9DFE8', // Khối nóc tòa nhà, công trình
    buildingOutline: '#C0C9D5', // Viền mép tường, mái tòa nhà
    // ─── Đường sá & Giao thông (Roads) ───
    roadCasing: '#C8D2DD', // Viền mép ngoài đường xe chạy
    roadSurface: '#FFFFFF', // Mặt đường xe chạy (lòng đường)
    roadCasingOpacity: 0.94, // Độ mờ viền đường (0.0 - 1.0)
    roadSurfaceOpacity: 1.0, // Độ mờ mặt đường (0.0 - 1.0)
    // ─── Điểm mốc & Chấm định danh ───
    placeDot: '#6C7B8A', // Chấm vị trí địa danh (thôn, xóm, thị trấn)
    placeStroke: '#FFFFFF', // Viền chấm địa danh
    poiDot: '#607D8B', // Chấm vị trí POI (quán ăn, trạm xăng, ATM)
    poiStroke: '#FFFFFF', // Viền chấm POI
    houseNumberDot: '#7B8794', // Chấm vị trí số nhà
    // ─── Nhãn chữ & Typography (Labels) ───
    labelPrimary: '#374151', // Chữ chính (quốc gia, tỉnh/thành, đường lớn)
    labelSecondary: '#596579', // Chữ phụ (hẻm nhỏ, địa danh cấp thấp)
    labelWater: '#2E759C', // Tên sông, hồ, biển, vịnh
    labelPoi: '#4B5563', // Tên các điểm tiện ích POI
    labelHalo: '#F7F9FC', // Hào quang viền chữ (giúp chữ không bị chìm)
  );

  static const MapStylePalette dark = MapStylePalette(
    // ─── Nền bản đồ ───
    // Xanh than nâng nhẹ để khu dân cư không bị chìm vào nền.
    mapBackground: '#1D293A', // Màu nền canvas bản đồ
    // ─── Thảm thực vật & Tự nhiên (Landcover) ───
    landWood: '#294B40', // Rừng cây, rừng rậm
    landGrass: '#315047', // Đồng cỏ, bãi cỏ
    landScrub: '#3B5149', // Thảm cây bụi, đất hoang sơ
    landWetland: '#2A5264', // Đất ngập nước, đầm lầy
    landDefault: '#28374A', // Đất nền tự nhiên mặc định
    // ─── Quy hoạch sử dụng đất (Landuse) ───
    landResidential: '#2E3D50', // Khu dân cư, khu nhà ở
    landCommercial: '#493C40', // Khu thương mại, dịch vụ
    landIndustrial: '#3D4050', // Khu công nghiệp, nhà máy
    landCemetery: '#334B42', // Nghĩa trang, hoa viên
    landMilitary: '#403B52', // Khu vực quân sự, an ninh
    landuseDefault: '#2F3D50', // Đất quy hoạch mặc định
    // ─── Công viên & Cảnh quan xanh (Parks) ───
    parkFill: '#2C523F', // Lòng công viên, vườn hoa công cộng
    parkOutline: '#42765B', // Đường viền bao quanh công viên
    // ─── Sông ngòi & Nguồn nước (Water) ───
    waterFill: '#23536C', // Lòng sông, hồ, biển, kênh rạch lớn
    waterOutline: '#347696', // Viền bờ sông, mép nước
    waterwayLine: '#4F91AA', // Nét vẽ suối nhỏ, kênh dẫn nước
    // ─── Ranh giới & Hàng không ───
    boundaryLine: '#708BA0', // Ranh giới hành chính, biên giới
    aerowayFill: '#3E4858', // Bề mặt khu vực sân bay, bãi đáp
    aerowayLine: '#6A7E91', // Đường kẻ tim đường băng sân bay
    // ─── Tòa nhà & Công trình (Buildings) ───
    buildingFill: '#3B4A5C', // Khối nóc tòa nhà, công trình
    buildingOutline: '#4C5F74', // Viền mép tường, mái tòa nhà
    // ─── Đường sá & Giao thông (Roads) ───
    // Dùng màu đặc (opacity 1.0) để triệt tiêu lỗi overdraw bị đốm màu ở ngã ba/ngã tư.
    roadCasing: '#243345', // Viền mép ngoài đường xe chạy (xanh than trầm)
    roadSurface:
        '#46586C', // Mặt đường xe chạy (lòng đường xám xanh đã hòa màu nền)
    roadCasingOpacity: 1.0, // Độ mờ viền đường (1.0 để liền mạch tại giao lộ)
    roadSurfaceOpacity: 1.0, // Độ mờ mặt đường (1.0 để liền mạch tại giao lộ)
    // ─── Điểm mốc & Chấm định danh ───
    placeDot: '#A4B3C1', // Chấm vị trí địa danh (thôn, xóm, thị trấn)
    placeStroke: '#25354A', // Viền chấm địa danh
    poiDot: '#89A2B4', // Chấm vị trí POI (quán ăn, trạm xăng, ATM)
    poiStroke: '#233247', // Viền chấm POI
    houseNumberDot: '#8DA1B3', // Chấm vị trí số nhà
    // ─── Nhãn chữ & Typography (Labels) ───
    labelPrimary: '#CBD6E0', // Chữ chính (quốc gia, tỉnh/thành, đường lớn)
    labelSecondary: '#A9B9C8', // Chữ phụ (hẻm nhỏ, địa danh cấp thấp)
    labelWater: '#78B1C9', // Tên sông, hồ, biển, vịnh
    labelPoi: '#B8C7D3', // Tên các điểm tiện ích POI
    labelHalo: '#1D293A', // Hào quang viền chữ (giúp chữ không bị chìm)
  );

  @override
  MapStylePalette paletteFor({required bool isDarkMode}) =>
      isDarkMode ? dark : light;
}
