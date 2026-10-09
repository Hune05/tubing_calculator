// 튜브·전선관 계산기를 가로(눕힌 폰·태블릿)로 두고 탭을 모두 돌아도 넘치지 않는지,
// 키가 낮은 가로 폰에서는 아래 탭 막대가 얇아지는지(10-09 가로 화면 후속).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/history_card_info.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/main_navigation_page.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// 아래 탭 막대 전체(흰 바탕 상자) 높이.
double _navHeight(WidgetTester tester) {
  final bar = find.byType(BottomNavigationBar);
  final box = find.ancestor(of: bar, matching: find.byType(Container)).first;
  return tester.getSize(box).height;
}

/// 화면 크기(MediaQuery까지 바뀌게 view로 정한다).
void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  late Map<String, dynamic> defaults;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    defaults = Map<String, dynamic>.from(globalBenderSettings.value);
    MachineSpecs().resetForTest();
    TubeHistoryDb.load = () async => [];
    final rows = [
      {'length': 300.0, 'angle': 0.0, 'rotation': 0.0},
      {'length': 400.0, 'angle': 90.0, 'rotation': 0.0},
      {'length': 300.0, 'angle': 0.0, 'rotation': 0.0},
    ];
    MobileBendDataManager().bendList
      ..clear()
      ..addAll([for (final r in rows) Map<String, dynamic>.of(r)]);
    ConduitDataManager().bendList
      ..clear()
      ..addAll([for (final r in rows) Map<String, dynamic>.of(r)]);
  });
  tearDown(() => globalBenderSettings.value = defaults);

  final pages = <String, Widget Function()>{
    '튜브': () => const MobileCalculatorPage(),
    '전선관': () => const ConduitMainNavigation(),
  };

  for (final size in const [Size(900, 400), Size(640, 340), Size(1000, 560)]) {
    for (final e in pages.entries) {
      testWidgets(
        '${e.key} ${size.width.toInt()}×${size.height.toInt()}: 마킹·보관함·아이소·설정 탭이 넘치지 않는다',
        (tester) async {
          _size(tester, size);
          final errors = <String>[];
          final old = FlutterError.onError;
          FlutterError.onError = (d) =>
              errors.add(d.exceptionAsString().split('\n').first);
          try {
            await tester.pumpWidget(MaterialApp(home: e.value()));
            await _settle(tester);
            for (final tab in ['마킹', '보관함', '아이소', '설정', '입력']) {
              await tester.tap(find.text(tab).last);
              await _settle(tester);
            }
          } finally {
            FlutterError.onError = old;
          }
          expect(errors, isEmpty);
        },
      );
    }
  }

  for (final e in pages.entries) {
    testWidgets('${e.key}: 키가 낮은 가로 폰에서는 아래 탭 막대가 얇다', (tester) async {
      _size(tester, const Size(412, 900));
      await tester.pumpWidget(MaterialApp(home: e.value()));
      await _settle(tester);
      final tall = _navHeight(tester);
      tester.view.physicalSize = const Size(900, 400);
      await _settle(tester);
      final low = _navHeight(tester);
      expect(tall - low, greaterThanOrEqualTo(14));
    });
  }
}
