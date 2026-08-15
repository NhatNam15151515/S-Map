import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/widgets/widgets.dart';

class SavedScreen extends StatefulWidget {
  static const String path = '/SavedScreen';

  const SavedScreen({super.key});

  @override
  _SavedScreenState createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen>
    with AppMixin, AuthStateChanged {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleAppBar(
        title: tr(LocaleKeys.savedPlaces),
      ),
      body: EmptyWidget(
        title: tr(LocaleKeys.noSavedPlaces),
        subtitle: tr(LocaleKeys.savePlacesSubtitle),
        icon: Icons.bookmark_border_rounded,
      ),
    );
  }

  @override
  void onAuthStateChanged() {}
}
