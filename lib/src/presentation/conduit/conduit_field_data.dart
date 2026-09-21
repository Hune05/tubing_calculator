/// 전선관 현장 탭(가로 줄자 화면)에 넘길 자료.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking.dart';

/// 마킹 탭의 커플링 "체결/미체결". 현장 탭도 같은 값으로 셈한다.
/// 🚀 [고침] 예전에는 마킹 탭 안에만 있어서, 현장 탭은 마킹 탭이 다 그린 뒤
/// 넘겨준 값을 한 프레임 늦게 받아 썼다.
final ValueNotifier<bool> conduitUseCoupling = ValueNotifier(false);

/// 3D(아이소) 탭에서 고른 시작 방향. 관끼리 닿는지 볼 때 쓴다.
final ValueNotifier<String> conduitStartDir = ValueNotifier('RIGHT');

Future<void> loadConduitStartDir() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('conduit_saved_start_dir');
    if (saved != null) conduitStartDir.value = saved;
  } catch (_) {}
}

/// 현장 탭이 다시 그려야 할 때 알려 주는 것들.
Listenable conduitFieldListenable() => Listenable.merge([
  ConduitDataManager(),
  globalBenderSettings,
  conduitUseCoupling,
  conduitStartDir,
]);

FieldMarkingData computeConduitFieldData() {
  final bendList = ConduitDataManager().bendList;
  if (bendList.isEmpty) return FieldMarkingData.empty;
  final settings = globalBenderSettings.value;

  final markings = calculateConduitMarkings(
    bendList,
    settings,
    useCoupling: conduitUseCoupling.value,
  );
  final check = conduitBendCheck(
    bendList,
    settings,
    startDir: conduitStartDir.value,
  );

  final marks = <FieldMark>[];
  int number = 0;
  double prevBend = 0.0;
  for (int i = 0; i < markings.length; i++) {
    final m = markings[i];
    final double angle = (m['angle'] as num).toDouble();
    final double pos = (m['mark'] as num).toDouble();
    if (angle > 0) {
      number++;
      marks.add(
        FieldMark(
          number: number,
          position: pos,
          angle: angle,
          targetAngle: (m['targetAngle'] as num?)?.toDouble(),
          rotation: (m['rotation'] as num).toDouble(),
          gap: pos - prevBend,
          roll: check.rollByIndex[i],
        ),
      );
      prevBend = pos;
    } else {
      marks.add(FieldMark(number: 0, position: pos, angle: 0, rotation: 0));
    }
  }

  return FieldMarkingData(
    totalCut: conduitTotalCut(bendList, settings),
    marks: marks,
    warnings: check.warnings,
  );
}

/// 마킹지(PDF)에 적을 전선관 장비 제원.
List<(String, String)> conduitMarkingSheetSpecs(Map<String, dynamic> s) {
  double d(String k) => (s[k] as num?)?.toDouble() ?? 0.0;
  String n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  const types = {'hand': '수동', 'ram': '유압', 'chicago': '시카고'};
  final type = s['benderType']?.toString() ?? 'hand';
  return [
    ('벤더', '${types[type] ?? type} · ${s['manufacturer'] ?? ''}'),
    ('규격', '${s['conduitType'] ?? ''} ${s['conduitSize'] ?? ''}'),
    if (type == 'ram')
      ('셋백(90°)', '${n(d('setback'))} mm')
    else
      ('테이크업(90°)', '${n(d('takeUp'))} mm'),
    ('게인(90°)', '${n(d('gain'))} mm'),
    ('CLR', '${n(d('clr'))} mm'),
    ('스프링백', (s['applySpringback'] ?? true) ? '${n(d('springback'))}°' : '안 씀'),
    (
      '커플링',
      conduitUseCoupling.value ? '체결 ${n(d('couplingDepth'))} mm' : '미체결',
    ),
    if (d('bladeKerf') > 0) ('톱날 두께', '${n(d('bladeKerf'))} mm'),
  ];
}
