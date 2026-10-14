// 10-15 고정 발 고르기(펌프도 움직이기)와 3점 측정의 셈.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/record_sync.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_page.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_math.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_plan.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_record.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_session.dart';

void main() {
  // 손 예제: A −0.10/−0.20/−0.10, B 0.05/0.10/0.05, 거리 200/100/150/450 → 앞발 빼기 0.14, 뒷발 빼기 0.21
  final r = solveReverse(
    a90: -0.10, a180: -0.20, a270: -0.10,
    b90: 0.05, b180: 0.10, b270: 0.05,
    betweenPlanes: 200, couplingFromB: 100, frontFoot: 150, rearFoot: 450,
  );
  const xFront = 100.0 + 150, xRear = 100.0 + 450; // xA = −100 + 200 = 100
  AlignPlan plan(Set<AlignFootPos> fixed) => alignPlan(
    r: r, fixed: fixed, xFront: xFront, xRear: xRear, pumpInner: 200, pumpOuter: 700,
  );

  test('펌프 두 발 고정이면 지금 결과와 같다', () {
    final p = plan(kAlignFixedDefault);
    expect(p.feet[AlignFootPos.motorFront]!.shim, closeTo(r.shimFront, 1e-9));
    expect(p.feet[AlignFootPos.motorRear]!.shim, closeTo(r.shimRear, 1e-9));
    expect(p.feet[AlignFootPos.pumpInner]!.shim, closeTo(0, 1e-9));
    expect(p.pumpMoves, isFalse);
  });

  test('어느 두 발을 고정해도 고친 뒤 두 축이 맞는다(고정 발은 0)', () {
    const all = AlignFootPos.values;
    for (var i = 0; i < 4; i++) {
      for (var j = i + 1; j < 4; j++) {
        final fixed = {all[i], all[j]};
        final p = plan(fixed);
        for (final f in fixed) {
          expect(p.feet[f]!.shim, closeTo(0, 1e-9), reason: '$fixed $f');
        }
        // 고친 뒤: 모터 축(지금 + 보정) − 펌프 축(보정) = 0 이 모든 x에서(직선 두 점으로 확인)
        double pumpLine(double x) {
          final pi = p.feet[AlignFootPos.pumpInner]!.shim, po = p.feet[AlignFootPos.pumpOuter]!.shim;
          final b = (pi - po) / (-200 - -700);
          return pi + b * (x - -200);
        }
        double motorFix(double x) {
          final mf = p.feet[AlignFootPos.motorFront]!.shim, mr = p.feet[AlignFootPos.motorRear]!.shim;
          final b = (mf - mr) / (xFront - xRear);
          return mf + b * (x - xFront);
        }
        for (final x in [-500.0, 0.0, 300.0]) {
          expect(r.vertical.at(x) + motorFix(x) - pumpLine(x), closeTo(0, 1e-9), reason: '$fixed x=$x');
        }
      }
    }
  });

  test('모터 두 발 고정이면 펌프만 움직인다(모터를 빼는 대신 펌프를 내림)', () {
    final p = plan({AlignFootPos.motorFront, AlignFootPos.motorRear});
    expect(p.pumpMoves, isTrue);
    // 모터 축이 펌프보다 높다 → 펌프를 올려야 한다(넣기)
    expect(p.feet[AlignFootPos.pumpInner]!.shim, greaterThan(0));
  });

  test('모터에서 뺄 심이 모자라면 알리고, 모자라지 않게 고정 발을 고른다', () {
    final now = {for (final f in AlignFoot.values) f: f.name.startsWith('front') ? 0.10 : 0.10};
    final short = alignShortShim(plan(kAlignFixedDefault), now);
    expect(short.keys, containsAll([AlignFootPos.motorFront, AlignFootPos.motorRear]));
    expect(short[AlignFootPos.motorRear], closeTo(0.21 - 0.10, 0.01));
    final auto = alignAutoFixed(r: r, now: now, xFront: xFront, xRear: xRear, pumpInner: 200, pumpOuter: 700)!;
    final p = plan(auto);
    expect(alignShortShim(p, now), isEmpty);
    expect(p.feet.entries.where((e) => e.key.isPump).every((e) => e.value.shim >= -0.005), isTrue);
  });

  test('잘못된 고르기', () {
    expect(() => plan({AlignFootPos.pumpInner}), throwsA(isA<AlignInputError>()));
    expect(
      () => alignPlan(r: r, fixed: {AlignFootPos.pumpInner, AlignFootPos.motorRear}, xFront: xFront, xRear: xRear),
      throwsA(isA<AlignInputError>()),
    );
  });

  group('화면', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      recordRemote = () => null;
    });

    testWidgets('3점 측정: 6시를 비워도 3시 + 9시로 채워 같은 결과', (tester) async {
      await _open(tester);
      await _fill(tester, skip6: true);
      expect(_text(tester, 'align_measure_status'), contains('3점 측정'));
      final check = tester.widget<Text>(find.descendant(of: find.byKey(const Key('align_check_a')), matching: find.byType(Text)));
      expect(check.data, contains('6시 = -0.20(셈)'));
      await _step(tester, 2);
      expect(_text(tester, 'align_shim_front'), '심 빼기 0.14 mm');
      expect(_text(tester, 'align_shim_rear'), '심 빼기 0.21 mm');
    });

    testWidgets('고정 발을 바꾸면 펌프 발 값이 나오고, 거리 없으면 알림', (tester) async {
      await _open(tester);
      await _fill(tester);
      await _step(tester, 2);
      expect(find.byKey(const Key('align_shim_pumpInner')), findsNothing);
      // 모터 앞발을 고르면 먼저 고른 펌프 바깥발이 빠진다 → 펌프 안쪽발 + 모터 앞발 고정
      await tester.tap(find.byKey(const Key('align_fix_motorFront')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('align_plan_error')), findsOneWidget);
      await _type(tester, 'pumpIn', '200');
      await _type(tester, 'pumpOut', '700');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('align_plan_error')), findsNothing);
      expect(_text(tester, 'align_shim_front'), '심 그대로');
      expect(_text(tester, 'align_shim_pumpInner'), '심 그대로');
      expect(_text(tester, 'align_shim_pumpOuter'), isNot('심 그대로'));
      await tester.tap(find.byKey(const Key('align_fix_reset')));
      await tester.pumpAndSettle();
      expect(_text(tester, 'align_shim_front'), '심 빼기 0.14 mm');
    });

    testWidgets('심 기록의 지금 심보다 더 빼야 하면 알리고, 자동으로 고정 발을 고른다', (tester) async {
      await _open(tester);
      await _fill(tester);
      await _step(tester, 3);
      for (final f in AlignFoot.values) {
        await _type(tester, 'start_${f.name}', '0.10');
      }
      await _step(tester, 2);
      expect(find.byKey(const Key('align_short_shim')), findsOneWidget);
      await _type(tester, 'pumpIn', '200');
      await _type(tester, 'pumpOut', '700');
      await tester.tap(find.byKey(const Key('align_fix_auto')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('align_short_shim')), findsNothing);
      expect(find.byKey(const Key('align_shim_pumpInner')), findsOneWidget);
      // 알림 줄이 저장 단추를 덮고 있어 사라질 때까지 기다린다
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('align_save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('align_save_ok')));
      await tester.pumpAndSettle();
      final saved = (await AlignStore.load()).single;
      expect(buildAlignText(saved), contains('고정 발: '));
      expect(buildAlignText(saved), contains('펌프도 움직임: '));
    });
  });

}

// ── 화면 ──
final _now = DateTime(2026, 10, 15, 10);

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(700, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: AlignmentPage(share: (_) async {}, now: () => _now)));
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

String _text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

Future<void> _fill(WidgetTester tester, {bool skip6 = false}) async {
  for (final (k, v) in [('between', '200'), ('coupB', '100'), ('front', '150'), ('rear', '450')]) {
    await _type(tester, k, v);
  }
  await _step(tester, 1);
  for (final (k, v) in [
    ('a90', '-0.10'), if (!skip6) ('a180', '-0.20'), ('a270', '-0.10'),
    ('b90', '0.05'), if (!skip6) ('b180', '0.10'), ('b270', '0.05'),
  ]) {
    await _type(tester, k, v);
  }
}

