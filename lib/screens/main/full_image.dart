import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/utils/utils.dart';

class FullImageScreen extends StatefulWidget {
  static String path = "/FullImageScreen";
  final AppImage args;

  const FullImageScreen({super.key, required this.args});

  @override
  _FullImageScreenState createState() => _FullImageScreenState();
}

class _FullImageScreenState extends State<FullImageScreen> with AppMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            alignment: Alignment.center,
            color: Colors.black,
            child: widget.args.build(),
          ),
          // Top gradient overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(128),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Back button
          Positioned(
            left: 16,
            top: MediaQuery.paddingOf(context).top + 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(77),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () {
                  context.pop();
                },
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.white,
                  size: 24,
                ),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
