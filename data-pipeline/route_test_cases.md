# Route Test Cases - Custom Model Xe Máy Việt Nam

## Mục đích
So sánh kết quả routing của `custom_model_moped.json` với Google Maps
để xác nhận xe máy không bị dẫn vào đường cấm, cao tốc, hoặc đường quá xa.

---

## Test Case 1: Hẻm Sài Gòn (Q1 → Q4)
- **From**: 10.7756, 106.7004 (Nguyễn Trãi, Q1)
- **To**: 10.7595, 106.7020 (Tôn Đản, Q4)
- **Kỳ vọng**: Route đi qua hẻm nhỏ / đường nội bộ, KHÔNG đi vòng ra đại lộ
- **Google Maps**: ~3.2 km, 12 phút
- **S-Map result**: _chưa test_
- **Status**: ⬜

## Test Case 2: Tránh cao tốc (TP.HCM → Biên Hòa)
- **From**: 10.8231, 106.6297 (Bình Tân, HCM)
- **To**: 10.9454, 106.8424 (TP Biên Hòa)
- **Kỳ vọng**: KHÔNG đi cao tốc HCM-Long Thành-Dầu Giây, đi QL1A hoặc đường tỉnh
- **Google Maps (xe máy)**: ~35 km, 1h10
- **S-Map result**: _chưa test_
- **Status**: ⬜
- **Critical**: Nếu route đi qua cao tốc → model CẦN FIX

## Test Case 3: Route dài (TP.HCM → Vũng Tàu)
- **From**: 10.8231, 106.6297 (Bình Tân, HCM)
- **To**: 10.3460, 107.0843 (TP Vũng Tàu)
- **Kỳ vọng**: Đi QL51 (cho phép xe máy), KHÔNG đi cao tốc Long Thành
- **Google Maps (xe máy)**: ~120 km, 3h
- **S-Map result**: _chưa test_
- **Chênh lệch**: < 30% quãng đường so với GG Maps
- **Status**: ⬜

## Test Case 4: Nội thành ngắn (< 2km)
- **From**: 10.7769, 106.7009 (Chợ Bến Thành)
- **To**: 10.7725, 106.6980 (Nhà thờ Đức Bà)
- **Kỳ vọng**: Route ngắn nhất qua đường nội thành, ưu tiên đường nhỏ
- **Google Maps**: ~0.8 km, 3 phút
- **S-Map result**: _chưa test_
- **Status**: ⬜

## Test Case 5: Khu vực đường 1 chiều (Q.3 HCM)
- **From**: 10.7832, 106.6879 (Lý Chính Thắng)
- **To**: 10.7870, 106.6810 (Cách Mạng Tháng 8)
- **Kỳ vọng**: Tuân thủ đường 1 chiều, KHÔNG đi ngược chiều
- **Google Maps**: ~1.5 km, 6 phút
- **S-Map result**: _chưa test_
- **Status**: ⬜

---

## Tóm tắt kết quả

| # | Mô tả | GG Maps | S-Map | Chênh lệch | Pass? |
|---|---|---|---|---|---|
| 1 | Hẻm SG Q1→Q4 | ~3.2km | _TBD_ | _TBD_ | ⬜ |
| 2 | Tránh cao tốc HCM→BH | ~35km | _TBD_ | _TBD_ | ⬜ |
| 3 | Route dài HCM→VT | ~120km | _TBD_ | _TBD_ | ⬜ |
| 4 | Nội thành < 2km | ~0.8km | _TBD_ | _TBD_ | ⬜ |
| 5 | Đường 1 chiều Q3 | ~1.5km | _TBD_ | _TBD_ | ⬜ |

## Tiêu chí Pass/Fail
- ✅ **Pass**: Route hợp lý, không đi đường cấm xe máy, chênh lệch < 30%
- ❌ **Fail**: Đi qua cao tốc/đường cấm, chênh lệch > 30%, hoặc route vô lý
- ⚠️ **Warning**: Route OK nhưng có thể tối ưu hơn

## Cách chạy test
```bash
# 1. Download OSM data
wget https://download.geofabrik.de/asia/vietnam-latest.osm.pbf

# 2. Build graph
java -jar graphhopper-web-*.jar import graphhopper-config.yml

# 3. Start server
java -jar graphhopper-web-*.jar server graphhopper-config.yml

# 4. Query route (ví dụ test case 1)
curl "http://localhost:8989/route?point=10.7756,106.7004&point=10.7595,106.7020&profile=moped_vn" | python -m json.tool

# 5. Mở browser http://localhost:8989 để visualize trên map
```
