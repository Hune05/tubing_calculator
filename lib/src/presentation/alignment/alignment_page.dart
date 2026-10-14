// 축 정렬 계산기: 모터·펌프 커플링 센터링. 다이얼 게이지 읽음값으로 앞발·뒷발에 넣고 뺄 심 두께와 좌우 이동량을 구한다.
//
// 10-15 개편: 한 페이지에 다 있던 것을 단계 넷으로 나눴다(위 단계 표시 + 옆으로 넘김 + 아래 이전·다음).
//   ① 준비(alignment_page_setup.dart): 방식·측정 그림·거리·회전수·판정 기준·처짐/열팽창
//   ② 측정(alignment_page_measure.dart): 시계 그림(바늘이 넣은 값대로)·읽음값·검산·다이얼 보는 법
//   ③ 결과(alignment_page_result.dart): 판정·발 이동량(+심 판 조합)·옆/위 그림
//   ④ 심 기록(alignment_page_shim.dart): 기계별 네 발 밑 심(시작·이번 작업·지금)·회차·저장·이 기계 심 이력
// 그림은 값에 연동된다: 지금 넣는 거리 칸은 측정 그림에서 진하게, 넣은 값이 치수선에 붙는다.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/app_components.dart'
    show showAppSnack;
import '../../core/common_widgets/swipe_to_delete.dart';
import '../../core/theme/app_icon_set.dart';
import '../../core/theme/app_tokens.dart';
import '../equipment/equipment_model.dart';
import '../equipment/equipment_store.dart';
import '../tube_cutting/cutting_action_bar.dart' show kakaoSender, textSharer;
import 'alignment_guide_page.dart';
import 'alignment_guide_painter.dart';
import 'alignment_math.dart';
import 'alignment_dial_painter.dart';
import 'alignment_render.dart';
import 'alignment_record.dart';
import 'alignment_session.dart';
import 'alignment_shim.dart';
import '../trash/trash_kinds.dart';
import '../common/number_text.dart';

part 'alignment_page_setup.dart';
part 'alignment_page_measure.dart';
part 'alignment_page_result.dart';
part 'alignment_page_shim.dart';
part 'alignment_page_sheets.dart';

Future<void> _defaultShare(String text) async {
  if (await kakaoSender(text)) return;
  await textSharer(text);
}

/// 단계 이름(위 단계 표시·아래 단추).
const List<String> kAlignSteps = ['준비', '측정', '결과', '심 기록'];

class AlignmentPage extends StatefulWidget {
  final Future<void> Function(String text) share;
  final DateTime Function()? now;
  final int initialStep;
  const AlignmentPage({
    super.key,
    this.share = _defaultShare,
    this.now,
    this.initialStep = 0,
  });

  @override
  State<AlignmentPage> createState() => _AlignmentPageState();
}

class _AlignmentPageState extends State<AlignmentPage>
    with SingleTickerProviderStateMixin {
  AlignMethod _method = AlignMethod.reverse;
  final Map<String, TextEditingController> _c = {};
  bool _showSag = false;
  bool _showTarget = false;
  // 방식 설명은 접어 두고 한 줄만(10-15: 길어서 그림이 거리 칸과 멀어졌다).
  bool _showMethodHelp = false;
  late final TabController _tab = TabController(
    length: kAlignSteps.length,
    vsync: this,
    initialIndex: widget.initialStep.clamp(0, kAlignSteps.length - 1),
  )..addListener(() {
      if (mounted) setState(() {});
    });

  /// 지금 넣고 있는 칸(그림 연동용).
  String? _focus;

  /// 측정 그림에 보이는 다이얼(a·b 또는 r·f). 칸을 누르면 그 다이얼로 바뀐다.
  String _clockDial = 'a';

  // 허용 기준(현장 기준). 처음에는 0.05 mm로 두고, 고치면 폰에 남아 다음에도 그 값으로 판정한다.
  static const String _tolKey = 'align_tolerance_v1';
  static const AlignTolerance _tolStart = AlignTolerance(0.05, 0.05);
  final TextEditingController _tolO = TextEditingController(text: _fmtTol(_tolStart.offset));
  final TextEditingController _tolA = TextEditingController(text: _fmtTol(_tolStart.angle100));

  static String _fmtTol(double v) => v.toStringAsFixed(v * 100 == (v * 100).roundToDouble() ? 2 : 3);
  List<AlignRound> _rounds = []; // 이번 정렬 작업의 회차(폰에 남아 있다)

  // ── 심 기록(10-15) ──
  final TextEditingController _machine = TextEditingController();
  final Map<AlignFoot, TextEditingController> _start = {
    for (final f in AlignFoot.values) f: TextEditingController(),
  };
  List<double> _sizes = List.of(kAlignShimSizesDefault);
  final TextEditingController _sizeAdd = TextEditingController();
  List<AlignRecord> _records = [];

  DateTime get _now => (widget.now ?? DateTime.now)();

  TextEditingController _f(String key) =>
      _c.putIfAbsent(key, () => TextEditingController()..addListener(_saveDraftSoon));

  // ── 적던 다이얼 값 임시 저장(10-08: 뒤로 가기·앱 꺼짐에 읽은 값이 모두 사라졌다) ──
  static const String _draftKey = 'align_draft_v1';
  Timer? _draftTimer;
  bool _draftLoaded = false;

  void _saveDraftSoon() {
    if (!_draftLoaded) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), () => _writeDraft(jsonEncode(_inputs())));
  }

  static Future<void> _writeDraft(String text) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_draftKey, text);
    } catch (_) {}
  }

  Future<void> _loadDraft() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_draftKey);
      if (raw != null && mounted) {
        final m = jsonDecode(raw) as Map;
        setState(() {
          m.forEach((k, v) {
            if (k == 'method') {
              for (final x in AlignMethod.values) {
                if (x.name == v) _method = x;
              }
            } else {
              _f('$k').text = '$v';
            }
          });
          _clockDial = _method == AlignMethod.reverse ? 'a' : 'r';
          // 처짐·열팽창에 값이 들어 있으면 펼쳐 둔다(10-15: 접혀 있어 모르고 계산에 들어갔다).
          _showSag = _hasAny(['sagA', 'sagB', 'sagR']);
          _showTarget = _hasAny(['targetY', 'targetZ']);
        });
      }
    } catch (_) {}
    _draftLoaded = true;
  }

  bool _hasAny(List<String> keys) =>
      keys.any((k) => (_c[k]?.text.trim() ?? '').isNotEmpty);

  Future<void> _loadShim() async {
    final s = await AlignShimStore.load();
    final sizes = await AlignShimStore.sizes();
    final recs = await AlignStore.load();
    final last = await AlignStore.lastMachine();
    if (!mounted) return;
    setState(() {
      _sizes = sizes;
      _records = recs;
      _machine.text = s.machine.isNotEmpty ? s.machine : last;
      Map<AlignFoot, double> start = s.start;
      // 작업 중 심이 없으면 같은 기계의 지난 끝 심으로 시작한다.
      if (start.isEmpty) start = lastFeetFor(recs, _machine.text) ?? const {};
      for (final f in AlignFoot.values) {
        final v = start[f];
        _start[f]!.text = v == null || v.abs() < 0.005 ? '' : footMm(v);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadTol();
    _loadDraft();
    _loadShim();
    AlignSessionStore.load().then((v) {
      if (mounted && v.isNotEmpty) setState(() => _rounds = v);
    });
  }

  @override
  void dispose() {
    if (_draftTimer?.isActive ?? false) _writeDraft(jsonEncode(_inputs()));
    _draftTimer?.cancel();
    for (final c in _c.values) {
      c.dispose();
    }
    _tolO.dispose();
    _tolA.dispose();
    _machine.dispose();
    _sizeAdd.dispose();
    for (final c in _start.values) {
      c.dispose();
    }
    _tab.dispose();
    super.dispose();
  }

  /// 숫자로 읽는다(쉼표 소수점·천 단위 쉼표 모두 공용 규칙으로). 비었거나 숫자가 아니면 null.
  /// 8차(10-09): 쉼표를 늘 소수점으로 바꿔 "3,600"이 3.6으로 읽혔다.
  double? _n(String key) => parseNumberText(_f(key).text);

  double _opt(String key) => _n(key) ?? 0;

  // "3,600"을 못 읽어 1800 rpm 허용치로 판정했다(8차).
  int get _rpm => parseNumberText(_f('rpm').text)?.round() ?? 1800;

  AlignTolerance get _tol {
    final o = parseNumberText(_tolO.text);
    final g = parseNumberText(_tolA.text);
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

  /// 방식별 거리 칸(그림 번호 순서).
  List<String> get _distKeys => _method == AlignMethod.reverse
      ? const ['between', 'coupB', 'front', 'rear']
      : const ['coupR', 'front', 'rear', 'faceR'];

  /// 방식별 다이얼 둘(칸 앞글자).
  List<String> get _dials => _method == AlignMethod.reverse ? const ['a', 'b'] : const ['r', 'f'];

  bool get _distancesDone => _distKeys.every((k) => _n(k) != null);

  bool get _readingsDone => [
    for (final p in _dials)
      for (final a in ['90', '180', '270']) '$p$a',
  ].every((k) => _n(k) != null);

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
    showAppSnack(context, m);
  }

  void _go(int step) => _tab.animateTo(step.clamp(0, kAlignSteps.length - 1));

  Future<void> _openGuide([String? id]) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => AlignmentGuidePage(openId: id, share: widget.share)),
    );
  }

  Future<void> _openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => AlignmentHistoryPage(share: widget.share)),
    );
    final recs = await AlignStore.load();
    if (mounted) setState(() => _records = recs);
  }

  // ── 화면 ──

  @override
  Widget build(BuildContext context) {
    final solved = _solve();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('축 정렬 계산'),
        actions: [
          IconButton(
            key: const Key('align_guide'),
            tooltip: '현장 지침',
            icon: const Icon(AppIcons.help),
            onPressed: () => _openGuide(),
          ),
          IconButton(
            key: const Key('align_history'),
            tooltip: '지난 기록',
            icon: const Icon(AppIcons.history),
            onPressed: _openHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          _stepHeader(solved),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _page(_setupTab(), pinned: _setupPinned()),
                _page(_measureTab(solved), pinned: _measurePinned()),
                _page(_resultTab(solved)),
                _page(_shimTab(solved.result)),
              ],
            ),
          ),
          // 자판이 떠 있으면 이전·다음을 숨겨 칸과 그림 자리를 넓힌다(10-15 폰 확인).
          if (MediaQuery.viewInsetsOf(context).bottom == 0) _bottomBar(solved),
        ],
      ),
    );
  }

  /// 단계 한 쪽. [pinned]가 있으면 목록 위에 붙여 둔다(칸에 들어가 자판이 떠도 그림이 보이게).
  Widget _page(List<Widget> children, {Widget? pinned}) => Column(
    children: [
      if (pinned != null)
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: pinned,
        ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: children,
        ),
      ),
    ],
  );

  /// 위 단계 표시: 끝난 단계는 ✓, 결과는 판정 색, 지금 단계는 청록.
  Widget _stepHeader(({AlignResult? result, String? error}) solved) {
    final r = solved.result;
    final verdict = r == null ? null : judge(r, _tol);
    final done = [
      _distancesDone,
      _readingsDone,
      r != null,
      _rounds.isNotEmpty,
    ];
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Row(
        children: [
          for (var i = 0; i < kAlignSteps.length; i++)
            Expanded(
              child: InkWell(
                key: Key('align_step_$i'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => _go(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      Builder(
                        builder: (_) {
                          final on = _tab.index == i;
                          final Color c = i == 2 && verdict != null
                              ? (verdict == AlignVerdict.ok ? AppColors.ok : AppColors.danger)
                              : (on ? AppColors.brand : (done[i] ? AppColors.ok : AppColors.textFaint));
                          return Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: on ? c : c.withValues(alpha: 0.12),
                              border: Border.all(color: c, width: 1.5),
                            ),
                            child: done[i] && !on
                                ? Icon(Icons.check_rounded, size: 16, color: c)
                                : Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: on ? Colors.white : c,
                                    ),
                                  ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        kAlignSteps[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: _tab.index == i ? FontWeight.w900 : FontWeight.w600,
                          color: _tab.index == i ? AppColors.text : AppColors.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 아래 이전·다음. 마지막 단계에서는 "기록 남기기".
  Widget _bottomBar(({AlignResult? result, String? error}) solved) {
    final i = _tab.index;
    final last = i == kAlignSteps.length - 1;
    final r = solved.result;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            OutlinedButton(
              key: const Key('align_prev'),
              onPressed: i == 0 ? null : () => _go(i - 1),
              child: const Text('이전'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: last
                  ? FilledButton.icon(
                      key: const Key('align_save'),
                      onPressed: r == null ? null : () => _save(r),
                      icon: const Icon(AppIcons.save, size: 18),
                      label: Text(r == null ? '결과가 나와야 저장합니다' : '기록 남기기'),
                    )
                  : FilledButton(
                      key: const Key('align_next'),
                      onPressed: () => _go(i + 1),
                      child: Text('다음: ${kAlignSteps[i + 1]}'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 공용 칸 ──

  Widget _card(String title, List<Widget> children, {Key? key}) => Card(
    key: key,
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
    bool applied = false,
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
                // 값이 들어 있으면 접혀 있어도 계산에 들어간다는 표시(10-15).
                if (applied)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.caution.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '계산에 들어감',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.caution),
                    ),
                  ),
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

  /// 숫자 칸. 들어가면 [_focus]가 바뀌어 그림이 그 칸을 강조한다.
  Widget _field(String key, String label, {String? hint, String? suffix}) => Focus(
    onFocusChange: (on) => setState(() {
      if (on) {
        _focus = key;
        final m = RegExp(r'^([abrf])(90|180|270)$').firstMatch(key);
        if (m != null) _clockDial = m.group(1)!;
      } else if (_focus == key) {
        _focus = null;
      }
    }),
    child: TextField(
      key: Key('align_$key'),
      controller: _f(key),
      onChanged: (_) => setState(() {}),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-+0-9.,]'))],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        isDense: true,
        filled: true,
        fillColor: _focus == key ? AppColors.brandSoft : AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    ),
  );

  Widget _notice(String text, Color color, {required String key, String? guideId}) => Container(
    key: Key(key),
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        if (guideId != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(key: Key('${key}_guide'), onPressed: () => _openGuide(guideId), child: const Text('현장 지침에서 조치 보기')),
          ),
      ],
    ),
  );
}
