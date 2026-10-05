import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';
import 'trip_route_point_item.dart';

import 'package:s_map/services/services.dart';

/// Khối hiển thị thông tin lộ trình (Điểm xuất phát -> Đường nối -> Điểm đến / Điểm dừng)
class TripDetailRouteInfo extends StatefulWidget {
  final TripRecordModel trip;

  const TripDetailRouteInfo({
    super.key,
    required this.trip,
  });

  @override
  State<TripDetailRouteInfo> createState() => _TripDetailRouteInfoState();
}

class _TripDetailRouteInfoState extends State<TripDetailRouteInfo> {
  late String _originAddress;
  late String _stoppedAddress;

  @override
  void initState() {
    super.initState();
    _originAddress = TripFormatHelper.getOriginAddress(widget.trip);
    _stoppedAddress = TripFormatHelper.getStoppedAddress(widget.trip);
    _resolveAddressIfNeeded();
  }

  @override
  void didUpdateWidget(covariant TripDetailRouteInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip != widget.trip) {
      _originAddress = TripFormatHelper.getOriginAddress(widget.trip);
      _stoppedAddress = TripFormatHelper.getStoppedAddress(widget.trip);
      _resolveAddressIfNeeded();
    }
  }

  /// Tự động tra cứu số nhà hoặc tên đường cho cả Điểm xuất phát và Điểm dừng
  Future<void> _resolveAddressIfNeeded() async {
    final trip = widget.trip;
    if (trip.polyline == null || trip.polyline!.isEmpty) return;

    var updatedTrip = trip;
    var needsUpdate = false;

    // 1. Resolve cho Điểm xuất phát (nếu chưa có originName hoặc đang là toạ độ thuần)
    if (trip.originName == null ||
        trip.originName!.trim().isEmpty ||
        trip.originName!.trim().contains(RegExp(r'^\d+\.\d+'))) {
      final firstPoint = trip.polyline!.first;
      final resolvedOrigin =
          await TripAddressResolver.resolveAddressAtCoordinate(
        firstPoint[0],
        firstPoint[1],
      );
      if (resolvedOrigin != null &&
          resolvedOrigin.trim().isNotEmpty &&
          mounted) {
        setState(() {
          _originAddress = resolvedOrigin.trim();
        });
        updatedTrip = updatedTrip.copyWith(originName: resolvedOrigin.trim());
        needsUpdate = true;
      }
    }

    // 2. Resolve cho Điểm dừng (nếu chưa đến đích và chưa có stoppedName)
    if (!trip.hasArrived &&
        (trip.stoppedName == null ||
            trip.stoppedName!.trim().isEmpty ||
            trip.stoppedName!.trim().contains(RegExp(r'^\d+\.\d+')))) {
      final lastPoint = trip.polyline!.last;
      final resolvedStopped =
          await TripAddressResolver.resolveAddressAtCoordinate(
        lastPoint[0],
        lastPoint[1],
      );
      if (resolvedStopped != null &&
          resolvedStopped.trim().isNotEmpty &&
          mounted) {
        setState(() {
          _stoppedAddress = resolvedStopped.trim();
        });
        updatedTrip = updatedTrip.copyWith(stoppedName: resolvedStopped.trim());
        needsUpdate = true;
      }
    }

    // Lưu ngầm vào cơ sở dữ liệu để lần sau mở lên tức thì
    if (needsUpdate) {
      try {
        TripServiceImpl.instance.saveTrip(updatedTrip);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final themeColors = context.themeColors;
    final startColor = themeColors.statsSuccess;
    final errorColor = colorScheme.error;
    final trip = widget.trip;
    final origin = _originAddress;
    final isCompleted = trip.hasArrived;
    final hasTarget = trip.destinationName?.trim().isNotEmpty == true;
    final targetName = trip.destinationName?.trim() ?? '';
    final stoppedAddress = _stoppedAddress;

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
          // 1. Điểm xuất phát (Start circle)
          TripRoutePointItem(
            dotColor: startColor,
            customLeading: Container(
              margin: const EdgeInsets.only(top: 2),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: startColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            label: TripFormatHelper.safeTr(
              LocaleKeys.stats_dashboard_detail_origin,
              'Điểm xuất phát',
            ),
            address: origin,
          ),

          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 2,
                height: 18,
                color: colorScheme.outline.withValues(alpha: 0.25),
              ),
            ),
          ),

          // 2. Chuyến đi HOÀN THÀNH: Điểm kết thúc là Đích đến (Target - Red Marker)
          if (isCompleted) ...[
            TripRoutePointItem(
              dotColor: errorColor,
              customLeading: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Image.asset(
                  AppAsset.redMarker.fullPath,
                  width: 18,
                  height: 20,
                  fit: BoxFit.contain,
                ),
              ),
              label: TripFormatHelper.safeTr(
                LocaleKeys.stats_dashboard_detail_destination,
                'Điểm đến',
              ),
              address: hasTarget ? targetName : stoppedAddress,
            ),
          ]
          // 3. Chuyến đi DỪNG GIỮA CHỪNG: Phân biệt rõ Điểm dừng (Stopped) vs Đích đến (Target)
          else ...[
            // Điểm đã dừng thực tế (Stop circle đỏ dấu ||)
            TripRoutePointItem(
              dotColor: errorColor,
              customLeading: Container(
                margin: const EdgeInsets.only(top: 2),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: errorColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: errorColor.withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 2.2,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colorScheme.onError,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(width: 2.5),
                      Container(
                        width: 2.2,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colorScheme.onError,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              label: TripFormatHelper.safeTr(
                LocaleKeys.stats_dashboard_detail_stopped_point,
                'Điểm dừng',
              ),
              address: stoppedAddress,
            ),

            // Nếu có đích đến ban đầu (Target), hiển thị thêm Đích đến ban đầu với RedMarker
            if (hasTarget) ...[
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 2,
                    height: 18,
                    color: colorScheme.outline.withValues(alpha: 0.15),
                  ),
                ),
              ),
              TripRoutePointItem(
                dotColor: colorScheme.outline,
                customLeading: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Image.asset(
                    AppAsset.redMarker.fullPath,
                    width: 18,
                    height: 20,
                    fit: BoxFit.contain,
                  ),
                ),
                label: TripFormatHelper.safeTr(
                  LocaleKeys.stats_dashboard_detail_destination,
                  'Điểm đến',
                ),
                address: targetName,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
