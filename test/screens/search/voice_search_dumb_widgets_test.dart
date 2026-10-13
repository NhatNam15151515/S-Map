import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/screens/search/widgets/voice_mic_visualizer.dart';
import 'package:s_map/screens/search/widgets/voice_search_action_buttons.dart';
import 'package:s_map/screens/search/widgets/voice_search_status_view.dart';

Widget createTestApp(Widget child) {
  return EasyLocalization(
    supportedLocales: const [Locale('vi')],
    path: 'assets/translations',
    fallbackLocale: const Locale('vi'),
    startLocale: const Locale('vi'),
    assetLoader: const CodegenLoader(),
    child: MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceMicVisualizer dumb widget tests', () {
    testWidgets('renders listening state and invokes onTap callback', (
      tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        createTestApp(
          VoiceMicVisualizer(
            isListening: true,
            isSuccess: false,
            isError: false,
            soundLevel: 0.5,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });

    testWidgets('renders success icon when isSuccess is true', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          VoiceMicVisualizer(
            isListening: false,
            isSuccess: true,
            isError: false,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('renders refresh icon when isError is true', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          VoiceMicVisualizer(
            isListening: false,
            isSuccess: false,
            isError: true,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });
  });

  group('VoiceSearchStatusView dumb widget tests', () {
    testWidgets('displays recognized text transcript when available', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const VoiceSearchStatusView(
            recognizedText: 'Hồ Gươm Hà Nội',
            isListening: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('"Hồ Gươm Hà Nội"'), findsOneWidget);
    });

    testWidgets('displays error status when isError is true', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const VoiceSearchStatusView(
            isError: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(VoiceSearchStatusView), findsOneWidget);
    });
  });

  group('VoiceSearchActionButtons dumb widget tests', () {
    testWidgets('renders open settings button when permission denied', (
      tester,
    ) async {
      bool openedSettings = false;

      await tester.pumpWidget(
        createTestApp(
          VoiceSearchActionButtons(
            isPermissionDenied: true,
            onOpenSettings: () {
              openedSettings = true;
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      expect(openedSettings, isTrue);
    });

    testWidgets('renders retry button when error occurs', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        createTestApp(
          VoiceSearchActionButtons(
            isError: true,
            onRetry: () {
              retried = true;
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      expect(retried, isTrue);
    });
  });
}
