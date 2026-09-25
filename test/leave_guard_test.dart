// 뒤로 가기 한 번에 쓰던 것을 잃던 세 곳(점검 18번): 지난 일지 고치기, 새 이슈 등록, PC 설정.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/daily_report_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/punch_list_page.dart';
import 'package:tubing_calculator/src/presentation/settings/screens/settings_screen.dart';

import 'helpers_text.dart';

Future<void> openFrom(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1440, 3200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => page)),
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

Future<void> back(WidgetTester tester) async {
  // 폰의 뒤로 가기와 같다.
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

bool atHome() => find.text('열기').evaluate().isNotEmpty;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('지난 일지 고치기', () {
    Map<String, dynamic> report() => {
      'id': 'r1',
      'date': '09/20',
      'dateISO': '2026-09-20T08:00:00.000',
      'points': 12,
      'note': '결선 작업',
    };

    testWidgets('안 고쳤으면 그냥 닫힌다', (tester) async {
      await openFrom(tester, DailyReportPage(existingData: report()));
      await back(tester);
      expect(atHome(), isTrue);
    });

    testWidgets('고친 것이 있으면 묻고, 계속 고치기를 누르면 남는다', (tester) async {
      await openFrom(tester, DailyReportPage(existingData: report()));
      await tester.enterText(
        find.widgetWithText(TextField, '결선 작업'),
        '결선 작업 + 라벨',
      );
      await tester.pump();
      await back(tester);
      // 예전: 묻지 않고 닫혀 고친 것이 사라졌다.
      expect(findText('고친 것을 버리겠습니까?'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(atHome(), isFalse);
      expect(find.text('결선 작업 + 라벨'), findsOneWidget);

      await back(tester);
      await tester.tap(find.text('버리기'));
      await tester.pumpAndSettle();
      expect(atHome(), isTrue);
    });
  });

  group('새 이슈 등록', () {
    testWidgets('아무것도 안 썼으면 그냥 닫힌다', (tester) async {
      await openFrom(tester, const PunchListPage());
      await back(tester);
      expect(atHome(), isTrue);
    });

    testWidgets('쓴 것이 있으면 묻는다', (tester) async {
      await openFrom(tester, const PunchListPage());
      await tester.enterText(find.byType(TextField).first, '3층 배관');
      await tester.pump();
      await back(tester);
      expect(findText('쓰던 이슈를 버리겠습니까?'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(atHome(), isFalse);
    });
  });

  group('PC 설정', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async =>
                const StandardMessageCodec().encodeMessage(<Object?>[]),
          );
    });

    testWidgets('적용하지 않고 나가면 묻고, 적용하고 나가기를 고를 수 있다', (tester) async {
      await openFrom(tester, const SettingsScreen());
      await back(tester);
      expect(atHome(), isTrue); // 안 바꿨으면 그냥

      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      final sw = find.byType(Switch).first;
      await tester.ensureVisible(sw);
      await tester.tap(sw);
      await tester.pumpAndSettle();
      await back(tester);
      // 예전: 묻지 않고 닫혀 고친 설정이 사라졌다.
      expect(find.text('적용하지 않은 설정이 있습니다'), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings_apply_leave')));
      await tester.pumpAndSettle();
      expect(atHome(), isTrue);
    });
  });
}
