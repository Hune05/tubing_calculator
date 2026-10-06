import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/common/formula_card.dart';

/// 풀이 카드는 식·대입·결과를 따로 보여 주고 나눗셈은 분수로 그린다(위젯이 여러 개로 나뉨).
/// 테스트는 글자만 이어 붙여 같은 내용인지 본다: 공백·줄바꿈·괄호·"="·"÷"·쉼표·"식:"과
/// 문장 끝 마침표(소수점은 둠)는 버리고 비교한다.
String flat(String s) => s
    .replaceAll('식:', '')
    .replaceAll(RegExp(r'\.(?!\d)'), '')
    .replaceAll(RegExp(r'[\s()=÷,:]'), '');

/// 화면에 만들어진 모든 글자를 [flat]으로 이어 붙인 것.
String allFlat(WidgetTester tester) => flat(
  tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').join(),
);

/// 긴 풀이(4단계 이상)는 처음엔 접혀 있다. 단계별 글을 보는 테스트는 먼저 펼쳐 둔다.
void expandFormulaCards() => ElecFormulaCard.openAll.value = true;
