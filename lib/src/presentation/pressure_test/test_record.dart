// 배관 압력시험 기록(폰에 저장하고 서버에도 올림, record_sync.dart). 시험 정보(튜브면 튜브 규격)·유지시간(시작·종료 시각)·측정 기록·압력계·안전밸브·입회자와 판정.
// 기록서 PDF는 test_record_pdf.dart, 목록은 test_records_page.dart.
// 판정은 judgePressureTest 하나로 화면·기록서·CSV가 같이 쓴다. 근거는 docs/압력시험계산기_근거.md.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/record_sync.dart';
import 'pressure_calc.dart';
import 'pressure_units.dart';

String ptCodeLabel(PipingCode c) =>
    c == PipingCode.b313 ? 'B31.3 공정 배관' : 'B31.1 동력 배관';
String ptCodeShort(PipingCode c) => c == PipingCode.b313 ? 'B31.3' : 'B31.1';
String ptMediumLabel(TestMedium m) => m == TestMedium.hydro ? '수압' : '공압';

/// 시험유체.
enum PtFluid { water, air, nitrogen, other }

String ptFluidLabel(PtFluid f) => switch (f) {
  PtFluid.water => '물',
  PtFluid.air => '공기',
  PtFluid.nitrogen => '질소',
  PtFluid.other => '기타',
};

/// 시험 종류에 맞는 기본 시험유체(수압 = 물, 공압 = 공기).
PtFluid ptDefaultFluid(TestMedium m) =>
    m == TestMedium.hydro ? PtFluid.water : PtFluid.air;

/// 측정 구분: 시작·중간 측정·종료.
enum PtReadKind { start, mid, end }

String ptReadKindLabel(PtReadKind k) => switch (k) {
  PtReadKind.start => '시작',
  PtReadKind.mid => '측정',
  PtReadKind.end => '종료',
};

String _two(int v) => v.toString().padLeft(2, '0');

/// 2026-09-26
String ptDay(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// 09:05
String ptHm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// 09:05:30
String ptHms(DateTime d) => '${ptHm(d)}:${_two(d.second)}';

/// 경과 시간 글: 1시간 미만은 "mm:ss", 넘으면 "h:mm:ss". 음수는 0.
String ptClock(Duration d) {
  final s = d.isNegative ? 0 : d.inSeconds;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  return h > 0 ? '$h:${_two(m)}:${_two(sec)}' : '${_two(m)}:${_two(sec)}';
}

/// 분(소수).
double ptMinutes(Duration d) => d.inMilliseconds / 60000;

/// 측정값 한 줄.
class PtReading {
  final DateTime at;
  final double kpa; // 게이지 kPa
  final double? tempC;
  final PtReadKind kind;
  const PtReading({
    required this.at,
    required this.kpa,
    this.tempC,
    this.kind = PtReadKind.mid,
  });

  PtReading withValues(double kpa, double? tempC) =>
      PtReading(at: at, kpa: kpa, tempC: tempC, kind: kind);

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'kpa': kpa,
    't': tempC,
    'k': kind.name,
  };

  /// 망가진 값이면 null.
  static PtReading? fromJson(Object? j) {
    if (j is! Map) return null;
    final at = DateTime.tryParse(j['at']?.toString() ?? '');
    final kpa = j['kpa'];
    if (at == null || kpa is! num) return null;
    final t = j['t'];
    return PtReading(
      at: at,
      kpa: kpa.toDouble(),
      tempC: t is num ? t.toDouble() : null,
      kind: PtReadKind.values.firstWhere(
        (k) => k.name == j['k'],
        orElse: () => PtReadKind.mid,
      ),
    );
  }
}

/// 압력계: 번호·눈금 범위·검교정 유효일(글 그대로).
class PtGauge {
  final String no;
  final String range;
  final String calDue;
  const PtGauge({this.no = '', this.range = '', this.calDue = ''});

  bool get isEmpty =>
      no.trim().isEmpty && range.trim().isEmpty && calDue.trim().isEmpty;

  /// "PG-01 · 0~25 bar · 유효일 2027-03-31"
  String get summary => [
    if (no.trim().isNotEmpty) no.trim(),
    if (range.trim().isNotEmpty) range.trim(),
    if (calDue.trim().isNotEmpty) '유효일 ${calDue.trim()}',
  ].join(' · ');

  Map<String, dynamic> toJson() => {'no': no, 'range': range, 'due': calDue};

  static PtGauge fromJson(Object? j) => j is Map
      ? PtGauge(
          no: j['no']?.toString() ?? '',
          range: j['range']?.toString() ?? '',
          calDue: j['due']?.toString() ?? '',
        )
      : const PtGauge();
}

/// 판정 결과. 화면·기록서·CSV가 같이 쓴다.
class PtVerdict {
  final TestMedium medium;
  final bool started;
  final bool ended;
  final double? elapsedMin; // 종료했을 때만
  final double requiredMin; // 규정 유지시간(분)
  final double? rawDropKpa; // 시작 − 종료(게이지 측정값)
  final double? correctedDropKpa; // 공압, 시작·종료 온도가 있을 때 P₂·T₁/T₂ 보정
  final double? hydroTempKpa; // 수압, 물 온도 변화만으로 바뀌는 압력(추정)
  final double? hydroDeltaC; // 수압, 물 온도 변화
  final double? allowKpa;
  final bool leakOk;

  const PtVerdict({
    required this.medium,
    required this.started,
    required this.ended,
    required this.elapsedMin,
    required this.requiredMin,
    this.rawDropKpa,
    this.correctedDropKpa,
    this.hydroTempKpa,
    this.hydroDeltaC,
    this.allowKpa,
    required this.leakOk,
  });

  bool get tempCorrected => correctedDropKpa != null;

  /// 판정에 쓰는 압력강하: 공압은 온도 보정 값(온도가 없으면 측정값), 수압은 측정값.
  double? get judgedDropKpa => correctedDropKpa ?? rawDropKpa;

  bool get holdMet => elapsedMin != null && elapsedMin! >= requiredMin - 1e-9;

  /// 허용 압력강하 이내인지. 허용값이나 종료 압력이 없으면 null.
  bool? get dropOk => allowKpa == null || judgedDropKpa == null
      ? null
      : judgedDropKpa! <= allowKpa! + 1e-9;

  /// 합격(true)·불합격(false)·판정 없음(null).
  /// 종료해야 판정한다. 유지시간 미만이거나 허용 압력강하 초과면 불합격.
  /// 누설·물맺힘 없음을 확인하지 않았으면 합격으로 하지 않는다(판정 없음).
  bool? get pass {
    if (!started || !ended) return null;
    if (!holdMet || dropOk == false) return false;
    if (!leakOk) return null;
    return true;
  }

  /// 불합격·판정 없음의 이유(합격이면 빈 목록).
  List<String> reasons(PUnit u) {
    if (!started) return const ['시작하지 않았습니다.'];
    if (!ended) return const ['종료하지 않았습니다. 종료 압력을 기록하면 판정합니다.'];
    return [
      if (!holdMet)
        '경과 시간 ${ptFmt(elapsedMin!, 1)}분: 유지시간 ${ptFmt(requiredMin, 1)}분 미만',
      if (dropOk == false)
        '압력강하 ${ptDrop(judgedDropKpa!, u)}: 허용 압력강하 ${ptPressure(allowKpa!, u)} 초과',
      if (!leakOk) '누설·물맺힘 없음(육안 확인)을 확인하지 않았습니다.',
    ];
  }

  /// 압력강하·온도·유지시간 설명 줄.
  List<String> details(PUnit u) {
    if (!ended) return const [];
    final dT = hydroDeltaC;
    return [
      '유지시간: ${ptFmt(elapsedMin!, 1)}분 경과 (규정 ${ptFmt(requiredMin, 1)}분 이상)',
      if (rawDropKpa != null) '측정 압력강하: ${ptDrop(rawDropKpa!, u)}',
      if (correctedDropKpa != null)
        '온도 보정 후 압력강하: ${ptDrop(correctedDropKpa!, u)} (P₂·T₁/T₂, 절대압·절대 온도)',
      if (medium == TestMedium.pneumatic && correctedDropKpa == null)
        '시작·종료 온도가 없어 온도 보정을 하지 않았습니다.',
      if (medium == TestMedium.hydro) '수압은 온도 보정 없이 측정 압력강하로 판정합니다.',
      if (hydroTempKpa != null && dT != null)
        '물 온도 변화 ${dT > 0 ? '+' : ''}${ptFmt(dT, 1)}°C: 온도만으로 압력이 약 '
            '${ptPressure(hydroTempKpa!.abs(), u)} ${hydroTempKpa! < 0 ? '낮아집니다' : '높아집니다'}'
            '(추정, 공기 없는 막힌 관 기준).',
      if (allowKpa == null)
        '허용 압력강하를 넣으면 압력강하도 판정합니다.'
      else if (dropOk != null)
        '허용 압력강하 ${ptPressure(allowKpa!, u)}: ${dropOk! ? '이내' : '초과'}',
    ];
  }
}

/// 압력 시험 판정. [holdMin] 규정 유지시간(분), [allowKpa] 허용 압력강하(없으면 압력강하는 판정하지 않음).
/// 공압: 시작·종료 온도가 있으면 pressureDecay로 온도를 보정한 강하로 판정한다.
/// 수압: 측정 강하로 판정하고, 외경·두께와 온도가 있으면 물 온도 영향(hydroBarPerDegC)을 참고로 보인다.
PtVerdict judgePressureTest({
  required TestMedium medium,
  required List<PtReading> readings,
  DateTime? startAt,
  DateTime? endAt,
  required double holdMin,
  double? allowKpa,
  bool leakOk = false,
  double? odMm,
  double? wallMm,
  PipeMaterial material = PipeMaterial.carbon,
}) {
  PtReading? start, end;
  for (final r in readings) {
    if (r.kind == PtReadKind.start) start ??= r;
    if (r.kind == PtReadKind.end) end = r;
  }
  final s = startAt ?? start?.at;
  final e = end == null ? null : (endAt ?? end.at);
  final allow = allowKpa != null && allowKpa >= 0 ? allowKpa : null;
  if (s == null || start == null || end == null || e == null) {
    return PtVerdict(
      medium: medium,
      started: s != null && start != null,
      ended: false,
      elapsedMin: null,
      requiredMin: holdMin,
      allowKpa: allow,
      leakOk: leakOk,
    );
  }
  final p1 = start.kpa, p2 = end.kpa;
  final t1 = start.tempC, t2 = end.tempC;
  double? corrected, hydroKpa, hydroDt;
  if (t1 != null && t2 != null && t1 > -273.15 && t2 > -273.15) {
    if (medium == TestMedium.pneumatic) {
      corrected = pressureDecay(
        p1Kpa: p1,
        p2Kpa: p2,
        t1C: t1,
        t2C: t2,
      ).correctedDropKpa;
    } else if (t2 != t1 &&
        odMm != null &&
        wallMm != null &&
        wallMm > 0 &&
        odMm > wallMm) {
      final per = hydroBarPerDegC(
        waterC: (t1 + t2) / 2,
        odMm: odMm,
        wallMm: wallMm,
        material: material,
      );
      hydroDt = t2 - t1;
      hydroKpa = per * 100 * hydroDt;
    }
  }
  return PtVerdict(
    medium: medium,
    started: true,
    ended: true,
    elapsedMin: ptMinutes(e.difference(s)),
    requiredMin: holdMin,
    rawDropKpa: p1 - p2,
    correctedDropKpa: corrected,
    hydroTempKpa: hydroKpa,
    hydroDeltaC: hydroDt,
    allowKpa: allow,
    leakOk: leakOk,
  );
}

/// 판정 글: 합격 / 불합격 / 판정 없음.
String ptVerdictText(bool? pass) =>
    pass == null ? '판정 없음' : (pass ? '합격' : '불합격');

double? _d(Object? v) => v is num ? v.toDouble() : null;
String _s(Object? v) => v is String ? v : (v == null ? '' : v.toString());

class PtRecord {
  final String id;
  final DateTime date; // 시험일
  final String testNo; // 시험 번호(기록서 번호)
  final String site; // 현장·프로젝트
  final String system; // 계통
  final String line; // 라인 번호
  final String pid; // P&ID·아이소 번호
  final String section; // 시험 구간(From ~ To)
  final PipingCode code;
  final TestMedium medium;
  final PtFluid fluid;
  final double? designKpa;
  final double? testKpa; // 시험압력(실제 시험압력을 넣었으면 그 값, 아니면 최소 시험압력)
  final PUnit unit; // 기록서·목록에 보이는 단위
  final double holdMin; // 규정 유지시간(분)
  final DateTime? startAt;
  final DateTime? endAt;
  final List<PtReading> readings;
  final double? allowKpa;
  final bool leakOk; // 누설·물맺힘 없음(육안 확인)
  final List<PtGauge> gauges; // 0~2개
  final double? reliefKpa; // 안전밸브 설정압력
  final String reliefNo;
  final String tester;
  final String witnessContractor; // 시공사
  final String witnessSupervisor; // 감리
  final String witnessOwner; // 발주처
  final String memo;
  final double? odMm; // 수압 물 온도 영향 계산용(선택)
  final double? wallMm;
  final PipeMaterial material;
  final String tubeId; // 튜브 규격 번호(tube_rating.dart). 배관·이전 기록은 ''
  final String tubeSpec; // 튜브 규격 글(기록서·CSV에 그대로)
  final String tubeMat; // 튜브 재질(TubeMaterial 이름)

  const PtRecord({
    required this.id,
    required this.date,
    this.testNo = '',
    this.site = '',
    this.system = '',
    required this.line,
    this.pid = '',
    this.section = '',
    this.code = PipingCode.b313,
    this.medium = TestMedium.hydro,
    this.fluid = PtFluid.water,
    this.designKpa,
    this.testKpa,
    this.unit = PUnit.bar,
    this.holdMin = 10,
    this.startAt,
    this.endAt,
    this.readings = const [],
    this.allowKpa,
    this.leakOk = false,
    this.gauges = const [],
    this.reliefKpa,
    this.reliefNo = '',
    this.tester = '',
    this.witnessContractor = '',
    this.witnessSupervisor = '',
    this.witnessOwner = '',
    this.memo = '',
    this.odMm,
    this.wallMm,
    this.material = PipeMaterial.carbon,
    this.tubeId = '',
    this.tubeSpec = '',
    this.tubeMat = '',
  });

  PtVerdict get verdict => judgePressureTest(
    medium: medium,
    readings: readings,
    startAt: startAt,
    endAt: endAt,
    holdMin: holdMin,
    allowKpa: allowKpa,
    leakOk: leakOk,
    odMm: odMm,
    wallMm: wallMm,
    material: material,
  );

  PtReading? get startReading {
    for (final r in readings) {
      if (r.kind == PtReadKind.start) return r;
    }
    return null;
  }

  PtReading? get endReading {
    PtReading? e;
    for (final r in readings) {
      if (r.kind == PtReadKind.end) e = r;
    }
    return e;
  }

  /// 입회자 이름들(비지 않은 것만): "시공사 김 · 감리 이".
  String get witnessLine => [
    if (witnessContractor.trim().isNotEmpty) '시공사 ${witnessContractor.trim()}',
    if (witnessSupervisor.trim().isNotEmpty) '감리 ${witnessSupervisor.trim()}',
    if (witnessOwner.trim().isNotEmpty) '발주처 ${witnessOwner.trim()}',
  ].join(' · ');

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'testNo': testNo,
    'site': site,
    'system': system,
    'line': line,
    'pid': pid,
    'section': section,
    'code': code.name,
    'medium': medium.name,
    'fluid': fluid.name,
    'design': designKpa,
    'test': testKpa,
    'unit': unit.name,
    'hold': holdMin,
    'start': startAt?.toIso8601String(),
    'end': endAt?.toIso8601String(),
    'readings': [for (final r in readings) r.toJson()],
    'allow': allowKpa,
    'leakOk': leakOk,
    'gauges': [for (final g in gauges) g.toJson()],
    'relief': reliefKpa,
    'reliefNo': reliefNo,
    'tester': tester,
    'wC': witnessContractor,
    'wS': witnessSupervisor,
    'wO': witnessOwner,
    'memo': memo,
    'od': odMm,
    'wall': wallMm,
    'mat': material.name,
    'tubeId': tubeId,
    'tube': tubeSpec,
    'tubeMat': tubeMat,
  };

  /// 칸이 빠지거나 형식이 달라도 읽는다(없는 칸은 기본값).
  factory PtRecord.fromJson(Map<String, dynamic> j) {
    final date = DateTime.tryParse(_s(j['date'])) ?? DateTime(2000);
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    final hold = _d(j['hold']);
    return PtRecord(
      id: _s(j['id']).isEmpty
          ? date.microsecondsSinceEpoch.toString()
          : _s(j['id']),
      date: date,
      testNo: _s(j['testNo']),
      site: _s(j['site']),
      system: _s(j['system']),
      line: _s(j['line']),
      pid: _s(j['pid']),
      section: _s(j['section']),
      code: pick(PipingCode.values, j['code'], PipingCode.b313),
      medium: pick(TestMedium.values, j['medium'], TestMedium.hydro),
      fluid: pick(PtFluid.values, j['fluid'], PtFluid.water),
      designKpa: _d(j['design']),
      testKpa: _d(j['test']),
      unit: punitByName(j['unit']),
      holdMin: hold != null && hold > 0 ? hold : 10,
      startAt: DateTime.tryParse(_s(j['start'])),
      endAt: DateTime.tryParse(_s(j['end'])),
      readings: [
        if (j['readings'] is List)
          for (final r in j['readings'] as List) ?PtReading.fromJson(r),
      ],
      allowKpa: _d(j['allow']),
      leakOk: j['leakOk'] == true,
      gauges: [
        if (j['gauges'] is List)
          for (final g in j['gauges'] as List) PtGauge.fromJson(g),
      ],
      reliefKpa: _d(j['relief']),
      reliefNo: _s(j['reliefNo']),
      tester: _s(j['tester']),
      witnessContractor: _s(j['wC']),
      witnessSupervisor: _s(j['wS']),
      witnessOwner: _s(j['wO']),
      memo: _s(j['memo']),
      odMm: _d(j['od']),
      wallMm: _d(j['wall']),
      material: pick(PipeMaterial.values, j['mat'], PipeMaterial.carbon),
      tubeId: _s(j['tubeId']),
      tubeSpec: _s(j['tube']),
      tubeMat: _s(j['tubeMat']),
    );
  }
}

String _csvCell(String s) =>
    s.contains(RegExp(r'[",\n\r]')) ? '"${s.replaceAll('"', '""')}"' : s;

/// 엑셀에서 바로 여는 CSV(UTF-8 BOM). 한 기록이 한 줄. 압력은 기록의 단위(압력 단위 칸)로 적는다.
/// 측정 기록은 마지막 칸에 "시각 구분 압력 온도"를 ; 로 이어 적는다.
String ptRecordsCsv(List<PtRecord> records) {
  final head = <String>[
    '시험 번호',
    '시험일',
    '현장·프로젝트',
    '계통',
    '라인 번호',
    'P&ID·아이소 번호',
    '시험 구간',
    '튜브 규격',
    '규격',
    '시험 종류',
    '시험유체',
    '압력 단위',
    '설계압력',
    '시험압력',
    '규정 유지시간(분)',
    '시작 시각',
    '종료 시각',
    '경과 시간(분)',
    '시작 압력',
    '종료 압력',
    '시작 온도(°C)',
    '종료 온도(°C)',
    '측정 압력강하',
    '온도 보정 후 압력강하',
    '허용 압력강하',
    '유지시간 달성',
    '누설·물맺힘 없음',
    '판정',
    '판정 사유',
    '압력계 1',
    '압력계 2',
    '안전밸브 설정압력',
    '안전밸브 번호',
    '시험자',
    '입회자(시공사)',
    '입회자(감리)',
    '입회자(발주처)',
    '메모',
    '측정 기록',
  ];
  final rows = <List<String>>[head];
  for (final r in records) {
    final u = r.unit;
    String p(double? kpa) => kpa == null ? '' : ptFmt(kpa / u.kpa, 4);
    String t(double? c) => c == null ? '' : ptFmt(c, 1);
    String at(DateTime? d) => d == null ? '' : '${ptDay(d)} ${ptHms(d)}';
    final v = r.verdict;
    final s = r.startReading, e = r.endReading;
    rows.add([
      r.testNo,
      ptDay(r.date),
      r.site,
      r.system,
      r.line,
      r.pid,
      r.section,
      r.tubeSpec,
      ptCodeShort(r.code),
      ptMediumLabel(r.medium),
      ptFluidLabel(r.fluid),
      u.label,
      p(r.designKpa),
      p(r.testKpa),
      ptFmt(r.holdMin, 1),
      at(r.startAt ?? s?.at),
      at(r.endAt ?? e?.at),
      v.elapsedMin == null ? '' : ptFmt(v.elapsedMin!, 1),
      p(s?.kpa),
      p(e?.kpa),
      t(s?.tempC),
      t(e?.tempC),
      p(v.rawDropKpa),
      p(v.correctedDropKpa),
      p(v.allowKpa),
      v.ended ? (v.holdMet ? '예' : '아니오') : '',
      r.leakOk ? '예' : '아니오',
      ptVerdictText(v.pass),
      v.reasons(u).join(' / '),
      r.gauges.isNotEmpty ? r.gauges[0].summary : '',
      r.gauges.length > 1 ? r.gauges[1].summary : '',
      p(r.reliefKpa),
      r.reliefNo,
      r.tester,
      r.witnessContractor,
      r.witnessSupervisor,
      r.witnessOwner,
      r.memo,
      [
        for (final x in r.readings)
          '${ptHms(x.at)} ${ptReadKindLabel(x.kind)} ${ptFmt(x.kpa / u.kpa, 4)}${u.label}'
              '${x.tempC == null ? '' : ' ${ptFmt(x.tempC!, 1)}°C'}',
      ].join('; '),
    ]);
  }
  return '﻿${rows.map((c) => c.map(_csvCell).join(',')).join('\r\n')}\r\n';
}

/// 폰에 저장(SharedPreferences, JSON 목록). 최근 것이 앞.
/// 저장·지우기는 서버(Firestore)에도 올린다(기다리지 않음). 목록 화면을 열면 서버 것과 합친다.
class PtRecordStore {
  static const String key = 'pressure_test_records_v1';
  static const String lastTesterKey = 'pressure_test_last_tester';
  static const String lastGearKey = 'pressure_test_last_gear';

  static Future<List<PtRecord>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      final out = <PtRecord>[];
      for (final e in list) {
        try {
          out.add(PtRecord.fromJson(Map<String, dynamic>.from(e as Map)));
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

  static Future<void> _write(List<PtRecord> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode([for (final r in list) r.toJson()]));
  }

  /// 같은 id가 있으면 바꾸고, 없으면 더한다. 시험자·압력계·안전밸브는 다음 저장 창에 미리 채운다.
  static Future<void> put(PtRecord r) async {
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
    await p.setString(lastTesterKey, r.tester);
    await p.setString(
      lastGearKey,
      jsonEncode({
        'gauges': [for (final g in r.gauges) g.toJson()],
        'relief': r.reliefKpa,
        'reliefNo': r.reliefNo,
      }),
    );
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
      PtRecord.fromJson(j);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 서버 올리기·받기(모음 pressure_test_records, 주인 = 앱 사용자 이름). record_sync.dart.
  static final RecordSync sync = RecordSync(
    key: key,
    collection: 'pressure_test_records',
    isValid: _readable,
  );

  /// 저장 창에 미리 채울 시험자(마지막에 쓴 것, 없으면 앱 사용자 이름).
  static Future<String> lastTester() async {
    final p = await SharedPreferences.getInstance();
    final w = p.getString(lastTesterKey);
    return (w == null || w.trim().isEmpty
            ? p.getString('user_real_name') ?? ''
            : w)
        .trim();
  }

  /// 마지막에 쓴 압력계·안전밸브(설정압력 kPa·번호).
  static Future<(List<PtGauge>, double?, String)> lastGear() async {
    final p = await SharedPreferences.getInstance();
    try {
      final j = jsonDecode(p.getString(lastGearKey) ?? '');
      if (j is! Map) return (const <PtGauge>[], null, '');
      return (
        [
          if (j['gauges'] is List)
            for (final g in j['gauges'] as List) PtGauge.fromJson(g),
        ],
        _d(j['relief']),
        _s(j['reliefNo']),
      );
    } catch (_) {
      return (const <PtGauge>[], null, '');
    }
  }
}
