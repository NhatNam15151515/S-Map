import 'package:s_map/models/models.dart';

/// Supplies the visual tokens used to materialize a MapLibre style.
///
/// This is deliberately independent from Flutter's BuildContext. The UI only
/// chooses the brightness; the provider owns the map-specific palette.
abstract interface class IMapStyleThemeProvider {
  MapStylePalette paletteFor({required bool isDarkMode});
}
