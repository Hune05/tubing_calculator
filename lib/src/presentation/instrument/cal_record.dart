// 4-20mA 교정 기록(폰에 저장하고 서버에도 올림, record_sync.dart). 한 계기의 조정 전·조정 후 시험점(상승·하강)과 계기·표준기·작업자 정보.
// 스위치 시험 기록('type': 'switch')은 스위치 설정과 반복 측정값(switch_check.dart)을 담는다.
// 성적서 PDF는 cal_record_pdf.dart. 계산은 signal_calc.dart의 checkPoint를 그대로 쓴다.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/record_sync.dart';
import 'signal_calc.dart';
import 'switch_check.dart';
import 'temp_sensor.dart';

/// 교정 측정점: 0·25·50·75·100%.
const List<double> kCalPoints = [0, 25, 50, 75, 100];

/// 시험점 하나: 측정 범위 %와 방향(상승·하강).
class CalPointDef {
  final double pct;
  final bool down;
  const CalPointDef(this.pct, {this.down = false});

  Map<String, dynamic> toJson() => {'p': pct, if (down) 'dn': true};
  factory CalPointDef.fromJson(Map<String, dynamic> j) =>
      CalPointDef((j['p'] as num).toDouble(), down: j['dn'] == true);

  @override
  bool operator ==(Object other) =>
      other is CalPointDef && other.pct == pct && other.down == down;

  @override
  int get hashCode => Object.hash(pct, down);
}

/// 시험점 묶음: 3점·5점·11점.
enum CalPointSet { p3, p5, p11 }

List<double> calSetPcts(CalPointSet s) => switch (s) {
  CalPointSet.p3 => const [0, 50, 100],
  CalPointSet.p5 => kCalPoints,
  CalPointSet.p11 => const [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100],
};

/// 시험점 묶음 이름(화면).
String calSetLabel(CalPointSet s) => switch (s) {
  CalPointSet.p3 => '3점(0·50·100)',
  CalPointSet.p5 => '5점(0·25·50·75·100)',
  CalPointSet.p11 => '11점(0·10·…·100)',
};

/// 시험점 목록. [withDown]이면 맨 위 점에서 되돌아 내려오는 하강 점을 붙인다.
/// 예: 5점 + 하강 = 0·25·50·75·100·75·50·25·0(아홉 점).
List<CalPointDef> calPointList(CalPointSet s, {bool withDown = false}) {
  final up = [for (final p in calSetPcts(s)) CalPointDef(p)];
  if (!withDown) return up;
  return [
    ...up,
    for (var i = up.length - 2; i >= 0; i--) CalPointDef(up[i].pct, down: true),
  ];
}

/// 시험점이 가장 많을 때의 줄 수(11점 + 하강 10점).
const int kMaxCalRows = 21;

/// 기본값이자 예전 기록(시험점 칸 없음)의 시험점: 5점 상승만.
const List<CalPointDef> kDefaultCalPoints = [
  CalPointDef(0),
  CalPointDef(25),
  CalPointDef(50),
  CalPointDef(75),
  CalPointDef(100),
];

/// 목록에 하강 점이 있는지.
bool calHasDown(List<CalPointDef> defs) => defs.any((d) => d.down);

/// 목록이 어느 묶음인지. 묶음과 다르면 null.
(CalPointSet, bool)? calSetOf(List<CalPointDef> defs) {
  bool same(List<CalPointDef> a) {
    if (a.length != defs.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != defs[i]) return false;
    }
    return true;
  }

  for (final s in CalPointSet.values) {
    for (final d in const [false, true]) {
      if (same(calPointList(s, withDown: d))) return (s, d);
    }
  }
  return null;
}

/// 점 이름: 하강이 없으면 "50%", 있으면 "상승 50%"·"하강 50%".
String calPointLabel(List<CalPointDef> defs, int i) {
  final d = defs[i];
  final p = '${_num(d.pct)}%';
  if (!calHasDown(defs)) return p;
  return '${d.down ? '하강' : '상승'} $p';
}

/// 시험점 요약: "5점", "5점 상승·하강".
String calPointsText(List<CalPointDef> defs) {
  final up = defs.where((d) => !d.down).length;
  return '$up점${calHasDown(defs) ? ' 상승·하강' : ''}';
}

/// 성적서·CSV의 센서 글: "Pt100 (IEC 60751)", "K형 (IEC 60584-1), 냉접점 20 °C".
String calSensorText(TempSensor? s, double? cjC) {
  if (s == null) return '';
  final base = '${s.label} (${s.standard})';
  if (s.isRtd) return base;
  return '$base, 냉접점 ${_num(cjC ?? 0)} °C';
}

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
  final List<CalPointDef> defs; // 시험점(points와 같은 순서)
  final List<double?> hyst; // 하강 점의 히스테리시스(스팬 %). 상승 점·짝이 없으면 null
  final double? hystTolPct; // 히스테리시스 허용값(0 이하·없음은 null)
  const CalSummary(
    this.points, {
    this.tolPct,
    this.defs = kDefaultCalPoints,
    this.hyst = const [],
    this.hystTolPct,
  });

  double? hystAt(int i) => i < hyst.length ? hyst[i] : null;

  /// 히스테리시스 판정: 허용값을 넣었고 상승·하강 짝이 있을 때만.
  bool? hystPass(int i) {
    final h = hystAt(i), t = hystTolPct;
    if (h == null || t == null) return null;
    return h <= t + 1e-9;
  }

  /// 한 점의 판정: 오차(허용오차)와 히스테리시스(허용값). 둘 다 판정하지 않으면 null.
  bool? rowPass(int i) {
    final p = points[i];
    if (p == null) return null;
    final a = p.pass, b = hystPass(i);
    if (a == null && b == null) return null;
    return (a ?? true) && (b ?? true);
  }

  /// 히스테리시스가 가장 큰 하강 점(없으면 null).
  (int, double)? get maxHyst {
    (int, double)? m;
    for (var i = 0; i < hyst.length; i++) {
      final h = hyst[i];
      if (h != null && (m == null || h > m.$2)) m = (i, h);
    }
    return m;
  }

  /// 히스테리시스 허용값을 넘은 점.
  List<int> get hystFailed => [
    for (final m in measured)
      if (hystPass(m.$1) == false) m.$1,
  ];

  /// 허용오차를 넘은 점.
  List<int> get errFailed => [
    for (final m in measured)
      if (m.$2.pass == false) m.$1,
  ];

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

  /// 불합격 점: 허용오차 초과 또는 히스테리시스 허용값 초과.
  List<int> get failed => [
    for (final m in measured)
      if (rowPass(m.$1) == false) m.$1,
  ];

  /// 합격이지만 조정 한계(허용오차의 50%)를 넘은 점. Beamex 권장값.
  List<int> get adjustAdvised {
    final t = tolPct;
    if (t == null) return const [];
    return [
      for (final m in measured)
        if (m.$2.pass == true &&
            rowPass(m.$1) != false &&
            m.$2.errPct.abs() > t / 2 + 1e-9)
          m.$1,
    ];
  }

  /// 판정: 측정값이 없거나 판정한 점이 없으면(허용오차·히스테리시스 허용값 없음) null.
  bool? get pass {
    final m = measured;
    if (m.isEmpty || !m.any((e) => rowPass(e.$1) != null)) return null;
    return failed.isEmpty;
  }
}

/// 시험점마다 계산한다. 입력값이 비었으면 측정점 값.
/// 히스테리시스 = |같은 %의 상승 오차 % − 하강 오차 %|(스팬 %). 하강 점에 적는다.
CalSummary evaluateCal({
  required List<CalEntry> entries,
  required double lrv,
  required double urv,
  required Transfer transfer,
  required ReadKind kind,
  double? tolPct,
  List<CalPointDef> points = kDefaultCalPoints,
  double? hystTolPct,
}) {
  final tol = tolPct != null && tolPct > 0 ? tolPct : null;
  final pts = <CalPoint?>[
    for (var i = 0; i < points.length; i++)
      if (i >= entries.length || entries[i].reading == null)
        null
      else
        checkPoint(
          applied:
              entries[i].applied ?? nominalInput(points[i].pct, kind, lrv, urv),
          reading: entries[i].reading!,
          kind: kind,
          lrv: lrv,
          urv: urv,
          transfer: transfer,
          tolPct: tol,
        ),
  ];
  double? hystOf(int i) {
    final d = points[i], p = pts[i];
    if (!d.down || p == null) return null;
    final j = points.indexOf(CalPointDef(d.pct));
    if (j < 0 || pts[j] == null) return null;
    return (pts[j]!.errPct - p.errPct).abs();
  }

  return CalSummary(
    pts,
    tolPct: tol,
    defs: points,
    hyst: [for (var i = 0; i < points.length; i++) hystOf(i)],
    hystTolPct: hystTolPct != null && hystTolPct > 0 ? hystTolPct : null,
  );
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
  final List<CalPointDef> points; // 시험점(found·left와 같은 순서). 예전 기록은 5점 상승
  final double? hystTolPct; // 히스테리시스 허용값(스팬 %)
  final TempSensor? sensor; // 온도 센서(측정 범위가 °C일 때만)
  final double? cjC; // 열전대 냉접점 온도(°C)
  // 스위치 시험 기록이면 설정과 반복 측정값(조정 전·후). 전송기 기록(예전 기록 포함)은 null·빈 목록.
  // 스위치 기록의 lrv·urv는 측정 범위(같으면 범위 없음), found·left·points는 쓰지 않는다.
  final SwitchSpec? sw;
  final List<SwitchRepeat> swFound;
  final List<SwitchRepeat> swLeft;

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
    this.points = kDefaultCalPoints,
    this.hystTolPct,
    this.sensor,
    this.cjC,
    this.sw,
    this.swFound = const [],
    this.swLeft = const [],
  });

  /// 스위치 시험 기록인지.
  bool get isSwitch => sw != null;

  /// 스위치 기록의 측정 범위(0%·100% 값이 같으면 없음).
  (double, double)? get switchRange => lrv == urv ? null : (lrv, urv);

  SwitchSummary switchSummaryOf(List<SwitchRepeat> e) =>
      evaluateSwitch(spec: sw!, repeats: e, range: switchRange);
  SwitchSummary get swFoundSummary => switchSummaryOf(swFound);
  SwitchSummary get swLeftSummary => switchSummaryOf(swLeft);

  /// 조정 전 판정(전송기·스위치 공통).
  bool? get foundPass => isSwitch ? swFoundSummary.pass : foundSummary.pass;

  /// 조정 후 판정(전송기·스위치 공통).
  bool? get leftPass => isSwitch ? swLeftSummary.pass : leftSummary.pass;

  CalSummary summaryOf(List<CalEntry> e) => evaluateCal(
    entries: e,
    lrv: lrv,
    urv: urv,
    transfer: transfer,
    kind: kind,
    tolPct: tolPct,
    points: points,
    hystTolPct: hystTolPct,
  );
  CalSummary get foundSummary => summaryOf(found);
  CalSummary get leftSummary => summaryOf(left);

  /// 조정 후를 측정했는지.
  bool get adjusted => isSwitch ? !swLeftSummary.isEmpty : !leftSummary.isEmpty;

  /// 최종 판정: 조정 후가 있으면 조정 후, 없으면 조정 전.
  bool? get finalPass => adjusted ? leftPass : foundPass;

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
    'pts': [for (final p in points) p.toJson()],
    'hystTol': hystTolPct,
    'sensor': sensor?.name,
    'cj': cjC,
    if (sw != null) ...{
      'type': 'switch',
      'sw': sw!.toJson(),
      'swFound': [for (final e in swFound) e.toJson()],
      'swLeft': [for (final e in swLeft) e.toJson()],
    },
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
    points: _pointsFromJson(j['pts']),
    hystTolPct: (j['hystTol'] as num?)?.toDouble(),
    sensor: TempSensor.values.where((s) => s.name == j['sensor']).firstOrNull,
    cjC: (j['cj'] as num?)?.toDouble(),
    // 'type' 칸이 없으면(예전 기록) 전송기 기록.
    sw: j['type'] == 'switch' && j['sw'] is Map
        ? SwitchSpec.fromJson(Map<String, dynamic>.from(j['sw'] as Map))
        : null,
    swFound: _repeatsFromJson(j['swFound']),
    swLeft: _repeatsFromJson(j['swLeft']),
  );
}

List<SwitchRepeat> _repeatsFromJson(Object? v) => [
  if (v is List)
    for (final e in v)
      SwitchRepeat.fromJson(Map<String, dynamic>.from(e as Map)),
];

/// 시험점 칸이 없거나 비었으면(예전 기록) 5점 상승.
List<CalPointDef> _pointsFromJson(Object? v) {
  if (v is! List || v.isEmpty) return kDefaultCalPoints;
  return [
    for (final e in v)
      CalPointDef.fromJson(Map<String, dynamic>.from(e as Map)),
  ];
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

String _csv(List<List<String>> rows) =>
    '﻿${rows.map((c) => c.map(_csvCell).join(',')).join('\r\n')}\r\n';

/// 엑셀에서 바로 여는 요약 CSV(UTF-8 BOM). 한 기록이 한 줄.
/// 앞쪽 칸은 예전 모양 그대로(0·25·50·75·100% 상승 점의 입력값·측정값·오차 %, 그 점이 시험점에 없으면 빈 칸)이고,
/// 뒤에 시험점·히스테리시스·센서 칸을 붙였다. 모든 점(하강 포함)은 [calPointsCsv]에 있다.
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
    '시험점',
    '히스테리시스 허용값(%)',
    '조정 전 최대 히스테리시스(%)',
    '조정 후 최대 히스테리시스(%)',
    '센서',
    // 스위치 시험 칸(2026-09-26 추가). 전송기 기록은 시험 종류만 채운다.
    '시험 종류',
    '동작 방향',
    '동작점 설정값',
    '복귀점 설정값',
    '데드밴드 설정값',
    '스위치 허용오차(±단위)',
    '데드밴드 허용 범위',
    '접점',
    '조정 전 최대 동작점 오차',
    '조정 전 반복성',
    '조정 후 최대 동작점 오차',
    '조정 후 반복성',
  ];
  final rows = <List<String>>[head];
  for (final r in records) {
    if (r.isSwitch) {
      rows.add(_switchSummaryRow(r));
      continue;
    }
    final f = r.foundSummary, l = r.leftSummary;
    List<String> phase(List<CalEntry> e, CalSummary s) {
      final out = <String>[];
      for (final p in kCalPoints) {
        final i = r.points.indexOf(CalPointDef(p));
        if (i < 0) {
          out.addAll(const ['', '', '']);
          continue;
        }
        out.addAll([
          _num(
            i < e.length && e[i].applied != null
                ? e[i].applied
                : (s.points[i] == null
                      ? null
                      : nominalInput(p, r.kind, r.lrv, r.urv)),
          ),
          _num(i < e.length ? e[i].reading : null),
          _num(s.points[i]?.errPct),
        ]);
      }
      return out;
    }

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
      calPointsText(r.points),
      _num(r.hystTolPct),
      _num(f.maxHyst?.$2),
      _num(l.maxHyst?.$2),
      calSensorText(r.sensor, r.cjC),
      '전송기',
      for (var i = 0; i < 11; i++) '',
    ]);
  }
  return _csv(rows);
}

/// 요약 CSV의 스위치 기록 한 줄. 전송기 칸 중 뜻이 같은 칸(범위·단위·허용오차 %·최대 오차 %·판정·정보)만 채운다.
List<String> _switchSummaryRow(CalRecord r) {
  final sp = r.sw!;
  final range = r.switchRange;
  final f = r.swFoundSummary, l = r.swLeftSummary;
  return [
    r.tag,
    r.instrument,
    r.model,
    calDay(r.date),
    r.nextDue == null ? '' : calDay(r.nextDue!),
    range == null ? '' : _num(r.lrv),
    range == null ? '' : _num(r.urv),
    r.unit,
    '',
    '스위치 시험',
    sp.tolMode == SwitchTolMode.pct ? _num(sp.tol) : '',
    _num(f.worst?.$2.errPct),
    f.isEmpty ? '' : calVerdictText(f.pass),
    _num(l.worst?.$2.errPct),
    l.isEmpty ? '' : calVerdictText(l.pass),
    calVerdictText(r.finalPass),
    r.refStd,
    r.worker,
    r.ambient,
    r.memo,
    for (var i = 0; i < 2 * kCalPoints.length * 3; i++) '',
    '반복 ${(f.isEmpty ? l : f).measured.length}회',
    '',
    '',
    '',
    calSensorText(r.sensor, r.cjC),
    '스위치',
    switchDirLabel(sp.dir),
    _num(sp.setpoint),
    _num(sp.resetSet),
    _num(sp.dbSet),
    _num(f.tolUnit ?? l.tolUnit),
    switchDbRangeText(sp),
    sp.contact == null ? '' : switchContactLabel(sp.contact!),
    _num(f.worst?.$2.err),
    _num(f.repeatability),
    _num(l.worst?.$2.err),
    _num(l.repeatability),
  ];
}

/// 측정점 CSV(UTF-8 BOM). 측정한 점마다 한 줄: 기록·구분(조정 전·후)·방향(상승·하강)·측정점.
/// 시험점 수가 기록마다 달라도 칸이 같아 엑셀에서 거르고 모으기 쉽다.
/// 스위치 기록은 반복마다 한 줄(시험 종류 "스위치", 뒤쪽 칸에 반복·복귀점·데드밴드·오차).
String calPointsCsv(List<CalRecord> records) {
  final rows = <List<String>>[
    [
      '태그 번호',
      '교정일',
      '구분',
      '방향',
      '측정점(%)',
      '입력값',
      '입력 단위',
      '이론값',
      '측정값·지시값',
      '측정 단위',
      '오차(%)',
      '히스테리시스(%)',
      '판정',
      '측정 방법',
      // 스위치 시험 칸(2026-09-26 추가)
      '시험 종류',
      '반복',
      '복귀점',
      '데드밴드',
      '동작점 오차',
      '복귀 오차',
    ],
  ];
  for (final r in records) {
    if (r.isSwitch) {
      rows.addAll(_switchPointRows(r));
      continue;
    }
    final inUnit = r.kind == ReadKind.maIn ? 'mA' : r.unit;
    final outUnit = r.kind == ReadKind.ma ? 'mA' : r.unit;
    for (final (ph, e) in [('조정 전', r.found), ('조정 후', r.left)]) {
      final s = r.summaryOf(e);
      for (final (i, p) in s.measured) {
        final v = s.rowPass(i);
        rows.add([
          r.tag,
          calDay(r.date),
          ph,
          r.points[i].down ? '하강' : '상승',
          _num(r.points[i].pct),
          _num(p.applied),
          inUnit,
          _num(p.expected),
          _num(p.reading),
          outUnit,
          _num(p.errPct),
          _num(s.hystAt(i)),
          v == null ? '' : calVerdictText(v),
          kindLabel(r.kind),
          '전송기',
          '',
          '',
          '',
          '',
          '',
        ]);
      }
    }
  }
  return _csv(rows);
}

/// 측정점 CSV의 스위치 기록 줄: 반복마다 한 줄. 이론값 = 동작점 설정값, 측정값 = 측정한 동작점,
/// 측정점(%) = 동작점 설정값의 범위 %(범위가 없으면 빈 칸), 방향 = 상승 동작·하강 동작.
List<List<String>> _switchPointRows(CalRecord r) {
  final sp = r.sw!;
  final range = r.switchRange;
  final out = <List<String>>[];
  for (final (ph, e) in [('조정 전', r.swFound), ('조정 후', r.swLeft)]) {
    final s = r.switchSummaryOf(e);
    for (final (i, row) in s.measured) {
      final v = row.pass;
      out.add([
        r.tag,
        calDay(r.date),
        ph,
        switchDirLabel(sp.dir),
        range == null ? '' : _num(pvToPct(sp.setpoint, range.$1, range.$2)),
        '',
        r.unit,
        _num(sp.setpoint),
        _num(row.trip),
        r.unit,
        _num(row.errPct),
        '',
        v == null ? '' : calVerdictText(v),
        '스위치 시험',
        '스위치',
        '${i + 1}',
        _num(row.reset),
        _num(row.deadband),
        _num(row.err),
        _num(row.resetErr),
      ]);
    }
  }
  return out;
}

/// 폰에 저장(SharedPreferences, JSON 목록). 최근 것이 앞.
/// 저장·지우기는 서버(Firestore)에도 올린다(기다리지 않음). 목록 화면을 열면 서버 것과 합친다.
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
    await sync.saved(r.id);
    final p = await SharedPreferences.getInstance();
    await p.setString(lastWorkerKey, r.worker);
    await p.setString(lastRefKey, r.refStd);
  }

  static Future<void> delete(String id) async {
    final list = await load();
    list.removeWhere((e) => e.id == id);
    await _write(list);
    await sync.removed(id);
  }

  /// 서버에서 받은 JSON을 읽을 수 있는지.
  static bool _readable(Map<String, dynamic> j) {
    try {
      CalRecord.fromJson(j);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 서버 올리기·받기(모음 calibration_records, 주인 = 앱 사용자 이름). record_sync.dart.
  static final RecordSync sync = RecordSync(
    key: key,
    collection: 'calibration_records',
    isValid: _readable,
  );

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
