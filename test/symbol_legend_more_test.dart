// 풀이 카드 기호 설명(2026-10-07 추가분): 실제 풀이 줄에 나온 기호만 보이는지.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/common/formula_card.dart';
import 'package:tubing_calculator/src/presentation/electrical/panel_design_page.dart';

import 'formula_flat.dart';

List<String> _legend(String key, List<String> lines) =>
    legendFor(kSymbolLegend[key]!, splitFormulaLines(lines).rows);

void main() {
  setUpAll(expandFormulaCards);

  test('접지바: 2 × T + R로 쓰면 T·R 둘 다 보인다', () {
    final l = _legend('gb_result', [
      '구멍 가장자리 ~ 꺾기 시작선 거리: 탭 20 mm. 필요 거리 = 2 × T + R(구멍 지름 25.4 이상은 2.5 × T + R, 일반 판금 규칙).',
    ]).join(' ');
    expect(l, contains('T 부스바 두께(mm)'));
    expect(l, contains('R 꺾기 안쪽 반경(mm)'));
  });

  test('전압강하: 식에 나온 기호만 남는다(X·sinφ가 없으면 빠짐)', () {
    final l = _legend('ec_vd_result', [
      '① ΔU = √3 × I × L × (R × cosφ) = 1.732 × 20 × 0.05 × (4.61 × 0.85) = 6.8 V',
    ]).join(' ');
    expect(l, contains('ΔU 전압강하(V)'));
    expect(l, contains('R 도체 저항(Ω/km)'));
    expect(l, isNot(contains('X 리액턴스')));
    expect(l, isNot(contains('sinφ')));
  });

  testWidgets('조명 광속법 결과에 E·A·F·U·M·K 뜻이 붙는다', (tester) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: PanelDesignPage()));
    await tester.pumpAndSettle();
    Future<void> type(String key, String text) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.enterText(find.byKey(Key(key)), text);
      await tester.pumpAndSettle();
    }

    await type('pd_lux', '500');
    await type('pd_x', '10');
    await type('pd_y', '5');
    await type('pd_h', '2.5');
    await type('pd_lm', '3000');
    await type('pd_u', '0.6');
    await type('pd_m', '80');
    final all = allFlat(tester);
    expect(all, contains(flat('E 목표 평균 조도(lx)')));
    expect(all, contains(flat('F 등기구 1개 광속(lm)')));
    expect(all, contains(flat('K 실지수')));
  });
}
