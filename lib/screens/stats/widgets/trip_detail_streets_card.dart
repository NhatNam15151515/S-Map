import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/route_format_helper.dart';
import 'package:s_map/commons/utils/trip_address_resolver.dart';
import 'package:s_map/commons/utils/trip_format_helper.dart';
import 'package:s_map/commons/utils/trip_leg_extractor.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

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

  @override
  void initState() {
    super.initState();
    _originName = widget.trip.originName;
    _stoppedName = widget.trip.stoppedName;
    _resolveNamesIfNeeded();
  }

  @override
  void didUpdateWidget(covariant TripDetailStreetsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip != widget.trip) {
      _originName = widget.trip.originName;
      _stoppedName = widget.trip.stoppedName;
      _resolveNamesIfNeeded();
    }
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final legs = TripLegExtractor.extractLegs(
      widget.trip,
      customOrigin: _originName,
      customStopped: _stoppedName,
    );

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
          // Header: Tiêu đề + Badge số lượng
          Row(
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
                  '${legs.length}',
                  style: colorScheme.primary.textTheme.semiBoldStyle.copyWith(
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Danh sách các chặng
          ListView.separated(
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
            itemBuilder: (context, index) {
              final leg = legs[index];
              return _buildLegItem(context, leg, index, legs.length);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegItem(
    BuildContext context,
    TripLegItem leg,
    int index,
    int totalCount,
  ) {
    final colorScheme = context.colorScheme;
    final durationStr = RouteFormatHelper.formatTripDuration(leg.duration);
    final distanceStr = leg.distanceKm >= 1.0
        ? '${leg.distanceKm.toStringAsFixed(1)} km'
        : '${leg.distanceMeters.round()} m';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge số thứ tự chặng
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              '${leg.index}',
              style: colorScheme.onSurfaceVariant.textTheme.boldStyle.copyWith(
                fontSize: 10,
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Thông tin chi tiết chặng
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tên con đường / chặng: xuống dòng đầy đủ tối đa 3 dòng
              Text(
                leg.title,
                style: colorScheme.onSurface.textTheme.semiBoldStyle.copyWith(
                  fontSize: 13,
                  height: 1.3,
                ),
                softWrap: true,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 6),

              // Thông số chặng: Dùng Wrap tự co giãn, chống hoàn toàn RenderFlex overflow
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Quãng đường
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.straighten_rounded,
                        size: 13,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        distanceStr,
                        style: colorScheme.primary.textTheme.semiBoldStyle.copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),

                  // Thời gian
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        durationStr,
                        style: colorScheme.onSurfaceVariant.textTheme.mediumStyle.copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),

                  // Vận tốc trung bình
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.speed_rounded,
                        size: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${TripFormatHelper.safeTr(LocaleKeys.stats_dashboard_detail_street_avg_speed, 'TB')}: ${leg.avgSpeedKmh.toStringAsFixed(0)} km/h',
                        style: colorScheme.onSurfaceVariant.textTheme.captionStyle.copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),

                  // Vận tốc tối đa
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: 14,
                        color: context.themeColors.statsOrange,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${TripFormatHelper.safeTr(LocaleKeys.stats_dashboard_detail_street_max_speed, 'Tối đa')}: ${leg.topSpeedKmh.toStringAsFixed(0)} km/h',
                        style: colorScheme.onSurfaceVariant.textTheme.captionStyle.copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
