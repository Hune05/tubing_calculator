/// 전선관 보관함(저장해 둔 도면).
///
/// 🚀 [고침] 예전 보관함은 코드에 박아 둔 예시 3건(2024년 날짜)을 보여 줄 뿐이었다.
/// 저장하는 곳이 없었고, "불러오기"를 눌러도 "성공적으로 불러왔습니다"만 뜨고
/// 목록에는 아무것도 들어가지 않았다. 폰에 적어 두고 실제로 읽고 불러온다.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kConduitDrawingsPrefsKey = 'conduit_saved_drawings_v1';

class ConduitDrawing {
  final String id;
  final String folderName;
  final String title;
  final String date; // 2026-09-21 14:30
  final double totalCut;
  final List<Map<String, dynamic>> bends;

  /// 저장할 때 쓴 장비(벤더 종류·제조사·규격·테이크업·게인…). 기록용.
  final Map<String, dynamic> settings;

  const ConduitDrawing({
    required this.id,
    required this.folderName,
    required this.title,
    required this.date,
    required this.totalCut,
    required this.bends,
    this.settings = const {},
  });

  int get segmentCount => bends.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'folderName': folderName,
    'title': title,
    'date': date,
    'totalCut': totalCut,
    'bends': bends,
    'settings': settings,
  };

  static ConduitDrawing? fromJson(dynamic j) {
    if (j is! Map) return null;
    final rawBends = j['bends'];
    if (rawBends is! List) return null;
    return ConduitDrawing(
      id: j['id']?.toString() ?? '',
      folderName: j['folderName']?.toString() ?? '미분류 도면',
      title: j['title']?.toString() ?? '이름 없는 도면',
      date: j['date']?.toString() ?? '',
      totalCut: (j['totalCut'] as num?)?.toDouble() ?? 0.0,
      bends: [
        for (final b in rawBends)
          if (b is Map)
            {
              'length': (b['length'] as num?)?.toDouble() ?? 0.0,
              'angle': (b['angle'] as num?)?.toDouble() ?? 0.0,
              'rotation': (b['rotation'] as num?)?.toDouble() ?? 0.0,
            },
      ],
      settings: j['settings'] is Map
          ? Map<String, dynamic>.from(j['settings'] as Map)
          : const {},
    );
  }
}

/// 보관함 목록(새것이 먼저). 깨져 있으면 빈 목록.
Future<List<ConduitDrawing>> loadConduitDrawings() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kConduitDrawingsPrefsKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    final list = [for (final j in decoded) ?ConduitDrawing.fromJson(j)];
    list.sort((a, b) => b.id.compareTo(a.id));
    return list;
  } catch (e) {
    debugPrint('전선관 보관함 읽기 실패: $e');
    return [];
  }
}

Future<void> _write(List<ConduitDrawing> list) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    kConduitDrawingsPrefsKey,
    jsonEncode([for (final d in list) d.toJson()]),
  );
}

String _now() {
  final d = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

/// 지금 목록을 보관함에 넣는다. 넣은 도면을 돌려준다.
Future<ConduitDrawing> saveConduitDrawing({
  required String folderName,
  required String title,
  required double totalCut,
  required List<Map<String, dynamic>> bends,
  Map<String, dynamic> settings = const {},
}) async {
  final all = await loadConduitDrawings();
  final drawing = ConduitDrawing(
    // 시각으로 만든 id라 정렬하면 새것이 먼저 온다.
    id: DateTime.now().microsecondsSinceEpoch.toString().padLeft(20, '0'),
    folderName: folderName.trim().isEmpty ? '미분류 도면' : folderName.trim(),
    title: title.trim().isEmpty ? '이름 없는 도면' : title.trim(),
    date: _now(),
    totalCut: totalCut,
    bends: [
      for (final b in bends)
        {
          'length': (b['length'] as num?)?.toDouble() ?? 0.0,
          'angle': (b['angle'] as num?)?.toDouble() ?? 0.0,
          'rotation': (b['rotation'] as num?)?.toDouble() ?? 0.0,
        },
    ],
    settings: {
      for (final k in const [
        'benderType',
        'manufacturer',
        'conduitType',
        'conduitSize',
        'takeUp',
        'gain',
        'clr',
        'setback',
      ])
        if (settings[k] != null) k: settings[k],
    },
  );
  await _write([drawing, ...all]);
  return drawing;
}

Future<void> deleteConduitDrawing(String id) async {
  final all = await loadConduitDrawings();
  await _write([
    for (final d in all)
      if (d.id != id) d,
  ]);
}

/// 지운 도면을 다시 넣는다(지운 알림의 "되돌리기").
Future<void> restoreConduitDrawing(ConduitDrawing drawing) async {
  final all = await loadConduitDrawings();
  if (all.any((d) => d.id == drawing.id)) return;
  await _write([drawing, ...all]);
}
