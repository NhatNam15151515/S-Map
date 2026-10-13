import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/widgets/poi_quick_card.dart';
import 'package:s_map/models/models.dart';

/// Home coordinator: supplies live map/favorite state and owns card actions.
class HomePoiQuickCard extends StatelessWidget {
  final PoiModel poi;
  final LatLng? userLocation;
  final VoidCallback onClose;
  final VoidCallback? onDirections;
  final VoidCallback? onCustomRoute;
  final VoidCallback? onAddDestination;

  const HomePoiQuickCard({
    super.key,
    required this.poi,
    this.userLocation,
    required this.onClose,
    this.onDirections,
    this.onCustomRoute,
    this.onAddDestination,
  });

  @override
  Widget build(BuildContext context) {
    final mapPosition = userLocation == null
        ? BlocBuilder<MapDisplayCubit, MapDisplayState>(
            buildWhen: (previous, current) =>
                previous.currentPosition != current.currentPosition,
            builder: (context, state) => _buildWithLocation(
              context,
              state.currentPosition,
            ),
          )
        : _buildWithLocation(context, userLocation);
    return mapPosition;
  }

  Widget _buildWithLocation(BuildContext context, LatLng? location) {
    return BlocBuilder<FavoritesCubit, FavoritesState>(
      builder: (context, favorites) {
        final cubit = context.read<FavoritesCubit>();
        final isFavorite = favorites.isFavorite(cubit.getPoiKey(poi));
        return PoiQuickCard(
          poi: poi,
          userLocation: location,
          isFavorite: isFavorite,
          onFavoriteTap: () => cubit.toggleFavorite(poi),
          onCopyCoordinates: () => _copyCoordinates(context),
          onClose: onClose,
          onDirections: onDirections,
          onCustomRoute: onCustomRoute,
          onAddDestination: onAddDestination,
        );
      },
    );
  }

  void _copyCoordinates(BuildContext context) {
    final coordinates = '${poi.lat.toStringAsFixed(5)}, '
        '${poi.lon.toStringAsFixed(5)}';
    Clipboard.setData(ClipboardData(text: coordinates));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          content: Text('Đã sao chép tọa độ: $coordinates'),
        ),
      );
  }
}
