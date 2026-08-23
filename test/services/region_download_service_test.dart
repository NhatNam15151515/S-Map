import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/services.dart';

class FakeHiveBox implements Box<dynamic> {
  final Map<dynamic, dynamic> _storage = {};
  bool shouldThrow = false;

  @override
  bool get isOpen => true;

  @override
  Iterable<dynamic> get keys {
    if (shouldThrow) throw Exception('Hive keys read failed');
    return _storage.keys;
  }

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) {
    if (shouldThrow) throw Exception('Hive get failed');
    return _storage.containsKey(key) ? _storage[key] : defaultValue;
  }

  @override
  Future<void> put(dynamic key, dynamic value) async {
    if (shouldThrow) throw Exception('Hive put failed');
    _storage[key] = value;
  }

  @override
  Future<void> delete(dynamic key) async {
    if (shouldThrow) throw Exception('Hive delete failed');
    _storage.remove(key);
  }

  @override
  Future<int> clear() async {
    if (shouldThrow) throw Exception('Hive clear failed');
    final count = _storage.length;
    _storage.clear();
    return count;
  }

  @override
  int get length => _storage.length;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpClient implements HttpClient {
  final Uint8List zipBytes;
  final int statusCode;
  final Duration chunkDelay;

  FakeHttpClient({
    required this.zipBytes,
    this.statusCode = HttpStatus.ok,
    this.chunkDelay = Duration.zero,
  });

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return FakeHttpClientRequest(
      zipBytes: zipBytes,
      statusCode: statusCode,
      chunkDelay: chunkDelay,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpClientRequest implements HttpClientRequest {
  final Uint8List zipBytes;
  final int statusCode;
  final Duration chunkDelay;

  FakeHttpClientRequest({
    required this.zipBytes,
    required this.statusCode,
    this.chunkDelay = Duration.zero,
  });

  @override
  Future<HttpClientResponse> close() async {
    return FakeHttpClientResponse(
      zipBytes: zipBytes,
      statusCode: statusCode,
      chunkDelay: chunkDelay,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  final Uint8List zipBytes;
  @override
  final int statusCode;
  final Duration chunkDelay;

  FakeHttpClientResponse({
    required this.zipBytes,
    required this.statusCode,
    this.chunkDelay = Duration.zero,
  });

  @override
  int get contentLength => zipBytes.length;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final controller = StreamController<List<int>>();
    controller.onListen = () async {
      final half = zipBytes.length ~/ 2;
      controller.add(zipBytes.sublist(0, half));
      if (chunkDelay > Duration.zero) {
        await Future.delayed(chunkDelay);
      }
      if (!controller.isClosed) {
        controller.add(zipBytes.sublist(half));
        controller.close();
      }
    };
    return controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Uint8List createSampleZipArchive() {
  final archive = Archive();

  final pmtilesBytes = Uint8List.fromList([1, 2, 3, 4]);
  final ghzBytes = Uint8List.fromList([5, 6, 7, 8]);
  final dbBytes = Uint8List.fromList([9, 10, 11, 12]);
  final versionBytes = Uint8List.fromList('{"version": "1.0.0"}'.codeUnits);

  archive.addFile(ArchiveFile('metro_hcm.pmtiles', pmtilesBytes.length, pmtilesBytes));
  archive.addFile(ArchiveFile('metro_hcm.ghz', ghzBytes.length, ghzBytes));
  archive.addFile(ArchiveFile('metro_hcm_poi.db', dbBytes.length, dbBytes));
  archive.addFile(ArchiveFile('version.json', versionBytes.length, versionBytes));

  final encoded = ZipEncoder().encode(archive);
  return Uint8List.fromList(encoded);
}

void main() {
  late FakeHiveBox fakeBox;
  late Directory tempDir;
  late Uint8List sampleZipBytes;
  late FakeHttpClient fakeHttpClient;
  late RegionDownloadServiceImpl service;

  setUp(() async {
    fakeBox = FakeHiveBox();
    tempDir = await Directory.systemTemp.createTemp('smap_region_test_');
    sampleZipBytes = createSampleZipArchive();
    fakeHttpClient = FakeHttpClient(zipBytes: sampleZipBytes);

    service = RegionDownloadServiceImpl(
      customBox: fakeBox,
      customHttpClient: fakeHttpClient,
      customBaseDir: tempDir.path,
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('RegionDownloadServiceImpl Tests', () {
    test('getAvailableRegions returns default regions when box is empty', () async {
      final regions = await service.getAvailableRegions();

      expect(regions.length, 6);
      expect(regions.map((r) => r.id), containsAll([
        'metro_hcm',
        'metro_hn',
        'mien_nam',
        'mien_trung',
        'mien_bac',
        'vietnam',
      ]));
      expect(regions.every((r) => r.status == RegionDownloadStatus.notDownloaded), isTrue);
    });

    test('downloadAndExtractRegion downloads, extracts zip and saves metadata', () async {
      final regions = await service.getAvailableRegions();
      final targetRegion = regions.firstWhere((r) => r.id == 'metro_hcm');

      final progressEvents = <double>[];
      await for (final progress in service.downloadAndExtractRegion(
        targetRegion,
        onProgress: (p) => progressEvents.add(p),
      )) {
        expect(progress, greaterThanOrEqualTo(0.0));
        expect(progress, lessThanOrEqualTo(1.0));
      }

      expect(progressEvents, isNotEmpty);
      expect(progressEvents.last, equals(1.0));

      final extractedDir = Directory('${tempDir.path}/metro_hcm');
      expect(extractedDir.existsSync(), isTrue);
      expect(File('${extractedDir.path}/metro_hcm.pmtiles').existsSync(), isTrue);
      expect(File('${extractedDir.path}/metro_hcm.ghz').existsSync(), isTrue);
      expect(File('${extractedDir.path}/metro_hcm_poi.db').existsSync(), isTrue);
      expect(File('${extractedDir.path}/version.json').existsSync(), isTrue);

      final savedData = fakeBox.get('metro_hcm');
      expect(savedData, isNotNull);
      expect(savedData['status'], equals(RegionDownloadStatus.downloaded.name));
      expect(savedData['localVersion'], equals('1.0.0'));

      final downloaded = await service.getDownloadedRegions();
      expect(downloaded.length, 1);
      expect(downloaded.first.id, equals('metro_hcm'));
      expect(downloaded.first.isDownloaded, isTrue);
    });

    test('downloadAndExtractRegion throws HttpException on non-200 HTTP response', () async {
      final errorHttpClient = FakeHttpClient(
        zipBytes: sampleZipBytes,
        statusCode: HttpStatus.notFound,
      );
      final errorService = RegionDownloadServiceImpl(
        customBox: fakeBox,
        customHttpClient: errorHttpClient,
        customBaseDir: tempDir.path,
      );
      final regions = await errorService.getAvailableRegions();
      final targetRegion = regions.firstWhere((r) => r.id == 'metro_hcm');

      expect(
        errorService.downloadAndExtractRegion(targetRegion).drain(),
        throwsA(isA<HttpException>()),
      );
      expect(fakeBox.get('metro_hcm'), isNull);
      expect(File('${tempDir.path}/metro_hcm_temp.zip').existsSync(), isFalse);
    });

    test('cancelDownload cancels download stream and cleans temp zip file', () async {
      final delayedHttpClient = FakeHttpClient(
        zipBytes: sampleZipBytes,
        chunkDelay: const Duration(milliseconds: 50),
      );
      final cancelService = RegionDownloadServiceImpl(
        customBox: fakeBox,
        customHttpClient: delayedHttpClient,
        customBaseDir: tempDir.path,
      );
      final regions = await cancelService.getAvailableRegions();
      final targetRegion = regions.firstWhere((r) => r.id == 'metro_hcm');

      final stream = cancelService.downloadAndExtractRegion(targetRegion);
      final future = expectLater(stream.drain(), throwsA(isA<Exception>()));
      await Future.delayed(const Duration(milliseconds: 10));
      await cancelService.cancelDownload('metro_hcm');

      await future;
      expect(File('${tempDir.path}/metro_hcm_temp.zip').existsSync(), isFalse);
      expect(fakeBox.get('metro_hcm'), isNull);
    });

    test('deleteRegion removes local directory and deletes Hive record', () async {
      final regions = await service.getAvailableRegions();
      final targetRegion = regions.firstWhere((r) => r.id == 'metro_hcm');

      await service.downloadAndExtractRegion(targetRegion).drain();

      final extractedDir = Directory('${tempDir.path}/metro_hcm');
      expect(extractedDir.existsSync(), isTrue);
      expect(fakeBox.get('metro_hcm'), isNotNull);

      await service.deleteRegion('metro_hcm');

      expect(extractedDir.existsSync(), isFalse);
      expect(fakeBox.get('metro_hcm'), isNull);

      final downloaded = await service.getDownloadedRegions();
      expect(downloaded, isEmpty);
    });

    test('getTotalOfflineStorageUsage calculates bytes of extracted files', () async {
      final regions = await service.getAvailableRegions();
      final targetRegion = regions.firstWhere((r) => r.id == 'metro_hcm');

      await service.downloadAndExtractRegion(targetRegion).drain();

      final storageBytes = await service.getTotalOfflineStorageUsage();
      expect(storageBytes, greaterThan(0));
    });

    test('checkRegionVersion returns region model', () async {
      final region = await service.checkRegionVersion('metro_hn');
      expect(region, isNotNull);
      expect(region!.name, equals('Vùng Hà Nội'));

      final nonExistent = await service.checkRegionVersion('non_existent');
      expect(nonExistent, isNull);
    });
  });

  group('NoOpRegionDownloadService Tests', () {
    test('NoOpRegionDownloadService functions correctly without throwing', () async {
      final noOp = NoOpRegionDownloadService();
      final regions = await noOp.getAvailableRegions();
      expect(regions.length, 6);

      final progress = await noOp.downloadAndExtractRegion(regions.first).toList();
      expect(progress, containsAllInOrder([0.5, 1.0]));

      await noOp.deleteRegion('metro_hcm');
      final usage = await noOp.getTotalOfflineStorageUsage();
      expect(usage, equals(0));
    });
  });
}
