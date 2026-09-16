import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/fitting_item.dart';

// 🚀 [6번 강화] 부속 검색 팝업(SmartFittingSelectorSheet)이 저장하는
// "즐겨찾기 부속" 데이터를 계산기 화면에서도 읽을 수 있게 공용 저장소로
// 뺐다. 여기서 만드는 "부속 세트"는 즐겨찾기해둔 낱개 부속 중 몇 개를
// 묶어 이름 붙여, 한 번에 라인에 삽입할 수 있게 한다.

const String kFavoriteFittingsPrefsKey = 'cutting_favorite_fittings_v1';
const String kFittingSetsPrefsKey = 'cutting_fitting_sets_v1';
const String kRecentCustomFittingsPrefsKey =
    'cutting_recent_custom_fittings_v1';
const int kMaxRecentCustomFittings = 8;

Map<String, dynamic> fittingItemToJson(FittingItem item) => {
  'id': item.id,
  'maker': item.maker,
  'tubeOD': item.tubeOD,
  'category': item.category,
  'name': item.name,
  'deduction': item.deduction,
};

FittingItem fittingItemFromJson(Map<String, dynamic> m) => FittingItem(
  id: m['id'] ?? 'unknown',
  maker: m['maker'] ?? '',
  tubeOD: m['tubeOD'] ?? '',
  category: m['category'] ?? '',
  name: m['name'] ?? '',
  deduction: (m['deduction'] as num?)?.toDouble() ?? 0.0,
  icon: Icons.settings,
);

Future<List<FittingItem>> loadFavoriteFittings() async {
  final prefs = await SharedPreferences.getInstance();
  final str = prefs.getString(kFavoriteFittingsPrefsKey);
  if (str == null) return [];
  return (jsonDecode(str) as List)
      .map((e) => fittingItemFromJson(e as Map<String, dynamic>))
      .toList();
}

/// 즐겨찾기 부속 몇 개를 묶어 이름 붙인 "부속 세트".
class FittingSetGroup {
  final String name;
  final List<FittingItem> items;

  const FittingSetGroup({required this.name, required this.items});

  Map<String, dynamic> toJson() => {
    'name': name,
    'items': items.map(fittingItemToJson).toList(),
  };

  factory FittingSetGroup.fromJson(Map<String, dynamic> m) => FittingSetGroup(
    name: m['name'] ?? '이름 없는 세트',
    items: ((m['items'] as List?) ?? [])
        .map((e) => fittingItemFromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

Future<List<FittingSetGroup>> loadFittingSets() async {
  final prefs = await SharedPreferences.getInstance();
  final str = prefs.getString(kFittingSetsPrefsKey);
  if (str == null) return [];
  return (jsonDecode(str) as List)
      .map((e) => FittingSetGroup.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<void> saveFittingSets(List<FittingSetGroup> sets) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    kFittingSetsPrefsKey,
    jsonEncode(sets.map((s) => s.toJson()).toList()),
  );
}

/// 현장에서 직접 만들어 쓰는 자체 제작 부속(예: 특수 니플, 자체 가공
/// 소켓)은 매번 이름/규격/공제값을 새로 타이핑해야 했다. 최근 입력한
/// 커스텀 부속을 몇 개 기억해뒀다가 한 번 탭으로 다시 채울 수 있게 한다.
class RecentCustomFitting {
  final String name;
  final String spec;
  final double deduction;

  const RecentCustomFitting({
    required this.name,
    required this.spec,
    required this.deduction,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'spec': spec,
    'deduction': deduction,
  };

  factory RecentCustomFitting.fromJson(Map<String, dynamic> m) =>
      RecentCustomFitting(
        name: m['name'] ?? '커스텀 부속',
        spec: m['spec'] ?? '',
        deduction: (m['deduction'] as num?)?.toDouble() ?? 0.0,
      );
}

Future<List<RecentCustomFitting>> loadRecentCustomFittings() async {
  final prefs = await SharedPreferences.getInstance();
  final str = prefs.getString(kRecentCustomFittingsPrefsKey);
  if (str == null) return [];
  return (jsonDecode(str) as List)
      .map((e) => RecentCustomFitting.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// 같은 이름+규격이 이미 있으면 맨 앞으로 올리고, 없으면 새로 추가한다.
/// 최근 [kMaxRecentCustomFittings]개만 남긴다.
Future<void> saveRecentCustomFitting(RecentCustomFitting entry) async {
  final list = await loadRecentCustomFittings();
  list.removeWhere((e) => e.name == entry.name && e.spec == entry.spec);
  list.insert(0, entry);
  if (list.length > kMaxRecentCustomFittings) {
    list.removeRange(kMaxRecentCustomFittings, list.length);
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    kRecentCustomFittingsPrefsKey,
    jsonEncode(list.map((e) => e.toJson()).toList()),
  );
}
