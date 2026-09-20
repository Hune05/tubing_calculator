import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vmath;
import 'package:shared_preferences/shared_preferences.dart'; // 🚀 SharedPreferences 추가
import 'package:tubing_calculator/src/presentation/calculator/widgets/pipe_path_points.dart';

const Color makitaTeal = Color(0xFF007580);

// 🚀 기존 태블릿 코드와 충돌하지 않도록 독립적인 모바일 전용 클래스 생성
class MobilePipeVisualizer extends StatefulWidget {
  final List<Map<String, dynamic>> bendList;
  final double tailLength;
  final int? selectedSegmentIndex;
  final String initialStartDir;
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

  const MobilePipeVisualizer({
    super.key,
    required this.bendList,
    this.tailLength = 0.0,
    this.selectedSegmentIndex,
    this.initialStartDir = 'RIGHT',
    this.onStartDirChanged,
    this.isLightMode = false,
    this.startFit = false,
    this.endFit = false,
    this.totalCutLength = 0.0,
    this.bendRadius = 0.0,
    this.outerDiameter = 0.0,
    this.fittingDepth = 0.0,
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

  @override
  void initState() {
    super.initState();
    _startDir = widget.initialStartDir; // 1. 우선 기본값으로 세팅
    _loadSavedDirection(); // 2. 🚀 기기에 저장된 방향이 있다면 무조건 덮어씌움
  }

  // 🚀 [추가됨] 앱을 껐다 켜도, 탭을 이동해도 무조건 기억하도록 로드하는 함수
  Future<void> _loadSavedDirection() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDir = prefs.getString('mobile_saved_start_dir');
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

  // 🚀 [삭제됨] 부모 위젯이 강제로 초기값으로 덮어씌우는 didUpdateWidget 로직을 제거했습니다.
  // 이제 사용자가 직접 드롭다운을 누르기 전까지는 절대 값이 바뀌지 않습니다.

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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 🌟 1. 도면 렌더링 (제스처 컨트롤 포함)
        GestureDetector(
          onScaleStart: widget.isLightMode ? null : _onScaleStart,
          onScaleUpdate: widget.isLightMode ? null : _onScaleUpdate,
          onDoubleTap: widget.isLightMode ? null : _resetView,
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
              ),
            ),
          ),
        ),

        // 🌟 2. 좌측 상단: 시작 방향 변경 컨트롤러
        Positioned(top: 16, left: 16, child: _buildStartDirSelector()),

        // 🌟 3. 우측 상단: 총 컷팅 기장 표시 뱃지
        if (widget.totalCutLength > 0)
          Positioned(top: 16, right: 16, child: _buildTotalCutBadge()),

        // 🌟 4. 모바일 전용 컴팩트 컨트롤러 (하단 중앙 플로팅 바)
        if (!widget.isLightMode)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
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
                        () => _zoomLevel = (_zoomLevel - 0.2).clamp(0.2, 10.0),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _buildIconBtn(
                      Icons.add_circle_outline,
                      Colors.white70,
                      () => setState(
                        () => _zoomLevel = (_zoomLevel + 0.2).clamp(0.2, 10.0),
                      ),
                    ),
                    _buildDivider(),
                    _buildIconBtn(Icons.refresh, makitaTeal, _resetView),
                  ],
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
        borderRadius: BorderRadius.circular(8),
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
                  await prefs.setString('mobile_saved_start_dir', val);

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

  // 🚀 우측 상단: 총 컷팅 기장 뱃지 위젯
  Widget _buildTotalCutBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isLightMode
            ? Colors.white.withValues(alpha: 0.9)
            : const Color(0xFF2B3643).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
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
          const Icon(Icons.straighten, size: 14, color: makitaTeal),
          const SizedBox(width: 6),
          Text(
            "총 기장: ",
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
    double scale =
        (math.min(size.width, size.height) * 0.4) / maxRadius * zoomLevel;

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
        -finalY * scale + size.height / 2 + panY,
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
        renderQueue.add(
          MobilePolylineRenderable(pts, zSum / (j - i + 1)),
        );
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
        oldDelegate.fittingDepth != fittingDepth;
  }
}
