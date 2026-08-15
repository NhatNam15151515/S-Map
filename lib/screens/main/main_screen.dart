import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/widgets/widgets.dart';

class MainScreen extends StatefulWidget with AppMixin {
  final StatefulNavigationShell navigationShell;

  const MainScreen(this.navigationShell, {super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with AppMixin {
  @override
  void initState() {
    appCubit.onMainScreenMounted();
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      resizeToAvoidBottomInset: false,
      extendBody: true,
      bottomNavigationBar: AppMainBottomBar(widget.navigationShell),
    );
  }
}
