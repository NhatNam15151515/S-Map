import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/utils/trip_address_resolver.dart';
import 'package:s_map/commons/utils/trip_leg_extractor.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class FakePoiRepository implements IPoiRepository {
  List<PoiModel> candidatesToReturn = [];
  double? lastMinLat;
  double? lastMaxLat;
  double? lastMinLon;
  double? lastMaxLon;

  @override
  Future<List<PoiModel>> searchInBounds({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    String? query,
    String? category,
    int limit = 50,
  }) async {
    lastMinLat = minLat;
    lastMaxLat = maxLat;
    lastMinLon = minLon;
    lastMaxLon = maxLon;
    return candidatesToReturn;
  }

  @override
  Future<List<PoiModel>> searchByName(String query, {int limit = 20}) async => [];

  @override
  Future<List<PoiModel>> searchByNameAscii(String query, {int limit = 20}) async => [];

  @override
  Future<List<PoiModel>> search(String query, {int limit = 20}) async => [];

  @override
  Future<List<String>> getSuggestions(String query, {int limit = 10}) async => [];

  @override
  Future<PoiModel?> getPoiById(int id) async => null;
}

class FakeRoutingService implements IRoutingService {
  SnappedRoadPoint snapResultToReturn = const SnappedRoadPoint(
    isSnapped: false,
    originalLat: 0.0,
    originalLon: 0.0,
    snappedLat: 0.0,
    snappedLon: 0.0,
  );

  @override
  Future<SnappedRoadPoint> snapToRoad({
    required double lat,
    required double lon,
  }) async {
    return snapResultToReturn;
  }

  @override
  Future<bool> initGraphHopper(String graphPath) async => true;

  @override
  Future<RouteResult> getRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  }) async =>
      const RouteResult(isSuccess: false);

  @override
  Future<bool> isInitialized() async => true;

  @override
  Future<bool> dispose() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TripAddressResolver Unit Tests', () {
    late FakePoiRepository fakePoiRepo;
    late FakeRoutingService fakeRoutingService;

    // Tọa độ mẫu thử nghiệm tại Đường Tam Đảo
    const sampleLat = 10.7878;
    const sampleLon = 106.7045;

    setUp(() {
      fakePoiRepo = FakePoiRepository();
      fakeRoutingService = FakeRoutingService();
    });

    test('Ưu tiên 1 cao nhất: Bắt đúng số nhà + tên đường ngay cả khi có POI khác ở gần hơn', () async {
      fakePoiRepo.candidatesToReturn = [
        // POI ở rất gần (cách ~2m) nhưng là ATM không có số nhà
        const PoiModel(
          id: 1,
          name: 'Cây ATM Vietcombank',
          nameAscii: 'Cay ATM Vietcombank',
          lat: 10.78781,
          lon: 106.70451,
        ),
        // Căn nhà ở cách ~5m có đầy đủ số nhà và tên đường
        const PoiModel(
          id: 2,
          name: 'Nhà dân',
          nameAscii: 'Nha dan',
          housenumber: '84',
          street: 'Đường Tam Đảo',
          lat: 10.78784,
          lon: 106.70454,
        ),
      ];

      final result = await TripAddressResolver.resolveAddressAtCoordinate(
        sampleLat,
        sampleLon,
        poiRepository: fakePoiRepo,
        routingService: fakeRoutingService,
      );

      // Phải ưu tiên bắt đúng "84 Đường Tam Đảo", không bị bốc nhầm Cây ATM
      expect(result, equals('84 Đường Tam Đảo'));
    });

    test('Ưu tiên 2: Trả về địa chỉ chi tiết (address) nếu không có cặp housenumber + street', () async {
      fakePoiRepo.candidatesToReturn = [
        const PoiModel(
          id: 3,
          name: 'Văn phòng',
          nameAscii: 'Van phong',
          address: '84 Đường Tam Đảo, Phường 15, Quận 10',
          lat: 10.78782,
          lon: 106.70452,
        ),
      ];

      final result = await TripAddressResolver.resolveAddressAtCoordinate(
        sampleLat,
        sampleLon,
        poiRepository: fakePoiRepo,
        routingService: fakeRoutingService,
      );

      expect(result, equals('84 Đường Tam Đảo, Phường 15, Quận 10'));
    });

    test('Ưu tiên 3: Trả về tên con đường nếu POI chỉ ghi nhận tên đường', () async {
      fakePoiRepo.candidatesToReturn = [
        const PoiModel(
          id: 4,
          name: 'Đoạn đường',
          nameAscii: 'Doan duong',
          street: 'Đường Tam Đảo',
          lat: 10.78782,
          lon: 106.70452,
        ),
      ];

      final result = await TripAddressResolver.resolveAddressAtCoordinate(
        sampleLat,
        sampleLon,
        poiRepository: fakePoiRepo,
        routingService: fakeRoutingService,
      );

      expect(result, equals('Đường Tam Đảo'));
    });

    test('Ưu tiên 4: Trả về tên POI/địa điểm nếu không có thông tin đường phố', () async {
      fakePoiRepo.candidatesToReturn = [
        const PoiModel(
          id: 5,
          name: 'Highlands Coffee Tam Đảo',
          nameAscii: 'Highlands Coffee Tam Dao',
          lat: 10.78783,
          lon: 106.70453,
        ),
      ];

      final result = await TripAddressResolver.resolveAddressAtCoordinate(
        sampleLat,
        sampleLon,
        poiRepository: fakePoiRepo,
        routingService: fakeRoutingService,
      );

      expect(result, equals('Highlands Coffee Tam Đảo'));
    });

    test('Ưu tiên 5 (Fallback snapToRoad): Nắn vào tim đường khi POI database trống', () async {
      fakePoiRepo.candidatesToReturn = []; // Không có POI nào trong database
      fakeRoutingService.snapResultToReturn = const SnappedRoadPoint(
        isSnapped: true,
        streetName: 'Đường Tô Hiến Thành',
        distanceToRoad: 8.5,
        originalLat: sampleLat,
        originalLon: sampleLon,
        snappedLat: 10.78785,
        snappedLon: 106.70455,
      );

      final result = await TripAddressResolver.resolveAddressAtCoordinate(
        sampleLat,
        sampleLon,
        poiRepository: fakePoiRepo,
        routingService: fakeRoutingService,
      );

      expect(result, equals('Đường Tô Hiến Thành'));
    });

    test('Bỏ qua POI nằm ngoài bán kính maxRadiusMeters', () async {
      fakePoiRepo.candidatesToReturn = [
        // POI ở rất xa (~500m)
        const PoiModel(
          id: 6,
          name: 'Nhà xa',
          nameAscii: 'Nha xa',
          housenumber: '999',
          street: 'Đường Xa Lộ',
          lat: 10.7920,
          lon: 106.7090,
        ),
      ];

      final result = await TripAddressResolver.resolveAddressAtCoordinate(
        sampleLat,
        sampleLon,
        maxRadiusMeters: 30.0,
        poiRepository: fakePoiRepo,
        routingService: fakeRoutingService,
      );

      expect(result, isNull);
    });

    test('Trả về null an toàn khi cả POI database và snapToRoad đều không có dữ liệu', () async {
      fakePoiRepo.candidatesToReturn = [];
      fakeRoutingService.snapResultToReturn = const SnappedRoadPoint(
        isSnapped: false,
        streetName: '',
        distanceToRoad: 999.0,
        originalLat: sampleLat,
        originalLon: sampleLon,
        snappedLat: 0.0,
        snappedLon: 0.0,
      );

      final result = await TripAddressResolver.resolveAddressAtCoordinate(
        sampleLat,
        sampleLon,
        poiRepository: fakePoiRepo,
        routingService: fakeRoutingService,
      );

      expect(result, isNull);
    });
  });

  group('TripLegExtractor Address Integration Tests', () {
    test('Sử dụng customOrigin và customStopped đã resolve thay cho toạ độ thô', () {
      final trip = TripRecordModel(
        id: 'test_trip_1',
        startTime: DateTime.now().subtract(const Duration(minutes: 10)),
        endTime: DateTime.now(),
        durationMs: 600000,
        distanceMeters: 25.0,
        avgSpeedKmh: 0.0,
        topSpeedKmh: 0.0,
        hasArrived: false,
        polyline: const [
          [10.7878, 106.7045],
          [10.7879, 106.7046],
        ],
        createdAt: DateTime.now(),
      );

      final legs = TripLegExtractor.extractLegs(
        trip,
        customOrigin: '84 Đường Tam Đảo',
        customStopped: 'Đường Tô Hiến Thành',
      );

      expect(legs, isNotEmpty);
      expect(legs.first.title, contains('84 Đường Tam Đảo'));
      expect(legs.first.title, contains('Đường Tô Hiến Thành'));
      expect(legs.first.title, isNot(contains('10.7878')));
    });

    test('Lọc sạch toạ độ thô khi không có địa chỉ', () {
      final trip = TripRecordModel(
        id: 'test_trip_2',
        startTime: DateTime.now().subtract(const Duration(minutes: 5)),
        endTime: DateTime.now(),
        durationMs: 300000,
        distanceMeters: 10.0,
        avgSpeedKmh: 0.0,
        topSpeedKmh: 0.0,
        hasArrived: false,
        originName: '10.7878, 106.7045',
        stoppedName: '10.7879, 106.7046',
        polyline: const [
          [10.7878, 106.7045],
          [10.7879, 106.7046],
        ],
        createdAt: DateTime.now(),
      );

      final legs = TripLegExtractor.extractLegs(trip);

      expect(legs, isNotEmpty);
      // Toạ độ dạng "10.7878, 106.7045" phải được lọc thành nhãn fallback chuẩn
      expect(legs.first.title, isNot(contains('10.7878, 106.7045')));
    });
  });
}
