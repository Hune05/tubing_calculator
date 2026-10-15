// 축 정렬 화면의 창들: 기록 남기기, 회차에 한 일 적기, 지난 기록(10-15 나눔).
part of 'alignment_page.dart';

// ── 기록 남기기 창 ──

class _SaveSheet extends StatefulWidget {
  final AlignResult result;
  final AlignMethod method;
  final int rpm;
  final Map<String, String> inputs;
  final AlignVerdict verdict;
  final DateTime now;
  final String machineDefault;
  final List<Equipment> equipment;
  final List<AlignRound> rounds;
  final Map<AlignFoot, double> footStart;
  final Map<AlignFoot, double> footEnd;
  const _SaveSheet({
    required this.result,
    required this.method,
    required this.rpm,
    required this.inputs,
    required this.verdict,
    required this.now,
    required this.machineDefault,
    required this.equipment,
    this.rounds = const [],
    this.footStart = const {},
    this.footEnd = const {},
  });

  @override
  State<_SaveSheet> createState() => _SaveSheetState();
}

class _SaveSheetState extends State<_SaveSheet> {
  late final _machine = TextEditingController(text: widget.machineDefault);
  final _note = TextEditingController();
  late AlignStage _stage = widget.rounds.isEmpty ? AlignStage.before : AlignStage.after;
  String _equipmentId = '';

  @override
  void dispose() {
    _machine.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('정렬 기록 남기기', style: AppText.title),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final s in AlignStage.values)
                  ChoiceChip(
                    key: Key('align_stage_${s.id}'),
                    label: Text(s.label),
                    selected: _stage == s,
                    labelStyle: TextStyle(fontWeight: FontWeight.w700, ),
                    onSelected: (_) => setState(() => _stage = s),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('align_machine'),
              controller: _machine,
              decoration: const InputDecoration(labelText: '기계 이름', hintText: '예: 1호기 급수펌프 · 모터'),
            ),
            if (widget.equipment.isNotEmpty) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: const Key('align_equipment'),
                initialValue: _equipmentId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '장비 관리 대장에 기록 남기기 (선택)'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('연결 안 함')),
                  for (final e in widget.equipment)
                    DropdownMenuItem(
                      value: e.id,
                      child: Text([if (e.assetNo.isNotEmpty) e.assetNo, e.name].join('  '), overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _equipmentId = v ?? ''),
              ),
            ],
            const SizedBox(height: 8),
            TextField(key: const Key('align_note'), controller: _note, decoration: const InputDecoration(labelText: '메모 (선택)')),
            const SizedBox(height: 10),
            // 같이 저장되는 발 밑 심(10-15 심 기록).
            Text(
              '같이 남는 발 밑 심(mm): ${[for (final f in AlignFoot.values) '${f.label} ${footMm(widget.footEnd[f] ?? 0)}'].join(' · ')}',
              key: const Key('align_save_feet'),
              style: const TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSub),
            ),
            const SizedBox(height: 12),
            // 한 일 적기 창처럼 꽉 찬 단추(10-15 폰: 혼자 작은 단추였다).
            FilledButton(
              key: const Key('align_save_ok'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.pop(
                context,
                AlignRecord(
                  id: widget.now.microsecondsSinceEpoch.toString(),
                  at: widget.now,
                  machine: _machine.text.trim(),
                  method: widget.method,
                  stage: _stage,
                  rpm: widget.rpm,
                  equipmentId: _equipmentId,
                  note: _note.text.trim(),
                  inputs: widget.inputs,
                  offset: r.offset,
                  angle100: r.angle100,
                  shimFront: r.shimFront,
                  shimRear: r.shimRear,
                  moveFront: r.moveFront,
                  moveRear: r.moveRear,
                  verdict: widget.verdict,
                  rounds: widget.rounds,
                  footStart: widget.footStart,
                  footEnd: widget.footEnd,
                ),
              ),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 회차에 실제로 한 일 적기 ──

class _DoneSheet extends StatefulWidget {
  final AlignRound round;
  final int index;
  const _DoneSheet({required this.round, required this.index});

  @override
  State<_DoneSheet> createState() => _DoneSheetState();
}

class _DoneSheetState extends State<_DoneSheet> {
  late final Map<AlignFoot, TextEditingController> _foot;
  late final TextEditingController _mf, _mr, _note;

  static String _fmt(double v) => v.abs() < 0.005 ? '0' : v.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    final r = widget.round;
    final d = r.done;
    // 처음에는 계산이 말한 값으로 채운다(그대로 했으면 바로 저장).
    double init(AlignFoot f) => d?[f] ?? (f == AlignFoot.frontLeft || f == AlignFoot.frontRight ? r.shimFront : r.shimRear);
    _foot = {for (final f in AlignFoot.values) f: TextEditingController(text: _fmt(init(f)))};
    _mf = TextEditingController(text: _fmt(d == null ? r.moveFront : r.doneMoveFront));
    _mr = TextEditingController(text: _fmt(d == null ? r.moveRear : r.doneMoveRear));
    _note = TextEditingController(text: r.note);
  }

  @override
  void dispose() {
    for (final c in _foot.values) {
      c.dispose();
    }
    _mf.dispose();
    _mr.dispose();
    _note.dispose();
    super.dispose();
  }

  double _v(TextEditingController c) => parseNumberText(c.text) ?? 0;

  Widget _num(String key, String label, TextEditingController c) => Expanded(
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: TextField(
        key: Key(key),
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(labelText: label, suffixText: 'mm'),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.index + 1}회차에 실제로 한 일', style: AppText.title),
            const SizedBox(height: 4),
            const Text(
              '계산값이 미리 들어 있습니다. 실제로 넣고 뺀 만큼으로 고치십시오. 넣은 심은 +, 뺀 심은 −입니다.',
              style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSub),
            ),
            const SizedBox(height: 8),
            const Text('왼쪽 발 (펌프 쪽에서 모터를 볼 때)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSub)),
            Row(children: [_num('align_done_frontLeft', '앞발 왼쪽 심', _foot[AlignFoot.frontLeft]!), _num('align_done_rearLeft', '뒷발 왼쪽 심', _foot[AlignFoot.rearLeft]!)]),
            const Text('오른쪽 발', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSub)),
            Row(children: [_num('align_done_frontRight', '앞발 오른쪽 심', _foot[AlignFoot.frontRight]!), _num('align_done_rearRight', '뒷발 오른쪽 심', _foot[AlignFoot.rearRight]!)]),
            const SizedBox(height: 4),
            const Text('옆으로 민 양 (오른쪽 +, 왼쪽 −)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSub)),
            Row(children: [_num('align_done_moveFront', '앞발 옆으로', _mf), _num('align_done_moveRear', '뒷발 옆으로', _mr)]),
            Padding(
              padding: const EdgeInsets.all(4),
              child: TextField(key: const Key('align_done_note'), controller: _note, decoration: const InputDecoration(labelText: '메모 (선택, 예: 0.2 심 두 장)')),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('align_done_ok'),
              onPressed: () => Navigator.pop(
                context,
                widget.round.withDone(
                  {for (final f in AlignFoot.values) f: _v(_foot[f]!)},
                  moveFront: _v(_mf),
                  moveRear: _v(_mr),
                  note: _note.text.trim(),
                ),
              ),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 지난 기록 ──

class AlignmentHistoryPage extends StatefulWidget {
  final Future<void> Function(String text) share;
  const AlignmentHistoryPage({super.key, required this.share});

  @override
  State<AlignmentHistoryPage> createState() => _AlignmentHistoryPageState();
}

class _AlignmentHistoryPageState extends State<AlignmentHistoryPage> {
  List<AlignRecord>? _list;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final l = await AlignStore.load();
    if (mounted) setState(() => _list = l);
  }

  Future<void> _open(AlignRecord r) async {
    final all = _list ?? const <AlignRecord>[];
    final cmp = compareText(r, all);
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(
                    [buildAlignText(r), if (cmp != null) '비교: $cmp'].join('\n'),
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton(
                    key: const Key('align_history_delete'),
                    onPressed: () => Navigator.pop(ctx, 'delete'),
                    child: const Text('지우기'),
                  ),
                  const SizedBox(width: 8),
                  // 보고·제출용 기록 PDF(10-15).
                  OutlinedButton.icon(
                    key: const Key('align_history_pdf'),
                    onPressed: () => Navigator.pop(ctx, 'pdf'),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('PDF'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      key: const Key('align_history_send'),
                      onPressed: () => Navigator.pop(ctx, 'send'),
                      child: const Text('카톡으로 보내기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (action == 'send') {
      await widget.share([buildAlignText(r), if (cmp != null) '비교: $cmp'].join('\n'));
    } else if (action == 'pdf') {
      if (mounted) await openAlignPdf(context, r);
    } else if (action == 'delete') {
      _delete(r);
    }
  }

  /// 목록에서 곧바로 빼고 휴지통으로 옮긴다. "되돌리기"를 누르면 휴지통에서 복원한다(10-02).
  void _delete(AlignRecord r) {
    final l = _list;
    if (l == null || !mounted) return;
    setState(() => _list = [...l]..removeWhere((e) => e.id == r.id));
    final title = '${r.at.month}/${r.at.day} ${r.stage.label}${r.machine.isEmpty ? '' : ' ${r.machine}'}';
    final done = trashAlignRecord(r, title: title);
    showTrashUndo(context, title, done, onRestored: () async {
        await _reload();
      });
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('축 정렬 기록')),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
          ? const Center(child: Text('저장한 정렬 기록이 없습니다', style: AppText.sub))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final r in list)
                  SwipeToDelete(
                    itemKey: ValueKey('align_swipe_${r.id}'),
                    onDelete: () => _delete(r),
                    child: Card(
                      elevation: 0,
                      color: AppColors.surface,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        key: Key('align_record_${r.id}'),
                        onTap: () => _open(r),
                        title: Text(
                          [
                            '${r.at.month}/${r.at.day}',
                            r.stage.label,
                            if (r.machine.isNotEmpty) r.machine,
                          ].join(' · '),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '평행 ${r.offset.toStringAsFixed(3)} mm · 각도 ${r.angle100.toStringAsFixed(3)} mm/100mm · ${verdictLabel(r.verdict)}',
                        ),
                        trailing: const Icon(AppIcons.forward),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
