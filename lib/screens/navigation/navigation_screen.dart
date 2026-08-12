import 'package:flutter/material.dart';

class NavigationScreen extends StatefulWidget {
  static const String path = '/navigation';

  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Navigation Screen - S-Map'),
      ),
    );
  }
}
