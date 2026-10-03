import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/screens/main/home/widgets/navigation/widgets.dart';

/// Overlay chế độ điều hướng rẽ theo từng chặng (Top banner chỉ dẫn + Controls + Bottom bar)
class HomeNavigationOverlay extends StatelessWidget {
  final double topPadding;
  final MapDisplayCubit displayCubit;

  const HomeNavigationOverlay({
    super.key,
    required this.topPadding,
    required this.displayCubit,
  });

  @override
  Widget build(BuildContext context) {
    final navigationBloc = context.read<NavigationBloc>();
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: [
        NavigationTopPanel(topPadding: topPadding),
        Positioned(
          right: 16,
          bottom: 120 + bottomPadding,
          child: NavigationMapControls(
            displayCubit: displayCubit,
            onRecenter: () => displayCubit.locateMe(),
          ),
        ),
        NavigationBottomPanel(
          onStopNavigation: () {
            DLog.info('🛑 [HomeScreen] Stop Navigation tapped');
            navigationBloc.add(const StopNavigation());
          },
          onRecenter: () => displayCubit.locateMe(),
        ),
      ],
    );
  }
}
