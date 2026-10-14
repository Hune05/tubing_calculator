// 10-15 축 정렬 개편: 심 기록(시작 + 이번 작업 = 지금, 판 조합, 저장·다음에 이어 쓰기·이력)과 그림 연동.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/record_sync.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_guide_painter.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_math.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_page.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_record.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_render.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_session.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_shim.dart';

final _now = DateTime(2026, 10, 15, 10);
int _tick = 0;

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(700, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: AlignmentPage(
        share: (_) async {},
        now: () => _now.add(Duration(seconds: _tick++)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _step(WidgetTester tester, int i) async {
  await tester.tap(find.byKey(Key('align_step_$i')));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String v) async {
  await tester.enterText(find.byKey(Key('align_$key')), v);
  await tester.pump();
}

Future<void> _fill(WidgetTester tester) async {
  for (final (k, v) in [
    ('between', '200'),
    ('coupB', '100'),
    ('front', '150'),
    ('rear', '450'),
  ]) {
    await _type(tester, k, v);
  }
  await _step(tester, 1);
  for (final (k, v) in [
    ('a90', '-0.10'),
    ('a180', '-0.20'),
    ('a270', '-0.10'),
    ('b90', '0.05'),
    ('b180', '0.10'),
    ('b270', '0.05'),
  ]) {
    await _type(tester, k, v);
  }
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    recordRemote = () => null;
    _tick = 0;
  });

  group('셈', () {
    test('가진 심 두께로 판 조합(큰 것부터), 맞는 판이 없으면 남는 양', () {
      expect(shimPlates(1.25, kAlignShimSizesDefault).plates, [1.0, 0.2, 0.05]);
      expect(shimPlateText(1.25, kAlignShimSizesDefault), '1.0 + 0.2 + 0.05');
      expect(shimPlateText(-0.3, kAlignShimSizesDefault), '0.2 + 0.1');
      expect(shimPlateText(0.03, kAlignShimSizesDefault), '가진 심보다 얇음(0.03)');
      expect(shimPlateText(0.27, kAlignShimSizesDefault), '0.2 + 0.05 (0.02 모자람)');
      expect(shimPlateText(0, kAlignShimSizesDefault), '없음');
    });

    test('지금 심 = 시작 + 회차 누계, 같은 기계 지난 끝 심', () {
      final round = AlignRound(
        at: _now,
        offset: 0,
        angle100: 0,
        verdict: AlignVerdict.ok,
        shimFront: -0.1,
        shimRear: 0.2,
        moveFront: 0,
        moveRear: 0,
        done: {
          for (final f in AlignFoot.values)
            f: f.name.startsWith('front') ? -0.1 : 0.2,
        },
      );
      final now = footNow(
        {AlignFoot.frontLeft: 1.0, AlignFoot.rearLeft: 0.5},
        [round],
      );
      expect(now[AlignFoot.frontLeft], closeTo(0.9, 1e-9));
      expect(now[AlignFoot.rearLeft], closeTo(0.7, 1e-9));
      expect(now[AlignFoot.frontRight], closeTo(-0.1, 1e-9));
      AlignRecord rec(String id, String m, DateTime at, double v) =>
          AlignRecord(
            id: id,
            at: at,
            machine: m,
            method: AlignMethod.reverse,
            stage: AlignStage.after,
            rpm: 1800,
            offset: 0,
            angle100: 0,
            shimFront: 0,
            shimRear: 0,
            moveFront: 0,
            moveRear: 0,
            verdict: AlignVerdict.ok,
            footEnd: {for (final f in AlignFoot.values) f: v},
          );
      final all = [
        rec('1', '1호기 펌프', DateTime(2026, 9, 1), 0.5),
        rec('2', '1호기  펌프', DateTime(2026, 10, 1), 0.8),
        rec('3', '2호기', DateTime(2026, 10, 2), 9),
      ];
      expect(lastFeetFor(all, '1호기펌프')![AlignFoot.rearRight], 0.8);
      expect(shimHistory(all, '1호기 펌프').map((r) => r.id), ['2', '1']);
      expect(lastFeetFor(all, '없는 기계'), isNull);
      // 저장했다 읽어도 발 심이 남는다.
      final back = AlignRecord.fromJson(all[1].toJson());
      expect(back.footEnd[AlignFoot.frontLeft], 0.8);
      expect(buildAlignText(back), contains('발 밑 심(mm): 앞발 왼쪽 0.80'));
    });
  });

  testWidgets('심 기록: 시작 심 + 회차 = 지금, 저장하면 끝 심이 남고 다음에 이어진다', (tester) async {
    await _open(tester);
    await _fill(tester); // 앞발 빼기 0.14, 뒷발 빼기 0.21
    await _step(tester, 3);
    await tester.enterText(
      find.byKey(const Key('align_shim_machine')),
      '1호기 펌프',
    );
    for (final f in AlignFoot.values) {
      await tester.enterText(find.byKey(Key('align_start_${f.name}')), '1.0');
    }
    await tester.pump();
    expect(_text(tester, 'align_now_frontLeft'), '지금 1.00');

    // 결과에서 회차로 적기 → 심 기록으로 넘어가 "한 일" 창(계산값 그대로 저장)
    await _step(tester, 2);
    expect(find.byKey(const Key('align_plates_front')), findsOneWidget);
    await tester.tap(find.byKey(const Key('align_round_add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('align_done_ok')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'align_now_frontLeft'), '지금 0.86');
    expect(_text(tester, 'align_now_rearRight'), '지금 0.79');

    await tester.tap(find.byKey(const Key('align_save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('align_save_feet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('align_save_ok')));
    await tester.pumpAndSettle();
    final saved = (await AlignStore.load()).single;
    expect(saved.machine, '1호기 펌프');
    expect(saved.footStart[AlignFoot.frontLeft], 1.0);
    expect(saved.footEnd[AlignFoot.frontLeft], closeTo(0.86, 1e-9));
    // 저장 뒤 다음 작업은 지금 심에서 시작하고, 이 기계 이력이 보인다.
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('align_start_frontLeft')))
          .controller!
          .text,
      '0.86',
    );
    expect(find.byKey(Key('align_shim_hist_${saved.id}')), findsOneWidget);

    // 화면을 새로 열어도 기계·시작 심이 이어진다.
    await tester.pumpWidget(const SizedBox());
    await _open(tester);
    await _step(tester, 3);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('align_shim_machine')))
          .controller!
          .text,
      '1호기 펌프',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('align_start_rearRight')))
          .controller!
          .text,
      '0.79',
    );

    // 다른 기계 이름을 넣으면 그 기계 값(없으면 빈칸)으로, 다시 돌아오면 지난 끝 심으로(10-15 폰에서 찾은 문제).
    String start(String f) => tester
        .widget<TextField>(find.byKey(Key('align_start_$f')))
        .controller!
        .text;
    await tester.enterText(find.byKey(const Key('align_shim_machine')), '2호기');
    await tester.pump();
    expect(start('rearRight'), '');
    await tester.enterText(find.byKey(const Key('align_shim_machine')), '1호기 펌프');
    await tester.pump();
    expect(start('rearRight'), '0.79');
    // 손으로 고친 시작 심은 이름을 바꿔도 그대로 둔다.
    await tester.enterText(find.byKey(const Key('align_start_rearRight')), '0.5');
    await tester.enterText(find.byKey(const Key('align_shim_machine')), '3호기');
    await tester.pump();
    expect(start('rearRight'), '0.5');
  });

  testWidgets('그림 연동: 거리 칸을 누르면 그 치수 강조·값 표시, 지시값은 시계 바늘로', (tester) async {
    await _open(tester);
    await _type(tester, 'front', '150');
    await tester.tap(find.byKey(const Key('align_front')));
    await tester.pump();
    final setup =
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('align_setup_diagram')),
                )
                .painter
            as AlignSetupRenderPainter;
    expect(setup.highlight, 2);
    expect(setup.values[2], '150');

    await _step(tester, 1);
    await _type(tester, 'b180', '0.10');
    await tester.tap(find.byKey(const Key('align_b180')));
    await tester.pump();
    final clock =
        tester.widget<CustomPaint>(find.byKey(const Key('align_clock'))).painter
            as AlignClockPainter;
    expect(clock.title, contains('다이얼 B'));
    expect(clock.values![1], 0.10);
    expect(clock.highlight, 2);
  });

  testWidgets('처짐 값이 들어 있으면 "계산에 들어감"', (tester) async {
    SharedPreferences.setMockInitialValues({
      'align_draft_v1': '{"sagA":"-0.05","method":"reverse"}',
    });
    await _open(tester);
    expect(find.text('계산에 들어감'), findsOneWidget);
    expect(
      find.byKey(const Key('align_sagA')),
      findsOneWidget,
      reason: '처짐 칸은 늘 보인다',
    );
  });

  test('소프트 풋: 기준(0.05) 넘은 발과 기록 글', () {
    final v = softFootOf({'sf_frontLeft': '0.08', 'sf_rearRight': '0,03', 'sf_rearLeft': ''});
    expect(v.length, 2);
    expect(softFootOver(v), [AlignFoot.frontLeft]);
    expect(softFootList(v, softFootOver(v)), '앞발 왼쪽 0.08');
    expect(softFootOver({AlignFoot.frontRight: 0.05}), isEmpty, reason: '0.05는 기준 안쪽');
  });

  testWidgets('소프트 풋: 심 기록 탭에 넣으면 판정, 넘으면 결과 탭에 알림', (tester) async {
    await _open(tester);
    await _fill(tester);
    await _step(tester, 3);
    await _type(tester, 'sf_frontLeft', '0.08');
    await _type(tester, 'sf_rearLeft', '0.02');
    expect(
      tester.widget<Text>(find.descendant(of: find.byKey(const Key('align_softfoot_line')), matching: find.byType(Text))).data,
      contains('앞발 왼쪽 0.08'),
    );
    await _step(tester, 2);
    expect(find.byKey(const Key('align_softfoot_warn')), findsOneWidget);
    await _step(tester, 3);
    await _type(tester, 'sf_frontLeft', '0.04');
    await _step(tester, 2);
    expect(find.byKey(const Key('align_softfoot_warn')), findsNothing);
  });

  testWidgets('네 발 그림: 지금 심을 받는다', (tester) async {
    await _open(tester);
    await _step(tester, 3);
    await _type(tester, 'start_frontLeft', '0.5');
    final p = tester.widget<CustomPaint>(find.byKey(const Key('align_feet'))).painter as AlignFeetRenderPainter;
    expect(p.now[AlignFoot.frontLeft], 0.5);
    expect(tester.takeException(), isNull);
  });
}
