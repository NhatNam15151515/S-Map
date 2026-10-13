import 'package:flutter/material.dart';
import 'package:s_map/commons/utils/app_colors.dart';

/// Dumb Widget hiển thị nút Micro và hiệu ứng sóng âm nhịp đập khi thu âm.
///
/// Hoàn toàn độc lập với business logic/BLoC; chỉ nhận dữ liệu và callbacks qua props.
class VoiceMicVisualizer extends StatefulWidget {
  final bool isListening;
  final bool isSuccess;
  final bool isError;
  final double soundLevel;
  final VoidCallback onTap;

  const VoiceMicVisualizer({
    super.key,
    required this.isListening,
    required this.isSuccess,
    required this.isError,
    this.soundLevel = 0.0,
    required this.onTap,
  });

  @override
  State<VoiceMicVisualizer> createState() => _VoiceMicVisualizerState();
}

class _VoiceMicVisualizerState extends State<VoiceMicVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isListening) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant VoiceMicVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isListening && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = widget.isError
        ? colorScheme.error
        : (widget.isSuccess ? AppColors.victorianGreenhouse : colorScheme.primary);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = widget.isListening ? _pulseController.value : 0.0;
        final soundScale = widget.isListening ? (widget.soundLevel * 0.4) : 0.0;
        final ringScale = 1.0 + (pulse * 0.25) + soundScale;

        return SizedBox(
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Vòng sóng âm ngoài (Outer pulse ring)
              if (widget.isListening)
                Container(
                  width: 110 * ringScale,
                  height: 110 * ringScale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withValues(alpha: 0.12 * (1.0 - pulse)),
                  ),
                ),

              // Vòng sóng âm trong (Inner pulse ring)
              if (widget.isListening)
                Container(
                  width: 86 * (1.0 + soundScale * 0.6),
                  height: 86 * (1.0 + soundScale * 0.6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withValues(alpha: 0.2),
                  ),
                ),

              // Nút Micro chính giữa
              Material(
                color: primaryColor,
                shape: const CircleBorder(),
                elevation: 4,
                shadowColor: primaryColor.withValues(alpha: 0.4),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onTap,
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: Center(
                      child: Icon(
                        widget.isSuccess
                            ? Icons.check_rounded
                            : (widget.isListening
                                ? Icons.mic_rounded
                                : (widget.isError
                                    ? Icons.refresh_rounded
                                    : Icons.mic_none_rounded)),
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
