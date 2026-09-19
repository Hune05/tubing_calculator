import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'project_phase.dart';

// 🚀 [단계 템플릿] 자주 하는 공사 유형별 단계 구성을 저장해 두고, 새 프로젝트에서
// 시작일/납기만 정해 바로 불러온다. 단계별 상대 비중(weight)만 저장하므로 기간이
// 달라져도 비율대로 다시 나뉜다. 이 기기(SharedPreferences)에 보관한다.
class PhaseTemplate {
  final String name;
  final List<String> names;
  final List<double> weights;
  final bool builtIn;

  const PhaseTemplate(
    this.name,
    this.names,
    this.weights, {
    this.builtIn = false,
  });

  static const standard = PhaseTemplate(
    '표준',
    kStandardPhaseNames,
    kStandardPhaseWeights,
    builtIn: true,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'names': names,
    'weights': weights,
  };

  static PhaseTemplate fromJson(Map<String, dynamic> j) => PhaseTemplate(
    j['name'].toString(),
    (j['names'] as List).map((e) => e.toString()).toList(),
    (j['weights'] as List).map((e) => (e as num).toDouble()).toList(),
  );
}

const _kKey = 'phase_templates_v1';

Future<List<PhaseTemplate>> loadPhaseTemplates() async {
  final list = <PhaseTemplate>[PhaseTemplate.standard];
  try {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kKey);
    if (raw != null) {
      for (final e in jsonDecode(raw) as List) {
        list.add(PhaseTemplate.fromJson(Map<String, dynamic>.from(e as Map)));
      }
    }
  } catch (_) {}
  return list;
}

Future<void> _saveAll(List<PhaseTemplate> all) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(
    _kKey,
    jsonEncode(all.where((t) => !t.builtIn).map((t) => t.toJson()).toList()),
  );
}

// 같은 이름이 있으면 덮어쓴다.
Future<void> savePhaseTemplate(PhaseTemplate t) async {
  final all = await loadPhaseTemplates();
  all.removeWhere((e) => e.name == t.name && !e.builtIn);
  all.add(t);
  await _saveAll(all);
}

Future<void> deletePhaseTemplate(String name) async {
  final all = await loadPhaseTemplates();
  all.removeWhere((e) => e.name == name && !e.builtIn);
  await _saveAll(all);
}

// 현재 프로젝트의 단계 구성을 템플릿으로: 각 단계 기간(일)을 비중으로 쓴다.
PhaseTemplate templateFromPhases(String name, List<Map<String, dynamic>> ph) {
  return PhaseTemplate(
    name,
    ph.map((p) => p['name'].toString()).toList(),
    ph.map((p) {
      final s = phaseStart(p), e = phaseEnd(p);
      if (s == null || e == null) return 1.0;
      return (e.difference(s).inDays + 1).toDouble();
    }).toList(),
  );
}
