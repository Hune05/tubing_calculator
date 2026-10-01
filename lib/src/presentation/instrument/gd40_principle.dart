// GD40 검출기 원리·구조 그림(10-01): 검사관이 "순도를 어떻게 재느냐"고 물을 때 보여 줄 것.
// 근거: 요꼬가와 기술 자료 TI 11T03E01-01E(5판, 2017) 4장 원리·5장 특성·9장 계산식, 사용자 설명서 IM 11T03E01-01E.
// ① 단면 그림(얇은 스테인리스 원통 공진자, 압전 소자 두 쌍(구동·검출), 백금 온도 센서, O-링, 가스 길)
// ② 진동 모드 그림(2차 원주 모드 F2 약 2 kHz, 4차 모드 F4 약 6 kHz, 둘레 가스가 같이 흔들림) — 몇 번 움직이고 멈춤
// ③ 순도 ↔ 밀도 그림(수소·공기 두 가스가 섞인 밀도는 섞인 비율에 직선으로 비례)
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'loop_paint_kit.dart';

/// 0 ℃, 101.33 kPa 밀도(kg/m3). TI 부록 표 1(JIS K2301) 값, 공기는 설명서 값.
const double kDensH2 = 0.08988, kDensAir = 1.2928, kDensCO2 = 1.9771, kDensN2 = 1.2504;

/// 수소·공기 혼합 밀도(이상 기체, 부피 비율 x = 수소 %/100).
double mixDensity(double h2Pct, {double other = kDensAir}) => h2Pct / 100 * kDensH2 + (1 - h2Pct / 100) * other;

/// 밀도로 수소 순도(%) — 제로·스팬 직선 보간과 같은 꼴(TI 9장 C = (do − dz)/(ds − dz) × (Cs − Cz) + Cz).
double purityFromDensity(double d, {double other = kDensAir}) => (other - d) / (other - kDensH2) * 100;

Widget _frame(Widget child, double aspect) => Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 560),
    child: Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF7F9FA), Color(0xFFE9EDF0)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.all(8),
      child: AspectRatio(aspectRatio: aspect, child: child),
    ),
  ),
);

// ───────── ① 단면 ─────────

class Gd40StructurePainter extends CustomPainter {
  const Gd40StructurePainter();

  void _label(Canvas c, String s, Offset at, Offset to, {Color color = const Color(0xFF2B3036)}) {
    c.drawLine(at, to, Paint()
      ..color = color.withValues(alpha: .7)
      ..strokeWidth = 1);
    c.drawCircle(to, 2, Paint()..color = color);
    lpPill(c, s, at, Colors.white, fg: color, size: 8);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = canvas;
    c.save();
    c.scale(size.width / 360, size.height / 240);
    // 몸체(스테인리스 블록) 단면
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(40, 50, 280, 140), const Radius.circular(14));
    lpShadow(c, body, blur: 8, off: const Offset(3, 6), a: .28);
    c.drawRRect(body, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF1F3F5), Color(0xFFB9C0C7), Color(0xFF8E979F)]).createShader(body.outerRect));
    // 빗금(단면 표시)
    c.save();
    c.clipRRect(body);
    for (var x = 20.0; x < 360; x += 9) {
      c.drawLine(Offset(x, 50), Offset(x - 140, 190), Paint()
        ..color = Colors.black.withValues(alpha: .05)
        ..strokeWidth = 1);
    }
    c.restore();
    // 가스 공간
    final cavity = RRect.fromRectAndRadius(const Rect.fromLTWH(70, 78, 220, 84), const Radius.circular(10));
    c.drawRRect(cavity, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE6F4F1), Color(0xFFCDE8E3)]).createShader(cavity.outerRect));
    // 원통 공진자(얇은 벽, 왼쪽 밑판에 고정)
    const top = 96.0, bot = 144.0, x0 = 92.0, x1 = 262.0;
    final wall = Paint()
      ..shader = const LinearGradient(colors: [Color(0xFFDDE2E7), Color(0xFF9AA3AB)]).createShader(const Rect.fromLTWH(x0, top, x1 - x0, 6));
    c.drawRect(const Rect.fromLTRB(x0, top - 2, x1, top + 2), wall);
    c.drawRect(const Rect.fromLTRB(x0, bot - 2, x1, bot + 2), wall);
    c.drawRect(const Rect.fromLTRB(x1 - 2, top - 2, x1 + 2, bot + 2), wall); // 막힌 끝
    c.drawRect(const Rect.fromLTRB(x0 - 10, top - 10, x0, bot + 10), Paint()..color = const Color(0xFF8E979F)); // 밑판
    // 원통 안쪽(가스 안 들어감)
    c.drawRect(const Rect.fromLTRB(x0, top + 2, x1 - 2, bot - 2), Paint()..color = const Color(0xFFF7F8F9));
    // 압전 소자 두 쌍(위·아래 네 곳)
    const piezo = Color(0xFFF59E0B);
    for (final p in const [Offset(150, top + 6), Offset(150, bot - 6), Offset(210, top + 6), Offset(210, bot - 6)]) {
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: p, width: 18, height: 7), const Radius.circular(2));
      c.drawRRect(r, Paint()..color = piezo);
      c.drawRRect(r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = const Color(0xFF92400E));
    }
    // 신호선(원통 안쪽 → 왼쪽 밖)
    final wire = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF6B737B);
    for (final p in const [Offset(150, top + 6), Offset(150, bot - 6), Offset(210, top + 6), Offset(210, bot - 6)]) {
      c.drawPath(Path()
        ..moveTo(p.dx - 9, p.dy)
        ..lineTo(104, 120)
        ..lineTo(30, 120), wire);
    }
    // 백금 온도 센서
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(276, 60, 6, 40), const Radius.circular(3)), Paint()..color = const Color(0xFF4A5057));
    c.drawCircle(const Offset(279, 102), 4, Paint()..color = const Color(0xFFDC2626));
    // O-링
    for (final p in const [Offset(76, 90), Offset(76, 150), Offset(286, 84), Offset(286, 156)]) {
      c.drawCircle(p, 4, Paint()..color = const Color(0xFF111316));
    }
    // 가스 길(입구 → 원통 바깥 → 출구)
    final gas = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF0E9F8E);
    final flow = Path()
      ..moveTo(120, 214)
      ..lineTo(120, 162)
      ..quadraticBezierTo(120, 152, 140, 152)
      ..lineTo(270, 152)
      ..quadraticBezierTo(282, 152, 282, 130)
      ..lineTo(282, 118)
      ..moveTo(110, 152)
      ..lineTo(80, 152)
      ..quadraticBezierTo(80, 88, 140, 88)
      ..lineTo(270, 88)
      ..quadraticBezierTo(300, 88, 300, 60)
      ..lineTo(300, 26);
    for (final m in flow.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 10) {
        final a = m.getTangentForOffset(d)!.position;
        final b = m.getTangentForOffset(math.min(d + 5, m.length))!.position;
        c.drawLine(a, b, gas);
      }
    }
    lpPill(c, '시료 입구', const Offset(120, 226), const Color(0xFF0E9F8E), size: 8);
    lpPill(c, '출구', const Offset(300, 18), const Color(0xFF0E9F8E), size: 8);
    // 이름표
    _label(c, '얇은 스테인리스 원통 공진자', const Offset(170, 32), const Offset(180, top - 2));
    _label(c, '압전 소자 (구동·검출 두 쌍)', const Offset(215, 210), const Offset(210, bot - 4), color: const Color(0xFF92400E));
    _label(c, '백금 온도 센서', const Offset(330, 112), const Offset(282, 100), color: const Color(0xFFDC2626));
    _label(c, 'O-링', const Offset(36, 172), const Offset(76, 152));
    _label(c, '변환기로', const Offset(30, 104), const Offset(30, 120), color: const Color(0xFF6B737B));
    c.restore();
  }

  @override
  bool shouldRepaint(Gd40StructurePainter o) => false;
}

Widget gd40StructureFigure() => _frame(const CustomPaint(key: Key('gd40_structure'), painter: Gd40StructurePainter()), 360 / 240);

// ───────── ② 진동 모드 ─────────

class Gd40ModesFigure extends StatefulWidget {
  final double density; // 둘레 가스 밀도(점 개수·색 진하기로)
  const Gd40ModesFigure({super.key, this.density = 0.11});

  @override
  State<Gd40ModesFigure> createState() => _Gd40ModesFigureState();
}

class _Gd40ModesFigureState extends State<Gd40ModesFigure> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  int _loops = 0;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && ++_loops < 4) _c.forward(from: 0);
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _frame(
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(key: const Key('gd40_modes'), painter: _ModesPainter(_c.value, widget.density)),
        ),
        360 / 190,
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          key: const Key('gd40_modes_replay'),
          onPressed: () {
            _loops = 0;
            _c.forward(from: 0);
          },
          icon: const Icon(Icons.replay, size: 18),
          label: const Text('다시 보기'),
        ),
      ),
    ],
  );
}

class _ModesPainter extends CustomPainter {
  final double t, density;
  const _ModesPainter(this.t, this.density);

  void _mode(Canvas c, Offset ctr, int n, double phase, String title, String freq) {
    const r = 46.0, amp = 7.0;
    // 둘레 가스(점): 원통 겉면을 따라 같이 흔들림
    final rnd = math.Random(n);
    final gasCount = (40 + density * 120).clamp(30, 220).toInt();
    final dot = Paint()..color = const Color(0xFF0E9F8E).withValues(alpha: .55);
    for (var i = 0; i < gasCount; i++) {
      final th = rnd.nextDouble() * math.pi * 2;
      final rr = r + 8 + rnd.nextDouble() * 18;
      final push = amp * math.cos(n * th) * math.sin(phase) * (1 - (rr - r - 8) / 22);
      final p = ctr + Offset(math.cos(th), math.sin(th)) * (rr + push);
      c.drawCircle(p, 1.4, dot);
    }
    // 원래 모양(점선 원)
    final ref = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.textFaint;
    for (var a = 0.0; a < math.pi * 2; a += .2) {
      c.drawArc(Rect.fromCircle(center: ctr, radius: r), a, .1, false, ref);
    }
    // 흔들리는 원통 단면
    final path = Path();
    for (var i = 0; i <= 120; i++) {
      final th = i / 120 * math.pi * 2;
      final rr = r + amp * math.cos(n * th) * math.sin(phase);
      final p = ctr + Offset(math.cos(th), math.sin(th)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    c.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..shader = const LinearGradient(colors: [Color(0xFFDDE2E7), Color(0xFF6D757D)]).createShader(Rect.fromCircle(center: ctr, radius: r + amp)));
    // 압전 소자 네 곳
    for (var k = 0; k < 4; k++) {
      final th = k * math.pi / 2 + math.pi / 4;
      final rr = r + amp * math.cos(n * th) * math.sin(phase);
      c.drawCircle(ctr + Offset(math.cos(th), math.sin(th)) * rr, 3.4, Paint()..color = const Color(0xFFF59E0B));
    }
    lpText(c, title, ctr + const Offset(0, -r - 34), size: 9.5, color: AppColors.text, w: FontWeight.w900);
    lpPill(c, freq, ctr + const Offset(0, r + 36), AppColors.brand, size: 8.5);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = canvas;
    c.save();
    c.scale(size.width / 360, size.height / 190);
    final ph = t * math.pi * 2 * 3;
    _mode(c, const Offset(92, 96), 2, ph, '2차 원주 모드', 'F2 약 2 kHz');
    _mode(c, const Offset(268, 96), 4, ph * 1.6, '4차 원주 모드', 'F4 약 6 kHz');
    lpText(c, '두 모드를 동시에 울리고 F2 ÷ F4 비율로 밀도 계산', const Offset(180, 182), size: 8.5, color: AppColors.textSub, w: FontWeight.w800);
    c.restore();
  }

  @override
  bool shouldRepaint(_ModesPainter o) => o.t != t || o.density != density;
}

// ───────── ③ 순도 ↔ 밀도 ─────────

class Gd40PurityFigure extends StatefulWidget {
  const Gd40PurityFigure({super.key});

  @override
  State<Gd40PurityFigure> createState() => _Gd40PurityFigureState();
}

class _Gd40PurityFigureState extends State<Gd40PurityFigure> {
  double _pct = 98;

  @override
  Widget build(BuildContext context) {
    final d = mixDensity(_pct);
    final d1 = mixDensity(_pct - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _frame(CustomPaint(key: const Key('gd40_purity'), painter: _PurityPainter(_pct)), 360 / 200),
        const SizedBox(height: 8),
        Text('수소 순도 ${_pct.toStringAsFixed(1)}% → 밀도 ${d.toStringAsFixed(4)} kg/m³ (0 ℃, 1 atm)', key: const Key('gd40_purity_text'), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text)),
        const SizedBox(height: 4),
        Text('여기서 공기가 1% 더 들어오면 밀도 +${(d1 - d).toStringAsFixed(4)} kg/m³ (+${((d1 - d) / d * 100).toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 13, color: AppColors.textSub)),
        Slider(key: const Key('gd40_purity_slider'), min: 80, max: 100, divisions: 200, value: _pct, onChanged: (v) => setState(() => _pct = v)),
      ],
    );
  }
}

class _PurityPainter extends CustomPainter {
  final double pct;
  const _PurityPainter(this.pct);

  @override
  void paint(Canvas canvas, Size size) {
    final c = canvas;
    c.save();
    c.scale(size.width / 360, size.height / 200);
    const l = 56.0, r = 340.0, t = 20.0, b = 160.0;
    double x(double p) => l + (p / 100) * (r - l);
    double y(double d) => b - d / 1.4 * (b - t);
    final axis = Paint()
      ..color = AppColors.textFaint
      ..strokeWidth = 1;
    c.drawLine(const Offset(l, b), const Offset(r, b), axis);
    c.drawLine(const Offset(l, t), const Offset(l, b), axis);
    for (final p in const [0.0, 25.0, 50.0, 75.0, 100.0]) {
      lpText(c, '${p.toInt()}', Offset(x(p), b + 10), size: 8, color: AppColors.textSub);
    }
    lpText(c, '수소 % (나머지 공기)', Offset((l + r) / 2, b + 26), size: 8.5, color: AppColors.textSub, w: FontWeight.w800);
    for (final d in const [0.0, 0.5, 1.0]) {
      lpText(c, d.toStringAsFixed(1), Offset(l - 18, y(d)), size: 8, color: AppColors.textSub);
      c.drawLine(Offset(l, y(d)), Offset(r, y(d)), Paint()
        ..color = AppColors.line
        ..strokeWidth = 1);
    }
    lpText(c, 'kg/m³', const Offset(l - 18, t - 8), size: 7.5, color: AppColors.textSub);
    // 직선(공기 1.2928 → 수소 0.0899)
    final line = Paint()
      ..color = AppColors.brand
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(x(0), y(kDensAir)), Offset(x(100), y(kDensH2)), line);
    lpPill(c, '공기 1.2928', Offset(x(0) + 34, y(kDensAir) - 12), const Color(0xFF6B737B), size: 8);
    lpPill(c, '수소 0.0899', Offset(x(100) - 30, y(kDensH2) - 14), const Color(0xFFF97316), size: 8);
    // 운전 범위(85~100%) 띠
    c.drawRect(Rect.fromLTRB(x(85), t, x(100), b), Paint()..color = AppColors.brand.withValues(alpha: .08));
    lpText(c, '측정 범위 85~100%', Offset(x(92.5), t + 8), size: 7.5, color: AppColors.brand, w: FontWeight.w800);
    // 지금 점
    final p = Offset(x(pct), y(mixDensity(pct)));
    c.drawLine(Offset(p.dx, b), p, Paint()
      ..color = const Color(0xFFDC2626).withValues(alpha: .5)
      ..strokeWidth = 1.2);
    c.drawCircle(p, 6, Paint()..color = Colors.white);
    c.drawCircle(p, 4, Paint()..color = const Color(0xFFDC2626));
    c.restore();
  }

  @override
  bool shouldRepaint(_PurityPainter o) => o.pct != pct;
}
