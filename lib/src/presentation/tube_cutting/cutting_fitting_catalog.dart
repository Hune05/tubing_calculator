// 부속 공제값: 앱 안 부속표(통신 없이), 사용자가 잰 값(실측)으로 덮기, 저장해 둔 라인에서 부속 되살리기.
//
// 부속 선택은 서버(fittings)를 먼저 보지만, 서버에 없거나 통신이 없으면 이 파일의 내장 부속표를 쓴다.
// 내장 부속표의 공제값은 카탈로그 확정값이 아니라 근사값이다(db_seeder.dart). 그래서 사용자가 부속을 실제로
// 재서 넣은 값(실측)이 있으면 그것을 우선하고, 화면에는 "근사"·"실측"을 표시한다.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/db_seeder.dart';
import '../../data/models/fitting_item.dart';
import '../../data/models/smart_fitting_db.dart';
import '../common/number_text.dart';

const String kFittingOverridesPrefsKey = 'cutting_fitting_overrides_v1';

/// 부속을 구별하는 열쇠(제조사·외경·분류·이름). 즐겨찾기와 같은 규칙.
String fittingOverrideKey(
  String maker,
  String tubeOD,
  String category,
  String name,
) => '$maker|$tubeOD|$category|$name';

String fittingKeyOf(FittingItem f) =>
    fittingOverrideKey(f.maker, f.tubeOD, f.category, f.name);

/// 서버 문서나 내장 부속표의 한 줄을 부속으로 바꾼다.
FittingItem fittingFromMap(Map<String, dynamic> m, {String? fallbackId}) {
  final rawId = m['id']?.toString();
  return FittingItem(
    id: (rawId != null && rawId.isNotEmpty) ? rawId : (fallbackId ?? ''),
    tubeOD: (m['tubeOD'] ?? '').toString(),
    category: (m['category'] ?? '').toString(),
    name: (m['displayName'] ?? m['name'] ?? '').toString(),
    maker: (m['maker'] ?? '').toString(),
    deduction: (m['deduction'] as num?)?.toDouble() ?? 0.0,
    icon: Icons.settings,
  );
}

/// 내장 부속표에서 제조사·외경이 맞는 줄들(서버에서 읽는 것과 같은 모양).
List<Map<String, dynamic>> builtInFittingMaps({
  required String maker,
  required String tubeOD,
}) => [
  for (final m in SmartFittingDBSeeder.catalog())
    if (m['maker'] == maker && m['tubeOD'] == tubeOD) m,
];

Map<String, FittingItem>? _byIdCache;

/// 내장 부속표에서 id로 찾는다. 없으면 null.
FittingItem? builtInFittingById(String id) {
  _byIdCache ??= {
    for (final m in SmartFittingDBSeeder.catalog())
      m['id'].toString(): fittingFromMap(m),
  };
  return _byIdCache![id];
}

// ── 실측 공제값(이 폰에 기억) ──

typedef FittingOverrides = Map<String, double>;

Future<FittingOverrides> loadFittingOverrides() async {
  try {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(kFittingOverridesPrefsKey);
    if (raw == null) return {};
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final e in m.entries)
        if (e.value is num && (e.value as num).isFinite)
          e.key: (e.value as num).toDouble(),
    };
  } catch (_) {
    return {};
  }
}

Future<void> saveFittingOverrides(FittingOverrides o) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(kFittingOverridesPrefsKey, jsonEncode(o));
  } catch (_) {}
}

/// 실측값이 있으면 그 값으로 바꾸고 "실측"으로 표시한 부속을 돌려준다.
FittingItem withOverride(FittingItem item, FittingOverrides overrides) {
  final v = overrides[fittingKeyOf(item)];
  if (v == null) return item;
  return item.copyWith(deduction: v, measured: true);
}

/// 잰 값으로 쓸 수 있는 글인지(0 이상, 너무 크지 않은 유한한 숫자). 아니면 null.
double? parseMeasuredDeduction(String text) {
  final v = parseNumberText(text);
  if (v == null || !v.isFinite || v < 0 || v > 500) return null;
  return v;
}

// ── 저장해 둔 라인(임시 저장·템플릿)의 한 구간에서 부속 되살리기 ──

/// 구간을 저장할 때 적는 부속 칸. 되살릴 때 내장 부속표에 없어도 값을 잃지 않게 이름·분류·제조사까지 적는다.
Map<String, dynamic> fittingPointJson(FittingItem f) => {
  'fittingId': f.id,
  'isCustom': f.category == 'CUSTOM',
  'customName': f.name,
  'customDed': f.deduction,
  'customOD': f.tubeOD,
  'category': f.category,
  'maker': f.maker,
};

/// 저장해 둔 구간 [m]에서 부속을 되살린다.
/// - 직접 입력한 부속은 저장해 둔 값 그대로.
/// - 내장 부속표(또는 예전 코드 안 표)에 있는 id는 그 부속(실측값이 있으면 그 값).
/// - 어느 표에도 없으면 저장해 둔 이름·값으로 만든다(공제값을 0으로 바꾸지 않는다).
FittingItem restoreFittingFromPoint(
  Map m, {
  FittingOverrides overrides = const {},
}) {
  final id = (m['fittingId'] ?? 'none').toString();
  if (m['isCustom'] == true) {
    return FittingItem(
      id: id.isEmpty ? 'custom' : id,
      category: 'CUSTOM',
      name: (m['customName'] ?? '커스텀 부속').toString(),
      tubeOD: (m['customOD'] ?? '미지정').toString(),
      maker: 'CUSTOM',
      deduction: (m['customDed'] as num?)?.toDouble() ?? 0.0,
      icon: Icons.extension,
    );
  }
  if (id == 'none') return SmartFittingDB.getById('none');
  final known = builtInFittingById(id) ?? _inCodeFittingById(id);
  if (known != null) return withOverride(known, overrides);
  final saved = FittingItem(
    id: id,
    maker: (m['maker'] ?? '').toString(),
    tubeOD: (m['customOD'] ?? '').toString(),
    category: (m['category'] ?? '').toString(),
    name: (m['customName'] ?? id).toString(),
    deduction: (m['customDed'] as num?)?.toDouble() ?? 0.0,
    icon: Icons.settings,
  );
  return withOverride(saved, overrides);
}

FittingItem? _inCodeFittingById(String id) {
  for (final f in SmartFittingDB.allFittings) {
    if (f.id == id) return f;
  }
  return null;
}

/// 라인의 부속들 가운데 공제값이 근사값인 것의 개수.
int approxFittingCount(Iterable<FittingItem> fittings) =>
    fittings.where((f) => f.isApprox).length;

/// 근사값 부속 [n]개가 있을 때 화면·지시서에 붙일 안내. 없으면 빈 글.
String approxFittingNote(int n) => n <= 0
    ? ''
    : '공제값이 근사값인 부속 $n개 · 실제 부속을 재서 확인하십시오';
