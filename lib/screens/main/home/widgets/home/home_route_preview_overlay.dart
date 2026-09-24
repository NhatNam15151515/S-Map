import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/screens/main/home/widgets/widgets.dart';

/// Overlay chế độ xem trước lộ trình (RouteDirectionHeader + RoutePreviewBottomSheet)
class HomeRoutePreviewOverlay extends StatelessWidget {
  final double topPadding;
  final RoutePreviewState routeState;
  final HomeRouteActions routeActions;
  final VoidCallback onStartNavigationTriggered;

  const HomeRoutePreviewOverlay({
    super.key,
    required this.topPadding,
    required this.routeState,
    required this.routeActions,
    required this.onStartNavigationTriggered,
  });

  @override
  Widget build(BuildContext context) {
    final routePreviewCubit = context.read<RoutePreviewCubit>();
    final navigationBloc = context.read<NavigationBloc>();

    return Stack(
      children: [
        RouteDirectionHeader(
          topPadding: topPadding,
          onSelectOrigin: () => routeActions.handleSelectEndpointForRoute(
            context,
            isOrigin: true,
            mounted: true,
          ),
          onSelectDestination: () => routeActions.handleSelectEndpointForRoute(
            context,
            isOrigin: false,
            mounted: true,
          ),
          onClose: () {
            DLog.info('❌ [HomeScreen] Close Route Preview tapped');
            routePreviewCubit.clearRoute();
          },
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            top: false,
            child: RoutePreviewBottomSheet(
              onClose: () {
                DLog.info('❌ [HomeScreen] Close Route Preview tapped');
                routePreviewCubit.clearRoute();
              },
              onCustomRoute: routeState.destination != null
                  ? () => routeActions.handleOpenCustomRouteDrawing(
                        context,
                        destination: LatLng(
                          routeState.destination!.lat,
                          routeState.destination!.lon,
                        ),
                        destinationName: routeState.destinationName,
                      )
                  : null,
              onStartNavigation: () {
                if (routeState.currentRoute != null &&
                    routeState.origin != null &&
                    routeState.destination != null) {
                  DLog.info('🚀 [HomeScreen] Starting Turn-by-Turn Navigation');
                  onStartNavigationTriggered();
                  navigationBloc.add(StartNavigation(
                    initialRoute: routeState.currentRoute!,
                    origin: routeState.origin!,
                    destination: routeState.destination!,
                    destinationName: routeState.destinationName,
                    profile: routeState.currentProfile,
                  ));
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
