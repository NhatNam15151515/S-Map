# Tích hợp Overture Maps Places vào S-Map POI Database

## Mục tiêu

Bổ sung các địa điểm từ Overture Maps Places vào pipeline POI hiện tại để tăng
độ phủ quán ăn, cà phê, cửa hàng và dịch vụ mà OSM có thể còn thiếu. Overture
là nguồn bổ sung, không thay thế OSM. Schema SQLite hiện tại của S-Map được giữ
nguyên để Flutter tiếp tục đọc được database mới.

## Quyết định đã chốt

### 1. Phạm vi tải dữ liệu: toàn quốc

Tải Overture Places một lần theo bbox toàn quốc, lưu cache dùng chung, sau đó
lọc lại theo bbox của từng region khi build. Cách này khớp với việc pipeline
đang đọc một file OSM PBF toàn quốc rồi build các database khu vực.

Cache ưu tiên GeoJSONSeq (`.geojsonseq`) để đọc theo từng dòng, tránh nạp toàn
bộ dữ liệu quốc gia vào RAM. Cache phải có metadata ngày tải và bbox. Bbox Việt
Nam là hình chữ nhật nên loader cũng kiểm tra `addresses[].country` khi trường
này có mặt; không coi bbox là polygon biên giới chính xác.

### 2. Xử lý trùng OSM ↔ Overture: hợp nhất có điều kiện

Không ưu tiên cứng toàn bộ bản ghi OSM hoặc Overture. Hai nguồn được đánh giá
theo từng địa điểm:

- Overture-only: thêm vào database.
- Trùng tên và rất gần nhau: gộp thành một bản ghi.
- Địa chỉ, tên đường, số nhà và thành phố được hợp nhất theo trường; nguồn nào
  có trường đầy đủ hơn giữ giá trị đó, nguồn kia bổ sung trường còn thiếu.
- Nếu cả hai nguồn có giá trị khác nhau, chọn bản ghi canonical theo thứ tự:
  độ đầy đủ địa chỉ → confidence → timestamp cập nhật → OSM làm tie-breaker
  ổn định. Đây không phải quy tắc “OSM luôn thắng”.
- Cùng vị trí nhưng khác tên sẽ không tự động gộp nếu không có thêm bằng chứng
  từ địa chỉ/category; tránh xóa nhầm địa điểm đã đổi tên.

Ngưỡng matching:

- Tối đa 50m.
- Tên tương đồng (`SequenceMatcher >= 0.80`) được chấp nhận trong 25m.
- Chỉ mở rộng tới 50m khi tên tương đồng và số nhà + tên đường cũng khớp.
- Bỏ qua các record OSM loại `address` và `street` khi dedup POI.

Timestamp chỉ là tín hiệu phụ: timestamp OSM là thời điểm element được chỉnh
sửa, còn `sources[].update_time` của Overture là thời điểm cập nhật nguồn. Hai
giá trị không đồng nghĩa với việc địa điểm đang mở hoặc dữ liệu nào chính xác
hơn.

## Thay đổi dự kiến

### Script tải dữ liệu Overture

#### `data-pipeline/download_overture_places.py`

- Gọi official `overturemaps` CLI để tải type `place` từ AWS S3.
- Mặc định tải bbox `vietnam` và ghi vào
  `data-pipeline/data/overture/vietnam_places.geojsonseq`.
- Ghi metadata vào `vietnam_places.metadata.json`.
- Dùng file `.part` và rename atomic sau khi tải thành công.
- Có `--force`, `--bbox`, `--output` và `--metadata`.
- Nếu chưa cài package, báo lệnh `python -m pip install overturemaps`.

### Tích hợp vào `build_poi_database.py`

- `load_overture_places()` hỗ trợ GeoJSONSeq và GeoJSON FeatureCollection.
- Chỉ nhận geometry `Point`, kiểm tra bbox region và loại bỏ record
  `permanently_closed`/confidence bằng 0.
- Map dữ liệu:
  - `names.primary` → `name`.
  - `basic_category` → category chính; fallback `taxonomy.primary`, sau đó
    `categories.primary` của dữ liệu cũ.
  - `addresses[0].freeform` → `address`.
  - `addresses[0].street`/`number` → `street`/`housenumber` khi có.
  - `addresses[0].locality` → `city`, đồng thời dùng thêm `region` và address
    để tạo `admin_aliases`.
  - geometry → `lat`, `lon`.
  - `overture:<id>` → `osm_id` để nhận diện nguồn.
- `iter_merged_overture_pois()` thực hiện spatial grid + matching có điều kiện
  và stream record vào SQLite; `merge_overture_pois()` là wrapper dạng list cho
  test/region nhỏ.
- Build log số record Overture đã đọc, đã gộp và đã thêm.
- Metadata nguồn (`_source`, `_source_updated_at`, `_confidence`) chỉ tồn tại
  trong bộ nhớ build và bị loại trước khi insert; schema SQLite không đổi.
- Có `--no-overture` để tạo baseline OSM hoặc debug cache.
- Có `--reuse-existing-osm-db` để merge nhanh vào POI DB OSM đã build sẵn mà
  không phải đọc lại PBF toàn quốc.

### Config

Thêm các đường dẫn:

- `OVERTURE_DIR`.
- `OVERTURE_GEOJSONSEQ`.
- `OVERTURE_GEOJSON` cho cache legacy.
- `OVERTURE_METADATA`.

## Verification Plan

### Test không cần internet

- Compile các script Python.
- Test loader GeoJSONSeq/GeoJSON với dữ liệu giả lập.
- Test lọc country, bỏ record đóng cửa và category fallback.
- Test các trường hợp dedup: tên giống, tên gần giống + cùng địa chỉ, cùng vị
  trí nhưng khác tên, Overture-only.
- Test SQLite insert không bị ảnh hưởng bởi metadata nội bộ.

### Test có internet

```powershell
python data-pipeline/download_overture_places.py --bbox 102.1,8.5,109.5,23.4
python data-pipeline/build_poi_database.py --region vietnam
```

Khi đã có POI DB OSM sẵn và chỉ cần merge nguồn mới, có thể dùng:

```powershell
python data-pipeline/build_poi_database.py --region vietnam --reuse-existing-osm-db
```

### Kiểm tra thủ công

- So sánh baseline OSM (`--no-overture`) với bản merged về số lượng và dung
  lượng database.
- Kiểm tra benchmark FTS5 và spatial query vẫn trong mục tiêu hiện tại.
- Spot-check POI ở Q1, Bình Thạnh, Tân Bình và một số tỉnh ngoài đô thị lớn.
- Kiểm tra không có record ngoài Việt Nam do bbox chữ nhật.
- Kiểm tra app Flutter vẫn đọc được database mới vì schema không đổi.

## Kết quả lần chạy đầu tiên

- Cache Overture: 2.691.503.888 bytes, 2.011.860 dòng GeoJSONSeq.
- Overture hợp lệ sau lọc: 1.503.087 record; gộp 12.976; thêm mới 1.490.111.
- Database toàn quốc sau merge: 1.764.681 record, dung lượng khoảng 839 MB.
- `PRAGMA integrity_check`: `ok`; số dòng `poi`, `poi_fts` và `poi_rtree` khớp
  nhau; schema SQLite không đổi.

## Trạng thái chuẩn bị release data

- Package: `map-data-v1.1.0/vietnam.zip`.
- Dung lượng ZIP: `928,931,146` bytes (885.90 MB).
- SHA256 ZIP: `3dfe7113a65635a630d67dc0f381e96157faaf7a6b1cc5eaeb99cee3ba5a3b62`.
- `version.json` trong package đã ghi version `1.1.0` và checksum của từng file.
- Database đầy đủ được phát hành trong package tải về; `assets/database/poi.db`
  vẫn là fallback nhẹ để APK không bị phình lên gần 1 GB. Sau khi người dùng
  tải vùng Toàn quốc, `PoiDatabaseService` ưu tiên DB trong package.

## Tài liệu nguồn

- [Overture Places schema](https://docs.overturemaps.org/schema/reference/places/place/)
- [Overture Places taxonomy](https://docs.overturemaps.org/schema/reference/places/types/taxonomy/)
- [Overture Maps Python CLI](https://github.com/OvertureMaps/overturemaps-py)
