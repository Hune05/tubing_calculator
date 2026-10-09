// 마킹 카드: 가로로 넓으면 두 줄로 나란히, 세로(좁으면)는 예전처럼 한 줄(10-09 가로 화면).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_result_tab.dart';

Future<List<String>> _pump(WidgetTester tester, Size size, Widget tab) async {
  final errors = <String>[];
  final old = FlutterError.onError;
  FlutterError.onError = (d) =>
      errors.add(d.exceptionAsString().split('\n').first);
  try {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: tab)));
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = old;
  }
  addTearDown(() => tester.binding.setSurfaceSize(null));
  return errors;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final rows = [
    {'length': 300.0, 'angle': 0.0, 'rotation': 0.0},
    {'length': 400.0, 'angle': 90.0, 'rotation': 0.0},
    {'length': 500.0, 'angle': 90.0, 'rotation': 90.0},
    {'length': 300.0, 'angle': 0.0, 'rotation': 0.0},
  ];

  for (final e in <String, Widget Function()>{
    '튜브': () => const MobileResultTab(startDir: 'RIGHT'),
    '전선관': () => const ConduitResultTab(),
  }.entries) {
    testWidgets('${e.key}: 가로 1000에서 카드가 두 줄로 나란히, 넘침 없음', (tester) async {
      MobileBendDataManager().bendList
        ..clear()
        ..addAll([for (final r in rows) Map<String, dynamic>.of(r)]);
      ConduitDataManager().bendList
        ..clear()
        ..addAll([for (final r in rows) Map<String, dynamic>.of(r)]);
      final errors = await _pump(tester, const Size(1000, 1400), e.value());
      expect(errors, isEmpty);
      expect(find.byKey(const ValueKey('mark_row_0')), findsOneWidget);
      // 첫 줄 두 카드가 같은 높이 선에서 시작한다(왼쪽·오른쪽).
      final row = find.byKey(const ValueKey('mark_row_0'));
      final kids = tester.widget<Row>(row).children;
      expect(kids.whereType<Expanded>(), hasLength(2));
      final l = tester.getTopLeft(find.byWidget(kids.first));
      final r = tester.getTopLeft(find.byWidget(kids.last));
      expect(l.dy, r.dy);
      expect(r.dx, greaterThan(l.dx + 300));
    });

    testWidgets('${e.key}: 가로 640(작은 폰 가로)도 넘침 없음', (tester) async {
      MobileBendDataManager().bendList
        ..clear()
        ..addAll([for (final r in rows) Map<String, dynamic>.of(r)]);
      ConduitDataManager().bendList
        ..clear()
        ..addAll([for (final r in rows) Map<String, dynamic>.of(r)]);
      final errors = await _pump(tester, const Size(640, 1400), e.value());
      expect(errors, isEmpty);
      expect(find.byKey(const ValueKey('mark_row_0')), findsNothing);
    });

    testWidgets('${e.key}: 세로 폭 412에서는 예전처럼 한 줄', (tester) async {
      MobileBendDataManager().bendList
        ..clear()
        ..addAll([for (final r in rows) Map<String, dynamic>.of(r)]);
      ConduitDataManager().bendList
        ..clear()
        ..addAll([for (final r in rows) Map<String, dynamic>.of(r)]);
      final errors = await _pump(tester, const Size(412, 2400), e.value());
      expect(errors, isEmpty);
      expect(find.byKey(const ValueKey('mark_row_0')), findsNothing);
    });
  }
}
