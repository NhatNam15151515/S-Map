abstract class ILocalAuthService {
  bool get initDone;
  bool get faceIdAvailable;
  Future<void> init();
  Future<void> getAvailableBio();
  Future<bool> authenticate();
}
