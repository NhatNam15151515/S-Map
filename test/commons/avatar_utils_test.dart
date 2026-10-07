import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/utils/avatar_utils.dart';
import 'package:s_map/models/user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AvatarUtils Tests', () {
    test('calculateCompressionRatio calculates correct ratio', () {
      const originalBytes = 100000; // ~100 KB
      // Base64 string representing ~10KB (10 * 1024 * 4 / 3 chars)
      final dummyBase64 = base64Encode(Uint8List(10000));

      final ratio = AvatarUtils.calculateCompressionRatio(
        originalBytesLength: originalBytes,
        base64String: dummyBase64,
      );

      expect(ratio, closeTo(90.0, 0.5));
    });

    test('estimateSizeKb estimates correctly', () {
      final sampleBytes = Uint8List(2048); // 2 KB
      final base64String = base64Encode(sampleBytes);
      final estimatedKb = AvatarUtils.estimateSizeKb(base64String);

      expect(estimatedKb, closeTo(2.0, 0.1));
    });

    test('compressToBase64 and decodeBase64 roundtrip', () async {
      // Create a simple 200x200 canvas image
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()..color = const ui.Color(0xFFFF0000);
      canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 200, 200), paint);
      final picture = recorder.endRecording();
      final image = await picture.toImage(200, 200);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final rawBytes = byteData!.buffer.asUint8List();

      // Compress to 128x128 Base64
      final base64String = await AvatarUtils.compressToBase64(rawBytes, targetSize: 128);
      expect(base64String.isNotEmpty, isTrue);

      // Verify decode back to bytes
      final decodedBytes = AvatarUtils.decodeBase64(base64String);
      expect(decodedBytes.length, greaterThan(0));

      // Payload size should be small (~less than 50 KB)
      final sizeKb = AvatarUtils.estimateSizeKb(base64String);
      expect(sizeKb, lessThan(50.0));
    });
  });

  group('User Model avatarBase64 Tests', () {
    test('toJson and fromJson preserves avatarBase64', () {
      final user = User(
        id: 'user_123',
        username: 'Nam AI',
        email: 'nam@example.com',
        avatarBase64: 'base64_sample_payload',
      );

      final json = user.toJson();
      expect(json['avatarBase64'], equals('base64_sample_payload'));

      final fromJsonUser = User.fromJson(json);
      expect(fromJsonUser.avatarBase64, equals('base64_sample_payload'));
      expect(fromJsonUser.id, equals('user_123'));
    });

    test('copyWith updates avatarBase64 correctly', () {
      final user = User(id: '1', username: 'Old');
      final updated = user.copyWith(avatarBase64: 'new_avatar_base64');

      expect(updated.id, equals('1'));
      expect(updated.username, equals('Old'));
      expect(updated.avatarBase64, equals('new_avatar_base64'));
    });
  });
}
