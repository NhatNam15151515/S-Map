import 'package:s_map/commons/mixin/app_mixin.dart';
import 'package:s_map/commons/cubits/map_display_cubit/map_display_cubit.dart';
import 'package:s_map/commons/cubits/map_display_cubit/map_display_state.dart';
import 'package:s_map/screens/map/widgets/map_error_overlay.dart';
import 'package:s_map/screens/map/widgets/map_fab_buttons.dart';
import 'package:s_map/screens/map/widgets/map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MapScreen extends StatefulWidget {
  static const String path = '/map';

  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MyMapScreenContent extends StatelessWidget with AppMixin {
  const _MyMapScreenContent();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MapDisplayCubit>();

    return Scaffold(
      body: BlocBuilder<MapDisplayCubit, MapDisplayState>(
        builder: (context, state) {
          return Stack(
            children: [
              MapView(
                onMapCreated: cubit.onMapCreated,
                onStyleLoadedCallback: cubit.onStyleLoaded,
              ),
              if (state.status == MapDisplayStatus.ready ||
                  state.status == MapDisplayStatus.loading)
                MapFabButtons(
                  onZoomIn: cubit.zoomIn,
                  onZoomOut: cubit.zoomOut,
                  onLocateMe: cubit.locateMe,
                ),
              if (state.status == MapDisplayStatus.loading)
                Positioned.fill(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: styles.colorScheme.primary,
                    ),
                  ),
                ),
              if (state.status == MapDisplayStatus.error)
                MapErrorOverlay(
                  errorMessage:
                      state.errorMessage ?? 'Không thể tải dữ liệu bản đồ',
                  onRetry: cubit.locateMe,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MapScreenState extends State<MapScreen> with AppMixin {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MapDisplayCubit(),
      child: const _MyMapScreenContent(),
    );
  }
}
