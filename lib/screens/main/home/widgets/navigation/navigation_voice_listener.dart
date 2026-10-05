import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/services/voice_guidance_service.dart';

/// Headless widget lắng nghe [NavigationBloc] để phát thông báo giọng nói TTS tiếng Việt.
/// 
/// Tách rời lifecycle và logic TTS khỏi UI của HomeScreen.
class NavigationVoiceListener extends StatefulWidget {
  final Widget child;

  const NavigationVoiceListener({
    super.key,
    required this.child,
  });

  @override
  State<NavigationVoiceListener> createState() => _NavigationVoiceListenerState();
}

class _NavigationVoiceListenerState extends State<NavigationVoiceListener> {
  final VoiceGuidanceService _voiceGuidance = VoiceGuidanceService();
  NavigationState _previousNavState = const NavigationState();

  @override
  void initState() {
    super.initState();
    _voiceGuidance.init();
  }

  @override
  void dispose() {
    _voiceGuidance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NavigationBloc, NavigationState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.currentInstructionIndex != curr.currentInstructionIndex ||
          prev.isPreAnnounced != curr.isPreAnnounced,
      listener: (context, navState) {
        final prev = _previousNavState;
        _voiceGuidance.onNavigationStateChanged(prev, navState);
        _previousNavState = navState;
      },
      child: widget.child,
    );
  }
}
