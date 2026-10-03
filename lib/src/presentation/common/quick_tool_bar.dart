// 빠른 도구 막대 — 갤럭시 엣지 패널처럼 화면 옆에서 밀어 여는 아이콘 막대.
// 전선관·튜브 마킹 계산 중에 계산기·단위 환산 같은 도구를 쓰려고 앱을 나가거나 메뉴까지 돌아가지
// 않게, 작업 화면 위에 도구 화면을 덮어 연다. 닫거나 뒤로 가면 하던 작업 화면 그대로(입력한 값·탭 유지).
//
// - 옆 가장자리의 얇은 손잡이를 탭하거나 안쪽으로 밀면 막대가 나온다(안드로이드 뒤로 가기 제스처와
//   겹치지 않게 화면 가운데 높이에 둔 손잡이에서만 반응한다).
// - 막대에 넣을 도구·어느 쪽에 둘지는 막대 아래 "편집"에서 고르고 폰에 저장한다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/field_view.dart';
import '../alignment/alignment_page.dart';
import '../bend_check/bend_check_page.dart';
import '../equipment/equipment_pages.dart';
import '../electrical/electric_calculator_page.dart';
import '../field_tools/eng_calculator_page.dart';
import '../field_tools/level_page.dart';
import '../field_tools/protractor_page.dart';
import '../flow/flow_calc_page.dart';
import '../instrument/signal_calculator_page.dart';
import '../pressure_test/pressure_test_page.dart';
import '../reference/page/tube_reference_page.dart';
import '../safety/safety_check_page.dart';
import '../unit_converter/unit_converter_page.dart';
import '../calculator/screens/mobile_calculator_page.dart';
import '../calculator/screens/mobile_remote_page.dart';
import '../conduit/screens/main_navigation_page.dart';
import '../my_work_logs/pages/layout_board_project_list_page.dart';
import '../reference/page/equipment_usage_page.dart';
import '../reference/search/knowledge_search_page.dart';
import '../steel_cutting/screens/mobile_steel_project_list_page.dart';
import '../tube_cutting/screens/mobile_cutting_project_list_page.dart';
import 'feature_search.dart';
import 'quick_sub_tools.dart';
import 'app_icons.dart';
import '../electrical/cable_tray_page.dart';
import '../electrical/busbar_bend_page.dart';
import '../electrical/busbar_ground_page.dart';
import '../electrical/circuit_reading_page.dart';
import '../electrical/panel_design_page.dart';
import '../electrical/troubleshoot_page.dart';
import '../electrical/cable_tray_route_page.dart';

/// 막대에 넣을 수 있는(그리고 전체 검색에 나오는) 기능 하나.
/// 큰 기능은 [glyph](직접 그린 아이콘), 세부 기능(탭·분류)은 [icon](Lucide 선 아이콘)을 쓴다.
class QuickToolDef {
  final String id;
  final String label;
  final AppGlyph? glyph;
  final WidgetBuilder builder;

  /// 전체 검색 창에 보이는 설명과 묶음 이름.
  final String subtitle;
  final String? group;
  final IconData? icon;
  const QuickToolDef(
    this.id,
    this.label,
    this.glyph,
    this.builder, {
    this.subtitle = '',
    this.group,
    this.icon,
  });

  /// 아이콘 위젯(직접 그린 것이 있으면 그것, 없으면 선 아이콘).
  Widget iconWidget({double size = 26, Color? color}) => glyph != null
      ? AppIcon(glyph!, size: size, color: color)
      : Icon(icon ?? LucideIcons.circle, size: size, color: color);
}

/// 고를 수 있는 기능 전부(막대에는 고른 것이 이 순서대로 나오고, "전체" 검색에는 다 나온다).
/// 메뉴의 같은 이름 항목과 같은 화면을 연다. 로그인·프로젝트 이름이 있어야 열리는 기능
/// (내 프로젝트·일정·근태·자재)은 작업 화면 위에 덮어 열기 어려워 뺐다.
final List<QuickToolDef> kQuickTools = [
  QuickToolDef(
    'eng',
    '공학용 계산기',
    AppGlyph.engCalc,
    (_) => const EngCalculatorPage(),
    subtitle: '사칙연산·삼각함수·거듭제곱 · 인치 분수·피트',
    group: '현장 도구',
  ),
  QuickToolDef(
    'unit',
    '단위 환산',
    AppGlyph.unitConvert,
    (_) => const UnitConverterPage(),
    subtitle: '길이·압력·온도·토크·분수 인치·배관 호칭',
    group: '현장 도구',
  ),
  QuickToolDef(
    'protractor',
    '각도기',
    AppGlyph.protractor,
    (_) => const ProtractorPage(),
    subtitle: '벤딩 각도 재기 · 화면 각도기',
    group: '현장 도구',
  ),
  QuickToolDef(
    'level',
    '수평계',
    AppGlyph.level,
    (_) => const LevelPage(),
    subtitle: '기포 수평계 · 배관 구배(%·mm/m) · 영점 맞추기',
    group: '현장 도구',
  ),
  QuickToolDef(
    'bendcheck',
    '벤딩 실측 기록',
    AppGlyph.tubeSpec,
    (_) => const BendCheckPage(),
    subtitle: '계산값과 실측값의 차이를 남겨 다음 마킹에 참고',
    group: '현장 도구',
  ),
  QuickToolDef(
    'equipledger',
    '장비 대장',
    AppGlyph.equipment,
    (_) => const EquipmentLedgerPage(),
    subtitle: '개인·작업 공구 점검 기한 · QR 찾기',
    group: '현장 도구',
  ),
  QuickToolDef(
    'align',
    '축 정렬',
    AppGlyph.alignment,
    (_) => const AlignmentPage(),
    subtitle: '모터·펌프 커플링 센터링 · 발 심 두께',
    group: '현장 도구',
  ),
  QuickToolDef(
    'safety',
    '안전 점검',
    AppGlyph.safety,
    (_) => const SafetyCheckPage(),
    subtitle: '작업 전 안전 점검표 · 기록 · 카톡 보내기',
    group: '현장 도구',
  ),
  QuickToolDef(
    'remote',
    '벤딩 리모컨',
    AppGlyph.remote,
    (_) => const MobileRemotePage(),
    subtitle: '수치 전송용 리모컨 (스마트폰 권장)',
    group: '현장 도구',
  ),
  QuickToolDef(
    'kbsearch',
    '자료 검색',
    AppGlyph.searchDocs,
    (_) => const KnowledgeSearchPage(),
    subtitle: '증상·코드·장비 이름으로 고장 조치·알람 코드·현장 자료 찾기',
    group: '참고 자료',
  ),
  QuickToolDef(
    'ref',
    '현장 자료',
    AppGlyph.tubeSpec,
    (_) => const TubeReferencePage(),
    subtitle: '튜브·전선관·형강 규격표, 발전 설비, 전기 기준(KEC)',
    group: '참고 자료',
  ),
  QuickToolDef(
    'equip',
    '장비 사용법',
    AppGlyph.benderHand,
    (_) => const EquipmentUsagePage(),
    subtitle: '벤더·절단기·계측기 쓰는 법, 주의·정비·고장·정리',
    group: '참고 자료',
  ),
  QuickToolDef(
    'bend',
    '벤딩 마킹 계산기',
    AppGlyph.tubeBend,
    (_) => const MobileCalculatorPage(),
    subtitle: '스마트폰용 · 단계별 치수 입력',
    group: '배관·튜브',
  ),
  QuickToolDef(
    'cut',
    '튜브 컷팅 계산기',
    AppGlyph.tubeCut,
    (_) => const MobileCuttingProjectListPage(),
    subtitle: '피팅 삽입깊이 차감 · 절단 자재 기록',
    group: '배관·튜브',
  ),
  QuickToolDef(
    'pressure',
    '압력시험',
    AppGlyph.pressureGauge,
    (_) => const PressureTestPage(),
    subtitle: '튜브·배관 수압·공압 시험압력 · 유지시간 기록 · 기록서',
    group: '배관·튜브',
  ),
  QuickToolDef(
    'flow',
    '유량 계산',
    AppGlyph.flow,
    (_) => const FlowCalcPage(),
    subtitle: '유속·관경 · 압력손실 · 차압 유량계 · 유량계 점검',
    group: '배관·튜브',
  ),
  QuickToolDef(
    'conduit',
    '전선관 벤딩 마킹 계산기',
    AppGlyph.conduitBend,
    (_) => const ConduitMainNavigation(),
    subtitle: '장비 프로필 설정 · 마킹 뷰어',
    group: '전기',
  ),
  QuickToolDef(
    'electric',
    '전기 설계 계산',
    AppGlyph.electric,
    (_) => const ElectricCalculatorPage(),
    subtitle: '부하 합산·전선 굵기·전압강하·단락 전류·발전기·축전지',
    group: '전기',
  ),
  QuickToolDef(
    'cabletray',
    '케이블 트레이 규격 선정',
    AppGlyph.cableTray,
    (_) => const CableTrayPage(),
    subtitle: '트레이 점유율 판정·권장 폭 (KEC 232.41)',
    group: '전기',
  ),
  QuickToolDef(
    'trayroute',
    '케이블 트레이 가공',
    AppGlyph.trayRoute,
    (_) => const CableTrayRoutePage(),
    subtitle: '넘어가기·옆으로 비켜가기·단 오르내리기·가지 내기(티)',
    group: '전기',
  ),
  QuickToolDef(
    'busbarbend',
    '부스바 절곡 계산기',
    AppGlyph.busbarBend,
    (_) => const BusbarBendPage(),
    subtitle: 'L·U·Z 절곡 절단 길이와 절곡 시작선',
    group: '전기',
  ),
  QuickToolDef(
    'groundbar',
    '접지바 구멍 계산기',
    AppGlyph.groundBar,
    (_) => const GroundBarPage(),
    subtitle: '구멍 위치·절단 길이·중량',
    group: '전기',
  ),
  QuickToolDef(
    'motor',
    '전동기·발전기 계산',
    AppGlyph.motor,
    (_) => const ElectricCalculatorPage(group: ElecGroup.motor),
    subtitle: '전동기 공식·선정·콘덴서·기타·보호·점검, 발전기 용량',
    group: '전동기·발전기',
  ),
  QuickToolDef(
    'circuit',
    '결선도·기동 회로',
    AppGlyph.ladder,
    (_) => const CircuitReadingPage(),
    subtitle: 'Y·Δ 결선, 직입·정역·Y-Δ 시퀀스',
    group: '전동기·발전기',
  ),
  QuickToolDef(
    'paneldesign',
    '분전반·조명 설계',
    AppGlyph.panelBoard,
    (_) => const PanelDesignPage(),
    subtitle: '조명 광속법 · 분전반 상 평형 · 여러 부하 간선 전압강하',
    group: '전기',
  ),
  QuickToolDef(
    'troubleshoot',
    '고장 진단',
    AppGlyph.troubleshoot,
    (_) => const TroubleshootPage(),
    subtitle: '차단기 트립·전압 이상·접속부 발열·지락·조명·변압기·전동기를 질문과 측정값으로 좁히기',
    group: '전기',
  ),
  QuickToolDef(
    'signal',
    '계기 교정',
    AppGlyph.currentLoop,
    (_) => const SignalCalculatorPage(),
    subtitle: '교정 점검 · 4-20mA · 온도 센서 · 교정 가스 · 성적서',
    group: '계장',
  ),
  QuickToolDef(
    'steel',
    '형강 컷팅 (찬넬/앵글)',
    AppGlyph.steel,
    (_) => const MobileSteelProjectListPage(),
    subtitle: '규격·길이만 넣어 재단 계획·지시서 출력',
    group: '가공·배치',
  ),
  QuickToolDef(
    'layout',
    '작업 배치도',
    AppGlyph.layout,
    (_) => const LayoutBoardProjectListPage(),
    subtitle: '캐비닛 중판 레이아웃 및 튜빙/결선 스케치',
    group: '가공·배치',
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

  /// 앱 전체(화면들을 담은 Navigator 바깥)에 얹을 때 앱의 Navigator 열쇠. 주면 도구 화면·창을 그
  /// Navigator에 연다. 없으면 이 위젯 위쪽의 Navigator를 쓴다.
  final GlobalKey<NavigatorState>? navigatorKey;

  const QuickToolBarHost({
    super.key,
    required this.child,
    this.enabled = true,
    this.tools,
    this.navigatorKey,
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

  NavigatorState get _nav =>
      widget.navigatorKey?.currentState ?? Navigator.of(context);
  BuildContext get _navContext => widget.navigatorKey?.currentContext ?? context;

  @override
  void didUpdateWidget(QuickToolBarHost old) {
    super.didUpdateWidget(old);
    // 이 화면에서 빼기로 했으면 열려 있던 막대도 바로 접는다.
    if (old.enabled && !widget.enabled && (_open || _mounted)) {
      _closeTimer?.cancel();
      _open = false;
      _mounted = false;
    }
  }

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
    _nav.push(MaterialPageRoute<void>(builder: t.builder));
  }

  /// 전체 기능을 아이콘 격자로 띄우고 검색으로도 찾는다. 세부 기능이 있는 큰 기능은 폴더 하나로 묶여
  /// 누르면 안의 기능이 열린다. 누르면 작업 화면 위에 열린다.
  void _showAll() {
    HapticFeedback.selectionClick();
    final nav = _nav;
    final sheetContext = _navContext;
    _closeBar();
    final mains = widget.tools ?? kQuickTools;
    final subs = widget.tools == null ? kQuickSubTools : const <QuickToolDef>[];
    FeatureItem leaf(QuickToolDef t, {String? title}) => FeatureItem(
      title: title ?? t.label,
      subtitle: t.subtitle,
      glyph: t.glyph,
      icon: t.icon,
      group: t.group,
      onTap: () => nav.push(MaterialPageRoute<void>(builder: t.builder)),
    );
    final items = <FeatureItem>[];
    for (final m in mains) {
      final kids = [
        for (final s in subs)
          if (s.group == m.label) s,
      ];
      if (kids.isEmpty) {
        items.add(leaf(m));
        continue;
      }
      items.add(
        FeatureItem(
          title: m.label,
          subtitle: m.subtitle,
          glyph: m.glyph,
          icon: m.icon,
          group: m.group,
          onTap: () => nav.push(MaterialPageRoute<void>(builder: m.builder)),
          children: [
            leaf(m, title: '첫 화면'),
            for (final s in kids) leaf(s),
          ],
        ),
      );
    }
    showFeatureSearchSheet(
      sheetContext,
      title: '전체 기능',
      grid: true,
      items: items,
    );
  }

  Future<void> _edit() async {
    await showModalBottomSheet<void>(
      context: _navContext,
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
                      secondary: t.iconWidget(size: 24, color: fc.text),
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
                              t.iconWidget(size: 26, color: fc.text),
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
                    InkWell(
                      key: const Key('quick_tool_all'),
                      onTap: _showAll,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.layoutGrid,
                              size: 26,
                              color: fc.text,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '전체',
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
                    // 툴팁은 쓰지 않는다: 이 막대는 앱의 Navigator 바깥에 얹혀 Overlay가 없어 툴팁이 오류를 낸다.
                    Semantics(
                      label: '막대 편집',
                      button: true,
                      child: IconButton(
                        key: const Key('quick_tool_edit'),
                        icon: Icon(Icons.tune, size: 22, color: fc.textSub),
                        onPressed: _edit,
                      ),
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

// ── 앱 전체에 막대 얹기 ──
// 막대를 모든 화면에서 쓰되, 손가락으로 화면 가장자리를 쓰는 화면(배치도·사진 확대·QR 스캔 등)이나
// 가로로 눕힌 화면, 창·아래 시트가 떠 있을 때는 손잡이를 숨긴다.

/// 화면 변화가 그리는 도중에 일어나도 안전하게 값을 바꾼다(그리는 중이면 한 프레임 뒤에).
void _setLater<T>(ValueNotifier<T> n, T v) {
  if (n.value == v) return;
  final phase = SchedulerBinding.instance.schedulerPhase;
  if (phase == SchedulerPhase.persistentCallbacks) {
    SchedulerBinding.instance.addPostFrameCallback((_) => n.value = v);
  } else {
    n.value = v;
  }
}

/// 지금 가장 위 경로가 "화면"(창·시트가 아닌 것)인지 지켜본다.
class QuickBarRouteTracker extends NavigatorObserver {
  final ValueNotifier<bool> topIsPage = ValueNotifier(false);
  final List<Route<dynamic>> _stack = [];

  void _update() =>
      _setLater(topIsPage, _stack.isNotEmpty && _stack.last is PageRoute);

  /// 시험용: 지켜보던 경로를 잊는다(앞 시험의 Navigator가 남기고 간 것 지우기).
  @visibleForTesting
  void reset() {
    _stack.clear();
    topIsPage.value = false;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
    _update();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _update();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _update();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (i >= 0) {
      if (newRoute != null) {
        _stack[i] = newRoute;
      } else {
        _stack.removeAt(i);
      }
    } else if (newRoute != null) {
      _stack.add(newRoute);
    }
    _update();
  }
}

abstract final class QuickBarGate {
  /// 막대를 빼 달라고 한 화면 수(0이면 모두 허용).
  static final ValueNotifier<int> suppressed = ValueNotifier(0);
  static final QuickBarRouteTracker tracker = QuickBarRouteTracker();
}

/// 이 위젯이 화면에 있는 동안(그리고 [enabled]인 동안) 앱 전체 막대의 손잡이를 숨긴다.
class QuickBarSuppress extends StatefulWidget {
  final Widget child;
  final bool enabled;
  const QuickBarSuppress({super.key, required this.child, this.enabled = true});

  @override
  State<QuickBarSuppress> createState() => _QuickBarSuppressState();
}

class _QuickBarSuppressState extends State<QuickBarSuppress> {
  bool _counted = false;

  void _apply(bool want) {
    if (want == _counted) return;
    _counted = want;
    _setLater(
      QuickBarGate.suppressed,
      QuickBarGate.suppressed.value + (want ? 1 : -1),
    );
  }

  @override
  void initState() {
    super.initState();
    _apply(widget.enabled);
  }

  @override
  void didUpdateWidget(QuickBarSuppress old) {
    super.didUpdateWidget(old);
    _apply(widget.enabled);
  }

  @override
  void dispose() {
    if (_counted) {
      _counted = false;
      final v = QuickBarGate.suppressed;
      // 사라지는 도중이라 한 프레임 뒤에 뺀다.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (v.value > 0) v.value = v.value - 1;
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 앱의 Navigator 바깥에 얹어 모든 화면에서 막대를 쓰게 한다.
class GlobalQuickToolBar extends StatelessWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final List<QuickToolDef>? tools;
  const GlobalQuickToolBar({
    super.key,
    required this.child,
    required this.navigatorKey,
    this.tools,
  });

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return ValueListenableBuilder<int>(
      valueListenable: QuickBarGate.suppressed,
      builder: (context, hidden, _) => ValueListenableBuilder<bool>(
        valueListenable: QuickBarGate.tracker.topIsPage,
        builder: (context, onPage, _) => QuickToolBarHost(
          navigatorKey: navigatorKey,
          tools: tools,
          enabled: hidden == 0 && onPage && !landscape,
          child: child,
        ),
      ),
    );
  }
}
