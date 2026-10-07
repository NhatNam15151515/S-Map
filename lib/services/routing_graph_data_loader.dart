import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:s_map/commons/log/log.dart';

/// Locates the bundled/downloaded GraphHopper graph and initializes it.
///
/// Lifecycle and request de-duplication stay in [RoutingRepositoryImpl]; this
/// class owns filesystem discovery and legacy graph cleanup only.
class RoutingGraphDataLoader {
  const RoutingGraphDataLoader();

  Future<bool> initializeFromAvailableData({
    required Future<bool> Function(String path) initializeGraph,
  }) async {
    await _cleanupLegacyData();

    final candidateDirs = <String>[];
    try {
      final docDir = await getApplicationDocumentsDirectory();
      candidateDirs.add(docDir.path);
      DLog.info('[RoutingGraphDataLoader] Candidate AppDocDir: "${docDir.path}"');
    } catch (error) {
      DLog.warning('[RoutingGraphDataLoader] Cannot get AppDocDir: $error');
    }

    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        candidateDirs.add(extDir.path);
        DLog.info('[RoutingGraphDataLoader] Candidate AppExtDir: "${extDir.path}"');
      }
    } catch (error) {
      DLog.warning('[RoutingGraphDataLoader] Cannot get AppExtDir: $error');
    }

    candidateDirs.addAll(const [
      '/sdcard/Android/data/com.vnsmap.app/files',
      '/storage/emulated/0/Android/data/com.vnsmap.app/files',
    ]);

    const candidateDirNames = [
      'regions/vietnam',
      'regions/vietnam/graphhopper',
      'vietnam_extracted',
      'vietnam-latest-gh',
      'graphhopper',
    ];
    const candidateFileNames = [
      'regions/vietnam/vietnam.ghz',
      'vietnam.ghz',
    ];

    DLog.info(
      '[RoutingGraphDataLoader] Scanning ${candidateDirs.length} candidate directories for graph data...',
    );
    for (final dirPath in candidateDirs) {
      for (final dirName in candidateDirNames) {
        final targetDir = Directory(p.join(dirPath, dirName));
        if (!await targetDir.exists()) continue;

        final hasNodes = await File(p.join(targetDir.path, 'nodes')).exists();
        await _logGraphMetadata(targetDir);
        DLog.info(
          '[RoutingGraphDataLoader] Found candidate folder: "${targetDir.path}" (has nodes file: $hasNodes)',
        );
        if (!hasNodes) continue;

        DLog.info(
          '[RoutingGraphDataLoader] Initializing GraphHopper with extracted folder: "${targetDir.path}"',
        );
        final success = await initializeGraph(targetDir.path);
        DLog.info('[RoutingGraphDataLoader] Folder init outcome: success=$success');
        if (success) {
          DLog.info(
            '[RoutingGraphDataLoader] GraphHopper READY & ROUTING ENABLED from: "${targetDir.path}"',
          );
          return true;
        }
      }

      for (final name in candidateFileNames) {
        final file = File(p.join(dirPath, name));
        if (!await file.exists()) continue;

        final sizeMb = (await file.length() / (1024 * 1024)).toStringAsFixed(2);
        DLog.info(
          '[RoutingGraphDataLoader] Found candidate .ghz file: "${file.path}" (size: $sizeMb MB, modified: ${file.lastModifiedSync()})',
        );
        final success = await initializeGraph(file.path);
        DLog.info('[RoutingGraphDataLoader] .ghz file init outcome: success=$success');
        if (success) {
          DLog.info(
            '[RoutingGraphDataLoader] GraphHopper READY & ROUTING ENABLED from archive: "${file.path}"',
          );
          return true;
        }
      }
    }

    for (final bundledAsset in const ['assets/map/vietnam.ghz']) {
      DLog.info(
        '[RoutingGraphDataLoader] Attempting auto-init from bundled APK asset: "$bundledAsset"',
      );
      final success = await initializeGraph(bundledAsset);
      DLog.info(
        '[RoutingGraphDataLoader] Bundled asset init outcome ($bundledAsset): success=$success',
      );
      if (success) {
        DLog.info(
          '[RoutingGraphDataLoader] GraphHopper READY & ROUTING ENABLED from APK asset!',
        );
        return true;
      }
    }

    DLog.warning(
      '[RoutingGraphDataLoader] Scan completed: No valid GraphHopper graph data found or initialization failed on all candidates',
    );
    return false;
  }

  Future<void> _logGraphMetadata(Directory graphDir) async {
    final localVersion = File(p.join(graphDir.path, 'version.json'));
    final parentVersion = File(p.join(graphDir.parent.path, 'version.json'));
    final versionFile = await localVersion.exists() ? localVersion : parentVersion;
    if (await versionFile.exists()) {
      try {
        DLog.info(
          '[RoutingGraphDataLoader] Found version.json: ${await versionFile.readAsString()}',
        );
      } catch (_) {}
    }

    final propertiesFile = File(p.join(graphDir.path, 'properties'));
    if (!await propertiesFile.exists()) return;
    try {
      final properties = String.fromCharCodes(await propertiesFile.readAsBytes());
      final profile = RegExp(r'profiles=([^\r\n\x00]+)').firstMatch(properties);
      final importDate =
          RegExp(r'datareader\.import\.date=([^\r\n\x00]+)').firstMatch(properties);
      DLog.info(
        '[RoutingGraphDataLoader] Graph properties: profile=${profile?.group(1) ?? 'N/A'}, importDate=${importDate?.group(1) ?? 'N/A'}',
      );
    } catch (_) {}
  }

  Future<void> _cleanupLegacyData() async {
    const legacyNames = ['metro_hcm.ghz', 'metro_hcm_extracted', 'metro_hcm'];
    final dirsToClean = <String>[];
    try {
      dirsToClean.add((await getApplicationDocumentsDirectory()).path);
    } catch (_) {}
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) dirsToClean.add(extDir.path);
    } catch (_) {}

    dirsToClean.addAll(const [
      '/sdcard/Android/data/com.vnsmap.app/files',
      '/storage/emulated/0/Android/data/com.vnsmap.app/files',
    ]);

    for (final dirPath in dirsToClean) {
      for (final name in legacyNames) {
        final filePath = p.join(dirPath, name);
        try {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete(recursive: true);
            DLog.info('[RoutingGraphDataLoader] Deleted legacy file: "$filePath"');
          }
          final directory = Directory(filePath);
          if (await directory.exists()) {
            await directory.delete(recursive: true);
            DLog.info('[RoutingGraphDataLoader] Deleted legacy directory: "$filePath"');
          }
        } catch (error) {
          DLog.warning(
            '[RoutingGraphDataLoader] Failed to clean legacy "$name" in "$dirPath": $error',
          );
        }
      }
    }
  }
}
