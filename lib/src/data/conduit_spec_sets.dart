/// 전선관 벤더 제원을 "벤더 종류·제조사·재질·규격" 조합마다 기억해 둔다.
///
/// 🚀 [고침] 예전에는 설정 화면을 열기만 해도, 또 규격을 바꿨다 돌아와도 제조사
/// 표 값으로 칸이 다시 채워졌다. 게인을 손으로 고쳐 저장해도 다음에 열면 표
/// 값으로 돌아가 있고, 그대로 저장하면 고친 값이 날아갔다. 튜브 계산기처럼
/// 조합마다 저장한 값을 꺼내 쓴다.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kConduitSpecSetsPrefsKey = 'conduit_spec_sets_v1';

/// 조합마다 기억하는 칸(벤더 제원). 스프링백·커플링 같은 공통 보정은 넣지 않는다.
const List<String> kConduitSpecFields = [
  'clr',
  'takeUp',
  'gain',
  'ramTravel',
  'setback',
  'degPerNotch',
  'notchSpacing',
  'rollerSize',
];

String conduitSpecKey({
  required String benderType,
  required String manufacturer,
  required String conduitType,
  required String conduitSize,
}) {
  String n(String v) => v.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  return '${n(benderType)}|${n(manufacturer)}|${n(conduitType)}|${n(conduitSize)}';
}

/// 폰에 적어 둔 조합별 제원을 모두 읽는다. 깨져 있으면 빈 것.
Future<Map<String, Map<String, double>>> loadConduitSpecSets() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kConduitSpecSetsPrefsKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    final out = <String, Map<String, double>>{};
    decoded.forEach((k, v) {
      if (v is! Map) return;
      final m = <String, double>{};
      for (final f in kConduitSpecFields) {
        final x = v[f];
        if (x is num) m[f] = x.toDouble();
      }
      out[k.toString()] = m;
    });
    return out;
  } catch (e) {
    debugPrint('전선관 제원 묶음 읽기 실패: $e');
    return {};
  }
}

/// [key] 조합의 제원을 적어 둔다(다른 조합은 그대로).
Future<void> saveConduitSpecSet(String key, Map<String, double> values) async {
  final all = await loadConduitSpecSets();
  all[key] = {
    for (final f in kConduitSpecFields)
      if (values[f] != null) f: values[f]!,
  };
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kConduitSpecSetsPrefsKey, jsonEncode(all));
}
