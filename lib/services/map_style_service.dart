import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/services/region_download_service.dart';
import 'package:s_map/services/map_style_theme_provider.dart';

/// Selects the effective style for MapLibre.
///
/// The service is a facade: the widgets and cubits only ask for a style. The
/// actual colors live in [IMapStyleThemeProvider], while the offline source
/// lives in the generated PMTiles package. This keeps future map presets out
/// of the UI and interaction code.
class MapStyleService implements IMapStyleService {
  /// Keyless online fallback used before the Vietnam package is installed.
  static const String openFreeMapDarkStyleUrl =
      'https://tiles.openfreemap.org/styles/dark';

  final IMapStyleThemeProvider _themeProvider;
  final IRegionDownloadService _regionDownloadService;
  final StreamController<void> _changesController =
      StreamController<void>.broadcast(sync: true);

  String? _onlineStyleJson;
  String? _onlineNightStyleJson;
  String? _offlineStyleTemplate;
  String? _offlinePmtilesPath;
  String? _offlineFontPath;

  MapStyleService({
    IMapStyleThemeProvider? themeProvider,
    IRegionDownloadService? regionDownloadService,
  })  : _themeProvider = themeProvider ?? DefaultMapStyleThemeProvider(),
        _regionDownloadService =
            regionDownloadService ?? RegionDownloadServiceImpl.instance;

  static MapStyleService instance = MapStyleService();

  @override
  Stream<void> get changes => _changesController.stream;

  /// True when the complete Vietnam package contains a usable PMTiles file.
  bool get hasOfflineMap => _offlinePmtilesPath != null;

  String? get offlinePmtilesPath => _offlinePmtilesPath;

  @override
  String get styleJson => _effectiveStyle(isDarkMode: false);

  @override
  String get nightStyleJson => _effectiveStyle(isDarkMode: true);

  @override
  String getStyleJson({bool isDarkMode = false}) =>
      _effectiveStyle(isDarkMode: isDarkMode);

  String _effectiveStyle({required bool isDarkMode}) {
    final pmtilesPath = _offlinePmtilesPath;
    final template = _offlineStyleTemplate;
    if (pmtilesPath != null && template != null && template.isNotEmpty) {
      return _buildOfflineStyle(
        template: template,
        pmtilesPath: pmtilesPath,
        isDarkMode: isDarkMode,
      );
    }

    return isDarkMode
        ? (_onlineNightStyleJson ?? '')
        : (_onlineStyleJson ?? '');
  }

  String _buildOfflineStyle({
    required String template,
    required String pmtilesPath,
    required bool isDarkMode,
  }) {
    var style = template.replaceAll(
      '__PMTILES_URI__',
      Uri.file(pmtilesPath).toString(),
    );
    style = style.replaceAll(
      '__FONT_URL__',
      _offlineFontPath == null
          ? ''
          : Uri.file(_offlineFontPath!).toString(),
    );

    final palette = _themeProvider
        .paletteFor(isDarkMode: isDarkMode)
        .tokens;
    for (final entry in palette.entries) {
      style = style.replaceAll(entry.key, entry.value);
    }
    return style;
  }

  @override
  Future<void> init() async {
    try {
      _onlineStyleJson = await rootBundle.loadString('assets/map/style.json');
    } catch (_) {
      _onlineStyleJson = '';
    }

    try {
      _offlineStyleTemplate =
          await rootBundle.loadString('assets/map/offline_style.json');
    } catch (error) {
      _offlineStyleTemplate = null;
      DLog.warning('⚠️ Không tải được offline map style template: $error');
    }

    await _prepareOfflineFont();

    // OpenFreeMap remains the online fallback. Once the local Vietnam package
    // is installed, both light and dark modes use the local vector style.
    _onlineNightStyleJson = openFreeMapDarkStyleUrl;
    await refreshOfflineMap(emitChange: false);
  }

  /// MapLibre Native needs a local font face when the style is offline. The
  /// Flutter font registration is not enough for native map labels, so copy a
  /// small, already-bundled TTF into app storage once and reference it with a
  /// file URI from the style JSON.
  Future<void> _prepareOfflineFont() async {
    if (kIsWeb) return;

    try {
      final fontData =
          await rootBundle.load('assets/fonts/Montserrat-Regular.ttf');
      final appDir = await getApplicationDocumentsDirectory();
      final fontDir = Directory(p.join(appDir.path, 'map_fonts'));
      if (!fontDir.existsSync()) {
        await fontDir.create(recursive: true);
      }

      final fontFile = File(p.join(fontDir.path, 'Montserrat-Regular.ttf'));
      if (!fontFile.existsSync() ||
          await fontFile.length() != fontData.lengthInBytes) {
        await fontFile.writeAsBytes(
          fontData.buffer.asUint8List(
            fontData.offsetInBytes,
            fontData.lengthInBytes,
          ),
          flush: true,
        );
      }
      _offlineFontPath = fontFile.path;
    } catch (error, stack) {
      // Labels remain optional. The geometry-only style can still render if a
      // host does not expose path_provider (for example a pure unit test).
      _offlineFontPath = null;
      DLog.warning('⚠️ Không chuẩn bị được font nhãn offline: $error', stack);
    }
  }

  /// Re-checks the downloaded package after a download/delete operation.
  ///
  /// The returned stream event lets existing map cubits apply the new style
  /// without recreating the native MapLibre view.
  @override
  Future<bool> refreshOfflineMap({bool emitChange = true}) async {
    final previousPath = _offlinePmtilesPath;
    _offlinePmtilesPath = await _findInstalledPmtiles();
    final changed = previousPath != _offlinePmtilesPath;

    await _setNativeOfflineMode(_offlinePmtilesPath != null);

    if (changed && emitChange && !_changesController.isClosed) {
      _changesController.add(null);
    }
    return changed;
  }

  Future<String?> _findInstalledPmtiles() async {
    try {
      // MapStyleService.init() can run before Hive is initialized in a test or
      // a detached host. Do not make a best-effort map style refresh open a
      // storage box and fail the application bootstrap.
      if (identical(
            _regionDownloadService,
            RegionDownloadServiceImpl.instance,
          ) &&
          !Hive.isBoxOpen(RegionDownloadServiceImpl.boxName)) {
        return null;
      }

      final downloaded =
          await _regionDownloadService.getDownloadedRegions();
      final matchingRegions =
          downloaded.where((item) => item.id == 'vietnam').toList();
      final region = matchingRegions.isEmpty ? null : matchingRegions.first;
      if (region != null) {
        final storedPath = (region.localPath ?? '').trim();
        final regionDir = storedPath.isNotEmpty
            ? storedPath
            : p.join(
                (await getApplicationDocumentsDirectory()).path,
                'regions',
                region.id,
              );
        final file = File(p.join(regionDir, '${region.id}.pmtiles'));
        if (await file.exists() && await file.length() > 127) {
          return file.path;
        }
      }
    } catch (error, stack) {
      // The map must still start in online mode when storage/Hive is not
      // available yet (or in a detached unit-test environment).
      DLog.warning('⚠️ Không kiểm tra được PMTiles offline: $error', stack);
    }
    return null;
  }

  Future<void> _setNativeOfflineMode(bool enabled) async {
    if (kIsWeb) return;
    try {
      await setOffline(enabled);
    } catch (error) {
      // Desktop/test targets do not register MapLibre's native channel. This
      // must never prevent the rest of the app from starting.
      DLog.warning('⚠️ Không đổi được chế độ offline của MapLibre: $error');
    }
  }
}
