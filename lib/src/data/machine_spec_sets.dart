import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 규격·장비별 제원 묶음.
///
/// 🚀 [추가] 예전에는 제원이 한 벌뿐이라, 3/8"로 맞춰 둔 반경·게인을
/// 1/2"로 바꾸면 잃어버리고 다시 넣어야 했다. 벤더 브랜드·장비 타입·규격을
/// 묶어 이름표로 삼고, 그 조합으로 돌아오면 넣어 뒀던 값을 그대로 꺼낸다.
class MachineSpecSet {
  final double bendRadius;
  final double takeUp;
  final double gain;
  final double springback;
  final double minStraight;
  final double benderOffset;
  final double fittingDepth;
  final double markThickness;
  final double offsetShrink;
  final double cutMargin;

  /// AUTO(제원표로 계산)인 칸들. 여기 없는 칸은 손으로 넣은 값이다.
  final Set<String> autoFields;

  const MachineSpecSet({
    this.bendRadius = 0,
    this.takeUp = 0,
    this.gain = 0,
    this.springback = 0,
    this.minStraight = 0,
    this.benderOffset = 0,
    this.fittingDepth = 0,
    this.markThickness = 0,
    this.offsetShrink = 0,
    this.cutMargin = 0,
    this.autoFields = const {},
  });

  Map<String, dynamic> toJson() => {
    'bendRadius': bendRadius,
    'takeUp': takeUp,
    'gain': gain,
    'springback': springback,
    'minStraight': minStraight,
    'benderOffset': benderOffset,
    'fittingDepth': fittingDepth,
    'markThickness': markThickness,
    'offsetShrink': offsetShrink,
    'cutMargin': cutMargin,
    'auto': autoFields.toList(),
  };

  static MachineSpecSet fromJson(Map<String, dynamic> m) {
    double d(String k) => (m[k] as num?)?.toDouble() ?? 0.0;
    return MachineSpecSet(
      bendRadius: d('bendRadius'),
      takeUp: d('takeUp'),
      gain: d('gain'),
      springback: d('springback'),
      minStraight: d('minStraight'),
      benderOffset: d('benderOffset'),
      fittingDepth: d('fittingDepth'),
      markThickness: d('markThickness'),
      offsetShrink: d('offsetShrink'),
      cutMargin: d('cutMargin'),
      autoFields: {
        for (final a in (m['auto'] as List?) ?? const []) a.toString(),
      },
    );
  }

  /// 값이 하나라도 들어 있는지(다 0이면 저장할 게 없다).
  bool get hasAnyValue =>
      bendRadius > 0 ||
      takeUp > 0 ||
      gain > 0 ||
      springback > 0 ||
      minStraight > 0 ||
      benderOffset > 0 ||
      fittingDepth > 0 ||
      markThickness > 0 ||
      offsetShrink > 0 ||
      cutMargin > 0;
}

/// 제원 묶음을 찾을 이름표. 벤더 브랜드 · 장비 타입 · 규격 · 재질.
/// 10-09: 재질을 붙였다(SUS와 구리는 게인·스프링백이 달라 따로 기억한다). 재질이 비면 예전 꼴.
String machineSpecKey({
  required String benderBrand,
  required String benderType,
  required String tubeSize,
  String tubeMaterial = '',
}) {
  final base = '${_n(benderBrand)}|${_n(benderType)}|${_n(tubeSize)}';
  final m = _n(tubeMaterial);
  return m.isEmpty ? base : '$base|$m';
}

String _n(String v) => v.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

/// 재질 칸이 없는 예전 이름표(브랜드|타입|규격)를 [material]을 붙인 이름표로 옮긴다.
/// 예전 묶음은 그때 쓰던 재질 값이라, 앱을 켤 때의 재질로 한 번 옮긴다(이미 있으면 덮지 않는다).
Future<void> migrateMachineSpecSetsToMaterial(String material) async {
  final m = _n(material);
  if (m.isEmpty) return;
  try {
    final all = await loadMachineSpecSets();
    final old = {
      for (final e in all.entries)
        if (e.key.split('|').length == 3) e.key: e.value,
    };
    if (old.isEmpty) return;
    final out = <String, MachineSpecSet>{
      for (final e in all.entries)
        if (e.key.split('|').length != 3) e.key: e.value,
    };
    for (final e in old.entries) {
      out.putIfAbsent('${e.key}|$m', () => e.value);
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(
      kMachineSpecSetsPrefsKey,
      jsonEncode({for (final e in out.entries) e.key: e.value.toJson()}),
    );
  } catch (_) {}
}

const String kMachineSpecSetsPrefsKey = 'machine_spec_sets_v1';

/// 폰에 적어 둔 제원 묶음을 다 읽는다.
Future<Map<String, MachineSpecSet>> loadMachineSpecSets() async {
  try {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(kMachineSpecSetsPrefsKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return {
      for (final e in decoded.entries)
        if (e.value is Map)
          e.key.toString(): MachineSpecSet.fromJson(
            Map<String, dynamic>.from(e.value as Map),
          ),
    };
  } catch (_) {
    return {};
  }
}

/// 제원 묶음 하나를 적어 둔다(값이 다 0이면 적지 않는다).
Future<void> saveMachineSpecSet(String key, MachineSpecSet set) async {
  if (key.trim().isEmpty || !set.hasAnyValue) return;
  try {
    final all = await loadMachineSpecSets();
    all[key] = set;
    final p = await SharedPreferences.getInstance();
    await p.setString(
      kMachineSpecSetsPrefsKey,
      jsonEncode({for (final e in all.entries) e.key: e.value.toJson()}),
    );
  } catch (_) {}
}

/// 이름표로 제원 묶음을 꺼낸다(없으면 null).
Future<MachineSpecSet?> loadMachineSpecSet(String key) async {
  final all = await loadMachineSpecSets();
  return all[key];
}
