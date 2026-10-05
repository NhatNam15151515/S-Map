import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/transformers/transformers.dart';

// Test Events
abstract class TestEvent {
  const TestEvent();
}

class IncrementEvent extends TestEvent {
  final int value;
  const IncrementEvent(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncrementEvent &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class AsyncDelayEvent extends TestEvent {
  final int value;
  final Duration delay;
  const AsyncDelayEvent(this.value, {this.delay = const Duration(milliseconds: 50)});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AsyncDelayEvent &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

// Test State
class TestState {
  final List<int> values;
  const TestState([this.values = const []]);
}

typedef TransformerBuilder = EventTransformer<E> Function<E>();

// Test Bloc
class TransformerTestBloc extends Bloc<TestEvent, TestState> {
  TransformerTestBloc(TransformerBuilder builder)
      : super(const TestState()) {
    on<IncrementEvent>(
      (event, emit) {
        emit(TestState([...state.values, event.value]));
      },
      transformer: builder(),
    );

    on<AsyncDelayEvent>(
      (event, emit) async {
        await Future.delayed(event.delay);
        if (emit.isDone || isClosed) return;
        emit(TestState([...state.values, event.value]));
      },
      transformer: builder(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Transformers Unit Tests', () {
    test('debounce skips rapid events and only emits latest after duration', () async {
      final bloc = TransformerTestBloc(
        <E>() => debounce<E>(const Duration(milliseconds: 40)),
      );

      bloc.add(const IncrementEvent(1));
      bloc.add(const IncrementEvent(2));
      bloc.add(const IncrementEvent(3));

      // Before debounce duration, no events emitted
      await Future.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.values, isEmpty);

      // After debounce duration, only the latest event (3) is processed
      await Future.delayed(const Duration(milliseconds: 60));
      expect(bloc.state.values, [3]);

      await bloc.close();
    });

    test('debounceRestartable debounces and cancels in-flight async operations', () async {
      final bloc = TransformerTestBloc(
        <E>() => debounceRestartable<E>(const Duration(milliseconds: 30)),
      );

      // First batch
      bloc.add(const AsyncDelayEvent(1, delay: Duration(milliseconds: 50)));
      await Future.delayed(const Duration(milliseconds: 40)); // passes debounce, starts processing 1

      // Second batch interrupts before 1 finishes
      bloc.add(const AsyncDelayEvent(2, delay: Duration(milliseconds: 20)));
      await Future.delayed(const Duration(milliseconds: 100));

      // Only 2 should be in state because 1 was restarted/cancelled
      expect(bloc.state.values, [2]);

      await bloc.close();
    });

    test('debounceDroppable debounces and drops new events if processing is active', () async {
      final bloc = TransformerTestBloc(
        <E>() => debounceDroppable<E>(const Duration(milliseconds: 20)),
      );

      bloc.add(const AsyncDelayEvent(1, delay: Duration(milliseconds: 60)));
      await Future.delayed(const Duration(milliseconds: 30)); // starts processing 1

      // Trigger while 1 is processing
      bloc.add(const AsyncDelayEvent(2, delay: Duration(milliseconds: 10)));
      await Future.delayed(const Duration(milliseconds: 30)); // 2 passes debounce while 1 is active

      await Future.delayed(const Duration(milliseconds: 80));
      expect(bloc.state.values, [1]); // 2 was dropped

      await bloc.close();
    });

    test('debounceSequential debounces and executes handlers sequentially', () async {
      final bloc = TransformerTestBloc(
        <E>() => debounceSequential<E>(const Duration(milliseconds: 20)),
      );

      bloc.add(const AsyncDelayEvent(1, delay: Duration(milliseconds: 30)));
      await Future.delayed(const Duration(milliseconds: 40)); // 1 starts

      bloc.add(const AsyncDelayEvent(2, delay: Duration(milliseconds: 10)));
      await Future.delayed(const Duration(milliseconds: 70));

      expect(bloc.state.values, [1, 2]);

      await bloc.close();
    });

    test('throttle emits leading event immediately and suppresses within duration', () async {
      final bloc = TransformerTestBloc(
        <E>() => throttle<E>(const Duration(milliseconds: 50)),
      );

      bloc.add(const IncrementEvent(1));
      bloc.add(const IncrementEvent(2));
      bloc.add(const IncrementEvent(3));

      await Future.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.values, [1]); // 1 emitted immediately, 2 & 3 throttled

      await Future.delayed(const Duration(milliseconds: 60));
      bloc.add(const IncrementEvent(4));
      await Future.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.values, [1, 4]); // 4 emitted after duration expired

      await bloc.close();
    });

    test('throttleRestartable executes leading event and restarts on subsequent valid event', () async {
      final bloc = TransformerTestBloc(
        <E>() => throttleRestartable<E>(const Duration(milliseconds: 40)),
      );

      bloc.add(const AsyncDelayEvent(1, delay: Duration(milliseconds: 80)));
      bloc.add(const AsyncDelayEvent(2, delay: Duration(milliseconds: 10))); // ignored by throttle

      await Future.delayed(const Duration(milliseconds: 50)); // throttle period ends, 1 still running

      bloc.add(const AsyncDelayEvent(3, delay: Duration(milliseconds: 20))); // cancels 1 and starts 3
      await Future.delayed(const Duration(milliseconds: 80));

      expect(bloc.state.values, [3]);

      await bloc.close();
    });

    test('throttleDroppable executes leading event and drops if busy or in throttle window', () async {
      final bloc = TransformerTestBloc(
        <E>() => throttleDroppable<E>(const Duration(milliseconds: 50)),
      );

      bloc.add(const AsyncDelayEvent(1, delay: Duration(milliseconds: 30)));
      bloc.add(const AsyncDelayEvent(2, delay: Duration(milliseconds: 10))); // throttled

      await Future.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.values, [1]);

      await Future.delayed(const Duration(milliseconds: 30));
      bloc.add(const AsyncDelayEvent(3, delay: Duration(milliseconds: 10)));
      await Future.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.values, [1, 3]);

      await bloc.close();
    });

    test('throttleSequential executes leading event and queues subsequent events sequentially', () async {
      final bloc = TransformerTestBloc(
        <E>() => throttleSequential<E>(const Duration(milliseconds: 40)),
      );

      bloc.add(const AsyncDelayEvent(1, delay: Duration(milliseconds: 30)));
      bloc.add(const AsyncDelayEvent(2, delay: Duration(milliseconds: 10))); // throttled

      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const AsyncDelayEvent(3, delay: Duration(milliseconds: 20)));

      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.values, [1, 3]);

      await bloc.close();
    });

    test('distinctEvent ignores consecutive identical events', () async {
      final bloc = TransformerTestBloc(
        <E>() => distinctEvent<E>(),
      );

      bloc.add(const IncrementEvent(1));
      bloc.add(const IncrementEvent(1));
      bloc.add(const IncrementEvent(2));
      bloc.add(const IncrementEvent(2));
      bloc.add(const IncrementEvent(1));

      await Future.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.values, [1, 2, 1]);

      await bloc.close();
    });
  });
}
