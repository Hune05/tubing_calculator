// 압력시험 기록 저장 창: 라인 번호(꼭)·시험 번호·현장·계통·P&ID·시험 구간·시험유체·시험일·압력계 두 개·
// 안전밸브·시험자·입회자·메모. 입력 칸은 이 창이 만들고 치운다. 불러온 기록의 라인 번호를 바꾸면 "새로 저장"이 기본.
library;

import 'package:flutter/material.dart';

import '../../core/theme/field_view.dart';
import 'pressure_calc.dart';
import 'pressure_units.dart';
import 'test_record.dart';

/// 저장 창에서 돌려주는 값. [asNew]: 새 기록으로(아니면 불러온 기록을 고침).
class PtSaveResult {
  final bool asNew;
  final DateTime date;
  final String testNo, site, system, line, pid, section;
  final PtFluid fluid;
  final List<PtGauge> gauges;
  final double? reliefKpa;
  final String reliefNo;
  final String tester, witnessContractor, witnessSupervisor, witnessOwner;
  final String memo;
  const PtSaveResult({
    required this.asNew,
    required this.date,
    required this.testNo,
    required this.site,
    required this.system,
    required this.line,
    required this.pid,
    required this.section,
    required this.fluid,
    required this.gauges,
    required this.reliefKpa,
    required this.reliefNo,
    required this.tester,
    required this.witnessContractor,
    required this.witnessSupervisor,
    required this.witnessOwner,
    required this.memo,
  });
}

class PtSaveSheet extends StatefulWidget {
  final PtRecord? editing;
  final PUnit unit;
  final TestMedium medium;
  final String line; // 시험 기록 탭의 라인 번호
  final DateTime date; // 시험일 기본값
  final String tester;
  final List<PtGauge> gauges;
  final double? reliefKpa;
  final String reliefNo;

  const PtSaveSheet({
    super.key,
    required this.editing,
    required this.unit,
    required this.medium,
    required this.line,
    required this.date,
    required this.tester,
    this.gauges = const [],
    this.reliefKpa,
    this.reliefNo = '',
  });

  @override
  State<PtSaveSheet> createState() => _PtSaveSheetState();
}

class _PtSaveSheetState extends State<PtSaveSheet> {
  PtRecord? get _ed => widget.editing;
  PtGauge _g(int i) =>
      i < widget.gauges.length ? widget.gauges[i] : const PtGauge();

  late final _line = TextEditingController(text: widget.line);
  late final _testNo = TextEditingController(text: _ed?.testNo ?? '');
  late final _site = TextEditingController(text: _ed?.site ?? '');
  late final _system = TextEditingController(text: _ed?.system ?? '');
  late final _pid = TextEditingController(text: _ed?.pid ?? '');
  late final _section = TextEditingController(text: _ed?.section ?? '');
  late final _g1No = TextEditingController(text: _g(0).no);
  late final _g1Range = TextEditingController(text: _g(0).range);
  late final _g1Due = TextEditingController(text: _g(0).calDue);
  late final _g2No = TextEditingController(text: _g(1).no);
  late final _g2Range = TextEditingController(text: _g(1).range);
  late final _g2Due = TextEditingController(text: _g(1).calDue);
  late final String _reliefText = widget.reliefKpa == null
      ? ''
      : ptFmt(widget.reliefKpa! / widget.unit.kpa, 4);
  late final _relief = TextEditingController(text: _reliefText);
  late final _reliefNo = TextEditingController(text: widget.reliefNo);
  late final _tester = TextEditingController(text: widget.tester);
  late final _wC = TextEditingController(text: _ed?.witnessContractor ?? '');
  late final _wS = TextEditingController(text: _ed?.witnessSupervisor ?? '');
  late final _wO = TextEditingController(text: _ed?.witnessOwner ?? '');
  late final _memo = TextEditingController(text: _ed?.memo ?? '');
  late DateTime _date = widget.date;
  late PtFluid _fluid = _ed?.fluid ?? ptDefaultFluid(widget.medium);
  bool _lineError = false;

  List<TextEditingController> get _all => [
    _line,
    _testNo,
    _site,
    _system,
    _pid,
    _section,
    _g1No,
    _g1Range,
    _g1Due,
    _g2No,
    _g2Range,
    _g2Due,
    _relief,
    _reliefNo,
    _tester,
    _wC,
    _wS,
    _wO,
    _memo,
  ];

  /// 불러온 기록의 라인 번호를 바꾸면 다른 시험으로 보고 "새로 저장"을 기본으로.
  bool get _lineChanged => _ed != null && _line.text.trim() != _ed!.line;

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _reliefKpa {
    final t = _relief.text.trim();
    if (t.isEmpty) return null;
    // 미리 채운 글 그대로면 저장된 kPa를 그대로(반올림 누적 방지).
    if (t == _reliefText) return widget.reliefKpa;
    final v = double.tryParse(t.replaceAll(',', ''));
    return v == null ? null : v * widget.unit.kpa;
  }

  void _done(bool asNew) {
    if (_line.text.trim().isEmpty) {
      setState(() => _lineError = true);
      return;
    }
    PtGauge g(
      TextEditingController n,
      TextEditingController r,
      TextEditingController d,
    ) =>
        PtGauge(no: n.text.trim(), range: r.text.trim(), calDue: d.text.trim());
    final gauges = [g(_g1No, _g1Range, _g1Due), g(_g2No, _g2Range, _g2Due)];
    // 둘째만 적었으면 첫째 자리로 당긴다.
    final kept = [
      for (final x in gauges)
        if (!x.isEmpty) x,
    ];
    Navigator.pop(
      context,
      PtSaveResult(
        asNew: asNew,
        date: _date,
        testNo: _testNo.text.trim(),
        site: _site.text.trim(),
        system: _system.text.trim(),
        line: _line.text.trim(),
        pid: _pid.text.trim(),
        section: _section.text.trim(),
        fluid: _fluid,
        gauges: kept,
        reliefKpa: _reliefKpa,
        reliefNo: _reliefNo.text.trim(),
        tester: _tester.text.trim(),
        witnessContractor: _wC.text.trim(),
        witnessSupervisor: _wS.text.trim(),
        witnessOwner: _wO.text.trim(),
        memo: _memo.text.trim(),
      ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null && mounted) setState(() => _date = d);
  }

  Widget _field(
    String key,
    String label,
    TextEditingController c, {
    String? hint,
    String? error,
    int maxLines = 1,
    bool number = false,
    ValueChanged<String>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      key: Key(key),
      controller: c,
      maxLines: maxLines,
      onChanged: onChanged,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      style: TextStyle(fontSize: 16, color: fc.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );

  Widget _pair(Widget a, Widget b) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a),
      const SizedBox(width: 10),
      Expanded(child: b),
    ],
  );

  Widget _head(String t) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 8),
    child: Text(
      t,
      style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
    ),
  );

  Widget _gauge(
    int n,
    TextEditingController no,
    TextEditingController range,
    TextEditingController due,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _head(n == 1 ? '압력계 1' : '압력계 2 (선택)'),
      _pair(
        _field('ps_g${n}_no', '번호', no),
        _field('ps_g${n}_range', '눈금 범위', range, hint: '예: 0~25 bar'),
      ),
      _field('ps_g${n}_due', '검교정 유효일', due, hint: '예: 2027-03-31'),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final ed = _ed;
    // 새 기록이거나 라인 번호를 바꿨으면 "새로 저장"이 기본 단추.
    final primaryNew = ed == null || _lineChanged;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ed == null ? '압력시험 기록 저장' : '압력시험 기록 고치기',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: fc.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '폰에만 저장됩니다. 기록서(PDF)는 "저장한 기록"에서 봅니다.',
              style: TextStyle(fontSize: 13, color: fc.textSub),
            ),
            const SizedBox(height: 12),
            _field(
              'ps_line',
              '라인 번호',
              _line,
              hint: '예: 2"-P-1001-A1A',
              error: _lineError ? '라인 번호를 넣으십시오' : null,
              onChanged: (_) => setState(() {}),
            ),
            _field('ps_testno', '시험 번호', _testNo, hint: '예: HT-001'),
            _field('ps_site', '현장·프로젝트', _site),
            _field('ps_system', '계통', _system, hint: '예: 급수 계통'),
            _field('ps_pid', 'P&ID·아이소 번호', _pid),
            _field(
              'ps_section',
              '시험 구간 (From ~ To)',
              _section,
              hint: '예: V-101 ~ P-201A',
            ),
            _head('시험유체'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in PtFluid.values)
                  ChoiceChip(
                    key: Key('ps_fluid_${f.name}'),
                    label: Text(ptFluidLabel(f)),
                    selected: _fluid == f,
                    onSelected: (_) => setState(() => _fluid = f),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '시험일',
                  style: TextStyle(fontWeight: FontWeight.w700, color: fc.text),
                ),
                const SizedBox(width: 8),
                TextButton(
                  key: const Key('ps_date'),
                  onPressed: _pickDate,
                  child: Text(
                    ptDay(_date),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            _gauge(1, _g1No, _g1Range, _g1Due),
            _gauge(2, _g2No, _g2Range, _g2Due),
            _head('안전밸브'),
            _pair(
              _field(
                'ps_relief',
                '설정압력 (${widget.unit.label})',
                _relief,
                number: true,
              ),
              _field('ps_relief_no', '번호', _reliefNo),
            ),
            _field('ps_tester', '시험자', _tester),
            _head('입회자 (선택)'),
            _field('ps_w_c', '시공사', _wC),
            _field('ps_w_s', '감리', _wS),
            _field('ps_w_o', '발주처', _wO),
            _field('ps_memo', '메모', _memo, maxLines: 2),
            const SizedBox(height: 4),
            Row(
              children: [
                if (ed != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      key: Key(
                        primaryNew ? 'ps_save_overwrite' : 'ps_save_new',
                      ),
                      onPressed: () => _done(!primaryNew),
                      child: Text(primaryNew ? '고쳐 저장' : '새로 저장'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: ElevatedButton(
                    key: const Key('ps_save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: fc.brand,
                      foregroundColor: fc.onBrand,
                    ),
                    onPressed: () => _done(primaryNew),
                    child: Text(
                      ed == null ? '저장' : (primaryNew ? '새로 저장' : '고쳐 저장'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
