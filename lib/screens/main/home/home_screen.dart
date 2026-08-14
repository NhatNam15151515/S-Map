import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/map_display_cubit/map_display_cubit.dart';
import 'package:s_map/commons/cubits/map_display_cubit/map_display_state.dart';
import 'package:s_map/commons/mixin/app_mixin.dart';
import 'package:s_map/models/place_model.dart';
import 'package:s_map/screens/map/widgets/map_error_overlay.dart';
import 'package:s_map/screens/map/widgets/map_view.dart';
import 'package:s_map/services/firebase_firestore_service.dart';
import 'widgets/home_category_chips.dart';
import 'widgets/home_explore_bottom_sheet.dart';
import 'widgets/home_map_controls.dart';
import 'widgets/home_search_bar.dart';

class HomeScreen extends StatefulWidget {
  static const String path = '/HomeScreen';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MapDisplayCubit _mapCubit;

  @override
  void initState() {
    super.initState();
    _mapCubit = MapDisplayCubit();
  }

  @override
  void dispose() {
    _mapCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _mapCubit,
      child: const _HomeScreenContent(),
    );
  }
}

class _HomeScreenContent extends StatefulWidget {
  const _HomeScreenContent();

  @override
  State<_HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<_HomeScreenContent> with AppMixin {
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  final FireStoreService _fireStore = FireStoreService();
  String _selectedCategory = "Tất cả";

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MapDisplayCubit>();
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Stack(
        children: [
          // 1. BASE MAP VIEW
          BlocConsumer<MapDisplayCubit, MapDisplayState>(
            listener: (context, state) {
              if (state.errorMessage != null && state.status != MapDisplayStatus.error) {
                showWarning(state.errorMessage);
                cubit.clearError();
              }
            },
            builder: (context, state) {
              return Stack(
                children: [
                  MapView(
                    onMapCreated: cubit.onMapCreated,
                    onStyleLoadedCallback: cubit.onStyleLoaded,
                    onCameraTrackingDismissed: cubit.onCameraTrackingDismissed,
                    onCameraMove: cubit.onCameraMove,
                  ),
                  if (state.status == MapDisplayStatus.loading)
                    const Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  if (state.status == MapDisplayStatus.error)
                    MapErrorOverlay(
                      errorMessage: state.errorMessage ?? 'Không thể tải dữ liệu bản đồ',
                      onRetry: cubit.locateMe,
                    ),
                ],
              );
            },
          ),

          // 2. RIGHT MAP CONTROLS
          Positioned(
            right: 16,
            bottom: 220,
            child: HomeMapControls(
              onZoomIn: cubit.zoomIn,
              onZoomOut: cubit.zoomOut,
              onLocateMe: cubit.locateMe,
            ),
          ),

          // 3. TOP FLOATING SEARCH BAR & CATEGORIES
          Positioned(
            top: topPadding + 8,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HomeSearchBar(),
                const SizedBox(height: 10),
                HomeCategoryChips(
                  onCategorySelected: (category) {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                ),
              ],
            ),
          ),

          // 4. DYNAMIC EXPLORE BOTTOM SHEET (FIRESTORE STREAM)
          StreamBuilder<List<PlaceModel>>(
            stream: _fireStore.streamExplorePlaces(category: _selectedCategory),
            builder: (context, snapshot) {
              return HomeExploreBottomSheet(
                controller: _sheetController,
                places: snapshot.data,
                isLoading: snapshot.connectionState == ConnectionState.waiting,
                onPlaceTap: (place) {
                  if (place.latitude != null && place.longitude != null) {
                    // Navigate or move camera to place
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
