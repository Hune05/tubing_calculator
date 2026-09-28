// 압력시험 기록 저장 창: 라인 번호(꼭)·시험 번호·현장·계통·P&ID·시험 구간·시험유체·시험일·압력계 두 개·
// 안전밸브·시험자·입회자·메모. 입력 칸은 이 창이 만들고 치운다. 불러온 기록의 라인 번호를 바꾸면 "새로 저장"이 기본.
library;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/utils/image_picker_helper.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/photo_store.dart';

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
  final String tester;
  final bool selfInspection;
  final String selfInspectionDept;
  final String witnessContractor, witnessSupervisor, witnessOwner;
  final List<String> photos;
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
    required this.selfInspection,
    required this.selfInspectionDept,
    required this.witnessContractor,
    required this.witnessSupervisor,
    required this.witnessOwner,
    required this.photos,
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

  /// 이 시험의 시험압력(kPa). 있으면 압력계 눈금 범위가 맞는지 칸 아래에 알린다.
  final double? testKpa;

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
    this.testKpa,
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
  late final _dept = TextEditingController(text: _ed?.selfInspectionDept ?? '');
  late final _memo = TextEditingController(text: _ed?.memo ?? '');
  late DateTime _date = widget.date;
  late PtFluid _fluid = _ed?.fluid ?? ptDefaultFluid(widget.medium);
  late bool _selfInspection = _ed?.selfInspection ?? false;
  final List<String> _photos = [];
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
    _dept,
    _memo,
  ];

  /// 불러온 기록의 라인 번호를 바꾸면 다른 시험으로 보고 "새로 저장"을 기본으로.
  bool get _lineChanged => _ed != null && _line.text.trim() != _ed!.line;

  @override
  void initState() {
    super.initState();
    _photos.addAll(_ed?.photos ?? const []);
  }

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
        selfInspection: _selfInspection,
        selfInspectionDept: _dept.text.trim(),
        witnessContractor: _wC.text.trim(),
        witnessSupervisor: _wS.text.trim(),
        witnessOwner: _wO.text.trim(),
        photos: _photos,
        memo: _memo.text.trim(),
      ),
    );
  }

  Future<void> _addPhotos() async {
    final picked = await ImagePickerHelper.pickImages(
      context,
      maxCount: (10 - _photos.length).clamp(0, 10),
    );
    if (picked.isEmpty) return;
    final done = <String>[];
    for (final path in picked) {
      if (!mounted) break;
      final cropped = await ImagePickerHelper.cropImage(path);
      done.add(cropped ?? path);
    }
    if (mounted) setState(() => _photos.addAll(done));
  }

  Future<void> _removePhoto(int i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('사진 지우기'),
        content: const Text('이 사진을 지우겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('지우기', style: TextStyle(color: fc.danger)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) setState(() => _photos.removeAt(i));
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

  /// 눈금 최대가 시험압력보다 낮거나 1.5배 미만이면 알린다(저장은 막지 않는다).
  Widget _rangeWarning(int n, String text) {
    final test = widget.testKpa;
    final max = gaugeMaxKpa(text, widget.unit);
    final fit = max == null ? null : gaugeFit(max, test);
    if (fit == null || fit == GaugeFit.ok || test == null || max == null) {
      return const SizedBox.shrink();
    }
    final low = fit == GaugeFit.low;
    final msg = low
        ? '눈금 최대(${ptPressure(max, widget.unit)})가 시험압력(${ptPressure(test, widget.unit)})보다 낮습니다. 이 압력계로는 시험압력을 읽을 수 없고, 그 압력까지 올리면 압력계가 상합니다. 눈금이 더 큰 압력계로 바꾸십시오.'
        : '눈금 최대(${ptPressure(max, widget.unit)})가 시험압력(${ptPressure(test, widget.unit)})의 1.5배보다 작습니다. 압력계 눈금 범위는 시험압력의 1.5~4배(약 2배)로 잡습니다(B31.3 345.2.2(d)).';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: low ? fc.danger : fc.caution,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              msg,
              key: Key('ps_g${n}_range_warn'),
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: low ? fc.danger : fc.caution,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
        _field(
          'ps_g${n}_range',
          '눈금 범위',
          range,
          hint: '예: 0~25 bar',
          onChanged: (_) => setState(() {}),
        ),
      ),
      _rangeWarning(n, range.text),
      _field('ps_g${n}_due', '검교정 유효일', due, hint: '예: 2027-03-31'),
    ],
  );

  Widget _photoRow() {
    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < _photos.length; i++)
            Padding(
              key: Key('ps_photo_$i'),
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: PhotoImage(_photos[i], width: 80, height: 80),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: InkWell(
                      key: Key('ps_photo_del_$i'),
                      onTap: () => _removePhoto(i),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_photos.length < 10)
            InkWell(
              key: const Key('ps_photo_add'),
              onTap: _addPhotos,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  border: Border.all(color: fc.textSub.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_rounded, color: fc.textSub),
                    const SizedBox(height: 4),
                    Text(
                      '${_photos.length}/10',
                      style: TextStyle(fontSize: 11, color: fc.textSub),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

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
              '폰에 저장하고 통신되면 서버에도 올립니다. 기록서(PDF)는 "저장한 기록"에서 봅니다.',
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
            _head('검사 종류'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  key: const Key('ps_kind_witness'),
                  label: const Text('입회 검사'),
                  selected: !_selfInspection,
                  onSelected: (_) => setState(() => _selfInspection = false),
                ),
                ChoiceChip(
                  key: const Key('ps_kind_self'),
                  label: const Text('자체 검사'),
                  selected: _selfInspection,
                  onSelected: (_) => setState(() => _selfInspection = true),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_selfInspection)
              _field('ps_dept', '부서', _dept, hint: '예: 배관 1팀')
            else ...[
              _head('입회자 (선택)'),
              _field('ps_w_c', '시공사', _wC),
              _field('ps_w_s', '감리', _wS),
              _field('ps_w_o', '발주처', _wO),
            ],
            _field('ps_memo', '메모', _memo, maxLines: 2),
            _head('현장 사진 (선택, 최대 10장)'),
            _photoRow(),
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
