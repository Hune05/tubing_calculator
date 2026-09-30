// 축 정렬 현장 지침: 항목 자료, 찾기·분류, 펼치기, 내 메모, 계산 화면에서 들어가기.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/record_sync.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_guide_data.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_guide_page.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_page.dart';

Future<void> _pump(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(700, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: w));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    recordRemote = () => null;
  });

  test('항목 자료: id가 겹치지 않고, 모든 분류에 항목이 있고, 빈 칸이 없다', () {
    final ids = kAlignTips.map((t) => t.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final c in AlignGuideCat.values) {
      expect(kAlignTips.any((t) => t.cat == c), isTrue, reason: c.label);
    }
    for (final t in kAlignTips) {
      expect(t.title.trim(), isNotEmpty);
      expect(t.symptom.trim(), isNotEmpty);
      expect(t.fixes, isNotEmpty, reason: t.id);
      expect(t.check.trim(), isNotEmpty);
    }
    // 배관·용접(가장 흔한 원인)은 따로 모아 두었다
    final pipe = kAlignTips.where((t) => t.cat == AlignGuideCat.pipe).map((t) => t.id);
    expect(pipe, containsAll(['pipe', 'weld', 'weldground', 'pipeorder']));
  });

  testWidgets('찾기와 분류로 항목을 좁히고, 눌러서 펼친다', (tester) async {
    await _pump(tester, const AlignmentGuidePage());
    expect(find.byKey(const Key('guide_tip_weld')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('guide_search')), '접지');
    await tester.pump();
    expect(find.byKey(const Key('guide_tip_weldground')), findsOneWidget);
    expect(find.byKey(const Key('guide_tip_sag')), findsNothing);
    await tester.enterText(find.byKey(const Key('guide_search')), '');
    await tester.pump();
    await tester.tap(find.byKey(const Key('guide_cat_measure')));
    await tester.pump();
    expect(find.byKey(const Key('guide_tip_sag')), findsOneWidget);
    expect(find.byKey(const Key('guide_tip_weld')), findsNothing);
    expect(find.text('대책'), findsNothing);
    await tester.tap(find.byKey(const Key('guide_tip_sag')));
    await tester.pump();
    expect(find.text('대책'), findsOneWidget);
    expect(find.textContaining('브래킷 처짐 보정'), findsOneWidget);
  });

  testWidgets('내 메모를 남기면 보이고, 다시 열어도 남는다', (tester) async {
    await _pump(tester, const AlignmentGuidePage(openId: 'weld'));
    expect(find.text('대책'), findsOneWidget); // 처음부터 펼쳐져 있다
    await tester.tap(find.byKey(const Key('guide_note_btn_weld')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('guide_note_field')), '3호기는 토출 쪽 맞춤 용접을 두 번째 엘보에서');
    await tester.tap(find.byKey(const Key('guide_note_ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guide_note_weld')), findsOneWidget);
    expect((await AlignGuideNotes.load())['weld'], contains('두 번째 엘보'));

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const AlignmentGuidePage());
    expect(find.textContaining('내 메모 있음'), findsOneWidget);
    // 메모 글로도 찾아진다
    await tester.enterText(find.byKey(const Key('guide_search')), '엘보');
    await tester.pump();
    expect(find.byKey(const Key('guide_tip_weld')), findsOneWidget);
  });

  testWidgets('보내기 글에 대책과 내 메모가 들어간다', (tester) async {
    String? sent;
    SharedPreferences.setMockInitialValues({AlignGuideNotes.key: '{"weldground":"집게는 배관 쪽 30cm 안"}'});
    await _pump(tester, AlignmentGuidePage(openId: 'weldground', share: (t) async => sent = t));
    await tester.tap(find.byKey(const Key('guide_share_weldground')));
    await tester.pump();
    expect(sent, contains('[정렬 지침] 용접 접지 집게 자리'));
    expect(sent, contains('1. 접지 집게는'));
    expect(sent, contains('현장 메모: 집게는 배관 쪽 30cm 안'));
  });

  testWidgets('계산 화면에서 지침으로 들어간다', (tester) async {
    await _pump(tester, const AlignmentPage());
    await tester.tap(find.byKey(const Key('align_guide_entry')));
    await tester.pumpAndSettle();
    expect(find.text('축 정렬 현장 지침'), findsOneWidget);
  });
}
