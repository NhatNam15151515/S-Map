# Hướng Dẫn Build Vector Tiles (PMTiles) - S-Map

Tài liệu hướng dẫn quy trình tạo và đóng gói dữ liệu bản đồ dạng Vector Tiles (`.pmtiles`) cho ứng dụng S-Map.

## 🎯 Tổng quan về PMTiles

[PMTiles](https://protomaps.com/docs/pmtiles) là định dạng lưu trữ Vector Tiles trong **duy nhất 1 file nén** (`.pmtiles`). 
So với định dạng MBTiles (SQLite-based) cũ:
- Dung lượng nhỏ hơn **10 - 15%**.
- Hỗ trợ **HTTP Range Requests** (chỉ tải đúng tile ô vuông cần thiết từ Server / Cloud Storage mà không cần unpack server).
- Đọc trực tiếp offline trong Flutter bằng plugin `maplibre_gl` hoặc native MapLibre SDK.

---

## 🛠️ Công cụ sử dụng: Planetiler

Chúng ta sử dụng [Planetiler](https://github.com/onthegomap/planetiler) — công cụ build vector tile bằng Java nhanh nhất thế giới hiện nay (nhanh hơn Tilemaker 10 lần).

### Yêu cầu hệ thống:
- **Java 17 / 21 LTS**
- **RAM**: Tối thiểu 2GB cho vùng nhỏ, 4GB-8GB cho toàn Việt Nam.

---

## 🚀 Các bước thực hiện

### 1. Tự động hóa qua Script Python (Khuyên dùng)

Chạy câu lệnh sau từ gốc thư mục dự án:

```bash
python data-pipeline/build_vector_tiles.py
```

Script sẽ tự động:
1. Kiểm tra môi trường Java.
2. Tải `planetiler.jar` v0.8.0 chính thức.
3. Đọc dữ liệu OSM thô từ `data-pipeline/data/raw/vietnam-latest.osm.pbf`.
4. Xuất file PMTiles ra thư mục `data-pipeline/data/output_pmtiles/`.
5. Cập nhật thống kê dung lượng vào `data-pipeline/data_sizes.md`.

---

### 2. Chạy thủ công Planetiler cho 1 vùng cụ thể

Nếu chỉ muốn build cho vùng TP.HCM (`metro_hcm`):

```bash
java -Xmx4g -jar data-pipeline/tools/planetiler.jar \
  --osm-path=data-pipeline/data/raw/vietnam-latest.osm.pbf \
  --output=data-pipeline/data/output_pmtiles/metro_hcm.pmtiles \
  --bounds=106.10,10.35,107.25,11.35 \
  --minzoom=0 \
  --maxzoom=14
```

---

## 🇻🇳 Cấu hình Hiển thị Tiếng Việt Có Dấu & Hẻm Nhỏ

### 1. Tag tên đường (Name Tags)
Planetiler mặc định giữ nguyên tất cả các tag tên của OpenStreetMap:
- `name`: Tên gốc (Tiếng Việt đầy đủ dấu, ví dụ: *Đường Nguyễn Trãi*, *Hẻm 182*)
- `name:vi`: Tên tiếng Việt
- `name:en`: Tên tiếng Anh (cho khách nước ngoài)

### 2. Mức Zoom (Zoom Levels)
- **Zoom 0 - 8**: Quốc lộ, ranh giới tỉnh thành, thành phố chính.
- **Zoom 9 - 12**: Đường chính nội thành (`primary`, `secondary`, `tertiary`).
- **Zoom 13 - 14**: Đường nhỏ, đường dân cư, và **hẻm nhỏ** (`residential`, `service`, `unclassified`).

---

## 🔍 Cách Kiểm Tra File PMTiles (Verification)

1. Mở trang web viewer online chính thức: [https://pmtiles.io](https://pmtiles.io)
2. Kéo thả file `metro_hcm.pmtiles` vừa build vào trình duyệt.
3. Zoom vào khu vực TP.HCM để kiểm tra:
   - ✅ Tên đường hiển thị đầy đủ dấu tiếng Việt (`Nguyễn Văn Cừ`, `Lê Lợi`).
   - ✅ Hẻm nhỏ xuất hiện khi zoom tới level 13-14.
   - ✅ Dung lượng file hợp lý (< 50MB cho vùng Metro).
