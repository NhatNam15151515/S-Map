# S-Map Data Pipeline: Dung lượng Routing Graph (.ghz)

Bảng tổng hợp dung lượng các file routing graph `.ghz` (GraphHopper location cache cho moped)
được đóng gói cho 5 vùng địa lý và toàn quốc Việt Nam.

## 📊 Bảng thống kê dung lượng & thời gian build

| ID Vùng | Tên vùng | File PBF | File .ghz | Dung lượng | Thời gian build | Target MVP | Status |
|---|---|---|---|---|---|---|---|
| `vietnam` | Toàn quốc Việt Nam | 311.29 MB | `vietnam.ghz` | **300.89 MB** | 121.8s | < 200MB | ✅ Built |

---

## ⚡ Tiêu chuẩn tối ưu kích thước cho Mobile Offline

1. **`metro_hcm.ghz` & `metro_hn.ghz`**: Target **< 50MB** để tải cực nhanh trên mạng 4G/Wifi.
2. **`vietnam.ghz`**: Target **< 200MB** cho toàn quốc, vừa vặn lưu trong bộ nhớ máy.
3. **Mã nén**: Zip compression level standard (DEFLATED).
4. **Contraction Hierarchies (CH)**: Được bật sẵn để query route < 500ms trực tiếp trên thiết bị Android/iOS.
