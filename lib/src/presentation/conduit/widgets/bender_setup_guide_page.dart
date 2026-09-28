/// 전선관 설정 화면 헤더의 "장비 사용법" — 수동·유압식·시카고식 벤더를
/// 처음 만지는 사람도 순서대로 따라 할 수 있게, 실제 조작 절차(현장 자료 →
/// 장비 사용법 탭 4·5·6번과 같은 내용)를 그림으로 보여 준다.
/// (제원 칸을 내 장비에서 실제로 재는 방법은 그 탭의 "실측 캘리브레이션"에
/// 이미 있어서 여기서 다시 안 적는다 — 이 화면은 "어떻게 조작하는지"만.)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/presentation/common/guide_paint_kit.dart';

const Color _slate900 = AppColors.text;
const Color _slate600 = AppColors.textSub;
const Color _pureWhite = Color(0xFFFFFFFF);
const Color _slate100 = AppColors.background;
const Color _metal = Color(0xFF90A4AE); // blueGrey300 — 장비 몸체.
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
            '벤더 사용법',
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

class _UsageStep {
  final IconData icon;
  final String title;
  final String detail;
  const _UsageStep(this.icon, this.title, this.detail);
}

List<_UsageStep> _stepsFor(_BenderKind kind) {
  switch (kind) {
    case _BenderKind.hand:
      return const [
        _UsageStep(
          Icons.center_focus_strong,
          '마킹을 화살표에 맞춘다',
          '관에 그은 마킹선을 슈의 화살표(Arrow)에 맞춰 끼운다. 두 번째를 '
              '뒤로 꺾을 때는 별(Star) 표시에 맞춘다.',
        ),
        _UsageStep(
          Icons.pan_tool_alt,
          '발판을 밟으며 핸들을 당긴다',
          '발판을 밟은 채 핸들을 한 번에 지그시 당겨 꺾는다. 멈췄다 다시 '
              '당기면 관에 자국이 남는다.',
        ),
        _UsageStep(
          Icons.rule,
          '각도 + 스프링백 확인',
          '슈 눈금이 목표 각도보다 스프링백만큼(후강 3~5°) 더 간 곳에서 '
              '멈춘다. 바닥에 관이 뜨면 각이 모자란 것이다.',
        ),
      ];
    case _BenderKind.ram:
      return const [
        _UsageStep(
          Icons.build_circle_outlined,
          '슈·받침 고르기',
          '관 규격과 같은 슈를 램에 끼우고, 받침 롤러를 프레임의 그 규격 '
              '구멍에 핀으로 끝까지 꽂는다. 핀이 덜 들어가면 절대 밀지 않는다.',
        ),
        _UsageStep(
          Icons.center_focus_strong,
          '셋백 마크 맞추기',
          '마킹선(셋백을 뺀 자리)을 슈 가운데 표시에 맞춘다. 관은 받침 '
              '롤러 양쪽에 고르게 걸친다.',
        ),
        _UsageStep(
          Icons.compress,
          '펌프질로 밀기',
          '펌프 밸브를 잠그고 펌프질한다(전동은 스위치). 램 눈금이 설정한 '
              "'램 이동 거리'까지 오면 멈추고 각도기로 확인한다.",
        ),
        _UsageStep(
          Icons.replay,
          '천천히 되돌리기',
          '릴리스 밸브를 천천히 열어 램을 넣는다. 갑자기 열면 슈가 튄다. '
              '관을 빼고 다음 마킹으로.',
        ),
      ];
    case _BenderKind.chicago:
      return const [
        _UsageStep(
          Icons.build_circle_outlined,
          '롤러·슈에 넣기',
          '관 규격에 맞는 롤러 규격과 슈 홈에 관을 넣는다. 훅(고리)이 관을 '
              '꽉 눌러야 한다.',
        ),
        _UsageStep(
          Icons.center_focus_strong,
          '0점·마킹 맞추기',
          '노치 휠을 0점에 두고 마킹선(테이크업을 뺀 자리)을 슈 표시에 '
              '맞춘다.',
        ),
        _UsageStep(
          Icons.settings,
          '크랭크로 노치 세기',
          '크랭크를 돌리며 넘어가는 노치 칸을 센다. 칸 수 = 목표 각도 ÷ '
              '노치당 각도(설정값). 스프링백만큼 한두 칸 더.',
        ),
        _UsageStep(
          Icons.replay,
          '래칫 풀고 되돌리기',
          '래칫을 풀고 크랭크를 되돌린다. 관을 빼기 전에 훅을 먼저 푼다.',
        ),
      ];
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
    duration: const Duration(milliseconds: 4200),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _stepsFor(widget.kind);
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
              painter: _BenderUsagePainter(
                kind: widget.kind,
                t: _c.value,
                stepCount: steps.length,
              ),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final idx = (_c.value * steps.length).floor().clamp(
                0,
                steps.length - 1,
              );
              final s = steps[idx];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: const BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${idx + 1}',
                      style: const TextStyle(
                        color: _pureWhite,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _slate900,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            '전체 순서',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _slate600,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < steps.length; i++)
            _StepRow(index: i + 1, step: steps[i]),
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
                    '테이크업·게인 같은 제원 값을 내 장비에서 실제로 재는 '
                    '방법(줄자 대는 법·계산식)은 현장 자료 → 장비 사용법 탭의 '
                    '"내 장비 실측 캘리브레이션"에 자세히 있습니다.',
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

class _StepRow extends StatelessWidget {
  final int index;
  final _UsageStep step;
  const _StepRow({required this.index, required this.step});

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
            child: Icon(step.icon, size: 18, color: AppColors.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$index. ${step.title}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _slate900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  step.detail,
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

/// 벤더 옆모습 그림 — 장비 몸체(수동=굽힘틀+손잡이, 유압=롤러 받침+유압
/// 램, 시카고=톱니바퀴+크랭크)를 고정으로 그린 뒤, [t](0~1, 자동 재생)를
/// stepCount 등분해 각 구간마다 "지금 이 동작을 한다"를 움직임으로 보여
/// 준다. 실측 방법이 아니라 조작 순서만 보여 준다.
class _BenderUsagePainter extends CustomPainter {
  final _BenderKind kind;
  final double t;
  final int stepCount;
  _BenderUsagePainter({
    required this.kind,
    required this.t,
    required this.stepCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    paintDotGrid(canvas, size);

    final entryY = h * 0.38;
    final turnX = w * 0.54;
    final exitY = h * 0.90;
    const curveR = 27.0;
    final startX = 16.0;
    final markX = turnX - curveR - 34;
    final cornerCenter = Offset(turnX - curveR, entryY + curveR);

    switch (kind) {
      case _BenderKind.hand:
        _paintHand(canvas, cornerCenter, curveR, startX, entryY, exitY);
      case _BenderKind.ram:
        _paintRam(
          canvas,
          cornerCenter,
          curveR,
          startX,
          entryY,
          exitY,
          turnX,
          markX,
        );
      case _BenderKind.chicago:
        _paintChicago(
          canvas,
          cornerCenter,
          curveR,
          startX,
          entryY,
          exitY,
          turnX,
          markX,
        );
    }
  }

  // 스텝을 stepCount 등분한 구간 도우미 — [i]번째 스텝은 [t] ∈ [i/n, (i+1)/n).
  // curStep(i)는 "지금 이 스텝을 보여줄 차례"만 참(다음 스텝이 되면 꺼진다),
  // localT(i)는 그 스텝 안에서의 0~1 진행도다. 손잡이·램·크랭크처럼 "다음
  // 스텝에서도 그 자리를 유지해야 하는" 움직임은 이 도우미로 직접 계산한다.
  double _stepStart(int i) => i / stepCount;
  double _stepEnd(int i) => (i + 1) / stepCount;
  int _curStep() => (t * stepCount).floor().clamp(0, stepCount - 1);
  double _localT(int i) =>
      ((t - _stepStart(i)) / (_stepEnd(i) - _stepStart(i))).clamp(0.0, 1.0);

  // ── 수동 벤더: ①화살표에 맞추기 ②발판+핸들로 꺾기 ③각도 확인 ──
  void _paintHand(
    Canvas canvas,
    Offset cornerCenter,
    double curveR,
    double startX,
    double entryY,
    double exitY,
  ) {
    final turnX = cornerCenter.dx + curveR;
    final markX = turnX - curveR - 34;
    final curStep = _curStep();

    // 슈(굽힘틀) + 화살표·별 표시 — 항상 보이는 고정 장비.
    _metalArc(canvas, cornerCenter, curveR + 8, -math.pi / 2, math.pi / 2, 15);
    final arrowAt =
        cornerCenter + const Offset(0, -1) * (curveR + 8); // 슈 위쪽 끝(화살표 자리).
    paintGuideIcon(canvas, Icons.arrow_downward, arrowAt, 13, _metalDark);
    final starAt = cornerCenter + Offset(curveR + 8, 0); // 슈 옆(별 자리).
    paintGuideIcon(canvas, Icons.star, starAt, 11, _metalDark);

    // 관이 들어오는 정도 — 0단계에서 들어와 그 뒤로는 계속 그 자리에 있다.
    final leadP = t < _stepEnd(0) ? _localT(0) : 1.0;
    paintPipeSegment(
      canvas,
      Offset(startX, entryY),
      Offset(markX, entryY),
      leadP,
      _slate600,
      width: 8,
    );

    // 0단계: 화살표에 맞추는 중일 때만 강조.
    if (curStep == 0) {
      final l = _localT(0);
      if (l > 0.6) {
        canvas.drawCircle(
          arrowAt,
          9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = kGuideOrange.withValues(alpha: 0.7),
        );
      }
      if (l > 0.8) {
        paintPill(
          canvas,
          '화살표에 맞춤',
          Offset(markX - 4, entryY - 16),
          color: kGuideOrange,
          size: 9.5,
        );
      }
    }

    // 핸들 각도 + 벤드 진행도 — 1단계에서 움직이고, 그 뒤로는 유지된다.
    double swingP;
    if (t < _stepStart(1)) {
      swingP = 0;
    } else if (t < _stepEnd(1)) {
      swingP = _localT(1);
    } else {
      swingP = 1.0;
    }
    final handleAngle = degToRad(-135) + degToRad(35) * swingP;
    final hDir = Offset(math.cos(handleAngle), math.sin(handleAngle));
    final hBase = cornerCenter + hDir * (curveR + 8);
    final hTip = cornerCenter + hDir * (curveR * 2.3);
    paintPipeSegment(canvas, hBase, hTip, 1.0, _metalDark, width: 9);
    _metalKnob(canvas, hTip, 7);
    if (swingP > 0) {
      final path = Path()
        ..moveTo(markX, entryY)
        ..lineTo(turnX - curveR, entryY)
        ..quadraticBezierTo(turnX, entryY, turnX, entryY + curveR)
        ..lineTo(turnX, exitY);
      final metrics = path.computeMetrics().first;
      final partial = metrics.extractPath(0, metrics.length * swingP);
      _drawBentPipe(canvas, partial);
    }
    if (curStep == 1 && _localT(1) > 0.6) {
      paintPill(
        canvas,
        '발판+핸들로 꺾기',
        Offset(cornerCenter.dx - curveR * 0.4, entryY - curveR * 1.5),
        color: kGuideOrange,
        size: 9.5,
      );
    }

    // 2단계: 각도 확인(체크 표시 + 각도 이름표).
    if (curStep == 2) {
      final l = _localT(2);
      if (l > 0.3) {
        final chip = cornerCenter + Offset(curveR * 1.6, curveR * 0.4);
        paintGuideIcon(canvas, Icons.check_circle, chip, 16, AppColors.brand);
        if (l > 0.55) {
          paintPill(
            canvas,
            '각도 + 스프링백 확인',
            chip + const Offset(0, 16),
            color: AppColors.brand,
            size: 9.5,
          );
        }
      }
    }
  }

  // ── 유압식: ①슈·받침 고르기 ②셋백 마크 맞추기 ③펌프질 ④되돌리기 ──
  void _paintRam(
    Canvas canvas,
    Offset cornerCenter,
    double curveR,
    double startX,
    double entryY,
    double exitY,
    double turnX,
    double markX,
  ) {
    final curStep = _curStep();
    // 고정 장비 — 롤러 받침 두 개 + 유압 실린더.
    _drawRollerSupport(canvas, Offset(startX + 20, entryY + 4));
    final support2 = Offset(
      cornerCenter.dx + curveR * 1.7,
      cornerCenter.dy + curveR,
    );
    _drawRollerSupport(canvas, support2);
    final ramX = cornerCenter.dx;
    final bodyTopY = entryY - curveR * 1.5;
    final bodyRect = Rect.fromCenter(
      center: Offset(ramX, bodyTopY),
      width: curveR * 0.9,
      height: curveR,
    );
    final bodyRRect = RRect.fromRectAndRadius(
      bodyRect,
      Radius.circular(curveR * 0.2),
    );
    canvas.drawRRect(
      bodyRRect.shift(const Offset(0, 1.8)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
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

    // 0단계: 핀 강조(슈·받침 고르기) — 이 단계일 때만 보인다.
    if (curStep == 0) {
      final l = _localT(0);
      if (l > 0.3) {
        final pinAt = support2 + Offset(-curveR * 0.28, curveR * 0.05);
        canvas.drawCircle(
          pinAt,
          7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = kGuideOrange.withValues(alpha: 0.8),
        );
      }
      if (l > 0.6) {
        paintPill(
          canvas,
          '핀 끝까지 꽂기',
          support2 + const Offset(0, 18),
          color: kGuideOrange,
          size: 9,
        );
      }
    }

    // 관이 셋백 마크로 들어오는 정도 — 1단계에서 들어와 그 뒤로는 유지.
    final leadP = t < _stepEnd(1)
        ? (t < _stepStart(1) ? 0.0 : _localT(1))
        : 1.0;
    paintPipeSegment(
      canvas,
      Offset(startX, entryY),
      Offset(markX, entryY),
      leadP,
      _slate600,
      width: 8,
    );
    if (curStep == 1 && _localT(1) > 0.6) {
      paintPill(
        canvas,
        '셋백 마크 맞춤',
        Offset(markX - 6, entryY - 16),
        color: kGuideOrange,
        size: 9.5,
      );
    }

    // 램 신장(2단계에서 밀고 나가고, 3단계에서 되돌아간다) + 그에 맞춘 벤드.
    final rodTop = Offset(ramX, bodyRect.bottom - 2);
    final rodBottom = Offset(ramX, entryY - 1);
    double rodExt;
    if (t < _stepStart(2)) {
      rodExt = 0;
    } else if (t < _stepEnd(2)) {
      rodExt = _localT(2);
    } else {
      rodExt = 1 - _localT(3);
    }
    paintPipeSegment(canvas, rodTop, rodBottom, rodExt, _metalDark, width: 7);
    if (rodExt > 0.02) {
      _brandKnob(canvas, Offset.lerp(rodTop, rodBottom, rodExt)!, 6);
    }
    final bendP = t < _stepEnd(2) ? rodExt : 1.0;
    if (bendP > 0) {
      final path = Path()
        ..moveTo(markX, entryY)
        ..lineTo(turnX - curveR, entryY)
        ..quadraticBezierTo(turnX, entryY, turnX, entryY + curveR)
        ..lineTo(turnX, exitY);
      final metrics = path.computeMetrics().first;
      final partial = metrics.extractPath(0, metrics.length * bendP);
      _drawBentPipe(canvas, partial);
    }
    final rodMid = Offset(ramX + curveR * 1.6, (bodyRect.bottom + entryY) / 2);
    if (curStep == 2 && _localT(2) > 0.6) {
      paintPill(canvas, '펌프질로 밀기', rodMid, color: kGuideOrange, size: 9.5);
    }
    if (curStep == 3 && _localT(3) > 0.3) {
      paintPill(canvas, '천천히 되돌리기', rodMid, color: AppColors.brand, size: 9.5);
    }
  }

  // ── 시카고식: ①롤러·슈에 넣기 ②0점·마킹 ③크랭크로 노치 세기 ④되돌리기 ──
  void _paintChicago(
    Canvas canvas,
    Offset cornerCenter,
    double curveR,
    double startX,
    double entryY,
    double exitY,
    double turnX,
    double markX,
  ) {
    final curStep = _curStep();
    final wheelR = curveR + 9;
    _metalArc(canvas, cornerCenter, wheelR, 0, 2 * math.pi, 12);
    for (var i = 0; i < 10; i++) {
      final ang = i * (2 * math.pi / 10);
      final p1 = cornerCenter + Offset(math.cos(ang), math.sin(ang)) * wheelR;
      final p2 =
          cornerCenter +
          Offset(math.cos(ang), math.sin(ang)) * (wheelR + curveR * 0.22);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = _metal
          ..strokeWidth = 1.8,
      );
    }
    _metalKnob(canvas, cornerCenter, curveR * 0.22);

    // 0단계: 훅(관 넣는 자리) 강조 — 이 단계일 때만 보인다.
    final hookAt = cornerCenter + Offset(-wheelR * 0.75, -wheelR * 0.5);
    if (curStep == 0) {
      final l = _localT(0);
      if (l > 0.3) {
        canvas.drawCircle(
          hookAt,
          8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = kGuideOrange.withValues(alpha: 0.8),
        );
      }
      if (l > 0.6) {
        paintPill(
          canvas,
          '롤러·슈에 넣기',
          hookAt + const Offset(0, -16),
          color: kGuideOrange,
          size: 9,
        );
      }
    }

    // 관이 0점으로 들어오는 정도 — 1단계에서 들어와 그 뒤로는 유지.
    final leadP = t < _stepEnd(1)
        ? (t < _stepStart(1) ? 0.0 : _localT(1))
        : 1.0;
    paintPipeSegment(
      canvas,
      Offset(startX, entryY),
      Offset(markX, entryY),
      leadP,
      _slate600,
      width: 8,
    );
    if (curStep == 1 && _localT(1) > 0.6) {
      paintPill(
        canvas,
        '0점·마킹 맞춤',
        Offset(markX - 4, entryY - 16),
        color: kGuideOrange,
        size: 9.5,
      );
    }

    // 크랭크 회전(2단계에서 돌리고, 3단계에서 되돌린다) + 그에 맞춘 벤드.
    double crankP;
    if (t < _stepStart(2)) {
      crankP = 0;
    } else if (t < _stepEnd(2)) {
      crankP = _localT(2);
    } else {
      crankP = 1 - _localT(3);
    }
    final crankAngle = degToRad(200) + degToRad(150) * crankP;
    _drawCrank(canvas, cornerCenter, wheelR, crankAngle, curveR);
    final bendP = t < _stepEnd(2) ? crankP : 1.0;
    if (bendP > 0) {
      final path = Path()
        ..moveTo(markX, entryY)
        ..lineTo(turnX - curveR, entryY)
        ..quadraticBezierTo(turnX, entryY, turnX, entryY + curveR)
        ..lineTo(turnX, exitY);
      final metrics = path.computeMetrics().first;
      final partial = metrics.extractPath(0, metrics.length * bendP);
      _drawBentPipe(canvas, partial);
    }
    if (curStep == 2 && _localT(2) > 0.6) {
      paintPill(
        canvas,
        '크랭크로 노치 세기',
        cornerCenter + Offset(wheelR + curveR * 0.7, -4),
        color: kGuideOrange,
        size: 9.5,
      );
    }
    if (curStep == 3 && _localT(3) > 0.3) {
      paintPill(
        canvas,
        '래칫 풀고 되돌리기',
        cornerCenter + Offset(wheelR + curveR * 0.7, -4),
        color: AppColors.brand,
        size: 9.5,
      );
    }
  }

  void _drawCrank(
    Canvas canvas,
    Offset center,
    double wheelR,
    double angle,
    double curveR,
  ) {
    final dir = Offset(math.cos(angle), math.sin(angle));
    final tip = center + dir * (wheelR + curveR * 0.6);
    paintPipeSegment(canvas, center, tip, 1.0, _metalDark, width: 6);
    _metalKnob(canvas, tip, 6);
  }

  void _drawBentPipe(Canvas canvas, Path partial) {
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

  void _drawRollerSupport(Canvas canvas, Offset topCenter) {
    final path = Path()
      ..moveTo(topCenter.dx, topCenter.dy + 2)
      ..lineTo(topCenter.dx - 11, topCenter.dy + 19)
      ..lineTo(topCenter.dx + 11, topCenter.dy + 19)
      ..close();
    final rect = Rect.fromLTWH(topCenter.dx - 11, topCenter.dy, 22, 19);
    canvas.drawPath(
      path.shift(const Offset(0, 1.6)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_metal, _metalDark],
        ).createShader(rect),
    );
    _metalKnob(canvas, topCenter, 4.5);
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

  @override
  bool shouldRepaint(_BenderUsagePainter old) =>
      old.t != t || old.kind != kind || old.stepCount != stepCount;
}
