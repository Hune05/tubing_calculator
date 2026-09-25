import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../../../data/models/conduit_data_manager.dart';
import '../../conduit/screens/conduit_input_tab.dart' show ConduitInputTab;
import '../models/instrument_shape_painter.dart';
import '../models/skid_part_painter.dart';
import '../models/layout_board_models.dart';
import '../models/skid_presets.dart';
import '../models/skid_route.dart';
import '../widgets/korean_text.dart';
import '../widgets/layout_board_ui.dart';

// 🚀 스키드 전선관 경로 입력. 위에는 작은 도면(평면·정면·좌측면·우측면)에 경로를 바로 그리고,
// 아래는 전선관 벤딩 계산기 입력 탭을 그대로 쓴다(90°|직관+각도|0°, 방향 6칸, 카드 밀어서
// 지우기, 특수 벤딩의 오프셋·롤링 오프셋·새들 계산기). 목록은 계산기 목록과 따로 논다.

class SkidRouteEditorPage extends StatefulWidget {
  final ConduitRoute route;

  /// 도면 탭들(평면 'main'·'front'·'left'·'right'). 저장 모양(panelWidth·panelHeight·items).
  final Map<String, Map<String, dynamic>> plates;

  /// 같은 도면의 다른 경로(연하게 그린다).
  final List<ConduitRoute> otherRoutes;

  /// 처음 보여 줄 탭.
  final String initialView;

  const SkidRouteEditorPage({
    super.key,
    required this.route,
    required this.plates,
    this.otherRoutes = const [],
    this.initialView = kPlateMainId,
  });

  /// 경로 입력 화면을 연다. 저장하면 고친 경로, 그냥 나가면 null.
  static Future<ConduitRoute?> open(
    BuildContext context, {
    required ConduitRoute route,
    required Map<String, Map<String, dynamic>> plates,
    List<ConduitRoute> otherRoutes = const [],
    String initialView = kPlateMainId,
  }) => Navigator.push<ConduitRoute>(
    context,
    MaterialPageRoute(
      builder: (_) => SkidRouteEditorPage(
        route: route,
        plates: plates,
        otherRoutes: otherRoutes,
        initialView: initialView,
      ),
    ),
  );

  @override
  State<SkidRouteEditorPage> createState() => _SkidRouteEditorPageState();
}

class _SkidRouteEditorPageState extends State<SkidRouteEditorPage> {
  late final ConduitRoute _route = ConduitRoute.fromJson(widget.route.toJson());
  late final String _startJson = _json(_route);
  late final ConduitDataManager _list = ConduitDataManager.detached(
    _route.bends,
  );
  late String _view = kSkidViewOrder.contains(widget.initialView)
      ? widget.initialView
      : kPlateMainId;

  static String _json(ConduitRoute r) => r.toJson().toString();

  // 도면에서 경로 선을 눌러 이 화면을 열면, 그 누름이 막 뜬 작은 도면에도 닿아 크게 보기가
  // 같이 열렸다. 열린 뒤 잠깐은 작은 도면 누름을 받지 않는다.
  final DateTime _openedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _list.addListener(_onListChanged);
  }

  @override
  void dispose() {
    _list.removeListener(_onListChanged);
    super.dispose();
  }

  void _onListChanged() {
    setState(() {
      _route.bends = [
        for (final b in _list.bendList) Map<String, dynamic>.from(b),
      ];
    });
  }

  Map<String, dynamic> get _plan => widget.plates[kPlateMainId] ?? const {};
  List<PlacedItem> get _planItems => layoutItemsFromData(_plan);
  double get _planW => (_plan['panelWidth'] as num?)?.toDouble() ?? 2400;
  double get _planH => (_plan['panelHeight'] as num?)?.toDouble() ?? 1200;

  /// 탭 크기(없는 탭은 새로 만들 때와 같은 기본 크기).
  Size _viewSize(String id) {
    final p = widget.plates[id];
    final double? w = (p?['panelWidth'] as num?)?.toDouble();
    final double? h = (p?['panelHeight'] as num?)?.toDouble();
    if (id == kPlateMainId) return Size(_planW, _planH);
    return Size(
      w ?? (id == kSkidViewFront ? _planW : _planH),
      h ?? kSkidDefaultHeight,
    );
  }

  bool get _changed => _json(_route) != _startJson;

  Future<bool> _confirmLeave() async {
    if (!_changed) return true;
    return confirmLayoutDanger(
      context,
      title: "저장하지 않고 나가기",
      message: "고친 경로를 저장하지 않고 나갑니다.",
      confirmLabel: "나가기",
    );
  }

  Future<void> _sendToCalculator() async {
    if (_route.bends.isEmpty) return;
    final ok = await confirmLayoutDanger(
      context,
      title: "계산기로 보내기",
      message:
          "전선관 벤딩 계산기의 입력 목록을 이 경로(${_route.bends.length}줄)로 바꿉니다. 계산기에서 ↶로 되돌릴 수 있습니다.",
      confirmLabel: "보내기",
    );
    if (!ok || !mounted) return;
    ConduitDataManager().replaceAll(_route.bends);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          keepWords(
            "전선관 계산기 입력 목록에 넣었습니다. 계산기 설정 규격이 후강 ${_route.size}인지 확인하십시오.",
          ),
        ),
      ),
    );
  }

  String _startText() {
    final plan = _planItems;
    final it = plan.where((e) => e.id == _route.startItemId).firstOrNull;
    final double z = it?.elevation ?? _route.z;
    final String from = it != null
        ? it.name
        : "가로 ${_route.x.toInt()} · 세로 ${_route.y.toInt()}";
    final end = _route.endRun(plan);
    final String to = end == null
        ? ""
        : " → 끝: ${end.item.name} (마지막 줄 ${end.length.round()})";
    return "시작: $from · 높이 ${z.toInt()} · ${routeDirLabel(_route.startDir)}$to";
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: tossBg,
        appBar: AppBar(
          backgroundColor: pureWhite,
          foregroundColor: tossText,
          elevation: 0,
          titleSpacing: 0,
          title: Text(
            "${_route.name} · 후강 ${_route.size}",
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              key: const ValueKey("route_to_calc"),
              tooltip: "계산기로 보내기",
              icon: const Icon(AppIcons.send),
              onPressed: _route.bends.isEmpty ? null : _sendToCalculator,
            ),
            TextButton(
              key: const ValueKey("route_save"),
              onPressed: () => Navigator.pop(context, _route),
              child: const Text(
                "저장",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: tossBlue,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildStartRow(),
            _buildViewTabs(),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.26,
              child: _buildMiniBoard(),
            ),
            for (final w in [
              ..._route.warnings(),
              ..._route.endWarnings(_planItems),
            ])
              Container(
                width: double.infinity,
                color: warningRed.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Text(
                  keepWords(w),
                  style: const TextStyle(fontSize: 13, color: warningRed),
                ),
              ),
            Expanded(child: ConduitInputTab(manager: _list)),
          ],
        ),
      ),
    );
  }

  Widget _buildStartRow() => Material(
    color: pureWhite,
    child: InkWell(
      key: const ValueKey("route_start"),
      onTap: _editStart,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _startText(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tossSubText,
                ),
              ),
            ),
            const Icon(Icons.edit_outlined, size: 20, color: tossBlue),
          ],
        ),
      ),
    ),
  );

  Widget _buildViewTabs() => Container(
    color: pureWhite,
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
    child: Row(
      children: [
        for (final id in kSkidViewOrder) ...[
          Expanded(
            child: ChoiceChip(
              key: ValueKey("route_view_$id"),
              label: SizedBox(
                width: double.infinity,
                child: Text(
                  skidViewLabel(id),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
              labelPadding: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              visualDensity: VisualDensity.compact,
              selected: id == _view,
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: id == _view ? pureWhite : tossText,
              ),
              selectedColor: tossBlue,
              backgroundColor: pureWhite,
              side: BorderSide(color: id == _view ? tossBlue : layoutLine),
              onSelected: (_) => setState(() => _view = id),
            ),
          ),
          if (id != kSkidViewOrder.last) const SizedBox(width: 6),
        ],
      ],
    ),
  );

  Widget _buildMiniBoard() => GestureDetector(
    key: const ValueKey("route_mini_board"),
    onTap: _openBigBoard,
    child: Stack(
      children: [
        Positioned.fill(child: _boardPaint(_view)),
        const Positioned(
          right: 8,
          bottom: 6,
          child: Icon(Icons.zoom_out_map_rounded, size: 22, color: tossSubText),
        ),
      ],
    ),
  );

  // 작은 도면을 누르면 크게: 화면 전체에 같은 그림, 손가락으로 벌려 더 키운다. 탭도 바꾼다.
  void _openBigBoard() {
    if (DateTime.now().difference(_openedAt) <
        const Duration(milliseconds: 700)) {
      return;
    }
    String view = _view;
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setBig) => Scaffold(
            key: const ValueKey("route_big_board"),
            backgroundColor: tossBg,
            appBar: AppBar(
              backgroundColor: pureWhite,
              foregroundColor: tossText,
              elevation: 0,
              title: Text(
                "${_route.name} · 크게 보기",
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            body: Column(
              children: [
                Container(
                  color: pureWhite,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      for (final id in kSkidViewOrder) ...[
                        Expanded(
                          child: ChoiceChip(
                            label: SizedBox(
                              width: double.infinity,
                              child: Text(
                                skidViewLabel(id),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                            labelPadding: EdgeInsets.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 4,
                            ),
                            selected: id == view,
                            showCheckmark: false,
                            labelStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: id == view ? pureWhite : tossText,
                            ),
                            selectedColor: tossBlue,
                            backgroundColor: pureWhite,
                            side: BorderSide(
                              color: id == view ? tossBlue : layoutLine,
                            ),
                            onSelected: (_) => setBig(() => view = id),
                          ),
                        ),
                        if (id != kSkidViewOrder.last) const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    key: ValueKey("big_$view"),
                    minScale: 1,
                    maxScale: 12,
                    child: SizedBox.expand(child: _boardPaint(view)),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 6, 16, 16),
                  child: Text(
                    "두 손가락으로 벌려 키우고, 끌어서 옮깁니다.",
                    style: TextStyle(fontSize: 14, color: tossSubText),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _boardPaint(String view) {
    final Size board = _viewSize(view);
    final plan = _planItems;
    Offset proj(vm.Vector3 p) => projectToView(
      p,
      view,
      planW: _planW,
      planH: _planH,
      viewH: board.height,
    );
    final viewItems = view == kPlateMainId
        ? plan
        : layoutItemsFromData(widget.plates[view] ?? const {});
    return CustomPaint(
      size: Size.infinite,
      painter: SkidMiniViewPainter(
        board: board,
        items: viewItems,
        view: view,
        // 정면·측면은 평면 부품을 그 면에서 본 모양으로(가까운 것이 위, 가려진 것은 점선).
        planViews: view == kPlateMainId
            ? const []
            : skidViewLayout(plan, view, planH: _planH, viewH: board.height),
        others: [
          for (final r in widget.otherRoutes)
            if (r.id != _route.id) (r.points(plan).map(proj).toList(), r.od),
        ],
        route: _route.points(plan).map(proj).toList(),
        routeOd: _route.od,
        version:
            "${view}_${_json(_route)}_${plan.map((e) => e.toJson()).join()}",
      ),
    );
  }

  Future<void> _editStart() async {
    final plan = _planItems;
    final nameCtrl = TextEditingController(text: _route.name);
    final xCtrl = TextEditingController(text: _num(_route.x));
    final yCtrl = TextEditingController(text: _num(_route.y));
    final zCtrl = TextEditingController(text: _num(_route.z));
    final r = ConduitRoute.fromJson(_route.toJson());
    final bool? ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "경로 시작",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: tossText,
                  ),
                ),
                const SizedBox(height: 12),
                _field(nameCtrl, "이름", number: false),
                const SizedBox(height: 12),
                _label("후강 규격"),
                _chips<int>(
                  kThickConduitOd.keys.toList(),
                  r.size,
                  (v) => "$v",
                  (v) => setSheet(() => r.size = v),
                ),
                const SizedBox(height: 12),
                _label("시작 부품 (평면 부품 가운데·바닥에서 높이)"),
                DropdownButton<String?>(
                  isExpanded: true,
                  value: plan.any((e) => e.id == r.startItemId)
                      ? r.startItemId
                      : null,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text("부품 없이 자리로"),
                    ),
                    for (final it in plan)
                      DropdownMenuItem<String?>(
                        value: it.id,
                        child: Text(it.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setSheet(() => r.startItemId = v),
                ),
                if (!plan.any((e) => e.id == r.startItemId)) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _field(xCtrl, "가로 (왼쪽에서)")),
                      const SizedBox(width: 8),
                      Expanded(child: _field(yCtrl, "세로 (위에서)")),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                _field(zCtrl, "높이 (바닥에서, 부품에 높이가 없을 때)"),
                const SizedBox(height: 12),
                _label("처음 나가는 방향 (앞 = 평면 아래쪽)"),
                _chips<double>(
                  [for (final d in kRouteDirections) d.$1],
                  r.startDir,
                  routeDirLabel,
                  (v) => setSheet(() => r.startDir = v),
                ),
                const SizedBox(height: 12),
                _label("끝 부품 (고르면 마지막 줄을 그 부품 가운데까지 자동으로 잇습니다)"),
                DropdownButton<String?>(
                  key: const ValueKey("route_end_item"),
                  isExpanded: true,
                  value: plan.any((e) => e.id == r.endItemId)
                      ? r.endItemId
                      : null,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text("없음 (마지막 꺾이는 점에서 끝)"),
                    ),
                    for (final it in plan)
                      if (it.id != r.startItemId)
                        DropdownMenuItem<String?>(
                          value: it.id,
                          child: Text(it.name, overflow: TextOverflow.ellipsis),
                        ),
                  ],
                  onChanged: (v) => setSheet(() => r.endItemId = v),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const ValueKey("route_start_ok"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tossBlue,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    "적용",
                    style: TextStyle(
                      color: pureWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _route
        ..name = nameCtrl.text.trim().isEmpty ? r.name : nameCtrl.text.trim()
        ..size = r.size
        ..startItemId = r.startItemId
        ..endItemId = r.endItemId
        ..startDir = r.startDir
        ..x = double.tryParse(xCtrl.text.trim()) ?? r.x
        ..y = double.tryParse(yCtrl.text.trim()) ?? r.y
        ..z = double.tryParse(zCtrl.text.trim()) ?? r.z;
    });
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: tossSubText,
      ),
    ),
  );

  Widget _field(TextEditingController c, String label, {bool number = true}) =>
      TextField(
        controller: c,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: const TextStyle(fontSize: 16, color: tossText),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      );

  Widget _chips<T>(
    List<T> values,
    T selected,
    String Function(T) label,
    ValueChanged<T> onPick,
  ) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final v in values)
        ChoiceChip(
          label: Text(label(v)),
          selected: v == selected,
          showCheckmark: false,
          labelStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: v == selected ? pureWhite : tossText,
          ),
          selectedColor: tossBlue,
          backgroundColor: pureWhite,
          side: BorderSide(color: v == selected ? tossBlue : layoutLine),
          onSelected: (_) => onPick(v),
        ),
    ],
  );
}

/// 작은 도면: 판 테두리, 그 탭의 부품(모양), 평면 부품(그 면에서 본 모양), 다른 경로(회색), 고치는 경로(청록).
/// 좌표는 mm, 칸에 맞춰 줄이되 선 굵기는 줄이지 않는다.
class SkidMiniViewPainter extends CustomPainter {
  final Size board;
  final List<PlacedItem> items;

  /// 어느 면인지('main'·'front'·'left'·'right').
  final String view;

  /// 정면·측면에 그릴 평면 부품(skidViewLayout: 먼 것부터, 가려진 정도 포함).
  final List<({PlacedItem it, Rect rect, SkidFace face, double covered})>
  planViews;
  final List<(List<Offset>, double)> others;
  final List<Offset> route;
  final double routeOd;
  final String version;

  const SkidMiniViewPainter({
    required this.board,
    required this.items,
    this.view = kPlateMainId,
    this.planViews = const [],
    required this.others,
    required this.route,
    required this.routeOd,
    required this.version,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (board.width <= 0 || board.height <= 0) return;
    const double pad = 10;
    final double k = math.min(
      (size.width - pad * 2) / board.width,
      (size.height - pad * 2) / board.height,
    );
    final Offset o = Offset(
      (size.width - board.width * k) / 2,
      (size.height - board.height * k) / 2,
    );
    Offset p(Offset mm) => o + mm * k;
    Rect r(Rect mm) => Rect.fromPoints(p(mm.topLeft), p(mm.bottomRight));

    canvas.drawRect(r(Offset.zero & board), Paint()..color = pureWhite);
    canvas.drawRect(
      r(Offset.zero & board),
      Paint()
        ..color = tossText
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    for (final it in items) {
      final Rect rr = r(it.position & Size(it.width, it.height));
      if (SkidShape.isFitting(it.shape)) {
        canvas.save();
        canvas.translate(rr.left, rr.top);
        SkidPartPainter(
          shape: it.shape!,
          mirror: it.flipped,
          strokeWidth: 0.8,
        ).paint(canvas, rr.size);
        canvas.restore();
      } else if (it.shape != null) {
        canvas.save();
        canvas.translate(rr.left, rr.top);
        InstrumentShapePainter(
          shape: it.shape!,
          strokeWidth: 0.8,
        ).paint(canvas, rr.size);
        canvas.restore();
      } else {
        canvas.drawRect(
          rr,
          Paint()
            ..color = const Color(0xFF94A3B8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }

    // 평면 부품을 이 면에서 본 모양으로. 반 넘게 가려진 것은 점선 테두리만.
    final hiddenPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final pv in planViews) {
      final Rect rr = r(pv.rect);
      if (rr.width <= 0 || rr.height <= 0) continue;
      canvas.save();
      canvas.translate(rr.left, rr.top);
      SkidPartPainter(
        shape: pv.it.shape ?? '',
        face: pv.face,
        mirror: pv.face == SkidFace.side
            ? (pv.it.flipped != (view == 'right'))
            : view == 'right',
        strokeWidth: 0.8,
      ).paint(canvas, rr.size);
      canvas.restore();
      if (pv.covered >= 0.5) {
        const double dash = 4, gap = 3;
        void seg(Offset a, Offset b) {
          final double len = (b - a).distance;
          if (len <= 0) return;
          final Offset d = (b - a) / len;
          for (double t = 0; t < len; t += dash + gap) {
            canvas.drawLine(
              a + d * t,
              a + d * math.min(t + dash, len),
              hiddenPaint,
            );
          }
        }

        seg(rr.topLeft, rr.topRight);
        seg(rr.topRight, rr.bottomRight);
        seg(rr.bottomRight, rr.bottomLeft);
        seg(rr.bottomLeft, rr.topLeft);
      }
    }

    void line(List<Offset> pts, double od, Color c, bool dots) {
      if (pts.isEmpty) return;
      final path = Path()..moveTo(p(pts.first).dx, p(pts.first).dy);
      for (final q in pts.skip(1)) {
        path.lineTo(p(q).dx, p(q).dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = c.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(od * k, 4)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      if (dots) {
        for (final q in pts) {
          canvas.drawCircle(p(q), 3, Paint()..color = c);
        }
        canvas.drawCircle(
          p(pts.first),
          5,
          Paint()
            ..color = c
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    for (final (pts, od) in others) {
      line(pts, od, const Color(0xFF94A3B8), false);
    }
    line(route, routeOd, tossBlue, true);
  }

  @override
  bool shouldRepaint(covariant SkidMiniViewPainter old) =>
      old.version != version || old.board != board;
}
