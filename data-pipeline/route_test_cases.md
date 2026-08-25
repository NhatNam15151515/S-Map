# Route Test Cases - Custom Model Xe Máy Việt Nam

## Mục đích
So sánh kết quả routing của `custom_model_moped.json` với Google Maps
để xác nhận xe máy không bị dẫn vào đường cấm, cao tốc, hoặc đường quá xa.

## Baseline Data
- **OSM Snapshot**: `vietnam-latest.osm.pbf` từ Geofabrik
- **Ngày tải**: _ghi lại ngày tải + SHA-256 của file_
- **Google Maps mode**: Xe máy (Motorcycle) - nếu không có, dùng Driving
- **Thời điểm truy vấn GG Maps**: _ghi lại ngày giờ + điều kiện giao thông_

> ⚠️ Kết quả GG Maps thay đổi theo thời gian thực. Cần ghi lại timestamp mỗi lần query.

---

## Test Case 1: Hẻm Sài Gòn (Q1 → Q4)
- **From**: 10.7756, 106.7004 (Nguyễn Trãi, Q1)
- **To**: 10.7595, 106.7020 (Tôn Đản, Q4)
- **Kỳ vọng**: Route ưu tiên RESIDENTIAL/SERVICE (hẻm), KHÔNG đi vòng ra đại lộ
- **Kiểm tra road_class**: Không chứa MOTORWAY, TRUNK
- **Google Maps (xe máy)**: ~3.2 km, 12 phút — _ghi timestamp query_
- **S-Map result**: _distance_ / _time_
- **Status**: ⬜

## Test Case 2: Tránh cao tốc (TP.HCM → Biên Hòa)
- **From**: 10.8231, 106.6297 (Bình Tân, HCM)
- **To**: 10.9454, 106.8424 (TP Biên Hòa)
- **Kỳ vọng**: KHÔNG đi cao tốc HCM-Long Thành-Dầu Giây, đi QL1A hoặc đường tỉnh
- **Kiểm tra road_class**: Không chứa MOTORWAY
- **Google Maps (xe máy)**: ~35 km, 1h10 — _ghi timestamp query_
- **S-Map result**: _distance_ / _time_
- **Status**: ⬜
- **Critical**: Nếu route đi qua cao tốc → model CẦN FIX

## Test Case 3: Route dài (TP.HCM → Vũng Tàu)
- **From**: 10.8231, 106.6297 (Bình Tân, HCM)
- **To**: 10.3460, 107.0843 (TP Vũng Tàu)
- **Kỳ vọng**: Đi QL51 (cho phép xe máy), KHÔNG đi cao tốc Long Thành
- **Kiểm tra road_class**: Không chứa MOTORWAY
- **Google Maps (xe máy)**: ~120 km, 3h — _ghi timestamp query_
- **S-Map result**: _distance_ / _time_
- **Chênh lệch**: < 30% quãng đường, < 40% thời gian so với GG Maps
- **Status**: ⬜

## Test Case 4: Nội thành ngắn (< 2km)
- **From**: 10.7769, 106.7009 (Chợ Bến Thành)
- **To**: 10.7725, 106.6980 (Nhà thờ Đức Bà)
- **Kỳ vọng**: Route ngắn nhất qua đường nội thành, ưu tiên đường nhỏ
- **Google Maps (xe máy)**: ~0.8 km, 3 phút — _ghi timestamp query_
- **S-Map result**: _distance_ / _time_
- **Status**: ⬜

## Test Case 5: Khu vực đường 1 chiều (Q.3 HCM)
- **From**: 10.7832, 106.6879 (Lý Chính Thắng)
- **To**: 10.7870, 106.6810 (Cách Mạng Tháng 8)
- **Kỳ vọng**: Tuân thủ đường 1 chiều, KHÔNG đi ngược chiều
- **Google Maps (xe máy)**: ~1.5 km, 6 phút — _ghi timestamp query_
- **S-Map result**: _distance_ / _time_
- **Status**: ⬜

---

## Tóm tắt kết quả

| # | Mô tả | GG Maps (km) | GG Maps (phút) | S-Map (km) | S-Map (phút) | Lệch km | Lệch time | Pass? |
|---|---|---|---|---|---|---|---|---|
| 1 | Hẻm SG Q1→Q4 | ~3.2 | ~12 | _TBD_ | _TBD_ | _TBD_ | _TBD_ | ⬜ |
| 2 | Tránh cao tốc HCM→BH | ~35 | ~70 | _TBD_ | _TBD_ | _TBD_ | _TBD_ | ⬜ |
| 3 | Route dài HCM→VT | ~120 | ~180 | _TBD_ | _TBD_ | _TBD_ | _TBD_ | ⬜ |
| 4 | Nội thành < 2km | ~0.8 | ~3 | _TBD_ | _TBD_ | _TBD_ | _TBD_ | ⬜ |
| 5 | Đường 1 chiều Q3 | ~1.5 | ~6 | _TBD_ | _TBD_ | _TBD_ | _TBD_ | ⬜ |

## Tiêu chí Pass/Fail
- ✅ **Pass**: Route hợp lý, không đi đường cấm xe máy, chênh lệch < 30% quãng đường VÀ < 40% thời gian
- ❌ **Fail**: Đi qua cao tốc/đường cấm, chênh lệch > 30% km hoặc > 40% time, hoặc route vô lý
- ⚠️ **Warning**: Route OK nhưng có thể tối ưu hơn

## Cách chạy test

```bash
# 0. Di chuyển vào thư mục data-pipeline
cd data-pipeline

# 1. Download OSM data
wget https://download.geofabrik.de/asia/vietnam-latest.osm.pbf
# Ghi lại SHA-256: sha256sum vietnam-latest.osm.pbf

# 2. Build graph
java -jar graphhopper-web-*.jar import graphhopper-config.yml

# 3. Start server
java -jar graphhopper-web-*.jar server graphhopper-config.yml

# 4. Query route (ví dụ test case 1) - bật pipefail + chi tiết road_class
set -o pipefail
curl --fail "http://localhost:8989/route?point=10.7756,106.7004&point=10.7595,106.7020&profile=moped_vn&points_encoded=false&details=road_class&details=road_access" | python -m json.tool

# 5. Kiểm tra route KHÔNG chứa MOTORWAY hoặc PRIVATE
curl --fail -s "http://localhost:8989/route?point=10.7756,106.7004&point=10.7595,106.7020&profile=moped_vn&points_encoded=false&details=road_class&details=road_access" \
  | python -c "
import sys, json
data = json.load(sys.stdin)
for path in data.get('paths', []):
    for d in path.get('details', {}).get('road_class', []):
        assert d[2] != 'motorway', f'FAIL: route dùng motorway tại segment {d}'
    for d in path.get('details', {}).get('road_access', []):
        assert d[2] != 'private', f'FAIL: route dùng private road tại segment {d}'
print('PASS: Không có motorway hoặc private road')
"

# 6. Mở browser http://localhost:8989 để visualize trên map
```
