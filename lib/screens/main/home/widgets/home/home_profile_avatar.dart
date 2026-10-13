import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/widgets/user_avatar.dart';

/// Home-level adapter between authentication state and the dumb avatar widget.
class HomeProfileAvatar extends StatelessWidget {
  final double size;

  const HomeProfileAvatar({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (previous, current) =>
          previous.loggedInProfile?.avatarBase64 !=
          current.loggedInProfile?.avatarBase64,
      builder: (context, state) => ProfileAvatar(
        size: size,
        borderWidth: 1.5,
        avatarBase64: state.loggedInProfile?.avatarBase64,
      ),
    );
  }
}
