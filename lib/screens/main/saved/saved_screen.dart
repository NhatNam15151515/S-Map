import 'package:s_map/commons/mixin/app_mixin.dart';
import 'package:s_map/commons/mixin/auth_mixin.dart';
import 'package:s_map/commons/widgets/app_bar.dart';
import 'package:s_map/commons/widgets/empty_widget.dart';
import 'package:flutter/material.dart';

class SavedScreen extends StatefulWidget {
  static const String path = '/SavedScreen';

  const SavedScreen({super.key});

  @override
  _SavedScreenState createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> with AppMixin, AuthStateChanged {

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleAppBar(
        title: "Đã lưu",
      ),
      body: const EmptyWidget(
        title: "Chưa có địa điểm nào",
        subtitle: "Lưu các địa điểm yêu thích để truy cập nhanh",
        icon: Icons.bookmark_border_rounded,
      ),
    );
  }

  @override
  void onAuthStateChanged() {
  }
}
