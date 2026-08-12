import 'package:flutter/material.dart';

class RouteDrawingScreen extends StatefulWidget {
  static const String path = '/route_drawing';

  const RouteDrawingScreen({super.key});

  @override
  State<RouteDrawingScreen> createState() => _RouteDrawingScreenState();
}

class _RouteDrawingScreenState extends State<RouteDrawingScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Route Drawing Screen - S-Map'),
      ),
    );
  }
}
