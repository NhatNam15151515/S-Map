import 'package:equatable/equatable.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Arguments passed when navigating to SearchScreen via GoRouter extra.
class SearchScreenArgs extends Equatable {
  final LatLng? userLocation;
  final bool hasExistingDestinations;
  final String? initialQuery;

  const SearchScreenArgs({
    this.userLocation,
    this.hasExistingDestinations = false,
    this.initialQuery,
  });

  @override
  List<Object?> get props => [userLocation, hasExistingDestinations, initialQuery];
}
