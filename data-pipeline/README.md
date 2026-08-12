# S-Map Data Pipeline

Thư mục chứa các file cấu hình và tools để build offline data cho S-Map.

## Cấu trúc

```
data-pipeline/
├── custom_model_moped.json     # Custom routing model cho xe máy VN
├── graphhopper-config.yml      # Config GraphHopper server
├── route_test_cases.md         # Test cases so sánh với Google Maps
└── README.md                   # File này
```

## Custom Model - Xe máy Việt Nam

### Triết lý thiết kế

Xe máy ở Việt Nam có đặc thù riêng so với ô tô:

1. **Cấm cao tốc** — Xe máy không được phép lên đường cao tốc (motorway)
2. **Ưu tiên hẻm** — Xe máy có thể đi hẻm nhỏ, đường residential rất thuận lợi
3. **Tốc độ thực tế thấp** — Tốc độ trung bình trong TP khoảng 20-35 km/h (kẹt xe)
4. **Không thu phí** — Tránh đường toll (xe máy không trả phí trạm BOT cao tốc)
5. **Đường ngắn hơn đường nhanh** — Xe máy ưu tiên đường ngắn vì tốc độ không chênh nhiều

### Road Class Priority

| Road Class | Priority | Lý do |
|---|---|---|
| MOTORWAY | 🚫 0.0 | Cấm xe máy |
| TRUNK (>80km/h) | 🚫 0.0 | Quốc lộ tốc độ cao, nguy hiểm |
| TRUNK | 0.6 | Cho phép nhưng không ưu tiên |
| PRIMARY | 0.8 | OK, nhưng hay kẹt |
| SECONDARY | 0.9 | Tốt |
| TERTIARY | **1.0** | ✅ Ưu tiên cao nhất |
| RESIDENTIAL | **1.0** | ✅ Ưu tiên cao nhất |
| TRACK | 0.3 | Đường đất, rất ít dùng |

### Speed Limits (km/h)

| Road Class | Limit | Lý do |
|---|---|---|
| TRUNK | 60 | Tốc độ tối đa xe máy trên quốc lộ |
| PRIMARY | 50 | Đường chính nội thành |
| SECONDARY | 45 | Đường nhánh |
| TERTIARY | 40 | Đường nhỏ hơn |
| RESIDENTIAL | 30 | Khu dân cư |
| In CITY | 35 | Giới hạn thêm trong nội thành |

### Cách test

Xem chi tiết tại [route_test_cases.md](route_test_cases.md)

## Yêu cầu cài đặt

- Java 11+ (để chạy GraphHopper)
- Dung lượng: ~500MB RAM cho build graph VN
- Download OSM: https://download.geofabrik.de/asia/vietnam-latest.osm.pbf (~150MB)
