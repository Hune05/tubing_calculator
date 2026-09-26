// 4-20mA 교정 기록(폰에만 저장). 한 계기의 조정 전·조정 후 다섯 점과 계기·표준기·작업자 정보.
// 성적서 PDF는 cal_record_pdf.dart. 계산은 signal_calc.dart의 checkPoint를 그대로 쓴다.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'signal_calc.dart';

/// 교정 측정점: 0·25·50·75·100%.
const List<double> kCalPoints = [0, 25, 50, 75, 100];

/// 출력 특성 이름(화면·성적서·CSV 공통).
String transferLabel(Transfer t) => switch (t) {
  Transfer.linear => '선형',
  Transfer.sqrt => '제곱근(DCS 연산)',
  Transfer.sqrtOut => '제곱근(전송기 출력)',
};

/// 측정 방법 이름(화면·성적서·CSV 공통).
String kindLabel(ReadKind k) => switch (k) {
  ReadKind.ma => '전송기 출력(mA)',
  ReadKind.pv => '루프 지시값',
  ReadKind.maIn => 'mA 입력 → 지시값',
};

/// 한 점의 입력값(비우면 측정점 값)과 측정값(비우면 이 점은 측정하지 않음).
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
  final List<CalPoint?> points; // 측정점마다(측정값이 없으면 null)
  final double? tolPct; // 허용오차(0 이하·없음은 null)
  const CalSummary(this.points, [this.tolPct]);

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

  /// 허용오차를 초과한 점.
  List<int> get failed => [
    for (final m in measured)
      if (m.$2.pass == false) m.$1,
  ];

  /// 합격이지만 조정 한계(허용오차의 50%)를 넘은 점. Beamex 권장값.
  List<int> get adjustAdvised {
    final t = tolPct;
    if (t == null) return const [];
    return [
      for (final m in measured)
        if (m.$2.pass == true && m.$2.errPct.abs() > t / 2 + 1e-9) m.$1,
    ];
  }

  /// 판정: 측정값이 없거나 허용오차가 없으면 null.
  bool? get pass {
    final m = measured;
    if (m.isEmpty || m.first.$2.pass == null) return null;
    return failed.isEmpty;
  }
}

/// 다섯 점을 계산한다. 입력값이 비었으면 측정점 값.
CalSummary evaluateCal({
  required List<CalEntry> entries,
  required double lrv,
  required double urv,
  required Transfer transfer,
  required ReadKind kind,
  double? tolPct,
}) {
  final tol = tolPct != null && tolPct > 0 ? tolPct : null;
  return CalSummary([
    for (var i = 0; i < kCalPoints.length; i++)
      if (i >= entries.length || entries[i].reading == null)
        null
      else
        checkPoint(
          applied:
              entries[i].applied ?? nominalInput(kCalPoints[i], kind, lrv, urv),
          reading: entries[i].reading!,
          kind: kind,
          lrv: lrv,
          urv: urv,
          transfer: transfer,
          tolPct: tol,
        ),
  ], tol);
}

class CalRecord {
  final String id;
  final DateTime date; // 교정일
  final DateTime? nextDue; // 차기 교정일
  final String tag; // 태그 번호(PT-101 등)
  final String instrument; // 계기·용도
  final String model; // 제조사·모델
  final String refStd; // 표준기(모델·일련번호·교정 유효일)
  final String worker;
  final String ambient; // 주위 조건(온도·습도)
  final String memo;
  final double lrv;
  final double urv;
  final String unit;
  final Transfer transfer;
  final ReadKind kind;
  final double? tolPct;
  final List<CalEntry> found; // 조정 전
  final List<CalEntry> left; // 조정 후(조정하지 않았으면 비어 있음)

  const CalRecord({
    required this.id,
    required this.date,
    this.nextDue,
    required this.tag,
    this.instrument = '',
    this.model = '',
    this.refStd = '',
    this.worker = '',
    this.ambient = '',
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

  /// 조정 후를 측정했는지.
  bool get adjusted => !leftSummary.isEmpty;

  /// 최종 판정: 조정 후가 있으면 조정 후, 없으면 조정 전.
  bool? get finalPass => adjusted ? leftSummary.pass : foundSummary.pass;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'nextDue': nextDue?.toIso8601String(),
    'tag': tag,
    'instrument': instrument,
    'model': model,
    'refStd': refStd,
    'worker': worker,
    'ambient': ambient,
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
    nextDue: DateTime.tryParse(j['nextDue'] as String? ?? ''),
    tag: j['tag'] as String? ?? '',
    instrument: j['instrument'] as String? ?? '',
    model: j['model'] as String? ?? '',
    refStd: j['refStd'] as String? ?? '',
    worker: j['worker'] as String? ?? '',
    ambient: j['ambient'] as String? ?? '',
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

/// 판정 글: 합격 / 불합격 / 판정 없음.
String calVerdictText(bool? pass) =>
    pass == null ? '판정 없음' : (pass ? '합격' : '불합격');

String calDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _num(double? v) {
  if (v == null || v.isNaN) return '';
  var s = (v + (v >= 0 ? 1e-9 : -1e-9)).toStringAsFixed(4);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s == '-0' ? '0' : s;
}

String _csvCell(String s) =>
    s.contains(RegExp(r'[",\n\r]')) ? '"${s.replaceAll('"', '""')}"' : s;

/// 엑셀에서 바로 여는 CSV(UTF-8 BOM). 한 기록이 한 줄, 측정점마다 입력값·측정값·오차 % 칸.
String calRecordsCsv(List<CalRecord> records) {
  final head = <String>[
    '태그 번호',
    '계기',
    '제조사·모델',
    '교정일',
    '차기 교정일',
    '0% 값',
    '100% 값',
    '단위',
    '출력 특성',
    '측정 방법',
    '허용오차(±%)',
    '조정 전 최대 오차(%)',
    '조정 전 판정',
    '조정 후 최대 오차(%)',
    '조정 후 판정',
    '최종 판정',
    '표준기',
    '작업자',
    '주위 조건',
    '메모',
    for (final ph in ['조정 전', '조정 후'])
      for (final p in kCalPoints) ...[
        '$ph ${_num(p)}% 입력값',
        '$ph ${_num(p)}% 측정값',
        '$ph ${_num(p)}% 오차(%)',
      ],
  ];
  final rows = <List<String>>[head];
  for (final r in records) {
    final f = r.foundSummary, l = r.leftSummary;
    List<String> phase(List<CalEntry> e, CalSummary s) => [
      for (var i = 0; i < kCalPoints.length; i++) ...[
        _num(
          i < e.length && e[i].applied != null
              ? e[i].applied
              : (s.points[i] == null
                    ? null
                    : nominalInput(kCalPoints[i], r.kind, r.lrv, r.urv)),
        ),
        _num(i < e.length ? e[i].reading : null),
        _num(s.points[i]?.errPct),
      ],
    ];
    rows.add([
      r.tag,
      r.instrument,
      r.model,
      calDay(r.date),
      r.nextDue == null ? '' : calDay(r.nextDue!),
      _num(r.lrv),
      _num(r.urv),
      r.unit,
      transferLabel(r.transfer),
      kindLabel(r.kind),
      _num(r.tolPct),
      _num(f.worst?.$2.errPct),
      f.isEmpty ? '' : calVerdictText(f.pass),
      _num(l.worst?.$2.errPct),
      l.isEmpty ? '' : calVerdictText(l.pass),
      calVerdictText(r.finalPass),
      r.refStd,
      r.worker,
      r.ambient,
      r.memo,
      ...phase(r.found, f),
      ...phase(r.left, l),
    ]);
  }
  return '﻿${rows.map((c) => c.map(_csvCell).join(',')).join('\r\n')}\r\n';
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

  /// 저장 창에 미리 채울 작업자·표준기(마지막에 쓴 것, 작업자는 없으면 앱 사용자 이름).
  static Future<(String, String)> lastWorkerAndRef() async {
    final p = await SharedPreferences.getInstance();
    final w = p.getString(lastWorkerKey);
    return (
      (w == null || w.isEmpty ? p.getString('user_real_name') ?? '' : w).trim(),
      (p.getString(lastRefKey) ?? '').trim(),
    );
  }
}
