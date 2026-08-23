import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

// Backward compatibility alias
typedef RegionDownloadService = IRegionDownloadService;

class RegionDownloadServiceImpl implements IRegionDownloadService {
  static const String boxName = 'offline_regions_box';
  static const String basePackageUrl =
      'https://raw.githubusercontent.com/NhatNam15151515/S-Map/dev-w2/data-pipeline/data/output_packages';

  final Box<dynamic>? _customBox;
  final HttpClient? _customHttpClient;
  final String? _customBaseDir;
  final Map<String, bool> _cancellationMap = {};
  Box<dynamic>? _box;

  RegionDownloadServiceImpl({
    Box<dynamic>? customBox,
    HttpClient? customHttpClient,
    String? customBaseDir,
  })  : _customBox = customBox,
        _customHttpClient = customHttpClient,
        _customBaseDir = customBaseDir;

  static final RegionDownloadServiceImpl instance = RegionDownloadServiceImpl();

  static const List<RegionModel> defaultRegions = [
    RegionModel(
      id: 'metro_hcm',
      name: 'Vùng TP.HCM',
      description: 'TP.HCM, Bình Dương, Đồng Nai, Long An',
      bbox: [106.10, 10.35, 107.25, 11.35],
      downloadUrl: '$basePackageUrl/metro_hcm.zip',
      sizeBytes: 4509903,
      version: '1.0.0',
    ),
    RegionModel(
      id: 'metro_hn',
      name: 'Vùng Hà Nội',
      description: 'Hà Nội, Bắc Ninh, Hưng Yên, Vĩnh Phúc',
      bbox: [105.30, 20.60, 106.30, 21.40],
      downloadUrl: '$basePackageUrl/metro_hn.zip',
      sizeBytes: 4718592,
      version: '1.0.0',
    ),
    RegionModel(
      id: 'mien_nam',
      name: 'Miền Nam',
      description: 'Đông Nam Bộ và Tây Nam Bộ',
      bbox: [104.40, 8.50, 107.80, 12.00],
      downloadUrl: '$basePackageUrl/mien_nam.zip',
      sizeBytes: 15728640,
      version: '1.0.0',
    ),
    RegionModel(
      id: 'mien_trung',
      name: 'Miền Trung',
      description: 'Bắc Trung Bộ, Nam Trung Bộ và Tây Nguyên',
      bbox: [105.00, 11.50, 109.50, 19.50],
      downloadUrl: '$basePackageUrl/mien_trung.zip',
      sizeBytes: 20971520,
      version: '1.0.0',
    ),
    RegionModel(
      id: 'mien_bac',
      name: 'Miền Bắc',
      description: 'Đông Bắc, Tây Bắc và Đồng bằng Sông Hồng',
      bbox: [102.10, 19.50, 108.00, 23.40],
      downloadUrl: '$basePackageUrl/mien_bac.zip',
      sizeBytes: 23068672,
      version: '1.0.0',
    ),
    RegionModel(
      id: 'vietnam',
      name: 'Toàn quốc Việt Nam',
      description: 'Toàn bộ 63 tỉnh thành Việt Nam',
      bbox: [102.10, 8.50, 109.50, 23.40],
      downloadUrl: '$basePackageUrl/vietnam.zip',
      sizeBytes: 52428800,
      version: '1.0.0',
    ),
  ];

  Future<Box<dynamic>> _getBox() async {
    if (_customBox != null) return _customBox;
    if (_box != null && _box!.isOpen) return _box!;

    try {
      if (!Hive.isBoxOpen(boxName)) {
        _box = await Hive.openBox<dynamic>(boxName);
      } else {
        _box = Hive.box<dynamic>(boxName);
      }
    } catch (e) {
      DLog.error('Lỗi mở Hive box $boxName: $e');
      _box = await Hive.openBox<dynamic>(boxName);
    }
    return _box!;
  }

  Future<String> _getRegionsStorageDirectory() async {
    if (_customBaseDir != null) {
      final dir = Directory(_customBaseDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return dir.path;
    }
    final appDocDir = await getApplicationDocumentsDirectory();
    final regionsDir = Directory(p.join(appDocDir.path, 'regions'));
    if (!regionsDir.existsSync()) {
      regionsDir.createSync(recursive: true);
    }
    return regionsDir.path;
  }

  @override
  Future<List<RegionModel>> getAvailableRegions() async {
    try {
      final box = await _getBox();
      final regions = <RegionModel>[];

      for (final defaultRegion in defaultRegions) {
        final raw = box.get(defaultRegion.id);
        if (raw != null && raw is Map) {
          final map = Map<String, dynamic>.from(raw);
          regions.add(RegionModel.fromMap(map));
        } else {
          regions.add(defaultRegion);
        }
      }

      return regions;
    } catch (e) {
      DLog.error('❌ [RegionDownloadService] Lỗi lấy danh sách vùng: $e');
      return defaultRegions;
    }
  }

  @override
  Future<List<RegionModel>> getDownloadedRegions() async {
    try {
      final all = await getAvailableRegions();
      return all.where((r) => r.isDownloaded).toList();
    } catch (e) {
      DLog.error('❌ [RegionDownloadService] Lỗi lấy vùng đã tải: $e');
      return [];
    }
  }

  @override
  Future<int> getTotalOfflineStorageUsage() async {
    try {
      final regionsBaseDir = await _getRegionsStorageDirectory();
      final dir = Directory(regionsBaseDir);
      if (!dir.existsSync()) return 0;

      int totalBytes = 0;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }
      return totalBytes;
    } catch (e) {
      DLog.error('❌ [RegionDownloadService] Lỗi tính dung lượng bộ nhớ: $e');
      return 0;
    }
  }

  @override
  Future<RegionModel?> checkRegionVersion(String regionId) async {
    final all = await getAvailableRegions();
    try {
      final region = all.firstWhere((r) => r.id == regionId);
      return region;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<double> downloadAndExtractRegion(
    RegionModel region, {
    void Function(double progress)? onProgress,
    String? customDownloadUrl,
  }) async* {
    _cancellationMap[region.id] = false;
    final url = customDownloadUrl ?? region.downloadUrl;
    final regionsBaseDir = await _getRegionsStorageDirectory();
    final targetDir = Directory(p.join(regionsBaseDir, region.id));
    final tempZipFile = File(p.join(regionsBaseDir, '${region.id}_temp.zip'));

    final bool ownsClient = _customHttpClient == null;
    final client = _customHttpClient ?? HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    IOSink? sink;
    double lastEmittedProgress = 0.05;

    try {
      yield 0.05;
      onProgress?.call(0.05);

      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Tải gói dữ liệu thất bại với mã lỗi HTTP ${response.statusCode}',
          uri: Uri.parse(url),
        );
      }

      final totalBytes = response.contentLength > 0 ? response.contentLength : region.sizeBytes;
      int receivedBytes = 0;

      final activeSink = tempZipFile.openWrite();
      sink = activeSink;

      await for (final chunk in response) {
        if (_cancellationMap[region.id] == true) {
          await activeSink.close();
          sink = null;
          if (tempZipFile.existsSync()) tempZipFile.deleteSync();
          throw Exception('Quá trình tải đã bị hủy bởi người dùng');
        }

        activeSink.add(chunk);
        receivedBytes += chunk.length;

        final downloadProgress = totalBytes > 0
            ? (0.05 + (receivedBytes / totalBytes) * 0.65).clamp(0.05, 0.70)
            : 0.5;

        if (downloadProgress - lastEmittedProgress >= 0.01) {
          lastEmittedProgress = downloadProgress;
          yield downloadProgress;
          onProgress?.call(downloadProgress);
        }
      }

      await activeSink.flush();
      await activeSink.close();
      sink = null;

      // Bắt đầu giải nén (0.75 -> 1.0)
      yield 0.75;
      onProgress?.call(0.75);
      lastEmittedProgress = 0.75;

      if (_cancellationMap[region.id] == true) {
        if (tempZipFile.existsSync()) tempZipFile.deleteSync();
        throw Exception('Quá trình tải đã bị hủy bởi người dùng');
      }

      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }

      final inputStream = InputFileStream(tempZipFile.path);
      final archive = ZipDecoder().decodeStream(inputStream);

      int extractedFiles = 0;
      final totalFiles = archive.length;

      for (final file in archive) {
        if (_cancellationMap[region.id] == true) {
          inputStream.close();
          if (tempZipFile.existsSync()) tempZipFile.deleteSync();
          throw Exception('Quá trình tải đã bị hủy bởi người dùng');
        }

        final filename = p.basename(file.name);
        if (file.isFile) {
          final outFile = File(p.join(targetDir.path, filename));
          final outputStream = OutputFileStream(outFile.path);
          file.writeContent(outputStream);
          outputStream.closeSync();
        }
        extractedFiles++;
        final extractProgress = totalFiles > 0
            ? (0.75 + (extractedFiles / totalFiles) * 0.23).clamp(0.75, 0.98)
            : 0.9;

        if (extractProgress - lastEmittedProgress >= 0.01) {
          lastEmittedProgress = extractProgress;
          yield extractProgress;
          onProgress?.call(extractProgress);
        }
      }

      inputStream.close();

      if (tempZipFile.existsSync()) {
        tempZipFile.deleteSync();
      }

      // Lưu thông tin vào Hive
      final box = await _getBox();
      final updatedRegion = region.copyWith(
        status: RegionDownloadStatus.downloaded,
        localVersion: region.version,
        downloadProgress: 1.0,
        downloadedAt: DateTime.now(),
        localPath: targetDir.path,
      );

      await box.put(region.id, updatedRegion.toMap());

      yield 1.0;
      onProgress?.call(1.0);
      DLog.info('✅ [RegionDownloadService] Đã tải và giải nén thành công vùng: ${region.name}');
    } catch (e) {
      DLog.error('❌ [RegionDownloadService] Lỗi tải vùng ${region.name}: $e');
      if (tempZipFile.existsSync()) {
        try {
          tempZipFile.deleteSync();
        } catch (_) {}
      }
      rethrow;
    } finally {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      if (ownsClient) {
        client.close(force: true);
      }
      _cancellationMap.remove(region.id);
    }
  }

  @override
  Future<void> cancelDownload(String regionId) async {
    _cancellationMap[regionId] = true;
  }

  @override
  Future<void> deleteRegion(String regionId) async {
    try {
      final regionsBaseDir = await _getRegionsStorageDirectory();
      final targetDir = Directory(p.join(regionsBaseDir, regionId));
      if (targetDir.existsSync()) {
        targetDir.deleteSync(recursive: true);
      }

      final box = await _getBox();
      await box.delete(regionId);
      DLog.info('🗑️ [RegionDownloadService] Đã xóa thành công vùng $regionId');
    } catch (e) {
      DLog.error('❌ [RegionDownloadService] Lỗi xóa vùng $regionId: $e');
      rethrow;
    }
  }
}

class NoOpRegionDownloadService implements IRegionDownloadService {
  @override
  Future<List<RegionModel>> getAvailableRegions() async {
    return RegionDownloadServiceImpl.defaultRegions;
  }

  @override
  Future<List<RegionModel>> getDownloadedRegions() async {
    return [];
  }

  @override
  Future<int> getTotalOfflineStorageUsage() async {
    return 0;
  }

  @override
  Future<RegionModel?> checkRegionVersion(String regionId) async {
    return null;
  }

  @override
  Stream<double> downloadAndExtractRegion(
    RegionModel region, {
    void Function(double progress)? onProgress,
    String? customDownloadUrl,
  }) async* {
    yield 0.5;
    onProgress?.call(0.5);
    yield 1.0;
    onProgress?.call(1.0);
  }

  @override
  Future<void> cancelDownload(String regionId) async {}

  @override
  Future<void> deleteRegion(String regionId) async {}
}
