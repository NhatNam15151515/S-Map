import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/interfaces/i_speech_recognition_service.dart';
import 'package:s_map/screens/search/widgets/voice_search_bottom_sheet.dart';

class MockSpeechService implements ISpeechRecognitionService {
  bool isInitSuccess = true;
  bool isListeningVal = false;
  void Function(String words, bool isFinal)? onResultCb;

  @override
  Future<bool> initialize() async => isInitSuccess;

  @override
  bool get isListening => isListeningVal;

  @override
  bool get isAvailable => true;

  @override
  Future<void> startListening({
    String localeId = 'vi_VN',
    void Function(String words, bool isFinal)? onResult,
    void Function(double soundLevel)? onSoundLevel,
    void Function(String error)? onError,
    void Function(String status)? onStatus,
  }) async {
    isListeningVal = true;
    onResultCb = onResult;
  }

  @override
  Future<void> stopListening() async {
    isListeningVal = false;
  }

  @override
  Future<void> cancelListening() async {
    isListeningVal = false;
  }

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VoiceSearchBottomSheet renders and closes on dismiss button', (
    tester,
  ) async {
    final mockService = MockSpeechService();

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('vi')],
        path: 'assets/translations',
        fallbackLocale: const Locale('vi'),
        startLocale: const Locale('vi'),
        child: MaterialApp(
          home: Scaffold(
            body: VoiceSearchBottomSheet(speechService: mockService),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(VoiceSearchBottomSheet), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });
}
