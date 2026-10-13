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

    // Bóc nháy kép quanh các token dạng số (float) nếu file template bọc ngoặc kép để tránh lỗi IDE
    final casingOpacity = palette['__ROAD_CASING_OPACITY__'];
    if (casingOpacity != null) {
      style = style.replaceAll('"__ROAD_CASING_OPACITY__"', casingOpacity);
    }
    final surfaceOpacity = palette['__ROAD_SURFACE_OPACITY__'];
    if (surfaceOpacity != null) {
      style = style.replaceAll('"__ROAD_SURFACE_OPACITY__"', surfaceOpacity);
    }

    for (final entry in palette.entries) {
      style = style.replaceAll(entry.key, entry.value);
    }
    return stripJsonComments(style);
  }

  @override
  Future<void> init() async {
    try {
      final raw = await rootBundle.loadString('assets/map/style.json');
      _onlineStyleJson = stripJsonComments(raw);
    } catch (_) {
      _onlineStyleJson = '';
    }

    _offlineStyleTemplate = await _loadOfflineStyleTemplate();

    await _prepareOfflineFont();

    // OpenFreeMap remains the online fallback. Once the local Vietnam package
    // is installed, both light and dark modes use the local vector style.
    _onlineNightStyleJson = openFreeMapDarkStyleUrl;
    await refreshOfflineMap(emitChange: false);
  }

  /// Nạp template offline vector map: Ưu tiên ghép từ các module layer
  /// (assets/map/layers/), nếu không có sẽ fallback về assets/map/offline_style.json.
  Future<String?> _loadOfflineStyleTemplate() async {
    try {
      final baseStr = await _loadLayerAsset('base');
      final landStr = await _loadLayerAsset('land');
      final waterStr = await _loadLayerAsset('water');
      final buildingStr = await _loadLayerAsset('buildings');
      final roadStr = await _loadLayerAsset('roads');
      final labelStr = await _loadLayerAsset('labels');

      final layersMerged = [
        _cleanLayerArray(landStr),
        _cleanLayerArray(waterStr),
        _cleanLayerArray(buildingStr),
        _cleanLayerArray(roadStr),
        _cleanLayerArray(labelStr),
      ].where((s) => s.isNotEmpty).join(',\n');

      final merged = baseStr.replaceFirst(RegExp(r'"?__LAYERS__"?'), layersMerged);
      return stripJsonComments(merged);
    } catch (modularError) {
      DLog.info('ℹ️ Không tải được modular layers, fallback về offline_style.json: $modularError');
    }

    try {
      final raw = await _loadLayerFallback();
      return stripJsonComments(raw);
    } catch (error) {
      DLog.warning('⚠️ Không tải được offline map style template: $error');
      return null;
    }
  }

  static Future<String> _loadLayerAsset(String name) async {
    try {
      return await rootBundle.loadString('assets/map/layers/$name.jsonc');
    } catch (_) {
      return await rootBundle.loadString('assets/map/layers/$name.json');
    }
  }

  static Future<String> _loadLayerFallback() async {
    try {
      return await rootBundle.loadString('assets/map/offline_style.jsonc');
    } catch (_) {
      return await rootBundle.loadString('assets/map/offline_style.json');
    }
  }

  /// Chuẩn hóa mảng JSON layer: bóc tách dấu [ ] ngoài cùng và loại bỏ comment
  static String _cleanLayerArray(String moduleContent) {
    var trimmed = stripJsonComments(moduleContent).trim();
    if (trimmed.startsWith('[')) {
      trimmed = trimmed.substring(1).trim();
    }
    if (trimmed.endsWith(']')) {
      trimmed = trimmed.substring(0, trimmed.length - 1).trim();
    }
    return trimmed;
  }

  /// Loại bỏ các dòng chú thích // và /* */ (hỗ trợ chuẩn JSONC)
  /// mà không làm ảnh hưởng đến các URL chứa `://` (như pmtiles://, https://).
  static String stripJsonComments(String input) {
    final buffer = StringBuffer();
    final len = input.length;
    bool inString = false;
    bool isEscaped = false;

    for (int i = 0; i < len; i++) {
      final char = input[i];

      if (inString) {
        buffer.write(char);
        if (isEscaped) {
          isEscaped = false;
        } else if (char == r'\') {
          isEscaped = true;
        } else if (char == '"') {
          inString = false;
        }
      } else {
        if (char == '"') {
          inString = true;
          buffer.write(char);
        } else if (char == '/' && i + 1 < len && input[i + 1] == '/') {
          // Bỏ qua chú thích // cho đến hết dòng
          while (i < len && input[i] != '\n' && input[i] != '\r') {
            i++;
          }
          if (i < len) {
            buffer.write(input[i]); // Giữ lại ký tự xuống dòng
          }
        } else if (char == '/' && i + 1 < len && input[i + 1] == '*') {
          // Bỏ qua chú thích /* ... */
          i += 2;
          while (i + 1 < len && !(input[i] == '*' && input[i + 1] == '/')) {
            if (input[i] == '\n') buffer.write('\n');
            i++;
          }
          i++; // Bỏ qua ký tự '/' của '*/'
        } else {
          buffer.write(char);
        }
      }
    }
    return buffer.toString();
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
