/// 전선관 설정 화면 헤더의 "설정 가이드" — 수동·유압식·시카고식 벤더 각각
/// 제원 칸이 실제 장비의 어느 부위 값인지 움직이는 그림으로 짚어 준다.
/// (실측하는 방법 자체는 이미 현장 자료 → 장비 사용법에 글로 자세히 있어서
/// 여기서 다시 안 적고, "이 칸 = 그림의 이 부분"만 그림으로 보여 준다.)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/presentation/common/guide_paint_kit.dart';

const Color _slate900 = AppColors.text;
const Color _slate600 = AppColors.textSub;
const Color _pureWhite = Color(0xFFFFFFFF);
const Color _slate100 = AppColors.background;

enum _BenderKind { hand, ram, chicago }

class BenderSetupGuidePage extends StatelessWidget {
  const BenderSetupGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        key: const Key('bender_guide_page'),
        backgroundColor: _slate100,
        appBar: AppBar(
          title: const Text(
            '벤더 설정 가이드',
            style: TextStyle(
              color: _slate900,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          backgroundColor: _pureWhite,
          elevation: 1,
          shadowColor: Colors.grey.shade200,
          centerTitle: false,
          iconTheme: const IconThemeData(color: _slate900),
          bottom: const TabBar(
            labelColor: AppColors.brand,
            unselectedLabelColor: _slate600,
            indicatorColor: AppColors.brand,
            tabs: [
              Tab(text: '수동 벤더'),
              Tab(text: '유압식 벤더'),
              Tab(text: '시카고식 벤더'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BenderGuideTab(kind: _BenderKind.hand),
            _BenderGuideTab(kind: _BenderKind.ram),
            _BenderGuideTab(kind: _BenderKind.chicago),
          ],
        ),
      ),
    );
  }
}

class _BenderGuideTab extends StatefulWidget {
  final _BenderKind kind;
  const _BenderGuideTab({required this.kind});

  @override
  State<_BenderGuideTab> createState() => _BenderGuideTabState();
}

class _BenderGuideTabState extends State<_BenderGuideTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = _fieldsFor(widget.kind);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GuideFrame(
            height: 240,
            animation: _c,
            onReplay: () => _c.forward(from: 0),
            replayKey: Key('bender_guide_replay_${widget.kind.name}'),
            painterBuilder: (context, anim) => CustomPaint(
              size: Size.infinite,
              painter: _BenderDiagramPainter(kind: widget.kind, t: _c.value),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '이 칸이 그림의 어느 부분인지',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _slate600,
            ),
          ),
          const SizedBox(height: 8),
          for (final f in fields) _FieldRow(field: f),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.brand),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '내 장비에서 이 값을 실제로 재는 방법(줄자 대는 법·계산식)은 '
                    '현장 자료 → 장비 사용법 탭의 "내 장비 실측 캘리브레이션"에 '
                    '자세히 있습니다.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _slate900,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideField {
  final IconData icon;
  final String label;
  final String desc;
  const _GuideField(this.icon, this.label, this.desc);
}

List<_GuideField> _fieldsFor(_BenderKind kind) {
  const takeup = _GuideField(
    Icons.straighten,
    '테이크업 (Take-up)',
    '꺾이는 점(그림의 점선 코너)에서 이만큼 앞으로 당겨서 마킹을 찍습니다.',
  );
  const setback = _GuideField(
    Icons.straighten,
    '셋백 (Setback)',
    '꺾이는 점(그림의 점선 코너)에서 이만큼 앞으로 당겨서 마킹을 찍습니다.',
  );
  const gain = _GuideField(
    Icons.compress,
    '벤딩 게인 (Gain)',
    '직각으로 꺾었을 때보다 관이 덜 필요해지는 길이 — 총 절단 길이에서 뺍니다.',
  );
  const clr = _GuideField(
    Icons.data_usage,
    '슈 중심선 반경 (CLR)',
    '벤더 슈(굽힘틀)가 관을 굽히는 곡선의 반지름입니다.',
  );
  switch (kind) {
    case _BenderKind.hand:
      return const [takeup, gain, clr];
    case _BenderKind.ram:
      return const [
        _GuideField(
          Icons.height,
          '램 이동 거리',
          '90°로 꺾을 때 유압 램(피스톤)이 밀고 나가는 거리입니다.',
        ),
        setback,
        gain,
        clr,
      ];
    case _BenderKind.chicago:
      return const [
        _GuideField(
          Icons.settings,
          '노치당 각도',
          '크랭크를 돌려 기어(노치) 한 칸을 넘길 때마다 꺾이는 각도입니다.',
        ),
        takeup,
        gain,
        _GuideField(
          Icons.straighten,
          '노치 간격',
          '슈에 새겨진 노치와 노치 사이 거리(아직 마킹 계산에는 안 씁니다).',
        ),
        _GuideField(
          Icons.circle_outlined,
          '롤러 규격',
          '관을 위에서 눌러 주는 롤러(바퀴)의 지름(아직 마킹 계산에는 안 씁니다).',
        ),
        clr,
      ];
  }
}

class _FieldRow extends StatelessWidget {
  final _GuideField field;
  const _FieldRow({required this.field});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(field.icon, size: 18, color: AppColors.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _slate900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  field.desc,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _slate600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 벤더 옆모습 그림 — 관이 들어와 굽혀 나가는 L자 곡선에 테이크업(셋백)·
/// 게인·CLR을 공통으로 짚고, 종류별로 하나씩 더 짚는다(유압=램 이동 거리,
/// 시카고=노치당 각도). 실측 방법이 아니라 "칸 이름 = 이 부분"만 보여준다.
class _BenderDiagramPainter extends CustomPainter {
  final _BenderKind kind;
  final double t;
  _BenderDiagramPainter({required this.kind, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    paintDotGrid(canvas, size);

    final entryY = h * 0.28;
    final turnX = w * 0.52;
    final exitY = h * 0.90;
    const curveR = 27.0;
    final startX = 14.0;
    final markX = turnX - curveR - 30; // 테이크업만큼 코너에서 당겨진 마킹 자리.

    // 1) 들어오는 직선 관(마킹 자리까지).
    final leadT = stageT(t, 0.0, 0.16);
    paintPipeSegment(
      canvas,
      Offset(startX, entryY),
      Offset(markX, entryY),
      leadT,
      _slate600,
      width: 8,
    );

    // 2) 테이크업/셋백 안내 화살표 + 이름표.
    final takeT = stageT(t, 0.16, 0.30);
    if (takeT > 0) {
      final a = Offset(markX, entryY);
      final b = Offset(turnX, entryY);
      final tip = Offset.lerp(a, b, takeT)!;
      final arrow = Paint()
        ..color = kGuideOrange
        ..strokeWidth = 1.6;
      canvas.drawLine(a, tip, arrow);
      _arrowHead(canvas, a, tip, kGuideOrange);
      if (takeT > 0.7) {
        paintPill(
          canvas,
          kind == _BenderKind.ram ? '셋백' : '테이크업',
          Offset((a.dx + b.dx) / 2, entryY - 14),
          color: kGuideOrange,
          size: 9.5,
        );
      }
    }

    // 3) 마킹 자리부터 코너를 지나 굽어서 내려가는 관.
    final bendT = stageT(t, 0.30, 0.58);
    if (bendT > 0) {
      final path = Path()
        ..moveTo(markX, entryY)
        ..lineTo(turnX - curveR, entryY)
        ..quadraticBezierTo(turnX, entryY, turnX, entryY + curveR)
        ..lineTo(turnX, exitY);
      final metrics = path.computeMetrics().first;
      final partial = metrics.extractPath(0, metrics.length * bendT);
      canvas.drawPath(
        partial,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..color = AppColors.brand,
      );
      canvas.drawPath(
        partial,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.55),
      );
    }

    // 4) 점선 코너(직각으로 꺾었다면의 자리) — 게인의 기준.
    final cornerT = stageT(t, 0.58, 0.68);
    if (cornerT > 0) {
      _dashLine(
        canvas,
        Offset(turnX - curveR, entryY),
        Offset(turnX, entryY),
        cornerT,
        _slate600.withValues(alpha: 0.5),
      );
      _dashLine(
        canvas,
        Offset(turnX, entryY),
        Offset(turnX, entryY + curveR),
        cornerT,
        _slate600.withValues(alpha: 0.5),
      );
    }

    // 5) CLR(반지름) 표시.
    final clrT = stageT(t, 0.68, 0.82);
    if (clrT > 0) {
      final center = Offset(turnX - curveR, entryY + curveR);
      final rim = Offset.lerp(center, Offset(turnX, entryY + curveR), clrT)!;
      canvas.drawLine(
        center,
        rim,
        Paint()
          ..color = AppColors.brand.withValues(alpha: 0.6)
          ..strokeWidth = 1.4,
      );
      if (clrT > 0.7) {
        paintPill(
          canvas,
          'CLR',
          Offset(turnX - curveR / 2, entryY + curveR + 12),
          color: AppColors.brand,
          size: 9,
        );
      }
    }

    // 6) 게인 이름표(직선 코너와 굽은 선의 차이).
    final gainT = stageT(t, 0.80, 0.92);
    if (gainT > 0.5) {
      paintPill(
        canvas,
        '게인',
        Offset(turnX - curveR - 6, entryY + curveR + 30),
        color: kGuideOrange,
        size: 9,
      );
    }

    // 7) 종류별로 하나 더.
    final extraT = stageT(t, 0.86, 1.0);
    if (extraT > 0) {
      switch (kind) {
        case _BenderKind.hand:
          break;
        case _BenderKind.ram:
          final pistonY = entryY + 22;
          final a = Offset(startX + 6, pistonY);
          final b = Offset(markX - 8, pistonY);
          if (extraT > 0.3) {
            paintGuideIcon(
              canvas,
              Icons.arrow_forward_rounded,
              Offset.lerp(a, b, 0.5)!,
              14,
              kGuideOrange,
            );
            canvas.drawLine(
              a,
              b,
              Paint()
                ..color = kGuideOrange.withValues(alpha: 0.7)
                ..strokeWidth = 1.4,
            );
          }
          if (extraT > 0.7) {
            paintPill(
              canvas,
              '램 이동 거리',
              Offset.lerp(a, b, 0.5)! + const Offset(0, 14),
              color: kGuideOrange,
              size: 9,
            );
          }
          break;
        case _BenderKind.chicago:
          final gearCenter = Offset(turnX + 26, entryY + curveR + 6);
          if (extraT > 0.2) {
            canvas.drawCircle(
              gearCenter,
              10,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.6
                ..color = kGuideOrange,
            );
            for (var i = 0; i < 8; i++) {
              final ang = i * (2 * math.pi / 8);
              final p1 =
                  gearCenter + Offset(10 * math.cos(ang), 10 * math.sin(ang));
              final p2 =
                  gearCenter + Offset(13 * math.cos(ang), 13 * math.sin(ang));
              canvas.drawLine(
                p1,
                p2,
                Paint()
                  ..color = kGuideOrange
                  ..strokeWidth = 1.6,
              );
            }
          }
          if (extraT > 0.7) {
            paintPill(
              canvas,
              '노치당 각도',
              gearCenter + const Offset(0, 20),
              color: kGuideOrange,
              size: 9,
            );
          }
      }
    }
  }

  void _arrowHead(Canvas canvas, Offset from, Offset to, Color color) {
    final dir = (to - from);
    if (dir.distance < 1) return;
    final n = dir / dir.distance;
    final left = Offset(-n.dy, n.dx);
    final p1 = to - n * 6 + left * 3;
    final p2 = to - n * 6 - left * 3;
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(p1.dx, p1.dy)
      ..moveTo(to.dx, to.dy)
      ..lineTo(p2.dx, p2.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.6,
    );
  }

  void _dashLine(Canvas canvas, Offset a, Offset b, double s, Color color) {
    final end = Offset.lerp(a, b, s)!;
    final d = (end - a).distance;
    if (d < 1) return;
    final dir = (end - a) / d;
    const step = 4.0, gap = 3.0;
    var covered = 0.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    while (covered < d) {
      final segEnd = covered + step > d ? d : covered + step;
      canvas.drawLine(a + dir * covered, a + dir * segEnd, paint);
      covered += step + gap;
    }
  }

  @override
  bool shouldRepaint(_BenderDiagramPainter old) =>
      old.t != t || old.kind != kind;
}
