// 풀이 카드: 결과 줄을 식·대입·결과로 나누는 규칙과 분수 그리기.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/common/formula_card.dart';

void main() {
  group('splitFormulaLines', () {
    test('식 = 대입 = 결과 세 조각', () {
      final r = splitFormulaLines([
        '정격전류 I = P ÷ (√3 × V) = 11 × 1000 ÷ (√3 × 380) = 16.7 A',
      ]);
      expect(r.rest, isEmpty);
      expect(r.rows, hasLength(1));
      expect(r.rows.first.formula, '정격전류 I = P ÷ (√3 × V)');
      expect(r.rows.first.sub, '11 × 1000 ÷ (√3 × 380)');
      expect(r.rows.first.result, '16.7 A');
    });

    test('"식:" 줄은 쉼표(괄호 밖)마다 식 한 줄씩', () {
      final r = splitFormulaLines([
        '식: V = I × R, P = V × I = I² × R = V² ÷ R',
      ]);
      expect(r.rows.map((e) => e.formula), [
        'V = I × R',
        'P = V × I = I² × R = V² ÷ R',
      ]);
      expect(r.rows.every((e) => e.result == null), isTrue);
    });

    test('문장·연산 없는 값 줄은 결과 상자에 그대로 남는다', () {
      final r = splitFormulaLines([
        'V = 380 V, I = 20 A',
        '한도 = 5 % (편도 100 m 이하). 2.3 % ≤ 5 %이므로 한도 이내입니다.',
        '한도 5% 이내입니다.',
      ]);
      expect(r.rows, isEmpty);
      expect(r.rest, hasLength(3));
    });

    test('한 줄에 식이 둘이면(쉼표) 행도 둘', () {
      final r = splitFormulaLines([
        'S = √3 × 380 × 50 ÷ 1000 = 32.9 kVA, P = S × 역률 = 32.9 × 0.85 = 28 kW',
      ]);
      expect(r.rows, hasLength(2));
      expect(r.rows[1].result, '28 kW');
    });

    test('문장이 섞인 줄: 식 문장은 식 행, 나머지는 설명 행, 끝 마침표는 뗀다', () {
      final r = splitFormulaLines([
        '② 변압기: ZT = %Z ÷ 100 × U² ÷ S = 5 ÷ 100 × 380² ÷ 500000 = 14.44 mΩ. 변압기는 KT를 곱해 씁니다.',
      ]);
      expect(r.rest, isEmpty);
      expect(r.rows, hasLength(2));
      expect(r.rows[0].label, '② 변압기');
      expect(r.rows[0].result, '14.44 mΩ');
      expect(r.rows[1].text, '변압기는 KT를 곱해 씁니다');
    });

    test('식이 하나도 없는 문장 줄은 그대로 둔다', () {
      final r = splitFormulaLines(['c = 1.05, KT = 0.968. 차단기 선정용입니다.']);
      expect(r.rows, isEmpty);
      expect(r.rest, hasLength(1));
    });

    test('결과 끝 서술어(입니다)는 뗀다', () {
      final r = splitFormulaLines(['선도체 35 mm² 초과는 S ÷ 2 = 50 ÷ 2 = 25 mm²입니다']);
      expect(r.rows.single.result, '25 mm²');
    });

    test('앞이 기호 하나뿐인 3조각은 "R = 0 + 0 + 0"이 식', () {
      final r = splitFormulaLines(['R = 0 + 0 + 0 = 0 mΩ']);
      expect(r.rows.single.formula, 'R = 0 + 0 + 0');
      expect(r.rows.single.result, '0 mΩ');
    });

    test('괄호 안 쉼표는 자르지 않는다', () {
      final r = splitFormulaLines(['식: ΔU = 2 × I × L × R (직류, 리액턴스 없음)']);
      expect(r.rows, hasLength(1));
    });
  });

  testWidgets('나눗셈이 하나면 분수(분자·분모가 따로 그려짐), 둘이면 한 줄', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MathText('I = P × 1000 ÷ (√3 × V)', style: TextStyle(fontSize: 16)),
              MathText('A ÷ B ÷ C', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .toList();
    // 분수: "I = ", 분자, 분모 / 한 줄: 통째
    expect(texts, ['I = ', 'P × 1000', '√3 × V', 'A ÷ B ÷ C']);
  });

  testWidgets('한글이 낀 식은 분수로 그리지 않는다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MathText('선도체 35 mm² 초과는 S ÷ 2', style: TextStyle(fontSize: 16)),
        ),
      ),
    );
    expect(
      tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList(),
      ['선도체 35 mm² 초과는 S ÷ 2'],
    );
  });

  test('기호 뜻 목록은 모두 내용이 있다', () {
    expect(kSymbolLegend, isNotEmpty);
    for (final e in kSymbolLegend.entries) {
      expect(e.value, isNotEmpty, reason: e.key);
      expect(e.value.every((s) => s.trim().isNotEmpty), isTrue, reason: e.key);
    }
  });

  testWidgets('긴 풀이(6단계 이상)는 앞 두 단계만 보이고 "나머지 보기"로 펼친다, 짧으면 그대로', (tester) async {
    SharedPreferences.setMockInitialValues({});
    ElecFormulaCard.openAll.value = false;
    Widget card(int n) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ElecFormulaCard(
            rows: [
              for (var i = 1; i <= n; i++)
                FormulaRow(
                  formula: 'A$i = B$i × C$i',
                  sub: '$i × 2',
                  result: '${i * 2} W',
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(card(5));
    expect(find.text('= 10 W'), findsOneWidget);
    expect(find.byKey(const Key('formula_card_more')), findsNothing);

    await tester.pumpWidget(card(7));
    await tester.pump();
    expect(find.text('= 2 W'), findsOneWidget);
    expect(find.text('= 4 W'), findsOneWidget);
    expect(find.text('= 6 W'), findsNothing);
    expect(find.text('나머지 5단계 보기'), findsOneWidget);
    await tester.tap(find.byKey(const Key('formula_card_more')));
    await tester.pump();
    expect(find.text('= 14 W'), findsOneWidget);
    expect(find.byKey(const Key('formula_card_less')), findsOneWidget);
    // 펼친 상태는 폰에 적혀 다음 카드도 펼쳐 둔다.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('formula_card_open_v1'), isTrue);
    await tester.ensureVisible(find.byKey(const Key('formula_card_less')));
    await tester.tap(find.byKey(const Key('formula_card_less')));
    await tester.pump();
    expect(find.text('= 14 W'), findsNothing);
    ElecFormulaCard.openAll.value = false;
  });

  testWidgets('카드는 결과 앞에 "="를 붙이고 기호 뜻을 맨 아래에 둔다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ElecFormulaCard(
            rows: [FormulaRow(formula: 'P = V × I', sub: '100 × 2', result: '200 W')],
            symbols: ['P 전력(W)'],
          ),
        ),
      ),
    );
    expect(find.text('= 200 W'), findsOneWidget);
    expect(find.text('P 전력(W)'), findsOneWidget);
  });
}
