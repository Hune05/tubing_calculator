// 접지바 가공 화면(10-03, 10-10 현장용으로 정리): 기본값, 막대 길이로 바꾸기, 겹침 알림, 카톡 글,
// 입력값 남기기, 모자(윗면·다리·발), "자세히" 안 설정, 내 펀치 금형 칩.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_ground_page.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_punch_dies.dart';
import 'formula_flat.dart';

Future<void> _open(
  WidgetTester tester, {
  Future<void> Function(String)? share,
  double height = 30000,
}) async {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: share == null ? const GroundBarPage() : GroundBarPage(share: share),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(expandFormulaCards);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('기본값(일자, 양 끝 취부 구멍 1개, 접지 구멍 φ11 10개, 피치 25): 길이 375', (
    tester,
  ) async {
    await _open(tester);
    // 양 끝 (취부 25 + 50) × 2 + 9 × 25 = 375
    expect(find.text('375 mm'), findsOneWidget);
    expect(find.text('첫 구멍 75 → 피치 25 × 9칸 → 마지막 구멍 300'), findsOneWidget);
    expect(find.text('1~5번'), findsOneWidget);
    expect(find.text('6~10번'), findsOneWidget);
    expect(find.text('75   100   125   150   175'), findsOneWidget);
    expect(find.byKey(const Key('gb_view')), findsOneWidget);
    // 겉에 보이는 모양 칩은 일자·모자뿐(L자는 "자세히" 안)
    expect(find.text('일자'), findsOneWidget);
    expect(find.text('모자'), findsWidgets);
  });

  testWidgets('막대 길이로: 500mm에는 구멍 15개', (tester) async {
    await _open(tester);
    await _tap(tester, 'gb_by_len');
    // (500 − 75 × 2) ÷ 25 = 14칸 → 15개
    expect(find.textContaining('구멍 15개'), findsWidgets);
  });

  testWidgets('피치가 구멍 지름 이하이면 겹침 알림, 피치 칩은 칸을 채운다', (tester) async {
    await _open(tester);
    await _type(tester, 'gb_hole', '14');
    await _type(tester, 'gb_pitch', '8');
    // 피치 8은 최소 12로 올려 계산하므로 구멍 14와 겹친다
    expect(find.textContaining('서로 겹칩니다'), findsOneWidget);
    expect(find.textContaining('최소 간격 12mm보다 작아 12mm로 계산'), findsOneWidget);
    await _tap(tester, 'gb_pp_5000');
    expect(find.textContaining('서로 겹칩니다'), findsNothing);
    String text(String k) =>
        tester.widget<TextField>(find.byKey(Key(k))).controller!.text;
    expect(text('gb_pitch'), '50');
  });

  testWidgets('카톡 글과 입력값 남기기', (tester) async {
    String? sent;
    await _open(tester, share: (t) async => sent = t);
    await _type(tester, 'gb_n', '4');
    await _tap(tester, 'gb_share');
    expect(sent, startsWith('[접지바] 구리 6×50mm · 구멍 φ11 4개 피치 25'));
    expect(sent, contains('절단 길이: 225mm'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await _open(tester);
    expect(
      tester.widget<TextField>(find.byKey(const Key('gb_n'))).controller!.text,
      '4',
    );
  });

  testWidgets('끝 L자(자세히): 왼쪽 탭을 켜면 꺾기 선과 옆모습, 카톡 글에 포함', (tester) async {
    String? sent;
    await _open(tester, share: (t) async => sent = t);
    await _tap(tester, 'gb_tab_1');
    await _type(tester, 'gb_n', '4');
    await _type(tester, 'gb_tabl', '40');
    await _type(tester, 'gb_t', '6');
    // 곧은 28 + 호 13.2 + 구멍 줄 125
    expect(find.text('166.2 mm'), findsOneWidget);
    expect(find.byKey(const Key('gb_shape_view')), findsOneWidget);
    expect(find.textContaining('왼쪽 탭 · 시작선 28 mm'), findsOneWidget);
    expect(find.textContaining('첫 구멍 66.2'), findsOneWidget);
    // 겉 모양 칩에도 지금 고른 L자가 켜져 보인다
    expect(find.byKey(const Key('gb_tab_lnow')), findsOneWidget);
    await _tap(tester, 'gb_share');
    expect(sent, contains('왼쪽 탭 꺾기 시작선 28 · 끝선 41.2mm'));
    expect(sent, contains('1~4번 66.2 · 91.2 · 116.2 · 141.2'));
  });

  testWidgets('탭이 너무 짧으면 알림', (tester) async {
    await _open(tester);
    await _tap(tester, 'gb_tab_2');
    await _type(tester, 'gb_tabr', '5');
    expect(find.textContaining('꺾기에 너무 짧습니다'), findsOneWidget);
  });

  testWidgets('모자: 발·높이 입력, 꺾기 4곳(윗면·다리·발), 발 구멍 위치, 옆모습', (tester) async {
    String? sent;
    await _open(tester, share: (t) async => sent = t);
    await _type(tester, 'gb_n', '4');
    await _tap(tester, 'gb_tab_4');
    await _type(tester, 'gb_t', '6');
    await _type(tester, 'gb_hatf', '50');
    expect(find.byKey(const Key('gb_shape_view')), findsOneWidget);
    expect(find.textContaining('왼쪽 발 → 다리'), findsWidgets);
    expect(find.textContaining('왼쪽 다리 → 윗면'), findsWidgets);
    expect(find.textContaining('오른쪽 다리 → 발'), findsWidgets);
    expect(find.textContaining('챙'), findsNothing);
    expect(find.textContaining('몸체'), findsNothing);
    // 모자를 고르면 발 구멍 1개가 켜진다(바로 취부)
    expect(find.byKey(const Key('gb_tab_holes')), findsOneWidget);
    expect(find.text('19'), findsOneWidget); // 왼쪽 발 구멍: 평평한 38 가운데
    await _tap(tester, 'gb_share');
    expect(sent, contains('모자 높이 40 · 발 50'));
    expect(sent, contains('발 구멍 φ11 (왼쪽 끝에서 중심): 왼쪽 1 19 · 오른쪽 1'));
  });

  testWidgets('모자 기본값(발 60)이면 발 구멍이 꺾기 시작선 거리(2T + R)를 넘는다', (tester) async {
    await _open(tester);
    await _tap(tester, 'gb_tab_4');
    // 6t, 반경 6: 필요 18. 발 평평한 48 가운데 φ11 → 24 − 5.5 = 18.5
    expect(find.textContaining('발 구멍 18.5mm (필요 18mm 이상 ✓)'), findsOneWidget);
    expect(find.textContaining('보다 가깝습니다'), findsNothing);
    // 양쪽 발 구멍이면 판넬 구멍 가로 간격이 결과에 바로 나온다
    expect(find.textContaining('판넬 구멍 가로 간격'), findsOneWidget);
  });

  testWidgets('두 줄 대칭·비대칭(자세히): 줄 간격, A·B줄 위치, 엇갈림 칸, 자세히 요약', (tester) async {
    String? sent;
    await _open(tester, share: (t) async => sent = t);
    expect(find.textContaining('켜 둔 것'), findsNothing);
    await _tap(tester, 'gb_rm_1');
    expect(find.byKey(const Key('gb_gap')), findsOneWidget);
    expect(find.byKey(const Key('gb_shift')), findsNothing);
    // 폭 50, 간격 20 → A줄 15 · B줄 35, 길이 변화 없음 375
    expect(find.text('375 mm'), findsOneWidget);
    expect(find.textContaining('두 줄 대칭'), findsWidgets);
    expect(find.text('A1~5'), findsOneWidget);
    expect(find.text('B1~5'), findsOneWidget);
    // 접어 둬도 켜 둔 것은 "자세히" 제목 아래에 보인다
    expect(find.text('켜 둔 것: 두 줄 대칭'), findsOneWidget);
    await _tap(tester, 'gb_rm_2');
    expect(find.byKey(const Key('gb_shift')), findsOneWidget);
    expect(find.text('387.5 mm'), findsOneWidget); // 375 + 12.5
    await _tap(tester, 'gb_share');
    expect(sent, contains('구멍 φ11 10개 × 2줄'));
    expect(sent, contains('B줄은 길이 방향으로 12.5mm 옮김'));
  });

  testWidgets('구멍 하나만 크기 바꾸기: 적용·기본으로·전부 기본으로', (tester) async {
    String? sent;
    await _open(tester, share: (t) async => sent = t);
    expect(find.byKey(const Key('gb_ov_list')), findsNothing);
    await _type(tester, 'gb_ovdia', '18');
    await _tap(tester, 'gb_ov_apply'); // 처음 구멍(1번)이 선택돼 있다
    expect(find.byKey(const Key('gb_ov_list')), findsOneWidget);
    expect(find.textContaining('바꾼 구멍 1개: 1번 φ18'), findsOneWidget);
    expect(find.text('켜 둔 것: 크기 바꾼 구멍 1개'), findsOneWidget);
    await _tap(tester, 'gb_share');
    expect(sent, contains('크기 바꾼 구멍: 1번 φ18'));
    await _tap(tester, 'gb_ov_reset');
    expect(find.byKey(const Key('gb_ov_list')), findsNothing);
    // 너무 큰 지름은 겹침 알림
    await _type(tester, 'gb_ovdia', '45');
    await _tap(tester, 'gb_ov_apply');
    expect(find.textContaining('서로 겹칩니다'), findsWidgets);
    await _tap(tester, 'gb_ov_clear');
    expect(find.textContaining('서로 겹칩니다'), findsNothing);
  });

  testWidgets('모자 오른쪽 발을 따로(자세히): 비우면 같고 넣으면 그 값', (tester) async {
    await _open(tester);
    await _tap(tester, 'gb_tab_4');
    expect(find.textContaining('mm · 구멍'), findsWidgets);
    expect(find.byKey(const Key('gb_hatfr')), findsOneWidget);
    expect(find.textContaining('발 60 / 60'), findsWidgets);
    await _type(tester, 'gb_hatfr', '80');
    expect(find.textContaining('발 60 / 80'), findsWidgets);
    expect(find.textContaining('켜 둔 것: 오른쪽 발 따로'), findsOneWidget);
  });

  testWidgets('발 구멍 줄은 접지 구멍 줄 수와 따로: 접지 두 줄이어도 발은 1개씩', (tester) async {
    await _open(tester);
    await _tap(tester, 'gb_tab_4');
    await _tap(tester, 'gb_rm_1'); // 접지 두 줄 대칭
    expect(find.textContaining('왼쪽 발 1개 + 오른쪽 발 1개(합계 2개)'), findsOneWidget);
    expect(find.byKey(const Key('gb_tabgap')), findsNothing); // 발은 한 줄
    await _tap(tester, 'gb_trm_1');
    expect(find.textContaining('(합계 4개)'), findsOneWidget);
    expect(find.byKey(const Key('gb_tabgap')), findsOneWidget);
    await _tap(tester, 'gb_tsd_1'); // 왼쪽만
    expect(find.textContaining('왼쪽 발 2개(합계 2개)'), findsOneWidget);
  });

  testWidgets('뚫을 쪽을 "왼쪽만"으로 둔 채 오른쪽 L로 바꿔도 탭 구멍이 사라지지 않는다', (tester) async {
    // 10-10 고침: 뚫을 쪽 칩은 모자·양쪽 L에서만 보이는데, 숨은 "왼쪽만" 값이 오른쪽 L에 들어가
    // 탭 구멍이 말없이 0개가 됐다.
    await _open(tester);
    await _tap(tester, 'gb_tab_3');
    await _tap(tester, 'gb_mc_1');
    await _tap(tester, 'gb_tsd_1'); // 왼쪽만
    expect(find.textContaining('왼쪽 탭 1개(합계 1개)'), findsOneWidget);
    await _tap(tester, 'gb_tab_2'); // 오른쪽 L
    expect(find.byKey(const Key('gb_tsd_1')), findsNothing);
    expect(find.textContaining('오른쪽 탭 1개(합계 1개)'), findsOneWidget);
  });

  testWidgets('접지 러그(외부 큰 러그): 접지 구멍 왼쪽으로 몰고 러그 구멍은 같은 줄 가운데', (tester) async {
    String? sent;
    await _open(tester, share: (t) async => sent = t);
    expect(find.byKey(const Key('gb_lug_result')), findsNothing);
    await _tap(tester, 'gb_lug_2');
    // 처음 켜면 큰 러그 기본값: 구멍 13.5(M12), 구멍 간격 44.45
    String text(String k) =>
        tester.widget<TextField>(find.byKey(Key(k))).controller!.text;
    expect(text('gb_lugdia'), '13.5');
    expect(text('gb_lugsp'), '44.45');
    // 기본은 "왼쪽으로 몰기": 겹치지 않고 길이 = 마지막 접지 구멍 + 피치 + 러그 묶음 + 끝 여유
    expect(find.textContaining('접지 구멍과 겹칩니다'), findsNothing);
    expect(find.text('러그 구멍 2개 · 볼트 세트 2'), findsOneWidget);
    expect(find.textContaining('접지 구멍은 왼쪽 끝으로 몰았고'), findsOneWidget);
    expect(find.textContaining('볼트 M12 2개'), findsWidgets);
    // 75 + 9 × 25 + 25 + 44.45 + 75 = 444.45
    expect(find.textContaining(RegExp(r'^444.[45] mm$')), findsOneWidget);
    expect(find.byKey(const Key('gb_lug_notes')), findsOneWidget);
    // 가운데 균등으로 바꾸면 한 줄 접지 구멍과 겹칠 수 있다
    await _tap(tester, 'gb_pack_off');
    expect(find.textContaining('접지 구멍과 겹칩니다'), findsOneWidget);
    await _tap(tester, 'gb_pack_on');
    await _tap(tester, 'gb_share');
    expect(sent, contains('접지 러그 2구멍 1개(접지 구멍과 따로'));
    expect(sent, contains('볼트 세트 2개'));
  });

  testWidgets('러그 구멍 하나만 크기 바꾸기(구멍 고르기에 러그 구멍도 들어간다)', (tester) async {
    await _open(tester);
    await _tap(tester, 'gb_lug_1');
    // 1구멍 러그는 구멍 1개만(2개·4개가 아니다)
    expect(find.text('러그 구멍 1개 · 볼트 세트 1'), findsOneWidget);
    expect(find.byKey(const Key('gb_lugn')), findsNothing);
    await _tap(tester, 'gb_ov_sel');
    expect(find.textContaining('러그 1 · φ13.5'), findsWidgets);
  });

  testWidgets('판넬 취부: 모자 발 구멍으로 판넬 구멍 자리와 볼트 세트, 판넬 두께', (tester) async {
    String? sent;
    await _open(tester, share: (t) async => sent = t);
    await _tap(tester, 'gb_mc_0');
    expect(find.byKey(const Key('gb_mount_result')), findsNothing);
    await _type(tester, 'gb_n', '3');
    await _tap(tester, 'gb_tab_4');
    await _type(tester, 'gb_hatf', '50');
    expect(find.byKey(const Key('gb_mount_result')), findsOneWidget);
    expect(find.text('취부 구멍 2개 · 볼트 세트 2'), findsOneWidget);
    // 윗면 바깥 폭 124(구멍 줄 100 + 2 × 12) + 양쪽 발 구멍까지 31씩
    expect(find.textContaining('오른쪽 구멍 가로 간격 186mm'), findsOneWidget);
    expect(find.textContaining('판넬 구멍 가로 간격 186mm'), findsOneWidget);
    expect(find.textContaining('그립) 9mm'), findsOneWidget); // 부스바 6 + 판넬 3
    expect(find.textContaining('볼트 M10 2개'), findsOneWidget);
    expect(find.byKey(const Key('gb_mount_notes')), findsOneWidget);
    expect(find.textContaining('구멍 가장자리 ~ 꺾기 시작선 거리'), findsOneWidget);
    await _tap(tester, 'gb_share');
    expect(sent, contains('판넬 취부 구멍(왼쪽 구멍 0 기준): 왼쪽 1 가로 0'));
  });

  testWidgets('러그·판넬 칸 값이 저장 순서가 어긋나지 않고 다시 열면 그대로', (tester) async {
    await _open(tester);
    await _tap(tester, 'gb_tab_4');
    await _tap(tester, 'gb_lug_1');
    await _type(tester, 'gb_lugdia', '9');
    await _type(tester, 'gb_lugpad', '7');
    await _type(tester, 'gb_panelt', '4');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await _open(tester);
    String text(String k) =>
        tester.widget<TextField>(find.byKey(Key(k))).controller!.text;
    expect(text('gb_lugdia'), '9');
    expect(text('gb_lugpad'), '7');
    expect(text('gb_panelt'), '4');
  });

  testWidgets('구멍 지름 칩: 기본은 볼트 틈새 구멍, 내 금형을 저장하면 그 값이 칩이 된다', (tester) async {
    await _open(tester);
    expect(find.text('φ9 (M8)'), findsWidgets);
    expect(find.text('φ11 (M10)'), findsWidgets);
    expect(find.text('φ17.5 (M16)'), findsWidgets);
    await _tap(tester, 'gb_hd_1350');
    String text(String k) =>
        tester.widget<TextField>(find.byKey(Key(k))).controller!.text;
    expect(text('gb_hole'), '13.5');
    // 내 금형 넣기: 10, 12.5, 20
    await _tap(tester, 'gb_hd_edit');
    await tester.enterText(
      find.byKey(const Key('gb_dies_field')),
      '20, 10 12.5',
    );
    await _tap(tester, 'gb_dies_ok');
    expect(find.byKey(const Key('gb_hd_900')), findsNothing);
    expect(find.byKey(const Key('gb_hd_1000')), findsOneWidget);
    expect(find.byKey(const Key('gb_hd_1250')), findsOneWidget);
    expect(find.byKey(const Key('gb_hd_2000')), findsOneWidget);
    expect(find.text('내 금형 고치기'), findsWidgets);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(kPunchDiesKey), ['10', '12.5', '20']);
    // 다시 열어도 내 금형 칩
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await _open(tester);
    expect(find.byKey(const Key('gb_hd_1250')), findsOneWidget);
    // 비우고 저장하면 기본 칩으로
    await _tap(tester, 'gb_hd_edit');
    await tester.enterText(find.byKey(const Key('gb_dies_field')), '');
    await _tap(tester, 'gb_dies_ok');
    expect(find.byKey(const Key('gb_hd_900')), findsOneWidget);
    expect(find.byKey(const Key('gb_hd_1250')), findsNothing);
  });

  testWidgets('일자 취부 구멍(10-10): 양 끝에 따로, 판넬 간격, 거리 바꾸기·겹침·한쪽만·없음', (
    tester,
  ) async {
    String? sent;
    await _open(tester, share: (t) async => sent = t);
    // 기본: 끝 하나에 1개, 끝에서 25, 첫 접지 구멍까지 50
    expect(
      find.textContaining('취부 구멍 φ11: 왼쪽 끝 1개 + 오른쪽 끝 1개(합계 2개)'),
      findsOneWidget,
    );
    expect(find.text('25'), findsWidgets); // 취부 구멍 위치 표: 왼쪽 25
    expect(find.text('350'), findsOneWidget); // 오른쪽 375 − 25
    // 판넬 구멍 가로 간격 = 350 − 25
    expect(
      find.textContaining('판넬 구멍 가로 간격 325mm(양 끝 취부 구멍 중심 사이)'),
      findsOneWidget,
    );
    expect(find.text('취부 구멍 2개 · 볼트 세트 2'), findsOneWidget);
    expect(find.textContaining('그립) 9mm = 부스바 6 + 판넬 3'), findsOneWidget);
    await _tap(tester, 'gb_share');
    expect(sent, contains('취부 구멍 φ11 (왼쪽 끝에서 중심): 왼쪽 1 25 · 오른쪽 1 350'));
    // 일자는 꺾기가 없어 "꺾기" 칸이 없다
    expect(find.byKey(const Key('gb_fold_bends')), findsNothing);
    // 첫 접지 구멍까지 30 → 길이 335, 너무 가까우면 겹침
    await _type(tester, 'gb_mgap', '30');
    expect(find.text('335 mm'), findsOneWidget);
    await _type(tester, 'gb_mgap', '8');
    expect(find.textContaining('취부 구멍이 접지 구멍과 겹칩니다'), findsOneWidget);
    await _type(tester, 'gb_mgap', '50');
    // 왼쪽만: 오른쪽은 끝 여유 25 → 75 + 225 + 25 = 325
    await _tap(tester, 'gb_tsd_1');
    expect(find.text('325 mm'), findsOneWidget);
    expect(find.text('켜 둔 것: 취부 구멍 왼쪽만'), findsOneWidget);
    await _tap(tester, 'gb_tsd_3');
    // 없음: 예전처럼 끝 여유만 → 275
    await _tap(tester, 'gb_mc_0');
    expect(find.text('275 mm'), findsOneWidget);
    expect(find.byKey(const Key('gb_mend')), findsNothing);
    // 모자 → 일자로 돌아오면 다시 1개
    await _tap(tester, 'gb_tab_4');
    await _tap(tester, 'gb_tab_0');
    expect(find.text('375 mm'), findsOneWidget);
  });

  test('금형 글 읽기·칩 이름', () {
    expect(parsePunchDies('9, 11 13.5/17.5 · 0 abc 11'), [9, 11, 13.5, 17.5]);
    expect(parsePunchDies(''), isEmpty);
    expect(punchDieLabel(11), 'φ11 (M10)');
    expect(punchDieLabel(13.5), 'φ13.5 (M12)');
    expect(punchDieLabel(12.5), 'φ12.5');
  });
}
