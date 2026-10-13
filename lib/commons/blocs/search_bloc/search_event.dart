import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/models/models.dart';

abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => const [];
}

class SearchQueryChanged extends SearchEvent {
  final String query;
  final Duration? debounceDuration;

  const SearchQueryChanged(this.query, {this.debounceDuration});

  @override
  List<Object?> get props => [query, debounceDuration];
}

class SearchSubmitted extends SearchEvent {
  final String query;
  final bool returnResults;
  final Completer<void>? completer;

  const SearchSubmitted(
    this.query, {
    this.returnResults = false,
    this.completer,
  });

  @override
  List<Object?> get props => [query, returnResults];
}

class SearchUserLocationChanged extends SearchEvent {
  final LatLng location;

  const SearchUserLocationChanged(this.location);

  @override
  List<Object?> get props => [location];
}

class SearchCleared extends SearchEvent {
  const SearchCleared();
}

abstract class SearchHistoryEvent extends SearchEvent {
  final Completer<void>? completer;

  const SearchHistoryEvent({this.completer});
}

class SearchHistoryLoadRequested extends SearchHistoryEvent {
  const SearchHistoryLoadRequested({super.completer});
}

class SearchRecentAdded extends SearchHistoryEvent {
  final String query;

  const SearchRecentAdded(this.query, {super.completer});

  @override
  List<Object?> get props => [query];
}

class SearchDestinationAdded extends SearchHistoryEvent {
  final PoiModel poi;

  const SearchDestinationAdded(this.poi, {super.completer});

  @override
  List<Object?> get props => [poi];
}

class SearchRecentRemoved extends SearchHistoryEvent {
  final String query;

  const SearchRecentRemoved(this.query, {super.completer});

  @override
  List<Object?> get props => [query];
}

class SearchHistoryCleared extends SearchHistoryEvent {
  const SearchHistoryCleared({super.completer});
}
