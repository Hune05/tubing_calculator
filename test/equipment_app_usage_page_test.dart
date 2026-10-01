// 장비 사용법·앱 사용법 화면: "현장 자료" 화면에서 분리한 두 화면이 각자 뜨고
// 넘기다 멈춰도 예외가 없다(2026-09-28, 헤더 점 3개 구획 나누기의 일부).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/equipment/equipment_manual.dart';
import 'package:tubing_calculator/src/presentation/reference/page/app_usage_page.dart';
import 'package:tubing_calculator/src/presentation/reference/page/equipment_usage_page.dart';
import 'package:tubing_calculator/src/presentation/reference/page/gd402_manual_page.dart';

Future<void> _scrollThrough(WidgetTester tester) async {
  final list = find.byType(ListView).last;
  for (var i = 0; i < 12; i++) {
    await tester.drag(list, const Offset(0, -1500));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: '스크롤 $i');
  }
}

Future<void> _openUsage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: EquipmentUsagePage()));
  await tester.pumpAndSettle();
}

/// 묶음 칩을 고르고 장비 줄을 편다.
Future<void> _openGuide(WidgetTester tester, String group, String id) async {
  await tester.tap(find.text(group).first);
  await tester.pumpAndSettle();
  final head = find.byKey(Key('guide_head_$id'));
  await tester.ensureVisible(head);
  await tester.pumpAndSettle();
  await tester.tap(head);
  await tester.pumpAndSettle();
}

Future<void> _pickPart(WidgetTester tester, String id, String part) async {
  final chip = find.descendant(of: find.byKey(Key('guide_$id')), matching: find.text(part));
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('장비 사용법 화면: 장비 줄이 접혀서 보이고, 모두 펴고 끝까지 넘겨도 예외가 없다', (tester) async {
    await _openUsage(tester);
    expect(find.text('장비 사용법'), findsWidgets);
    expect(find.text('튜브 수동 벤더'), findsOneWidget);
    // 접혀 있으면 안 내용은 없다
    expect(find.textContaining('롤러를 튜브에 밀착'), findsNothing);
    await _scrollThrough(tester);
  });

  testWidgets('장비 사용법: 묶음 칩으로 거르고, 줄을 펴서 칸을 바꾸면 그 내용이 보인다', (tester) async {
    await _openUsage(tester);
    await _openGuide(tester, '튜브', 'tube_hand');
    expect(find.text('유압식 벤더'), findsNothing); // 전선관은 걸러졌다
    expect(find.textContaining('롤러를 튜브에 밀착'), findsOneWidget); // 처음 칸 = 작업 순서
    await _pickPart(tester, 'tube_hand', '고장 조치');
    expect(find.text('튜브 찌그러짐·주름'), findsOneWidget);
    expect(find.textContaining('롤러를 튜브에 밀착'), findsNothing);
    await _pickPart(tester, 'tube_hand', '정리정돈');
    expect(find.textContaining('규격별 전용 케이스'), findsOneWidget);
    // 다시 누르면 접힌다
    await tester.tap(find.byKey(const Key('guide_head_tube_hand')));
    await tester.pumpAndSettle();
    expect(find.textContaining('규격별 전용 케이스'), findsNothing);
  });

  testWidgets('장비 사용법: 모든 장비 줄을 펴서 모든 칸을 눌러도 예외가 없다', (tester) async {
    await _openUsage(tester);
    final seen = <String>{};
    for (final g in ['튜브', '전선관', '절단·나사 가공', '계측', '실측', '공통']) {
      await tester.tap(find.text(g).first);
      await tester.pumpAndSettle();
      final heads = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('guide_head_'), skipOffstage: false);
      final ids = [for (final e in heads.evaluate()) ((e.widget.key as ValueKey<String>).value).substring('guide_head_'.length)];
      expect(ids, isNotEmpty, reason: g);
      seen.addAll(ids);
      for (final id in ids) {
        final head = find.byKey(Key('guide_head_$id'));
        await tester.ensureVisible(head);
        await tester.pumpAndSettle();
        await tester.tap(head);
        await tester.pumpAndSettle();
        final chips = find.descendant(of: find.byKey(Key('guide_$id')), matching: find.byType(ChoiceChip));
        final n = chips.evaluate().length;
        for (var i = 0; i < n; i++) {
          final c = chips.at(i);
          await tester.ensureVisible(c);
          await tester.pumpAndSettle();
          await tester.tap(c);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$id 칸 $i');
        }
        await tester.ensureVisible(head);
        await tester.pumpAndSettle();
        await tester.tap(head);
        await tester.pumpAndSettle();
      }
    }
    expect(seen.length, 17);
  });

  testWidgets('장비 사용법: GD402 줄의 "전체 매뉴얼 보기"를 누르면 매뉴얼 화면이 열린다', (tester) async {
    await _openUsage(tester);
    await _openGuide(tester, '계측', 'meter_gd402');
    expect(find.text('수소(H2) 100%'), findsOneWidget);
    final btn = find.byKey(const Key('gd402_manual'));
    await tester.ensureVisible(btn);
    await tester.pumpAndSettle();
    await tester.tap(btn);
    await tester.pumpAndSettle();
    expect(find.text('GD402 가스 밀도계 매뉴얼'), findsOneWidget);
    await tester.dragUntilVisible(
      find.textContaining('10. 수소순도계 보정 절차'),
      find.byType(ListView).last,
      const Offset(0, -400), maxIteration: 200,
    );
    expect(find.textContaining('10. 수소순도계 보정 절차'), findsOneWidget);
  });

  testWidgets('장비 사용법: REMS 아미고(설명서 기준)·타이거 SR에 제원·안전 수칙·점검·고장 조치·정리정돈 칸이 있고, 설명서 단추가 받는 곳을 알려 준다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _openUsage(tester);
    await _openGuide(tester, '절단·나사 가공', 'rems_amigo');
    expect(find.text('1200 W'), findsOneWidget); // 처음 칸 = 제원(아미고 1)
    expect(find.text('S3 20% (10분 중 2분 가동)'), findsOneWidget);
    for (final t in ['제원', '작업 순서', '안전 수칙', '점검·정비', '날 교체', '절삭유', '고장 조치', '정리정돈']) {
      expect(find.descendant(of: find.byKey(const Key('guide_rems_amigo')), matching: find.text(t)), findsOneWidget, reason: t);
    }
    final amigo = find.byKey(const Key('vendor_manual_REMS|Amigo'));
    await tester.ensureVisible(amigo);
    await tester.pumpAndSettle();
    await tester.tap(amigo);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manual_pick')), findsOneWidget);
    expect(find.byKey(const Key('manual_url')), findsNothing); // 받은 PDF를 고르는 방식(주소 없음)
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    final tiger = find.byKey(const Key('guide_head_rems_tiger'));
    await tester.ensureVisible(tiger);
    await tester.pumpAndSettle();
    await tester.tap(tiger);
    await tester.pumpAndSettle();
    expect(find.text('230 V 6.4 A / 110 V 12.8 A'), findsOneWidget);
    await _pickPart(tester, 'rems_tiger', '안전 수칙');
    expect(find.textContaining('격리·배수·퍼지'), findsOneWidget);
    final tigerManual = find.byKey(const Key('vendor_manual_REMS|Tiger SR'));
    await tester.ensureVisible(tigerManual);
    await tester.pumpAndSettle();
    await tester.tap(tigerManual);
    await tester.pumpAndSettle();
    expect(find.text(kOfficialManualUrls['REMS|Tiger SR']!), findsOneWidget);
  });

  test('설명서 열쇠: 같은 제조사·모델이면 같은 설명서', () {
    expect(manualKeyFor(maker: 'rems', model: 'Amigo 2', id: 'x'), 'REMS|Amigo 2');
    expect(manualKeyFor(maker: 'REMS', model: 'Tiger SR'), 'REMS|Tiger SR');
    expect(manualKeyFor(id: 'abc'), 'id:abc');
  });

  testWidgets('GD402 매뉴얼 화면: 챕터가 다 보이고 끝까지 넘겨도 예외가 없다', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: Gd402ManualPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('1. 사양'), findsOneWidget);
    final list = find.byType(ListView).last;
    // 10장(수소순도)은 처음부터 펼쳐져 있다 — 화면까지 내리면 탭 없이도 안 내용이 보인다.
    await tester.dragUntilVisible(
      find.textContaining('10. 수소순도계 보정 절차'),
      list,
      const Offset(0, -400), maxIteration: 200,
    );
    expect(find.textContaining('제로가스'), findsWidgets);
    await tester.dragUntilVisible(
      find.textContaining('11. 점검·유지보수'),
      list,
      const Offset(0, -400), maxIteration: 200,
    );
    expect(find.textContaining('11. 점검·유지보수'), findsOneWidget);
    await _scrollThrough(tester);
  });

  testWidgets('앱 사용법 화면: 계산기 사용 순서가 보이고 끝까지 넘겨도 예외가 없다', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AppUsagePage()));
    await tester.pumpAndSettle();
    expect(find.text('앱 사용법'), findsWidgets);
    expect(find.textContaining('벤딩 마킹 계산기 (튜브)'), findsOneWidget);
    await _scrollThrough(tester);
  });
}
