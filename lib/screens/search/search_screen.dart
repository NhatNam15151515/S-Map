import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  static const String path = '/search';

  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Search Screen - S-Map'),
      ),
    );
  }
}
