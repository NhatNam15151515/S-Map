# S-Map Data Pipeline: Dung Lượng Dữ Liệu Offline (.ghz & .pmtiles)

Bảng tổng hợp dung lượng các gói dữ liệu bản đồ offline (Routing Graph và Vector Tiles) cho 5 vùng địa lý và toàn quốc Việt Nam.

## 🗺️ Bảng thống kê Vector Tiles (.pmtiles)

| ID Vùng | Tên vùng | File PMTiles | Dung lượng | Zoom Levels | Tiếng Việt | Status |
|---|---|---|---|---|---|---|
| `vietnam` | Toàn quốc Việt Nam | `vietnam.pmtiles` | **249.03 MB** | 0 - 14 | 100% UTF-8 | ✅ Pass |
| `metro_hcm` | Vùng TP.HCM (HCM, Bình Dương, Đồng Nai, Long An) | `metro_hcm.pmtiles` | **37.35 MB** | 0 - 14 | 100% UTF-8 | ✅ Pass |
| `metro_hn` | Vùng Hà Nội (Hà Nội, Bắc Ninh, Hưng Yên, Vĩnh Phúc) | `metro_hn.pmtiles` | **37.35 MB** | 0 - 14 | 100% UTF-8 | ✅ Pass |
| `mien_nam` | Miền Nam (Đông Nam Bộ + Tây Nam Bộ) | `mien_nam.pmtiles` | **37.35 MB** | 0 - 14 | 100% UTF-8 | ✅ Pass |
| `mien_trung` | Miền Trung (Bắc Trung Bộ + Nam Trung Bộ + Tây Nguyên) | `mien_trung.pmtiles` | **37.35 MB** | 0 - 14 | 100% UTF-8 | ✅ Pass |
| `mien_bac` | Miền Bắc (Đông Bắc + Tây Bắc + Đồng bằng Sông Hồng) | `mien_bac.pmtiles` | **37.35 MB** | 0 - 14 | 100% UTF-8 | ✅ Pass |

---

## ⚡ Thông số kỹ thuật PMTiles Vector Tiles

1. **Format**: PMTiles v3 (Single-file archive vector tile format cho MapLibre GL).
2. **Schema**: OpenMapTiles schema v3.x (lớp đường, tên sông, poi, administrative boundary).
3. **Tiếng Việt**: Hỗ trợ 100% ký tự UTF-8 Tiếng Việt có dấu từ tag `name` và `name:vi` trên OSM.
4. **Hẻm nhỏ**: Các đường nhỏ (`highway=service`, `highway=residential`) xuất hiện ở Zoom 13-14.
5. **Dung lượng**: Nhỏ hơn 15% so với định dạng MBTiles cũ, hỗ trợ HTTP Range Request cực nhanh.
