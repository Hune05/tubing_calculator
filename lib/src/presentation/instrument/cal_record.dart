// 4-20mA 교정 기록(폰에만 저장). 한 계기의 조정 전·조정 후 다섯 점과 계기·기준기·작업자 정보.
// 성적서 PDF는 cal_record_pdf.dart. 셈은 signal_calc.dart의 checkPoint를 그대로 쓴다.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'signal_calc.dart';

/// 교정 점 — 0·25·50·75·100%.
const List<double> kCalPoints = [0, 25, 50, 75, 100];

/// 한 점에 넣은 값(비우면 점 값)과 읽은 값(비우면 이 점은 안 잼).
class CalEntry {
  final double? applied;
  final double? reading;
  const CalEntry({this.applied, this.reading});

  Map<String, dynamic> toJson() => {'a': applied, 'r': reading};
  factory CalEntry.fromJson(Map<String, dynamic> j) => CalEntry(
    applied: (j['a'] as num?)?.toDouble(),
    reading: (j['r'] as num?)?.toDouble(),
  );
}

/// 한 벌(조정 전 또는 조정 후)의 결과 요약.
class CalSummary {
  final List<CalPoint?> points; // 점마다(읽은 값이 없으면 null)
  const CalSummary(this.points);

  List<(int, CalPoint)> get measured => [
    for (var i = 0; i < points.length; i++)
      if (points[i] != null) (i, points[i]!),
  ];
  bool get isEmpty => measured.isEmpty;

  /// 오차가 가장 큰 점(없으면 null).
  (int, CalPoint)? get worst {
    final m = measured;
    if (m.isEmpty) return null;
    return m.reduce((a, b) => b.$2.errPct.abs() > a.$2.errPct.abs() ? b : a);
  }

  /// 허용 오차를 넘은 점.
  List<int> get failed => [
    for (final m in measured)
      if (m.$2.pass == false) m.$1,
  ];

  /// 판정: 잰 점이 없거나 허용 오차가 없으면 null.
  bool? get pass {
    final m = measured;
    if (m.isEmpty || m.first.$2.pass == null) return null;
    return failed.isEmpty;
  }
}

/// 다섯 점을 셈한다. 넣은 값이 비었으면 점 값.
CalSummary evaluateCal({
  required List<CalEntry> entries,
  required double lrv,
  required double urv,
  required Transfer transfer,
  required ReadKind kind,
  double? tolPct,
}) => CalSummary([
  for (var i = 0; i < kCalPoints.length; i++)
    if (i >= entries.length || entries[i].reading == null)
      null
    else
      checkPoint(
        applied: entries[i].applied ?? pctToPv(kCalPoints[i], lrv, urv),
        reading: entries[i].reading!,
        kind: kind,
        lrv: lrv,
        urv: urv,
        transfer: transfer,
        tolPct: tolPct != null && tolPct > 0 ? tolPct : null,
      ),
]);

class CalRecord {
  final String id;
  final DateTime date;
  final String tag; // 태그 번호(PT-101 등)
  final String instrument; // 계기·용도
  final String model; // 제조사·모델
  final String refStd; // 기준기(모델·교정 번호)
  final String worker;
  final String memo;
  final double lrv;
  final double urv;
  final String unit;
  final Transfer transfer;
  final ReadKind kind;
  final double? tolPct;
  final List<CalEntry> found; // 조정 전
  final List<CalEntry> left; // 조정 후(조정 안 했으면 비어 있음)

  const CalRecord({
    required this.id,
    required this.date,
    required this.tag,
    this.instrument = '',
    this.model = '',
    this.refStd = '',
    this.worker = '',
    this.memo = '',
    required this.lrv,
    required this.urv,
    this.unit = '',
    this.transfer = Transfer.linear,
    this.kind = ReadKind.ma,
    this.tolPct,
    required this.found,
    this.left = const [],
  });

  CalSummary summaryOf(List<CalEntry> e) => evaluateCal(
    entries: e,
    lrv: lrv,
    urv: urv,
    transfer: transfer,
    kind: kind,
    tolPct: tolPct,
  );
  CalSummary get foundSummary => summaryOf(found);
  CalSummary get leftSummary => summaryOf(left);

  /// 조정 후를 쟀는지.
  bool get adjusted => !leftSummary.isEmpty;

  /// 최종 판정: 조정 후가 있으면 조정 후, 없으면 조정 전.
  bool? get finalPass => adjusted ? leftSummary.pass : foundSummary.pass;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'tag': tag,
    'instrument': instrument,
    'model': model,
    'refStd': refStd,
    'worker': worker,
    'memo': memo,
    'lrv': lrv,
    'urv': urv,
    'unit': unit,
    'transfer': transfer.name,
    'kind': kind.name,
    'tol': tolPct,
    'found': [for (final e in found) e.toJson()],
    'left': [for (final e in left) e.toJson()],
  };

  factory CalRecord.fromJson(Map<String, dynamic> j) => CalRecord(
    id: j['id'] as String,
    date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime(2000),
    tag: j['tag'] as String? ?? '',
    instrument: j['instrument'] as String? ?? '',
    model: j['model'] as String? ?? '',
    refStd: j['refStd'] as String? ?? '',
    worker: j['worker'] as String? ?? '',
    memo: j['memo'] as String? ?? '',
    lrv: (j['lrv'] as num).toDouble(),
    urv: (j['urv'] as num).toDouble(),
    unit: j['unit'] as String? ?? '',
    transfer: Transfer.values.firstWhere(
      (t) => t.name == j['transfer'],
      orElse: () => Transfer.linear,
    ),
    kind: ReadKind.values.firstWhere(
      (k) => k.name == j['kind'],
      orElse: () => ReadKind.ma,
    ),
    tolPct: (j['tol'] as num?)?.toDouble(),
    found: [
      for (final e in (j['found'] as List? ?? const []))
        CalEntry.fromJson(Map<String, dynamic>.from(e as Map)),
    ],
    left: [
      for (final e in (j['left'] as List? ?? const []))
        CalEntry.fromJson(Map<String, dynamic>.from(e as Map)),
    ],
  );
}

/// 폰에 저장(SharedPreferences, JSON 목록). 최근 것이 앞.
class CalRecordStore {
  static const String key = 'signal_cal_records_v1';
  static const String lastWorkerKey = 'signal_cal_last_worker';
  static const String lastRefKey = 'signal_cal_last_ref';

  static Future<List<CalRecord>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      final out = <CalRecord>[];
      for (final e in list) {
        try {
          out.add(CalRecord.fromJson(Map<String, dynamic>.from(e as Map)));
        } catch (_) {
          // 망가진 한 건은 건너뛴다
        }
      }
      out.sort((a, b) => b.date.compareTo(a.date));
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _write(List<CalRecord> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode([for (final r in list) r.toJson()]));
  }

  /// 같은 id가 있으면 바꾸고, 없으면 더한다.
  static Future<void> put(CalRecord r) async {
    final list = await load();
    final i = list.indexWhere((e) => e.id == r.id);
    if (i >= 0) {
      list[i] = r;
    } else {
      list.add(r);
    }
    await _write(list);
    final p = await SharedPreferences.getInstance();
    await p.setString(lastWorkerKey, r.worker);
    await p.setString(lastRefKey, r.refStd);
  }

  static Future<void> delete(String id) async {
    final list = await load();
    list.removeWhere((e) => e.id == id);
    await _write(list);
  }

  /// 저장 창에 미리 채울 작업자·기준기(마지막에 쓴 것, 작업자는 없으면 앱 사용자 이름).
  static Future<(String, String)> lastWorkerAndRef() async {
    final p = await SharedPreferences.getInstance();
    final w = p.getString(lastWorkerKey);
    return (
      (w == null || w.isEmpty ? p.getString('user_real_name') ?? '' : w).trim(),
      (p.getString(lastRefKey) ?? '').trim(),
    );
  }
}
