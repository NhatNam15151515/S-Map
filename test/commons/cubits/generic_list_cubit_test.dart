import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/cubits/generic_list_cubit/generic_list_cubit.dart';
import 'package:s_map/commons/cubits/generic_list_cubit/generic_list_cubit_state.dart';

void main() {
  group('GenericListCubit Tests', () {
    test('Initial state is correct', () {
      final cubit = GenericListCubit<String>(
        future: (page, limit) async => ['item1', 'item2'],
      );
      expect(cubit.state.type, GenericListStateType.initial);
      expect(cubit.state.value, isEmpty);
      expect(cubit.state.errorMessage, isNull);
      cubit.close();
    });

    test('request loads first page items successfully', () async {
      final cubit = GenericListCubit<String>(
        future: (page, limit) async => ['A', 'B', 'C'],
        limit: 3,
      );

      await cubit.request();

      expect(cubit.state.type, GenericListStateType.succeed);
      expect(cubit.state.value, ['A', 'B', 'C']);
      expect(cubit.canLoadMore, true);
      cubit.close();
    });

    test('loadMore appends next page items successfully', () async {
      final cubit = GenericListCubit<String>(
        future: (page, limit) async {
          if (page == 1) return ['A', 'B'];
          if (page == 2) return ['C', 'D'];
          return [];
        },
        limit: 2,
      );

      await cubit.request();
      expect(cubit.state.value, ['A', 'B']);

      await cubit.loadMore();
      expect(cubit.state.value, ['A', 'B', 'C', 'D']);
      expect(cubit.state.type, GenericListStateType.succeed);
      cubit.close();
    });

    test('refresh reloads from page 1 and replaces current items', () async {
      int fetchCount = 0;
      final cubit = GenericListCubit<String>(
        future: (page, limit) async {
          fetchCount++;
          return ['Item_$fetchCount'];
        },
        limit: 10,
      );

      await cubit.request();
      expect(cubit.state.value, ['Item_1']);

      await cubit.refresh();
      expect(cubit.state.value, ['Item_2']);
      expect(cubit.state.type, GenericListStateType.succeed);
      cubit.close();
    });
  });
}
