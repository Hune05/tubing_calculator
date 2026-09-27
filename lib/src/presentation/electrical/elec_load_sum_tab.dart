// 전기 설계 계산 "부하 합산" 탭: 부하 목록으로 최대수요전력·필요 변압기 용량·2차 정격전류를 계산하고,
// 부하 계산서(PDF)로 내보내며, 이름 붙여 폰에만 저장한다. 계산은 elec_load_sum.dart, 근거는 docs/전기_부하합산_근거.md.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/field_view.dart';
import '../../data/record_sync.dart';
import '../common/calc_form_parts.dart';
import 'elec_form_parts.dart';
import 'elec_load_sum.dart';
import 'elec_load_sum_pdf.dart';

/// 입력값을 남기는 저장 칸 이름.
const String kLoadSumDraftKey = 'elec_load_sum_draft_v1';

class _RowCtl {
  final int id;
  final TextEditingController name;
  final TextEditingController kw;
  final TextEditingController pf;
  final TextEditingController df;

  _RowCtl(this.id, [LoadRowInput r = const LoadRowInput()])
    : name = TextEditingController(text: r.name),
      kw = TextEditingController(text: r.kw),
      pf = TextEditingController(text: r.pf),
      df = TextEditingController(text: r.df);

  LoadRowInput get input =>
      LoadRowInput(name: name.text, kw: kw.text, pf: pf.text, df: df.text);

  void dispose() {
    name.dispose();
    kw.dispose();
    pf.dispose();
    df.dispose();
  }
}

class ElecLoadSumTab extends StatefulWidget {
  const ElecLoadSumTab({super.key, this.onSendToShortCircuit});

  /// 변압기 용량(kVA)과 2차 전압(V)을 단락 전류 탭으로 넘긴다. 없으면 단추를 보이지 않는다.
  final void Function(double kva, double volts)? onSendToShortCircuit;

  @override
  State<ElecLoadSumTab> createState() => _ElecLoadSumTabState();
}

class _ElecLoadSumTabState extends State<ElecLoadSumTab>
    with
        CalcFormParts<ElecLoadSumTab>,
        ElecTabParts<ElecLoadSumTab>,
        AutomaticKeepAliveClientMixin<ElecLoadSumTab> {
  // 탭을 옮겨도 입력이 사라지지 않게 살려 둔다.
  @override
  bool get wantKeepAlive => true;

  final List<_RowCtl> _rows = [];
  int _nextId = 0;
  final _defPf = TextEditingController();
  final _defDf = TextEditingController();
  final _diversity = TextEditingController(text: '1.0');
  final _margin = TextEditingController(text: '0');
  final _selected = TextEditingController();
  final _site = TextEditingController();
  final _memo = TextEditingController();
  final _saveName = TextEditingController();
  double _volts = 380;
  List<LoadSheet> _sheets = [];

  Timer? _saveTimer;
  String? _lastDraft;
  String? _pendingDraft;
  bool _draftReady = false;

  List<TextEditingController> get _texts => [
    _defPf,
    _defDf,
    _diversity,
    _margin,
    _selected,
    _site,
    _memo,
    _saveName,
  ];

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 3; i++) {
      _rows.add(_RowCtl(_nextId++));
    }
    _loadDraft();
    _loadSheets();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _flushDraft();
    for (final r in _rows) {
      r.dispose();
    }
    for (final c in _texts) {
      c.dispose();
    }
    super.dispose();
  }

  // ─────────────── 입력 모으기·되돌리기 ───────────────

  LoadSumInput _input() => LoadSumInput(
    rows: [for (final r in _rows) r.input],
    defaultPf: _defPf.text,
    defaultDf: _defDf.text,
    diversity: _diversity.text,
    margin: _margin.text,
    volts: _volts,
    selectedKva: _selected.text,
    site: _site.text,
    memo: _memo.text,
  );

  void _apply(LoadSumInput i) {
    final old = List<_RowCtl>.of(_rows);
    _rows
      ..clear()
      ..addAll([for (final r in i.rows) _RowCtl(_nextId++, r)]);
    if (_rows.isEmpty) _rows.add(_RowCtl(_nextId++));
    _defPf.text = i.defaultPf;
    _defDf.text = i.defaultDf;
    _diversity.text = i.diversity;
    _margin.text = i.margin;
    _selected.text = i.selectedKva;
    _site.text = i.site;
    _memo.text = i.memo;
    _volts = i.volts;
    // 화면이 아직 옛 칸을 쓰고 있으므로 다음 그림 뒤에 버린다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final r in old) {
        r.dispose();
      }
    });
  }

  // ─────────────── 자동 저장(입력값 남기기) ───────────────

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kLoadSumDraftKey);
      if (raw != null && mounted) {
        final m = jsonDecode(raw);
        if (m is Map) setState(() => _apply(LoadSumInput.fromJson(m)));
      }
      _lastDraft = raw;
    } catch (_) {
      // 저장 칸을 못 읽어도 기본값으로 쓴다.
    }
    _draftReady = true;
  }

  void _scheduleSave() {
    if (!_draftReady) return;
    final raw = jsonEncode(_input().toJson());
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
      await prefs.setString(kLoadSumDraftKey, raw);
    } catch (_) {
      // 저장을 못 해도 계산에는 지장이 없다.
    }
  }

  // ─────────────── 저장한 계산서 ───────────────

  RecordSyncStatus? _sync;

  Future<void> _loadSheets() async {
    final s = await LoadSheetStore.load();
    if (mounted) setState(() => _sheets = s);
    _syncSheets();
  }

  /// 서버에 있는 내 계산서를 폰에 합치고, 폰에만 있는 것을 올린다(다른 폰·태블릿에서 저장한 것도 보이게).
  /// 통신이 없거나 로그인하지 않았으면 폰 저장 그대로다.
  Future<void> _syncSheets() async {
    final before = await LoadSheetStore.sync.status();
    if (mounted) setState(() => _sync = before);
    final s = await LoadSheetStore.sync.syncNow();
    final l = await LoadSheetStore.load();
    if (mounted) {
      setState(() {
        _sync = s;
        _sheets = l;
      });
    }
  }

  Future<void> _refreshSyncAfterPush() async {
    await RecordSync.idle();
    final s = await LoadSheetStore.sync.status();
    if (mounted) setState(() => _sync = s);
  }

  void _toast(String t) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(t)));

  Future<bool> _confirm(String text, String okLabel) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(
            key: const Key('els_dialog_cancel'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            key: const Key('els_dialog_ok'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(okLabel),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _saveSheet() async {
    final name = _saveName.text.trim();
    if (name.isEmpty) {
      _toast('저장 이름을 넣으십시오.');
      return;
    }
    final same = _sheets.indexWhere((s) => s.name == name);
    if (same < 0 && _sheets.length >= kLoadSumMaxSheets) {
      _toast('저장은 $kLoadSumMaxSheets개까지 됩니다. 안 쓰는 계산서를 지우십시오.');
      return;
    }
    if (same >= 0 && !await _confirm('"$name" 이름이 이미 있습니다. 덮어쓰겠습니까?', '덮어쓰기')) {
      return;
    }
    // 같은 이름이면 첫 것의 이름표를 이어 쓴다(다른 기기에서 그 계산서가 새 것으로 바뀌게).
    // 같은 이름이 더 있으면(두 기기에서 따로 저장한 경우) 나머지는 지운다.
    final sheet = LoadSheet(
      id: same >= 0 ? _sheets[same].id : null,
      name: name,
      savedAt: DateTime.now(),
      input: _input(),
    );
    final dropped = [
      for (final x in _sheets)
        if (x.name == name && x.id != sheet.id) x.id,
    ];
    final next = [
      for (final x in _sheets)
        if (x.name != name) x,
    ];
    next.insert(0, sheet);
    final ok = await LoadSheetStore.save(next);
    if (!mounted) return;
    if (ok) {
      setState(() => _sheets = next);
      await LoadSheetStore.sync.saved(sheet.id);
      for (final id in dropped) {
        await LoadSheetStore.sync.removed(id);
      }
      _refreshSyncAfterPush();
      _toast('"$name" 저장했습니다.');
    } else {
      _toast('저장하지 못했습니다.');
    }
  }

  Future<void> _openSheet(LoadSheet s) async {
    if (!await _confirm('"${s.name}" 계산서를 불러오겠습니까?\n지금 입력한 값은 바뀝니다.', '불러오기')) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _apply(s.input);
      _saveName.text = s.name;
    });
  }

  Future<void> _deleteSheet(LoadSheet s) async {
    if (!await _confirm('"${s.name}" 계산서를 지우겠습니까?', '지우기')) return;
    final next = [
      for (final x in _sheets)
        if (x.id != s.id) x,
    ];
    final ok = await LoadSheetStore.save(next);
    if (!mounted) return;
    if (ok) {
      setState(() => _sheets = next);
      await LoadSheetStore.sync.removed(s.id);
      _refreshSyncAfterPush();
    } else {
      _toast('지우지 못했습니다.');
    }
  }

  // ─────────────── 줄 ───────────────

  void _addRow() {
    if (_rows.length >= kLoadSumMaxRows) return;
    setState(() => _rows.add(_RowCtl(_nextId++)));
  }

  void _removeRow(_RowCtl r) {
    setState(() {
      if (_rows.length == 1) {
        r.name.clear();
        r.kw.clear();
        r.pf.clear();
        r.df.clear();
        return;
      }
      _rows.remove(r);
      WidgetsBinding.instance.addPostFrameCallback((_) => r.dispose());
    });
  }

  // ─────────────── 화면 부품 ───────────────

  Widget _cell(
    String key,
    String label,
    TextEditingController c, {
    String? hint,
    bool numeric = true,
  }) => TextField(
    key: Key(key),
    controller: c,
    textAlign: numeric ? TextAlign.right : TextAlign.left,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    textInputAction: TextInputAction.next,
    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: fc.text),
    decoration: InputDecoration(
      isDense: true,
      labelText: label,
      // 칸이 좁아서 비었을 때 이름이 잘리지 않게 이름표를 늘 위에 둔다(폰에서 "설비용량 (k…"로 잘렸음).
      floatingLabelBehavior: FloatingLabelBehavior.always,
      hintText: hint,
      labelStyle: TextStyle(fontSize: 13, color: fc.textSub),
      hintStyle: TextStyle(fontSize: 17, color: fc.textSub),
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

  Widget _textBox(String key, String label, TextEditingController c) => calcBox(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: _cell(key, label, c, numeric: false),
    ),
  );

  Widget _rowCard(int i, _RowCtl r) =>
      KeyedSubtree(key: ValueKey('els_rowbox_${r.id}'), child: _rowBox(i, r));

  Widget _rowBox(int i, _RowCtl r) => calcBox(
    child: Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${i + 1}번',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: fc.brand,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _cell(
                  'els_name_${r.id}',
                  '부하 이름',
                  r.name,
                  numeric: false,
                ),
              ),
              IconButton(
                key: Key('els_del_${r.id}'),
                tooltip: '줄 삭제',
                visualDensity: VisualDensity.compact,
                onPressed: () => _removeRow(r),
                icon: Icon(Icons.close_rounded, color: fc.textSub),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: _cell('els_kw_${r.id}', '설비용량 (kW)', r.kw),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 4,
                child: _cell(
                  'els_pf_${r.id}',
                  '역률 (%)',
                  r.pf,
                  hint: _defPf.text.trim().isEmpty ? null : _defPf.text.trim(),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 4,
                child: _cell(
                  'els_df_${r.id}',
                  '수용률 (%)',
                  r.df,
                  hint: _defDf.text.trim().isEmpty ? null : _defDf.text.trim(),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  String _syncText() {
    final s = _sync;
    if (s == null) return '';
    return recordSyncText(s);
  }

  Widget _savedList() {
    if (_sheets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          '저장한 계산서가 없습니다. ${_syncText()}',
          key: const Key('els_sync'),
          style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.4),
        ),
      );
    }
    String day(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _syncText(),
              key: const Key('els_sync'),
              style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.4),
            ),
          ),
        ),
        for (var i = 0; i < _sheets.length; i++)
          calcBox(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sheets[i].name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: fc.text,
                          ),
                        ),
                        Text(
                          day(_sheets[i].savedAt),
                          style: TextStyle(fontSize: 12, color: fc.textSub),
                        ),
                      ],
                    ),
                  ),
                ),
                calcToggle('els_open_$i', '불러오기', () => _openSheet(_sheets[i])),
                calcToggle(
                  'els_sheet_del_$i',
                  '지우기',
                  () => _deleteSheet(_sheets[i]),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─────────────── 화면 ───────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final input = _input();
    final r = computeLoadSum(input);
    _scheduleSave();

    Widget result;
    String? summary;
    var warn = false;
    if (r.errors.isNotEmpty) {
      warn = true;
      summary = '입력 확인: ${r.errors.length}건';
      result = calcResult(
        key: const Key('els_result'),
        big: '입력 확인',
        caption: '입력값에 문제가 있어 계산하지 않았습니다',
        warn: true,
        lines: r.errors,
      );
    } else if (r.noLines) {
      summary = '부하를 넣으십시오';
      result = calcResult(
        key: const Key('els_result'),
        big: '-',
        caption: '설비용량(kW)을 넣으면 계산합니다',
        lines: const [
          '부하는 kW로 넣습니다. kVA 값만 있으면 역률을 곱해 kW로 바꾸십시오.',
          '역률·수용률을 비워 두면 위의 기본값을 씁니다.',
        ],
      );
    } else {
      final pass = r.pass;
      warn = pass == false;
      summary =
          '최대수요 ${fmt(r.demandKw, 1)} kW · 필요 ${fmt(r.requiredKva, 1)} kVA'
          '${pass == null ? '' : ' · 부하율 ${fmt(r.loadPct!, 1)}% ${pass ? '합격' : '불합격'}'}';
      result = calcResult(
        key: const Key('els_result'),
        big: '${fmt(r.requiredKva, 1)} kVA',
        caption: '필요 변압기 용량',
        warn: warn,
        lines: [
          '설비용량 합계 ${fmt(r.totalKw, 1)} kW',
          '최대수요 ${fmt(r.demandKw, 1)} kW, ${fmt(r.demandKvar, 1)} kvar, ${fmt(r.demandKva, 1)} kVA',
          '종합 역률 ${fmt(r.pf * 100, 1)}%',
          '필요 용량 = ${fmt(r.demandKva, 1)} kVA ÷ ${fmt(r.diversity, 2)} × ${fmt(1 + r.marginPct / 100, 3)}',
          '2차 정격전류 ${fmt(r.ratedAmps, 1)} A (${fmt(r.volts, 0)} V, 3상)',
          if (pass == null)
            '선정 변압기 용량(kVA)을 넣으면 부하율과 합격/불합격을 봅니다.'
          else ...[
            '선정 ${fmt(r.selectedKva!, 1)} kVA: 부하율 ${fmt(r.loadPct!, 1)}% ${pass ? '합격' : '불합격'}'
                '${r.marginPct > 0 ? ' (여유를 뺀 부하율 ${fmt(r.loadPctNoMargin!, 1)}%)' : ''}',
            if (!pass) '선정 용량이 필요 용량보다 작습니다. 더 큰 용량을 선정하십시오.',
          ],
          '참고(원문 대조 전): 부하율 60~80%를 적정으로 보는 설명이 있습니다. 2차 자료입니다.',
        ],
      );
    }

    return elecPage(sumKey: 'els_sum', summary: summary, warn: warn, [
      elecSectionTitle('부하 목록'),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Text(
          '설비용량은 kW로 넣습니다(kVA를 섞어 넣으면 결과가 틀립니다). '
          '수용률은 100% 이하, 부등률은 1 이상입니다.',
          style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.4),
        ),
      ),
      elecField(
        'els_def_pf',
        '기본 역률 (%)',
        _defPf,
        '줄의 역률 칸을 비워 두면 이 값을 씁니다. 부하마다 다르면 줄에 직접 넣으십시오. 0 초과 100 이하입니다.',
      ),
      elecField(
        'els_def_df',
        '기본 수용률 (%)',
        _defDf,
        '줄의 수용률 칸을 비워 두면 이 값을 씁니다. 설비용량 중 동시에 쓰는 비율입니다. 0 초과 100 이하입니다.',
      ),
      for (var i = 0; i < _rows.length; i++) _rowCard(i, _rows[i]),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          key: const Key('els_add'),
          onPressed: _rows.length >= kLoadSumMaxRows ? null : _addRow,
          icon: const Icon(Icons.add_rounded),
          label: Text('줄 추가 (${_rows.length}/$kLoadSumMaxRows)'),
        ),
      ),
      const SizedBox(height: 12),
      elecSectionTitle('변압기 조건'),
      elecField(
        'els_diversity',
        '부등률',
        _diversity,
        '부하마다 최대수요가 같은 시간에 오지 않는 정도입니다. 1 이상이며 클수록 변압기가 작아집니다. 비우면 1입니다.',
      ),
      elecField(
        'els_margin',
        '장래 증설 여유 (%)',
        _margin,
        '앞으로 부하가 늘 것을 감안해 필요 용량에 더하는 비율입니다. 없으면 0입니다.',
      ),
      elecChipGroup('2차 전압 (3상)', '변압기 2차 쪽 선간 전압입니다. 정격전류 계산에 씁니다.', [
        for (final v in kLoadSumVolts)
          calcChip('els_v_${v.round()}', '${v.round()} V', _volts == v, () {
            setState(() => _volts = v);
          }),
      ]),
      elecField(
        'els_selected',
        '선정 변압기 용량 (kVA, 선택)',
        _selected,
        '실제로 선정한 변압기 용량입니다. 넣으면 부하율과 합격/불합격을 봅니다. 표준 용량 목록은 원문 대조 전이라 넣지 않았습니다.',
      ),
      const SizedBox(height: 4),
      result,
      if (r.ok && !r.noLines && widget.onSendToShortCircuit != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('els_to_short'),
              onPressed: () => widget.onSendToShortCircuit!(
                r.selectedKva ?? r.requiredKva,
                r.volts,
              ),
              icon: const Icon(Icons.bolt_rounded),
              label: Text(
                '단락 전류로 보내기 (${fmt(r.selectedKva ?? r.requiredKva, 1)} kVA, ${fmt(r.volts, 0)} V)',
              ),
            ),
          ),
        ),
      if (r.ok && !r.noLines && widget.onSendToShortCircuit != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            r.selectedKva == null
                ? '선정 변압기 용량을 넣지 않아 필요 용량을 넘깁니다. 실제 변압기 명판 값으로 고치십시오. %Z는 넘기지 않습니다.'
                : '선정 변압기 용량을 넘깁니다. %Z는 명판 값을 단락 전류 탭에서 넣으십시오.',
            style: TextStyle(fontSize: 12, color: fc.textSub),
          ),
        ),
      elecBasis('els_basis', [
        '최대수요전력 = 설비용량 × 수용률. 줄마다 유효전력 P = kW × 수용률, 무효전력 Q = P × tanφ(φ = acos 역률).',
        '최대수요 kVA = √((ΣP)² + (ΣQ)²). 종합 역률 = ΣP ÷ 최대수요 kVA.',
        '필요 변압기 용량 [kVA] = 최대수요 kVA ÷ 부등률 × (1 + 여유). 역률이 한 값이면 Σ(설비용량×수용률) ÷ (부등률×역률)과 같습니다.',
        '2차 정격전류 [A] = 필요 용량[kVA] × 1000 ÷ (√3 × 2차 전압[V]).',
        '부하율 = 필요 용량 ÷ 선정 용량. 100% 초과면 불합격입니다.',
        '식과 용어(수용률·부등률)는 국내 전기 설계 자료의 통용 식입니다. 조항 원문 대조 전(2차 자료)입니다.',
        '부하율 60~80% 적정이라는 설명도 2차 자료라 원문 대조 전입니다. 판정에는 쓰지 않았습니다.',
        '표준 변압기 용량 목록은 KS 원문이나 제조사 카탈로그 두 곳으로 확인하지 못해 넣지 않았습니다. 선정 용량은 직접 입력합니다.',
        '수용률·부등률·역률의 기본값은 정하지 않았습니다. 설계 기준서나 부하 자료에 맞춰 직접 넣으십시오.',
      ]),
      const SizedBox(height: 8),
      elecSectionTitle('계산서'),
      _textBox('els_site', '현장·프로젝트 (계산서에 적힘)', _site),
      _textBox('els_memo', '메모 (계산서에 적힘)', _memo),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          key: const Key('els_pdf'),
          onPressed: r.ok
              ? () => openLoadSumPdf(
                  context,
                  input,
                  r,
                  title: _saveName.text.trim().isNotEmpty
                      ? _saveName.text.trim()
                      : _site.text.trim(),
                )
              : null,
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('부하 계산서 PDF'),
        ),
      ),
      if (!r.ok)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '입력 확인이 끝나야 계산서를 만들 수 있습니다.',
            style: TextStyle(fontSize: 12, color: fc.textSub),
          ),
        ),
      const SizedBox(height: 12),
      elecSectionTitle('저장한 계산서'),
      _textBox('els_save_name', '저장 이름', _saveName),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          key: const Key('els_save'),
          onPressed: _saveSheet,
          icon: const Icon(Icons.save_outlined),
          label: const Text('저장'),
        ),
      ),
      const SizedBox(height: 8),
      _savedList(),
    ]);
  }
}
