import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/utils/turn_by_turn_engine.dart';
import 'package:s_map/models/models.dart';

void main() {
  group('InstructionType & RouteInstruction Tests', () {
    test('InstructionType.fromSign maps all standard GraphHopper signs correctly', () {
      expect(InstructionType.fromSign(-99), equals(InstructionType.unknown));
      expect(InstructionType.fromSign(-98), equals(InstructionType.uTurnUnknown));
      expect(InstructionType.fromSign(-8), equals(InstructionType.uTurnLeft));
      expect(InstructionType.fromSign(-7), equals(InstructionType.keepLeft));
      expect(InstructionType.fromSign(-6), equals(InstructionType.leaveRoundabout));
      expect(InstructionType.fromSign(-3), equals(InstructionType.turnSharpLeft));
      expect(InstructionType.fromSign(-2), equals(InstructionType.turnLeft));
      expect(InstructionType.fromSign(-1), equals(InstructionType.turnSlightLeft));
      expect(InstructionType.fromSign(0), equals(InstructionType.continueStraight));
      expect(InstructionType.fromSign(1), equals(InstructionType.turnSlightRight));
      expect(InstructionType.fromSign(2), equals(InstructionType.turnRight));
      expect(InstructionType.fromSign(3), equals(InstructionType.turnSharpRight));
      expect(InstructionType.fromSign(4), equals(InstructionType.arrive));
      expect(InstructionType.fromSign(5), equals(InstructionType.reachedVia));
      expect(InstructionType.fromSign(6), equals(InstructionType.useRoundabout));
      expect(InstructionType.fromSign(7), equals(InstructionType.keepRight));
      expect(InstructionType.fromSign(8), equals(InstructionType.uTurnRight));
      expect(InstructionType.fromSign(999), equals(InstructionType.unknown));
    });

    test('InstructionType helper getters behave correctly', () {
      expect(InstructionType.turnLeft.isTurnLeft, isTrue);
      expect(InstructionType.turnSharpLeft.isTurnLeft, isTrue);
      expect(InstructionType.turnSlightLeft.isTurnLeft, isTrue);
      expect(InstructionType.turnRight.isTurnLeft, isFalse);

      expect(InstructionType.turnRight.isTurnRight, isTrue);
      expect(InstructionType.turnSharpRight.isTurnRight, isTrue);
      expect(InstructionType.turnSlightRight.isTurnRight, isTrue);
      expect(InstructionType.turnLeft.isTurnRight, isFalse);

      expect(InstructionType.continueStraight.isStraight, isTrue);
      expect(InstructionType.useRoundabout.isRoundabout, isTrue);
      expect(InstructionType.leaveRoundabout.isRoundabout, isTrue);
      expect(InstructionType.arrive.isArrive, isTrue);

      expect(InstructionType.uTurnLeft.isUTurn, isTrue);
      expect(InstructionType.uTurnRight.isUTurn, isTrue);
      expect(InstructionType.uTurnUnknown.isUTurn, isTrue);

      expect(InstructionType.keepLeft.isKeepLeft, isTrue);
      expect(InstructionType.keepRight.isKeepRight, isTrue);
    });

    test('RouteInstruction type, startPoint, and endPoint return expected values', () {
      const ins = RouteInstruction(
        text: 'Rẽ trái vào Tràng Tiền',
        streetName: 'Tràng Tiền',
        distance: 250.0,
        time: 30000,
        sign: -2,
        points: [
          [21.0285, 105.8542],
          [21.0286, 105.8550],
          [21.0290, 105.8560],
        ],
      );

      expect(ins.type, equals(InstructionType.turnLeft));
      expect(ins.startPoint, equals([21.0285, 105.8542]));
      expect(ins.endPoint, equals([21.0290, 105.8560]));
    });

    test('RouteInstruction with empty points returns null for startPoint and endPoint', () {
      const emptyIns = RouteInstruction(
        text: 'Đi thẳng',
        streetName: 'Nguyễn Du',
        distance: 0.0,
        time: 0,
        sign: 0,
        points: [],
      );

      expect(emptyIns.startPoint, isNull);
      expect(emptyIns.endPoint, isNull);
    });
  });

  group('InstructionProgress Model Tests', () {
    test('copyWith and props behave as expected', () {
      const initial = InstructionProgress.initial(
        distanceToNextInstruction: 350.0,
        remainingDistance: 1200.0,
        remainingDurationMs: 120000,
      );

      expect(initial.currentInstructionIndex, equals(0));
      expect(initial.isPreAnnounced, isFalse);
      expect(initial.hasArrived, isFalse);
      expect(initial.distanceToNextInstruction, equals(350.0));

      final updated = initial.copyWith(
        currentInstructionIndex: 1,
        isPreAnnounced: true,
        hasArrived: false,
        distanceToNextInstruction: 150.0,
        remainingDistance: 850.0,
      );

      expect(updated.currentInstructionIndex, equals(1));
      expect(updated.isPreAnnounced, isTrue);
      expect(updated.distanceToNextInstruction, equals(150.0));
      expect(updated.remainingDistance, equals(850.0));
    });
  });

  group('TurnByTurnEngine Unit Tests', () {
    const engine = TurnByTurnEngine(
      advanceThresholdMeters: 30.0,
      preAnnounceThresholdMeters: 200.0,
      arrivalThresholdMeters: 20.0,
    );

    final sampleInstructions = [
      const RouteInstruction(
        text: 'Đi thẳng trên đường Lê Duẩn',
        streetName: 'Lê Duẩn',
        distance: 500.0,
        time: 60000,
        sign: 0,
        points: [
          [21.0200, 105.8400],
          [21.0220, 105.8400],
          [21.0245, 105.8400], // Maneuver waypoint at start of next step
        ],
      ),
      const RouteInstruction(
        text: 'Rẽ phải vào Trần Hưng Đạo',
        streetName: 'Trần Hưng Đạo',
        distance: 300.0,
        time: 40000,
        sign: 2,
        points: [
          [21.0245, 105.8400],
          [21.0245, 105.8420],
          [21.0245, 105.8435], // Next waypoint
        ],
      ),
      const RouteInstruction(
        text: 'Rẽ trái vào Quán Sứ',
        streetName: 'Quán Sứ',
        distance: 200.0,
        time: 25000,
        sign: -2,
        points: [
          [21.0245, 105.8435],
          [21.0260, 105.8435],
        ],
      ),
      const RouteInstruction(
        text: 'Đến đích tại Nhà hát Lớn',
        streetName: 'Nhà hát Lớn',
        distance: 0.0,
        time: 0,
        sign: 4,
        points: [
          [21.0260, 105.8435],
        ],
      ),
    ];

    test('initializeProgress sets initial instruction, next instruction and total distance/ETA', () {
      final progress = engine.initializeProgress(sampleInstructions);

      expect(progress.currentInstructionIndex, equals(0));
      expect(progress.currentInstruction?.text, equals('Đi thẳng trên đường Lê Duẩn'));
      expect(progress.nextInstruction?.text, equals('Rẽ phải vào Trần Hưng Đạo'));
      expect(progress.remainingDistance, equals(1000.0));
      expect(progress.remainingDurationMs, equals(125000));
      expect(progress.isPreAnnounced, isFalse);
      expect(progress.hasArrived, isFalse);
    });

    test('initializeProgress handles empty instruction list gracefully', () {
      final progress = engine.initializeProgress([]);
      expect(progress.currentInstructionIndex, equals(0));
      expect(progress.currentInstruction, isNull);
      expect(progress.remainingDistance, equals(0.0));
      expect(progress.remainingDurationMs, equals(0));
    });

    test('updateProgress triggers pre-announcement when vehicle is within 200m of turn', () {
      // Step 0 maneuver waypoint is (21.0245, 105.8400).
      // At (21.0232, 105.8400), distance to maneuver is ~144m (<= 200m)
      final progress = engine.updateProgress(
        currentLat: 21.0232,
        currentLon: 105.8400,
        instructions: sampleInstructions,
        currentInstructionIndex: 0,
      );

      expect(progress.currentInstructionIndex, equals(0));
      expect(progress.isPreAnnounced, isTrue);
      expect(progress.distanceToNextInstruction, lessThanOrEqualTo(200.0));
      expect(progress.distanceToNextInstruction, greaterThanOrEqualTo(30.0));
      expect(progress.hasArrived, isFalse);
    });

    test('updateProgress advances to next instruction when within 30m of maneuver point', () {
      // Maneuver point for step 0 -> step 1 is (21.0245, 105.8400)
      // At (21.0244, 105.8400), distance to maneuver is ~11m (< 30m)
      final progress = engine.updateProgress(
        currentLat: 21.0244,
        currentLon: 105.8400,
        instructions: sampleInstructions,
        currentInstructionIndex: 0,
      );

      // Should automatically advance to step 1
      expect(progress.currentInstructionIndex, equals(1));
      expect(progress.currentInstruction?.text, equals('Rẽ phải vào Trần Hưng Đạo'));
      expect(progress.nextInstruction?.text, equals('Rẽ trái vào Quán Sứ'));
      expect(progress.hasArrived, isFalse);
    });

    test('updateProgress advances sequentially through steps and detects arrival at destination', () {
      // 1. Moving along step 1 toward (21.0245, 105.8435)
      final progressStep1 = engine.updateProgress(
        currentLat: 21.0245,
        currentLon: 105.8434, // ~10m from step 1 end -> advances to step 2
        instructions: sampleInstructions,
        currentInstructionIndex: 1,
      );
      expect(progressStep1.currentInstructionIndex, equals(2));
      expect(progressStep1.currentInstruction?.text, equals('Rẽ trái vào Quán Sứ'));

      // 2. Moving along step 2 toward destination (21.0260, 105.8435)
      final progressStep2 = engine.updateProgress(
        currentLat: 21.0259,
        currentLon: 105.8435, // ~11m from step 2 end -> advances to step 3 (arrive)
        instructions: sampleInstructions,
        currentInstructionIndex: 2,
      );
      expect(progressStep2.currentInstructionIndex, equals(3));
      expect(progressStep2.currentInstruction?.type, equals(InstructionType.arrive));

      // 3. Reached destination within arrival threshold (< 20m)
      final progressArrive = engine.updateProgress(
        currentLat: 21.0260,
        currentLon: 105.8435,
        instructions: sampleInstructions,
        currentInstructionIndex: 3,
      );
      expect(progressArrive.hasArrived, isTrue);
      expect(progressArrive.remainingDistance, equals(0.0));
      expect(progressArrive.remainingDurationMs, equals(0));
      expect(progressArrive.isPreAnnounced, isFalse);
    });

    test('updateProgress handles boundary index and corrupted data safely', () {
      final progressOutOfBounds = engine.updateProgress(
        currentLat: 21.0200,
        currentLon: 105.8400,
        instructions: sampleInstructions,
        currentInstructionIndex: 999, // out of bounds index
      );

      expect(progressOutOfBounds.currentInstructionIndex, equals(sampleInstructions.length - 1));

      final progressEmpty = engine.updateProgress(
        currentLat: 21.0200,
        currentLon: 105.8400,
        instructions: [],
        currentInstructionIndex: 0,
      );
      expect(progressEmpty.hasArrived, isFalse);
    });
  });
}
