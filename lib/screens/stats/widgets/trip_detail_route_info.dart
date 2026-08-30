import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class TripDetailRouteInfo extends StatelessWidget {
  final TripRecordModel trip;

  const TripDetailRouteInfo({
    super.key,
    required this.trip,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final firstPoint =
        trip.polyline?.isNotEmpty == true ? trip.polyline!.first : null;
    final lastPoint =
        trip.polyline?.isNotEmpty == true ? trip.polyline!.last : null;

    final origin = trip.originName?.trim().isNotEmpty == true
        ? trip.originName!
        : (firstPoint != null
            ? '${firstPoint[0].toStringAsFixed(4)}, ${firstPoint[1].toStringAsFixed(4)}'
            : tr(LocaleKeys.stats_dashboard_detail_origin));

    final destination = trip.destinationName?.trim().isNotEmpty == true
        ? trip.destinationName!
        : (lastPoint != null
            ? '${lastPoint[0].toStringAsFixed(4)}, ${lastPoint[1].toStringAsFixed(4)}'
            : tr(LocaleKeys.stats_dashboard_detail_destination));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          _LocationPoint(
            dotColor: colorScheme.primary,
            label: tr(LocaleKeys.stats_dashboard_detail_origin),
            address: origin,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 2,
                height: 16,
                color: colorScheme.outline.withValues(alpha: 0.25),
              ),
            ),
          ),
          _LocationPoint(
            dotColor: colorScheme.error,
            label: tr(LocaleKeys.stats_dashboard_detail_destination),
            address: destination,
          ),
        ],
      ),
    );
  }
}

class _LocationPoint extends StatelessWidget {
  final Color dotColor;
  final String label;
  final String address;

  const _LocationPoint({
    required this.dotColor,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 3),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: dotColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: colorScheme.onSurfaceVariant.textTheme.captionStyle.copyWith(
                  fontSize: 10,
                ),
              ),
              Text(
                address,
                style: colorScheme.onSurface.textTheme.semiBoldStyle.copyWith(
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
