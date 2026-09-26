// 압력 시험 계산기 ⑤ 시험 기록 탭: 시험 정보(시험 압력 탭에서) → 유지시간 타이머(시작·측정 추가·종료, 폰 알림)
// → 측정 기록 → 판정(허용 압력강하·누설 확인·유지시간) → 기록 저장·저장한 기록·새로 시작.
// 시작 시각과 측정값은 임시 저장('pressure_test_draft_v1'의 'record')에 넣어, 화면이나 앱을 나갔다 와도
// 저장된 시작 시각으로 경과 시간을 다시 계산한다. 판정은 test_record.dart의 judgePressureTest.
part of 'pressure_test_page.dart';

/// 측정값 입력 창에서 돌려주는 값.
class _ReadingInput {
  final double kpa;
  final double? tempC;
  final bool delete;
  const _ReadingInput(this.kpa, this.tempC, {this.delete = false});
}

mixin _PtRecordTab on State<PressureTestPage>, CalcFormParts<PressureTestPage> {
  // 페이지(시험 압력 탭 등)의 값·도움 함수. 이 mixin은 _PressureTestPageState에만 쓴다.
  _PressureTestPageState get _pg => this as _PressureTestPageState;

  // ── 시험 기록 탭의 값 ──
  final _rHold = TextEditingController(text: '10');
  final _rAllow = TextEditingController();
  final _rLine = TextEditingController();
  final _rOd = TextEditingController();
  final _rWall = TextEditingController();
  PipeMaterial _rMat = PipeMaterial.carbon;
  bool _rLeakOk = false;
  DateTime? _rStart;
  DateTime? _rEnd;
  List<PtReading> _rReads = const [];
  PtRecord? _rEditing; // 불러오거나 저장한 기록(고쳐 저장할 때 같은 id)
  double? _rLastTemp; // 마지막에 넣은 온도(다음 입력 창에 미리 채움)

  Timer? _rAlarmTimer; // 유지시간·라인 번호를 고칠 때 알림 다시 예약(잠시 뒤)
  String? _rScheduledKey; // 이 화면이 예약한 알림(시각|본문)

  /// 정확한 알람을 쓸 수 있는지(null: 아직 모름). setState 대신 이것으로 다시 그려
  /// 임시 저장을 읽기 전에 "사용자가 고침"으로 잡히지 않게 한다.
  final ValueNotifier<bool?> _rExact = ValueNotifier(null);

  HoldAlarm get _alarm => widget.holdAlarm ?? const PluginHoldAlarm();
  DateTime _now() => (widget.now ?? DateTime.now)();

  /// 임시 저장·해제에 같이 넣는 칸.
  Map<String, TextEditingController> get _recordFields => {
    'rHold': _rHold,
    'rAllow': _rAllow,
    'rLine': _rLine,
    'rOd': _rOd,
    'rWall': _rWall,
  };

  void _recordInit() {
    _rHold.addListener(_onAlarmInputChanged);
    _rLine.addListener(_onAlarmInputChanged);
    _checkExact();
  }

  void _recordDispose() {
    _rAlarmTimer?.cancel();
    _rAlarmTimer = null;
    _rExact.dispose();
  }

  // ── 정확한 알람 ──
  // 꺼져 있으면 안드로이드가 알림을 묶어 보내 몇 분 늦는다(폰 시험 09-26: 5분 30초 늦음).
  // 타이머 아래에 알리고 "설정 열기"로 허용 화면을 연다. 돌아와서 켜졌으면 알림을 다시 예약한다.

  Future<void> _checkExact() async => _applyExact(await _alarm.canExact());

  /// 폰 설정에서 돌아왔을 때(페이지가 부른다).
  void _recordResumed() => _checkExact();

  Future<void> _openExactSettings() async =>
      _applyExact(await _alarm.requestExact());

  /// 꺼져 있던 것이 켜졌고 진행 중이면 정확한 방식으로 다시 예약한다(같은 번호라 앞 예약이 바뀐다).
  Future<void> _applyExact(bool exact) async {
    if (!mounted) return;
    final was = _rExact.value;
    _rExact.value = exact;
    if (exact && was == false && _rRunning) {
      _rScheduledKey = null;
      await _syncAlarm();
    }
  }

  Map<String, dynamic> _recordDraftJson() => {
    'mat': _rMat.name,
    'leakOk': _rLeakOk,
    'start': _rStart?.toIso8601String(),
    'end': _rEnd?.toIso8601String(),
    'reads': [for (final r in _rReads) r.toJson()],
    'editing': _rEditing?.id,
    'lastT': _rLastTemp,
  };

  void _applyRecordDraft(Object? m) {
    if (m is! Map) return;
    _rMat = PipeMaterial.values.firstWhere(
      (v) => v.name == m['mat'],
      orElse: () => _rMat,
    );
    _rLeakOk = m['leakOk'] == true;
    _rStart = DateTime.tryParse(m['start']?.toString() ?? '');
    _rEnd = _rStart == null
        ? null
        : DateTime.tryParse(m['end']?.toString() ?? '');
    final reads = m['reads'];
    _rReads = [
      if (reads is List)
        for (final r in reads) ?PtReading.fromJson(r),
    ];
    final t = m['lastT'];
    _rLastTemp = t is num ? t.toDouble() : null;
  }

  /// 임시 저장에 적힌 "불러온 기록"을 폰 기록에서 찾는다.
  Future<PtRecord?> _draftEditing(String raw) async {
    try {
      final m = jsonDecode(raw);
      final rec = m is Map ? m['record'] : null;
      final id = rec is Map ? rec['editing'] : null;
      if (id is! String) return null;
      for (final r in await PtRecordStore.load()) {
        if (r.id == id) return r;
      }
    } catch (_) {
      // 못 찾으면 새 기록으로 본다.
    }
    return null;
  }

  // ── 유지시간 ──

  /// 규격 최소 유지시간(분). 설계압력이 없어도 규격·시험 종류로 정한다.
  double get _codeHoldMin =>
      (_pg._currentPlan ??
              testPlan(code: _pg._code, medium: _pg._medium, designKpa: 100))
          .holdMin;

  /// 판정·타이머에 쓰는 유지시간: 입력값과 규격 최소 중 큰 것.
  double get _requiredHold {
    final v = _pg._num(_rHold);
    final min = _codeHoldMin;
    return v == null || v <= 0 ? min : math.max(v, min);
  }

  bool get _rRunning => _rStart != null && _rEnd == null;

  DateTime? get _rDue =>
      _rStart?.add(Duration(milliseconds: (_requiredHold * 60000).round()));

  PtVerdict get _rVerdict => judgePressureTest(
    medium: _pg._medium,
    readings: _rReads,
    startAt: _rStart,
    endAt: _rEnd,
    holdMin: _requiredHold,
    allowKpa: _pg._kpa(_rAllow),
    leakOk: _rLeakOk,
    odMm: _rOdMm,
    wallMm: _rWallMm,
    material: _rMaterial,
  );

  // 수압 물 온도 영향 계산 치수: 튜브면 시험 압력 탭 튜브 규격(공칭), 배관이면 이 탭의 칸.
  double? get _rOdMm => _pg._tube ? _pg._tubeSize.odMm : _pg._num(_rOd);
  double? get _rWallMm => _pg._tube ? _pg._tubeSize.wallMm : _pg._num(_rWall);
  PipeMaterial get _rMaterial => _pg._tube ? _pg._tubePipeMat : _rMat;

  void _onAlarmInputChanged() {
    _rAlarmTimer?.cancel();
    if (!_rRunning && _rScheduledKey == null) return;
    _rAlarmTimer = Timer(const Duration(seconds: 1), _syncAlarm);
  }

  /// 진행 중이면 완료 시각에 알림을 예약한다(같은 시각·본문이면 그대로).
  /// 완료 시각이 지났거나 진행 중이 아니면, 이 화면이 예약한 알림만 취소한다.
  Future<void> _syncAlarm() async {
    final due = _rRunning ? _rDue : null;
    if (due == null || !due.isAfter(_now())) {
      if (_rScheduledKey != null) {
        _rScheduledKey = null;
        await _alarm.cancel();
      }
      return;
    }
    final body = ptHoldBody(line: _rLine.text, holdMin: _requiredHold);
    final key = '${due.toIso8601String()}|$body';
    if (key == _rScheduledKey) return;
    _rScheduledKey = key;
    await _alarm.schedule(due, title: kPtHoldTitle, body: body);
  }

  Future<void> _cancelAlarm() async {
    _rAlarmTimer?.cancel();
    _rScheduledKey = null;
    await _alarm.cancel();
  }

  // ── 입력 창 ──

  void _rSnack(String t, {SnackBarAction? action}) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t), action: action));

  Future<_ReadingInput?> _askReading({
    required String title,
    required String okLabel,
    double? kpa,
    double? tempC,
    String? note,
    bool canDelete = false,
  }) => showDialog<_ReadingInput>(
    context: context,
    builder: (_) => _PtReadingDialog(
      title: title,
      okLabel: okLabel,
      unit: _pg._unit,
      kpa: kpa,
      tempC: tempC,
      note: note,
      canDelete: canDelete,
    ),
  );

  Future<void> _startHold() async {
    final last = _rReads.isEmpty ? null : _rReads.last;
    final res = await _askReading(
      title: '시작 압력·온도',
      okLabel: '시작',
      kpa: last?.kpa ?? _pg._currentPlan?.usedKpa,
      tempC: last?.tempC ?? _rLastTemp,
      note: '확인을 누른 시각부터 유지시간을 계산합니다.',
    );
    if (res == null || !mounted) return;
    final now = _now();
    setState(() {
      _rStart = now;
      _rEnd = null;
      _rReads = [
        PtReading(
          at: now,
          kpa: res.kpa,
          tempC: res.tempC,
          kind: PtReadKind.start,
        ),
      ];
      if (res.tempC != null) _rLastTemp = res.tempC;
    });
    _pg._saveNow();
    await _syncAlarm();
  }

  Future<void> _addReading() async {
    final last = _rReads.isEmpty ? null : _rReads.last;
    final res = await _askReading(
      title: '측정 추가',
      okLabel: '추가',
      kpa: last?.kpa,
      tempC: last?.tempC ?? _rLastTemp,
    );
    if (res == null || !mounted) return;
    setState(() {
      _rReads = [
        ..._rReads,
        PtReading(at: _now(), kpa: res.kpa, tempC: res.tempC),
      ];
      if (res.tempC != null) _rLastTemp = res.tempC;
    });
    _pg._saveNow();
  }

  Future<void> _endHold() async {
    final s = _rStart;
    if (s == null) return;
    final elapsed = ptMinutes(_now().difference(s));
    final hold = _requiredHold;
    final last = _rReads.isEmpty ? null : _rReads.last;
    final res = await _askReading(
      title: '종료 압력·온도',
      okLabel: '종료',
      kpa: last?.kpa,
      tempC: last?.tempC ?? _rLastTemp,
      note: elapsed < hold
          ? '유지시간 ${ptFmt(hold, 1)}분이 아직 지나지 않았습니다(경과 ${ptFmt(elapsed, 1)}분). '
                '지금 종료하면 불합격입니다.'
          : null,
    );
    if (res == null || !mounted) return;
    final now = _now();
    setState(() {
      _rEnd = now;
      _rReads = [
        ..._rReads,
        PtReading(
          at: now,
          kpa: res.kpa,
          tempC: res.tempC,
          kind: PtReadKind.end,
        ),
      ];
      if (res.tempC != null) _rLastTemp = res.tempC;
    });
    _pg._saveNow();
    await _cancelAlarm();
  }

  Future<void> _editReading(int i) async {
    final r = _rReads[i];
    final res = await _askReading(
      title: '${ptReadKindLabel(r.kind)} 값 고치기',
      okLabel: '고치기',
      kpa: r.kpa,
      tempC: r.tempC,
      note: '시각(${ptHms(r.at)})은 그대로 둡니다.',
      canDelete: r.kind == PtReadKind.mid,
    );
    if (res == null || !mounted || i >= _rReads.length) return;
    setState(() {
      final list = [..._rReads];
      if (res.delete) {
        list.removeAt(i);
      } else {
        list[i] = r.withValues(res.kpa, res.tempC);
      }
      _rReads = list;
    });
  }

  Future<bool> _rConfirm(String title, String body, String okLabel) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            key: const Key('pt_r_confirm_ok'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(okLabel, style: TextStyle(color: fc.danger)),
          ),
        ],
      ),
    );
    return ok == true && mounted;
  }

  Future<void> _confirmNewRecord() async {
    if (_rStart == null &&
        _rReads.isEmpty &&
        _rEditing == null &&
        !_rLeakOk &&
        _rLine.text.trim().isEmpty) {
      return;
    }
    final running = _rRunning;
    if (!await _rConfirm(
      '새로 시작',
      '시작 시각·측정 기록·누설 확인·라인 번호를 지우고 새로 시작하겠습니까? 저장한 기록은 지워지지 않습니다.'
          '${running ? ' 유지시간 알림도 취소합니다.' : ''}',
      '새로 시작',
    )) {
      return;
    }
    setState(() {
      _rStart = null;
      _rEnd = null;
      _rReads = const [];
      _rLeakOk = false;
      _rEditing = null;
      _rLine.clear();
    });
    _pg._saveNow();
    await _cancelAlarm();
  }

  Future<void> _saveRecord() async {
    final start = _rStart;
    if (start == null || _rReads.isEmpty) {
      _rSnack('시작 압력을 넣고 시작한 뒤 저장하십시오.');
      return;
    }
    final ed = _rEditing;
    final tester = ed?.tester ?? await PtRecordStore.lastTester();
    final (gauges, relief, reliefNo) = ed != null
        ? (ed.gauges, ed.reliefKpa, ed.reliefNo)
        : await PtRecordStore.lastGear();
    if (!mounted) return;
    final line = _rLine.text.trim();
    final res = await showModalBottomSheet<PtSaveResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: fc.surface,
      builder: (_) => PtSaveSheet(
        editing: ed,
        unit: _pg._unit,
        medium: _pg._medium,
        line: line.isNotEmpty ? line : (ed?.line ?? ''),
        date: ed?.date ?? start,
        tester: tester,
        gauges: gauges,
        reliefKpa: relief,
        reliefNo: reliefNo,
      ),
    );
    if (res == null || !mounted) return;
    final keep = !res.asNew && ed != null;
    final design = _pg._kpa(_pg._design);
    final actual = _pg._kpa(_pg._actual);
    final allow = _pg._kpa(_rAllow);
    final rec = PtRecord(
      id: keep ? ed.id : _now().microsecondsSinceEpoch.toString(),
      date: DateTime(
        res.date.year,
        res.date.month,
        res.date.day,
        start.hour,
        start.minute,
      ),
      testNo: res.testNo,
      site: res.site,
      system: res.system,
      line: res.line,
      pid: res.pid,
      section: res.section,
      code: _pg._code,
      medium: _pg._medium,
      fluid: res.fluid,
      designKpa: design != null && design > 0 ? design : null,
      testKpa:
          _pg._currentPlan?.usedKpa ??
          (actual != null && actual > 0 ? actual : null),
      unit: _pg._unit,
      holdMin: _requiredHold,
      startAt: start,
      endAt: _rEnd,
      readings: _rReads,
      allowKpa: allow != null && allow >= 0 ? allow : null,
      leakOk: _rLeakOk,
      gauges: res.gauges,
      reliefKpa: res.reliefKpa,
      reliefNo: res.reliefNo,
      tester: res.tester,
      witnessContractor: res.witnessContractor,
      witnessSupervisor: res.witnessSupervisor,
      witnessOwner: res.witnessOwner,
      memo: res.memo,
      odMm: _rOdMm,
      wallMm: _rWallMm,
      material: _rMaterial,
      tubeId: _pg._tube ? _pg._tubeSize.id : '',
      tubeSpec: _pg._tube ? _pg._tubeSpec : '',
      tubeMat: _pg._tube ? _pg._tubeMat.name : '',
    );
    await PtRecordStore.put(rec);
    if (!mounted) return;
    setState(() {
      _rEditing = rec;
      _rLine.text = rec.line;
    });
    _rSnack(
      '${rec.line} 기록을 저장했습니다.',
      action: SnackBarAction(
        label: '기록서 보기',
        onPressed: () => openPtRecordPdf(context, rec),
      ),
    );
  }

  Future<void> _openRecords() async {
    final r = await Navigator.of(
      context,
    ).push<PtRecord>(MaterialPageRoute(builder: (_) => const PtRecordsPage()));
    if (r == null || !mounted) return;
    await _cancelAlarm();
    if (!mounted) return;
    setState(() {
      _pg._loadPlanFrom(r);
      _rHold.text = ptFmt(r.holdMin, 1);
      if (r.allowKpa == null) {
        _rAllow.clear();
      } else {
        _pg._putKpa(_rAllow, r.allowKpa!);
      }
      _rLine.text = r.line;
      _rOd.text = r.odMm == null ? '' : ptFmt(r.odMm!, 3);
      _rWall.text = r.wallMm == null ? '' : ptFmt(r.wallMm!, 3);
      _rMat = r.material;
      _rLeakOk = r.leakOk;
      _rStart = r.startAt ?? r.startReading?.at;
      _rEnd = r.endAt ?? r.endReading?.at;
      _rReads = [...r.readings];
      _rEditing = r;
    });
    _pg._saveNow();
    await _syncAlarm();
    if (!mounted) return;
    _rSnack('${r.line} 기록을 불러왔습니다.');
  }

  // ── 화면 ──

  Widget _card({required Key key, required List<Widget> children}) => Container(
    key: key,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: fc.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: fc.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _cardTitle(String t, {Widget? trailing}) => Row(
    children: [
      Expanded(
        child: Text(
          t,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: fc.text,
          ),
        ),
      ),
      ?trailing,
    ],
  );

  Widget _line(String t, {Key? key, bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          t,
          key: key,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: color ?? fc.text,
          ),
        ),
      );

  Widget _textBox(
    String key,
    String label,
    TextEditingController c,
    String guide, {
    String? hint,
  }) => calcBox(
    child: Row(
      children: [
        Expanded(flex: 5, child: calcLabel(label, guide)),
        Expanded(
          flex: 5,
          child: TextField(
            key: Key(key),
            controller: c,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: fc.text,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hint,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
      ],
    ),
  );

  Widget _bigButton(
    String key,
    String label,
    VoidCallback onTap, {
    bool outlined = false,
  }) => SizedBox(
    height: 48,
    child: outlined
        ? OutlinedButton(
            key: Key(key),
            style: OutlinedButton.styleFrom(
              foregroundColor: fc.brand,
              side: BorderSide(color: fc.brand),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onTap,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          )
        : ElevatedButton(
            key: Key(key),
            style: ElevatedButton.styleFrom(
              backgroundColor: fc.brand,
              foregroundColor: fc.onBrand,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onTap,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
  );

  String _p4(double kpa) =>
      '${ptFmt(kpa / _pg._unit.kpa, 4)} ${_pg._unit.label}';

  Widget _recordTab() {
    final plan = _pg._currentPlan;
    final hydro = _pg._medium == TestMedium.hydro;
    final ed = _rEditing;
    final entered = _pg._num(_rHold);
    final codeMin = _codeHoldMin;
    final v = _rVerdict;
    return _pg._page([
      if (ed != null)
        Container(
          key: const Key('pt_r_editing'),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: fc.brandSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '불러온 기록: ${ed.line.isEmpty ? '(라인 번호 없음)' : ed.line} · ${ptDay(ed.date)}',
            style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
          ),
        ),
      _infoCard(plan),
      _pg._unitChips(),
      calcField(
        'pt_r_hold',
        '유지시간 (분)',
        _rHold,
        '시험압력에서 유지할 시간입니다. 규격 최소는 ${ptFmt(codeMin, 0)}분입니다. '
            '절차서가 30분·1시간 등으로 정했으면 그 값을 넣으십시오. '
            '규격 최소보다 짧게 넣으면 규격 최소로 판정합니다.',
      ),
      if (entered != null && entered < codeMin)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            '규격 최소 ${ptFmt(codeMin, 0)}분 미만이라 ${ptFmt(codeMin, 0)}분으로 판정합니다.',
            key: const Key('pt_r_hold_warn'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: fc.danger,
            ),
          ),
        ),
      _textBox(
        'pt_r_line',
        '라인 번호 (선택)',
        _rLine,
        '유지시간 완료 알림과 기록서에 적힙니다. "기록 저장" 창에서 넣어도 됩니다.',
        hint: '예: P-1001',
      ),
      const SizedBox(height: 4),
      _timerCard(),
      if (_rReads.isNotEmpty) _logCard(),
      calcField(
        'pt_r_allow',
        '허용 압력강하 (${_pg._unit.label}, 선택)',
        _rAllow,
        '절차서나 발주처가 정한 허용 압력강하입니다. 규격에는 수치 기준이 없습니다. '
            '입력하면 공압은 온도를 보정한 압력강하, 수압은 측정 압력강하로 합격·불합격을 판정합니다. '
            '비우면 압력강하는 판정하지 않습니다.',
      ),
      if (hydro && _pg._tube)
        _pg._tubeLine(
          'pt_r_tube',
          '튜브: ${_pg._tubeMat.label} ${_pg._tubeSize.label} (${_pg._tubeDims(_pg._tubeSize)}). '
              '물 온도 영향 계산에 씁니다.',
        )
      else if (hydro) ...[
        calcField(
          'pt_r_od',
          '관 외경 (mm, 선택)',
          _rOd,
          '물 온도가 바뀐 만큼 압력이 얼마나 바뀌는지 참고로 계산합니다. 판정에는 쓰지 않습니다. '
              '예: 50A = 60.5mm.',
        ),
        calcField(
          'pt_r_wall',
          '관 두께 (mm, 선택)',
          _rWall,
          '관 두께(스케줄)입니다. 예: 50A SCH40 = 3.9mm.',
        ),
        _pg._chips('재질', '탄소강·스테인리스에 따라 팽창이 달라 결과가 조금 바뀝니다.', [
          calcChip(
            'pt_r_cs',
            '탄소강',
            _rMat == PipeMaterial.carbon,
            () => setState(() => _rMat = PipeMaterial.carbon),
          ),
          calcChip(
            'pt_r_ss',
            '스테인리스',
            _rMat == PipeMaterial.stainless,
            () => setState(() => _rMat = PipeMaterial.stainless),
          ),
        ]),
      ],
      calcBox(
        child: CheckboxListTile(
          key: const Key('pt_r_leak'),
          value: _rLeakOk,
          onChanged: (x) => setState(() => _rLeakOk = x ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: fc.brand,
          title: Text(
            '누설·물맺힘 없음(육안 확인)',
            style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
          ),
          subtitle: Text(
            '모든 이음·연결부를 확인했으면 표시하십시오. 합격하려면 꼭 확인해야 합니다.',
            style: TextStyle(fontSize: 13, color: fc.textSub),
          ),
        ),
      ),
      const SizedBox(height: 8),
      calcResult(
        key: const Key('pt_r_result'),
        big: ptVerdictText(v.pass),
        caption: '판정',
        warn: v.pass == false,
        lines: [
          if (v.pass != true) ...v.reasons(_pg._unit),
          ...v.details(_pg._unit),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _bigButton('pt_r_save', '기록 저장', _saveRecord)),
          const SizedBox(width: 10),
          Expanded(
            child: _bigButton(
              'pt_r_records',
              '저장한 기록',
              _openRecords,
              outlined: true,
            ),
          ),
        ],
      ),
      Align(
        alignment: Alignment.centerRight,
        child: calcToggle('pt_r_new', '새로 시작', _confirmNewRecord),
      ),
    ]);
  }

  Widget _infoCard(TestPlan? plan) {
    final design = _pg._kpa(_pg._design);
    final actual = _pg._kpa(_pg._actual);
    final actualGiven = actual != null && actual > 0;
    final String test;
    if (plan != null) {
      test = actualGiven
          ? '시험압력: ${_pg._p(plan.usedKpa)} (실제 시험압력)'
          : '시험압력: ${_pg._p(plan.minKpa)} 이상 (최소 시험압력)';
    } else {
      test = actualGiven ? '시험압력: ${_pg._p(actual)} (실제 시험압력)' : '시험압력: 없음';
    }
    return _card(
      key: const Key('pt_r_info'),
      children: [
        _cardTitle(
          '시험 정보',
          trailing: calcToggle(
            'pt_r_goto_plan',
            '시험 압력 탭에서 바꾸기',
            () => _pg._tabs.animateTo(0),
          ),
        ),
        _line('규격: ${ptCodeLabel(_pg._code)}'),
        _line('시험 종류: ${ptMediumLabel(_pg._medium)}'),
        if (_pg._tube)
          _line('튜브: ${_pg._tubeSpec}', key: const Key('pt_r_info_tube')),
        _line(
          design == null || design <= 0
              ? '설계압력: 없음 (시험 압력 탭에서 넣으십시오)'
              : '설계압력: ${_pg._p(design)}',
        ),
        _line(test),
        _line('규정 유지시간: ${ptFmt(_codeHoldMin, 0)}분 이상'),
      ],
    );
  }

  Widget _timerCard() {
    final s = _rStart;
    final e = _rEnd;
    final due = _rDue;
    return _card(
      key: const Key('pt_r_timer'),
      children: [
        _cardTitle('유지시간 타이머'),
        const SizedBox(height: 6),
        _HoldClock(start: s, end: e, holdMin: _requiredHold, now: _now),
        if (s != null)
          _line(
            '시작 ${ptHms(s)}'
            '${e == null && due != null ? ' · 완료 예정 ${ptHm(due)}' : ''}'
            '${e == null ? '' : ' · 종료 ${ptHms(e)}'}',
            key: const Key('pt_r_times'),
          ),
        const SizedBox(height: 12),
        if (s == null)
          SizedBox(
            width: double.infinity,
            child: _bigButton('pt_r_start', '시작', _startHold),
          )
        else if (e == null) ...[
          Row(
            children: [
              Expanded(
                child: _bigButton(
                  'pt_r_add',
                  '측정 추가',
                  _addReading,
                  outlined: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _bigButton('pt_r_end', '종료', _endHold)),
            ],
          ),
          _line(
            '완료 시각에 폰 알림이 울립니다. 화면이나 앱을 나가도 시간은 계속 계산됩니다.',
            color: fc.textSub,
          ),
        ] else
          _line('종료했습니다. 다음 시험은 "새로 시작"을 누르십시오.', color: fc.textSub),
        if (e == null)
          ValueListenableBuilder<bool?>(
            valueListenable: _rExact,
            builder: (_, exact, _) => exact != false
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _line(
                        kPtExactOffText,
                        key: const Key('pt_r_exact_off'),
                        bold: true,
                        color: fc.danger,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: calcToggle(
                          'pt_r_exact_open',
                          '설정 열기',
                          _openExactSettings,
                        ),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }

  Widget _logCard() {
    final s = _rStart;
    return _card(
      key: const Key('pt_r_log'),
      children: [
        _cardTitle('측정 기록'),
        _line('줄을 누르면 값을 고칠 수 있습니다.', color: fc.textSub),
        const SizedBox(height: 4),
        for (var i = 0; i < _rReads.length; i++)
          InkWell(
            key: Key('pt_r_read_$i'),
            onTap: () => _editReading(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      ptReadKindLabel(_rReads[i].kind),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _rReads[i].kind == PtReadKind.mid
                            ? fc.text
                            : fc.brand,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      '${ptHms(_rReads[i].at)}\n'
                      '${s == null ? '' : '${ptFmt(ptMinutes(_rReads[i].at.difference(s)), 1)}분'}',
                      style: TextStyle(fontSize: 14, color: fc.text),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      '${_p4(_rReads[i].kpa)}\n'
                      '${_rReads[i].tempC == null ? '' : '${ptFmt(_rReads[i].tempC!, 1)}°C'}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: fc.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 경과 시간·남은 시간(1초마다 다시 그린다). 저장된 시작 시각으로 계산하므로 화면을 나갔다 와도 맞다.
class _HoldClock extends StatefulWidget {
  final DateTime? start;
  final DateTime? end;
  final double holdMin;
  final DateTime Function() now;
  const _HoldClock({
    required this.start,
    required this.end,
    required this.holdMin,
    required this.now,
  });

  @override
  State<_HoldClock> createState() => _HoldClockState();
}

class _HoldClockState extends State<_HoldClock> {
  Timer? _tick;

  void _sync() {
    final running = widget.start != null && widget.end == null;
    if (running && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!running) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _HoldClock old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.start;
    final e = widget.end;
    final elapsed = s == null
        ? Duration.zero
        : (e ?? widget.now()).difference(s);
    final hold = Duration(milliseconds: (widget.holdMin * 60000).round());
    final done = s != null && elapsed >= hold;
    final h = ptFmt(widget.holdMin, 1);
    final status = s == null
        ? '시작 전'
        : (e != null ? '종료' : (done ? '유지시간 완료' : '유지 중'));
    final String remain;
    if (s == null) {
      remain = '유지시간 $h분';
    } else if (done) {
      remain = '유지시간 완료 ($h분)';
    } else if (e != null) {
      remain = '유지시간 $h분 미만에 종료했습니다.';
    } else {
      remain = '남은 시간 ${ptClock(hold - elapsed)}';
    }
    final bad = e != null && !done;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          status,
          key: const Key('pt_r_status'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: fc.textSub,
          ),
        ),
        Text(
          ptClock(elapsed),
          key: const Key('pt_r_elapsed'),
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: done ? fc.brand : fc.text,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          remain,
          key: const Key('pt_r_remain'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: bad ? fc.danger : (done ? fc.brand : fc.text),
          ),
        ),
      ],
    );
  }
}

/// 압력·온도 입력 창. 입력 칸은 이 창이 만들고 치운다.
class _PtReadingDialog extends StatefulWidget {
  final String title;
  final String okLabel;
  final PUnit unit;
  final double? kpa;
  final double? tempC;
  final String? note;
  final bool canDelete;
  const _PtReadingDialog({
    required this.title,
    required this.okLabel,
    required this.unit,
    this.kpa,
    this.tempC,
    this.note,
    this.canDelete = false,
  });

  @override
  State<_PtReadingDialog> createState() => _PtReadingDialogState();
}

class _PtReadingDialogState extends State<_PtReadingDialog> {
  late final String _pText = widget.kpa == null
      ? ''
      : ptFmt(widget.kpa! / widget.unit.kpa, 4);
  late final _pc = TextEditingController(text: _pText)
    ..selection = TextSelection(baseOffset: 0, extentOffset: _pText.length);
  late final _tc = TextEditingController(
    text: widget.tempC == null ? '' : ptFmt(widget.tempC!, 1),
  );
  String? _pErr;
  String? _tErr;

  @override
  void dispose() {
    _pc.dispose();
    _tc.dispose();
    super.dispose();
  }

  void _ok() {
    final pt = _pc.text.trim().replaceAll(',', '');
    final tt = _tc.text.trim().replaceAll(',', '');
    final pv = double.tryParse(pt);
    final tv = tt.isEmpty ? null : double.tryParse(tt);
    setState(() {
      _pErr = pv == null ? '압력을 넣으십시오' : null;
      _tErr = tt.isNotEmpty && (tv == null || tv <= -273.15)
          ? '온도는 숫자로 넣으십시오'
          : null;
    });
    if (_pErr != null || _tErr != null) return;
    // 미리 채운 글 그대로면 저장된 kPa를 그대로(반올림 누적 방지).
    final kpa = pt == _pText && widget.kpa != null
        ? widget.kpa!
        : pv! * widget.unit.kpa;
    Navigator.pop(context, _ReadingInput(kpa, tv));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.note != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                widget.note!,
                key: const Key('pt_rd_note'),
                style: TextStyle(fontSize: 14, color: fc.text, height: 1.4),
              ),
            ),
          TextField(
            key: const Key('pt_rd_p'),
            controller: _pc,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '압력 (${widget.unit.label})',
              errorText: _pErr,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('pt_rd_t'),
            controller: _tc,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: InputDecoration(
              labelText: '온도 (°C, 선택)',
              errorText: _tErr,
            ),
            onSubmitted: (_) => _ok(),
          ),
        ],
      ),
    ),
    actions: [
      if (widget.canDelete)
        TextButton(
          key: const Key('pt_rd_delete'),
          onPressed: () => Navigator.pop(
            context,
            const _ReadingInput(0, null, delete: true),
          ),
          child: Text('지우기', style: TextStyle(color: fc.danger)),
        ),
      TextButton(
        key: const Key('pt_rd_cancel'),
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      TextButton(
        key: const Key('pt_rd_ok'),
        onPressed: _ok,
        child: Text(widget.okLabel),
      ),
    ],
  );
}
