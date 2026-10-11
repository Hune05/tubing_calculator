// 철판 구멍 배치 편집(10-10): 판을 눌러 놓기, 끌어 옮기기(모눈 맞춤), 여러 개 고르기·줄 맞추기·대칭 복사,
// 되돌리기·다시 하기, 원형 배치, 장공 돌리기, 판 90° 돌리기, 지우기(되돌리기), 예전 저장(구멍 묶음) 옮기기.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_page.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_ui.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> openPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1700);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: PlatePage(share: (_) async {})));
    await tester.pumpAndSettle();
  }

  /// 철판 가공 화면(목록)은 보이는 곳 둘레만 그린다. 찾는 것이 아직 안 그려졌으면 위로 먼저, 그다음 아래로 굴려 찾는다.
  Future<void> see(WidgetTester tester, Finder f) async {
    Finder off() => find.byElementPredicate(
      (e) => f.evaluate().contains(e),
      skipOffstage: false,
    );
    if (f.evaluate().isEmpty) {
      for (final dy in const [400.0, -400.0]) {
        for (var k = 0; k < 25 && f.evaluate().isEmpty; k++) {
          final sc = find.byType(Scrollable).first;
          final pos = tester.state<ScrollableState>(sc).position;
          if ((dy > 0 && pos.pixels <= pos.minScrollExtent) ||
              (dy < 0 && pos.pixels >= pos.maxScrollExtent)) {
            break;
          }
          await tester.drag(sc, Offset(0, dy));
          await tester.pumpAndSettle();
        }
        if (f.evaluate().isNotEmpty) break;
      }
    }
    off();
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
  }

  /// 결과 표 한 줄을 "칸 | 칸" 글로.
  Future<String> row(WidgetTester tester, String key) async {
    await see(tester, find.byKey(Key(key)));
    return tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .join(' | ');
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await see(tester, find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  /// 평판 200 × 100 편집 화면에서 mm 자리 → 화면 점.
  Offset scr(
    WidgetTester tester,
    double x,
    double y, {
    double w = 200,
    double h = 100,
  }) {
    // 여백: 옆 40, 위 40, 아래 70(홀 넣기·고른 홀 단추 줄 자리)
    final r = tester.getRect(find.byKey(const Key('ed_canvas')));
    final s = math.min((r.width - 80) / w, (r.height - 110) / h);
    final cy = 40 + (r.height - 110) / 2;
    return r.topLeft +
        Offset(r.width / 2 + (x - w / 2) * s, cy - (y - h / 2) * s);
  }

  String status(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('ed_status'))).data!;

  Future<void> openFlatEditor(WidgetTester tester) async {
    await openPage(tester);
    // 레이저 절단 화면은 평판 200 × 100부터
    // 10-10: 편집 화면은 철판 가공의 "구멍" 탭 안에 있다
    await tester.tap(find.byKey(const Key('pl_tab_holes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ed_canvas')), findsOneWidget);
  }

  testWidgets('누르면 놓고, 끌면 모눈에 맞춰 옮긴다', (tester) async {
    await openFlatEditor(tester);
    await tap(tester, 'ed_mode_place');
    await tester.tapAt(scr(tester, 40, 30));
    await tester.pumpAndSettle();
    expect(
      status(tester),
      startsWith('홀 1 φ13.5: 왼쪽 40 · 아래 30 · 오른쪽 160 · 위 70'),
    );
    await tester.tapAt(scr(tester, 161, 71)); // 모눈 5에 붙어 160 · 70
    await tester.pumpAndSettle();
    expect(status(tester), startsWith('홀 2 φ13.5: 왼쪽 160 · 아래 70'));
    await tap(tester, 'ed_mode_sel');
    // 구멍 1을 오른쪽으로 20mm 끌기
    final from = scr(tester, 40, 30);
    final to = scr(tester, 60, 30);
    await tester.dragFrom(from, to - from);
    await tester.pumpAndSettle();
    expect(status(tester), startsWith('홀 1 φ13.5: 왼쪽 60 · 아래 30'));
    // 빈 곳을 누르면 고르기가 풀린다
    await tester.tapAt(scr(tester, 100, 90));
    await tester.pumpAndSettle();
    expect(status(tester), startsWith('홀을 눌러 선택하고'));
    // 결과 탭에 바로 들어가 있다
    await tester.tap(find.byKey(const Key('pl_tab_result')));
    await tester.pumpAndSettle();
    await see(tester, find.byKey(const Key("pl_hole_summary")));
    expect(find.textContaining('홀 2개 · φ13.5 2'), findsOneWidget);
  });

  testWidgets('다중 선택: 가로 줄 맞추기·좌우 대칭 복사, 되돌리기·다시 하기', (tester) async {
    await openFlatEditor(tester);
    await tap(tester, 'ed_mode_place');
    await tester.tapAt(scr(tester, 40, 30));
    await tester.tapAt(scr(tester, 70, 60));
    await tester.pumpAndSettle();
    await tap(tester, 'ed_mode_sel');
    await tap(tester, 'ed_multi');
    // 방금 놓은 구멍이 골라져 있으니 빈 곳을 눌러 풀고 시작
    await tester.tapAt(scr(tester, 100, 90));
    await tester.pumpAndSettle();
    await tester.tapAt(scr(tester, 40, 30));
    await tester.pumpAndSettle();
    await tester.tapAt(scr(tester, 70, 60));
    await tester.pumpAndSettle();
    expect(status(tester), '홀 2개 선택');
    await tap(tester, 'ed_align_h'); // 첫째(40, 30)의 높이로
    await tap(tester, 'ed_mirror_lr'); // 판 가운데(100) 기준 → 160, 130
    await tester.tap(find.byKey(const Key('pl_tab_result')));
    await tester.pumpAndSettle();
    await see(tester, find.byKey(const Key("pl_hole_summary")));
    expect(find.textContaining('홀 4개 · φ13.5 4'), findsOneWidget);
    await see(tester, find.byKey(const Key('pl_holes')));
    expect(await row(tester, 'pl_hole_row_2'), '2 | φ13.5 | 70 | 30');
    expect(await row(tester, 'pl_hole_row_3'), '3 | φ13.5 | 160 | 30');
    expect(await row(tester, 'pl_hole_row_4'), '4 | φ13.5 | 130 | 30');
    // 탭을 옮겨 다녀와도 편집 기록(되돌리기)은 남는다
    await tester.tap(find.byKey(const Key('pl_tab_holes')));
    await tester.pumpAndSettle();
    final undo = tester.widget<PlateCanvasButton>(
      find.byKey(const Key('ed_undo')),
    );
    expect(undo.onTap, isNotNull);
  });

  testWidgets('되돌리기·다시 하기, 지우기 알림으로 되돌리기', (tester) async {
    await openFlatEditor(tester);
    await tap(tester, 'ed_mode_place');
    await tester.tapAt(scr(tester, 40, 30));
    await tester.pumpAndSettle();
    await tap(tester, 'ed_undo');
    expect(status(tester), startsWith('판을 누르면'));
    await tap(tester, 'ed_redo');
    expect(status(tester), startsWith('판을 누르면')); // 고르기는 풀려 있다
    await tap(tester, 'ed_mode_sel');
    await tester.tapAt(scr(tester, 40, 30));
    await tester.pumpAndSettle();
    expect(status(tester), startsWith('홀 1 φ13.5'));
    await tap(tester, 'ed_del');
    expect(find.text('삭제했습니다: 홀 1개'), findsOneWidget);
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pl_tab_result')));
    await tester.pumpAndSettle();
    await see(tester, find.byKey(const Key("pl_hole_summary")));
    expect(find.textContaining('홀 1개 · φ13.5 1'), findsOneWidget);
  });

  testWidgets('장공을 놓고 15°씩 돌리기, 원형 배치(PCD)', (tester) async {
    await openFlatEditor(tester);
    await tap(tester, 'ed_mode_place');
    await tap(tester, 'ed_tslot_30');
    await tester.tapAt(scr(tester, 40, 50));
    await tester.pumpAndSettle();
    expect(status(tester), contains('장공 13.5×30(가로)'));
    await tap(tester, 'ed_spin_p15');
    expect(status(tester), contains('장공 13.5×30(15°)'));
    await tap(tester, 'ed_spin_90');
    expect(status(tester), contains('장공 13.5×30(105°)'));
    // 숫자로 넣기 → 원형 배치(센터 기준 0, 0에서 시작) → 가운데를 센터에서 가로 +30(= 130), PCD 60
    await tap(tester, 'ed_pcd');
    expect(find.byKey(const Key('hi_preview')), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('hs_x'))).controller!.text,
      '0',
    );
    await tester.enterText(find.byKey(const Key('hs_pcd')), '60');
    await tester.enterText(find.byKey(const Key('hs_x')), '30');
    await tester.pumpAndSettle();
    expect(find.text('넣기 (4개)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('hs_ok')));
    await tester.pumpAndSettle();
    expect(status(tester), '홀 4개 선택');
    await tester.tap(find.byKey(const Key('pl_tab_result')));
    await tester.pumpAndSettle();
    await see(tester, find.byKey(const Key("pl_hole_summary")));
    expect(find.textContaining('홀 5개 · '), findsOneWidget);
    await see(tester, find.byKey(const Key('pl_holes')));
    final x = 130 + 30 * math.cos(math.pi / 4);
    expect(
      await row(tester, 'pl_hole_row_2'),
      startsWith('2 | φ13.5 | ${x.toStringAsFixed(1)} | '),
    );
  });

  testWidgets('90° 회전: 판과 홀이 같이 돌고 요약에 나온다', (tester) async {
    await openFlatEditor(tester);
    await tap(tester, 'ed_mode_place');
    await tester.tapAt(scr(tester, 40, 20));
    await tester.pumpAndSettle();
    await tap(tester, 'ed_rot');
    await tester.tap(find.byKey(const Key('pl_tab_result')));
    await tester.pumpAndSettle();
    await see(tester, find.byKey(const Key("pl_hole_summary")));
    expect(find.textContaining('판 90° 회전'), findsOneWidget);
    await see(tester, find.textContaining(' 100 × 200 mm'));
    // 위 요약 줄(결과 탭에는 크기를 되풀이하지 않는다)
    expect(find.textContaining(' 100 × 200 mm'), findsOneWidget);
    // (40, 20) → (80, 40)
    expect(await row(tester, 'pl_hole_row_1'), '1 | φ13.5 | 80 | 40');
  });

  testWidgets('예전 저장(홀 묶음: 네 코너)은 하나하나로 풀어 옮긴다', (tester) async {
    SharedPreferences.setMockInitialValues({
      PlatePage.legacyDraftKey: jsonEncode({
        'bend': false,
        'sh': 'flat',
        'mat': 'steel',
        't': '3',
        'len': '200',
        'wid': '100',
        'holes': [
          {
            'f': 0,
            'd': 13.5,
            's': 0,
            'sx': true,
            'c': true,
            'n': 1,
            'x': 20,
            'y': 20,
            'p': 0,
            'rx': true,
          },
        ],
      }),
    });
    await openPage(tester);
    await tester.tap(find.byKey(const Key('pl_tab_result')));
    await tester.pumpAndSettle();
    await see(tester, find.byKey(const Key("pl_hole_summary")));
    expect(find.textContaining('홀 4개 · φ13.5 4'), findsOneWidget);
    expect(await row(tester, 'pl_hole_row_3'), '3 | φ13.5 | 180 | 80');
  });
}
