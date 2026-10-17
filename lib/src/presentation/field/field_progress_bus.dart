// 현장 탭 진행(어디까지 했는지·실측)을 다른 화면이 읽게 하는 연결(10-17).
// 아이소가 캐드식 치수에 실측을 같이 보여 줄 때 쓴다. 현장 탭이 진행을 저장할 때마다
// [fieldProgressRev]가 1씩 늘고, 아이소는 그것을 듣고 저장된 진행을 다시 읽는다.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 현장 진행이 저장될 때마다 1씩 는다.
final ValueNotifier<int> fieldProgressRev = ValueNotifier<int>(0);

/// 튜브 현장 탭이 진행을 적는 칸(FieldMarkingScreen 기본값과 같다).
const String kTubeFieldProgressKey = 'field_progress_v1';

/// 저장된 현장 진행에서 실측 차이(단계 번호 0부터 → 실측 − 계산 mm).
/// 도면 구분 글 [signature]가 다르면(다른 도면) 빈 것.
Future<Map<int, double>> readFieldMeasured(
  String progressKey,
  String signature,
) async {
  final out = <int, double>{};
  try {
    final raw = (await SharedPreferences.getInstance()).getString(progressKey);
    if (raw == null || raw.isEmpty) {
      return (await _archived(signature, progressKey)).measured;
    }
    final p = jsonDecode(raw);
    if (p is! Map || p['sig'] != signature) {
      return (await _archived(signature, progressKey)).measured;
    }
    final m = p['measured'];
    if (m is Map) {
      m.forEach((k, v) {
        final i = int.tryParse('$k');
        if (i != null && v is num) out[i] = v.toDouble();
      });
    }
  } catch (_) {}
  return out;
}

/// 저장된 현장 진행에서 실측 기록 번호(단계 → 벤딩 실측 기록 id). 다시 기록하면 같은 번호로 덮는다.
Future<Map<int, String>> readFieldMeasuredIds(
  String progressKey,
  String signature,
) async {
  final out = <int, String>{};
  try {
    final raw = (await SharedPreferences.getInstance()).getString(progressKey);
    if (raw == null || raw.isEmpty) {
      return (await _archived(signature, progressKey)).ids;
    }
    final p = jsonDecode(raw);
    if (p is! Map || p['sig'] != signature) {
      return (await _archived(signature, progressKey)).ids;
    }
    final m = p['measuredIds'];
    if (m is Map) {
      m.forEach((k, v) {
        final i = int.tryParse('$k');
        if (i != null && v is String) out[i] = v;
      });
    }
  } catch (_) {}
  return out;
}

/// 다른 화면(아이소)에서 넣은 실측을 현장 진행에 적는다(10-17).
/// 같은 도면이면 진행(어디까지 했는지)은 그대로 두고 실측만 바꾼다. 다른 도면이면 새로 시작한다.
Future<void> writeFieldMeasured({
  required String progressKey,
  required String signature,
  required int step,
  required double diff,
  required String id,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> p = {};
    final raw = prefs.getString(progressKey);
    if (raw != null && raw.isNotEmpty) {
      final j = jsonDecode(raw);
      if (j is Map<String, dynamic> && j['sig'] == signature) p = j;
    }
    if (p.isEmpty) {
      p = {'sig': signature, 'current': 0, 'done': <int>[]};
    }
    final measured = Map<String, dynamic>.from(p['measured'] as Map? ?? {});
    final ids = Map<String, dynamic>.from(p['measuredIds'] as Map? ?? {});
    measured['$step'] = diff;
    ids['$step'] = id;
    p['measured'] = measured;
    p['measuredIds'] = ids;
    await prefs.setString(progressKey, jsonEncode(p));
    await archiveFieldMeasured(
      progressKey: progressKey,
      signature,
      {
        for (final e in measured.entries)
          int.parse(e.key): (e.value as num).toDouble(),
      },
      {for (final e in ids.entries) int.parse(e.key): '${e.value}'},
    );
  } catch (_) {}
  fieldProgressRev.value++;
}

// ── 도면별 실측 보관(10-17 점검) ──
// 현장 진행 칸은 지금 도면 하나만 적는다. 그래서 보관함에서 다른 도면을 열면 앞 도면의
// 실측(아이소 표시)이 사라졌다. 실측이 있는 도면은 여기에 따로 남겨 두고, 다시 열면 되살린다.
// 최근 [_kArchiveCap]개까지만.

const String kMeasureArchiveKey = 'field_measure_archive_v1';
const int _kArchiveCap = 50;

String _archiveKeyFor(String progressKey) =>
    progressKey == kTubeFieldProgressKey
    ? kMeasureArchiveKey
    : '${progressKey}_archive';

Future<({Map<int, double> measured, Map<int, String> ids})> _archived(
  String signature,
  String progressKey,
) async {
  final m = <int, double>{};
  final ids = <int, String>{};
  try {
    final raw = (await SharedPreferences.getInstance()).getString(
      _archiveKeyFor(progressKey),
    );
    if (raw != null && raw.isNotEmpty) {
      final a = jsonDecode(raw);
      final dm = a is Map ? a['data'] : null;
      final e = dm is Map ? dm[signature] : null;
      if (e is Map) {
        (e['m'] as Map? ?? {}).forEach((k, v) {
          final i = int.tryParse('$k');
          if (i != null && v is num) m[i] = v.toDouble();
        });
        (e['ids'] as Map? ?? {}).forEach((k, v) {
          final i = int.tryParse('$k');
          if (i != null && v is String) ids[i] = v;
        });
      }
    }
  } catch (_) {}
  return (measured: m, ids: ids);
}

/// 이 도면의 실측을 도면별 보관에 적는다(비면 그 도면을 뺀다).
Future<void> archiveFieldMeasured(
  String signature,
  Map<int, double> measured,
  Map<int, String> ids, {
  String progressKey = kTubeFieldProgressKey,
}) async {
  if (signature.isEmpty) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_archiveKeyFor(progressKey));
    Map<String, dynamic> data = {};
    List<String> order = [];
    if (raw != null && raw.isNotEmpty) {
      final a = jsonDecode(raw);
      if (a is Map) {
        data = Map<String, dynamic>.from(a['data'] as Map? ?? {});
        order = [for (final o in (a['order'] as List? ?? [])) '$o'];
      }
    }
    order.remove(signature);
    if (measured.isEmpty) {
      data.remove(signature);
    } else {
      data[signature] = {
        'm': {for (final e in measured.entries) '${e.key}': e.value},
        'ids': {for (final e in ids.entries) '${e.key}': e.value},
      };
      order.add(signature);
    }
    while (order.length > _kArchiveCap) {
      data.remove(order.removeAt(0));
    }
    await prefs.setString(
      _archiveKeyFor(progressKey),
      jsonEncode({'order': order, 'data': data}),
    );
  } catch (_) {}
}

// ── 각도 실측(10-17) ──
// 각도기로 잰 실제 각도(벤드 순서 → °). 벤딩 실측 기록(mm 통계)과 섞이지 않게 따로 둔다.
// 도면 구분 글이 다르면(다른 도면) 빈 것.

const String kTubeAngleKey = 'field_angle_v1';

/// 각도 허용(± °). 수동 벤더 검사 기준으로 흔히 쓰는 1°.
const double kAngleTolDefault = 1.0;

/// 진행 칸(튜브·전선관)마다 각도 실측을 따로 적는다. 튜브는 튜브 벤딩 앱과 같은 칸 이름.
String angleKeyFor(String progressKey) => progressKey == kTubeFieldProgressKey
    ? kTubeAngleKey
    : '${progressKey}_angle';

Future<Map<int, double>> readAngleMeasured(
  String signature, {
  String progressKey = kTubeFieldProgressKey,
}) async {
  final out = <int, double>{};
  try {
    final raw = (await SharedPreferences.getInstance()).getString(
      angleKeyFor(progressKey),
    );
    if (raw == null || raw.isEmpty) return out;
    final p = jsonDecode(raw);
    if (p is! Map) return out;
    // 10-17: 도면별 {data: {sig: {step: °}}}. 예전(한 도면) 모양 {sig, angles}도 읽는다.
    final m = p['data'] is Map
        ? (p['data'] as Map)[signature]
        : (p['sig'] == signature ? p['angles'] : null);
    if (m is Map) {
      m.forEach((k, v) {
        final i = int.tryParse('$k');
        if (i != null && v is num) out[i] = v.toDouble();
      });
    }
  } catch (_) {}
  return out;
}

/// [actual]이 null이면 그 벤드 각도 실측을 지운다.
Future<void> writeAngleMeasured(
  String signature,
  int step,
  double? actual, {
  String progressKey = kTubeFieldProgressKey,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cur = await readAngleMeasured(signature, progressKey: progressKey);
    if (actual == null) {
      cur.remove(step);
    } else {
      cur[step] = actual;
    }
    Map<String, dynamic> data = {};
    List<String> order = [];
    final raw = prefs.getString(angleKeyFor(progressKey));
    if (raw != null && raw.isNotEmpty) {
      final p = jsonDecode(raw);
      if (p is Map && p['data'] is Map) {
        data = Map<String, dynamic>.from(p['data'] as Map);
        order = [for (final o in (p['order'] as List? ?? [])) '$o'];
      } else if (p is Map && p['sig'] is String && p['angles'] is Map) {
        data[p['sig'] as String] = p['angles'];
        order.add(p['sig'] as String);
      }
    }
    order.remove(signature);
    if (cur.isEmpty) {
      data.remove(signature);
    } else {
      data[signature] = {for (final e in cur.entries) '${e.key}': e.value};
      order.add(signature);
    }
    while (order.length > _kArchiveCap) {
      data.remove(order.removeAt(0));
    }
    await prefs.setString(
      angleKeyFor(progressKey),
      jsonEncode({'order': order, 'data': data}),
    );
  } catch (_) {}
  fieldProgressRev.value++;
}
