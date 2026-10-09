// 도면 위치 핀(10-10): 새 핀은 도면 그림 기준 0~1로 저장하고, 예전 핀(화면 몸통 기준)은 보여 줄 때
// 그림 기준으로 바꾼다. "이슈 도면"은 위치를 찍은 이슈를 번호 핀으로 보이고 누르면 상세로 간다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/plan_pin.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/floor_plan_pin_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/issue_plan_page.dart';

void main() {
  test('그림 칸·좌표 바꾸기: 가로 도면을 세로 화면에 놓으면 위아래가 빈다', () {
    const image = Size(400, 300);
    const box = Size(800, 1200);
    expect(containRect(image, box), const Rect.fromLTWH(0, 300, 800, 600));
    expect(boxPointToImage(const Offset(400, 600), image, box), const Offset(0.5, 0.5));
    expect(boxPointToImage(const Offset(0, 300), image, box), Offset.zero);
    // 예전 핀: 화면 몸통 기준 (0.5, 0.25)는 그림의 맨 위 가운데
    expect(
      legacyPinToImage(const Offset(0.5, 0.25), image, box),
      const Offset(0.5, 0),
    );
    // 그림 밖을 찍은 예전 핀은 그림 가장자리로
    expect(legacyPinToImage(const Offset(0.5, 0.05), image, box).dy, 0);
  });

  test('핀 읽기: 그림 기준 표시가 있으면 그대로, 없으면 바꾼다, 핀이 없으면 null', () {
    const image = Size(400, 300);
    const box = Size(800, 1200);
    expect(
      pinOnImageOf(
        {'locationPinDx': 0.2, 'locationPinDy': 0.3, kPinOnImageKey: true},
        image,
        legacyBox: box,
      ),
      const Offset(0.2, 0.3),
    );
    expect(
      pinOnImageOf(
        {'locationPinDx': 0.5, 'locationPinDy': 0.75},
        image,
        legacyBox: box,
      ),
      const Offset(0.5, 1),
    );
    expect(pinOnImageOf({'locationPinDx': 0.5}, image), isNull);
  });

  group('화면', () {
    late String planPath;
    setUpAll(() {
      final dir = Directory.systemTemp.createTempSync('plan_pin_test');
      planPath = '${dir.path}/plan.png';
      File('assets/images/tubing_master_logo.png').copySync(planPath);
    });
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> preload(WidgetTester tester) async {
      await tester.runAsync(() async {
        await planImageSize(planPath);
      });
    }

    testWidgets('핀 찍는 화면: 도면 가운데를 누르면 그림 기준 (0.5, 0.5)', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await preload(tester);
      Offset? got;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => got = await Navigator.push<Offset>(
                context,
                MaterialPageRoute(
                  builder: (_) => FloorPlanPinPage(imagePath: planPath),
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      final area = find.byKey(const Key('floor_plan_pin_area'));
      await tester.tapAt(tester.getCenter(area));
      await tester.pump();
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(got!.dx, closeTo(0.5, 0.01));
      expect(got!.dy, closeTo(0.5, 0.01));
    });

    testWidgets('이슈 도면: 미해결 핀만 번호로, 전체로 바꾸면 처리된 것도, 누르면 상세로', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await preload(tester);
      final opened = <String>[];
      final log = <String, dynamic>{
        'name': 'TEST',
        'floor_plan_image_path': planPath,
        'punch_lists': [
          {
            'id': 'a',
            'content': '서포트 간격',
            'priority': '긴급',
            'is_completed': false,
            'locationPinDx': 0.2,
            'locationPinDy': 0.3,
            kPinOnImageKey: true,
          },
          {
            'id': 'b',
            'content': '라벨 누락',
            'is_completed': true,
            'locationPinDx': 0.7,
            'locationPinDy': 0.6,
            kPinOnImageKey: true,
          },
          {'id': 'c', 'content': '위치 없음', 'is_completed': false},
        ],
      };
      expect(IssuePlanPage.hasPins(log), isTrue);
      await tester.pumpWidget(
        MaterialApp(
          home: IssuePlanPage(
            log: log,
            onOpenPunch: (p) async => opened.add(p['id'].toString()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('issue_plan_pin_1')), findsOneWidget);
      expect(find.byKey(const Key('issue_plan_pin_2')), findsNothing);
      expect(find.text('위치를 안 찍은 이슈 1건은 이슈 목록에만 있습니다.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('issue_plan_all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('issue_plan_pin_2')), findsOneWidget);
      await tester.tap(find.byKey(const Key('issue_plan_pin_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('issue_plan_row_2')));
      await tester.pumpAndSettle();
      expect(opened, ['a', 'b']);
    });
  });
}
