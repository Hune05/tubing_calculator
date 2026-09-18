import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// 🚀 [형강 컷팅 고도화] 튜브 컷팅의 부속 검색 팝업이 가진 "즐겨찾기/최근
// 사용" 빠른 선택(cutting_fitting_favorites.dart)과 같은 개념을 형강
// 항목(규격+길이)에도 적용했다. 자주 쓰는 규격·길이 조합(예: "40x20x1.6
// 찬넬 300mm"를 전선관 지지대로 매번 몇 개씩 자름)을 매번 처음부터
// 고르고 타이핑하지 않고 한 번 탭으로 다시 넣을 수 있게 한다. 수량은
// 매번 다를 수 있어 즐겨찾기/최근 항목엔 포함하지 않고 규격+길이만
// 기억한다.
const String kFavoriteSteelItemsPrefsKey = 'steel_favorite_items_v1';
const String kRecentSteelItemsPrefsKey = 'steel_recent_items_v1';
const int kMaxRecentSteelItems = 8;

class SteelQuickPick {
  final String category; // 'ANGLE' | 'CHANNEL' | 'CUSTOM'
  final String shapeLabel;
  final double length;

  const SteelQuickPick({
    required this.category,
    required this.shapeLabel,
    required this.length,
  });

  String get key => '$category|$shapeLabel|$length';

  Map<String, dynamic> toJson() => {
    'category': category,
    'shapeLabel': shapeLabel,
    'length': length,
  };

  factory SteelQuickPick.fromJson(Map<String, dynamic> m) => SteelQuickPick(
    category: m['category'] ?? 'CUSTOM',
    shapeLabel: m['shapeLabel'] ?? '',
    length: (m['length'] as num?)?.toDouble() ?? 0.0,
  );
}

Future<List<SteelQuickPick>> loadFavoriteSteelItems() async {
  final prefs = await SharedPreferences.getInstance();
  final str = prefs.getString(kFavoriteSteelItemsPrefsKey);
  if (str == null) return [];
  return (jsonDecode(str) as List)
      .map((e) => SteelQuickPick.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// 이미 즐겨찾기에 있으면 빼고, 없으면 추가한다. 갱신된 목록을 돌려준다.
Future<List<SteelQuickPick>> toggleFavoriteSteelItem(
  SteelQuickPick item,
) async {
  final list = await loadFavoriteSteelItems();
  final idx = list.indexWhere((e) => e.key == item.key);
  if (idx >= 0) {
    list.removeAt(idx);
  } else {
    list.insert(0, item);
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    kFavoriteSteelItemsPrefsKey,
    jsonEncode(list.map((e) => e.toJson()).toList()),
  );
  return list;
}

Future<List<SteelQuickPick>> loadRecentSteelItems() async {
  final prefs = await SharedPreferences.getInstance();
  final str = prefs.getString(kRecentSteelItemsPrefsKey);
  if (str == null) return [];
  return (jsonDecode(str) as List)
      .map((e) => SteelQuickPick.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<void> saveRecentSteelItem(SteelQuickPick item) async {
  final list = await loadRecentSteelItems();
  list.removeWhere((e) => e.key == item.key);
  list.insert(0, item);
  if (list.length > kMaxRecentSteelItems) {
    list.removeRange(kMaxRecentSteelItems, list.length);
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    kRecentSteelItemsPrefsKey,
    jsonEncode(list.map((e) => e.toJson()).toList()),
  );
}
