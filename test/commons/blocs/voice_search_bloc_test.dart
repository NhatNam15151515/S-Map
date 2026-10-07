import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/blocs/voice_search_bloc/voice_search_bloc.dart';
import 'package:s_map/commons/blocs/voice_search_bloc/voice_search_event.dart';
import 'package:s_map/commons/blocs/voice_search_bloc/voice_search_state.dart';
import 'package:s_map/interfaces/i_speech_recognition_service.dart';

class FakeSpeechRecognitionService implements ISpeechRecognitionService {
  bool initSuccess = true;
  bool isListeningValue = false;
  bool isAvailableValue = true;
  void Function(String words, bool isFinal)? onResultCallback;
  void Function(double soundLevel)? onSoundLevelCallback;
  void Function(String error)? onErrorCallback;

  @override
  Future<bool> initialize() async => initSuccess;

  @override
  bool get isListening => isListeningValue;

  @override
  bool get isAvailable => isAvailableValue;

  @override
  Future<void> startListening({
    String localeId = 'vi_VN',
    void Function(String words, bool isFinal)? onResult,
    void Function(double soundLevel)? onSoundLevel,
    void Function(String error)? onError,
    void Function(String status)? onStatus,
  }) async {
    isListeningValue = true;
    onResultCallback = onResult;
    onSoundLevelCallback = onSoundLevel;
    onErrorCallback = onError;
  }

  @override
  Future<void> stopListening() async {
    isListeningValue = false;
  }

  @override
  Future<void> cancelListening() async {
    isListeningValue = false;
  }

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSpeechRecognitionService fakeService;
  late VoiceSearchBloc bloc;

  setUp(() {
    fakeService = FakeSpeechRecognitionService();
    bloc = VoiceSearchBloc(speechService: fakeService);
  });

  tearDown(() {
    bloc.close();
  });

  group('VoiceSearchBloc', () {
    test('initial state is correct', () {
      expect(bloc.state.status, VoiceSearchStatus.initial);
      expect(bloc.state.recognizedText, '');
      expect(bloc.state.soundLevel, 0.0);
      expect(bloc.state.isFinal, false);
    });

    test('emits listening state when VoiceSearchStarted succeeds', () async {
      bloc.add(const VoiceSearchStarted());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<VoiceSearchState>((s) => s.status == VoiceSearchStatus.initializing),
          predicate<VoiceSearchState>((s) => s.status == VoiceSearchStatus.listening),
        ]),
      );
    });

    test('emits intermediate and final results correctly', () async {
      bloc.add(const VoiceSearchStarted());
      await pumpEventQueue();

      bloc.add(const VoiceSearchResultReceived('Hồ Gươm', isFinal: false));
      await pumpEventQueue();

      expect(bloc.state.status, VoiceSearchStatus.listening);
      expect(bloc.state.recognizedText, 'Hồ Gươm');
      expect(bloc.state.isFinal, false);

      bloc.add(const VoiceSearchResultReceived('Hồ Gươm Hà Nội', isFinal: true));
      await pumpEventQueue();

      expect(bloc.state.status, VoiceSearchStatus.success);
      expect(bloc.state.recognizedText, 'Hồ Gươm Hà Nội');
      expect(bloc.state.isFinal, true);
    });

    test('updates soundLevel when listening', () async {
      bloc.add(const VoiceSearchStarted());
      await pumpEventQueue();

      bloc.add(const VoiceSearchSoundLevelChanged(0.75));
      await pumpEventQueue();

      expect(bloc.state.soundLevel, 0.75);
    });

    test('emits success on VoiceSearchStopped if text is present', () async {
      bloc.add(const VoiceSearchStarted());
      await pumpEventQueue();

      bloc.add(const VoiceSearchResultReceived('Bến Thành', isFinal: false));
      await pumpEventQueue();

      bloc.add(const VoiceSearchStopped());
      await pumpEventQueue();

      expect(bloc.state.status, VoiceSearchStatus.success);
      expect(bloc.state.recognizedText, 'Bến Thành');
      expect(bloc.state.isFinal, true);
    });

    test('emits initial on VoiceSearchCancelled', () async {
      bloc.add(const VoiceSearchStarted());
      await pumpEventQueue();

      bloc.add(const VoiceSearchCancelled());
      await pumpEventQueue();

      expect(bloc.state.status, VoiceSearchStatus.initial);
    });

    test('emits error on VoiceSearchErrorOccurred if no text recognized', () async {
      bloc.add(const VoiceSearchStarted());
      await pumpEventQueue();

      bloc.add(const VoiceSearchErrorOccurred('No speech recognized'));
      await pumpEventQueue();

      expect(bloc.state.status, VoiceSearchStatus.error);
      expect(bloc.state.errorMessage, 'No speech recognized');
    });

    test('emits unavailable when speech engine fails initialization', () async {
      fakeService.initSuccess = false;
      bloc.add(const VoiceSearchStarted());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<VoiceSearchState>((s) => s.status == VoiceSearchStatus.initializing),
          predicate<VoiceSearchState>((s) => s.status == VoiceSearchStatus.unavailable),
        ]),
      );
    });
  });
}
