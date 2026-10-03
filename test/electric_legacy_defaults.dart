// 전기 계산기 기본값이 "일반 부하·전동기 여유 꺼짐"으로 바뀐 뒤에도, 전동기 기본을 전제로 쓴 옛 테스트가 그대로 돌도록
// 저장 칸(draft)에 옛 기본값(전동기·효율 90·전동기 여유 켜짐)을 넣어 여는 도우미.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';

void legacyElectricDefaults() => SharedPreferences.setMockInitialValues({
  ElectricCalculatorPage.draftKey: jsonEncode({
    'lt': 'motor',
    'motor': true,
    'cm': true,
    'eff': '90',
    'pf': '85',
  }),
});
