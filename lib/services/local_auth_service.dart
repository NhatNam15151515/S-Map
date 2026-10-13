import 'dart:async';

import 'package:s_map/commons/log/log.dart';
import 'package:local_auth/local_auth.dart';
import 'package:s_map/interfaces/interfaces.dart';

class FlutterLocalAuth implements ILocalAuthService {
  final LocalAuthentication _auth;

  FlutterLocalAuth({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  static FlutterLocalAuth instance = FlutterLocalAuth();
  Completer<bool> initCheckCompleter = Completer();

  @override
  bool get initDone => initCheckCompleter.isCompleted;

  final List<BiometricType> _availableBiometrics = [];
  @override
  bool get faceIdAvailable => _availableBiometrics.contains(BiometricType.face);

  @override
  Future<void> init() async {
    if (initDone) return;
    await getAvailableBio();
    if (!initCheckCompleter.isCompleted) {
      initCheckCompleter.complete(true);
    }
  }

  @override
  Future<void> getAvailableBio() async {
    try {
      DLog.info("LOADING BIOMETRICS");
      _availableBiometrics.addAll(await _auth.getAvailableBiometrics());
      DLog.info("LOADED BIOMETRICS");
    } catch (e) {
      DLog.error("Biometric availability error: $e");
    }
  }

  @override
  Future<bool> authenticate() async {
    await init();
    try {
      return await _auth.authenticate(
        localizedReason: 'Please authenticate to login',
        options: const AuthenticationOptions(
            useErrorDialogs: false, biometricOnly: true),
      );
    } catch (e) {
      DLog.error("Biometric authentication error: $e");
    }
    return false;
  }
}
