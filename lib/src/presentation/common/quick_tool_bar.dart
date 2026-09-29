// 빠른 도구 막대 — 갤럭시 엣지 패널처럼 화면 옆에서 밀어 여는 아이콘 막대.
// 전선관·튜브 마킹 계산 중에 계산기·단위 환산 같은 도구를 쓰려고 앱을 나가거나 메뉴까지 돌아가지
// 않게, 작업 화면 위에 도구 화면을 덮어 연다. 닫거나 뒤로 가면 하던 작업 화면 그대로(입력한 값·탭 유지).
//
// - 옆 가장자리의 얇은 손잡이를 탭하거나 안쪽으로 밀면 막대가 나온다(안드로이드 뒤로 가기 제스처와
//   겹치지 않게 화면 가운데 높이에 둔 손잡이에서만 반응한다).
// - 막대에 넣을 도구·어느 쪽에 둘지는 막대 아래 "편집"에서 고르고 폰에 저장한다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/field_view.dart';
import '../electrical/electric_calculator_page.dart';
import '../field_tools/eng_calculator_page.dart';
import '../field_tools/level_page.dart';
import '../field_tools/protractor_page.dart';
import '../flow/flow_calc_page.dart';
import '../instrument/signal_calculator_page.dart';
import '../pressure_test/pressure_test_page.dart';
import '../reference/page/tube_reference_page.dart';
import '../unit_converter/unit_converter_page.dart';
import 'app_icons.dart';

/// 막대에 넣을 수 있는 도구 하나.
class QuickToolDef {
  final String id;
  final String label;
  final AppGlyph glyph;
  final WidgetBuilder builder;
  const QuickToolDef(this.id, this.label, this.glyph, this.builder);
}

/// 고를 수 있는 도구 전부(막대에는 이 순서대로 나온다). 메뉴의 같은 이름 항목과 같은 화면을 연다.
final List<QuickToolDef> kQuickTools = [
  QuickToolDef(
    'eng',
    '공학용 계산기',
    AppGlyph.engCalc,
    (_) => const EngCalculatorPage(),
  ),
  QuickToolDef(
    'unit',
    '단위 환산',
    AppGlyph.unitConvert,
    (_) => const UnitConverterPage(),
  ),
  QuickToolDef(
    'protractor',
    '각도기',
    AppGlyph.protractor,
    (_) => const ProtractorPage(),
  ),
  QuickToolDef('level', '수평계', AppGlyph.level, (_) => const LevelPage()),
  QuickToolDef(
    'ref',
    '현장 자료',
    AppGlyph.tubeSpec,
    (_) => const TubeReferencePage(),
  ),
  QuickToolDef(
    'pressure',
    '압력 시험',
    AppGlyph.pressureGauge,
    (_) => const PressureTestPage(),
  ),
  QuickToolDef('flow', '유량 계산', AppGlyph.flow, (_) => const FlowCalcPage()),
  QuickToolDef(
    'electric',
    '전기 설계',
    AppGlyph.electric,
    (_) => const ElectricCalculatorPage(),
  ),
  QuickToolDef(
    'signal',
    '계기 교정',
    AppGlyph.currentLoop,
    (_) => const SignalCalculatorPage(),
  ),
];

/// 처음 켰을 때 막대에 들어 있는 도구(마킹하다가 자주 쓰는 것).
const List<String> kQuickToolDefaultIds = [
  'eng',
  'unit',
  'protractor',
  'level',
  'ref',
];

const String kQuickToolIdsKey = 'quick_tool_bar_ids_v1';
const String kQuickToolSideKey = 'quick_tool_bar_side_v1';

/// [ids]에 든 도구를 [all]의 순서대로 돌려준다(모르는 id는 버린다). [ids]가 null이면 기본.
List<QuickToolDef> resolveQuickTools(
  List<String>? ids,
  List<QuickToolDef> all,
) {
  final want = (ids ?? kQuickToolDefaultIds).toSet();
  return [
    for (final t in all)
      if (want.contains(t.id)) t,
  ];
}

/// [child] 위에 옆 가장자리 손잡이와 도구 막대를 얹는다. [enabled]가 false면 손잡이도 막대도
/// 없다(가로 전체 화면처럼 쓰지 않을 때). [child]는 늘 같은 자리에 있어 켜고 꺼도 상태가 안 날아간다.
class QuickToolBarHost extends StatefulWidget {
  final Widget child;
  final bool enabled;

  /// 시험용: 실제 화면 대신 쓸 도구 목록.
  final List<QuickToolDef>? tools;

  const QuickToolBarHost({
    super.key,
    required this.child,
    this.enabled = true,
    this.tools,
  });

  @override
  State<QuickToolBarHost> createState() => _QuickToolBarHostState();
}

class _QuickToolBarHostState extends State<QuickToolBarHost> {
  List<String>? _ids; // null = 기본
  bool _right = true;
  bool _mounted = false; // 막대가 화면 트리에 있는지(닫는 애니메이션이 끝날 때까지)
  bool _open = false; // 막대가 열린 쪽으로 가는 중/열림
  Timer? _closeTimer;
  double _dragSum = 0;

  List<QuickToolDef> get _all => widget.tools ?? kQuickTools;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final ids = p.getStringList(kQuickToolIdsKey);
      final side = p.getString(kQuickToolSideKey);
      if (!mounted) return;
      setState(() {
        _ids = ids;
        _right = side != 'left';
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (_ids != null) await p.setStringList(kQuickToolIdsKey, _ids!);
      await p.setString(kQuickToolSideKey, _right ? 'right' : 'left');
    } catch (_) {}
  }

  void _openBar() {
    if (_open) return;
    _closeTimer?.cancel();
    HapticFeedback.selectionClick();
    setState(() => _mounted = true);
    // 한 프레임 뒤에 열어야 옆에서 미끄러져 들어오는 모양이 나온다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _mounted) setState(() => _open = true);
    });
  }

  void _closeBar() {
    if (!_open && !_mounted) return;
    setState(() => _open = false);
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _mounted = false);
    });
  }

  void _launch(QuickToolDef t) {
    HapticFeedback.selectionClick();
    _closeBar();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: t.builder));
  }

  Future<void> _edit() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: fc.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final on = (_ids ?? kQuickToolDefaultIds).toSet();
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                key: const Key('quick_tool_edit_sheet'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '빠른 도구 막대',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: fc.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        key: const Key('quick_tool_side_right'),
                        label: const Text('오른쪽'),
                        selected: _right,
                        onSelected: (_) {
                          setState(() => _right = true);
                          setSheet(() {});
                          _save();
                        },
                      ),
                      ChoiceChip(
                        key: const Key('quick_tool_side_left'),
                        label: const Text('왼쪽'),
                        selected: !_right,
                        onSelected: (_) {
                          setState(() => _right = false);
                          setSheet(() {});
                          _save();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final t in _all)
                    SwitchListTile(
                      key: Key('quick_tool_pick_${t.id}'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      secondary: AppIcon(t.glyph, size: 24, color: fc.text),
                      title: Text(
                        t.label,
                        style: TextStyle(
                          color: fc.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      value: on.contains(t.id),
                      onChanged: (v) {
                        final next = {...on};
                        v ? next.add(t.id) : next.remove(t.id);
                        setState(
                          () => _ids = [
                            for (final d in _all)
                              if (next.contains(d.id)) d.id,
                          ],
                        );
                        setSheet(() {});
                        _save();
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _handle() => Align(
    alignment: _right ? Alignment.centerRight : Alignment.centerLeft,
    child: GestureDetector(
      key: const Key('quick_tool_handle'),
      behavior: HitTestBehavior.opaque,
      onTap: _openBar,
      onHorizontalDragStart: (_) => _dragSum = 0,
      onHorizontalDragUpdate: (d) {
        // 오른쪽 손잡이는 왼쪽으로(음수), 왼쪽 손잡이는 오른쪽으로(양수) 밀어야 열린다.
        _dragSum += _right ? -d.delta.dx : d.delta.dx;
        if (_dragSum > 14) {
          _dragSum = 0;
          _openBar();
        }
      },
      child: SizedBox(
        width: 26,
        height: 110,
        child: Align(
          alignment: _right ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 6,
            height: 54,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: fc.textSub.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _bar(List<QuickToolDef> tools, double maxHeight) {
    final radius = _right
        ? const BorderRadius.horizontal(left: Radius.circular(18))
        : const BorderRadius.horizontal(right: Radius.circular(18));
    return Align(
      alignment: _right ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedSlide(
        offset: _open ? Offset.zero : Offset(_right ? 1 : -1, 0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Material(
            key: const Key('quick_tool_panel'),
            elevation: 10,
            color: fc.surface,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: 72,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final t in tools)
                      InkWell(
                        key: Key('quick_tool_${t.id}'),
                        onTap: () => _launch(t),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppIcon(t.glyph, size: 26, color: fc.text),
                              const SizedBox(height: 3),
                              Text(
                                t.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: fc.textSub,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Divider(height: 8, color: fc.line),
                    IconButton(
                      key: const Key('quick_tool_edit'),
                      tooltip: '막대 편집',
                      icon: Icon(Icons.tune, size: 22, color: fc.textSub),
                      onPressed: _edit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tools = resolveQuickTools(_ids, _all);
    return Stack(
      children: [
        widget.child,
        if (widget.enabled) ...[
          if (_mounted)
            Positioned.fill(
              child: GestureDetector(
                key: const Key('quick_tool_scrim'),
                behavior: HitTestBehavior.opaque,
                onTap: _closeBar,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  color: _open ? Colors.black26 : Colors.transparent,
                ),
              ),
            ),
          if (!_mounted) Positioned.fill(child: _handle()),
          if (_mounted)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, c) => _bar(tools, c.maxHeight - 24),
              ),
            ),
        ],
      ],
    );
  }
}
