// 공학용 계산기 "현장 도구"(10-09): 직각삼각형 풀이·볼트 구멍 원(PCD) 좌표.
// 셈은 eng_tools.dart. 길이는 mm로 넣고, 결과는 mm와 피트·인치 분수로 같이 보인다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_icon_set.dart';
import '../../core/theme/field_view.dart';
import '../common/calc_form_parts.dart';
import '../common/number_text.dart';
import '../unit_converter/unit_defs.dart' show feetInches, formatNumber;
import 'eng_tools.dart';

/// mm 값을 "1234.5 mm (4' 0-5/8")" 꼴로.
String _mmText(double mm) => '${_n(mm, 1)} mm (${feetInches(mm / 25.4)})';

/// 소수 [d]자리, 끝의 0은 뗀다.
String _n(double v, int d) {
  var s = v.toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s == '-0' ? '0' : s;
}

class EngToolsPage extends StatelessWidget {
  const EngToolsPage({super.key});

  @override
  Widget build(BuildContext context) => FieldViewTheme(
    child: Builder(
      builder: (context) {
        Widget item(String key, String title, String sub, Widget page) => Card(
          key: Key(key),
          margin: const EdgeInsets.only(bottom: 8),
          color: fc.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: fc.line),
          ),
          child: ListTile(
            title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: fc.text)),
            subtitle: Text(sub, style: TextStyle(color: fc.textSub)),
            trailing: Icon(AppIcons.forward, color: fc.textSub),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
          ),
        );
        return Scaffold(
          backgroundColor: fc.surface,
          appBar: AppBar(
            backgroundColor: fc.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            foregroundColor: fc.text,
            title: Text('현장 도구', style: TextStyle(fontWeight: FontWeight.w800, color: fc.text)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              item(
                'tool_triangle',
                '직각삼각형 풀이',
                '높이·밑변·빗변·각도 중 두 값 → 나머지 (브레이스·경사 배관)',
                const RightTrianglePage(),
              ),
              item(
                'tool_bolt_circle',
                '볼트 구멍 원 (PCD)',
                'PCD·구멍 수 → 구멍마다 X·Y 좌표, 이웃 구멍 거리',
                const BoltCirclePage(),
              ),
            ],
          ),
        );
      },
    ),
  );
}

// ───────────────────────── 직각삼각형 ─────────────────────────

class RightTrianglePage extends StatefulWidget {
  const RightTrianglePage({super.key});

  @override
  State<RightTrianglePage> createState() => _RightTrianglePageState();
}

class _RightTrianglePageState extends State<RightTrianglePage>
    with CalcFormParts<RightTrianglePage> {
  final _rise = TextEditingController();
  final _run = TextEditingController();
  final _hyp = TextEditingController();
  final _angle = TextEditingController();

  @override
  void dispose() {
    for (final c in [_rise, _run, _hyp, _angle]) {
      c.dispose();
    }
    super.dispose();
  }

  void _clear() => setState(() {
    for (final c in [_rise, _run, _hyp, _angle]) {
      c.clear();
    }
  });

  @override
  Widget build(BuildContext context) => FieldViewTheme(
    child: Builder(builder: _buildPage),
  );

  Widget _buildPage(BuildContext context) {
    double? read(TextEditingController c) => c.text.trim().isEmpty ? null : parseNumberText(c.text);
    final bad = [_rise, _run, _hyp, _angle].any((c) => c.text.trim().isNotEmpty && read(c) == null);
    RightTriangle? t;
    String? error;
    if (bad) {
      error = '숫자가 아닌 칸이 있습니다.';
    } else {
      try {
        t = solveRightTriangle(rise: read(_rise), run: read(_run), hyp: read(_hyp), angle: read(_angle));
      } on TriangleError catch (e) {
        error = e.message;
      }
    }
    return Scaffold(
      backgroundColor: fc.surface,
      appBar: AppBar(
        backgroundColor: fc.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: fc.text,
        title: Text('직각삼각형 풀이', style: TextStyle(fontWeight: FontWeight.w800, color: fc.text)),
        actions: [calcToggle('tri_clear', '지우기', _clear)],
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            SizedBox(
              height: 170,
              child: CustomPaint(
                key: const Key('tri_drawing'),
                painter: _TrianglePainter(t, fc.brand, fc.text, fc.textSub, fc.brandSoft),
                size: Size.infinite,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '두 칸만 넣으면 나머지를 계산합니다. 길이는 mm, 각도는 밑변과 빗변 사이(°)입니다.',
              style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.4),
            ),
            const SizedBox(height: 8),
            calcField('tri_rise', '높이 (mm)', _rise, '세운 쪽 길이입니다. 오프셋 배관이면 옮길 높이, 브레이스면 세로 길이.'),
            calcField('tri_run', '밑변 (mm)', _run, '바닥 쪽 길이입니다. 오프셋 배관이면 앞으로 나가는 거리.'),
            calcField('tri_hyp', '빗변 (mm)', _hyp, '비스듬한 쪽 길이입니다. 브레이스·경사 배관의 실제 길이.'),
            calcField('tri_angle', '각도 (°)', _angle, '밑변과 빗변 사이 각입니다. 높이와 빗변 사이 각은 90°에서 뺀 값입니다.'),
            const SizedBox(height: 12),
            if (t != null)
              calcResult(
                key: const Key('tri_result'),
                caption: '빗변',
                big: '${_n(t.hyp, 1)} mm',
                lines: [
                  '높이 ${_mmText(t.rise)}',
                  '밑변 ${_mmText(t.run)}',
                  '빗변 ${_mmText(t.hyp)}',
                  '각도 ${_n(t.angle, 2)}° (높이 쪽 각 ${_n(t.otherAngle, 2)}°)',
                  '구배 ${_n(t.slopePercent, 2)} % (밑변 1 m에 ${_n(t.slopePercent * 10, 1)} mm)',
                ],
              )
            else
              calcResult(
                key: const Key('tri_result'),
                caption: '결과',
                big: '—',
                lines: [error ?? '두 칸을 넣으십시오.'],
                warn: error != null && error != '두 칸을 넣으십시오.',
              ),
          ],
        ),
      ),
    );
  }
}

/// 직각삼각형 그림. 풀이가 되면 그 비율로, 아니면 보기 모양(3:4)으로 그리고 변 이름을 붙인다.
class _TrianglePainter extends CustomPainter {
  final RightTriangle? t;
  final Color brand, ink, sub, soft;
  _TrianglePainter(this.t, this.brand, this.ink, this.sub, this.soft);

  @override
  void paint(Canvas canvas, Size size) {
    final ratio = t == null ? 0.75 : (t!.rise / t!.run).clamp(0.08, 3.0);
    const pad = 28.0;
    final availW = size.width - pad * 2 - 40, availH = size.height - pad * 2;
    var w = availW, h = w * ratio;
    if (h > availH) {
      h = availH;
      w = h / ratio;
    }
    final left = (size.width - w) / 2 - 10, bottom = size.height - pad;
    final a = Offset(left, bottom), b = Offset(left + w, bottom), c = Offset(left + w, bottom - h);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..close();
    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [soft, Color.lerp(soft, Colors.white, 0.5)!],
        ).createShader(Rect.fromPoints(a, c)),
    );
    final line = Paint()
      ..color = brand
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, line);
    // 직각 표시
    const sq = 12.0;
    canvas.drawRect(Rect.fromLTWH(b.dx - sq, b.dy - sq, sq, sq), Paint()
      ..color = sub
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
    // 각도 호
    canvas.drawArc(
      Rect.fromCircle(center: a, radius: 26),
      -math.atan2(h, w),
      math.atan2(h, w),
      false,
      Paint()
        ..color = sub
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    void label(String s, Offset at, {bool bold = false}) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(color: bold ? brand : ink, fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }

    label('밑변', Offset((a.dx + b.dx) / 2, bottom + 14));
    label('높이', Offset(b.dx + 22, (b.dy + c.dy) / 2));
    final mid = Offset((a.dx + c.dx) / 2, (a.dy + c.dy) / 2);
    label('빗변', mid + const Offset(-16, -12), bold: true);
    label('각도', a + const Offset(44, -10));
  }

  @override
  bool shouldRepaint(_TrianglePainter old) =>
      old.t?.rise != t?.rise || old.t?.run != t?.run || old.brand != brand || old.ink != ink;
}

// ───────────────────────── 볼트 구멍 원 ─────────────────────────

class BoltCirclePage extends StatefulWidget {
  const BoltCirclePage({super.key});

  @override
  State<BoltCirclePage> createState() => _BoltCirclePageState();
}

enum _BoltStart { top, straddle, custom }

class _BoltCirclePageState extends State<BoltCirclePage> with CalcFormParts<BoltCirclePage> {
  final _pcd = TextEditingController();
  final _count = TextEditingController();
  final _start = TextEditingController();
  _BoltStart _mode = _BoltStart.straddle;

  @override
  void dispose() {
    _pcd.dispose();
    _count.dispose();
    _start.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FieldViewTheme(child: Builder(builder: _buildPage));

  Widget _buildPage(BuildContext context) {
    final pcd = parseNumberText(_pcd.text);
    final n = parseNumberText(_count.text);
    final custom = parseNumberText(_start.text);
    String? error;
    List<BoltHole>? holes;
    if (_pcd.text.trim().isEmpty || _count.text.trim().isEmpty) {
      error = null;
    } else if (pcd == null || pcd <= 0) {
      error = 'PCD는 0보다 큰 숫자로 넣으십시오.';
    } else if (n == null || n != n.roundToDouble() || n < 2 || n > 72) {
      error = '구멍 수는 2~72개 정수로 넣으십시오.';
    } else if (_mode == _BoltStart.custom && _start.text.trim().isNotEmpty && custom == null) {
      error = '시작 각도가 숫자가 아닙니다.';
    } else {
      final count = n.round();
      final start = switch (_mode) {
        _BoltStart.top => 0.0,
        _BoltStart.straddle => straddleStart(count),
        _BoltStart.custom => custom ?? 0.0,
      };
      holes = boltCircle(pcd, count, start: start);
    }
    final count = holes?.length ?? 0;
    return Scaffold(
      backgroundColor: fc.surface,
      appBar: AppBar(
        backgroundColor: fc.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: fc.text,
        title: Text('볼트 구멍 원 (PCD)', style: TextStyle(fontWeight: FontWeight.w800, color: fc.text)),
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            SizedBox(
              height: 220,
              child: CustomPaint(
                key: const Key('bolt_drawing'),
                painter: _BoltPainter(holes, fc.brand, fc.text, fc.textSub, fc.brandSoft),
                size: Size.infinite,
              ),
            ),
            const SizedBox(height: 8),
            calcField('bolt_pcd', 'PCD (mm)', _pcd, '볼트 구멍 중심을 잇는 원의 지름입니다. 플랜지 표의 "볼트 원 지름(C)".'),
            calcField('bolt_count', '구멍 수', _count, '볼트 구멍 개수입니다(2~72).'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                calcChip('bolt_start_straddle', '12시 양쪽 걸침', _mode == _BoltStart.straddle,
                    () => setState(() => _mode = _BoltStart.straddle)),
                calcChip('bolt_start_top', '12시에 1번', _mode == _BoltStart.top,
                    () => setState(() => _mode = _BoltStart.top)),
                calcChip('bolt_start_custom', '각도 직접', _mode == _BoltStart.custom,
                    () => setState(() => _mode = _BoltStart.custom)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '플랜지는 보통 위·아래 중심선에 구멍이 걸치지 않게 "양쪽 걸침"으로 놓습니다.',
              style: TextStyle(fontSize: 12, color: fc.textSub, height: 1.4),
            ),
            if (_mode == _BoltStart.custom)
              calcField('bolt_start', '1번 구멍 각도 (°)', _start, '12시 방향에서 시계 방향으로 잰 각입니다.'),
            const SizedBox(height: 12),
            if (holes == null)
              calcResult(
                key: const Key('bolt_result'),
                caption: '결과',
                big: '—',
                lines: [error ?? 'PCD와 구멍 수를 넣으십시오.'],
                warn: error != null,
              )
            else ...[
              calcResult(
                key: const Key('bolt_result'),
                caption: '이웃 구멍 중심 사이',
                big: '${_n(boltPitch(pcd!, count), 2)} mm',
                lines: [
                  '구멍 사이 각 ${_n(360 / count, 2)}°',
                  if (count >= 4) '하나 건너 구멍 사이 ${_n(pcd * math.sin(2 * math.pi / count), 2)} mm',
                  '좌표는 원 중심 기준, X는 오른쪽 +, Y는 위 +. 1번부터 시계 방향.',
                ],
              ),
              const SizedBox(height: 12),
              _holeTable(holes),
            ],
          ],
        ),
      ),
    );
  }

  Widget _holeTable(List<BoltHole> holes) {
    TextStyle st({bool head = false}) => TextStyle(
      fontSize: 14,
      fontWeight: head ? FontWeight.w800 : FontWeight.w600,
      color: head ? fc.textSub : fc.text,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget row(List<String> cells, {bool head = false, Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(cells[0], style: st(head: head))),
          Expanded(child: Text(cells[1], textAlign: TextAlign.right, style: st(head: head))),
          Expanded(child: Text(cells[2], textAlign: TextAlign.right, style: st(head: head))),
          Expanded(child: Text(cells[3], textAlign: TextAlign.right, style: st(head: head))),
        ],
      ),
    );
    return Container(
      key: const Key('bolt_table'),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        border: Border.all(color: fc.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          row(['번호', '각도', 'X (mm)', 'Y (mm)'], head: true),
          Divider(height: 1, color: fc.line),
          for (final h in holes)
            row(
              ['${h.no}', '${_n(h.angle, 2)}°', formatNumber(double.parse(h.x.toStringAsFixed(2))), formatNumber(double.parse(h.y.toStringAsFixed(2)))],
              key: Key('bolt_row_${h.no}'),
            ),
        ],
      ),
    );
  }
}

/// 볼트 구멍 원 그림: 원·중심선, 구멍마다 번호. 1번은 진하게.
class _BoltPainter extends CustomPainter {
  final List<BoltHole>? holes;
  final Color brand, ink, sub, soft;
  _BoltPainter(this.holes, this.brand, this.ink, this.sub, this.soft);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 30;
    // 플랜지 바탕(그라데이션·그림자)
    final disk = Path()..addOval(Rect.fromCircle(center: c, radius: r + 18));
    canvas.drawShadow(disk, Colors.black, 4, false);
    canvas.drawCircle(
      c,
      r + 18,
      Paint()
        ..shader = RadialGradient(
          colors: [Color.lerp(soft, Colors.white, 0.6)!, soft],
        ).createShader(Rect.fromCircle(center: c, radius: r + 18)),
    );
    final thin = Paint()
      ..color = sub
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    // 중심선
    canvas.drawLine(c - Offset(r + 26, 0), c + Offset(r + 26, 0), thin);
    canvas.drawLine(c - Offset(0, r + 26), c + Offset(0, r + 26), thin);
    // PCD
    canvas.drawCircle(c, r, thin..color = brand.withValues(alpha: 0.6));
    final list = holes;
    if (list == null) return;
    final holeR = (math.pi * r / list.length * 0.35).clamp(3.0, 10.0);
    final scale = r / (math.sqrt(list.first.x * list.first.x + list.first.y * list.first.y));
    for (final h in list) {
      final p = c + Offset(h.x * scale, -h.y * scale);
      canvas.drawCircle(p, holeR, Paint()..color = h.no == 1 ? brand : ink.withValues(alpha: 0.75));
      canvas.drawCircle(p - Offset(holeR * 0.3, holeR * 0.3), holeR * 0.3, Paint()..color = Colors.white.withValues(alpha: 0.35));
      if (list.length <= 24) {
        final dir = (p - c) / r;
        final at = c + dir * (r + 18 + holeR);
        final tp = TextPainter(
          text: TextSpan(
            text: '${h.no}',
            style: TextStyle(color: h.no == 1 ? brand : ink, fontSize: 11, fontWeight: FontWeight.w800),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_BoltPainter old) =>
      old.holes?.length != holes?.length ||
      old.holes?.first.angle != holes?.first.angle ||
      old.brand != brand;
}
