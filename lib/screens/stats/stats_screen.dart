import 'package:flutter/material.dart';

class StatsScreen extends StatefulWidget {
  static const String path = '/stats';

  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Stats Screen - S-Map'),
      ),
    );
  }
}
