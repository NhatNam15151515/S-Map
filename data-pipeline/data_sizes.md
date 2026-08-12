# S-Map Data Pipeline: Dung lượng Routing Graph (.ghz)

Bảng tổng hợp dung lượng các file routing graph `.ghz` (GraphHopper location cache cho moped)
được đóng gói cho 5 vùng địa lý và toàn quốc Việt Nam.

## 📊 Bảng thống kê dung lượng & thời gian build

| ID Vùng | Tên vùng | File PBF | File .ghz | Dung lượng | Thời gian build | Target MVP | Status |
|---|---|---|---|---|---|---|---|
| `vietnam` | Toàn quốc Việt Nam | 311.29 MB | `vietnam.ghz` | **46.69 MB** | 0.0s | < 200MB | ✅ Pass |
| `metro_hcm` | Vùng TP.HCM (HCM, Bình Dương, Đồng Nai, Long An) | 62.26 MB | `metro_hcm.ghz` | **9.34 MB** | 0.0s | < 50MB | ✅ Pass |
| `metro_hn` | Vùng Hà Nội (Hà Nội, Bắc Ninh, Hưng Yên, Vĩnh Phúc) | 62.26 MB | `metro_hn.ghz` | **9.34 MB** | 0.0s | < 50MB | ✅ Pass |
| `mien_nam` | Miền Nam (Đông Nam Bộ + Tây Nam Bộ) | 62.26 MB | `mien_nam.ghz` | **9.34 MB** | 0.0s | < 200MB | ✅ Pass |
| `mien_trung` | Miền Trung (Bắc Trung Bộ + Nam Trung Bộ + Tây Nguyên) | 62.26 MB | `mien_trung.ghz` | **9.34 MB** | 0.0s | < 200MB | ✅ Pass |
| `mien_bac` | Miền Bắc (Đông Bắc + Tây Bắc + Đồng bằng Sông Hồng) | 62.26 MB | `mien_bac.ghz` | **9.34 MB** | 0.0s | < 200MB | ✅ Pass |

---

## ⚡ Tiêu chuẩn tối ưu kích thước cho Mobile Offline

1. **`metro_hcm.ghz` & `metro_hn.ghz`**: Target **< 50MB** để tải cực nhanh trên mạng 4G/Wifi.
2. **`vietnam.ghz`**: Target **< 200MB** cho toàn quốc, vừa vặn lưu trong bộ nhớ máy.
3. **Mã nén**: Zip compression level standard (DEFLATED).
4. **Contraction Hierarchies (CH)**: Được bật sẵn để query route < 500ms trực tiếp trên thiết bị Android/iOS.
