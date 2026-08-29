import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/routers/app_routes.dart';
import 'package:s_map/screens/stats/widgets/widgets.dart';

class StatsScreen extends StatefulWidget {
  final RouteProfileCubit? cubit;

  const StatsScreen({
    super.key,
    this.cubit,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late final RouteProfileCubit _cubit;
  bool _isInternalCubit = false;

  @override
  void initState() {
    super.initState();
    if (widget.cubit != null) {
      _cubit = widget.cubit!;
    } else {
      _cubit = RouteProfileCubit();
      _isInternalCubit = true;
      _cubit.init(autoWatch: true);
    }
  }

  @override
  void dispose() {
    if (_isInternalCubit) {
      _cubit.close();
    }
    super.dispose();
  }

  Future<void> _showClearAllDialog(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          tr(LocaleKeys.stats_dashboard_clear_all_title),
          style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
            fontSize: 16,
          ),
        ),
        content: Text(
          tr(LocaleKeys.stats_dashboard_clear_all_desc),
          style: colorScheme.onSurfaceVariant.textTheme.textStyle.copyWith(
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              tr(LocaleKeys.cancel),
              style: colorScheme.onSurfaceVariant.textTheme.mediumStyle,
            ),
          ),
          ElevatedButton(
            key: const Key('confirm_clear_all_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              tr(LocaleKeys.stats_dashboard_clear_all_btn),
              style: colorScheme.onError.textTheme.semiBoldStyle,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cubit.clearAllTrips();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: TitleAppBar(
          title: tr(LocaleKeys.stats_dashboard_title),
          rightWidget: IconButton(
            key: const Key('stats_clear_all_btn'),
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: tr(LocaleKeys.stats_dashboard_clear_all_btn),
            onPressed: () => _showClearAllDialog(context),
          ),
        ),
        body: BlocListener<RouteProfileCubit, RouteProfileState>(
          listenWhen: (previous, current) =>
              current.isError && current.errorMessage != previous.errorMessage,
          listener: (context, state) {
            if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.errorMessage ?? tr(LocaleKeys.common_error),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          },
          child: BlocBuilder<RouteProfileCubit, RouteProfileState>(
            builder: (context, state) {
              if (state.isLoading && state.allTrips.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              return RefreshIndicator(
                onRefresh: () => _cubit.loadStats(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Time Range Selector
                      StatsTimeRangeSelector(
                        selectedRange: state.timeRange,
                        onRangeSelected: (range) => _cubit.setTimeRange(range),
                      ),

                      // 2. Vehicle Profile Filter Chips
                      StatsVehicleFilterChips(
                        selectedProfile: state.profileFilter,
                        profileCounts: state.stats.tripsByProfile,
                        onProfileSelected: (profile) =>
                            _cubit.setProfileFilter(profile),
                      ),

                      const SizedBox(height: 8),

                      // 3. KPI Summary Cards Grid
                      StatsSummaryCards(stats: state.stats),

                      // 4. Distance Bar Chart
                      StatsDistanceChart(chartData: state.chartData),

                      // 5. Trip History List
                      StatsTripHistoryList(
                        trips: state.filteredTrips,
                        onTapTrip: (trip) => context.push(
                          AppRoutes.tripDetail,
                          extra: trip,
                        ),
                        onDeleteTrip: (tripId) => _cubit.deleteTrip(tripId),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
