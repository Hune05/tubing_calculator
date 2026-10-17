import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:vector_math/vector_math_64.dart' as vmath;
import 'package:shared_preferences/shared_preferences.dart'; // 🚀 SharedPreferences 추가
import 'package:tubing_calculator/src/presentation/calculator/widgets/pipe_path_points.dart';

Color get makitaTeal => AppColors.brand;

/// 캐드식 치수 색(어두운 아이소 바탕 위).
const Color _kDimLine = Color(0xFF9FB3C8);
const Color _kDimPass = Color(0xFF4CC38A);
const Color _kDimFail = Color(0xFFFF6B6B);

// 🚀 기존 태블릿 코드와 충돌하지 않도록 독립적인 모바일 전용 클래스 생성
class MobilePipeVisualizer extends StatefulWidget {
  final List<Map<String, dynamic>> bendList;
  final double tailLength;
  final int? selectedSegmentIndex;
  final String initialStartDir;

  /// 폰에 적어 둔 시작 방향(계산기 마지막 값)을 덮어 쓸지. 보관함 도면은 도면에 적힌
  /// 방향을 그대로 써야 하므로 false로 연다(예전엔 열기만 해도 도면 방향이 바뀌어 저장됐다).
  final bool useSavedDirection;

  /// 시작 방향을 폰에 적는 칸(튜브 mobile_saved_start_dir, 전선관 conduit_saved_start_dir).
  final String startDirPrefKey;
  final ValueChanged<String>? onStartDirChanged;
  final bool isLightMode;
  final bool startFit;
  final bool endFit;

  // 🚀 앞서 추가했던 총 컷팅 기장 변수
  final double totalCutLength;

  /// 벤드 반경. 실제 형상으로 그릴 때 모서리를 이만큼 둥글게 그린다.
  final double bendRadius;

  /// 관 바깥지름. 실제 형상으로 그릴 때 관 굵기를 이만큼 그린다.
  final double outerDiameter;

  /// 피팅에 관이 들어가는 깊이. 실제 형상으로 그릴 때 이 길이만큼 피팅을 그린다.
  final double fittingDepth;

  /// 캐드식 치수에 붙일 실측 차이(배관 줄 번호 → 실측 − 계산 mm, 10-17).
  /// 현장 탭 [실측]에서 넣은 값이다.
  final Map<int, double> measuredDiff;

  /// 절단 길이 실측 차이(없으면 null).
  final double? cutDiff;

  /// 합격 허용(± mm).
  final double tolerance;

  /// 치수 단추(끔·계획·실측)를 보일지. 보관함 상세처럼 보기만 하는 곳은 끈다.
  final bool showDimControl;

  /// [실측] 보기를 보일지(10-18). 보관함 도면 보기처럼 보기만 하는 곳은 끔·계획만.
  final bool allowMeasureMode;

  /// "실측" 보기에서 치수(또는 관)를 누르면 그 구간이 끝나는 벤드 줄 번호로 부른다(마지막 직관은 -1).
  final ValueChanged<int>? onLegTap;

  /// "실측" 보기에서 꺾이는 점을 누르면 그 벤드 줄 번호로 부른다(각도 실측).
  final ValueChanged<int>? onBendTap;

  /// 각도 실측(벤드 줄 → 잰 각도 °)과 허용(± °).
  final Map<int, double> measuredAngle;
  final double angleTolerance;

  const MobilePipeVisualizer({
    super.key,
    required this.bendList,
    this.tailLength = 0.0,
    this.selectedSegmentIndex,
    this.initialStartDir = 'RIGHT',
    this.onStartDirChanged,
    this.useSavedDirection = true,
    this.startDirPrefKey = 'mobile_saved_start_dir',
    this.isLightMode = false,
    this.startFit = false,
    this.endFit = false,
    this.totalCutLength = 0.0,
    this.bendRadius = 0.0,
    this.outerDiameter = 0.0,
    this.fittingDepth = 0.0,
    this.measuredDiff = const {},
    this.cutDiff,
    this.tolerance = 2.0,
    this.showDimControl = false,
    this.allowMeasureMode = true,
    this.onLegTap,
    this.onBendTap,
    this.measuredAngle = const {},
    this.angleTolerance = 1.0,
  });

  @override
  State<MobilePipeVisualizer> createState() => _MobilePipeVisualizerState();
}

class _MobilePipeVisualizerState extends State<MobilePipeVisualizer> {
  static const double _defaultRotX = -math.pi / 6;
  static const double _defaultRotY = -math.pi / 4;

  double _rotationX = _defaultRotX;
  double _rotationY = _defaultRotY;
  double _zoomLevel = 1.0;
  double _baseZoom = 1.0;

  double _panX = 0.0;
  double _panY = 0.0;

  /// 실제 비율로 그릴지. 켜면 길이를 있는 그대로, 모서리는 반경만큼 둥글게,
  /// 관 굵기도 바깥지름대로 그린다. 끄면 짧은 구간도 보이게 줄여 그린다
  /// (긴 배관에 아주 짧은 마디가 섞였을 때 쓴다).
  bool _realScale = true;

  bool _isFlippedX = false;
  bool _isFlippedY = false;

  late String _startDir;

  /// 캐드식 치수(10-17): 0 끔 · 1 계획 · 2 계획+실측. 폰에 기억한다.
  int _dimMode = 0;

  /// 지금 보일 치수 보기(실측을 못 쓰는 곳에서는 실측이 계획으로).
  int get _mode => widget.allowMeasureMode ? _dimMode : math.min(_dimMode, 1);
  static const String _dimKey = 'iso_dim_mode_v1';

  /// 마지막으로 그린 치수 자리(누른 곳 찾기용). 그리기가 채운다.
  final List<IsoDimHit> _dimHits = [];

  /// 마지막으로 그린 꺾이는 점 자리(각도 실측 누르기용).
  final List<IsoBendHit> _bendHits = [];

  /// 실측 말풍선(누른 배지 하나만 자세히). null이면 닫힘.
  ({
    String title,
    String plan,
    String meas,
    String diff,
    bool ok,
    VoidCallback edit,
    Offset at,
  })?
  _detail;

  String _n(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  void _onTapUp(TapUpDetails d) {
    if (_mode != 2) return;
    final p = d.localPosition;
    final had = _detail;
    if (had != null) setState(() => _detail = null);
    // 꺾이는 점(또는 그 각도 글)을 먼저 본다.
    final bcb = widget.onBendTap;
    if (bcb != null) {
      IsoBendHit? hb;
      var bd = 26.0;
      for (final h in _bendHits) {
        if (h.box.inflate(4).contains(p)) {
          hb = h;
          break;
        }
        final dd = (p - h.at).distance;
        if (dd < bd) {
          bd = dd;
          hb = h;
        }
      }
      if (hb != null) {
        final meas = widget.measuredAngle[hb.row];
        if (meas == null) {
          bcb(hb.row);
          return;
        }
        if (had != null && had.at == hb.at) return; // 같은 것 다시 누르면 닫기
        final dd = meas - hb.design;
        final row = hb.row;
        final h = hb;
        setState(
          () => _detail = (
            title: '${h.number}번 벤드 각도',
            plan: '설계 ${_n(h.design)}°',
            meas: '실측 ${_n(meas)}°',
            diff: '${dd > 0 ? '+' : (dd < 0 ? '−' : '')}${_n(dd.abs())}°',
            ok: dd.abs() <= widget.angleTolerance + 1e-9,
            edit: () => bcb(row),
            at: h.at,
          ),
        );
        return;
      }
    }
    final cb = widget.onLegTap;
    if (cb == null) return;
    IsoDimHit? best;
    var bestD = 30.0;
    for (final h in _dimHits) {
      if (h.box.inflate(6).contains(p)) {
        best = h;
        break;
      }
      final dd = math.min(_segDist(p, h.a, h.b), _segDist(p, h.da, h.db));
      if (dd < bestD) {
        bestD = dd;
        best = h;
      }
    }
    if (best == null) return;
    final diff = best.row >= 0 ? widget.measuredDiff[best.row] : null;
    if (diff == null) {
      cb(best.row);
      return;
    }
    final at = best.box.center;
    if (had != null && had.at == at) return;
    final row = best.row;
    final bh = best;
    setState(
      () => _detail = (
        title: '${bh.number}번 구간 길이',
        plan: '계획 ${bh.plan.round()}',
        meas: '실측 ${(bh.plan + diff).round()}',
        diff: '${diff > 0 ? '+' : ''}${_n(diff)} mm',
        ok: diff.abs() <= widget.tolerance + 1e-9,
        edit: () => cb(row),
        at: at,
      ),
    );
  }

  // 잘 보이게 맞춤(10-17): 8방향을 미리 대 보고, 구간이 정면으로 보여 짧아지거나(점처럼)
  // 서로 겹치는 일이 가장 적은 방향으로 돌린 뒤 화면에 맞춘다.
  void _autoFit() {
    final path = pipeDrawPath(
      widget.bendList,
      startDir: _startDir,
      radius: 0,
      tail: widget.tailLength,
    );
    final pts = path.points;
    if (pts.length < 2) return;
    final size = context.size;
    if (size == null || size.isEmpty) return;
    // 10-17 A11 시험: 관 모양만 보고 고르면 글이 몰리는 방향을 골랐다. 8방향을 화면 밖에서
    // 실제로 그려 보고, 치수·각도 글이 멀리 밀리거나 겹치거나 화면 밖에 걸친 정도로 고른다.
    final mode = !widget.showDimControl || _mode == 0 ? 1 : _mode;
    final topInset = _topInset;
    final bottomInset = _bottomInset;
    final view = Rect.fromLTRB(
      4,
      math.max(4.0, topInset),
      size.width - 4,
      size.height - math.max(4.0, bottomInset),
    );
    var best = double.infinity;
    var bestRy = _defaultRotY;
    for (var k = 0; k < 8; k++) {
      final ry = _defaultRotY + k * math.pi / 4;
      final dh = <IsoDimHit>[];
      final bh = <IsoBendHit>[];
      final painter = MobileIsoPipePainter(
        bendList: widget.bendList,
        tailLength: widget.tailLength,
        rotationX: _defaultRotX,
        rotationY: ry,
        zoomLevel: 0.85,
        panX: 0,
        panY: 0,
        isFlippedX: false,
        isFlippedY: false,
        startDirection: _startDir,
        isLightMode: widget.isLightMode,
        startFit: widget.startFit,
        endFit: widget.endFit,
        realScale: _realScale,
        bendRadius: widget.bendRadius,
        outerDiameter: widget.outerDiameter,
        fittingDepth: widget.fittingDepth,
        dimMode: mode,
        measuredDiff: widget.measuredDiff,
        tolerance: widget.tolerance,
        hits: dh,
        bendHits: bh,
        measuredAngle: widget.measuredAngle,
        angleTolerance: widget.angleTolerance,
        topInset: topInset,
        bottomInset: bottomInset,
      );
      final rec = ui.PictureRecorder();
      painter.paint(Canvas(rec), size);
      rec.endRecording().dispose();
      final sc =
          _layoutScore(dh, bh, view) +
          0.3 * isoViewScore(pts, _defaultRotX, ry) +
          (k == 0 ? 0 : 0.2); // 비슷하면 처음 방향
      if (sc < best - 1e-6) {
        best = sc;
        bestRy = ry;
      }
    }
    setState(() {
      _rotationX = _defaultRotX;
      _rotationY = bestRy;
      _zoomLevel = 0.85;
      _panX = 0;
      _panY = 0;
      _isFlippedX = false;
      _isFlippedY = false;
      _detail = null;
    });
  }

  /// 그려 본 치수·각도 글 자리로 매긴 점수(낮을수록 잘 보임).
  static double _layoutScore(
    List<IsoDimHit> dh,
    List<IsoBendHit> bh,
    Rect view,
  ) {
    var s = 0.0;
    final boxes = <Rect>[];
    for (final h in dh) {
      s += math.max(0.0, (h.da - h.a).distance - 32) / 26; // 바깥으로 밀린 칸 수
      boxes.add(h.box);
    }
    for (final h in bh) {
      s += math.max(0.0, (h.box.center - h.at).distance - 30) / 20;
      boxes.add(h.box);
    }
    for (final r in boxes) {
      if (!view.contains(r.topLeft) || !view.contains(r.bottomRight)) s += 3;
    }
    for (var i = 0; i < boxes.length; i++) {
      for (var j = i + 1; j < boxes.length; j++) {
        if (boxes[i].overlaps(boxes[j])) s += 2;
      }
    }
    return s;
  }

  static double _segDist(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final l2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (l2 < 1e-6) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / l2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  @override
  void initState() {
    super.initState();
    _startDir = widget.initialStartDir; // 1. 우선 기본값으로 세팅
    if (widget.useSavedDirection) _loadSavedDirection();
    if (widget.showDimControl) _loadDimMode();
  }

  Future<void> _loadDimMode() async {
    try {
      final v = (await SharedPreferences.getInstance()).getInt(_dimKey);
      if (v != null && mounted) setState(() => _dimMode = v.clamp(0, 2));
    } catch (_) {}
  }

  Future<void> _setDimMode(int v) async {
    setState(() {
      _dimMode = v;
      _detail = null;
    });
    try {
      await (await SharedPreferences.getInstance()).setInt(_dimKey, v);
    } catch (_) {}
  }

  // 🚀 [추가됨] 앱을 껐다 켜도, 탭을 이동해도 무조건 기억하도록 로드하는 함수
  Future<void> _loadSavedDirection() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDir = prefs.getString(widget.startDirPrefKey);
    if (savedDir != null && mounted) {
      setState(() {
        _startDir = savedDir;
      });
      // 🚀 불러온 값을 부모에게도 동기화
      if (widget.onStartDirChanged != null) {
        widget.onStartDirChanged!(savedDir);
      }
    }
  }

  // 부모가 넘기는 시작 방향이 "바뀌었을 때만" 따라간다(보관함에서 도면을 불러온 경우).
  // 🚀 [고침] 예전엔 아예 따라가지 않아, 불러온 도면인데 아이소는 옛 방향, 마킹 탭의
  // 관끼리 닿음 검사는 새 방향으로 셈했다. 같은 값을 다시 넘기는 것은 무시하므로
  // 사용자가 드롭다운으로 고른 방향을 덮지 않는다(고른 값은 부모에도 올라간다).
  @override
  void didUpdateWidget(covariant MobilePipeVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_detail != null &&
        (!mapEquals(oldWidget.measuredDiff, widget.measuredDiff) ||
            !mapEquals(oldWidget.measuredAngle, widget.measuredAngle))) {
      _detail = null;
    }
    if (widget.initialStartDir != oldWidget.initialStartDir &&
        widget.initialStartDir != _startDir) {
      setState(() => _startDir = widget.initialStartDir);
    }
  }

  void _resetView() {
    setState(() {
      _rotationX = _defaultRotX;
      _rotationY = _defaultRotY;
      _zoomLevel = 1.0;
      _panX = 0.0;
      _panY = 0.0;
      _isFlippedX = false;
      _isFlippedY = false;
    });
  }

  void _rotateCamera() {
    setState(() {
      _rotationY -= math.pi / 2;
    });
  }

  void _toggleFlipX() {
    setState(() => _isFlippedX = !_isFlippedX);
  }

  void _toggleFlipY() {
    setState(() => _isFlippedY = !_isFlippedY);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseZoom = _zoomLevel;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      if (details.scale == 1.0) {
        _panX += details.focalPointDelta.dx;
        _panY += details.focalPointDelta.dy;
      } else {
        _zoomLevel = (_baseZoom * details.scale).clamp(0.2, 10.0);
      }
    });
  }

  /// 왼쪽 위 칸 묶음(높이를 재서 그림 자리를 비운다).
  final GlobalKey _topKey = GlobalKey();
  double _topBottom = 120;

  void _measureTop() {
    if (!mounted) return;
    final box = _topKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final b = 16 + box.size.height + 8;
    if ((b - _topBottom).abs() > 1) setState(() => _topBottom = b);
  }

  /// 그림 글이 피할 위·아래 높이(아이소 탭에서만).
  double get _topInset =>
      widget.showDimControl && !widget.isLightMode ? _topBottom : 0.0;
  double get _bottomInset =>
      widget.showDimControl && !widget.isLightMode ? 84.0 : 0.0;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTop());
    // 10-17 밤샘 점검: 말풍선이 그리는 중에 context.size를 물어 디버그에서 오류, 릴리스는 지난 크기를 썼다.
    return LayoutBuilder(
      builder: (context, box) {
        _viewSize = box.biggest;
        return _buildStack();
      },
    );
  }

  Size _viewSize = const Size(360, 640);

  Widget _buildStack() {
    return Stack(
      children: [
        // 🌟 1. 도면 렌더링 (제스처 컨트롤 포함)
        GestureDetector(
          onScaleStart: widget.isLightMode ? null : _onScaleStart,
          onScaleUpdate: widget.isLightMode ? null : _onScaleUpdate,
          onDoubleTap: widget.isLightMode ? null : _resetView,
          onTapUp: widget.onLegTap == null && widget.onBendTap == null
              ? null
              : _onTapUp,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: widget.isLightMode
                ? Colors.transparent
                : const Color(0xFF151B22),
            child: CustomPaint(
              painter: MobileIsoPipePainter(
                bendList: widget.bendList,
                tailLength: widget.tailLength,
                rotationX: _rotationX,
                rotationY: _rotationY,
                zoomLevel: _zoomLevel,
                panX: _panX,
                panY: _panY,
                isFlippedX: _isFlippedX,
                isFlippedY: _isFlippedY,
                startDirection: _startDir, // 현재 선택된 방향 주입
                selectedSegmentIndex: widget.selectedSegmentIndex,
                isLightMode: widget.isLightMode,
                startFit: widget.startFit,
                endFit: widget.endFit,
                realScale: _realScale,
                bendRadius: widget.bendRadius,
                outerDiameter: widget.outerDiameter,
                fittingDepth: widget.fittingDepth,
                dimMode: widget.showDimControl ? _mode : 0,
                measuredDiff: widget.measuredDiff,
                tolerance: widget.tolerance,
                hits: _dimHits,
                bendHits: _bendHits,
                measuredAngle: widget.measuredAngle,
                angleTolerance: widget.angleTolerance,
                topInset: _topInset,
                bottomInset: _bottomInset,
              ),
            ),
          ),
        ),

        // 🌟 2. 왼쪽 위 칸들(시작 방향·치수·실측 요약·절단): 한 묶음으로 — 좁으면 접히고(폰),
        // 넓으면 한 줄로(가로 화면). 실제 높이를 재서 그림·치수 글이 그 밑으로 안 들어가게 한다(10-17).
        // 10-17 폰 확인: 요약 글 길이가 바뀌면 줄이 접혔다 펴지며 그림이 위아래로 움직여, 다음에
        // 누른 자리가 다른 것을 집었다 → 줄 배치를 글 길이와 상관없이 고정(요약은 한 줄, 넘치면 …).
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: LayoutBuilder(
            builder: (context, c) =>
                KeyedSubtree(key: _topKey, child: _buildTopBar(c.maxWidth)),
          ),
        ),

        if (_detail != null && _mode == 2) _buildDetailBubble(),

        // 🌟 4. 모바일 전용 컴팩트 컨트롤러 (하단 중앙 플로팅 바)
        if (!widget.isLightMode)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              // 10-17: 320dp 폰에서 단추 하나 늘어 6px 넘쳤다 → 좁으면 살짝 줄여 맞춘다.
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B3643).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildIconBtn(
                          Icons.swap_vert,
                          _isFlippedY ? Colors.redAccent : Colors.white,
                          _toggleFlipY,
                        ),
                        _buildDivider(),
                        _buildIconBtn(
                          Icons.swap_horiz,
                          _isFlippedX ? Colors.redAccent : Colors.white,
                          _toggleFlipX,
                        ),
                        _buildDivider(),
                        _buildIconBtn(
                          Icons.rotate_90_degrees_cw,
                          Colors.white,
                          _rotateCamera,
                        ),
                        _buildDivider(),
                        // 실제 비율로 그리기(모서리를 둥글게, 관 굵기도 그대로).
                        _buildIconBtn(
                          Icons.straighten,
                          _realScale ? makitaTeal : Colors.white,
                          () => setState(() => _realScale = !_realScale),
                        ),
                        _buildDivider(),
                        _buildIconBtn(
                          Icons.remove_circle_outline,
                          Colors.white70,
                          () => setState(
                            () => _zoomLevel = (_zoomLevel - 0.2).clamp(
                              0.2,
                              10.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _buildIconBtn(
                          Icons.add_circle_outline,
                          Colors.white70,
                          () => setState(
                            () => _zoomLevel = (_zoomLevel + 0.2).clamp(
                              0.2,
                              10.0,
                            ),
                          ),
                        ),
                        _buildDivider(),
                        // 잘 보이게 맞춤: 겹침이 가장 적은 방향 + 화면 맞춤(10-17).
                        Semantics(
                          label: '잘 보이게 맞춤',
                          button: true,
                          child: KeyedSubtree(
                            key: const Key('iso_auto_fit'),
                            child: _buildIconBtn(
                              Icons.center_focus_strong,
                              Colors.white,
                              _autoFit,
                            ),
                          ),
                        ),
                        _buildDivider(),
                        _buildIconBtn(Icons.refresh, makitaTeal, _resetView),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // 🚀 좌측 상단: 시작 방향 드롭다운 위젯
  Widget _buildStartDirSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: widget.isLightMode
            ? Colors.white.withValues(alpha: 0.9)
            : const Color(0xFF2B3643).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
        border: Border.all(
          color: widget.isLightMode ? Colors.grey.shade300 : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "시작 방향:",
            style: TextStyle(
              fontSize: 12,
              color: widget.isLightMode ? Colors.black54 : Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _startDir,
              isDense: true,
              dropdownColor: widget.isLightMode
                  ? Colors.white
                  : const Color(0xFF2B3643),
              icon: Icon(
                Icons.arrow_drop_down,
                color: widget.isLightMode ? Colors.black87 : Colors.white,
              ),
              style: TextStyle(
                color: widget.isLightMode ? Colors.black87 : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              items: ['UP', 'DOWN', 'LEFT', 'RIGHT', 'FRONT', 'BACK'].map((
                dir,
              ) {
                return DropdownMenuItem(value: dir, child: Text(dir));
              }).toList(),
              // 🚀 [수정됨] 사용자가 방향을 바꿀 때 무조건 기기에 영구 저장합니다.
              onChanged: (val) async {
                if (val != null) {
                  setState(() => _startDir = val);

                  // 🚀 기기 내부에 저장
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(widget.startDirPrefKey, val);

                  if (widget.onStartDirChanged != null) {
                    widget.onStartDirChanged!(val);
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // 캐드식 치수 고르기: 끔 · 계획 · 실측(계획 + 현장 탭에서 잰 값).
  Widget _buildDimSelector() {
    Widget seg(int v, String label) {
      final on = _mode == v;
      return GestureDetector(
        key: Key('iso_dim_$v'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _setDimMode(v),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: on ? makitaTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: on ? Colors.white : Colors.white70,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 3, 3, 3),
      decoration: BoxDecoration(
        color: const Color(0xFF2B3643).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '치수',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          seg(0, '끔'),
          seg(1, '계획'),
          if (widget.allowMeasureMode) seg(2, '실측'),
        ],
      ),
    );
  }

  String _signed(double v) {
    final r = v.round();
    return r > 0 ? '+$r' : (r < 0 ? '−${-r}' : '0');
  }

  // 왼쪽 위 칸 묶음: 넓으면 한 줄, 좁으면 [시작 방향·치수] 아래 [요약·절단] 한 줄.
  Widget _buildTopBar(double width) {
    final dim = widget.showDimControl && !widget.isLightMode;
    final m2 = dim && _mode == 2;
    final summaryRow = Row(
      children: [
        Flexible(child: _buildMeasureSummary()),
        if (widget.onLegTap != null) ...[
          const SizedBox(width: 8),
          _buildCutMeasureChip(),
        ],
      ],
    );
    if (width >= 700) {
      return Row(
        children: [
          _buildStartDirSelector(),
          if (dim) ...[const SizedBox(width: 8), _buildDimSelector()],
          if (m2) ...[const SizedBox(width: 8), Expanded(child: summaryRow)],
          if (!m2) const Spacer(),
          if (widget.totalCutLength > 0) ...[
            const SizedBox(width: 8),
            _buildTotalCutBadge(),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStartDirSelector(),
            if (dim) _buildDimSelector(),
            if (widget.totalCutLength > 0) _buildTotalCutBadge(),
          ],
        ),
        if (m2) ...[const SizedBox(height: 8), summaryRow],
      ],
    );
  }

  // 실측 요약: 잰 구간 수 · 불합격 수 · 절단 차이.
  Widget _buildMeasureSummary() {
    final diffs = widget.measuredDiff.values.toList();
    final fails = diffs.where((d) => d.abs() > widget.tolerance + 1e-9).length;
    final cut = widget.cutDiff;
    final cutFail = cut != null && cut.abs() > widget.tolerance + 1e-9;
    final String text =
        diffs.isEmpty && cut == null && widget.measuredAngle.isEmpty
        ? (widget.onLegTap != null
              ? '치수·꺾이는 점을 누르면 실측 넣기'
              : '실측 없음 · 현장 탭 [실측]에서 넣습니다')
        : [
            // 10-17 폰 확인: 길게 쓰면 좁은 폰에서 …로 잘려 각도 결과가 안 보였다 → 짧게.
            if (diffs.isNotEmpty)
              '길이 ${diffs.length} ${fails == 0 ? '합격' : '불합격 $fails'}',
            if (widget.measuredAngle.isNotEmpty)
              '각도 ${widget.measuredAngle.length} ${_angleFailText()}',
            if (diffs.isEmpty &&
                widget.measuredAngle.isEmpty &&
                cut != null &&
                widget.onLegTap != null)
              '길이·각도 없음',
            if (cut != null && widget.onLegTap == null) '절단 ${_signed(cut)}',
          ].join(' · ');
    final angles = widget.measuredAngle;
    final angleFails = angles.entries.where((e) {
      final design = _designAngle(e.key);
      return design != null &&
          (e.value - design).abs() > widget.angleTolerance + 1e-9;
    }).length;
    final bad = fails > 0 || cutFail || angleFails > 0;
    return Container(
      key: const Key('iso_measure_summary'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF2B3643).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(
            color: diffs.isEmpty && cut == null
                ? Colors.white38
                : (bad ? _kDimFail : _kDimPass),
            width: 4,
          ),
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12.5,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  double? _designAngle(int row) {
    if (row < 0 || row >= widget.bendList.length) return null;
    return (widget.bendList[row]['angle'] as num?)?.toDouble();
  }

  String _angleFailText() {
    final n = widget.measuredAngle.entries.where((e) {
      final design = _designAngle(e.key);
      return design != null &&
          (e.value - design).abs() > widget.angleTolerance + 1e-9;
    }).length;
    return n == 0 ? '합격' : '불합격 $n';
  }

  // 누른 배지 하나의 자세한 값: 계획·실측·차이 + [다시 넣기].
  Widget _buildDetailBubble() {
    final d = _detail!;
    final size = _viewSize;
    const w = 230.0;
    final left = (d.at.dx - w / 2).clamp(
      8.0,
      math.max(8.0, size.width - w - 8),
    );
    final below = d.at.dy < size.height / 2;
    final color = d.ok ? _kDimPass : _kDimFail;
    final card = Container(
      key: const Key('iso_measure_detail'),
      width: w,
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  d.title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                d.ok ? '합격' : '불합격',
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${d.plan}  →  ${d.meas}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            d.diff,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                onPressed: () => setState(() => _detail = null),
                child: const Text('닫기'),
              ),
              TextButton(
                key: const Key('iso_measure_detail_edit'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onPressed: () {
                  final edit = d.edit;
                  setState(() => _detail = null);
                  edit();
                },
                child: const Text('다시 넣기'),
              ),
            ],
          ),
        ],
      ),
    );
    return Positioned(
      left: left.toDouble(),
      top: below ? d.at.dy + 18 : null,
      bottom: below ? null : size.height - d.at.dy + 18,
      child: card,
    );
  }

  // 절단 길이 실측(10-17): 벤드로 끝나는 배관은 아이소에 마지막 직관이 없어 누를 곳이 없다.
  Widget _buildCutMeasureChip() {
    final cut = widget.cutDiff;
    final ok = cut != null && cut.abs() <= widget.tolerance + 1e-9;
    return GestureDetector(
      key: const Key('iso_cut_measure'),
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onLegTap?.call(-1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF2B3643).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.content_cut, size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              cut == null ? '절단 넣기' : '절단 ${_signed(cut)}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: cut == null
                    ? Colors.white
                    : (ok ? _kDimPass : _kDimFail),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🚀 우측 상단: 총 컷팅 기장 뱃지 위젯
  Widget _buildTotalCutBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isLightMode
            ? Colors.white.withValues(alpha: 0.9)
            : const Color(0xFF2B3643).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
        border: Border.all(
          color: widget.isLightMode ? Colors.grey.shade300 : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.straighten, size: 14, color: makitaTeal),
          const SizedBox(width: 6),
          Text(
            "총 절단 길이: ",
            style: TextStyle(
              fontSize: 12,
              color: widget.isLightMode ? Colors.black54 : Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "${widget.totalCutLength.round()} mm",
            style: TextStyle(
              fontSize: 13,
              color: widget.isLightMode
                  ? Colors.red.shade700
                  : Colors.redAccent,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 20,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: Colors.white24,
    );
  }
}

// =========================================================
// 🚀 아래부터는 태블릿과 충돌하지 않도록 이름이 변경된 렌더링 클래스들
// =========================================================

/// 아이소에 그린 치수 하나의 자리(누른 곳 찾기용).
class IsoDimHit {
  /// 구간이 끝나는 벤드 줄(마지막 직관은 -1).
  final int row;

  /// 구간 번호(그 구간이 끝나는 벤드 번호, 마지막 직관은 0)·계획 길이.
  final int number;
  final double plan;

  /// 관 위 두 꼭짓점·치수선 두 끝·글 칸(화면 좌표).
  final Offset a, b, da, db;
  final Rect box;
  const IsoDimHit({
    required this.row,
    this.number = 0,
    this.plan = 0,
    required this.a,
    required this.b,
    required this.da,
    required this.db,
    required this.box,
  });
}

/// 아이소에 그린 꺾이는 점 하나(각도 실측 누르기용).
class IsoBendHit {
  final int row;
  final Offset at;
  final Rect box;

  /// 벤드 번호·설계 각도.
  final int number;
  final double design;
  const IsoBendHit({
    required this.row,
    required this.at,
    required this.box,
    this.number = 0,
    this.design = 0,
  });
}

abstract class MobileRenderable {
  double get z;
  void draw(
    Canvas canvas,
    Paint pipePaint,
    Paint highlightPaint,
    Paint outlinePaint,
  );
}

/// 관 끝에 끼우는 피팅.
///
/// 🚀 [고침] 예전에는 굵기·길이를 못 박아 놓고 끝을 둥글게 그려서, 실제
/// 비율로 볼 때 관보다 뭉툭한 덩어리가 붙은 것처럼 보였다. 관 굵기에 맞춰
/// 몸통과 너트를 나눠 그리고, 끝을 각지게 잘라 실제 피팅처럼 보이게 한다.
class MobileFittingRenderable implements MobileRenderable {
  /// p1은 관 끝, p2는 피팅이 관을 무는 안쪽 끝.
  final Offset p1, p2;
  @override
  final double z;
  final bool isLightMode;

  /// 이 화면에서 관을 그리는 굵기(픽셀). 피팅은 관보다 굵다.
  final double pipeWidth;

  MobileFittingRenderable(
    this.p1,
    this.p2,
    this.z, {
    this.isLightMode = false,
    this.pipeWidth = 6.0,
  });

  @override
  void draw(
    Canvas canvas,
    Paint pipePaint,
    Paint highlightPaint,
    Paint outlinePaint,
  ) {
    // 몸통은 관보다 조금 굵고, 너트는 그보다 더 굵다.
    final double body = (pipeWidth * 1.5).clamp(6.0, 60.0);
    final double nut = (pipeWidth * 2.0).clamp(8.0, 72.0);

    Paint stroke(double w, Color c) => Paint()
      ..color = c
      ..strokeWidth = w
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    final Color edge = isLightMode ? Colors.black87 : Colors.black54;
    final Color metal = isLightMode
        ? Colors.blueGrey.shade300
        : const Color(0xFF90A4AE);
    final Color metalLight = isLightMode
        ? Colors.blueGrey.shade200
        : const Color(0xFFB0BEC5);

    // 몸통.
    canvas.drawLine(p1, p2, stroke(body + 2.0, edge));
    canvas.drawLine(p1, p2, stroke(body, metal));

    // 너트: 관 끝에서 조금 들어간 자리에 짧게 두른다.
    final d = p2 - p1;
    final a = p1 + d * 0.18;
    final b = p1 + d * 0.52;
    canvas.drawLine(a, b, stroke(nut + 2.0, edge));
    canvas.drawLine(a, b, stroke(nut, metalLight));
  }
}

/// 이어진 여러 토막(벤드가 휘는 호)을 한 붓으로 그린다.
///
/// 🚀 [고침] 호를 토막마다 따로 그렸더니, 토막을 그릴 때마다 검은 테두리를
/// 다시 칠해서 앞 토막의 관 색을 덮었다. 이음새가 얼룩덜룩해지고 휜 자리가
/// 뭉개져서 각지게 꺾인 것처럼 보였다. 테두리를 먼저 한 번, 관을 그 위에
/// 한 번 그린다.
class MobilePolylineRenderable implements MobileRenderable {
  final List<Offset> pts;
  @override
  final double z;
  final bool isSelected;

  MobilePolylineRenderable(this.pts, this.z, {this.isSelected = false});

  @override
  void draw(
    Canvas canvas,
    Paint pipePaint,
    Paint highlightPaint,
    Paint outlinePaint,
  ) {
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, outlinePaint);
    canvas.drawPath(path, isSelected ? highlightPaint : pipePaint);
    drawCenterLine(canvas, path, pipePaint);
  }
}

/// 관 한가운데에 긋는 가는 선(중심선).
///
/// 🚀 [고침] 관을 바깥지름대로 굵게 그리면, 반경이 관 굵기의 서너 배밖에
/// 안 되는 튜브에서는 휘는 자리가 굵기에 묻혀 각지게 꺾인 것처럼 보였다
/// (3/8" 튜브 R38이면 호가 부푸는 양이 11mm라 관 굵기 12.7mm와 비슷하다).
/// 관 굵기는 실제대로 두고, 가운데에 가는 선을 하나 더 그어 휜 모양이
/// 드러나게 한다. 배관 도면에서 중심선을 긋는 것과 같다.
void drawCenterLine(Canvas canvas, Path path, Paint pipePaint) {
  final w = pipePaint.strokeWidth;
  if (w < 8.0) return; // 가는 관에는 중심선이 오히려 지저분하다.
  canvas.drawPath(
    path,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = (w * 0.16).clamp(1.0, 3.0)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
}

class MobileSegmentRenderable implements MobileRenderable {
  final Offset p1, p2;
  @override
  final double z;
  final bool isSelected;
  final bool isLightMode;

  /// 호를 잘게 나눠 그릴 때는 토막마다 화살표를 찍지 않는다.
  final bool showArrow;

  MobileSegmentRenderable(
    this.p1,
    this.p2,
    this.z, {
    this.isSelected = false,
    this.isLightMode = false,
    this.showArrow = true,
  });

  @override
  void draw(
    Canvas canvas,
    Paint pipePaint,
    Paint highlightPaint,
    Paint outlinePaint,
  ) {
    double sf = isLightMode ? 1.2 : 1.0;
    canvas.drawLine(p1, p2, outlinePaint);
    canvas.drawLine(p1, p2, isSelected ? highlightPaint : pipePaint);
    drawCenterLine(
      canvas,
      Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy),
      pipePaint,
    );

    double dx = p2.dx - p1.dx;
    double dy = p2.dy - p1.dy;
    double length = math.sqrt(dx * dx + dy * dy);

    if (showArrow && length > 15 * sf) {
      double arrowSize = 6.0 * sf;
      double lineAngle = math.atan2(dy, dx);
      Offset mid = Offset(p1.dx + dx * 0.55, p1.dy + dy * 0.55);

      Offset arrowP1 = Offset(
        mid.dx - arrowSize * math.cos(lineAngle - math.pi / 6),
        mid.dy - arrowSize * math.sin(lineAngle - math.pi / 6),
      );
      Offset arrowP2 = Offset(
        mid.dx - arrowSize * math.cos(lineAngle + math.pi / 6),
        mid.dy - arrowSize * math.sin(lineAngle + math.pi / 6),
      );

      Path arrowPath = Path()
        ..moveTo(mid.dx, mid.dy)
        ..lineTo(arrowP1.dx, arrowP1.dy)
        ..lineTo(arrowP2.dx, arrowP2.dy)
        ..close();
      Paint arrowPaint = Paint()
        ..color = isLightMode
            ? (isSelected ? Colors.black : Colors.black87)
            : (isSelected ? Colors.white : Colors.white.withValues(alpha: 0.8))
        ..style = PaintingStyle.fill;

      canvas.drawPath(arrowPath, arrowPaint);
    }
  }
}

class MobileDashedLineRenderable implements MobileRenderable {
  final Offset p1, p2;
  @override
  final double z;
  final bool isLightMode;

  MobileDashedLineRenderable(
    this.p1,
    this.p2,
    this.z, {
    this.isLightMode = false,
  });

  @override
  void draw(
    Canvas canvas,
    Paint pipePaint,
    Paint highlightPaint,
    Paint outlinePaint,
  ) {
    double sf = isLightMode ? 1.2 : 1.0;
    final dashPaint = Paint()
      ..color = isLightMode
          ? Colors.orange.shade800
          : Colors.amberAccent.withValues(alpha: 0.9)
      ..strokeWidth = 2.5 * sf
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    double dx = p2.dx - p1.dx;
    double dy = p2.dy - p1.dy;
    double distance = math.sqrt(dx * dx + dy * dy);

    if (distance <= 0) return;

    double dashWidth = 10.0 * sf;
    double dashSpace = 8.0 * sf;
    double unitDx = dx / distance;
    double unitDy = dy / distance;
    double startX = p1.dx;
    double startY = p1.dy;
    double drawn = 0.0;

    while (drawn < distance) {
      double nextDraw = math.min(dashWidth, distance - drawn);
      double endX = startX + unitDx * nextDraw;
      double endY = startY + unitDy * nextDraw;
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), dashPaint);
      drawn += nextDraw + dashSpace;
      startX = endX + unitDx * dashSpace;
      startY = endY + unitDy * dashSpace;
    }

    double arrowSize = 8.0 * sf;
    double lineAngle = math.atan2(dy, dx);
    Offset arrowP1 = Offset(
      p2.dx - arrowSize * math.cos(lineAngle - math.pi / 6),
      p2.dy - arrowSize * math.sin(lineAngle - math.pi / 6),
    );
    Offset arrowP2 = Offset(
      p2.dx - arrowSize * math.cos(lineAngle + math.pi / 6),
      p2.dy - arrowSize * math.sin(lineAngle + math.pi / 6),
    );

    Path arrowPath = Path()
      ..moveTo(p2.dx, p2.dy)
      ..lineTo(arrowP1.dx, arrowP1.dy)
      ..lineTo(arrowP2.dx, arrowP2.dy)
      ..close();
    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = isLightMode ? Colors.orange.shade800 : Colors.amberAccent
        ..style = PaintingStyle.fill,
    );
  }
}

class MobileLabelRenderable implements MobileRenderable {
  final Offset centerPos;
  @override
  final double z;
  final String text;
  final bool isStraightPipe;
  final bool isSelected;
  final bool isLightMode;
  final bool isStartLabel;

  MobileLabelRenderable(
    this.centerPos,
    this.z,
    this.text, {
    this.isStraightPipe = false,
    this.isSelected = false,
    this.isLightMode = false,
    this.isStartLabel = false,
  });

  @override
  void draw(
    Canvas canvas,
    Paint pipePaint,
    Paint highlightPaint,
    Paint outlinePaint,
  ) {
    double sf = isLightMode ? 1.2 : 1.0;

    Color textColor = isStartLabel
        ? (isLightMode ? Colors.red.shade800 : Colors.redAccent)
        : (isStraightPipe
              ? (isLightMode ? Colors.black87 : Colors.white70)
              : (isLightMode ? Colors.black : Colors.white));
    double baseFontSize = isStartLabel
        ? 12.0
        : (isStraightPipe ? 11.0 : (isSelected ? 20.0 : 16.0));
    double fontSize = baseFontSize * sf;

    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: kAppFontFamily,
        color: textColor,
        fontSize: fontSize,
        fontWeight: isStartLabel
            ? FontWeight.w900
            : (isStraightPipe ? FontWeight.bold : FontWeight.w900),
        letterSpacing: isStartLabel ? 1.0 * sf : 0.0,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    Offset drawPos = Offset(
      centerPos.dx - (textPainter.width / 2),
      centerPos.dy - (textPainter.height / 2),
    );
    double padX = (isStraightPipe ? 4.0 : 8.0) * sf;
    double padY = (isStraightPipe ? 2.0 : 4.0) * sf;
    final rect = Rect.fromLTWH(
      drawPos.dx - padX,
      drawPos.dy - padY,
      textPainter.width + padX * 2,
      textPainter.height + padY * 2,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular((isStraightPipe ? 4.0 : 8.0) * sf),
    );

    Color bgColor = isStartLabel
        ? (isLightMode
              ? Colors.white.withValues(alpha: 0.8)
              : const Color(0xFF151B22).withValues(alpha: 0.8))
        : (isStraightPipe
              ? (isLightMode
                    ? Colors.white70
                    : Colors.grey.shade800.withValues(alpha: 0.7))
              : (isSelected
                    ? Colors.orange.shade400
                    : (isLightMode
                          ? Colors.white
                          : const Color(0xFF151B22).withValues(alpha: 0.95))));
    Color borderColor = isStartLabel
        ? (isLightMode
              ? Colors.red.shade200
              : Colors.red.shade900.withValues(alpha: 0.5))
        : (isStraightPipe
              ? Colors.grey.shade600
              : (isSelected
                    ? Colors.orange.shade800
                    : (isLightMode ? Colors.black54 : Colors.grey.shade600)));

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = (isStraightPipe ? 1.0 : 1.5) * sf,
    );
    textPainter.paint(canvas, drawPos);
  }
}

class MobileIsoPipePainter extends CustomPainter {
  final List<Map<String, dynamic>> bendList;
  final double tailLength;
  final double rotationX;
  final double rotationY;
  final double zoomLevel;
  final double panX;
  final double panY;
  final bool isFlippedX;
  final bool isFlippedY;
  final String startDirection;
  final int? selectedSegmentIndex;
  final bool isLightMode;
  final bool startFit;
  final bool endFit;

  /// 실제 비율로 그릴지.
  final bool realScale;
  final double bendRadius;
  final double outerDiameter;
  final double fittingDepth;

  /// 캐드식 치수: 0 끔 · 1 계획 · 2 계획+실측.
  final int dimMode;
  final Map<int, double> measuredDiff;
  final double tolerance;

  /// 그린 치수 자리를 여기에 적어 준다(누른 곳 찾기용, 없으면 안 적음).
  final List<IsoDimHit>? hits;
  final List<IsoBendHit>? bendHits;
  final Map<int, double> measuredAngle;
  final double angleTolerance;

  /// 위쪽 단추가 덮는 높이(치수 글을 그 아래에만 놓는다).
  final double topInset;

  /// 아래 단추 줄이 덮는 높이.
  final double bottomInset;

  MobileIsoPipePainter({
    required this.bendList,
    this.tailLength = 0.0,
    required this.rotationX,
    required this.rotationY,
    required this.zoomLevel,
    required this.panX,
    required this.panY,
    required this.isFlippedX,
    required this.isFlippedY,
    required this.startDirection,
    this.selectedSegmentIndex,
    required this.isLightMode,
    required this.startFit,
    required this.endFit,
    this.realScale = false,
    this.bendRadius = 0.0,
    this.outerDiameter = 0.0,
    this.fittingDepth = 0.0,
    this.dimMode = 0,
    this.measuredDiff = const {},
    this.tolerance = 2.0,
    this.hits,
    this.bendHits,
    this.measuredAngle = const {},
    this.angleTolerance = 1.0,
    this.topInset = 0,
    this.bottomInset = 0,
  });

  double _getVisualLength(double realLength) {
    if (realLength <= 0) return 0.0;
    return 40.0 + math.pow(realLength, 0.5) * 6.0;
  }

  void _drawBlueprintGrid(Canvas canvas, Size size, double sf) {
    final minorPaint = Paint()
      ..color = isLightMode ? Colors.grey.shade200 : const Color(0xFF202A36)
      ..strokeWidth = 1.0 * sf;
    final majorPaint = Paint()
      ..color = isLightMode ? Colors.grey.shade300 : const Color(0xFF2C3948)
      ..strokeWidth = 1.5 * sf;
    double step = 30.0 * sf;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        i % (step * 5) == 0 ? majorPaint : minorPaint,
      );
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        i % (step * 5) == 0 ? majorPaint : minorPaint,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    double sf = isLightMode ? 1.2 : 1.0;
    _drawBlueprintGrid(canvas, size, sf);

    // 🚀 [고침] 이 그림은 공간 걷기를 따로 한 벌 들고 있었다. 마킹 값과
    // 같은 계산(pipePathPoints)을 쓰도록 바꿨다. 꺾을 수 없는 방향
    // (진행 방향과 나란하거나 정반대)일 때 아무 평면이나 골라 꺾어서,
    // 만들 수 없는 형상을 만들 수 있는 것처럼 그려 주던 것도 없앴다.
    // 🚀 [고침] "실제 비율"을 켜면 길이를 있는 그대로 쓰고 모서리를 반경만큼
    // 둥근 호로 그린다. 끄면 예전처럼 짧은 구간도 보이게 줄여 그린다.
    final drawPath = pipeDrawPath(
      bendList,
      startDir: startDirection,
      radius: realScale ? bendRadius : 0.0,
      tail: tailLength,
      visualLength: realScale ? null : _getVisualLength,
    );
    final List<vmath.Vector3> pts3D = drawPath.points;
    final List<int> segOwner = drawPath.owner;

    List<int> internalMarkNums = [];
    int currentMarkNum = 1;
    for (int i = 0; i < bendList.length; i++) {
      double angle = (bendList[i]['angle'] as num?)?.toDouble() ?? 0.0;
      if (angle == 0.0) {
        internalMarkNums.add(0);
      } else {
        internalMarkNums.add(currentMarkNum);
        currentMarkNum++;
      }
    }

    vmath.Vector3 center3D = _calculateCenter(pts3D);
    double maxRadius = _calculateMaxRadius(pts3D, center3D);
    // 10-17: 아이소 탭은 위쪽 칸·아래 단추 줄 사이 빈 곳에 맞춰 그린다(폰 가로에서 칸에 가렸다).
    final double drawTop = topInset;
    final double drawBottom = size.height - bottomInset;
    final bool inset = topInset + bottomInset > 0 && drawBottom - drawTop > 80;
    final double availH = inset ? drawBottom - drawTop : size.height;
    final double centerY = inset ? (drawTop + drawBottom) / 2 : size.height / 2;
    double scale = (math.min(size.width, availH) * 0.4) / maxRadius * zoomLevel;

    vmath.Matrix4 cameraMatrix = vmath.Matrix4.identity()
      ..rotateX(rotationX)
      ..rotateY(rotationY);
    List<vmath.Vector3> projectedPts = [];
    for (var p in pts3D) {
      vmath.Vector3 translated = p - center3D;
      projectedPts.add(cameraMatrix.transformed3(translated));
    }

    Offset to2D(vmath.Vector3 p) {
      double finalX = isFlippedX ? -p.x : p.x;
      double finalY = isFlippedY ? -p.y : p.y;
      return Offset(
        finalX * scale + size.width / 2 + panX,
        -finalY * scale + centerY + panY,
      );
    }

    // 🚀 [고침] 관 굵기를 늘 6픽셀로 그려서, 3/8"든 1"든 같은 굵기로 보였다.
    // "실제 비율"을 켜면 바깥지름대로 그린다(화면에서 너무 가늘거나 굵어지지
    // 않게 3~40픽셀 안으로 둔다).
    final double pipeWidth = (realScale && outerDiameter > 0)
        ? (outerDiameter * scale).clamp(3.0, 40.0)
        : 6.0 * sf;

    List<MobileRenderable> renderQueue = [];
    List<MobileLabelRenderable> labelQueue = [];

    int pipeEndIndex = projectedPts.length - 1;

    // 🚀 [고침] 이어진 호 토막을 한 덩어리로 묶어 한 붓으로 그린다.
    // 토막마다 따로 그리면 검은 테두리가 앞 토막을 덮어 휜 자리가 뭉개졌다.
    int i = 0;
    while (i < pipeEndIndex) {
      final int owner = i < segOwner.length ? segOwner[i] : -1;

      if (owner < 0) {
        // 벤드가 휘는 호: 이어지는 데까지 모아서 한 붓으로.
        int j = i;
        while (j < pipeEndIndex &&
            (j < segOwner.length ? segOwner[j] : -1) < 0) {
          j++;
        }
        final pts = <Offset>[
          for (int k = i; k <= j; k++) to2D(projectedPts[k]),
        ];
        var zSum = 0.0;
        for (int k = i; k <= j; k++) {
          zSum += projectedPts[k].z;
        }
        renderQueue.add(MobilePolylineRenderable(pts, zSum / (j - i + 1)));
        i = j;
        continue;
      }

      final double zAvg = (projectedPts[i].z + projectedPts[i + 1].z) / 2;
      renderQueue.add(
        MobileSegmentRenderable(
          to2D(projectedPts[i]),
          to2D(projectedPts[i + 1]),
          zAvg,
          isSelected: selectedSegmentIndex == owner,
          isLightMode: isLightMode,
        ),
      );
      i++;
    }

    // 🚀 [고침] 예전에는 꼭짓점 사이마다 글자를 달아서, 호를 잘게 나누면
    // 글자가 겹쳤다. 곧은 토막마다 한 번씩만 단다.
    for (final run in drawPath.straightRuns) {
      final idx = run.bendIndex;
      if (idx < 0 || idx >= bendList.length) continue;
      final double realL = (bendList[idx]['length'] as num?)?.toDouble() ?? 0.0;
      if (realL <= 0) continue;
      final double angle = (bendList[idx]['angle'] as num?)?.toDouble() ?? 0.0;
      if (dimMode > 0 && angle == 0.0) continue;
      final int mNum = internalMarkNums[idx];
      final bool isSelected = selectedSegmentIndex == idx;

      final a2 = to2D(cameraMatrix.transformed3(run.a - center3D));
      final b2 = to2D(cameraMatrix.transformed3(run.b - center3D));
      final zAvg =
          (cameraMatrix.transformed3(run.a - center3D).z +
              cameraMatrix.transformed3(run.b - center3D).z) /
          2;

      final mid = (a2 + b2) / 2;
      final dx = b2.dx - a2.dx;
      final dy = b2.dy - a2.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      Offset normal = len > 0
          ? Offset(-dy / len, dx / len)
          : const Offset(0, -1);
      if (normal.dy > 0) normal = Offset(-normal.dx, -normal.dy);
      // 🚀 [고침] 실제 비율로 그리면 짧은 구간의 글자가 서로 겹쳐 못 읽었다.
      // 이미 놓은 글자와 가까우면 바깥쪽으로 더 밀어낸다.
      var labelPos = mid + normal * (18.0 * sf);
      for (var push = 0; push < 6; push++) {
        final tooClose = labelQueue.any(
          (l) => (l.centerPos - labelPos).distance < 34.0 * sf,
        );
        if (!tooClose) break;
        labelPos = labelPos + normal * (20.0 * sf);
      }

      labelQueue.add(
        MobileLabelRenderable(
          labelPos,
          zAvg,
          angle == 0.0 ? "L:${realL.toInt()}" : "$mNum",
          isStraightPipe: angle == 0.0,
          isSelected: isSelected,
          isLightMode: isLightMode,
        ),
      );
    }

    // 🚀 [고침] 피팅 길이를 20(모델 단위)으로 못 박아 놔서, 실제 비율로 보면
    // 관에 비해 우스울 만큼 짧거나 길었다. 실제 비율일 때는 피팅에 관이
    // 들어가는 깊이만큼 그리고, 화면에서 너무 작아지지 않게 아래를 받쳐 둔다.
    final double minOnScreen = 14.0 / scale;
    final double fitVisualLen = (realScale && fittingDepth > 0)
        ? math.max(fittingDepth, minOnScreen)
        : 20.0;
    if (pts3D.length > 1) {
      if (startFit) {
        vmath.Vector3 dir = (pts3D[1] - pts3D[0])..normalize();
        vmath.Vector3 fitEnd =
            pts3D[0] +
            dir * math.min(fitVisualLen, pts3D[0].distanceTo(pts3D[1]));
        vmath.Vector3 projStart = cameraMatrix.transformed3(
          pts3D[0] - center3D,
        );
        vmath.Vector3 projEnd = cameraMatrix.transformed3(fitEnd - center3D);
        renderQueue.add(
          MobileFittingRenderable(
            to2D(projStart),
            to2D(projEnd),
            ((projStart.z + projEnd.z) / 2) - 0.1,
            isLightMode: isLightMode,
            pipeWidth: pipeWidth,
          ),
        );
      }
      if (endFit) {
        int last = pipeEndIndex;
        vmath.Vector3 dir = (pts3D[last - 1] - pts3D[last])..normalize();
        vmath.Vector3 fitEnd =
            pts3D[last] +
            dir *
                math.min(fitVisualLen, pts3D[last].distanceTo(pts3D[last - 1]));
        vmath.Vector3 projStart = cameraMatrix.transformed3(
          pts3D[last] - center3D,
        );
        vmath.Vector3 projEnd = cameraMatrix.transformed3(fitEnd - center3D);
        renderQueue.add(
          MobileFittingRenderable(
            to2D(projStart),
            to2D(projEnd),
            ((projStart.z + projEnd.z) / 2) - 0.1,
            isLightMode: isLightMode,
            pipeWidth: pipeWidth,
          ),
        );
      }
    }

    for (int i = 0; i <= pipeEndIndex; i++) {
      if (i == 0) {
        Offset nodePos = to2D(projectedPts[i]);
        labelQueue.add(
          MobileLabelRenderable(
            nodePos + Offset(0, -30.0 * sf),
            projectedPts[i].z - 0.1,
            "START",
            isStartLabel: true,
            isLightMode: isLightMode,
          ),
        );
      }
    }

    // 끝 방향 화살표: 마지막 두 꼭짓점으로 진행 방향을 잡는다.
    final vmath.Vector3 endPos = pts3D.last;
    vmath.Vector3 endDir = pts3D.length >= 2
        ? (pts3D.last - pts3D[pts3D.length - 2])
        : vmath.Vector3(1, 0, 0);
    if (endDir.length2 < 1e-9) endDir = vmath.Vector3(1, 0, 0);
    endDir = endDir.normalized();

    vmath.Vector3 translatedEnd =
        (endPos + endDir * (150.0 / scale)) - center3D;
    vmath.Vector3 pEndDir = cameraMatrix.transformed3(translatedEnd);
    Offset pEndDir2D = to2D(pEndDir);
    Offset pCurrentPos2D = to2D(projectedPts.last);
    double zAvgDir = (projectedPts.last.z + pEndDir.z) / 2;

    renderQueue.add(
      MobileDashedLineRenderable(
        pCurrentPos2D,
        pEndDir2D,
        zAvgDir,
        isLightMode: isLightMode,
      ),
    );

    renderQueue.sort((a, b) => b.z.compareTo(a.z));
    labelQueue.sort((a, b) => b.z.compareTo(a.z));

    final pipePaint = Paint()
      ..color = isLightMode ? const Color(0xFF455A64) : const Color(0xFF607D8B)
      ..strokeWidth = pipeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final highlightPaint = Paint()
      ..color = Colors.orange.shade500
      ..strokeWidth = pipeWidth + 2.0 * sf
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final outlinePaint = Paint()
      ..color = isLightMode ? Colors.black87 : Colors.black45
      ..strokeWidth = pipeWidth + 2.0 * sf
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _drawAxisGuide(canvas, cameraMatrix, to2D, scale, sf);
    for (var item in renderQueue) {
      item.draw(canvas, pipePaint, highlightPaint, outlinePaint);
    }
    for (var label in labelQueue) {
      label.draw(canvas, pipePaint, highlightPaint, outlinePaint);
    }
    // 치수는 번호 배지 위에 그리고, 글은 배지 자리를 피해 놓는다(10-17 복잡한 배관 시험: 배지에 가렸다).
    if (dimMode > 0) {
      _drawCadDims(
        canvas,
        drawPath.corners,
        (vmath.Vector3 w) => to2D(cameraMatrix.transformed3(w - center3D)),
        scale,
        size,
        avoid: [
          for (final l in labelQueue)
            Rect.fromCenter(
              center: l.centerPos,
              width: 38 * sf,
              height: 32 * sf,
            ),
        ],
      );
    }
  }

  // ── 캐드식 치수(10-17) ──
  // 배치도 캐드식 치수처럼: 관에서 조금 떨어진 보조선 두 줄 + 화살표 치수선 + 글.
  // 치수는 꺾이는 점(꼭짓점)에서 다음 꺾이는 점까지(현장 탭 실측과 같은 구간).
  // 보조선은 구간과 직각인 X·Y·Z 축 가운데 화면에서 바깥쪽을 향하는 축을 따른다(아이소 도면 방식).
  void _drawCadDims(
    Canvas canvas,
    List<vmath.Vector3> corners,
    Offset Function(vmath.Vector3) P,
    double scale,
    Size size, {
    List<Rect> avoid = const [],
  }) {
    hits?.clear();
    bendHits?.clear();
    if (corners.length < 2) return;
    // 구간 묶기: 앞 벤드(처음은 관 끝)부터 이 벤드까지. 사이 직관 줄은 한 구간으로.
    final legs = <({int from, int to, double plan, int row})>[];
    var from = 0;
    var sum = 0.0;
    for (var i = 0; i < bendList.length && i + 1 < corners.length; i++) {
      final len = (bendList[i]['length'] as num?)?.toDouble() ?? 0.0;
      final ang = (bendList[i]['angle'] as num?)?.toDouble() ?? 0.0;
      sum += len;
      if (ang > 0) {
        legs.add((from: from, to: i + 1, plan: sum, row: i));
        from = i + 1;
        sum = 0.0;
      }
    }
    final lastCorner = math.min(bendList.length, corners.length - 1);
    if (sum > 0.01 && lastCorner > from) {
      legs.add((from: from, to: lastCorner, plan: sum, row: -1));
    }

    final centre = P(_calculateCenter(corners));
    final placed = <Rect>[...avoid];
    final linePaint = Paint()
      ..color = _kDimLine
      ..strokeWidth = 1.2;
    final extPaint = Paint()
      ..color = _kDimLine.withValues(alpha: 0.75)
      ..strokeWidth = 1.0;

    for (final leg in legs) {
      final a3 = corners[leg.from], b3 = corners[leg.to];
      final d3 = b3 - a3;
      if (d3.length2 < 1e-9) continue;
      final dn = d3.normalized();
      final a2 = P(a3), b2 = P(b3);
      final seg2 = b2 - a2;
      final segLen = seg2.distance;
      if (segLen < 6) continue;
      final segN = seg2 / segLen;
      final mid = (a2 + b2) / 2;
      var outward = mid - centre;
      outward = outward.distance < 1
          ? Offset(-segN.dy, segN.dx)
          : outward / outward.distance;

      // 보조선 방향: 구간과 직각인 축 가운데 화면에서 바깥쪽·치수선과 덜 나란한 것.
      // 보조선 방향 후보: 구간과 직각인 축(화면 바깥쪽·치수선과 덜 나란한 순).
      final cands = <({Offset u, double score})>[];
      for (final ax in [
        vmath.Vector3(1, 0, 0),
        vmath.Vector3(0, 1, 0),
        vmath.Vector3(0, 0, 1),
      ]) {
        final pv = ax - dn * ax.dot(dn);
        if (pv.length < 0.5) continue;
        pv.normalize();
        for (final sgn in [1.0, -1.0]) {
          final raw = P(a3 + pv * (sgn / scale * 40)) - a2;
          final rl = raw.distance;
          if (rl < 12) continue; // 화면에서 거의 점으로 보이는 축
          final u = raw / rl;
          final cross = (u.dx * segN.dy - u.dy * segN.dx).abs();
          if (cross < 0.35) continue; // 치수선과 거의 나란함
          cands.add((
            u: u,
            score: u.dx * outward.dx + u.dy * outward.dy + 0.3 * cross,
          ));
        }
      }
      if (cands.isEmpty) {
        final n = Offset(-segN.dy, segN.dx);
        final out = (n.dx * outward.dx + n.dy * outward.dy) >= 0 ? n : -n;
        cands.add((u: out, score: 1));
        cands.add((u: -out, score: 0));
      }
      cands.sort((x, y) => y.score.compareTo(x.score));

      final planText = '${leg.plan.round()}';
      final diff = leg.row >= 0 ? measuredDiff[leg.row] : null;
      final showMeasured = dimMode == 2 && diff != null;
      // 10-17: 실측 보기는 짧은 배지(+3)만 — 누르면 말풍선에 실측 값(빽빽함 줄이기).
      final measText = showMeasured ? _signedDim(diff) : null;

      // 자리 잡기: 앞 치수·번호 배지와 안 겹치고 화면 안에 드는 곳.
      // 바깥쪽이 화면 밖이면(돌려서 형상이 가장자리에 붙을 때) 다른 축·반대쪽을 쓴다.
      final view = Rect.fromLTRB(
        4,
        math.max(4.0, topInset),
        size.width - 4,
        size.height - math.max(4.0, bottomInset),
      );
      bool inside(Rect r) =>
          r.left >= view.left &&
          r.top >= view.top &&
          r.right <= view.right &&
          r.bottom <= view.bottom;
      // 글 칸: 치수선 방향으로 돌린 글의 바깥 네모(짧은 구간의 긴 실측 글이 화면 끝에서 잘렸다).
      double textW(String t, double size) =>
          (TextPainter(
            text: TextSpan(
              text: t,
              style: TextStyle(
                fontFamily: kAppFontFamily,
                fontSize: size,
                fontWeight: FontWeight.w800,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout()).width +
          8;
      final tw = math.max(
        textW(planText, 13),
        measText == null ? 0.0 : textW(measText, 12),
      );
      final th = showMeasured ? 34.0 : 18.0;
      final ca = segN.dx.abs(), sa = segN.dy.abs();
      final bw = tw * ca + th * sa, bh = tw * sa + th * ca;
      Rect boxAt(Offset u, double dist) => Rect.fromCenter(
        center: mid + u * (dist + (showMeasured ? 16 : 9)),
        width: bw,
        height: bh,
      );
      ({Offset u, double dist})? pick;
      ({Offset u, double dist})? fallback;
      for (final c in cands) {
        var dist = 30.0;
        for (var tier = 0; tier < 5; tier++) {
          final r = boxAt(c.u, dist);
          final free = !placed.any((q) => q.overlaps(r));
          if (inside(r)) {
            fallback ??= (u: c.u, dist: dist);
            if (free) {
              pick = (u: c.u, dist: dist);
              break;
            }
          }
          dist += 26;
        }
        if (pick != null) break;
      }
      final chosen = pick ?? fallback ?? (u: cands.first.u, dist: 30.0);
      final u = chosen.u;
      final dist = chosen.dist;
      final box = boxAt(u, dist);
      placed.add(box);

      final pa = a2 + u * dist, pb = b2 + u * dist;
      hits?.add(
        IsoDimHit(
          row: leg.row,
          number: leg.row >= 0 ? legs.indexOf(leg) + 1 : 0,
          plan: leg.plan,
          a: a2,
          b: b2,
          da: pa,
          db: pb,
          box: box,
        ),
      );
      canvas.drawLine(a2 + u * 5, pa + u * 5, extPaint);
      canvas.drawLine(b2 + u * 5, pb + u * 5, extPaint);
      canvas.drawLine(pa, pb, linePaint);
      _dimArrow(canvas, pa, segN);
      _dimArrow(canvas, pb, -segN);

      var ang = math.atan2(segN.dy, segN.dx);
      if (ang > math.pi / 2) ang -= math.pi;
      if (ang < -math.pi / 2) ang += math.pi;
      // 계획 값은 치수선 바로 바깥, 실측은 그 바깥(관 쪽 번호 배지에 안 가리게).
      _dimText(canvas, planText, mid + u * (dist + 9), ang, Colors.white, 13);
      if (measText != null) {
        final ok = diff!.abs() <= tolerance + 1e-9;
        _badge(canvas, measText, mid + u * (dist + 25), ok);
      }
    }
    if (dimMode == 2) _drawBendAngles(canvas, corners, P, placed, size);
  }

  // 꺾이는 점마다 각도(실측 보기): 잰 각도는 "91° (+1°)" 초록·빨강, 안 잰 것은 흐린 설계 각도.
  // 형상 바깥쪽으로 떼어 놓고, 앞에 놓은 글과 겹치면 더 바깥으로.
  void _drawBendAngles(
    Canvas canvas,
    List<vmath.Vector3> corners,
    Offset Function(vmath.Vector3) P,
    List<Rect> placed,
    Size size,
  ) {
    final centre = P(_calculateCenter(corners));
    final view = Rect.fromLTRB(
      4,
      math.max(4.0, topInset),
      size.width - 4,
      size.height - math.max(4.0, bottomInset),
    );
    bool inside(Rect r) =>
        r.left >= view.left &&
        r.top >= view.top &&
        r.right <= view.right &&
        r.bottom <= view.bottom;
    var bendNo = 0;
    for (var i = 0; i < bendList.length && i + 1 < corners.length; i++) {
      final design = (bendList[i]['angle'] as num?)?.toDouble() ?? 0.0;
      if (design <= 0) continue;
      bendNo++;
      final c2 = P(corners[i + 1]);
      var out = c2 - centre;
      out = out.distance < 1 ? const Offset(0, -1) : out / out.distance;
      final meas = measuredAngle[i];
      String f(double v) =>
          v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
      final String text;
      final Color color;
      if (meas == null) {
        text = '${f(design)}°';
        color = Colors.white38;
      } else {
        final d = ((meas - design) * 10).round() / 10;
        text = '${d > 0 ? '+' : (d < 0 ? '−' : '')}${f(d.abs())}°';
        color = d.abs() <= angleTolerance + 1e-9 ? _kDimPass : _kDimFail;
      }
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: kAppFontFamily,
            color: color,
            fontSize: meas == null ? 11 : 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // 바깥쪽으로 밀어 보고, 안 되면 반대쪽·옆쪽도 본다.
      Rect boxAt(Offset dir, double dist) => Rect.fromCenter(
        center: c2 + dir * (dist + tp.width / 2 * dir.dx.abs()),
        width: tp.width + 8,
        height: tp.height + 4,
      );
      Rect? box;
      Rect? fallback;
      for (final dir in [
        out,
        Offset(-out.dy, out.dx),
        Offset(out.dy, -out.dx),
        -out,
      ]) {
        var dist = 22.0;
        for (var tier = 0; tier < 6; tier++) {
          final r = boxAt(dir, dist);
          if (inside(r)) {
            fallback ??= r;
            if (!placed.any((q) => q.overlaps(r))) {
              box = r;
              break;
            }
          }
          dist += 16;
        }
        if (box != null) break;
      }
      box ??= fallback ?? boxAt(out, 22);
      placed.add(box);
      // 꺾이는 점에서 떨어졌으면 가는 선으로 잇는다(어느 점 각도인지 보이게).
      final edge = Offset(
        c2.dx.clamp(box.left, box.right),
        c2.dy.clamp(box.top, box.bottom),
      );
      if ((edge - c2).distance > 14) {
        canvas.drawLine(
          c2,
          edge,
          Paint()
            ..color = color.withValues(alpha: 0.7)
            ..strokeWidth = 1,
        );
        canvas.drawCircle(c2, 2.5, Paint()..color = color);
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(3)),
        Paint()..color = const Color(0xFF151B22).withValues(alpha: 0.85),
      );
      if (meas != null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(3)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = color.withValues(alpha: 0.6),
        );
      }
      tp.paint(canvas, box.center - Offset(tp.width / 2, tp.height / 2));
      bendHits?.add(
        IsoBendHit(row: i, at: c2, box: box, number: bendNo, design: design),
      );
    }
  }

  /// 실측 차이 배지(초록·빨강 바탕, 똑바로 세운 글).
  void _badge(Canvas canvas, String text, Offset at, bool ok) {
    final color = ok ? _kDimPass : _kDimFail;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: kAppFontFamily,
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: at, width: tp.width + 10, height: tp.height + 4),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      r,
      Paint()..color = Color.lerp(const Color(0xFF151B22), color, 0.18)!,
    );
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.7),
    );
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  String _signedDim(double v) {
    final r = v.round();
    return r > 0 ? '+$r' : (r < 0 ? '−${-r}' : '0');
  }

  void _dimArrow(Canvas canvas, Offset tip, Offset dirInward) {
    final n = Offset(-dirInward.dy, dirInward.dx);
    final base = tip + dirInward * 8;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(base.dx + n.dx * 3, base.dy + n.dy * 3)
        ..lineTo(base.dx - n.dx * 3, base.dy - n.dy * 3)
        ..close(),
      Paint()..color = _kDimLine,
    );
  }

  void _dimText(
    Canvas canvas,
    String text,
    Offset at,
    double angle,
    Color color,
    double size,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: kAppFontFamily,
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    final r = Rect.fromCenter(
      center: Offset.zero,
      width: tp.width + 6,
      height: tp.height,
    );
    canvas.drawRect(
      r,
      Paint()..color = const Color(0xFF151B22).withValues(alpha: 0.85),
    );
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  vmath.Vector3 _calculateCenter(List<vmath.Vector3> pts) {
    double minX = double.infinity,
        maxX = -double.infinity,
        minY = double.infinity,
        maxY = -double.infinity,
        minZ = double.infinity,
        maxZ = -double.infinity;
    for (var p in pts) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
      if (p.z < minZ) minZ = p.z;
      if (p.z > maxZ) maxZ = p.z;
    }
    return vmath.Vector3(
      (minX + maxX) / 2,
      (minY + maxY) / 2,
      (minZ + maxZ) / 2,
    );
  }

  double _calculateMaxRadius(List<vmath.Vector3> pts, vmath.Vector3 center) {
    double maxRadius = 10.0;
    for (var p in pts) {
      double dist = p.distanceTo(center);
      if (dist > maxRadius) maxRadius = dist;
    }
    return maxRadius;
  }

  void _drawAxisGuide(
    Canvas canvas,
    vmath.Matrix4 camMatrix,
    Offset Function(vmath.Vector3) to2D,
    double scale,
    double sf,
  ) {
    double axLen = (40.0 / scale) * sf;
    List<vmath.Vector3> axes = [
      vmath.Vector3(axLen, 0, 0),
      vmath.Vector3(0, axLen, 0),
      vmath.Vector3(0, 0, axLen),
    ];
    List<Color> axColors = [
      const Color(0xFF81C784),
      const Color(0xFFE57373),
      const Color(0xFF64B5F6),
    ];
    vmath.Vector3 originCenter = vmath.Vector3(-axLen * 2, -axLen * 2, 0);
    vmath.Vector3 projOrigin = camMatrix.transformed3(originCenter);
    for (int i = 0; i < 3; i++) {
      vmath.Vector3 endDir = camMatrix.transformed3(originCenter + axes[i]);
      canvas.drawLine(
        to2D(projOrigin),
        to2D(endDir),
        Paint()
          ..color = axColors[i].withValues(alpha: 0.8)
          ..strokeWidth = 2.0 * sf,
      );
    }
  }

  // 🚀 [버그 수정] bendList는 MobileBendDataManager가 in-place로
  // add/removeAt/insert/원소 교체하는 같은 List라서, 참조 비교(!=)로는
  // 벤딩을 추가/삭제/순서변경/수정해도 "안 바뀜"으로 판정돼 3D 배관
  // 형상이 예전 상태 그대로 멈춰 있었다(사용자가 겪은 "형상이 망가짐"의
  // 실제 원인 — 값이 틀린 게 아니라 화면이 최신 데이터를 안 그린 것).
  // 길이 + 각 원소(맵) 참조를 순서대로 비교해 실제 변경만 감지한다.
  bool _bendListChanged(
    List<Map<String, dynamic>> oldList,
    List<Map<String, dynamic>> newList,
  ) {
    if (oldList.length != newList.length) return true;
    for (int i = 0; i < newList.length; i++) {
      if (oldList[i] != newList[i]) return true;
    }
    return false;
  }

  @override
  bool shouldRepaint(covariant MobileIsoPipePainter oldDelegate) {
    return oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.panX != panX ||
        oldDelegate.panY != panY ||
        _bendListChanged(oldDelegate.bendList, bendList) ||
        oldDelegate.isFlippedX != isFlippedX ||
        oldDelegate.isFlippedY != isFlippedY ||
        oldDelegate.startDirection != startDirection ||
        oldDelegate.selectedSegmentIndex != selectedSegmentIndex ||
        oldDelegate.isLightMode != isLightMode ||
        oldDelegate.startFit != startFit ||
        oldDelegate.endFit != endFit ||
        // 🚀 [고침] 실제 비율·반경·굵기가 바뀌어도 다시 그리지 않아서,
        // 자 단추를 눌러도 그림이 그대로일 때가 있었다.
        oldDelegate.realScale != realScale ||
        oldDelegate.bendRadius != bendRadius ||
        oldDelegate.outerDiameter != outerDiameter ||
        oldDelegate.fittingDepth != fittingDepth ||
        oldDelegate.dimMode != dimMode ||
        oldDelegate.tolerance != tolerance ||
        oldDelegate.angleTolerance != angleTolerance ||
        oldDelegate.topInset != topInset ||
        oldDelegate.bottomInset != bottomInset ||
        !mapEquals(oldDelegate.measuredAngle, measuredAngle) ||
        !mapEquals(oldDelegate.measuredDiff, measuredDiff);
  }
}

// ── 잘 보이게 맞춤 점수(10-17): 낮을수록 잘 보인다. 시험에서 방향별 값을 볼 수 있게 밖에 둔다. ──

double _isoSegDist(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final l2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (l2 < 1e-6) return (p - a).distance;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / l2).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

double isoViewScore(List<vmath.Vector3> pts, double rx, double ry) {
  final m = vmath.Matrix4.identity()
    ..rotateX(rx)
    ..rotateY(ry);
  final p2 = [
    for (final v in pts)
      () {
        final q = m.transformed3(v);
        return Offset(q.x, -q.y);
      }(),
  ];
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final o in p2) {
    minX = math.min(minX, o.dx);
    maxX = math.max(maxX, o.dx);
    minY = math.min(minY, o.dy);
    maxY = math.max(maxY, o.dy);
  }
  final w = math.max(maxX - minX, 1e-6), h = math.max(maxY - minY, 1e-6);
  final diag = math.sqrt(w * w + h * h);
  var score = 0.0;
  final n = p2.length - 1;
  for (var i = 0; i < n; i++) {
    final l3 = (pts[i + 1] - pts[i]).length;
    if (l3 < 1e-6) continue;
    final r = (p2[i + 1] - p2[i]).distance / l3;
    if (r < 0.35) score += 1 + 2 * (0.35 - r) / 0.35; // 정면으로 보여 점처럼
  }
  for (var i = 0; i < n; i++) {
    for (var j = i + 2; j < n; j++) {
      final d = _isoSegSegDist(p2[i], p2[i + 1], p2[j], p2[j + 1]) / diag;
      // 겹치거나 가까우면(사이에 치수 글 둘 자리가 없음) 벌점.
      if (d < 0.1) score += 0.5 + (0.1 - d) / 0.1;
    }
  }
  // 치수 글은 구간 가운데에 붙는다: 가운데끼리 가까우면 글이 몰린다.
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      final mi = (p2[i] + p2[i + 1]) / 2, mj = (p2[j] + p2[j + 1]) / 2;
      final d = (mi - mj).distance / diag;
      if (d < 0.15) score += (0.15 - d) / 0.15;
    }
  }
  // 세로 화면에 맞는 모양을 조금 더 좋게 본다.
  score += 0.2 * (math.log((w / h) / 0.7)).abs();
  return score;
}

double _isoSegSegDist(Offset a, Offset b, Offset c, Offset d) {
  double cross(Offset o, Offset p, Offset q) =>
      (p.dx - o.dx) * (q.dy - o.dy) - (p.dy - o.dy) * (q.dx - o.dx);
  final d1 = cross(c, d, a), d2 = cross(c, d, b);
  final d3 = cross(a, b, c), d4 = cross(a, b, d);
  if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
      ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
    return 0;
  }
  return [
    _isoSegDist(a, c, d),
    _isoSegDist(b, c, d),
    _isoSegDist(c, a, b),
    _isoSegDist(d, a, b),
  ].reduce(math.min);
}
