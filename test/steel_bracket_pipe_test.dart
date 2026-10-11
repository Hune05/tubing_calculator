// 형강 브라켓 가로대 위 관 자리(10-12, 사용자 "U볼트 홀 간격 … 단순 일자로 쭉 뚫어서는 안 되고"):
// 관마다 U볼트 한 쌍(관 중심 ± 다리 간격/2), 다리 간격 = 내경 + 나사, 관 사이 자동(몸 + 25, 너트·와셔 자리),
// 이웃 관 간섭 알림, 그림(관 원·U볼트·위 치수), 하중은 관 중심, 저장 지도 판 4.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_calc.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_form.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_load.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_page.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_piece_drawing.dart';

BracketPiece _p(BracketPlan p, String name) =>
    p.pieces.firstWhere((x) => x.name == name);

List<BracketPipe> _pipes(
  List<String> specs, {
  double first = 100,
  double pitch = 0,
}) => bracketPipeLayout(
  [for (final s in specs) BracketPipeSpec.parse(s)],
  first: first,
  pitch: pitch,
);

void main() {
  group('U볼트 값', () {
    test('다리 간격 = 내경 + 나사, 구멍은 나사에 맞춤, 고친 값이 먼저', () {
      final a = BracketPipeSpec.parse('25A||');
      expect(a.threadUsed, 10);
      expect(a.spacingUsed, 46); // 36 + 10
      expect(bracketUHole(a.threadUsed), 11);
      final b = BracketPipeSpec.parse('50A|16|');
      expect(b.spacingUsed, 79); // 63 + 16
      final c = BracketPipeSpec.parse('D48.6|12|62');
      expect(c.spacingUsed, 62);
      expect(c.row!.approx, isTrue);
      expect(BracketPipeSpec.parse('').size, '25A');
      expect(BracketPipeSpec.parse('50A|16|').text, '50A|16|');
    });

    test('관 사이 자동: 몸 + 25, 이웃 다리 사이에 너트·와셔가 안 들어가면 더 벌림(5 올림)', () {
      final p25 = BracketPipeSpec.parse('25A||');
      // 몸 34 + 25 = 59, 다리 23 + 23 + 와셔 25 = 71 → 75
      expect(bracketPipeAutoPitch(p25, p25), 75);
      final p15 = BracketPipeSpec.parse('15A||');
      expect(bracketPipeAutoPitch(p15, p15), 55); // 15 + 15 + 21 = 51
      expect(bracketPipeAutoPitchText([p25, p25, p25]), '자동 75');
      final ps = _pipes(['25A||', '50A||'], first: 80);
      // 몸 17 + 30.25 + 25 = 72.25, 다리 23 + 37.5 + (25 + 29)/2 = 87.5 → 90
      expect(ps.map((x) => x.at), [80, 170]);
    });
  });

  group('계산', () {
    test('ㄱ자: 관마다 구멍 한 쌍(관 중심 ± 23), 볼트 줄은 U볼트', () {
      final p = bracketPlan(
        BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          a: 400,
          b: 300,
          pipes: _pipes(['25A||', '25A||']),
        ),
      );
      final arm = _p(p, '가로대');
      expect(arm.holes.map((h) => h.fromEnd), [77, 123, 152, 198]);
      expect(arm.holes.every((h) => h.dia == 11 && h.pipe == '25A'), isTrue);
      expect(arm.holes.map((h) => h.pipeAt).toSet(), {100, 175});
      expect(p.armHoles, {11.0: 4});
      expect(p.problems, isEmpty);
      // 그림: 관 원 둘, 위 치수는 관 꼭대기 위로
      expect(
        p.drawing.polys.where((x) => x.fill == BracketFill.pipe).length,
        2,
      );
      final top = p.drawing.dims.firstWhere((d) => d.text == '400');
      expect(top.base, lessThan(-34));
      // 부재도: 관 중심 가운데 선과 이름
      final d = bracketPieceDrawing(arm);
      expect(d.labels.where((l) => l.text == '25A').length, 2);
    });

    test('이웃 관이 겹치거나 U볼트 너트가 닿으면 알림, 관 외경보다 좁은 다리 간격도', () {
      BracketPlan plan(List<BracketPipe> ps) => bracketPlan(
        BracketInput(
          shape: BracketShape.l,
          spec: '앵글 50x50x5',
          a: 400,
          b: 300,
          pipes: ps,
        ),
      );
      expect(
        plan(_pipes(['25A||', '25A||'], pitch: 30)).problems.join(),
        contains('서로 겹칩니다'),
      );
      expect(
        plan(_pipes(['25A||', '25A||'], pitch: 60)).problems.join(),
        contains('너트·와셔가 닿습니다'),
      );
      expect(
        plan(_pipes(['50A||40'])).problems.join(),
        contains('관이 들어가지 않습니다'),
      );
    });

    test('천장 매달기: 관 하나 가운데면 "관마다 나눠" = 가운데 한 점', () {
      BracketPlan plan() => bracketPlan(
        BracketInput(
          shape: BracketShape.hanger,
          spec: '찬넬 100x50x5',
          a: 600,
          b: 500,
          pipes: _pipes(['50A||'], first: 300),
        ),
      );
      final byPipe = bracketLoad(plan(), kg: 100, mode: BracketLoadMode.holes);
      final byPoint = bracketLoad(plan(), kg: 100, mode: BracketLoadMode.point);
      expect(
        byPipe.checks.map((c) => c.ratio.toStringAsFixed(4)),
        byPoint.checks.map((c) => c.ratio.toStringAsFixed(4)),
      );
    });
  });

  group('입력 지도', () {
    test('관 자리: 개수·관마다 글·첫 관·관 사이', () {
      final i = bracketInputFromMap({
        'upn': 2,
        'up0': '25A||',
        'up1': '50A|16|',
        'uf': '80',
        'ug': '120',
      });
      expect(i.pipes.map((x) => x.name), ['25A', '50A']);
      expect(i.pipes.map((x) => x.at), [80, 200]);
      expect(i.pipes.last.thread, 16);
      expect(i.armHoles.on, isFalse);
    });

    test('판 4 전 저장 값: 넣어 둔 일자 구멍은 "일자로 직접"으로 그대로', () {
      final old = bracketUpgradeMap(const {
        'v': 3,
        'an': 2,
        'ad': '13.5',
        'af': '50',
        'ap': '100',
      });
      expect(old['am'], 1);
      final i = bracketInputFromMap(old);
      expect(i.pipes, isEmpty);
      expect(i.armHoles.count, 2);
      expect(bracketUpgradeMap(const {'v': 3})['am'], 0);
    });
  });

  testWidgets('화면: 관 2개, 2번 관을 50A로, 일자로 바꾸면 예전 칸', (tester) async {
    SharedPreferences.setMockInitialValues({
      BracketPage.draftKey: jsonEncode({'sh': 0}),
    });
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: BracketPage(share: (_) async {}, openPlate: (_, _) {}),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> tap(String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    await tap('br_tab_holes');
    await tap('br_upn_2');
    expect(find.byKey(const Key('br_up_0')), findsOneWidget);
    expect(find.byKey(const Key('br_up_1')), findsOneWidget);
    await tap('br_up_1');
    await tap('br_ups_50A');
    await tap('br_up_ok');
    expect(tester.takeException(), isNull);
    expect(find.textContaining('2번 관 · 50A'), findsOneWidget);
    expect(find.textContaining('다리 간격 75'), findsOneWidget); // 63 + 12
    await tap('br_am_1');
    expect(find.byKey(const Key('br_an_0')), findsOneWidget);
    expect(find.byKey(const Key('br_up_0')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
