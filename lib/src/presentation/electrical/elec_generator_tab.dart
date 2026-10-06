// 전기 설비 계산: 발전기 용량 탭. 현행 GP 방식(KDS 32 20 20:2024, elec_generator_gp.dart)과
// 옛 PG 방식(건축전기설비설계기준, elec_generator.dart)을 고른다. 근거는 docs/전기_발전기_근거.md.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/recent_calc_history.dart';
import '../../core/common_widgets/swipe_to_delete.dart';
import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import 'elec_form_parts.dart';
import 'elec_generator.dart';
import 'elec_generator_gp.dart';

/// GP 방식 전동기 이외 부하 줄(종류·kW·효율·역률).
class _GpRowCtl {
  _GpRowCtl(
    this.id, {
    this.kind = GpLoadKind.general,
    String kw = '',
    String eff = '',
    String pf = '',
  }) : kw = TextEditingController(text: kw),
       eff = TextEditingController(text: eff),
       pf = TextEditingController(text: pf);

  final int id;
  GpLoadKind kind;
  final TextEditingController kw;
  final TextEditingController eff;
  final TextEditingController pf;

  Map<String, String> toJson() => {
    'kind': kind.name,
    'kw': kw.text,
    'eff': eff.text,
    'pf': pf.text,
  };

  void dispose() {
    kw.dispose();
    eff.dispose();
    pf.dispose();
  }
}

/// GP 부하 줄 최대 수.
const int _kGpMaxRows = 20;

/// 줄 칩에 쓰는 짧은 이름.
String _gpKindShort(GpLoadKind k) => switch (k) {
  GpLoadKind.general => '일반',
  GpLoadKind.vvvf => 'VVVF 전동기',
  GpLoadKind.harmonic => 'LED 등',
};

class ElecGeneratorTab extends StatefulWidget {
  const ElecGeneratorTab({super.key, this.history});

  /// "최근 계산 기록"을 다른 탭과 함께 쓸 때 밖에서 만든 기록을 넣는다. 비우면 이 탭만의 기록을 쓴다.
  final RecentCalcLog? history;

  /// 입력값을 남기는 저장 칸.
  static const draftKey = 'elec_generator_draft_v1';

  @override
  State<ElecGeneratorTab> createState() => _ElecGeneratorTabState();
}

class _ElecGeneratorTabState extends State<ElecGeneratorTab>
    with
        CalcFormParts<ElecGeneratorTab>,
        RecentCalcHistoryMixin<ElecGeneratorTab>,
        ElecTabParts<ElecGeneratorTab>,
        AutomaticKeepAliveClientMixin<ElecGeneratorTab> {
  // 탭을 옮겨도 입력이 사라지지 않게 살려 둔다.
  @override
  bool get wantKeepAlive => true;

  @override
  RecentCalcLog get calcLog => widget.history ?? super.calcLog;

  final _load = TextEditingController();
  final _demand = TextEditingController(text: '100');
  final _eff = TextEditingController(text: '85');
  final _pf = TextEditingController(text: '80');
  final _motor = TextEditingController();
  final _beta = TextEditingController();
  final _c = TextEditingController();
  final _xd = TextEditingController();
  final _dv = TextEditingController();
  // 원문은 기동 역률이 불분명하면 0.4를 쓴다.
  final _startPf = TextEditingController(text: '40');
  final _volts = TextEditingController(text: '380');
  final _chosen = TextEditingController();

  // 방식: 'gp'(현행) / 'pg'(옛 기준). 저장 칸에 함께 남기려고 글 칸으로 둔다.
  final _mode = TextEditingController(text: 'gp');
  bool get _gp => _mode.text != 'pg';

  // GP 방식 칸. 전동기 이외 부하는 줄 목록이고 저장 칸에는 'gRows'로 남긴다.
  final List<_GpRowCtl> _gRows = [_GpRowCtl(0)];
  int _nextRowId = 1;
  final _gUps = TextEditingController();
  final _gUpsEff = TextEditingController();
  final _gCharge = TextEditingController();
  final _gLambda = TextEditingController();
  final _gMotors = TextEditingController();
  final _gLargest = TextEditingController();
  final _gC = TextEditingController();
  final _gK = TextEditingController();
  // 표 4.1-1에서 누른 칸(허용 전압강하 %, x″d %). k를 직접 고치면 결과에 '직접 입력한 값'으로 적는다.
  final _gKDv = TextEditingController();
  final _gKXd = TextEditingController();
  final _gA = TextEditingController(text: '1.45');

  List<(TextEditingController, String)> get _texts => [
    (_load, 'load'),
    (_demand, 'demand'),
    (_eff, 'eff'),
    (_pf, 'pf'),
    (_motor, 'motor'),
    (_beta, 'beta'),
    (_c, 'c'),
    (_xd, 'xd'),
    (_dv, 'dv'),
    (_startPf, 'startPf'),
    (_volts, 'volts'),
    (_chosen, 'chosen'),
    (_mode, 'mode'),
    (_gUps, 'gUps'),
    (_gUpsEff, 'gUpsEff'),
    (_gCharge, 'gCharge'),
    (_gLambda, 'gLambda'),
    (_gMotors, 'gMotors'),
    (_gLargest, 'gLargest'),
    (_gA, 'gA'),
    (_gC, 'gC'),
    (_gK, 'gK'),
    (_gKDv, 'gKDv'),
    (_gKXd, 'gKXd'),
  ];

  Timer? _saveTimer;
  String? _lastDraft;
  String? _pendingDraft;
  bool _draftReady = false;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _flushDraft();
    for (final (c, _) in _texts) {
      c.dispose();
    }
    for (final r in _gRows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(ElecGeneratorTab.draftKey);
      if (raw != null && mounted) {
        final m = jsonDecode(raw);
        if (m is Map<String, dynamic>) {
          setState(() {
            for (final (c, k) in _texts) {
              if (m[k] is String) c.text = m[k] as String;
            }
            _readRows(m);
          });
        }
      }
      _lastDraft = raw;
    } catch (_) {
      // 저장 칸을 못 읽어도 기본값으로 쓴다.
    }
    _draftReady = true;
  }

  void _scheduleSave() {
    if (!_draftReady) return;
    final raw = jsonEncode({
      for (final (c, k) in _texts) k: c.text,
      'gRows': [for (final r in _gRows) r.toJson()],
    });
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
      await prefs.setString(ElecGeneratorTab.draftKey, raw);
    } catch (_) {
      // 저장을 못 해도 계산에는 지장이 없다.
    }
  }

  /// 칸을 숫자로 읽는다. 비면 null, 숫자가 아니면 bad에 이름을 적는다.
  /// [pct]인 칸(수용률·효율·역률)은 %로 넣는다: 1을 넘으면 100으로 나눠 비율로 바꾼다(0.85도 그대로 받는다).
  double? _read(
    TextEditingController c,
    String label,
    List<String> bad, {
    bool pct = false,
  }) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    var v = readNum(c);
    if (v == null) {
      bad.add('$label: 숫자가 아닙니다.');
    } else if (pct && v > 1) {
      v = v / 100;
    }
    return v;
  }

  GenStartKind get _kind {
    final v = readNum(_c);
    for (final k in GenStartKind.values) {
      if (k.c != null && v != null && (v - k.c!).abs() < 1e-9) return k;
    }
    return GenStartKind.custom;
  }

  GenStartClass? get _class {
    final v = readNum(_beta);
    for (final k in GenStartClass.values) {
      if (v != null && (v - k.beta).abs() < 1e-9) return k;
    }
    return null;
  }

  /// 맨 위 방식 고르기.
  Widget _modeChips() => elecChipGroup(
    '산정 방식',
    'GP 방식: 현행 국가건설기준 KDS 32 20 20:2024(예비전원설비) 식 4.1-1입니다. 새 설계는 이것을 씁니다.\n'
        'PG 방식: 옛 건축전기설비설계기준(국토교통부)의 식입니다. 원문은 사이리스터(고조파) 부하가 없을 때만 쓰라고 합니다. '
        '이미 시행 중인 설계는 발주기관이 인정하면 종전 기준을 쓸 수 있습니다.',
    [
      calcChip(
        'eg_mode_gp',
        'GP 방식 (현행)',
        _gp,
        () => setState(() => _mode.text = 'gp'),
      ),
      calcChip(
        'eg_mode_pg',
        'PG 방식 (옛 기준)',
        !_gp,
        () => setState(() => _mode.text = 'pg'),
      ),
    ],
  );

  /// 표 4.1-1을 그대로 보여 주고 칸을 누르면 k로 쓴다.
  Widget _kTable() {
    final cur = readNum(_gK);
    final picked = _kCell;
    Widget cell(
      String t, {
      bool head = false,
      double? v,
      String? key,
      int? dv,
      int? xd,
    }) {
      // 누른 칸이 있으면 그 칸만, 없으면(직접 넣은 k) 같은 값인 칸을 칠한다(표에 같은 값이 여러 칸 있다).
      final sel =
          v != null &&
          (picked != null
              ? picked == (dv, xd)
              : cur != null && (cur - v).abs() < 1e-9);
      final child = Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: sel ? fc.brand : null,
        child: Text(
          t,
          style: TextStyle(
            fontSize: 13,
            fontWeight: head || sel ? FontWeight.w800 : FontWeight.w500,
            color: sel ? fc.onBrand : (head ? fc.textSub : fc.text),
          ),
        ),
      );
      if (v == null) return child;
      return InkWell(
        key: key == null ? null : Key(key),
        onTap: () => setState(() {
          _gK.text = v.toStringAsFixed(2);
          _gKDv.text = dv == null ? '' : '$dv';
          _gKXd.text = xd == null ? '' : '$xd';
        }),
        child: child,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        calcLabel(
          '표 4.1-1 허용전압강하 계수 k',
          '가로는 발전기 x″d(%), 세로는 허용 전압강하율(%)입니다. 칸을 누르면 그 값을 k로 씁니다. '
              '원문에는 표 사이 값을 구하는 규칙이 없습니다. 명확하지 않으면 원문대로 1.07~1.13을 넣으십시오.',
        ),
        const SizedBox(height: 4),
        Container(
          key: const Key('eg_k_table'),
          decoration: BoxDecoration(
            color: fc.surface,
            border: Border.all(color: fc.line),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Table(
            border: TableBorder.symmetric(inside: BorderSide(color: fc.line)),
            children: [
              TableRow(
                children: [
                  cell('ΔV·x″d', head: true),
                  for (final x in kGpXdPcts) cell('$x', head: true),
                ],
              ),
              for (var r = 0; r < kGpDvPcts.length; r++)
                TableRow(
                  children: [
                    cell('${kGpDvPcts[r]}', head: true),
                    for (var c = 0; c < kGpXdPcts.length; c++)
                      cell(
                        kGpKTable[r][c].toStringAsFixed(2),
                        v: kGpKTable[r][c],
                        key: 'eg_k_${kGpDvPcts[r]}_${kGpXdPcts[c]}',
                        dv: kGpDvPcts[r],
                        xd: kGpXdPcts[c],
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ─────────────── GP 부하 줄 ───────────────

  /// 저장 칸의 줄 목록을 읽는다. 예전 저장값(일반·VVVF·LED 칸 + 같이 쓰는 효율·역률)은 줄로 옮긴다.
  void _readRows(Map<String, dynamic> m) {
    final list = m['gRows'];
    final rows = <_GpRowCtl>[];
    if (list is List) {
      for (final e in list) {
        if (e is! Map || rows.length >= _kGpMaxRows) continue;
        String s(String k) => e[k] is String ? e[k] as String : '';
        final kind = GpLoadKind.values.firstWhere(
          (k) => k.name == e['kind'],
          orElse: () => GpLoadKind.general,
        );
        rows.add(
          _GpRowCtl(
            _nextRowId++,
            kind: kind,
            kw: s('kw'),
            eff: s('eff'),
            pf: s('pf'),
          ),
        );
      }
    } else {
      String s(String k) => m[k] is String ? (m[k] as String).trim() : '';
      for (final (key, kind) in [
        ('gGeneral', GpLoadKind.general),
        ('gVvvf', GpLoadKind.vvvf),
        ('gLed', GpLoadKind.harmonic),
      ]) {
        if (s(key).isEmpty) continue;
        rows.add(
          _GpRowCtl(
            _nextRowId++,
            kind: kind,
            kw: s(key),
            eff: s('gEff'),
            pf: s('gPf'),
          ),
        );
      }
    }
    if (rows.isEmpty) return;
    final old = List.of(_gRows);
    _gRows
      ..clear()
      ..addAll(rows);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final r in old) {
        r.dispose();
      }
    });
  }

  /// 줄을 더한다. 효율·역률은 바로 위 줄 값을 그대로 가져와 같은 값이면 다시 안 넣게 한다.
  void _addRow() {
    if (_gRows.length >= _kGpMaxRows) return;
    final last = _gRows.isEmpty ? null : _gRows.last;
    setState(
      () => _gRows.add(
        _GpRowCtl(
          _nextRowId++,
          eff: last?.eff.text ?? '',
          pf: last?.pf.text ?? '',
        ),
      ),
    );
  }

  /// 밀어서 지운 줄을 곧바로 빼고, "되돌리기"를 누르면 같은 값으로 같은 자리에 다시 넣는다.
  /// 마지막 한 줄은 밀리지 않는다.
  void _removeRow(_GpRowCtl r) {
    final i = _gRows.indexOf(r);
    if (i < 0 || _gRows.length <= 1) return;
    final saved = r.toJson();
    final kind = r.kind;
    setState(() {
      _gRows.removeAt(i);
      WidgetsBinding.instance.addPostFrameCallback((_) => r.dispose());
    });
    showDeleteUndo(
      context,
      '부하 ${i + 1}',
      onUndo: () {
        if (!mounted || _gRows.length >= _kGpMaxRows) return;
        setState(
          () => _gRows.insert(
            i.clamp(0, _gRows.length),
            _GpRowCtl(
              _nextRowId++,
              kind: kind,
              kw: saved['kw']!,
              eff: saved['eff']!,
              pf: saved['pf']!,
            ),
          ),
        );
      },
    );
  }

  Widget _rowCell(
    String key,
    String label,
    TextEditingController c,
  ) => TextField(
    key: Key(key),
    controller: c,
    textAlign: TextAlign.right,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textInputAction: TextInputAction.next,
    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: fc.text),
    decoration: InputDecoration(
      isDense: true,
      labelText: label,
      // 칸이 좁아 비었을 때 이름이 잘리지 않게 이름표를 늘 위에 둔다.
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: TextStyle(fontSize: 13, color: fc.textSub),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: fc.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: fc.brand, width: 1.5),
      ),
    ),
    onChanged: (_) => setState(() {}),
  );

  Widget _rowCard(int i, _GpRowCtl r) => KeyedSubtree(
    key: ValueKey('eg_rowbox_${r.id}'),
    child: SwipeToDelete(
      itemKey: ValueKey('eg_swipe_${r.id}'),
      radius: 14,
      enabled: _gRows.length > 1,
      onDelete: () => _removeRow(r),
      child: calcBox(
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8, right: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '부하 ${i + 1}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: fc.brand,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final k in GpLoadKind.values)
                          calcChip(
                            'eg_kind_${i}_${k.name}',
                            _gpKindShort(k),
                            r.kind == k,
                            () => setState(() => r.kind = k),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: _rowCell('eg_row_kw_$i', '용량 (kW)', r.kw),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: _rowCell('eg_row_eff_$i', '효율 (%)', r.eff),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: _rowCell('eg_row_pf_$i', '역률 (%)', r.pf),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  /// 고른 k가 표 4.1-1의 어느 칸인지(칸을 눌러 고르고 그 뒤 k를 고치지 않았을 때만).
  (int, int)? get _kCell {
    final dv = int.tryParse(_gKDv.text.trim());
    final xd = int.tryParse(_gKXd.text.trim());
    final k = readNum(_gK);
    if (dv == null || xd == null || k == null) return null;
    final t = gpKFromTable(dv, xd);
    if (t == null || (t - k).abs() > 1e-9) return null;
    return (dv, xd);
  }

  GpStart? get _gpStart {
    final v = readNum(_gC);
    for (final s in GpStart.values) {
      if (v != null && (v - s.c).abs() < 1e-9) return s;
    }
    return null;
  }

  Widget _gpPage() {
    final bad = <String>[];
    final aVal = _read(_gA, 'a', bad);
    final cVal = _read(_gC, '기동계수 c', bad);
    final hasMotor = (readNum(_gMotors) ?? 0) > 0;
    if (hasMotor && (aVal == null || aVal <= 0)) {
      bad.add('a를 0보다 크게 넣으십시오(고효율 1.38, 표준형 1.45).');
    }
    if (hasMotor && (cVal == null || cVal <= 0)) {
      bad.add('기동계수 c를 고르거나 넣으십시오.');
    }
    final input = GpInput(
      loads: [
        for (var n = 0; n < _gRows.length; n++)
          GpLoad(
            kind: _gRows[n].kind,
            kw: _read(_gRows[n].kw, '부하 ${n + 1} 용량', bad),
            eff: _read(_gRows[n].eff, '부하 ${n + 1} 효율', bad, pct: true),
            pf: _read(_gRows[n].pf, '부하 ${n + 1} 역률', bad, pct: true),
          ),
      ],
      upsKva: _read(_gUps, 'UPS 출력', bad),
      upsEff: _read(_gUpsEff, 'UPS 효율', bad, pct: true),
      upsChargePct: _read(_gCharge, '축전지 충전용량', bad),
      lambda: _read(_gLambda, 'λ', bad),
      motorsKw: _read(_gMotors, '전동기 합계', bad),
      largestKw: _read(_gLargest, '가장 큰 전동기', bad),
      a: aVal ?? 0,
      c: cVal ?? 0,
      k: _read(_gK, 'k', bad),
    );
    final anyInput = [
      for (final r in _gRows) r.kw,
      _gUps,
      _gMotors,
    ].any((c) => c.text.trim().isNotEmpty);
    final r = calcGp(input);
    final errors = [...bad, if (bad.isEmpty) ...r.errors];

    Widget result;
    String? summary;
    var warn = false;
    if (!anyInput) {
      result = calcResult(
        solve: true,
        key: const Key('eg_gp_result'),
        big: '—',
        caption: '부하를 넣으면 필요 발전기 용량을 계산합니다',
        lines: const [],
      );
    } else if (errors.isNotEmpty) {
      warn = true;
      summary = '입력 확인';
      result = calcResult(
        solve: true,
        key: const Key('eg_gp_result'),
        big: '입력 확인',
        caption: '다음 입력값을 고치십시오',
        warn: true,
        lines: errors,
      );
    } else {
      final gp = r.gp!;
      final chosen = readNum(_chosen);
      final volts = readNum(_volts);
      final pass = chosen == null ? null : chosen + 1e-9 >= gp;
      warn = pass == false;
      summary = '필요 ${fmt(gp, 0)} kVA (GP 방식)';
      final lam = input.lambda ?? 1;
      final kCell = _kCell;
      // 단계 번호는 실제로 나오는 줄에만 차례로 붙인다(전동기가 없으면 건너뛰지 않게).
      var step = 0;
      String mark() => '①②③④⑤'[step++];
      final parts = [
        for (final p in r.loadP)
          if (p > 0) p,
        if (r.pUps > 0) r.pUps,
      ];
      result = calcResult(
        solve: true,
        key: const Key('eg_gp_result'),
        big: '${fmt(gp, 1)} kVA',
        caption: '필요 발전기 용량 GP (KDS 32 20 20 식 4.1-1)',
        warn: warn,
        lines: [
          for (var n = 0; n < input.loads.length; n++)
            if (r.loadP[n] > 0)
              '부하 ${n + 1} ${_gpKindShort(input.loads[n].kind)} P = ${fmt(input.loads[n].kw!, 1)} ÷ (${fmt(input.loads[n].eff!, 2)} × ${fmt(input.loads[n].pf!, 2)})${input.loads[n].kind.usesLambda ? ' × ${fmt(lam, 2)}' : ''} = ${fmt(r.loadP[n], 1)} kVA',
          if (r.pUps > 0)
            'UPS P = 출력 ÷ 효율 × λ + 충전용량 = ${fmt(input.upsKva!, 1)} ÷ ${fmt(input.upsEff!, 2)} × ${fmt(lam, 2)} + ${fmt(r.upsCharge, 1)} = ${fmt(r.pUps, 1)} kVA',
          parts.length > 1 && parts.length <= 6
              ? '${mark()} 전동기 이외 부하 합계 ΣP = ${parts.map((p) => fmt(p, 1)).join(' + ')} = ${fmt(r.sumP, 1)} kVA'
              : '${mark()} 전동기 이외 부하 합계 ΣP = ${fmt(r.sumP, 1)} kVA',
          if (hasMotor)
            '${mark()} 기동하지 않는 전동기 (ΣPm − PL) × a = (${fmt(input.motorsKw!, 1)} − ${fmt(input.largestKw ?? 0, 1)}) × ${fmt(input.a, 2)} = ${fmt(r.motorRest, 1)} kVA',
          if (hasMotor)
            '${mark()} 가장 큰 전동기 기동 PL × a × c = ${fmt(input.largestKw ?? 0, 1)} × ${fmt(input.a, 2)} × ${fmt(input.c, 2)} = ${fmt(r.motorStart, 1)} kVA',
          '${mark()} GP = [ΣP + (ΣPm − PL) × a + PL × a × c] × k = (${fmt(r.sumP, 1)} + ${fmt(r.motorRest, 1)} + ${fmt(r.motorStart, 1)}) × ${input.k!.toStringAsFixed(2)} = ${fmt(gp, 1)} kVA',
          kCell == null
              ? 'k ${input.k!.toStringAsFixed(2)}: 직접 입력한 값입니다.'
              : 'k ${input.k!.toStringAsFixed(2)}: 표 4.1-1에서 허용 전압강하 ${kCell.$1} %, x″d ${kCell.$2} % 칸을 고른 값입니다.',
          if (volts != null && volts > 0)
            '정격전류 = ${fmt(gp, 1)} × 1000 ÷ (√3 × ${fmt(volts, 0)}) = ${fmt(genRatedCurrent(gp, volts), 0)} A',
          if (pass != null)
            pass
                ? '선정 ${fmt(chosen!, 0)} kVA: 합격 (여유 ${fmt((chosen / gp - 1) * 100, 1)}%)'
                : '선정 ${fmt(chosen!, 0)} kVA: 불합격 (필요 ${fmt(gp, 1)} kVA)',
          '발전기 용량은 NFPC 103 제12조(스프링클러설비) 기준도 충족해야 하고, 관계 법령의 부하 용량·공급시간을 검토해 정합니다(KDS 32 20 20 4.1(6)①②).',
        ],
      );
    }

    final start = _gpStart;
    return elecPage(sumKey: 'eg_sum', summary: summary, warn: warn, [
      _modeChips(),
      elecSectionTitle('전동기 이외 부하 (ΣP)'),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          '부하마다 종류·용량·효율·역률을 넣습니다. 일반은 P = kW ÷ (효율 × 역률)(식 4.1-2), '
          'VVVF(인버터) 전동기와 LED 등 고조파 부하는 여기에 λ를 곱합니다(식 4.1-4·4.1-5). '
          'VVVF 전동기는 아래 전동기 부하에 넣지 않습니다. 줄을 옆으로 밀면 지웁니다.',
          style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.4),
        ),
      ),
      for (var i = 0; i < _gRows.length; i++) _rowCard(i, _gRows[i]),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          key: const Key('eg_add'),
          onPressed: _gRows.length >= _kGpMaxRows ? null : _addRow,
          icon: const Icon(Icons.add_rounded),
          label: Text('부하 추가 (${_gRows.length}/$_kGpMaxRows)'),
        ),
      ),
      const SizedBox(height: 12),
      elecField(
        'eg_g_ups',
        'UPS 출력 (kVA)',
        _gUps,
        'P = UPS 출력 ÷ UPS 효율 × λ + 축전지 충전용량(식 4.1-3).',
      ),
      elecField('eg_g_upseff', 'UPS 효율 (%)', _gUpsEff, 'UPS 명판의 효율입니다.'),
      elecField(
        'eg_g_charge',
        '축전지 충전용량 (UPS 용량의 %)',
        _gCharge,
        '원문은 UPS 용량의 6~10 %를 적용합니다.',
      ),
      elecField(
        'eg_g_lambda',
        'THD 가중값 λ',
        _gLambda,
        'KS C IEC 61000-3-6 표 6을 참고합니다. 고조파 발생 기기의 특성을 모르면 2.5를 적용하고, '
            '발전기로 들어가는 고조파 저감장치를 달면 기기별로 조정할 수 있습니다(KDS 32 20 20).',
      ),
      elecSectionTitle('전동기 부하'),
      elecField(
        'eg_g_motors',
        '전동기 부하 합계 ΣPm (kW)',
        _gMotors,
        'VVVF(인버터) 제어 전동기는 빼고 넣습니다.',
      ),
      elecField(
        'eg_g_largest',
        '기동용량이 가장 큰 전동기 PL (kW)',
        _gLargest,
        '동시에 기동하는 전동기가 있으면 그 용량을 더해 넣습니다.',
      ),
      elecChipGroup(
        'kW당 입력용량 계수 a',
        '원문 추천값: 고효율 1.38, 표준형 1.45. 전동기별 효율·역률로 입력용량을 환산해도 됩니다.',
        [
          calcChip(
            'eg_a_high',
            '고효율 1.38',
            readNum(_gA) == kGpAHighEff,
            () => setState(() => _gA.text = '1.38'),
          ),
          calcChip(
            'eg_a_std',
            '표준형 1.45',
            readNum(_gA) == kGpAStandard,
            () => setState(() => _gA.text = '1.45'),
          ),
        ],
      ),
      elecField('eg_g_a', 'a', _gA, '위 칩 대신 직접 넣을 수 있습니다.'),
      elecChipGroup(
        '기동 방식 (기동계수 c)',
        '원문 추천값: 직입 6(5~7), Y-Δ 2(2~3), VVVF 1.5(1~1.5), 리액터 탭 50 %·65 %·80 % = 3·3.9·4.8.',
        [
          for (final s in GpStart.values)
            calcChip(
              'eg_c_${s.name}',
              '${s.label} ${fmt(s.c, 1)}',
              start == s,
              () => setState(() => _gC.text = fmt(s.c, 1)),
            ),
        ],
      ),
      elecField(
        'eg_g_c',
        '기동계수 c',
        _gC,
        start?.range == null
            ? '위 칩을 고르거나 직접 넣습니다.'
            : '${start!.label}의 원문 범위는 ${start.range}입니다.',
      ),
      elecSectionTitle('허용전압강하 계수 k'),
      _kTable(),
      elecField(
        'eg_g_k',
        'k',
        _gK,
        '표에서 고르거나 직접 넣습니다. 명확하지 않으면 1.07~1.13(원문).',
      ),
      elecSectionTitle('결과'),
      elecField('eg_volts', '발전기 전압 (V)', _volts, '3상 선간전압입니다. 정격전류 계산에 씁니다.'),
      elecField(
        'eg_chosen',
        '선정 용량 (kVA, 선택)',
        _chosen,
        '제조사 표준 용량 중 고른 값을 넣으면 합격/불합격을 판정합니다.',
      ),
      const SizedBox(height: 12),
      result,
      elecBasis('eg_gp_basis', [
        '원문: 국가건설기준 KDS 32 20 20:2024 예비전원설비 4.1(6)④ 식 4.1-1~4.1-5와 표 4.1-1(국토교통부고시 제2026-93호 첨부, 2024-08-22 개정).',
        'GP ≥ [ΣP + (ΣPm − PL) × a + (PL × a × c)] × k',
        '표 4.1-1은 2024 개정에서 2021판(KDS 31 60 20)의 오타 세 칸(19 %행 20·21 열, 16 %행 23 열)을 바로잡은 값입니다.',
        '2021판과 다른 점: 2024판은 VVVF 전동기를 ΣP에 넣고 ΣPm에서 뺍니다. λ는 모르면 2.5입니다(2021판은 저감장치가 있으면 1.25).',
        '발전기 용량은 화재 및 예고 없는 정전 때에도 소방·비상부하 가동에 지장이 없어야 합니다(4.1(6)③).',
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _scheduleSave();
    if (_gp) return _gpPage();
    final bad = <String>[];
    final input = GenInput(
      loadKw: _read(_load, '부하 합계', bad),
      demand: _read(_demand, '수용률', bad, pct: true),
      eff: _read(_eff, '효율', bad, pct: true),
      pf: _read(_pf, '역률', bad, pct: true),
      motorKw: _read(_motor, '가장 큰 전동기', bad),
      beta: _read(_beta, 'β', bad),
      startC: _read(_c, '기동 방식 계수', bad),
      xdPct: _read(_xd, 'X″d', bad),
      dvPct: _read(_dv, '허용 전압강하', bad),
      startPf: _read(_startPf, '기동 역률', bad, pct: true),
      volts: _read(_volts, '발전기 전압', bad),
      chosenKva: _read(_chosen, '선정 용량', bad),
    );
    final empty = _load.text.trim().isEmpty && bad.isEmpty;
    final r = calcGenerator(input);
    final errors = [...bad, if (bad.isEmpty) ...r.errors];

    Widget result;
    String? summary;
    var warn = false;
    if (empty) {
      result = calcResult(
        solve: true,
        key: const Key('eg_result'),
        big: '—',
        caption: '부하 합계를 넣으면 필요 발전기 용량을 계산합니다',
        lines: const [],
      );
    } else if (errors.isNotEmpty) {
      warn = true;
      summary = '입력 확인';
      result = calcResult(
        solve: true,
        key: const Key('eg_result'),
        big: '입력 확인',
        caption: '다음 입력값을 고치십시오',
        warn: true,
        lines: errors,
      );
    } else {
      final req = r.required!;
      final fail = r.chosenPass == false;
      warn = fail;
      summary = '필요 ${fmt(req, 0)} kVA (${r.governing})';
      result = calcResult(
        solve: true,
        key: const Key('eg_result'),
        big: '${fmt(req, 1)} kVA',
        caption: '필요 발전기 용량 (${r.governing} 기준)',
        warn: fail,
        lines: [
          '① PG1 정상 운전: ${fmt(r.pg1!, 1)} kVA = ${fmt(input.loadKw!, 1)} × '
              '${fmt(input.demand!, 2)} ÷ (${fmt(input.eff!, 2)} × ${fmt(input.pf!, 2)})',
          if (r.pg2 != null)
            '② PG2 전동기 기동 전압강하: ${fmt(r.pg2!, 1)} kVA = ${fmt(input.motorKw!, 1)} × '
                '${fmt(input.beta!, 2)} × ${fmt(input.startC!, 2)} × ${fmt(input.xdPct! / 100, 3)} '
                '× (1 − ${fmt(input.dvPct! / 100, 3)}) ÷ ${fmt(input.dvPct! / 100, 3)}',
          if (r.pg3 != null)
            '③ PG3 마지막 전동기 기동: ${fmt(r.pg3!, 1)} kVA = [(${fmt(input.loadKw!, 1)} − '
                '${fmt(input.motorKw!, 1)}) ÷ ${fmt(input.eff!, 2)} + ${fmt(input.motorKw!, 1)} × '
                '${fmt(input.beta!, 2)} × ${fmt(input.startC!, 2)} × ${fmt(r.startPfUsed!, 2)}] '
                '÷ ${fmt(input.pf!, 2)}',
          '④ 가장 큰 값을 필요 용량으로 합니다: max(${['PG1 ${fmt(r.pg1!, 1)}', if (r.pg2 != null) 'PG2 ${fmt(r.pg2!, 1)}', if (r.pg3 != null) 'PG3 ${fmt(r.pg3!, 1)}'].join(', ')}) = ${fmt(req, 1)} kVA (${r.governing})',
          if (r.currentA != null)
            '정격전류: ${fmt(r.currentA!, 0)} A = ${fmt(req, 1)} kVA × 1000 ÷ (√3 × ${fmt(input.volts!, 0)} V)',
          if (r.chosenPass != null)
            r.chosenPass!
                ? '선정 ${fmt(input.chosenKva!, 0)} kVA: 합격 (여유 ${fmt(r.chosenMarginPct!, 1)}%)'
                : '선정 ${fmt(input.chosenKva!, 0)} kVA: 불합격 (필요 ${fmt(req, 1)} kVA에 ${fmt(-r.chosenMarginPct!, 1)}% 부족)',
          ...r.notes,
          '고조파(사이리스터) 부하가 있으면 PG 방식을 쓰지 않습니다(원문 3.1.2(1)). 위 "GP 방식"을 쓰십시오.',
          '최종 용량은 제조사 검토로 확정합니다.',
          '현행 기준(KDS 32 20 20:2024)은 GP 방식입니다. 새 설계는 위 "GP 방식"을 쓰십시오.',
        ],
      );
    }

    return elecPage(sumKey: 'eg_sum', summary: summary, warn: warn, [
      _modeChips(),
      elecSectionTitle('부하'),
      elecField(
        'eg_load',
        '부하 합계 (kW)',
        _load,
        '정상 운전 때 발전기에 걸리는 부하의 출력 합계입니다. 전동기 부하도 포함합니다. 부하 일람표의 kW를 더해 넣으십시오.',
      ),
      elecField(
        'eg_demand',
        '수용률 (α, %)',
        _demand,
        '부하가 한꺼번에 다 걸리지 않을 때 줄이는 비율입니다. 근거가 없으면 100으로 두십시오. 100을 초과해 넣을 수 없습니다.',
      ),
      elecField(
        'eg_eff',
        '부하 종합 효율 (%)',
        _eff,
        '원문은 불분명하면 85%(0.85)를 씁니다. 부하 자료가 있으면 그 값을 넣으십시오.',
      ),
      elecField(
        'eg_pf',
        '부하 종합 역률 (%)',
        _pf,
        '원문은 불분명하면 80%(0.8)를 씁니다. PG1과 PG3에 같이 씁니다. 부하 자료가 있으면 그 값을 넣으십시오.',
      ),
      elecSectionTitle('가장 큰 전동기'),
      elecField(
        'eg_motor',
        '전동기 출력 (kW)',
        _motor,
        '기동 용량이 가장 큰 전동기의 출력입니다. 없으면 비워 두십시오. 그러면 PG2와 PG3는 계산하지 않습니다.',
      ),
      elecChipGroup(
        '기동 방식',
        '기동 방식 계수 C(원문 3.1.1(5) 표): 직입 1.0, Y-Δ 0.67, 리액터 65% 0.65, 리액터 80% 0.80, '
            '콘돌퍼 50%·65%·80% 0.25·0.42·0.64.\n'
            '소프트스타터·인버터는 원문 표에 없으니 제조사 자료로 계수를 직접 넣으십시오.',
        [
          for (final k in GenStartKind.values)
            calcChip('eg_start_${k.name}', k.label, _kind == k, () {
              setState(() {
                if (k.c != null) {
                  _c.text = fmt(k.c!, 2);
                } else {
                  _c.clear();
                }
              });
            }),
        ],
      ),
      elecField(
        'eg_c',
        '기동 방식 계수 (C)',
        _c,
        '위 기동 방식을 고르면 값이 채워집니다. 다른 방식은 제조사 자료 값을 직접 넣으십시오.',
      ),
      elecChipGroup(
        '기동 계급 (β)',
        '원문 표의 기동 계급별 β(전동기 출력 1kW당 기동 입력 kVA, 범위 가운데 값): '
            'E 6.35, F 7.2, G 8.0, H 9.0, J 10.1, K 11.4.\n'
            '전동기 명판의 기동 계급(코드 문자)을 보고 고르십시오.',
        [
          for (final k in GenStartClass.values)
            calcChip(
              'eg_beta_${k.name}',
              '${k.label} ${k.beta}',
              _class == k,
              () => setState(() => _beta.text = '${k.beta}'),
            ),
        ],
      ),
      elecField(
        'eg_beta',
        '기동 kVA/kW (β)',
        _beta,
        '전동기 출력 1kW당 기동 입력(kVA)입니다. 위 기동 계급을 고르면 채워집니다. 7.2는 F 계급 값입니다. 계급을 모르면 제조사 자료로 확인하십시오.',
      ),
      elecField(
        'eg_xd',
        '발전기 X″d (%)',
        _xd,
        '발전기 명판이나 제조사 자료의 과도 리액턴스입니다. 원문은 보통 20~25%라고 적었습니다. 발전기마다 다르니 제조사 값을 넣으십시오.',
      ),
      elecField(
        'eg_dv',
        '허용 전압강하 ΔV (%)',
        _dv,
        '전동기 기동 순간에 발전기 전압이 떨어져도 되는 비율입니다. 승강기가 있으면 20 %, 그 밖에는 25 %(원문 3.1.2(4)).',
      ),
      elecField(
        'eg_startpf',
        '기동 역률 (%, PG3)',
        _startPf,
        '전동기 기동 때의 역률(Pfm)입니다. 원문은 불분명하면 40%(0.4)를 씁니다. 제조사 자료가 있으면 그 값을 넣으십시오. 비우면 PG3를 계산하지 않습니다.',
      ),
      elecSectionTitle('결과'),
      elecField('eg_volts', '발전기 전압 (V)', _volts, '3상 선간전압입니다. 정격전류 계산에 씁니다.'),
      elecField(
        'eg_chosen',
        '선정 용량 (kVA, 선택)',
        _chosen,
        '제조사 표준 용량 중 고른 값을 넣으면 합격/불합격을 판정합니다.',
      ),
      const SizedBox(height: 12),
      result,
      elecBasis('eg_basis', [
        '원문: 건축전기설비설계기준(국토교통부) 제5장 예비전원설비 3.1.1~3.1.2 PG 방식. 필요 용량은 PG1, PG2, PG3 중 큰 값입니다.',
        'PG1 = 부하 kW × 수용률 ÷ (효율 × 역률). 효율·역률이 불분명하면 0.85·0.8을 씁니다.',
        'PG2 = 전동기 kW × β × C × X″d × (1 − ΔV) ÷ ΔV. 가장 큰 전동기를 기동할 때 허용 전압강하 조건입니다.',
        'PG3 = [(부하 − 전동기) ÷ 효율 + 전동기 × β × C × 기동 역률] ÷ 부하 역률. 마지막 전동기를 기동할 때 조건입니다. PG1과 같은 부하 종합 역률로 나눕니다. 기동 역률이 불분명하면 0.4를 씁니다.',
        '원문은 사이리스터(고조파) 부하가 없을 때만 PG 방식을 씁니다(3.1.2(1)). 고조파 가산식은 원문에 없어 넣지 않았습니다.',
        'C 표의 리액터 50%는 원문에 65%와 같은 0.65로 적혀 있어 오타로 보고 넣지 않았습니다.',
        'β를 0.72로 적은 정리 글이 있으나 원문 값이 아닙니다. 7.2는 F 계급 값입니다.',
        '넣지 않은 것: RG 방식, 단상 부하 불평형 보정, 고도·온도 출력 감소, 연료·환기 조건.',
      ]),
    ]);
  }
}
