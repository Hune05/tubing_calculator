// 축 정렬 계산기: 모터·펌프 커플링 센터링. 다이얼 게이지 읽음값으로 앞발·뒷발에 넣고 뺄 심 두께와 좌우 이동량을 구한다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_icon_set.dart';
import '../../core/theme/app_tokens.dart';
import '../equipment/equipment_model.dart';
import '../equipment/equipment_store.dart';
import '../tube_cutting/cutting_action_bar.dart' show kakaoSender, textSharer;
import 'alignment_guide_painter.dart';
import 'alignment_math.dart';
import 'alignment_dial_painter.dart';
import 'alignment_render.dart';
import 'alignment_record.dart';
import 'alignment_session.dart';

Future<void> _defaultShare(String text) async {
  if (await kakaoSender(text)) return;
  await textSharer(text);
}

class AlignmentPage extends StatefulWidget {
  final Future<void> Function(String text) share;
  final DateTime Function()? now;
  const AlignmentPage({super.key, this.share = _defaultShare, this.now});

  @override
  State<AlignmentPage> createState() => _AlignmentPageState();
}

class _AlignmentPageState extends State<AlignmentPage> {
  AlignMethod _method = AlignMethod.reverse;
  final Map<String, TextEditingController> _c = {};
  bool _showSag = false;
  bool _showTarget = false;
  // 허용 기준(현장 기준). 처음에는 0.05 mm로 두고, 고치면 폰에 남아 다음에도 그 값으로 판정한다.
  static const String _tolKey = 'align_tolerance_v1';
  static const AlignTolerance _tolStart = AlignTolerance(0.05, 0.05);
  final TextEditingController _tolO = TextEditingController(text: _fmtTol(_tolStart.offset));
  final TextEditingController _tolA = TextEditingController(text: _fmtTol(_tolStart.angle100));

  static String _fmtTol(double v) => v.toStringAsFixed(v * 100 == (v * 100).roundToDouble() ? 2 : 3);
  List<AlignRound> _rounds = []; // 이번 정렬 작업의 회차(폰에 남아 있다)

  DateTime get _now => (widget.now ?? DateTime.now)();

  TextEditingController _f(String key) => _c.putIfAbsent(key, () => TextEditingController());

  @override
  void initState() {
    super.initState();
    _loadTol();
    AlignSessionStore.load().then((v) {
      if (mounted && v.isNotEmpty) setState(() => _rounds = v);
    });
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    _tolO.dispose();
    _tolA.dispose();
    super.dispose();
  }

  /// 숫자로 읽는다(쉼표 소수점도 허용). 비었거나 숫자가 아니면 null.
  double? _n(String key) {
    final t = _f(key).text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  double _opt(String key) => _n(key) ?? 0;

  int get _rpm => int.tryParse(_f('rpm').text.trim()) ?? 1800;

  AlignTolerance get _tol {
    final o = double.tryParse(_tolO.text.trim().replaceAll(',', '.'));
    final g = double.tryParse(_tolA.text.trim().replaceAll(',', '.'));
    return AlignTolerance(o != null && o > 0 ? o : _tolStart.offset, g != null && g > 0 ? g : _tolStart.angle100);
  }

  Future<void> _loadTol() async {
    final v = (await SharedPreferences.getInstance()).getStringList(_tolKey);
    if (!mounted || v == null || v.length != 2) return;
    setState(() {
      _tolO.text = v[0];
      _tolA.text = v[1];
    });
  }

  Future<void> _saveTol() async {
    setState(() {});
    await (await SharedPreferences.getInstance()).setStringList(_tolKey, [_tolO.text.trim(), _tolA.text.trim()]);
  }

  /// 값이 다 들어오면 계산한다. 덜 들어왔으면 null, 잘못된 값이면 오류 글.
  ({AlignResult? result, String? error}) _solve() {
    List<double>? three(String p) {
      final v = [for (final s in ['90', '180', '270']) _n('$p$s')];
      return v.any((e) => e == null) ? null : [for (final e in v) e!];
    }

    try {
      if (_method == AlignMethod.reverse) {
        final a = three('a'), b = three('b');
        final d = _n('between'), xc = _n('coupB'), f1 = _n('front'), f2 = _n('rear');
        if (a == null || b == null || d == null || xc == null || f1 == null || f2 == null) {
          return (result: null, error: null);
        }
        return (
          result: solveReverse(
            a90: a[0], a180: a[1], a270: a[2],
            b90: b[0], b180: b[1], b270: b[2],
            sagA: _opt('sagA'), sagB: _opt('sagB'),
            betweenPlanes: d, couplingFromB: xc, frontFoot: f1, rearFoot: f2,
            targetY: _opt('targetY'), targetZ: _opt('targetZ'),
          ),
          error: null,
        );
      }
      final r = three('r'), f = three('f');
      final rho = _n('faceR'), g = _n('coupR'), f1 = _n('front'), f2 = _n('rear');
      if (r == null || f == null || rho == null || g == null || f1 == null || f2 == null) {
        return (result: null, error: null);
      }
      return (
        result: solveRimFace(
          r90: r[0], r180: r[1], r270: r[2],
          f90: f[0], f180: f[1], f270: f[2],
          sagRim: _opt('sagR'),
          faceRadius: rho, couplingFromRim: g, frontFoot: f1, rearFoot: f2,
          targetY: _opt('targetY'), targetZ: _opt('targetZ'),
        ),
        error: null,
      );
    } on AlignInputError catch (e) {
      return (result: null, error: e.message);
    }
  }

  /// 저장하려고 화면의 값을 그대로 모은다.
  Map<String, String> _inputs() => {
    for (final e in _c.entries)
      if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
    'method': _method.name,
  };

  double get _rearX {
    if (_method == AlignMethod.reverse) {
      return (_n('between') ?? 0) - (_n('coupB') ?? 0) + (_n('rear') ?? 0);
    }
    return (_n('coupR') ?? 0) + (_n('rear') ?? 0);
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _save(AlignResult r) async {
    final machineDefault = await AlignStore.lastMachine();
    final equipment = await EquipmentStore.load();
    if (!mounted) return;
    final out = await showModalBottomSheet<AlignRecord>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SaveSheet(
        result: r,
        method: _method,
        rpm: _rpm,
        inputs: _inputs(),
        verdict: judge(r, _tol),
        now: _now,
        machineDefault: machineDefault,
        equipment: [for (final e in equipment) if (!e.isRetired) e],
        rounds: _rounds,
      ),
    );
    if (out == null) return;
    await AlignStore.put(out);
    if (_rounds.isNotEmpty) await _setRounds([]); // 회차는 기록에 같이 저장됐다
    // 장비 대장의 장비를 골랐으면 그 장비 이력에 "축 정렬"을 남긴다(교정 기한은 그대로).
    if (out.equipmentId.isNotEmpty) {
      final list = await EquipmentStore.load();
      for (final e in list) {
        if (e.id == out.equipmentId) {
          await EquipmentStore.put(
            recordAlignment(
              e,
              at: out.at,
              note: '${out.stage.label} · 평행 ${out.offset.toStringAsFixed(3)} mm, 각도 ${out.angle100.toStringAsFixed(3)} mm/100mm',
            ),
          );
        }
      }
    }
    final cmp = compareText(out, await AlignStore.load());
    _toast(cmp == null ? '기록했습니다' : '기록했습니다. $cmp');
  }

  Future<void> _openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => AlignmentHistoryPage(share: widget.share)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final solved = _solve();
    final r = solved.result;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('축 정렬 계산'),
        actions: [
          IconButton(
            key: const Key('align_history'),
            tooltip: '지난 기록',
            icon: const Icon(AppIcons.history),
            onPressed: _openHistory,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SegmentedButton<AlignMethod>(
            key: const Key('align_method'),
            segments: const [
              ButtonSegment(value: AlignMethod.reverse, label: Text('리버스 다이얼')),
              ButtonSegment(value: AlignMethod.rimFace, label: Text('림·페이스')),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.first),
          ),
          const SizedBox(height: 12),
          _methodCard(),
          _dialGuide(),
          _setupCard(),
          const SizedBox(height: 4),
          _card('회전수', [
            _row([_field('rpm', '회전수 (rpm)', hint: '예: 1800')]),
          ]),
          if (_method == AlignMethod.reverse) ..._reverseInputs() else ..._rimFaceInputs(),
          _toggleCard(
            keyName: 'align_sag_toggle',
            label: '브래킷 처짐 보정 (선택)',
            open: _showSag,
            onTap: () => setState(() => _showSag = !_showSag),
            child: _method == AlignMethod.reverse
                ? _row([_field('sagA', '다이얼 A 처짐 (mm)'), _field('sagB', '다이얼 B 처짐 (mm)')])
                : _row([_field('sagR', '림 다이얼 처짐 (mm)')]),
            help: '같은 다이얼 세팅을 어긋남 없는 곧은 관에 걸고 12시를 0으로 맞춘 뒤 6시에서 읽은 값입니다(보통 마이너스).',
          ),
          _toggleCard(
            keyName: 'align_target_toggle',
            label: '열팽창 목표 (선택)',
            open: _showTarget,
            onTap: () => setState(() => _showTarget = !_showTarget),
            child: _row([_field('targetY', '위아래 목표 (mm)'), _field('targetZ', '옆 목표 (mm)')]),
            help: '차가울 때 모터 축을 커플링 중심에서 이만큼 어긋나게 맞춰 두어야 운전 온도에서 맞는 경우에 넣습니다. + 위·오른쪽. 비우면 0.',
          ),
          const SizedBox(height: 4),
          if (solved.error != null)
            _notice(solved.error!, AppColors.danger, key: 'align_error')
          else if (r == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                '읽음값과 거리를 모두 넣으면 결과가 나옵니다.',
                key: Key('align_hint'),
                textAlign: TextAlign.center,
                style: AppText.sub,
              ),
            )
          else
            ..._results(r),
        ],
      ),
    );
  }

  // ── 방식 설명 ──

  Widget _methodCard() {
    final reverse = _method == AlignMethod.reverse;
    Widget line(String head, String body, Color c) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(head, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: c)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(body, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.text))),
        ],
      ),
    );
    return Container(
      key: const Key('align_method_help'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: AppColors.brandSoft, borderRadius: BorderRadius.circular(AppRadius.medium)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: reverse
            ? [
                const Text('리버스 다이얼 방식', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.text)),
                line('재는 것', '다이얼 두 개를 서로 반대로 걸어, 각각 상대 축의 림(바깥 둘레)을 읽습니다. A는 펌프 쪽에 걸어 모터 림을, B는 모터 쪽에 걸어 펌프 림을 읽습니다.', AppColors.brand),
                line('좋은 점', '옆면(페이스)을 재지 않아 축이 앞뒤로 밀려도 값이 덜 틀어집니다. 커플링 사이가 먼 경우(스페이서)에도 맞습니다.', AppColors.ok),
                line('주의', '두 접촉면 사이(①)가 짧으면 기울기 오차가 커집니다. 브래킷이 길면 처짐 보정을 넣습니다.', AppColors.caution),
              ]
            : [
                const Text('림·페이스 방식', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.text)),
                line('재는 것', '브래킷 하나에 다이얼 두 개를 달아, 하나는 모터 쪽 커플링의 림(바깥 둘레)을, 하나는 페이스(옆면)를 읽습니다. 림은 어긋남, 페이스는 기울기를 봅니다.', AppColors.brand),
                line('좋은 점', '한쪽 축에서만 걸면 되어 자리가 좁을 때 쉽습니다. 커플링 지름이 크고 사이가 가까울 때 잘 맞습니다.', AppColors.ok),
                line('주의', '돌리는 동안 축이 앞뒤로 밀리면 페이스 값이 틀어집니다. 축을 한쪽으로 밀어 붙인 채 읽습니다. 페이스가 닿는 반지름(④)을 정확히 잽니다.', AppColors.caution),
              ],
      ),
    );
  }

  // ── 정렬 작업 회차 ──

  Future<void> _setRounds(List<AlignRound> next) async {
    setState(() => _rounds = next);
    await AlignSessionStore.save(next);
  }

  Future<void> _addRound(AlignResult r) async {
    final round = AlignRound(
      at: _now,
      offset: r.offset,
      angle100: r.angle100,
      verdict: judge(r, _tol),
      shimFront: r.shimFront,
      shimRear: r.shimRear,
      moveFront: r.moveFront,
      moveRear: r.moveRear,
    );
    await _setRounds([..._rounds, round]);
    await _editDone(_rounds.length - 1);
  }

  Future<void> _editDone(int i) async {
    final out = await showModalBottomSheet<AlignRound>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DoneSheet(round: _rounds[i], index: i),
    );
    if (out == null) return;
    await _setRounds([for (var k = 0; k < _rounds.length; k++) k == i ? out : _rounds[k]]);
  }

  Widget _roundsCard(AlignResult r) {
    final totals = shimTotals(_rounds);
    final moves = moveTotals(_rounds);
    final anyDone = _rounds.any((x) => x.done != null);
    Widget total(AlignFoot f) => Expanded(
      child: Container(
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text(f.label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSub, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${signedMm(totals[f]!)} mm', key: Key('align_total_${f.name}'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.text)),
          ],
        ),
      ),
    );
    return _card('정렬 작업 기록 (회차)', [
      if (_rounds.isEmpty)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            '재기 → 심 넣고 빼기·옆으로 밀기 → 다시 재기를 회차로 남깁니다. 발마다 넣고 뺀 심이 누계로 쌓여, 지금 발 밑에 얼마가 더 들어가 있는지 알 수 있습니다.',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSub),
          ),
        ),
      for (var i = 0; i < _rounds.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.brandSoft, borderRadius: BorderRadius.circular(8)),
                child: Text('${i + 1}회차', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.brand)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '평행 ${_rounds[i].offset.toStringAsFixed(3)} mm · 각도 ${_rounds[i].angle100.toStringAsFixed(3)} · ${verdictLabel(_rounds[i].verdict)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text('한 일: ${doneLine(_rounds[i])}', key: Key('align_round_line_$i'), style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textSub)),
                  ],
                ),
              ),
              TextButton(
                key: Key('align_round_done_$i'),
                onPressed: () => _editDone(i),
                child: Text(_rounds[i].done == null ? '한 일 적기' : '고치기'),
              ),
            ],
          ),
        ),
      if (anyDone) ...[
        const Divider(height: 16),
        const Text('발 밑 심 누계 (시작할 때보다)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textSub)),
        const SizedBox(height: 4),
        Row(children: [total(AlignFoot.frontLeft), total(AlignFoot.rearLeft)]),
        Row(children: [total(AlignFoot.frontRight), total(AlignFoot.rearRight)]),
        if (moves.$1.abs() >= 0.005 || moves.$2.abs() >= 0.005)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text('옆으로 민 누계: 앞 ${moveText(moves.$1)}, 뒤 ${moveText(moves.$2)}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSub)),
          ),
      ],
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const Key('align_round_add'),
              onPressed: () => _addRound(r),
              child: Text('지금 결과를 ${_rounds.length + 1}회차로 적기'),
            ),
          ),
          if (_rounds.isNotEmpty) ...[
            const SizedBox(width: 8),
            TextButton(
              key: const Key('align_round_undo'),
              onPressed: () => _setRounds(_rounds.sublist(0, _rounds.length - 1)),
              child: const Text('마지막 회차 지우기'),
            ),
          ],
        ],
      ),
      if (_rounds.isNotEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('다 끝나면 아래 "기록 남기기"로 저장합니다. 회차와 심 누계가 같이 저장됩니다.', style: TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
        ),
    ]);
  }

  // ── 입력 ──

  /// 다이얼 게이지 쓰는 법과 읽는 법: 실물 모양 다이얼 그림으로.
  Widget _dialGuide() {
    Widget tile(double v, String caption, {bool bezel = false}) => Expanded(
      child: Column(
        children: [
          SizedBox(height: 104, child: CustomPaint(size: Size.infinite, painter: AlignSmallDialPainter(v, bezelArrow: bezel))),
          const SizedBox(height: 4),
          Text(caption, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, height: 1.35, color: AppColors.text, fontWeight: FontWeight.w600)),
        ],
      ),
    );
    return Card(
      margin: const EdgeInsets.only(top: 12),
      elevation: 0,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('다이얼 게이지 보는 법', style: AppText.title),
            const SizedBox(height: 6),
            SizedBox(
              height: 300,
              child: CustomPaint(key: const Key('align_dial_guide'), size: Size.infinite, painter: AlignDialGuidePainter(value: -0.12)),
            ),
            const SizedBox(height: 4),
            const Text(
              '큰 바늘이 0에서 시계 방향으로 가면 +(스핀들이 눌림), 반대로 가면 −(스핀들이 나옴)입니다. '
              '위 그림은 0에서 반시계 방향으로 12칸 → −0.12 mm입니다.',
              style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSub),
            ),
            const SizedBox(height: 14),
            Text('거는 순서', style: AppText.subtitle),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tile(0.5, '① 스핀들을 0.5 mm쯤\n눌러서 겁니다'),
                tile(0, '② 12시에서 베젤을\n돌려 0에 맞춥니다', bezel: true),
                tile(-0.10, '③ 두 축을 같이 돌려\n3·6·9시에서 읽습니다'),
                tile(0, '④ 12시로 오면\n다시 0인지 봅니다'),
              ],
            ),
            const SizedBox(height: 14),
            Text('보는 자리와 읽는 순서', style: AppText.subtitle),
            const SizedBox(height: 6),
            SizedBox(
              height: 300,
              child: CustomPaint(key: const Key('align_clock'), size: Size.infinite, painter: AlignClockPainter()),
            ),
            const SizedBox(height: 6),
            const Text(
              '고정 쪽(펌프)에 서서 이동 쪽(모터)을 바라봅니다. 이 자리에서 3시가 오른쪽, 9시가 왼쪽입니다. '
              '12시에서 0을 맞추고 축을 같이 돌려 3시 → 6시 → 9시 순서로 읽습니다.\n'
              '그림의 바늘은 읽은 예입니다(12시 0.00, 3시 −0.10, 6시 −0.20, 9시 −0.10). '
              '3시 + 9시 = 6시가 되면 제대로 읽은 것입니다. 크게 다르면 브래킷이 흔들리거나 스핀들이 덜 눌린 것이니 다시 겁니다.\n'
              '결과의 "넣기"는 발 밑에 심을 넣어 모터를 올리는 것, "오른쪽"은 이 자리에서 본 오른쪽입니다.',
              style: TextStyle(fontSize: 12.5, height: 1.55, color: AppColors.textSub),
            ),
          ],
        ),
      ),
    );
  }

  /// 측정 그림: 다이얼을 거는 자리와 재는 거리(번호는 아래 입력칸 이름과 같다).
  Widget _setupCard() => Card(
    margin: const EdgeInsets.only(top: 12),
    elevation: 0,
    color: AppColors.surface,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              _method == AlignMethod.reverse
                  ? '측정 그림 (리버스 다이얼: 두 다이얼이 서로 상대 림을 읽습니다)'
                  : '측정 그림 (림·페이스: 한 다이얼이 림과 옆면을 읽습니다)',
              style: AppText.title,
            ),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, c) => SizedBox(
              height: AlignSetupRenderPainter.heightFor(c.maxWidth),
              child: CustomPaint(
                key: const Key('align_setup_diagram'),
                size: Size.infinite,
                painter: AlignSetupRenderPainter(_method),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(6, 2, 6, 2),
            child: Text(
              '그림의 번호(①②③④)는 아래 입력칸 이름의 번호와 같습니다. 거리는 모두 mm로 잽니다. 그림 비율은 모터 IEC 160M, 펌프 ISO 2858 65-40-250 치수표를 따랐습니다(심 두께만 크게 그림).',
              style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSub),
            ),
          ),
        ],
      ),
    ),
  );

  List<Widget> _reverseInputs() => [
    _card('리버스 다이얼 읽음 (12시는 0)', [
      _readingRow('a', '다이얼 A (고정 쪽에 걸고 모터 림을 읽음)'),
      _readingRow('b', '다이얼 B (모터 쪽에 걸고 펌프 림을 읽음)'),
    ]),
    _card('거리 (mm)', [
      _row([_field('between', '① A·B 두 접촉면 사이'), _field('coupB', '② B면에서 커플링 중심까지')]),
      _row([_field('front', '③ A면에서 모터 앞발까지'), _field('rear', '④ A면에서 모터 뒷발까지')]),
    ]),
  ];

  List<Widget> _rimFaceInputs() => [
    _card('림·페이스 읽음 (12시는 0)', [
      _readingRow('r', '림 (바깥둘레)'),
      _readingRow('f', '페이스 (옆면)'),
    ]),
    _card('거리 (mm)', [
      _row([_field('coupR', '① 림면에서 커플링 중심까지'), _field('front', '② 림면에서 모터 앞발까지')]),
      _row([_field('rear', '③ 림면에서 모터 뒷발까지'), _field('faceR', '④ 페이스가 닿는 반지름')]),
    ]),
  ];

  Widget _readingRow(String p, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSub)),
        const SizedBox(height: 6),
        _row([
          _field('${p}90', '3시 (오른쪽)'),
          _field('${p}180', '6시 (아래)'),
          _field('${p}270', '9시 (왼쪽)'),
        ]),
      ],
    ),
  );

  Widget _card(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(top: 12),
    elevation: 0,
    color: AppColors.surface,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.title),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );

  Widget _toggleCard({
    required String keyName,
    required String label,
    required bool open,
    required VoidCallback onTap,
    required Widget child,
    required String help,
  }) => Card(
    margin: const EdgeInsets.only(top: 12),
    elevation: 0,
    color: AppColors.surface,
    child: Column(
      children: [
        InkWell(
          key: Key(keyName),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(child: Text(label, style: AppText.title)),
                Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.textSub),
              ],
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(help, style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSub)),
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
      ],
    ),
  );

  Widget _row(List<Widget> fields) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: fields[i]),
        ],
      ],
    ),
  );

  Widget _field(String key, String label, {String? hint}) => TextField(
    key: Key('align_$key'),
    controller: _f(key),
    onChanged: (_) => setState(() {}),
    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-+0-9.,]'))],
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    ),
  );

  Widget _notice(String text, Color color, {required String key}) => Container(
    key: Key(key),
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
    child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
  );

  // ── 결과 ──

  List<Widget> _results(AlignResult r) {
    final tol = _tol;
    final v = judge(r, tol);
    final ok = v == AlignVerdict.ok;
    final color = ok ? AppColors.ok : AppColors.danger;
    return [
      Container(
        key: const Key('align_verdict'),
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ok ? '허용 범위 안입니다' : verdictLabel(v),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              '평행 어긋남 ${r.offset.toStringAsFixed(3)} mm (허용 ${tol.offset.toStringAsFixed(2)})  ·  '
              '각도 ${r.angle100.toStringAsFixed(3)} mm/100mm (허용 ${tol.angle100.toStringAsFixed(2)})',
              key: const Key('align_offsets'),
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
      if (r.closure > 0.05)
        _notice(
          '읽음값이 서로 안 맞습니다 (3시 + 9시 ≠ 6시, 차이 ${r.closure.toStringAsFixed(2)} mm). '
          '다이얼이 흔들렸거나 부호를 잘못 넣었을 수 있습니다. 다시 읽어 보십시오.',
          AppColors.caution,
          key: 'align_closure',
        ),
      _card('발 이동량 (모터)', [
        _shimTable(r),
      ]),
      _roundsCard(r),
      Card(
        margin: const EdgeInsets.only(top: 12),
        elevation: 0,
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('위에서 본 모양 (네 발 심, 옆 이동)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSub)),
                ),
              ),
              LayoutBuilder(
                builder: (context, c) => SizedBox(
                  height: AlignTopRenderPainter.heightFor(c.maxWidth),
                  child: CustomPaint(
                    key: const Key('align_plan'),
                    size: Size.infinite,
                    painter: AlignTopRenderPainter(
                      horizontal: r.horizontal,
                      xRear: _rearX,
                      shimFront: r.shimFront,
                      shimRear: r.shimRear,
                      moveFront: r.moveFront,
                      moveRear: r.moveRear,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('옆에서 본 모양 (네 발 심, 위아래)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSub)),
                ),
              ),
              LayoutBuilder(
                builder: (context, c) => SizedBox(
                  height: AlignSideRenderPainter.heightFor(c.maxWidth),
                  child: CustomPaint(
                    key: const Key('align_diagram_v'),
                    size: Size.infinite,
                    painter: AlignSideRenderPainter(
                      vertical: r.vertical,
                      xRear: _rearX,
                      shimFront: r.shimFront,
                      shimRear: r.shimRear,
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: Text(
                  '그림의 심 판 두께와 옆 어긋남은 크게 부풀린 것입니다. 실제 값은 위 표를 보십시오. 왼쪽 발과 오른쪽 발은 같은 값입니다.',
                  style: TextStyle(fontSize: 11, color: AppColors.textFaint),
                ),
              ),
            ],
          ),
        ),
      ),
      _tolCard(tol),
      const SizedBox(height: 12),
      FilledButton.icon(
        key: const Key('align_save'),
        onPressed: () => _save(r),
        icon: const Icon(AppIcons.save, size: 18),
        label: const Text('기록 남기기'),
      ),
      const SizedBox(height: 6),
      const Text(
        '이 결과는 두 축의 어긋남을 직선으로 본 계산입니다. 소프트 풋(발 뜸)·파이프 변형·커플링 상태는 따로 확인하십시오. '
        '제조사·사내 정렬 기준이 있으면 그것이 우선입니다.',
        style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textFaint),
      ),
    ];
  }

  Widget _shimTable(AlignResult r) {
    Widget line(String foot, double shim, double move) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(foot, style: const TextStyle(fontWeight: FontWeight.w800))),
          Expanded(
            child: Text(
              '심 ${shimText(shim)}',
              key: Key('align_shim_${foot == '앞발' ? 'front' : 'rear'}'),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: shim.abs() < 0.005 ? AppColors.ok : AppColors.text),
            ),
          ),
          Expanded(
            child: Text(
              '옆 ${moveText(move)}',
              key: Key('align_move_${foot == '앞발' ? 'front' : 'rear'}'),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: move.abs() < 0.005 ? AppColors.ok : AppColors.text),
            ),
          ),
        ],
      ),
    );
    return Column(children: [line('앞발', r.shimFront, r.moveFront), const Divider(height: 1), line('뒷발', r.shimRear, r.moveRear)]);
  }

  Widget _tolCard(AlignTolerance tol) => Card(
    margin: const EdgeInsets.only(top: 12),
    elevation: 0,
    color: AppColors.surface,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('허용 오차', style: AppText.title),
          const SizedBox(height: 4),
          Text(
            '판정에 쓰는 현장 기준입니다. 처음에는 0.05 mm(100분의 5)로 두었고, 고치면 폰에 남아 다음에도 그 값으로 판정합니다. '
            '참고로 흔히 쓰는 경험값은 $_rpm rpm에서 평행 ${defaultTolerance(_rpm).offset.toStringAsFixed(2)} mm입니다.',
            style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSub),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('align_tol_offset'),
                  controller: _tolO,
                  onChanged: (_) => _saveTol(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '평행 어긋남 허용 (mm)', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('align_tol_angle'),
                  controller: _tolA,
                  onChanged: (_) => _saveTol(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '각도 허용 (mm/100mm)', isDense: true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

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
                    showCheckmark: false,
                    selectedColor: AppColors.brand,
                    backgroundColor: AppColors.surface,
                    labelStyle: TextStyle(fontWeight: FontWeight.w700, color: _stage == s ? Colors.white : AppColors.text),
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
                decoration: const InputDecoration(labelText: '장비 대장의 장비에 이력 남기기 (선택)'),
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
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('align_save_ok'),
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

  double _v(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.').replaceAll('−', '-')) ?? 0;

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
              '계산이 말한 값이 미리 들어 있습니다. 실제로 넣고 뺀 만큼으로 고치십시오. 넣은 심은 +, 뺀 심은 −입니다.',
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
                  const SizedBox(width: 10),
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
    } else if (action == 'delete') {
      await AlignStore.delete(r.id);
      await _reload();
    }
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
                  Card(
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
              ],
            ),
    );
  }
}
