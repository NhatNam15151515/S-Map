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
      'https://github.com/NhatNam15151515/S-Map/releases/download/map-data-v1.0.0';

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
      id: 'vietnam',
      name: 'Bản đồ Toàn quốc Việt Nam',
      description:
          'Dữ liệu bản đồ, tìm kiếm & dẫn đường offline toàn quốc; hỗ trợ địa chỉ trước và sau sáp nhập',
      bbox: [102.10, 8.50, 109.50, 23.40],
      downloadUrl: '$basePackageUrl/vietnam.zip',
      sizeBytes: 652548547,
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

  /// Dọn dẹp các tệp tạm / tệp mồ côi còn sót lại từ các lượt tải trước
  Future<void> cleanupStaleTempFiles([String? regionId]) async {
    try {
      final baseDir = await _getRegionsStorageDirectory();
      final dir = Directory(baseDir);
      if (!dir.existsSync()) return;

      if (regionId != null) {
        final tempZip = File(p.join(baseDir, '${regionId}_temp.zip'));
        if (tempZip.existsSync()) tempZip.deleteSync();
        final staging = Directory(p.join(baseDir, '${regionId}_staging'));
        if (staging.existsSync()) staging.deleteSync(recursive: true);
        final backup = Directory(p.join(baseDir, '$regionId.backup'));
        if (backup.existsSync()) backup.deleteSync(recursive: true);
      } else {
        await for (final entity in dir.list(followLinks: false)) {
          final name = p.basename(entity.path);
          if (name.endsWith('_temp.zip') ||
              name.endsWith('_staging') ||
              name.endsWith('.backup')) {
            try {
              if (entity is File) {
                entity.deleteSync();
              } else if (entity is Directory) {
                entity.deleteSync(recursive: true);
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      DLog.warning('⚠️ [RegionDownloadService] Không thể dọn dẹp file tạm: $e');
    }
  }

  @override
  Future<List<RegionModel>> getAvailableRegions() async {
    try {
      final box = await _getBox();
      final regionsBaseDir = await _getRegionsStorageDirectory();
      final regions = <RegionModel>[];

      for (final defaultRegion in defaultRegions) {
        final raw = box.get(defaultRegion.id);
        if (raw != null && raw is Map) {
          final map = Map<String, dynamic>.from(raw);
          final local = RegionModel.fromMap(map);

          // Kiểm tra tính toàn vẹn dữ liệu thực tế trên đĩa (yêu cầu đủ bộ tệp cần thiết)
          final regionDir = Directory(p.join(regionsBaseDir, defaultRegion.id));
          final requiredFiles = [
            '${defaultRegion.id}.pmtiles',
            '${defaultRegion.id}.ghz',
            '${defaultRegion.id}_poi.db',
            'version.json',
          ];
          final bool hasValidFiles = regionDir.existsSync() &&
              requiredFiles.every(
                (name) => File(p.join(regionDir.path, name)).existsSync(),
              );

          if (local.isDownloaded && !hasValidFiles) {
            // Dữ liệu cũ bị thiếu hoặc đã bị xóa ngoài luồng -> reset trạng thái để người dùng tải lại
            DLog.warning(
                '⚠️ [RegionDownloadService] Vùng ${defaultRegion.id} thiếu tệp trên đĩa, tự động reset trạng thái.');
            final resetRegion = defaultRegion.copyWith(
                status: RegionDownloadStatus.notDownloaded);
            await box.put(defaultRegion.id, resetRegion.toMap());
            regions.add(resetRegion);
          } else {
            regions.add(defaultRegion.copyWith(
              status: local.status,
              localVersion: local.localVersion,
              downloadProgress: local.downloadProgress,
              downloadedAt: local.downloadedAt,
              localPath: local.localPath ?? regionDir.path,
            ));
          }
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
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
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
    final stagingDir =
        Directory(p.join(regionsBaseDir, '${region.id}_staging'));
    final tempZipFile = File(p.join(regionsBaseDir, '${region.id}_temp.zip'));

    final bool ownsClient = _customHttpClient == null;
    final client = _customHttpClient ?? HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    const Duration requestTimeout = Duration(seconds: 15);
    const Duration receiveTimeout = Duration(minutes: 10);
    IOSink? sink;
    double lastEmittedProgress = 0.05;
    bool metadataCommitted = false;
    bool stagingPromoted = false;
    bool preservePartialDownload = false;

    try {
      yield 0.05;
      onProgress?.call(0.05);

      const maxDownloadAttempts = 4;
      int receivedBytes = tempZipFile.existsSync() ? tempZipFile.lengthSync() : 0;
      bool downloadCompleted = false;

      for (var attempt = 1; attempt <= maxDownloadAttempts; attempt++) {
        final resumeOffset = tempZipFile.existsSync() ? tempZipFile.lengthSync() : 0;
        final request = await client.getUrl(Uri.parse(url)).timeout(requestTimeout);
        if (resumeOffset > 0) {
          request.headers.set(HttpHeaders.rangeHeader, 'bytes=$resumeOffset-');
        }

        final response = await request.close().timeout(requestTimeout);
        if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable &&
            resumeOffset > 0) {
          // File tạm có thể là bản tải cũ đã đủ byte nhưng vẫn hỏng. Bỏ nó
          // và tải mới thay vì lặp vô hạn với cùng một Range.
          if (tempZipFile.existsSync()) tempZipFile.deleteSync();
          receivedBytes = 0;
          continue;
        }
        final isResumeResponse = response.statusCode == HttpStatus.partialContent;
        if (response.statusCode != HttpStatus.ok && !isResumeResponse) {
          throw HttpException(
            'Failed to download package with HTTP status ${response.statusCode}',
            uri: Uri.parse(url),
          );
        }

        // Server không hỗ trợ Range thì trả 200; khi đó phải bắt đầu lại,
        // nếu append sẽ làm ZIP bị nối hai bản với nhau.
        final append = resumeOffset > 0 && isResumeResponse;
        if (!append && resumeOffset > 0) {
          receivedBytes = 0;
        }
        final totalBytes = append && response.contentLength > 0
            ? resumeOffset + response.contentLength
            : response.contentLength > 0
                ? response.contentLength
                : region.sizeBytes;
        final activeSink = tempZipFile.openWrite(
          mode: append ? FileMode.append : FileMode.write,
        );
        sink = activeSink;
        receivedBytes = append ? resumeOffset : 0;

        try {
          await for (final chunk in response.timeout(receiveTimeout)) {
            if (_cancellationMap[region.id] == true) {
              await activeSink.close();
              sink = null;
              if (tempZipFile.existsSync()) tempZipFile.deleteSync();
              throw const DownloadCancelledException();
            }

            activeSink.add(chunk);
            receivedBytes += chunk.length;

            final downloadProgress = totalBytes > 0
                ? (0.05 + (receivedBytes / totalBytes) * 0.65)
                    .clamp(0.05, 0.70)
                : 0.5;

            if (downloadProgress - lastEmittedProgress >= 0.01) {
              lastEmittedProgress = downloadProgress;
              yield downloadProgress;
              onProgress?.call(downloadProgress);
            }
          }
          final bodyBytes = receivedBytes - (append ? resumeOffset : 0);
          if (response.contentLength > 0 &&
              bodyBytes != response.contentLength) {
            throw HttpException(
              'Connection ended before the complete package was received '
              '($bodyBytes/${response.contentLength} bytes)',
              uri: Uri.parse(url),
            );
          }
          await activeSink.flush();
          await activeSink.close();
          sink = null;
          downloadCompleted = true;
          break;
        } catch (e) {
          try {
            await activeSink.close();
          } catch (_) {}
          sink = null;
          if (e is DownloadCancelledException) rethrow;
          preservePartialDownload = true;
          if (attempt == maxDownloadAttempts) rethrow;
          DLog.warning(
              '⚠️ [RegionDownloadService] Mất kết nối khi tải ${region.id} ở lần $attempt/$maxDownloadAttempts; sẽ tiếp tục từ ${tempZipFile.existsSync() ? tempZipFile.lengthSync() : 0} bytes');
          await Future<void>.delayed(Duration(seconds: attempt * 2));
        }
      }

      if (!downloadCompleted) {
        throw HttpException(
          'Download did not complete after $maxDownloadAttempts attempts',
          uri: Uri.parse(url),
        );
      }

      // Bắt đầu giải nén vào staging directory (0.75 -> 1.0)
      yield 0.75;
      onProgress?.call(0.75);
      lastEmittedProgress = 0.75;

      if (_cancellationMap[region.id] == true) {
        if (tempZipFile.existsSync()) tempZipFile.deleteSync();
        throw const DownloadCancelledException();
      }

      if (stagingDir.existsSync()) {
        stagingDir.deleteSync(recursive: true);
      }
      stagingDir.createSync(recursive: true);

      final inputStream = InputFileStream(tempZipFile.path);
      final archive = ZipDecoder().decodeStream(inputStream);

      int extractedFiles = 0;
      final totalFiles = archive.length;

      for (final file in archive) {
        if (_cancellationMap[region.id] == true) {
          inputStream.close();
          if (stagingDir.existsSync()) stagingDir.deleteSync(recursive: true);
          if (tempZipFile.existsSync()) tempZipFile.deleteSync();
          throw const DownloadCancelledException();
        }

        final filename = p.basename(file.name);
        if (file.isFile) {
          final outFile = File(p.join(stagingDir.path, filename));
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

      // Hoán đổi stagingDir vào targetDir nguyên tử có backup phục hồi
      final backupDir = Directory('${targetDir.path}.backup');
      if (backupDir.existsSync()) {
        backupDir.deleteSync(recursive: true);
      }
      if (targetDir.existsSync()) {
        targetDir.renameSync(backupDir.path);
      }
      try {
        stagingDir.renameSync(targetDir.path);
        stagingPromoted = true;
      } catch (_) {
        if (!targetDir.existsSync() && backupDir.existsSync()) {
          try {
            backupDir.renameSync(targetDir.path);
          } catch (_) {}
        }
        rethrow;
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
      metadataCommitted = true;

      // Chỉ xóa backup sau khi metadata đã lưu vào Hive thành công
      if (backupDir.existsSync()) {
        try {
          backupDir.deleteSync(recursive: true);
        } catch (_) {}
      }

      yield 1.0;
      onProgress?.call(1.0);
      DLog.info(
          '✅ [RegionDownloadService] Đã tải và giải nén thành công vùng: ${region.name}');
    } catch (e) {
      if (e is! DownloadCancelledException) {
        DLog.error('❌ [RegionDownloadService] Lỗi tải vùng ${region.name}: $e');
      }
      final backupDir = Directory('${targetDir.path}.backup');
      if (backupDir.existsSync()) {
        if (!targetDir.existsSync()) {
          try {
            backupDir.renameSync(targetDir.path);
          } catch (_) {}
        } else if (!metadataCommitted) {
          // Khôi phục lại backup nếu commit metadata bị lỗi sau khi promote staging
          try {
            if (targetDir.existsSync()) {
              targetDir.deleteSync(recursive: true);
            }
            backupDir.renameSync(targetDir.path);
          } catch (_) {}
        }
      } else if (stagingPromoted &&
          !metadataCommitted &&
          targetDir.existsSync()) {
        // Lần tải đầu tiên không có backup: xóa targetDir để không để lại rác trên đĩa
        try {
          targetDir.deleteSync(recursive: true);
        } catch (_) {}
      }
      if (stagingDir.existsSync()) {
        try {
          stagingDir.deleteSync(recursive: true);
        } catch (_) {}
      }
      if (tempZipFile.existsSync()) {
        try {
          if (!preservePartialDownload) tempZipFile.deleteSync();
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
      final backupDir = Directory('${targetDir.path}.backup');
      if (metadataCommitted && backupDir.existsSync()) {
        try {
          backupDir.deleteSync(recursive: true);
        } catch (_) {}
      }
      if (stagingPromoted &&
          !metadataCommitted &&
          targetDir.existsSync() &&
          !backupDir.existsSync()) {
        try {
          targetDir.deleteSync(recursive: true);
        } catch (_) {}
      }
      if (stagingDir.existsSync()) {
        try {
          stagingDir.deleteSync(recursive: true);
        } catch (_) {}
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
