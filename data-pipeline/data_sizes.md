# S-Map Data Pipeline: Dung lượng Routing Graph (.ghz)

Bảng tổng hợp dung lượng các file routing graph `.ghz` (GraphHopper location cache cho moped)
được đóng gói cho 5 vùng địa lý và toàn quốc Việt Nam.

## 📊 Bảng thống kê dung lượng & thời gian build

| ID Vùng | Tên vùng | File PBF | File .ghz | Dung lượng | Thời gian build | Target MVP | Status |
|---|---|---|---|---|---|---|---|
| `vietnam` | Toàn quốc Việt Nam | 311.29 MB | `vietnam.ghz` | **N/A** | 0.0s | < 200MB | ⬜ Pending (thiếu tool) |
| `metro_hcm` | Vùng TP.HCM (HCM, Bình Dương, Đồng Nai, Long An) | N/A | `metro_hcm.ghz` | **N/A** | 0.0s | < 50MB | ⬜ Pending (thiếu tool) |
| `metro_hn` | Vùng Hà Nội (Hà Nội, Bắc Ninh, Hưng Yên, Vĩnh Phúc) | N/A | `metro_hn.ghz` | **N/A** | 0.0s | < 50MB | ⬜ Pending (thiếu tool) |
| `mien_nam` | Miền Nam (Đông Nam Bộ + Tây Nam Bộ) | N/A | `mien_nam.ghz` | **N/A** | 0.0s | < 200MB | ⬜ Pending (thiếu tool) |
| `mien_trung` | Miền Trung (Bắc Trung Bộ + Nam Trung Bộ + Tây Nguyên) | N/A | `mien_trung.ghz` | **N/A** | 0.0s | < 200MB | ⬜ Pending (thiếu tool) |
| `mien_bac` | Miền Bắc (Đông Bắc + Tây Bắc + Đồng bằng Sông Hồng) | N/A | `mien_bac.ghz` | **N/A** | 0.0s | < 200MB | ⬜ Pending (thiếu tool) |

---

## ⚡ Tiêu chuẩn tối ưu kích thước cho Mobile Offline

1. **`metro_hcm.ghz` & `metro_hn.ghz`**: Target **< 50MB** để tải cực nhanh trên mạng 4G/Wifi.
2. **`vietnam.ghz`**: Target **< 200MB** cho toàn quốc, vừa vặn lưu trong bộ nhớ máy.
3. **Mã nén**: Zip compression level standard (DEFLATED).
4. **Contraction Hierarchies (CH)**: Được bật sẵn để query route < 500ms trực tiếp trên thiết bị Android/iOS.

## POI SQLite Database (.db)

| Vùng địa lý | Tên File | Số lượng POI | Dung lượng file | Thời gian Query FTS5 |
| ----------- | -------- | ------------ | --------------- | -------------------- |
| Vùng TP.HCM (HCM, Bình Dương, Đồng Nai, Long An) | `metro_hcm_poi.db` | 39,807 địa điểm | 10.49 MB | < 20 ms |

## 📦 Bảng thống kê Gói Zip Dữ Liệu Vùng (Offline Region Packages)

| ID Vùng | Tên Vùng | File Zip Đóng Gói | Dung Lượng Zip | Nội Dung Bên Trong | Status |
|---|---|---|---|---|---|
| `metro_hcm` | Vùng TP.HCM (HCM, Bình Dương, Đồng Nai, Long An) | `metro_hcm.zip` | **4.30 MB** | `.pmtiles` + `.ghz` + `.db` + `version.json` | ✅ Ready |
