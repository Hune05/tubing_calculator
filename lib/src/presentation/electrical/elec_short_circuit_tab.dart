// 전기 설비 계산 탭: 단락 전류(3상 최대·최소), 차단기 차단용량 확인, 케이블 열 견딤(I²t).
// 계산은 elec_short_circuit.dart, 근거는 docs/전기_단락전류_근거.md. 입력값은 SharedPreferences 한 칸에 남긴다.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import 'elec_form_parts.dart';
import 'elec_short_circuit.dart';
import 'elec_tables.dart';

class ElecShortCircuitTab extends StatefulWidget {
  const ElecShortCircuitTab({super.key, this.seed, this.history});

  /// 부하 합산 탭이 넘긴 변압기 값(용량·2차 전압). 값이 오면 두 칸을 채운다.
  final ValueListenable<ElecTransformerSeed?>? seed;

  /// "최근 계산 기록"을 다른 탭과 함께 쓸 때 밖에서 만든 기록을 넣는다. 비우면 이 탭만의 기록을 쓴다.
  final RecentCalcLog? history;

  /// 입력값을 남기는 저장 칸 이름.
  static const String draftKey = 'elec_short_draft_v1';

  @override
  State<ElecShortCircuitTab> createState() => _ElecShortCircuitTabState();
}

/// 케이블 구간 한 줄.
class _SegRow {
  _SegRow({this.size = 50, String len = '', this.parallel = 1})
    : len = TextEditingController(text: len);
  double size;
  final TextEditingController len;
  int parallel;
}

class _ElecShortCircuitTabState extends State<ElecShortCircuitTab>
    with
        CalcFormParts<ElecShortCircuitTab>,
        RecentCalcHistoryMixin<ElecShortCircuitTab>,
        ElecTabParts<ElecShortCircuitTab>,
        AutomaticKeepAliveClientMixin<ElecShortCircuitTab> {
  // 탭을 옮겨도 입력이 사라지지 않게 살려 둔다.
  @override
  bool get wantKeepAlive => true;

  @override
  RecentCalcLog get calcLog => widget.history ?? super.calcLog;

  ElecTransformerSeed? _lastSeed;

  final _kva = TextEditingController();
  final _volts = TextEditingController();
  final _z = TextEditingController();
  final _pcu = TextEditingController();
  final _upMax = TextEditingController();
  final _upMin = TextEditingController();
  final _mKw = TextEditingController();
  final _mEff = TextEditingController();
  final _mMult = TextEditingController();
  final _rating = TextEditingController();
  final _make = TextEditingController();
  final _t = TextEditingController();
  final _manualIk = TextEditingController();
  final _letThrough = TextEditingController();

  bool _cMax10 = false;
  Insulation _ins = Insulation.pvc70;
  bool _ics = false;
  int _bkPos = -1; // -1: 마지막 자리(고장점)
  int _cabSeg = 0;
  final List<_SegRow> _rows = [];

  Timer? _saveTimer;
  String? _lastDraft;
  String? _pendingDraft;
  bool _draftReady = false;

  List<(String, TextEditingController)> get _texts => [
    ('kva', _kva),
    ('volts', _volts),
    ('z', _z),
    ('pcu', _pcu),
    ('upMax', _upMax),
    ('upMin', _upMin),
    ('mKw', _mKw),
    ('mEff', _mEff),
    ('mMult', _mMult),
    ('rating', _rating),
    ('make', _make),
    ('t', _t),
    ('manualIk', _manualIk),
    ('letThrough', _letThrough),
  ];

  @override
  void initState() {
    super.initState();
    widget.seed?.addListener(_takeSeed);
    // 저장해 둔 입력을 먼저 채운 다음, 이미 넘어온 값이 있으면 그 값으로 덮는다.
    _loadDraft().then((_) => _takeSeed());
  }

  /// 부하 합산 탭이 넘긴 변압기 용량·2차 전압을 칸에 넣는다(같은 꾸러미는 한 번만).
  void _takeSeed() {
    final s = widget.seed?.value;
    if (s == null || !mounted || identical(s, _lastSeed)) return;
    _lastSeed = s;
    setState(() {
      _kva.text = fmt(s.kva, 1);
      _volts.text = fmt(s.volts, 0);
    });
  }

  @override
  void dispose() {
    widget.seed?.removeListener(_takeSeed);
    _saveTimer?.cancel();
    _flushDraft();
    for (final (_, c) in _texts) {
      c.dispose();
    }
    for (final r in _rows) {
      r.len.dispose();
    }
    super.dispose();
  }

  // ─────────────── 저장(입력값 남기기) ───────────────

  // "최근 계산 기록"을 눌러 되돌릴 때 저장 칸과 같은 모양을 쓴다.
  @override
  Map<String, Object?>? historySnapshot() => _draft();

  @override
  void applyHistorySnapshot(Map<String, dynamic> m) => _applyDraft(m);

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(ElecShortCircuitTab.draftKey);
      if (raw != null && mounted) {
        final m = jsonDecode(raw);
        if (m is Map<String, dynamic>) setState(() => _applyDraft(m));
      }
      _lastDraft = raw;
    } catch (_) {
      // 저장 칸을 못 읽어도 빈 칸으로 쓴다.
    }
    _draftReady = true;
  }

  Map<String, Object?> _draft() => {
    'c10': _cMax10,
    'ins': _ins.name,
    'ics': _ics,
    'bkPos': _bkPos,
    'cabSeg': _cabSeg,
    'segs': [
      for (final r in _rows)
        {'size': r.size, 'len': r.len.text, 'par': r.parallel},
    ],
    for (final (k, c) in _texts) k: c.text,
  };

  void _applyDraft(Map<String, dynamic> m) {
    _cMax10 = m['c10'] is bool ? m['c10'] as bool : _cMax10;
    _ins = Insulation.values.firstWhere(
      (v) => v.name == m['ins'],
      orElse: () => _ins,
    );
    _ics = m['ics'] is bool ? m['ics'] as bool : _ics;
    _bkPos = m['bkPos'] is int ? m['bkPos'] as int : _bkPos;
    _cabSeg = m['cabSeg'] is int ? m['cabSeg'] as int : _cabSeg;
    final segs = m['segs'];
    if (segs is List) {
      for (final r in _rows) {
        r.len.dispose();
      }
      _rows.clear();
      for (final s in segs.take(8)) {
        if (s is! Map) continue;
        final size = s['size'] is num ? (s['size'] as num).toDouble() : 50.0;
        final par = s['par'] is num ? (s['par'] as num).round() : 1;
        _rows.add(
          _SegRow(
            size: kCableSizes.contains(size) ? size : 50,
            len: s['len'] is String ? s['len'] as String : '',
            parallel: par.clamp(1, 4),
          ),
        );
      }
    }
    for (final (k, c) in _texts) {
      if (m[k] is String) c.text = m[k] as String;
    }
  }

  void _scheduleSave() {
    if (!_draftReady) return;
    final raw = jsonEncode(_draft());
    if (raw == _lastDraft || raw == _pendingDraft) return;
    _pendingDraft = raw;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _flushDraft);
  }

  void _flushDraft() {
    final raw = _pendingDraft;
    if (raw == null) return;
    _pendingDraft = null;
    _lastDraft = raw;
    _writeDraft(raw);
  }

  static Future<void> _writeDraft(String raw) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ElecShortCircuitTab.draftKey, raw);
    } catch (_) {
      // 저장을 못 해도 계산에는 지장이 없습니다.
    }
  }

  // ─────────────── 입력 읽기 ───────────────

  /// 칸이 비면 null. 글이 있는데 숫자가 아니면 오류 글을 남기고 null.
  double? _val(TextEditingController c, String label, List<String> errs) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    final v = readNum(c);
    if (v == null || !v.isFinite) {
      errs.add('$label: 숫자가 아닙니다.');
      return null;
    }
    return v;
  }

  String _ka(double a) => fmt(a / 1000, 2);

  void _set(VoidCallback f) => setState(f);

  // ─────────────── 화면 ───────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _scheduleSave();
    final errs = <String>[];
    final kva = _val(_kva, '변압기 용량', errs);
    final volts = _val(_volts, '2차 전압', errs);
    final zPct = _val(_z, '%Z', errs);
    final pcu = _val(_pcu, '부하손', errs);
    final upMax = _val(_upMax, '상위 계통 단락용량', errs);
    final upMin = _val(_upMin, '상위 계통 최소 단락용량', errs);
    final mKw = _val(_mKw, '전동기 합계 kW', errs);
    final mEff = _val(_mEff, '전동기 효율×역률', errs);
    final mMult = _val(_mMult, '전동기 기여 배수', errs);
    final segs = <ScSegment>[];
    for (var i = 0; i < _rows.length; i++) {
      final len = _val(_rows[i].len, '구간 ${i + 1} 편도 길이', errs);
      if (_rows[i].len.text.trim().isEmpty) {
        errs.add('구간 ${i + 1}: 편도 길이(m)를 넣으십시오. 쓰지 않는 구간은 지우십시오.');
      }
      segs.add(
        ScSegment(
          sizeMm2: _rows[i].size,
          lengthM: len ?? 0,
          parallel: _rows[i].parallel,
        ),
      );
    }
    final missing = <String>[
      if (kva == null && _kva.text.trim().isEmpty) '변압기 용량',
      if (volts == null && _volts.text.trim().isEmpty) '2차 전압',
      if (zPct == null && _z.text.trim().isEmpty) '%Z',
    ];

    ScResult? res;
    ScInput? scIn;
    if (errs.isEmpty && missing.isEmpty) {
      scIn = ScInput(
        kva: kva!,
        volts: volts!,
        zPercent: zPct!,
        pcuKw: pcu,
        upstreamMvaMax: upMax,
        upstreamMvaMin: upMin,
        motorKw: mKw,
        motorEffPf: mEff,
        motorMultiple: mMult,
        cMax: _cMax10 ? kScCMax10 : kScCMax6,
        insulation: _ins,
        segments: segs,
      );
      res = calcShortCircuit(scIn);
    }

    final n = _rows.length;
    final pos = (_bkPos < 0 || _bkPos > n) ? n : _bkPos;
    final cabSeg = n == 0 ? 0 : _cabSeg.clamp(0, n - 1);

    final allErrs = [...errs, ...?res?.errors];
    Widget mainCard;
    String? summary;
    var warn = false;
    final extra = <Widget>[];
    if (allErrs.isNotEmpty) {
      warn = true;
      summary = '입력 확인';
      mainCard = calcResult(solve: true, 
        key: const Key('ec_sc_result'),
        big: '입력 확인',
        caption: '표시된 칸을 고치면 계산합니다',
        warn: true,
        lines: allErrs,
      );
    } else if (res == null) {
      mainCard = calcResult(solve: true, 
        key: const Key('ec_sc_result'),
        big: '—',
        caption: '빈 칸을 채우면 계산합니다:${missing.join(', ')}',
        lines: const ['변압기 용량·2차 전압·%Z는 변압기 명판 값을 넣으십시오. 앱이 값을 채우지 않습니다.'],
      );
    } else {
      final r = res;
      final diff = r.ikPercentZA == 0
          ? 0.0
          : (r.ikPercentZA - r.ikMaxA) / r.ikMaxA * 100;
      mainCard = calcResult(solve: true, 
        key: const Key('ec_sc_result'),
        big: '${_ka(r.ikMaxA)} kA',
        caption: 'Ik″ 최대 (3상 대칭 초기 단락전류, 고장점 = ${_posLabel(n, n)})',
        lines: [
          'IEC 60909 등가 전압원법: c = ${fmt(_cMax10 ? kScCMax10 : kScCMax6, 2)}, KT = ${fmt(r.kT, 3)}. 차단기 차단용량 선정용 최대값입니다.',
          ..._maxSteps(r, scIn!),
          '%임피던스법(비교): ${_ka(r.ikPercentZA)} kA. IEC 값보다 ${fmt(diff.abs(), 1)}% ${diff < 0 ? '작습니다' : '큽니다'}.',
          _peakLine(r),
        ],
      );
      final minCard = calcResult(solve: true, 
        key: const Key('ec_sc_min_result'),
        big: '${_ka(r.ikMin2A)} kA',
        caption: 'Ik″ 최소 (2상 단락, 보호 감도용)',
        warn: r.minUsesMaxUpstream,
        lines: [
          ..._minSteps(r, scIn),
          'c = ${fmt(kScCMin, 2)}, 케이블 저항은 단락이 끝날 때 도체 온도 ${fmt(minScConductorTemp(_ins), 0)}°C 값(IEC 909 9.3.1 식 32), 전동기 기여 제외.',
          '지락(1선) 단락은 포함하지 않음. 영상 임피던스가 필요합니다.',
          '차단기 순시 설정값이 이 값보다 작아야 최소 단락에서도 순시로 차단합니다.',
        ],
      );
      extra.add(const SizedBox(height: 10));
      extra.add(minCard);
      if (r.notes.isNotEmpty) {
        extra.add(const SizedBox(height: 10));
        extra.add(
          calcResult(solve: true, 
            key: const Key('ec_sc_notes'),
            big: '확인 ${r.notes.length}건',
            caption: '결과를 쓰기 전에 읽으십시오',
            warn: true,
            lines: r.notes,
          ),
        );
      }
    }

    // ── 차단기 차단용량
    final bkErrs = <String>[];
    final ratingKa = _val(_rating, '차단용량', bkErrs);
    final makeKa = _val(_make, '정격 투입용량', bkErrs);
    if (ratingKa != null && ratingKa <= 0) {
      bkErrs.add('차단용량은 0보다 커야 합니다.');
    }
    if (makeKa != null && makeKa <= 0) {
      bkErrs.add('정격 투입용량은 0보다 커야 합니다.');
    }
    Widget bkCard;
    String? bkSummary;
    var bkWarn = false;
    final rr = (res != null && res.ok) ? res : null;
    if (bkErrs.isNotEmpty) {
      bkWarn = true;
      bkSummary = '차단용량 입력 확인';
      bkCard = calcResult(solve: true, 
        key: const Key('ec_sc_breaker_result'),
        big: '입력 확인',
        caption: '차단기 칸',
        warn: true,
        lines: bkErrs,
      );
    } else if (rr == null || ratingKa == null) {
      bkCard = calcResult(solve: true, 
        key: const Key('ec_sc_breaker_result'),
        big: '—',
        caption: rr == null ? '위 단락전류를 먼저 계산하십시오' : '차단용량을 넣으면 합격/불합격을 판정합니다',
        lines: const [],
      );
    } else {
      final ik = rr.startIkMaxA[pos];
      final ok = breakingOk(ratingKa, ik / 1000);
      final ip = rr.startIpA[pos];
      final makeOk = makeKa == null ? null : makeKa >= ip / 1000;
      bkWarn = !ok || makeOk == false;
      bkSummary = '차단용량 ${ok ? '합격' : '불합격'}';
      bkCard = calcResult(solve: true, 
        key: const Key('ec_sc_breaker_result'),
        big: ok ? '합격' : '불합격',
        caption:
            '${_ics ? 'Ics' : 'Icu'} ${fmt(ratingKa, 1)} kA, 차단기 위치: ${_posLabel(pos, n)}',
        warn: bkWarn,
        lines: [
          ok
              ? '${_ics ? 'Ics' : 'Icu'} ${fmt(ratingKa, 1)} kA가 Ik″ 최대 ${_ka(ik)} kA 이상입니다(여유 ${fmt((ratingKa - ik / 1000) / (ik / 1000) * 100, 1)}%).'
              : '${_ics ? 'Ics' : 'Icu'} ${fmt(ratingKa, 1)} kA가 Ik″ 최대 ${_ka(ik)} kA보다 작습니다. 차단용량이 큰 차단기로 바꾸십시오.',
          if (_ics)
            'Ics는 Icu보다 작은 값이라 Ics로 비교하면 더 엄격합니다. 제조사 표에서 어느 값인지 확인하십시오.',
          if (makeKa == null)
            '투입(피크) 확인은 정격 투입용량을 넣을 때만 합니다.'
          else
            makeOk!
                ? '정격 투입용량 ${fmt(makeKa, 1)} kA가 피크 전류 ${_ka(ip)} kA 이상입니다.'
                : '정격 투입용량 ${fmt(makeKa, 1)} kA가 피크 전류 ${_ka(ip)} kA보다 작습니다. 불합격입니다.',
          '상위 차단기의 한류 효과(캐스케이드)와 후비 보호는 반영하지 않았습니다. 제조사 자료로 확인하십시오.',
        ],
      );
    }

    // ── 케이블 열 견딤
    final cabErrs = <String>[];
    final tSec = _val(_t, '차단 시간', cabErrs);
    final manualKa = _val(_manualIk, '단락전류 직접 입력', cabErrs);
    final lt = _val(_letThrough, '차단기 통과 에너지', cabErrs);
    if (tSec != null && tSec <= 0) cabErrs.add('차단 시간은 0보다 커야 합니다.');
    if (manualKa != null && manualKa <= 0) {
      cabErrs.add('단락전류 직접 입력은 0보다 커야 합니다.');
    }
    if (lt != null && lt <= 0) cabErrs.add('차단기 통과 에너지는 0보다 커야 합니다.');
    Widget cabCard;
    String? cabSummary;
    var cabWarn = false;
    if (cabErrs.isNotEmpty) {
      cabWarn = true;
      cabSummary = '케이블 입력 확인';
      cabCard = calcResult(solve: true, 
        key: const Key('ec_sc_cable_result'),
        big: '입력 확인',
        caption: '케이블 칸',
        warn: true,
        lines: cabErrs,
      );
    } else if (n == 0) {
      cabCard = calcResult(solve: true, 
        key: const Key('ec_sc_cable_result'),
        big: '—',
        caption: '케이블 구간을 추가하면 그 구간의 열적 강도를 판정합니다',
        lines: const [],
      );
    } else if (rr == null || tSec == null) {
      cabCard = calcResult(solve: true, 
        key: const Key('ec_sc_cable_result'),
        big: '—',
        caption: rr == null ? '위 단락전류를 먼저 계산하십시오' : '차단 시간(초)을 넣으면 합격/불합격을 판정합니다',
        lines: const [],
      );
    } else {
      final seg = _rows[cabSeg];
      final autoA = rr.startIkMaxA[cabSeg];
      final ikA = manualKa != null ? manualKa * 1000 : autoA;
      final w = cableWithstand(
        sizeMm2: seg.size,
        insulation: _ins,
        ikA: ikA,
        tSec: tSec,
        parallel: seg.parallel,
        letThroughA2s: lt,
      )!;
      final ltBad = w.letThroughOk == false;
      cabWarn = !w.ok || ltBad;
      cabSummary = '케이블 ${cabWarn ? '불합격' : '합격'}';
      final insName = _ins == Insulation.pvc70 ? 'PVC' : 'XLPE·EPR';
      final temps = _ins == Insulation.pvc70 ? '70→160°C' : '90→250°C';
      cabCard = calcResult(solve: true, 
        key: const Key('ec_sc_cable_result'),
        big: cabWarn ? '불합격' : '합격',
        caption:
            '구간 ${cabSeg + 1}: ${fmt(seg.size)}mm²${seg.parallel > 1 ? ' × ${seg.parallel}가닥' : ''}, 구리 $insName, k = ${fmt(w.k, 0)}',
        warn: cabWarn,
        lines: [
          '① 단락전류 ${_ka(ikA)} kA(${manualKa != null ? '직접 입력값. 자동 값 ${_ka(autoA)} kA' : '구간 시작점 자동 값'}), 차단 시간 ${fmt(tSec, 3)}초.',
          if (seg.parallel > 1) '가닥마다 Ik = ${_ka(ikA)} kA ÷ ${seg.parallel}가닥 = ${_ka(w.ikPerConductorA)} kA가 흐르는 것으로 계산했습니다.',
          '② 필요한 최소 굵기 S = Ik × √t ÷ k = ${fmt(w.ikPerConductorA, 0)} A × √${fmt(tSec, 3)} ÷ ${fmt(w.k, 0)} = ${fmt(w.sMinMm2, 1)} mm². 선정 ${fmt(w.sMm2)} mm²는 ${w.ok ? '이상이라 합격' : '미만이라 불합격'}입니다.',
          '③ 이 전류에서 허용 최대 시간 t = (k × S ÷ Ik)² = (${fmt(w.k, 0)} × ${fmt(w.sMm2)} ÷ ${fmt(w.ikPerConductorA, 0)})² = ${fmt(w.tMaxSec, 3)}초.',
          if (lt != null)
            '④ 허용 통과 에너지 = (병렬 수)² × k² × S² = ${seg.parallel}² × ${fmt(w.k, 0)}² × ${fmt(w.sMm2)}² = ${fmt(w.allowedA2s, 0)} A²s.',
          if (lt != null)
            w.letThroughOk!
                ? '차단기 통과 에너지 ${fmt(lt, 0)} A²s가 허용 ${fmt(w.allowedA2s, 0)} A²s 이내입니다.'
                : '차단기 통과 에너지 ${fmt(lt, 0)} A²s가 허용 ${fmt(w.allowedA2s, 0)} A²s를 초과합니다. 불합격입니다.',
          if (tSec > kScAdiabaticMaxSec)
            '차단 시간 ${fmt(kScAdiabaticMaxSec, 0)}초 초과는 이 식의 적용 범위 밖입니다. IEC 60949 계산으로 확인하십시오.',
          if (tSec < kScShortSec && lt == null)
            '0.1초보다 짧으면 차단기가 순시 영역에서 끊습니다. 이때는 시간이 아니라 제조사 통과 에너지(I²t) 곡선으로 확인해야 합니다. 통과 에너지를 넣으십시오.',
          '조건: 초기·최종 온도 $temps, 구리 도체, 300mm² 이하, 5초 이하. 단열 계산입니다.',
        ],
      );
    }

    // 요약 줄(고정).
    final sumParts = <String>[];
    if (allErrs.isNotEmpty) {
      summary = '입력 확인';
    } else if (rr != null) {
      sumParts.add('Ik″ 최대 ${_ka(rr.ikMaxA)} kA');
      sumParts.add('최소(2상) ${_ka(rr.ikMin2A)} kA');
      if (bkSummary != null) sumParts.add(bkSummary);
      if (cabSummary != null) sumParts.add(cabSummary);
      summary = sumParts.join(' · ');
      // 빈 선택 칸 때문에 나오는 안내(최소 단락이 안전 쪽이 아님)는 아래 카드에서만 붉게 보이고,
      // 요약 줄은 차단용량·케이블 열 견딤이 불합격일 때만 붉게 한다.
      warn = bkWarn || cabWarn;
    } else {
      summary = '변압기 명판 값을 넣으십시오';
    }

    return elecPage(sumKey: 'ec_sc_sum', summary: summary, warn: warn, [
      elecSectionTitle('변압기와 전원'),
      elecField(
        'ec_sc_kva',
        '변압기 용량 (kVA)',
        _kva,
        '변압기 명판의 정격 용량입니다. 3상 변압기 한 대 기준입니다.',
      ),
      elecField(
        'ec_sc_volts',
        '2차 전압 (V)',
        _volts,
        '변압기 2차 정격전압이며 계통 공칭전압으로 씁니다. 아래 단추로 넣을 수 있습니다.',
      ),
      if ((parseNumberText(_volts.text) ?? 0) > 1000)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '2차 전압이 1 kV를 넘습니다(고압). 이 계산의 전압 계수 c와 케이블 표는 저압(1 kV 이하) 기준이라 '
            '고압 단락 전류로는 맞지 않습니다. 고압은 IEC 60909 고압 전압 계수와 계통 자료로 따로 검토하십시오.',
            key: const Key('ec_sc_hv_note'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fc.danger,
            ),
          ),
        ),
      elecChipGroup('자주 쓰는 전압', '누르면 2차 전압 칸에 넣습니다.', [
        for (final v in const [220, 380, 400, 440, 480])
          calcChip('ec_sc_v_$v', '$v V', _volts.text.trim() == '$v', () {
            _set(() => _volts.text = '$v');
          }),
      ]),
      elecField(
        'ec_sc_z',
        '변압기 %Z (명판)',
        _z,
        '변압기 명판의 임피던스 전압(%)입니다. 앱이 값을 채우지 않으므로 명판을 보고 넣으십시오.',
      ),
      elecField(
        'ec_sc_pcu',
        '부하손 (kW, 명판, 선택)',
        _pcu,
        '변압기 명판이나 시험 성적서의 부하손(동손)입니다. 넣으면 변압기 저항까지 벡터로 계산합니다. 비우면 순리액턴스로 봅니다.',
      ),
      elecChipGroup(
        '전압 허용오차',
        'IEC 60909 저압 전압 계수 cmax를 정합니다.\n'
            '+6%: cmax 1.05. +10%: cmax 1.10. 처음 값은 +6%입니다. 계통의 최대 전압 허용오차가 +6%를 넘거나 모르면 +10%를 누르십시오(단락전류가 큰 쪽).',
        [
          calcChip('ec_sc_c6', '+6% (c 1.05)', !_cMax10, () {
            _set(() => _cMax10 = false);
          }),
          calcChip('ec_sc_c10', '+10% (c 1.10)', _cMax10, () {
            _set(() => _cMax10 = true);
          }),
        ],
      ),
      elecField(
        'ec_sc_up_max',
        '상위 계통 단락용량 (MVA, 선택)',
        _upMax,
        '한전이나 수전 설비 자료의 최대 단락용량입니다. 비우면 무한 전원으로 계산합니다(최대값).',
      ),
      elecField(
        'ec_sc_up_min',
        '상위 계통 최소 단락용량 (MVA, 선택)',
        _upMin,
        '최소 단락 계산에 씁니다. 비우면 위 최대용 값을 씁니다. 실제 최소값은 더 작을 수 있습니다.',
      ),
      ...elecFold('ec_sc_fold_motor', '저압 전동기 기여 (선택)', [
      elecField(
        'ec_sc_mkw',
        '전동기 합계 kW',
        _mKw,
        '단락 때 같이 운전 중인 저압 3상 전동기의 합계 출력입니다. 세 칸이 다 차야 반영합니다.',
      ),
      elecField(
        'ec_sc_meff',
        '효율×역률 (0~1)',
        _mEff,
        '전동기 명판의 효율과 역률을 곱한 값입니다. 정격전류 계산에 씁니다. 앱이 값을 채우지 않습니다.',
      ),
      elecField(
        'ec_sc_mmult',
        '기여 배수 (기동전류/정격전류)',
        _mMult,
        '전동기가 단락 때 내보내는 전류를 정격전류의 몇 배로 볼지 정합니다. IEC 909(1988) 원문은 저압 전동기 묶음에 ${fmt(kScMotorMultipleGuide, 0)}배(ILR/IrM = 5)를 씁니다. 모르면 ${fmt(kScMotorMultipleGuide, 0)}를 넣으십시오. 명판의 기동전류 배수를 알면 그 값을 넣으십시오. 앱이 값을 채우지 않습니다.',
      ),
      ], subtitle: _mKw.text.trim().isEmpty ? '넣지 않음' : '${_mKw.text.trim()} kW'),
      elecSectionTitle('케이블 구간 (변압기 쪽부터 순서대로)'),
      elecChipGroup(
        '케이블 절연',
        '최소 단락의 도체 온도(단락이 끝날 때 온도: PVC 160°C, XLPE·EPR 250°C)와 열적 강도 k 값에 씁니다. 구리 도체만 지원합니다.',
        [
          calcChip('ec_sc_pvc', 'PVC', _ins == Insulation.pvc70, () {
            _set(() => _ins = Insulation.pvc70);
          }),
          calcChip('ec_sc_xlpe', 'XLPE·EPR', _ins == Insulation.xlpe90, () {
            _set(() => _ins = Insulation.xlpe90);
          }),
        ],
      ),
      for (var i = 0; i < _rows.length; i++) _segCard(i),
      calcToggle('ec_sc_add', '구간 추가', () {
        _set(() {
          if (_rows.length < 8) _rows.add(_SegRow());
        });
      }),
      const SizedBox(height: 8),
      mainCard,
      ...extra,
      ...elecFold('ec_sc_fold_breaker', '차단기 차단용량 확인', [
      elecChipGroup(
        '차단용량 종류',
        'Icu: 극한 차단용량. Ics: 운전 차단용량. 제조사 표에서 어느 값을 넣는지 고르십시오.',
        [
          calcChip('ec_sc_icu', 'Icu', !_ics, () {
            _set(() => _ics = false);
          }),
          calcChip('ec_sc_ics', 'Ics', _ics, () {
            _set(() => _ics = true);
          }),
        ],
      ),
      calcDropdown<int>(
        'ec_sc_bk_pos',
        '차단기 위치',
        pos,
        [for (var k = 0; k <= n; k++) k],
        (k) => _posLabel(k, n),
        (k) => _set(() => _bkPos = k),
        '그 자리에서 보는 단락전류로 비교합니다. 가장 큰 값은 변압기 2차 단자입니다.',
      ),
      elecField(
        'ec_sc_rating',
        '차단용량 (kA)',
        _rating,
        '차단기 정격 차단용량(실효값 kA)입니다. 사용 전압에 맞는 값을 넣으십시오.',
      ),
      elecField(
        'ec_sc_make',
        '정격 투입용량 (kA 피크, 선택)',
        _make,
        '차단기 정격 투입용량(피크값 kA)입니다. 넣으면 피크 전류와 비교합니다.',
      ),
      bkCard,
      ], subtitle: _rating.text.trim().isEmpty ? '차단용량을 넣으면 판정' : '${_rating.text.trim()} kA'),
      ...elecFold('ec_sc_fold_cable', '케이블 단락 열적 강도 (I²t)', [
      if (n > 0)
        elecChipGroup('검토할 구간', '케이블 시작점의 단락전류를 씁니다. 시작점이 전류가 가장 큽니다.', [
          for (var i = 0; i < n; i++)
            calcChip('ec_sc_cab_$i', '구간 ${i + 1}', cabSeg == i, () {
              _set(() => _cabSeg = i);
            }),
        ]),
      elecField(
        'ec_sc_t',
        '차단 시간 t (초)',
        _t,
        '보호 차단기가 단락전류를 끊는 시간입니다. 차단기 특성 곡선에서 확인한 값을 넣으십시오. 5초 이하만 이 식이 맞습니다.',
      ),
      elecField(
        'ec_sc_ik_manual',
        '단락전류 직접 입력 (kA, 선택)',
        _manualIk,
        '비우면 위 계산의 케이블 시작점 값을 씁니다. 상위 계통 실제 자료가 있으면 넣으십시오.',
      ),
      elecField(
        'ec_sc_i2t',
        '차단기 통과 에너지 I²t (A²s, 선택)',
        _letThrough,
        '한류형 차단기가 순시로 끊을 때 제조사 통과 에너지 곡선에서 확인한 값입니다. 넣으면 케이블 허용값과 비교합니다.',
      ),
      cabCard,
      ], subtitle: _t.text.trim().isEmpty ? '차단 시간을 넣으면 판정' : 't ${_t.text.trim()}초'),
      const SizedBox(height: 10),
      Text(
        '최종 선정은 상위 계통 실제 자료와 차단기 제조사 자료로 확인하십시오.',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: fc.text,
        ),
      ),
      elecBasis('ec_sc_basis', _basisLines()),
    ]);
  }

  // ─────────────── 풀이 줄(화면 글만. 계산은 elec_short_circuit.dart) ───────────────
  // 임피던스는 계산 함수와 같은 식으로 화면에서 다시 구해 보인다(시험에서 결과 kA와 맞는지 확인).

  /// Ω을 mΩ 글로. 1 mΩ 미만은 소수 셋째 자리까지.
  String _mo(double ohm) {
    final m = ohm * 1000;
    return fmt(m, m.abs() < 1 ? 3 : 2);
  }

  /// 상위 계통 임피던스 (R, X) Ω: Z = c·U²/S″k, X = 0.995 Z, R = 0.1 X. 용량이 없으면 0.
  (double, double, double) _network(double? mva, double c, double u) {
    if (mva == null) return (0, 0, 0);
    final z = c * u * u / (mva * 1e6);
    final x = kScNetX * z;
    return (z, kScNetRoverX * x, x);
  }

  /// 최대 단락 풀이: ① 전원 ② 변압기 ③ 케이블 구간 ④ 합계 ⑤ Ik″ (전동기가 있으면 ⑥).
  List<String> _maxSteps(ScResult r, ScInput i) {
    final u = i.volts;
    final c = i.cMax;
    final s3 = math.sqrt(3);
    final uTxt = fmt(u, 1);
    final cTxt = fmt(c, 2);
    final zBase = u * u / (i.kva * 1000);
    final zt = r.ztOhm;
    final rt = r.rtOhm;
    final xt = math.sqrt(zt * zt - rt * rt);
    final kT = r.kT;
    final kvaTxt = fmt(i.kva, 1);
    final out = <String>[];

    final (zq, qR, qX) = _network(i.upstreamMvaMax, c, u);
    if (i.upstreamMvaMax == null) {
      out.add('① 전원: 상위 계통 단락용량을 넣지 않아 무한 전원으로 봅니다. Zq = 0.');
    } else {
      out.add(
        '① 전원: Zq = c × U² ÷ S″k = $cTxt × $uTxt² ÷ (${fmt(i.upstreamMvaMax!, 2)} × 10⁶) = ${_mo(zq)} mΩ. '
        'X = 0.995 × Zq = ${_mo(qX)} mΩ, R = 0.1 × X = ${_mo(qR)} mΩ.',
      );
    }

    out.add(
      '② 변압기: ZT = %Z ÷ 100 × U² ÷ S = ${fmt(i.zPercent, 2)} ÷ 100 × $uTxt² ÷ ($kvaTxt × 1000) = ${_mo(zt)} mΩ.',
    );
    if (r.hasLoss) {
      out.add(
        'RT = 부하손 ÷ 용량 × U² ÷ S = ${fmt(i.pcuKw!, 2)} ÷ $kvaTxt × ${_mo(zBase)} mΩ = ${_mo(rt)} mΩ. '
        'XT = √(ZT² − RT²) = √(${_mo(zt)}² − ${_mo(rt)}²) = ${_mo(xt)} mΩ.',
      );
    } else {
      out.add('부하손을 넣지 않아 RT = 0, XT = ZT = ${_mo(xt)} mΩ.');
    }
    out.add(
      'KT = 0.95 × cmax ÷ (1 + 0.6 × xT) = 0.95 × $cTxt ÷ (1 + 0.6 × ${fmt(xt / zBase, 4)}) = ${fmt(kT, 3)}. '
      'xT = XT ÷ (U² ÷ S). 변압기는 KT를 곱해 R = ${_mo(rt * kT)} mΩ, X = ${_mo(xt * kT)} mΩ로 씁니다.',
    );

    var cabR = 0.0, cabX = 0.0;
    if (i.segments.isEmpty) {
      out.add('③ 케이블 구간 없음: 고장점이 변압기 2차 단자입니다.');
    } else {
      out.add(
        '③ 케이블(최대 단락은 20 ℃ 저항): R = 저항(Ω/km) × 길이 ÷ 1000 ÷ 가닥 수, X = ${fmt(kReactanceOhmPerKm, 3)} × 길이 ÷ 1000 ÷ 가닥 수.',
      );
      for (var j = 0; j < i.segments.length; j++) {
        final s = i.segments[j];
        final z = s.z(20);
        cabR += z.r;
        cabX += z.x;
        final par = s.parallel > 1 ? ' ÷ ${s.parallel}' : '';
        final len = fmt(s.lengthM, 1);
        out.add(
          '구간 ${j + 1} (${fmt(s.sizeMm2)} mm², $len m${s.parallel > 1 ? ', ${s.parallel}가닥' : ''}): '
          'R = ${fmt(cuResistance(s.sizeMm2, 20), 4)} × $len ÷ 1000$par = ${_mo(z.r)} mΩ, '
          'X = ${fmt(kReactanceOhmPerKm, 3)} × $len ÷ 1000$par = ${_mo(z.x)} mΩ.',
        );
      }
    }

    final totR = qR + rt * kT + cabR;
    final totX = qX + xt * kT + cabX;
    final totZ = math.sqrt(totR * totR + totX * totX);
    out.add(
      '④ 합계: R = ${_mo(qR)} + ${_mo(rt * kT)} + ${_mo(cabR)} = ${_mo(totR)} mΩ, '
      'X = ${_mo(qX)} + ${_mo(xt * kT)} + ${_mo(cabX)} = ${_mo(totX)} mΩ. '
      'Z = √(R² + X²) = √(${_mo(totR)}² + ${_mo(totX)}²) = ${_mo(totZ)} mΩ.',
    );
    // 전동기가 있으면 이 값은 "전동기를 뺀 Ik″"이다(합계는 ⑥에서 모선 기준으로 다시 셈).
    final netOnlyA = i.cMax * u / (s3 * totZ);
    out.add(
      '⑤ Ik″ = c × Un ÷ (√3 × Z) = $cTxt × $uTxt ÷ (√3 × ${_mo(totZ)} mΩ) = ${_ka(r.motorsIncluded ? netOnlyA : r.ikNetA)} kA'
      '${r.motorsIncluded ? '(전동기를 뺀 값)' : ''}.',
    );

    if (r.motorsIncluded) {
      final mult = i.motorMultiple!;
      final zM = u / (s3 * mult * r.motorRatedA);
      final m = motorImpedance(zM);
      final rxTxt = fmt(kScMotorRoverX, 2);
      out.add(
        '⑥ 전동기 기여: 정격전류 IrM = kW × 1000 ÷ (√3 × U × 효율×역률) = ${fmt(i.motorKw!, 1)} × 1000 ÷ (√3 × $uTxt × ${fmt(i.motorEffPf!, 3)}) = ${fmt(r.motorRatedA, 1)} A. '
        'ZM = U ÷ (√3 × 배수 × IrM) = $uTxt ÷ (√3 × ${fmt(mult, 2)} × ${fmt(r.motorRatedA, 1)}) = ${_mo(zM)} mΩ.',
      );
      out.add(
        'RM/XM = $rxTxt(IEC 909 8.3.2.5 저압 전동기 묶음): XM = ZM ÷ √(1 + $rxTxt²) = ${_mo(m.x)} mΩ, RM = $rxTxt × XM = ${_mo(m.r)} mΩ.',
      );
      if (i.segments.isEmpty) {
        out.add(
          '모선 단락: 전동기 기여 = c × Un ÷ (√3 × |ZM|) = ${_ka(r.ikMotorA)} kA. '
          '합계 Ik″ = 변압기·계통분 ${_ka(r.ikNetA)} + 전동기분 ${_ka(r.ikMotorA)} = ${_ka(r.ikMaxA)} kA(IEC 909, 두 몫의 합).',
        );
      } else {
        // 10-07: 예전에는 전동기에도 케이블을 따로 더해 합쳐서 케이블 끝 값이 컸다.
        out.add(
          '케이블 끝 단락: 변압기·계통과 전동기는 같은 모선에서 같은 케이블을 지나므로, 두 전원을 모선에서 하나로 묶은 '
          '등가 임피던스(모선 단락전류가 두 몫의 합이 되게 맞춤)에 케이블을 더해 합계를 구하고, 모선에서의 비율대로 나눕니다(IEC 909 등가 전압원법). '
          '합계 Ik″ = ${_ka(r.ikMaxA)} kA = 변압기·계통분 ${_ka(r.ikNetA)} + 전동기분 ${_ka(r.ikMotorA)} kA.',
        );
      }
    }
    return out;
  }

  /// 피크 전류 풀이 한 줄: ip = κ·√2·Ik″.
  String _peakLine(ScResult r) {
    final kap = fmt(r.kappa, 3);
    final rx = fmt(r.rOverX, 3);
    if (!r.motorsIncluded) {
      return '피크 전류 ip = κ × √2 × Ik″ = $kap × 1.414 × ${_ka(r.ikMaxA)} = ${_ka(r.ipA)} kA (κ = 1.02 + 0.98·e^(−3R/X), R/X = $rx).';
    }
    final km = fmt(kScMotorKappa, 1);
    return '피크 전류 ip = κ × √2 × Ik″(변압기·계통) + κM × √2 × Ik″(전동기) = $kap × 1.414 × ${_ka(r.ikNetA)} + $km × 1.414 × ${_ka(r.ikMotorA)} = ${_ka(r.ipA)} kA (R/X = $rx, 저압 전동기 묶음 κM = $km).';
  }

  /// 최소 단락 풀이: ① 합계 임피던스 ② 3상 ③ 2상.
  List<String> _minSteps(ScResult r, ScInput i) {
    final u = i.volts;
    final uTxt = fmt(u, 1);
    final cTxt = fmt(kScCMin, 2);
    final rt = r.rtOhm;
    final xt = math.sqrt(r.ztOhm * r.ztOhm - rt * rt);
    final kT = r.kT;
    final minMva = i.upstreamMvaMin ?? i.upstreamMvaMax;
    final (_, qR, qX) = _network(minMva, kScCMin, u);
    final temp = minScConductorTemp(i.insulation);
    final factor = 1 + kScMinAlpha * (temp - 20);
    var cabR = 0.0, cabX = 0.0;
    for (final s in i.segments) {
      final z = s.zMin(temp);
      cabR += z.r;
      cabX += z.x;
    }
    final totR = qR + rt * kT + cabR;
    final totX = qX + xt * kT + cabX;
    final totZ = math.sqrt(totR * totR + totX * totX);
    final insName = i.insulation == Insulation.pvc70 ? 'PVC' : 'XLPE·EPR';
    return [
      if (i.segments.isNotEmpty)
        '케이블 저항(IEC 909 9.3.1 식 32): R = R20 × [1 + ${fmt(kScMinAlpha, 3)} × (θe − 20)] = R20 × [1 + ${fmt(kScMinAlpha, 3)} × (${fmt(temp, 0)} − 20)] = R20 × ${fmt(factor, 2)}. '
            'θe는 단락이 끝날 때 도체 온도이며 $insName 단락 최종 온도 ${fmt(temp, 0)}°C(KEC 표 212.5-1)를 씁니다.',
      '① 합계(전원 c = $cTxt${minMva == null ? ', 무한 전원 0' : ''} + 변압기 × KT + 케이블 ${fmt(temp, 0)} ℃ 저항): '
          'R = ${_mo(qR)} + ${_mo(rt * kT)} + ${_mo(cabR)} = ${_mo(totR)} mΩ, '
          'X = ${_mo(qX)} + ${_mo(xt * kT)} + ${_mo(cabX)} = ${_mo(totX)} mΩ. '
          'Z = √(${_mo(totR)}² + ${_mo(totX)}²) = ${_mo(totZ)} mΩ.',
      '② 3상 최소 = c × Un ÷ (√3 × Z) = $cTxt × $uTxt ÷ (√3 × ${_mo(totZ)} mΩ) = ${_ka(r.ikMin3A)} kA.',
      '③ 2상 최소 = 3상 × √3 ÷ 2 = ${_ka(r.ikMin3A)} × 0.866 = ${_ka(r.ikMin2A)} kA.',
    ];
  }

  String _posLabel(int k, int n) {
    if (k == 0) return n == 0 ? '변압기 2차 단자(고장점)' : '변압기 2차 단자';
    return k == n ? '구간 $k 끝(고장점)' : '구간 $k 끝';
  }

  Widget _segCard(int i) {
    final r = _rows[i];
    return calcBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '구간 ${i + 1}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: fc.text,
                  ),
                ),
              ),
              calcToggle('ec_sc_seg_${i}_del', '지우기', () {
                _set(() {
                  _rows.removeAt(i).len.dispose();
                  // 차단기 위치·검토 구간은 번호라 지운 구간 뒤는 한 칸씩 당긴다(8차).
                  final moved = scPositionsAfterRemove(_bkPos, _cabSeg, i);
                  _bkPos = moved.bkPos;
                  _cabSeg = moved.cabSeg;
                });
              }),
            ],
          ),
          DropdownButton<double>(
            key: Key('ec_sc_seg_${i}_size'),
            value: r.size,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: fc.surface,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: fc.text,
            ),
            items: [
              for (final s in kCableSizes)
                DropdownMenuItem<double>(
                  value: s,
                  child: Text('${fmt(s)} mm²'),
                ),
            ],
            onChanged: (v) {
              if (v != null) _set(() => r.size = v);
            },
          ),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: calcLabel(
                  '편도 길이 (m)',
                  '이 구간 케이블의 편도 길이입니다. 3상이라 왕복으로 곱하지 않습니다.',
                ),
              ),
              Expanded(
                flex: 4,
                child: TextField(
                  key: Key('ec_sc_seg_${i}_len'),
                  controller: r.len,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: fc.text,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          elecChipGroup(
            '병렬 가닥 수',
            '한 상에 같은 케이블을 나란히 포설한 수입니다. 저항·리액턴스를 가닥 수로 나눕니다.',
            [
              for (final p in const [1, 2, 3, 4])
                calcChip('ec_sc_seg_${i}_p$p', '$p가닥', r.parallel == p, () {
                  _set(() => r.parallel = p);
                }),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _basisLines() => [
    '방식: IEC 60909-0 등가 전압원법을 주로 쓰고 %임피던스법 값을 비교용으로 함께 표시합니다. Ik″ = c·Un / (√3·|Z|).',
    '전압 계수 c(저압 100V~1kV): 최대 단락 cmax 1.05(허용오차 +6%) 또는 1.10(+10%), 최소 단락 cmin 0.95.',
    '변압기: ZT = %Z/100 × U²/S. 부하손을 넣으면 RT = 부하손/S × U²/S, XT = √(ZT² − RT²). 보정계수 KT = 0.95·cmax / (1 + 0.6·xT), xT = XT ÷ (U²/S)를 ZT·RT·XT에 곱합니다.',
    '상위 계통: Z = c·U²/S″k, X = 0.995 Z, R = 0.1 X (IEC 909 8.3.2.1). 넣지 않으면 무한 전원(0)입니다.',
    '케이블: 구리 20°C 저항은 IEC 60228 표 값. 최대 단락은 20°C 그대로(IEC 909 9.1.1.1). 최소 단락은 단락이 끝날 때 도체 온도 θe(PVC 160°C, XLPE·EPR 250°C, KEC 표 212.5-1의 최종 온도)에서 R = R20 × [1 + 0.004 × (θe − 20)]로 올립니다(IEC 909 9.3.1 식 32). 리액턴스 0.096 Ω/km(60Hz).',
    '전동기: 합계 정격전류 = kW×1000 ÷ (√3·U·효율×역률). |ZM| = U ÷ (√3·배수·정격전류)이고 RM/XM = 0.42로 나눕니다. 모선에서는 두 몫의 크기를 더하고, 케이블 끝은 두 전원을 모선에서 묶은 등가 임피던스에 케이블을 더해 구합니다(케이블을 전원마다 따로 더하지 않음). 최대 단락에만 넣습니다. 원문 배수는 5입니다(IEC 909 8.3.2.5).',
    '피크 전류: ip = κ·√2·Ik″, κ = 1.02 + 0.98·e^(−3R/X)(IEC 909 9.1.1.2). R/X는 고장점까지 전체 합입니다. 전동기 분은 저압 전동기 묶음 κM = 1.3(IEC 909 8.3.2.5)입니다.',
    '%임피던스법(비교): c와 KT 없이 공칭 전압 그대로. Ik = Un / (√3·|Z|). 케이블 저항은 같은 20°C 표 값을 씁니다.',
    '최소 단락 2상 = 3상 × √3/2. 최소 단락은 전동기 기여를 뺍니다(IEC 909 9.3.1).',
    '열적 강도: S = Ik·√t / k, t = (k·S/Ik)². k는 구리 PVC 115(70→160°C, 300mm² 이하), XLPE·EPR 143(90→250°C). 5초 이하 단열 계산입니다(KEC 표 212.5-1, 212.5.5 식 212.5-1).',
    '케이블 시작점의 전류로 검토합니다. 차단기가 순시 영역(0.1초 미만)에서 끊으면 제조사 통과 에너지(I²t) 곡선으로 확인하십시오. 통과 에너지를 넣으면 허용 (병렬 수)²·k²·S²와 비교합니다.',
    '원문 대조함: IEC 909:1988(= IS 13234:1992, 무료 공개본)으로 κ 식(9.1.1.2), 상위 계통 Z·X·R(8.3.2.1), 최대 단락 20°C 저항(9.1.1.1), 최소 단락 전동기 제외와 식 32 온도계수 0.004·종료 온도(9.3.1), 저압 전동기 묶음 배수 5·RM/XM 0.42·κM 1.3(8.3.2.5)을 확인했습니다. k 115·143과 5초 상한은 KEC 2026(공고 제2025-227호) 표 212.5-1·식 212.5-1로 확인했습니다.',
    '원문 못 봄(2016판 유료): IEC 60909-0:2016의 전압 계수 c(cmax 1.05·1.10, cmin 0.95)와 변압기 보정계수 KT = 0.95·cmax/(1 + 0.6·xT)는 2차 자료 값 그대로입니다. 1988판 표 I은 230/400V가 cmax 1.00·cmin 0.95, 그 밖의 저압이 cmax 1.05·cmin 1.00이라 지금 값과 다릅니다. 2026-07-23에 IEC 60909-0 3.0판이 나왔으나 보지 못했습니다.',
    '전동기를 무시해도 되는 기준: IEC 909 식 (13)은 전동기 정격전류 합 ≤ 전동기를 뺀 Ik″의 1%입니다. 앱은 이 기준을 자동 적용하지 않고 세 칸이 다 차면 늘 더합니다.',
    '계산에서 뺀 것: 지락(1선) 단락, 발전기 근처 단락(Ib·Ik 감쇠), 차단기·부스바 임피던스, 아크 저항, 150mm² 이상 표피 효과, 병렬 가닥 상호 리액턴스, 300mm² 초과 PVC의 k, 알루미늄 도체, 상위 차단기 한류 효과.',
  ];
}
