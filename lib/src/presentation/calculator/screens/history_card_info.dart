/// 튜브 보관함(history 테이블) 줄 정보와 읽기·쓰기. 보관함 탭과 저장 창이 같이 쓴다.
library;

import 'dart:convert';

import 'package:tubing_calculator/src/core/database/database_helper.dart';

/// history 테이블 읽기·쓰기. 시험에서만 바꿔 끼운다(시험에는 sqflite가 없다).
class TubeHistoryDb {
  TubeHistoryDb._();

  static Future<List<Map<String, dynamic>>> Function() load = () =>
      DatabaseHelper.instance.getHistory();

  static Future<void> Function(int id) delete = (id) async {
    await DatabaseHelper.instance.deleteHistory(id);
  };

  static Future<void> Function(Map<String, dynamic> row) insert = (row) async {
    await DatabaseHelper.instance.insertHistory(row);
  };

  /// 여러 줄의 p_to_p(프로젝트 이름 등이 든 JSON 글)를 한 번에 바꾼다. 키는 줄 번호.
  static Future<void> Function(Map<int, String> idToPToP) updatePToP = (m) =>
      DatabaseHelper.instance.updateHistoryPToPBatch(m);
}

/// 저장한 줄의 p_to_p 글에 프로젝트 이름만 바꿔 넣는다(다른 값은 그대로).
/// 읽을 수 없는 글이면 프로젝트 이름만 든 새 글로.
String historyWithProject(String? pToPJson, String project) {
  Map<String, dynamic> map = {};
  try {
    final d = jsonDecode(pToPJson ?? '{}');
    if (d is Map) map = Map<String, dynamic>.from(d);
  } catch (_) {}
  map['project'] = project.trim();
  return jsonEncode(map);
}

/// 보관함 카드에 보일 글.
class HistoryCardInfo {
  /// 카드 제목: "A ➔ B". 시작·도착을 둘 다 모르면 "굽힘 3개 도면"처럼 도면 요약.
  final String title;

  /// 저장 일시 "2026-10-05 15:14"(시각이 없던 옛 줄은 날짜만).
  final String dateText;

  final int bendCount;

  /// "굽힘 2개 (90°, 45°)" 또는 "직관만".
  final String shapeText;

  /// 저장 때 적은 메모(없으면 빈 글).
  final String note;

  /// 총 절단 길이(mm, 반올림).
  final int cut;

  const HistoryCardInfo({
    required this.title,
    required this.dateText,
    required this.bendCount,
    required this.shapeText,
    required this.note,
    required this.cut,
  });

  static bool _unknown(String s) =>
      s.trim().isEmpty || s.trim() == '모름' || s.trim() == 'null';

  static String _angleText(double a) =>
      '${a == a.roundToDouble() ? a.round() : a}°';

  static HistoryCardInfo of(Map<String, dynamic> item) {
    var from = '';
    var to = '';
    var note = '';
    try {
      final p = jsonDecode(item['p_to_p']?.toString() ?? '{}');
      if (p is Map) {
        from = '${p['from'] ?? ''}';
        to = '${p['to'] ?? ''}';
        note = '${p['note'] ?? ''}'.trim();
      }
    } catch (_) {}

    final angles = <double>[];
    try {
      final b = jsonDecode(item['bend_data']?.toString() ?? '[]');
      if (b is List) {
        for (final e in b) {
          if (e is! Map) continue;
          final a = double.tryParse('${e['angle'] ?? 0}') ?? 0.0;
          if (a > 0) angles.add(a);
        }
      }
    } catch (_) {}

    final shown = angles.take(6).map(_angleText).join(', ');
    final shape = angles.isEmpty
        ? '직관만'
        : '굽힘 ${angles.length}개 ($shown${angles.length > 6 ? ' …' : ''})';
    final String title;
    if (_unknown(from) && _unknown(to)) {
      title = angles.isEmpty ? '직관 도면' : '굽힘 ${angles.length}개 도면';
    } else {
      title =
          '${_unknown(from) ? '모름' : from.trim()} ➔ ${_unknown(to) ? '모름' : to.trim()}';
    }

    final rawDate = item['date']?.toString() ?? '';
    final date = rawDate.length >= 16
        ? rawDate.substring(0, 16)
        : (rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate);

    return HistoryCardInfo(
      title: title,
      dateText: date,
      bendCount: angles.length,
      shapeText: shape,
      note: note,
      cut: (double.tryParse('${item['total_length']}') ?? 0.0).round(),
    );
  }
}
