import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
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
const _kCloud = 'my_project_templates';

// 템플릿은 Firestore(my_project_templates)에 보관해 어느 기기에서든 같이 쓰고,
// 이 기기의 SharedPreferences에도 사본을 둔다(오프라인 대비). 예전에 이 기기에만
// 저장했던 템플릿은 처음 불러올 때 클라우드로 올라간다.
Future<List<PhaseTemplate>> _loadLocal() async {
  final list = <PhaseTemplate>[];
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

Future<void> _saveLocal(List<PhaseTemplate> all) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(
    _kKey,
    jsonEncode(all.where((t) => !t.builtIn).map((t) => t.toJson()).toList()),
  );
}

Future<List<PhaseTemplate>> loadPhaseTemplates() async {
  final byName = <String, PhaseTemplate>{};
  final local = await _loadLocal();
  for (final t in local) {
    byName[t.name] = t;
  }
  try {
    final col = FirebaseFirestore.instance.collection(_kCloud);
    final snap = await col.get().timeout(const Duration(seconds: 6));
    final cloudNames = <String>{};
    for (final d in snap.docs) {
      final t = PhaseTemplate.fromJson(d.data());
      byName[t.name] = t;
      cloudNames.add(t.name);
    }
    for (final t in local) {
      if (!cloudNames.contains(t.name)) {
        await col.doc(Uri.encodeComponent(t.name)).set(t.toJson());
      }
    }
    await _saveLocal(byName.values.toList());
  } catch (_) {}
  return [PhaseTemplate.standard, ...byName.values];
}

// 같은 이름이 있으면 덮어쓴다.
Future<void> savePhaseTemplate(PhaseTemplate t) async {
  final local = await _loadLocal();
  local.removeWhere((e) => e.name == t.name);
  local.add(t);
  await _saveLocal(local);
  try {
    await FirebaseFirestore.instance
        .collection(_kCloud)
        .doc(Uri.encodeComponent(t.name))
        .set(t.toJson());
  } catch (_) {}
}

Future<void> deletePhaseTemplate(String name) async {
  final local = await _loadLocal();
  local.removeWhere((e) => e.name == name);
  await _saveLocal(local);
  try {
    await FirebaseFirestore.instance
        .collection(_kCloud)
        .doc(Uri.encodeComponent(name))
        .delete();
  } catch (_) {}
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
