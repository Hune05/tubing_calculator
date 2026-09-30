// 축 정렬 계산기: 모터·펌프 커플링 센터링. 다이얼 게이지 읽음값으로 앞발·뒷발에 넣고 뺄 심 두께와 좌우 이동량을 구한다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  String? _tolOffsetText; // 사용자가 고친 허용값(없으면 회전수별 참고값)
  String? _tolAngleText;

  DateTime get _now => (widget.now ?? DateTime.now)();

  TextEditingController _f(String key) => _c.putIfAbsent(key, () => TextEditingController());

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
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
    final d = defaultTolerance(_rpm);
    final o = double.tryParse((_tolOffsetText ?? '').replaceAll(',', '.'));
    final a = double.tryParse((_tolAngleText ?? '').replaceAll(',', '.'));
    return AlignTolerance(o ?? d.offset, a ?? d.angle100);
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
      ),
    );
    if (out == null) return;
    await AlignStore.put(out);
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
          _howTo(),
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

  // ── 입력 ──

  Widget _howTo() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.brandSoft, borderRadius: BorderRadius.circular(AppRadius.medium)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 170,
          height: 170,
          child: CustomPaint(key: const Key('align_clock'), painter: AlignClockPainter()),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            '읽는 방법\n'
            '① 고정 쪽(펌프)에서 이동 쪽(모터)을 바라보고 섭니다.\n'
            '② 다이얼을 12시에서 0으로 맞춥니다.\n'
            '③ 축을 같이 돌려 3시(오른쪽) → 6시(아래) → 9시(왼쪽) 순서로 읽습니다.\n'
            '다이얼이 눌리는 쪽이 + 입니다. 결과의 "넣기"는 발 밑에 심을 넣는 것(올림), "오른쪽"은 이 자리에서 본 오른쪽입니다.',
            style: TextStyle(fontSize: 13, height: 1.55, color: AppColors.text),
          ),
        ),
      ],
    ),
  );

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
            Text('읽은 예 (한 바퀴 돌리며)', style: AppText.subtitle),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tile(0, '12시\n0.00'),
                tile(-0.10, '3시 (오른쪽)\n−0.10'),
                tile(-0.20, '6시 (아래)\n−0.20'),
                tile(-0.10, '9시 (왼쪽)\n−0.10'),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '3시 + 9시 = 6시가 되면 제대로 읽은 것입니다(위 예: −0.10 + −0.10 = −0.20). 크게 다르면 브래킷이 흔들리거나 스핀들이 덜 눌린 것이니 다시 겁니다.',
              style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSub),
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
              '그림의 번호(①②③④)는 아래 입력칸 이름의 번호와 같습니다. 거리는 모두 mm로 잽니다.',
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
            '$_rpm rpm 기준 참고값입니다(경험값). 제조사·사내 기준이 있으면 아래에 그 값을 넣으십시오.',
            style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSub),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('align_tol_offset'),
                  onChanged: (v) => setState(() => _tolOffsetText = v),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: '평행 (mm)', hintText: tol.offset.toStringAsFixed(2), isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('align_tol_angle'),
                  onChanged: (v) => setState(() => _tolAngleText = v),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: '각도 (mm/100mm)', hintText: tol.angle100.toStringAsFixed(2), isDense: true),
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
  const _SaveSheet({
    required this.result,
    required this.method,
    required this.rpm,
    required this.inputs,
    required this.verdict,
    required this.now,
    required this.machineDefault,
    required this.equipment,
  });

  @override
  State<_SaveSheet> createState() => _SaveSheetState();
}

class _SaveSheetState extends State<_SaveSheet> {
  late final _machine = TextEditingController(text: widget.machineDefault);
  final _note = TextEditingController();
  AlignStage _stage = AlignStage.before;
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
