import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/widgets.dart';

class FakeRoutingRepository implements IRoutingRepository {
  Completer<RouteResult>? completer;

  @override
  Future<RouteResult> calculateRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  }) async {
    if (completer != null) {
      return completer!.future;
    }
    return const RouteResult(
      isSuccess: true,
      distance: 3500.0,
      time: 420000,
      points: [
        [21.0285, 105.8542],
        [21.0350, 105.8450],
      ],
    );
  }

  @override
  Future<bool> initializeEngine(String graphPath) async => true;

  @override
  Future<bool> isEngineReady() async => true;

  @override
  Future<bool> dispose() async => true;
}

Widget createTestableWidget(Widget child, {required RoutePreviewCubit cubit}) {
  return EasyLocalization(
    supportedLocales: const [Locale('vi'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('vi'),
    startLocale: const Locale('vi'),
    assetLoader: const CodegenLoader(),
    child: Builder(
      builder: (context) => BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(body: Center(child: child)),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    EasyLocalization.logger.enableLevels = [];
  });

  const origin = RoutePoint(
    lat: 21.0285,
    lon: 105.8542,
  );
  const destination = RoutePoint(
    lat: 21.0350,
    lon: 105.8450,
  );

  group('RoutePreviewBottomSheet Widget Tests', () {
    testWidgets('renders loading state when route calculation is in progress',
        (tester) async {
      final fakeRepo = FakeRoutingRepository();
      fakeRepo.completer = Completer<RouteResult>();
      final cubit = RoutePreviewCubit(routingRepository: fakeRepo);

      // Start calculating route (will remain in loading because completer is uncompleted)
      final future = cubit.getRoute(
        origin: origin,
        destination: destination,
        destinationName: 'Phở Bát Đàn',
      );

      await tester.pumpWidget(createTestableWidget(
        RoutePreviewBottomSheet(onClose: () {}),
        cubit: cubit,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(tr(LocaleKeys.routing_calculating_moped_route)), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Complete to finish async work cleanly
      fakeRepo.completer!.complete(const RouteResult(isSuccess: true));
      await future;
      await tester.pumpAndSettle();
      await cubit.close();
    });

    testWidgets('renders route details and triggers callbacks on button taps',
        (tester) async {
      bool closed = false;
      bool started = false;

      final fakeRepo = FakeRoutingRepository();
      final cubit = RoutePreviewCubit(routingRepository: fakeRepo);

      await cubit.getRoute(
        origin: origin,
        destination: destination,
        destinationName: 'Phở Bát Đàn',
      );

      await tester.pumpWidget(createTestableWidget(
        RoutePreviewBottomSheet(
          onClose: () => closed = true,
          onStartNavigation: () => started = true,
        ),
        cubit: cubit,
      ));
      await tester.pumpAndSettle();

      expect(
        find.text(RouteFormatHelper.formatDuration(420000)),
        findsOneWidget,
      );
      expect(find.text('(3.5 km)'), findsOneWidget);
      expect(find.text('Phở Bát Đàn'), findsOneWidget);
      expect(find.byIcon(Icons.two_wheeler_rounded), findsOneWidget);
      expect(find.byIcon(Icons.navigation_rounded), findsOneWidget);
      expect(find.text(tr(LocaleKeys.routing_start_navigation)), findsOneWidget);

      // Tap Start
      await tester.tap(find.text(tr(LocaleKeys.routing_start_navigation)));
      await tester.pump();
      expect(started, isTrue);

      // Tap Close
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(closed, isTrue);

      await cubit.close();
    });
  });
}
