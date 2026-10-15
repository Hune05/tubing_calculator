// 축 정렬 계산기: 모터·펌프 커플링 센터링. 다이얼 게이지 읽음값으로 앞발·뒷발에 넣고 뺄 심 두께와 좌우 이동량을 구한다.
//
// 10-15 화면: 부스바·철판 가공과 같은 틀(위 그림 + 아래 작업판 + 맨 아래 탭). 단계 표시·이전/다음은 없다
// (사용자: "계산기를 가이드처럼 만드나" — 처음 판은 단계 넘김이라 안내 화면처럼 보였다).
//   거리(alignment_page_setup.dart): 방식·거리·회전수·판정 기준·처짐/열팽창 — 위 그림은 측정 그림(넣는 거리 진하게)
//   지시값(alignment_page_measure.dart): 다이얼별 3·6·9시와 바로 검산 — 위 그림은 시계(바늘이 넣은 값대로)
//   결과(alignment_page_result.dart): 판정·발 이동량(+심 판 조합)·회차 — 위 그림은 옆/위에서 본 모양
//   심 기록(alignment_page_shim.dart): 기계별 네 발 밑 심(시작·이번 작업·지금)·회차·이력 — 위 그림은 네 발
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/common_widgets/app_components.dart' show showAppSnack;
import '../../core/common_widgets/swipe_to_delete.dart';
import '../../core/theme/app_icon_set.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/field_view.dart';
import '../calculator/widgets/swipe_delete.dart' show calcNavCompact;
import '../common/app_icons.dart';
import '../equipment/equipment_model.dart';
import '../equipment/equipment_store.dart';
import '../steel_plate/plate_ui.dart';
import '../tube_cutting/cutting_action_bar.dart' show kakaoSender, textSharer;
import 'alignment_guide_page.dart';
import 'alignment_guide_painter.dart';
import 'alignment_math.dart';
import 'alignment_pdf.dart';
import 'alignment_plan.dart';
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

/// 아래 탭 이름.
const List<String> kAlignSteps = ['거리', '지시값', '결과', '심 기록'];

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

class _AlignmentPageState extends State<AlignmentPage> {
  AlignMethod _method = AlignMethod.reverse;
  final Map<String, TextEditingController> _c = {};
  late int _tab = widget.initialStep.clamp(0, kAlignSteps.length - 1);

  /// 지금 넣고 있는 칸(그림 연동용).
  String? _focus;
  final Map<String, FocusNode> _nodes = {};

  /// 시계 그림에 보이는 다이얼(a·b 또는 r·f). 칸을 누르면 그 다이얼로 바뀐다.
  String _clockDial = 'a';

  /// 결과 그림: side 옆에서, top 위에서.
  String _resultView = 'side';

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

  /// 움직이지 않을 두 발(고른 순서대로, 셋째를 고르면 먼저 고른 것이 빠진다).
  List<AlignFootPos> _fixed = List.of(kAlignFixedDefault);
  AlignPlan? _plan; // 고정 발을 바꿨을 때의 네 발 값(빌드 때 채움)
  String? _planError;
  String? _startFrom; // 시작 심을 가져온 기계 이름
  Map<AlignFoot, double> _startLoaded = const {};

  DateTime get _now => (widget.now ?? DateTime.now)();

  TextEditingController _f(String key) =>
      _c.putIfAbsent(key, () => TextEditingController()..addListener(_saveDraftSoon));

  /// 칸마다 포커스. 들어가면 [_focus]가 바뀌어 위 그림이 그 칸을 강조한다.
  FocusNode _fn(String key) => _nodes.putIfAbsent(key, () {
    final n = FocusNode();
    n.addListener(() {
      if (!mounted) return;
      setState(() {
        if (n.hasFocus) {
          _focus = key;
          final m = RegExp(r'^([abrf])(90|180|270)$').firstMatch(key);
          if (m != null) _clockDial = m.group(1)!;
        } else if (_focus == key) {
          _focus = null;
        }
      });
    });
    return n;
  });

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
            } else if (k == 'fixed') {
              final f = [
                for (final n in '$v'.split(','))
                  for (final x in AlignFootPos.values)
                    if (x.name == n) x,
              ];
              if (f.length == 2) _fixed = f;
            } else {
              _f('$k').text = '$v';
            }
          });
          _clockDial = _method == AlignMethod.reverse ? 'a' : 'r';
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
      // 지난 기계 이름은 그 기계 기록이 남아 있을 때만(10-15: 지운 시험 기록 이름이 다시 채워졌다).
      _machine.text = s.machine.isNotEmpty ? s.machine : (shimHistory(recs, last).isNotEmpty ? last : '');
      Map<AlignFoot, double> start = s.start;
      // 작업 중 심이 없으면 같은 기계의 지난 끝 심으로 시작한다.
      if (start.isEmpty) start = lastFeetFor(recs, _machine.text) ?? const {};
      _setStart(start, _machine.text);
    });
  }

  /// 시작 심 칸을 [m]으로 채우고, 어느 기계 값인지 기억한다(이름을 바꾸면 그 기계 값으로 갈아 끼우려고).
  void _setStart(Map<AlignFoot, double> m, String machine) {
    for (final f in AlignFoot.values) {
      final v = m[f] ?? 0;
      _start[f]!.text = v.abs() < 0.005 ? '' : footMm(v);
    }
    _startFrom = machine.trim();
    _startLoaded = {for (final f in AlignFoot.values) f: m[f] ?? 0};
  }

  /// 시작 심을 넣은 뒤 손으로 고치지 않았는지.
  bool get _startUntouched => AlignFoot.values.every(
    (f) => ((parseNumberText(_start[f]!.text) ?? 0) - (_startLoaded[f] ?? 0)).abs() < 0.005,
  );

  /// 기계 이름이 바뀌면(10-15 폰 확인: A 기계 저장 뒤 B 이름을 넣어도 A의 심이 시작 심으로 남았다)
  /// 시작 심을 손대지 않았고 작업 회차가 없을 때만 그 기계의 지난 끝 심으로(없으면 비움) 바꾼다.
  void _machineChanged() {
    final name = _machine.text.trim();
    if (_rounds.isNotEmpty || !_startUntouched) return;
    if (_startFrom != null && sameMachine(_startFrom!, name)) return;
    _setStart(lastFeetFor(_records, name) ?? const {}, name);
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
    for (final n in _nodes.values) {
      n.dispose();
    }
    _tolO.dispose();
    _tolA.dispose();
    _machine.dispose();
    _sizeAdd.dispose();
    for (final c in _start.values) {
      c.dispose();
    }
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

  List<String> get _readingKeys => [
    for (final p in _dials)
      for (final a in ['90', '180', '270']) '$p$a',
  ];

  int get _distCount => _distKeys.where((k) => _n(k) != null).length;
  int get _readingCount => _readingKeys.where((k) => _n(k) != null).length;
  bool get _distancesDone => _distCount == _distKeys.length;
  /// 다이얼마다 세 자리 중 둘 이상 넣었으면 다 된 것(3점 측정).
  bool get _readingsDone => _dials.every((p) => fillReadings(_n('${p}90'), _n('${p}180'), _n('${p}270')) != null);

  /// 값이 다 들어오면 계산한다. 덜 들어왔으면 null, 잘못된 값이면 오류 글.
  ({AlignResult? result, String? error}) _solve() {
    // 한 자리가 비면 3시 + 9시 = 6시로 채운다(3점 측정, 10-15).
    List<double>? three(String p) {
      final v = fillReadings(_n('${p}90'), _n('${p}180'), _n('${p}270'));
      return v == null ? null : [v.r90, v.r180, v.r270];
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
    if (!_fixedDefault) 'fixed': _fixed.map((e) => e.name).join(','),
  };

  // ── 고정 발(10-15) ──
  bool get _fixedDefault => _fixed.toSet().containsAll(kAlignFixedDefault);

  double get _frontX {
    if (_method == AlignMethod.reverse) {
      return (_n('between') ?? 0) - (_n('coupB') ?? 0) + (_n('front') ?? 0);
    }
    return (_n('coupR') ?? 0) + (_n('front') ?? 0);
  }

  /// 계산 결과에 고른 고정 발을 적용한다. 펌프 두 발 고정(처음)이면 그대로.
  /// 바꾼 경우 모터 발 값이 고정 발 계획 값으로 바뀌고, 펌프 발 값은 [_plan]에 있다.
  ({AlignResult? result, String? error}) _solveApplied() {
    final s = _solve();
    _plan = null;
    _planError = null;
    final r = s.result;
    if (r == null || _fixedDefault) return s;
    try {
      final p = alignPlan(
        r: r,
        fixed: _fixed.toSet(),
        xFront: _frontX,
        xRear: _rearX,
        pumpInner: _n('pumpIn'),
        pumpOuter: _n('pumpOut'),
        targetY: _opt('targetY'),
        targetZ: _opt('targetZ'),
      );
      _plan = p;
      final mf = p.feet[AlignFootPos.motorFront]!, mr = p.feet[AlignFootPos.motorRear]!;
      return (
        result: AlignResult(
          vertical: r.vertical,
          horizontal: r.horizontal,
          shimFront: mf.shim,
          shimRear: mr.shim,
          moveFront: mf.move,
          moveRear: mr.move,
          offset: r.offset,
          angle100: r.angle100,
          closure: r.closure,
        ),
        error: null,
      );
    } on AlignInputError catch (e) {
      _planError = e.message;
      return s;
    }
  }

  /// 펌프도 움직일 때 펌프 발 할 일 한 줄(회차 메모·기록 글).
  String _pumpNote() {
    final p = _plan;
    if (p == null || !p.pumpMoves) return '';
    return [
      for (final f in [AlignFootPos.pumpInner, AlignFootPos.pumpOuter])
        if (p.feet[f] case final v?) '${f.label} 심 ${shimText(v.shim)} · 옆 ${moveText(v.move)}',
    ].join(', ');
  }

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

  void _go(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _tab = step.clamp(0, kAlignSteps.length - 1));
  }

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

  /// 제목 아래 한 줄: 결과가 나오면 판정, 아니면 넣은 칸 수.
  (String, Color) _summary(({AlignResult? result, String? error}) solved) {
    final r = solved.result;
    if (solved.error != null) return ('값을 확인하십시오', fc.danger);
    if (r == null) {
      final name = _method == AlignMethod.reverse ? '리버스 다이얼' : '림·페이스';
      return ('$name · 거리 $_distCount/${_distKeys.length} · 지시값 $_readingCount/${_readingKeys.length}', fc.textSub);
    }
    final ok = judge(r, _tol) == AlignVerdict.ok;
    return (
      '${ok ? '합격' : '불합격'} · 평행 ${r.offset.toStringAsFixed(3)} · 각도 ${r.angle100.toStringAsFixed(3)}',
      ok ? fc.ok : fc.danger,
    );
  }

  @override
  Widget build(BuildContext context) {
    final solved = _solveApplied();
    final (sum, sumColor) = _summary(solved);
    return FieldViewTheme(
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: fc.background,
          appBar: AppBar(
            backgroundColor: fc.surface,
            foregroundColor: fc.text,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('축 정렬 계산', style: TextStyle(fontWeight: FontWeight.w800, color: fc.text)),
                Text(
                  sum,
                  key: const Key('align_head'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: sumColor),
                ),
              ],
            ),
            actions: [
              PlateBarAction(
                key: const Key('align_guide'),
                icon: AppIcons.help,
                label: '현장 지침',
                onTap: () => _openGuide(),
              ),
              PlateBarAction(
                key: const Key('align_history'),
                icon: AppIcons.history,
                label: '지난 기록',
                onTap: _openHistory,
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            behavior: HitTestBehavior.translucent,
            child: PlateWorkspace(
              canvasShare: _tab == 3 ? 0.36 : 0.42,
              canvas: KeyedSubtree(key: ValueKey('align_canvas_$_tab'), child: _canvas(solved)),
              tools: _canvasTools(solved),
              hint: _canvasHint(solved),
              panel: IndexedStack(
                index: _tab,
                children: [
                  _setupPanel(),
                  _measurePanel(solved),
                  _resultPanel(solved),
                  _shimPanel(solved.result),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _navBar(solved),
        ),
      ),
    );
  }

  // ── 위 그림 ──

  Widget _canvas(({AlignResult? result, String? error}) solved) => switch (_tab) {
    0 => _setupCanvas(),
    1 => _measureCanvas(),
    2 => _resultCanvas(solved.result),
    _ => _shimCanvas(),
  };

  List<Widget> _canvasTools(({AlignResult? result, String? error}) solved) => switch (_tab) {
    1 => [_dialSwitch()],
    2 when solved.result != null && _planError == null => [
      PlateViewSwitch([
        PlateOption('align_vm_side', '옆에서', _resultView == 'side', () => setState(() => _resultView = 'side')),
        PlateOption('align_vm_top', '위에서', _resultView == 'top', () => setState(() => _resultView = 'top')),
      ]),
    ],
    _ => const [],
  };

  String? _canvasHint(({AlignResult? result, String? error}) solved) => switch (_tab) {
    0 => _focus != null && _distKeys.contains(_focus) ? null : '거리 칸을 누르면 그 치수만 크게 보입니다',
    1 => '펌프 쪽에 서서 모터를 볼 때 · 3시가 오른쪽',
    2 => solved.result == null ? null : (_plan?.pumpMoves ?? false ? '그림은 모터 발만 · 펌프 발 값은 아래 표' : '심 두께·어긋남은 크게 부풀려 그렸습니다'),
    _ => '위에서 본 네 발 · 지금 발 밑에 있는 심',
  };

  /// 그림이 없을 때 가운데 글.
  Widget _canvasEmpty(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        key: const Key('align_canvas_empty'),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: fc.textSub, height: 1.45),
      ),
    ),
  );

  // ── 아래 탭 ──

  Widget? _navBar(({AlignResult? result, String? error}) solved) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return null;
    final compact = calcNavCompact(context);
    final r = solved.result;
    final ok = r != null && judge(r, _tol) == AlignVerdict.ok;
    BottomNavigationBarItem item(int i) {
      final on = i == _tab;
      final Widget icon = switch (i) {
        0 => AppIcon(AppGlyph.navInput, size: 24, filled: on),
        1 => const Icon(LucideIcons.gauge, size: 22),
        2 => AppIcon(AppGlyph.navMarking, size: 24, filled: on),
        _ => const Icon(LucideIcons.layers, size: 22),
      };
      // 다 넣은 탭은 작은 점(결과는 판정 색).
      final Color? dot = switch (i) {
        0 => _distancesDone ? fc.ok : null,
        1 => _readingsDone ? fc.ok : null,
        2 => r == null ? null : (ok ? fc.ok : fc.danger),
        _ => _rounds.isNotEmpty ? fc.brand : null,
      };
      return BottomNavigationBarItem(
        icon: Padding(
          padding: EdgeInsets.only(bottom: compact ? 0 : 4),
          child: KeyedSubtree(
            key: Key('align_step_$i'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                icon,
                if (dot != null)
                  Positioned(
                    right: -4,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        ),
        label: kAlignSteps[i],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: fc.surface,
        border: Border(top: BorderSide(color: fc.line)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: compact ? 0 : 4),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            currentIndex: _tab,
            selectedItemColor: fc.brand,
            unselectedItemColor: fc.textSub,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
            onTap: (i) {
              HapticFeedback.selectionClick();
              _go(i);
            },
            items: [for (var i = 0; i < kAlignSteps.length; i++) item(i)],
          ),
        ),
      ),
    );
  }

  // ── 공용 칸 ──

  /// 숫자 칸(공용 PlateNumField: 누르면 값 전체 고르기). 들어가면 위 그림이 그 칸을 강조한다.
  Widget _field(String key, String? label, {String? hint, String? unit = 'mm', bool signed = true}) => PlateNumField(
    fieldKey: 'align_$key',
    label: label,
    controller: _f(key),
    focus: _fn(key),
    unit: unit,
    hint: hint,
    signed: signed,
    onChanged: (_) => setState(() {}),
  );

  /// 알림 상자(오류·주의). [guideId]면 현장 지침으로 가는 단추.
  Widget _notice(String text, Color color, {required String key, String? guideId}) => Container(
    key: Key(key),
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color, height: 1.4)),
        if (guideId != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(key: Key('${key}_guide'), onPressed: () => _openGuide(guideId), child: const Text('현장 지침에서 조치 보기')),
          ),
      ],
    ),
  );

  /// 작은 설명 글.
  Widget _note(String text) => Text(text, style: TextStyle(fontSize: 12.5, height: 1.5, color: fc.textSub));
}
