import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/widgets/widgets.dart';

class HomeSearchAreaButton extends StatelessWidget {
  final double topPadding;
  final bool isVisible;
  final VoidCallback onPressed;

  const HomeSearchAreaButton({
    super.key,
    required this.topPadding,
    required this.isVisible,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: topPadding + 108,
      left: 0,
      right: 0,
      child: Center(
        child: BlocBuilder<ViewportSearchBloc, ViewportSearchState>(
          buildWhen: (prev, curr) => prev.status != curr.status,
          builder: (context, viewportState) {
            final isLoading = viewportState.isLoading;
            return SearchThisAreaButton(
              isVisible: isVisible || isLoading,
              isLoading: isLoading,
              onPressed: onPressed,
            );
          },
        ),
      ),
    );
  }
}
