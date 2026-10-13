# S-Map Data Pipeline

Thư mục chứa các file cấu hình và tools để build offline data cho S-Map.

## Tải lại dữ liệu từ GitHub Releases

Các gói dữ liệu lớn đã được phát hành riêng trong GitHub Releases nên không lưu
trong Git. Sau khi clone repo, có thể tải và giải nén lại package vào các thư mục
pipeline bằng lệnh:

```powershell
python data-pipeline/download_release_data.py --region vietnam
```

Script đọc manifest mới nhất, tải package, xác minh SHA-256 của package và từng
file dữ liệu, rồi đặt tiles, routing graph, POI DB và trie vào đúng thư mục.
File hiện có khác bản release sẽ được giữ nguyên; thêm `--force` nếu muốn thay.
Package ZIP đã tải được lưu tại `data-pipeline/data/vietnam.zip`.

## Dựng routing graph

`build_routing_graph.py` tự tải GraphHopper Web 8.0 từ Maven Central nếu chưa
có `data-pipeline/graphhopper-web.jar`, đồng thời xác minh SHA-256 theo checksum
của Maven Central. Phiên bản này phải khớp GraphHopper 8.0 mà Android sử dụng.
Planetiler cũng được script `build_vector_tiles.py` tải và kiểm tra SHA-256.

## Cấu trúc

```text
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
| SERVICE | 0.9 | Hẻm nhỏ, đường nội bộ — ưu tiên cao |
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
