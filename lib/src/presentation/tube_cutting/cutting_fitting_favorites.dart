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
