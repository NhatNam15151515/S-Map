import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/trip_address_resolver.dart';
import 'package:s_map/commons/utils/trip_format_helper.dart';
import 'package:s_map/commons/utils/trip_leg_extractor.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/stats/widgets/trip_leg_item_tile.dart';

/// Card danh sách các con đường/chặng đường đã đi trong chi tiết chuyến đi
class TripDetailStreetsCard extends StatefulWidget {
  final TripRecordModel trip;

  const TripDetailStreetsCard({
    super.key,
    required this.trip,
  });

  @override
  State<TripDetailStreetsCard> createState() => _TripDetailStreetsCardState();
}

class _TripDetailStreetsCardState extends State<TripDetailStreetsCard> {
  String? _originName;
  String? _stoppedName;
  List<TripLegItem> _cachedLegs = const [];

  @override
  void initState() {
    super.initState();
    _originName = widget.trip.originName;
    _stoppedName = widget.trip.stoppedName;
    _computeLegs();
    _resolveNamesIfNeeded();
  }

  @override
  void didUpdateWidget(covariant TripDetailStreetsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip != widget.trip) {
      _originName = widget.trip.originName;
      _stoppedName = widget.trip.stoppedName;
      _computeLegs();
      _resolveNamesIfNeeded();
    }
  }

  void _computeLegs() {
    _cachedLegs = TripLegExtractor.extractLegs(
      widget.trip,
      customOrigin: _originName,
      customStopped: _stoppedName,
    );
  }

  Future<void> _resolveNamesIfNeeded() async {
    final trip = widget.trip;
    if (trip.polyline == null || trip.polyline!.isEmpty) return;

    var updatedOrigin = _originName;
    var updatedStopped = _stoppedName;
    var needsUpdate = false;

    if (updatedOrigin == null ||
        updatedOrigin.trim().isEmpty ||
        updatedOrigin.trim().contains(RegExp(r'^\d+\.\d+'))) {
      final firstPoint = trip.polyline!.first;
      final resolved = await TripAddressResolver.resolveAddressAtCoordinate(
        firstPoint[0],
        firstPoint[1],
      );
      if (resolved != null && resolved.trim().isNotEmpty) {
        updatedOrigin = resolved.trim();
        needsUpdate = true;
      }
    }

    if (!trip.hasArrived &&
        (updatedStopped == null ||
            updatedStopped.trim().isEmpty ||
            updatedStopped.trim().contains(RegExp(r'^\d+\.\d+')))) {
      final lastPoint = trip.polyline!.last;
      final resolved = await TripAddressResolver.resolveAddressAtCoordinate(
        lastPoint[0],
        lastPoint[1],
      );
      if (resolved != null && resolved.trim().isNotEmpty) {
        updatedStopped = resolved.trim();
        needsUpdate = true;
      }
    }

    if (needsUpdate && mounted) {
      setState(() {
        _originName = updatedOrigin;
        _stoppedName = updatedStopped;
        _computeLegs();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final legs = _cachedLegs;

    if (legs.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(colorScheme, legs.length),
          const SizedBox(height: 12),
          _buildLegList(colorScheme, legs),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, int count) {
    return Row(
      children: [
        Icon(
          Icons.alt_route_rounded,
          size: 18,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            TripFormatHelper.safeTr(
              LocaleKeys.stats_dashboard_detail_streets_traveled,
              'Các con đường đã đi',
            ),
            style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: colorScheme.primary.textTheme.semiBoldStyle.copyWith(
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegList(ColorScheme colorScheme, List<TripLegItem> legs) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: legs.length,
      separatorBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Divider(
          height: 1,
          thickness: 0.8,
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      itemBuilder: (context, index) => TripLegItemTile(leg: legs[index]),
    );
  }
}
