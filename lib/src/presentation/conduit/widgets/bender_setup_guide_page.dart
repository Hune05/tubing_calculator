/// 전선관 설정 화면 헤더의 "설정 가이드" — 수동·유압식·시카고식 벤더 각각
/// 제원 칸이 실제 장비의 어느 부위 값인지 슬라이더로 직접 밀어보며 짚어 준다.
/// (실측하는 방법 자체는 이미 현장 자료 → 장비 사용법에 글로 자세히 있어서
/// 여기서 다시 안 적고, "이 칸 = 그림의 이 부분"만 실제 장비 모양으로 보여 준다.)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/presentation/common/guide_paint_kit.dart';

const Color _slate900 = AppColors.text;
const Color _slate600 = AppColors.textSub;
const Color _pureWhite = Color(0xFFFFFFFF);
const Color _slate100 = AppColors.background;
const Color _metal = Color(0xFF90A4AE); // blueGrey300 — 장비 몸체(고정 부분).
const Color _metalDark = Color(0xFF546E7A); // blueGrey600 — 움직이는 부분.

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

class _BenderGuideTabState extends State<_BenderGuideTab> {
  double _t = 1.0;

  void _jumpTo(double v) => setState(() => _t = v.clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final fields = _fieldsFor(widget.kind);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GuideFrame(
            height: 300,
            animation: kAlwaysCompleteAnimation,
            onReplay: () => _jumpTo(0),
            replayKey: Key('bender_guide_replay_${widget.kind.name}'),
            painterBuilder: (context, anim) => CustomPaint(
              size: Size.infinite,
              painter: _BenderDiagramPainter(kind: widget.kind, t: _t),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.swipe, size: 14, color: _slate600),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '밀어서 장비가 굽히는 순서를 직접 확인합니다',
                  style: TextStyle(fontSize: 12, color: _slate600),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              key: const Key('bender_guide_slider'),
              value: _t,
              activeColor: AppColors.brand,
              inactiveColor: Colors.grey.shade300,
              onChanged: _jumpTo,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '칸을 누르면 그림에서 그 값이 어디인지 바로 보여줍니다',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _slate600,
            ),
          ),
          const SizedBox(height: 8),
          for (final f in fields)
            _FieldRow(field: f, onTap: () => _jumpTo(f.jumpT)),
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
  final double jumpT;
  const _GuideField(this.icon, this.label, this.desc, this.jumpT);
}

List<_GuideField> _fieldsFor(_BenderKind kind) {
  const takeup = _GuideField(
    Icons.straighten,
    '테이크업 (Take-up)',
    '꺾이는 점(그림의 점선 코너)에서 이만큼 앞으로 당겨서 마킹을 찍습니다.',
    0.30,
  );
  const setback = _GuideField(
    Icons.straighten,
    '셋백 (Setback)',
    '꺾이는 점(그림의 점선 코너)에서 이만큼 앞으로 당겨서 마킹을 찍습니다.',
    0.30,
  );
  const gain = _GuideField(
    Icons.compress,
    '벤딩 게인 (Gain)',
    '직각으로 꺾었을 때보다 관이 덜 필요해지는 길이 — 총 절단 길이에서 뺍니다.',
    0.90,
  );
  const clr = _GuideField(
    Icons.data_usage,
    '슈 중심선 반경 (CLR)',
    '벤더 슈(굽힘틀)가 관을 굽히는 곡선의 반지름입니다.',
    0.80,
  );
  switch (kind) {
    case _BenderKind.hand:
      return const [takeup, gain, clr];
    case _BenderKind.ram:
      return const [
        _GuideField(
          Icons.height,
          '램 이동 거리',
          '90°로 꺾을 때 유압 램(피스톤)이 밀고 나가는 거리입니다. 슬라이더를 '
              '밀면 램이 실제로 내려오는 모습을 볼 수 있습니다.',
          1.0,
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
          '크랭크를 돌려 기어(노치) 한 칸을 넘길 때마다 꺾이는 각도입니다. '
              '슬라이더를 밀면 크랭크가 실제로 돌아갑니다.',
          1.0,
        ),
        takeup,
        gain,
        _GuideField(
          Icons.straighten,
          '노치 간격',
          '슈에 새겨진 노치와 노치 사이 거리(아직 마킹 계산에는 안 씁니다).',
          1.0,
        ),
        _GuideField(
          Icons.circle_outlined,
          '롤러 규격',
          '관을 위에서 눌러 주는 롤러(바퀴)의 지름(아직 마킹 계산에는 안 씁니다).',
          1.0,
        ),
        clr,
      ];
  }
}

class _FieldRow extends StatelessWidget {
  final _GuideField field;
  final VoidCallback onTap;
  const _FieldRow({required this.field, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
            const Icon(Icons.touch_app_outlined, size: 16, color: _slate600),
          ],
        ),
      ),
    );
  }
}

/// 벤더 옆모습 그림 — 실제 장비 몸체(수동=굽힘틀+손잡이, 유압=롤러 받침+
/// 유압 램, 시카고=톱니바퀴+크랭크)를 그린 뒤, 관이 들어와 굽혀 나가는 L자
/// 곡선에 테이크업(셋백)·게인·CLR을 공통으로 짚고, 종류별로 하나씩 더 짚는다.
/// [t]는 0~1(슬라이더 위치) — 더 이상 시간이 아니라 사용자가 직접 미는 값.
class _BenderDiagramPainter extends CustomPainter {
  final _BenderKind kind;
  final double t;
  _BenderDiagramPainter({required this.kind, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    paintDotGrid(canvas, size);

    // 캔버스 크기에 맞춰 늘어나는 치수 — 좁은 구석에 몰아 그리지 않고
    // 프레임 전체 가로·세로를 쓴다.
    const margin = 18.0;
    final baseY = h - margin;
    final curveR = (h * 0.17).clamp(26.0, 44.0);
    final entryY = h * 0.30;
    final turnX = w * 0.62;
    final exitY = baseY - 10;
    final startX = margin;
    final takeupGap = curveR * 1.15;
    final markX = math.max(startX + 36, turnX - curveR - takeupGap);
    final cornerCenter = Offset(turnX - curveR, entryY + curveR);
    final tt = t.clamp(0.0, 1.0);
    final pipeW = (curveR * 0.24).clamp(7.0, 10.0);

    // 바닥 기준선 + 장비가 서 있는 그림자(장비를 캔버스에 붙여 놓은 느낌).
    canvas.drawLine(
      Offset(cornerCenter.dx - curveR * 2.0, baseY),
      Offset(cornerCenter.dx + curveR * 2.2, baseY),
      Paint()
        ..color = _slate600.withValues(alpha: 0.22)
        ..strokeWidth = 1.2,
    );
    _groundShadow(canvas, Offset(cornerCenter.dx, baseY), curveR * 3.2);

    // 0) 실제 장비 몸체(고정 부분 + 슬라이더로 움직이는 부분).
    _drawMachineBody(
      canvas,
      kind,
      cornerCenter,
      curveR,
      startX,
      entryY,
      baseY,
      tt,
    );

    // 1) 들어오는 직선 관(마킹 자리까지).
    final leadT = stageT(t, 0.0, 0.16);
    paintPipeSegment(
      canvas,
      Offset(startX, entryY),
      Offset(markX, entryY),
      leadT,
      _slate600,
      width: pipeW,
    );
    _pipeCenterline(
      canvas,
      Offset(startX, entryY),
      Offset(markX, entryY),
      leadT,
    );

    // 2) 테이크업/셋백 안내 화살표 + 이름표.
    final takeT = stageT(t, 0.16, 0.30);
    if (takeT > 0) {
      final a = Offset(markX, entryY);
      final b = Offset(turnX, entryY);
      final tip = Offset.lerp(a, b, takeT)!;
      final arrow = Paint()
        ..color = kGuideOrange
        ..strokeWidth = 1.8;
      canvas.drawLine(a, tip, arrow);
      _arrowHead(canvas, a, tip, kGuideOrange);
      if (takeT > 0.7) {
        paintPill(
          canvas,
          kind == _BenderKind.ram ? '셋백' : '테이크업',
          Offset((a.dx + b.dx) / 2, entryY - 16),
          color: kGuideOrange,
          size: 10.5,
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
        partial.shift(const Offset(0, 1.6)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = pipeW + 1
          ..strokeCap = StrokeCap.round
          ..color = Colors.black.withValues(alpha: 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
      );
      canvas.drawPath(
        partial,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = pipeW
          ..strokeCap = StrokeCap.round
          ..color = AppColors.brand,
      );
      canvas.drawPath(
        partial,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = pipeW * 0.24
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.55),
      );
      canvas.drawPath(
        partial,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..color = Colors.black.withValues(alpha: 0.12),
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
      final rim = Offset.lerp(
        cornerCenter,
        Offset(turnX, entryY + curveR),
        clrT,
      )!;
      canvas.drawLine(
        cornerCenter,
        rim,
        Paint()
          ..color = AppColors.brand.withValues(alpha: 0.6)
          ..strokeWidth = 1.6,
      );
      if (clrT > 0.7) {
        paintPill(
          canvas,
          'CLR',
          Offset(turnX - curveR * 0.5, entryY + curveR + 14),
          color: AppColors.brand,
          size: 10,
        );
      }
    }

    // 6) 게인 이름표(직선 코너와 굽은 선의 차이).
    final gainT = stageT(t, 0.80, 0.92);
    if (gainT > 0.5) {
      paintPill(
        canvas,
        '게인',
        Offset(turnX - curveR - 8, entryY + curveR * 1.6),
        color: kGuideOrange,
        size: 10,
      );
    }

    // 7) 종류별 이름표 하나 더(장비 몸체 자체는 위 0번에서 이미 그렸다).
    final extraT = stageT(t, 0.86, 1.0);
    if (extraT > 0.7) {
      switch (kind) {
        case _BenderKind.hand:
          break;
        case _BenderKind.ram:
          paintPill(
            canvas,
            '램 이동 거리',
            Offset(cornerCenter.dx + curveR * 1.15, entryY - curveR * 1.35),
            color: kGuideOrange,
            size: 10,
          );
        case _BenderKind.chicago:
          paintPill(
            canvas,
            '노치당 각도',
            cornerCenter + Offset(curveR * 2.05, -6),
            color: kGuideOrange,
            size: 10,
          );
      }
    }
  }

  /// 실제 장비 몸체 — 항상 보이는 고정 부분 + [tt]에 따라 움직이는 부분.
  /// 그림자+그라데이션+하이라이트로 다른 그림 설명(롤링 오프셋 등)과 같은
  /// 입체감을 주고, curveR을 기준 단위로 삼아 캔버스 크기에 맞춰 커진다.
  void _drawMachineBody(
    Canvas canvas,
    _BenderKind kind,
    Offset cornerCenter,
    double curveR,
    double startX,
    double entryY,
    double baseY,
    double tt,
  ) {
    switch (kind) {
      case _BenderKind.hand:
        // 굽힘틀(슈) — 관이 실제로 눕는 두꺼운 초승달 모양 굽힘틀(실제 부피감).
        _shoeCrescent(
          canvas,
          cornerCenter,
          curveR * 1.58,
          curveR * 1.06,
          degToRad(-102),
          degToRad(112),
        );
        // 슈 시작점의 걸쇠(관을 무는 훅).
        final hookAngle = degToRad(-102);
        final hookAt =
            cornerCenter +
            Offset(math.cos(hookAngle), math.sin(hookAngle)) * curveR * 1.32;
        _metalKnob(canvas, hookAt, curveR * 0.13);
        // 손잡이 — 슈에서 반대쪽(위-왼쪽)으로 뻗어 나가는 긴 봉 + 그립 밴드.
        const handleAngle = -2.35; // 라디안, 위-왼쪽 방향.
        final dir = Offset(math.cos(handleAngle), math.sin(handleAngle));
        final base = cornerCenter + dir * (curveR * 1.12);
        final tip = cornerCenter + dir * (curveR * 2.55);
        final handleW = curveR * 0.30;
        paintPipeSegment(canvas, base, tip, 1.0, _metalDark, width: handleW);
        final perp = Offset(-dir.dy, dir.dx);
        for (double f = 0.22; f < 0.92; f += 0.17) {
          final p = Offset.lerp(base, tip, f)!;
          canvas.drawLine(
            p - perp * handleW * 0.62,
            p + perp * handleW * 0.62,
            Paint()
              ..color = Colors.black.withValues(alpha: 0.22)
              ..strokeWidth = 2.2,
          );
        }
        _metalKnob(canvas, base, curveR * 0.14);
        _metalKnob(canvas, tip, curveR * 0.24);
      case _BenderKind.ram:
        // 바닥 프레임 — 양쪽 받침을 하나로 묶어 주는 긴 판.
        final frameRect = Rect.fromLTRB(
          startX + curveR * 0.1,
          baseY - curveR * 0.22,
          cornerCenter.dx + curveR * 1.9,
          baseY - curveR * 0.02,
        );
        _metalPanel(
          canvas,
          RRect.fromRectAndRadius(frameRect, Radius.circular(curveR * 0.06)),
        );
        // 양쪽 롤러 받침 — 관을 받쳐 주는 받침대(각각 작은 바퀴 한 쌍).
        _rollerStand(
          canvas,
          Offset(startX + curveR * 0.7, entryY),
          baseY,
          curveR,
        );
        _rollerStand(
          canvas,
          Offset(cornerCenter.dx + curveR * 1.55, cornerCenter.dy + curveR),
          baseY,
          curveR,
        );
        // 유압 실린더 몸체 — 코너 위쪽 고정, 위는 둥근 캡+압력계.
        final ramX = cornerCenter.dx;
        final bodyH = curveR * 1.15;
        final bodyW = curveR * 0.95;
        final bodyBottom = entryY - curveR * 0.28;
        final bodyRect = Rect.fromLTRB(
          ramX - bodyW / 2,
          bodyBottom - bodyH,
          ramX + bodyW / 2,
          bodyBottom,
        );
        final bodyRRect = RRect.fromRectAndCorners(
          bodyRect,
          topLeft: Radius.circular(bodyW * 0.5),
          topRight: Radius.circular(bodyW * 0.5),
          bottomLeft: Radius.circular(curveR * 0.12),
          bottomRight: Radius.circular(curveR * 0.12),
        );
        canvas.drawRRect(
          bodyRRect.shift(const Offset(0, 2)),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.16)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
        );
        canvas.drawRRect(
          bodyRRect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_metal, _metalDark],
            ).createShader(bodyRect),
        );
        canvas.drawRRect(
          bodyRRect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.white.withValues(alpha: 0.22),
        );
        for (final f in [0.32, 0.56, 0.78]) {
          canvas.drawLine(
            Offset(bodyRect.left + bodyW * 0.12, bodyRect.top + bodyH * f),
            Offset(bodyRect.right - bodyW * 0.12, bodyRect.top + bodyH * f),
            Paint()
              ..color = Colors.black.withValues(alpha: 0.14)
              ..strokeWidth = 1,
          );
        }
        // 압력계 — 실린더 옆에 붙은 작은 다이얼 + 바늘.
        final gaugeCenter = Offset(
          bodyRect.right + curveR * 0.24,
          bodyRect.top + bodyH * 0.34,
        );
        final gaugeR = curveR * 0.2;
        canvas.drawCircle(
          gaugeCenter + const Offset(0, 1),
          gaugeR,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.12)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
        );
        canvas.drawCircle(gaugeCenter, gaugeR, Paint()..color = _pureWhite);
        canvas.drawCircle(
          gaugeCenter,
          gaugeR,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = _metalDark,
        );
        canvas.drawLine(
          gaugeCenter,
          gaugeCenter + Offset(gaugeR * 0.65, -gaugeR * 0.5 * (0.3 + tt * 0.7)),
          Paint()
            ..color = kGuideOrange
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round,
        );
        // 램(피스톤) — tt만큼 아래로 내려온다(0=올라감, 1=관에 닿음).
        final rodTop = Offset(ramX, bodyBottom - curveR * 0.02);
        final rodBottom = Offset(ramX, entryY - 1);
        paintPipeSegment(
          canvas,
          rodTop,
          rodBottom,
          tt,
          _metalDark,
          width: curveR * 0.2,
        );
        if (tt > 0.02) {
          _brandKnob(
            canvas,
            Offset.lerp(rodTop, rodBottom, tt)!,
            curveR * 0.18,
          );
        }
      case _BenderKind.chicago:
        // 받침판 — 바퀴 아래 작은 발판(볼트 두 개로 바닥에 고정된 느낌).
        final plateRect = Rect.fromCenter(
          center: Offset(cornerCenter.dx, baseY - curveR * 0.14),
          width: curveR * 1.3,
          height: curveR * 0.28,
        );
        _metalPanel(
          canvas,
          RRect.fromRectAndRadius(plateRect, Radius.circular(curveR * 0.06)),
        );
        _metalKnob(
          canvas,
          Offset(plateRect.left + curveR * 0.22, plateRect.center.dy),
          curveR * 0.06,
        );
        _metalKnob(
          canvas,
          Offset(plateRect.right - curveR * 0.22, plateRect.center.dy),
          curveR * 0.06,
        );
        // 톱니바퀴(노치 휠) — 관이 감기는 두꺼운 금속 링 + 허브 + 눈금.
        final wheelR = curveR * 1.5;
        _metalArc(canvas, cornerCenter, wheelR, 0, 2 * math.pi, curveR * 0.4);
        for (var i = 0; i < 16; i++) {
          final ang = i * (2 * math.pi / 16);
          final isLong = i % 4 == 0;
          final outer = wheelR + curveR * (isLong ? 0.34 : 0.2);
          final p1 =
              cornerCenter + Offset(math.cos(ang), math.sin(ang)) * wheelR;
          final p2 =
              cornerCenter + Offset(math.cos(ang), math.sin(ang)) * outer;
          canvas.drawLine(
            p1,
            p2,
            Paint()
              ..color = _metal
              ..strokeWidth = isLong ? 2.2 : 1.6,
          );
        }
        _metalKnob(canvas, cornerCenter, curveR * 0.26);
        // 크랭크 — tt만큼 돌아간다(노치를 한 칸씩 넘기는 T자 손잡이).
        final crankAngle = degToRad(200) + degToRad(150) * tt;
        final crankDir = Offset(math.cos(crankAngle), math.sin(crankAngle));
        final crankTip = cornerCenter + crankDir * (wheelR + curveR * 0.62);
        paintPipeSegment(
          canvas,
          cornerCenter,
          crankTip,
          1.0,
          _metalDark,
          width: curveR * 0.16,
        );
        final crankPerp = Offset(-crankDir.dy, crankDir.dx);
        final tBar = curveR * 0.32;
        final gripA = crankTip - crankPerp * tBar;
        final gripB = crankTip + crankPerp * tBar;
        paintPipeSegment(
          canvas,
          gripA,
          gripB,
          1.0,
          _metalDark,
          width: curveR * 0.13,
        );
        _metalKnob(canvas, gripA, curveR * 0.1);
        _metalKnob(canvas, gripB, curveR * 0.1);
    }
  }

  /// 롤러 받침 — 관을 받치는 작은 바퀴 한 쌍 + 기둥 + 바닥판.
  void _rollerStand(
    Canvas canvas,
    Offset pipeContact,
    double baseY,
    double curveR,
  ) {
    final baseCenter = Offset(pipeContact.dx, baseY - curveR * 0.12);
    paintPipeSegment(
      canvas,
      baseCenter,
      pipeContact + Offset(0, curveR * 0.14),
      1.0,
      _metal,
      width: curveR * 0.14,
    );
    _metalKnob(
      canvas,
      pipeContact + Offset(-curveR * 0.26, curveR * 0.08),
      curveR * 0.16,
    );
    _metalKnob(
      canvas,
      pipeContact + Offset(curveR * 0.26, curveR * 0.08),
      curveR * 0.16,
    );
    final plate = Rect.fromCenter(
      center: baseCenter,
      width: curveR * 0.9,
      height: curveR * 0.2,
    );
    _metalPanel(
      canvas,
      RRect.fromRectAndRadius(plate, Radius.circular(curveR * 0.05)),
    );
  }

  /// 판형 금속 부품(그림자+그라데이션+얇은 테두리) — 바닥 프레임·받침판 공용.
  void _metalPanel(Canvas canvas, RRect rrect) {
    canvas.drawRRect(
      rrect.shift(const Offset(0, 1.8)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_metal, _metalDark],
        ).createShader(rrect.outerRect),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  /// 두꺼운 초승달형 굽힘틀(슈) — 실제 부피가 있는 채워진 모양.
  void _shoeCrescent(
    Canvas canvas,
    Offset center,
    double rOuter,
    double rInner,
    double startAngle,
    double sweepAngle,
  ) {
    final endAngle = startAngle + sweepAngle;
    final fullPath = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: rOuter),
        startAngle,
        sweepAngle,
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: rInner),
        endAngle,
        -sweepAngle,
        false,
      )
      ..close();
    canvas.drawPath(
      fullPath.shift(const Offset(0, 2.2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6),
    );
    canvas.drawPath(
      fullPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_metal, _metalDark],
        ).createShader(fullPath.getBounds()),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: rOuter - 1.6),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.3),
    );
  }

  /// 부드러운 바닥 그림자 — 장비가 캔버스에 실제로 놓인 느낌을 준다.
  void _groundShadow(Canvas canvas, Offset center, double width) {
    final rect = Rect.fromCenter(
      center: center,
      width: width,
      height: width * 0.16,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2),
    );
  }

  /// 관 벽 두께를 암시하는 얇은 가운데 선(직선 구간용).
  void _pipeCenterline(Canvas canvas, Offset a, Offset b, double s) {
    if (s <= 0) return;
    final tip = Offset.lerp(a, b, s)!;
    canvas.drawLine(
      a,
      tip,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.10)
        ..strokeWidth = 1,
    );
  }

  /// 금속 아치/링(그림자+그라데이션 몸체+얇은 하이라이트) — 슈·톱니바퀴 공용.
  void _metalArc(
    Canvas canvas,
    Offset center,
    double radius,
    double startAngle,
    double sweepAngle,
    double strokeWidth,
  ) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect.shift(const Offset(0, 1.6)),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withValues(alpha: 0.13)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_metal, _metalDark],
        ).createShader(rect),
    );
    final hlRect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth * 0.3,
    );
    canvas.drawArc(
      hlRect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.32),
    );
  }

  /// 반짝이는 금속 손잡이/볼트(그림자+원형 그라데이션+하이라이트 점).
  void _metalKnob(Canvas canvas, Offset center, double r) {
    canvas.drawCircle(
      center + const Offset(0, 1.3),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.3),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [_metal, _metalDark],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    canvas.drawCircle(
      center - Offset(r * 0.32, r * 0.32),
      r * 0.32,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  /// 유압 램 끝(관에 닿는 부분) — 브랜드 색 반짝이는 점.
  void _brandKnob(Canvas canvas, Offset center, double r) {
    canvas.drawCircle(
      center + const Offset(0, 1.2),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [AppColors.brand.withValues(alpha: 0.85), AppColors.brand],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    canvas.drawCircle(
      center - Offset(r * 0.3, r * 0.3),
      r * 0.3,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
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
