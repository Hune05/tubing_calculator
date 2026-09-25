// 각도기. 플레이 스토어에서 많이 쓰는 각도기 앱의 두 쓰임을 따랐다:
//  ① 벤딩 각도 재기: 폰 옆면을 관 한쪽 다리에 대고 "기준", 다른 다리에 대면 굽힌 각.
//  ② 화면 각도기: 화면 위 반원 눈금에 두 팔을 끌어 물건 각을 잰다.
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'level_painters.dart';
import 'tilt_math.dart';
import 'tilt_sensor.dart';

const Color _teal = AppColors.brand;
const Color _ink = AppColors.text;
const Color _grey = AppColors.textSub;
const Color _bg = AppColors.background;
const Color _orange = Color(0xFFEA580C);

class ProtractorPage extends StatefulWidget {
  /// 센서 흐름. 비우면 폰 가속도 센서(검사에서는 가짜 흐름).
  final Stream<TiltSample> Function()? source;
  final Duration noSensorAfter;

  /// 처음 열 탭(0: 벤딩 각도, 1: 화면 각도기).
  final int initialTab;

  const ProtractorPage({
    super.key,
    this.source,
    this.noSensorAfter = const Duration(seconds: 3),
    this.initialTab = 0,
  });

  @override
  State<ProtractorPage> createState() => _ProtractorPageState();
}

class _ProtractorPageState extends State<ProtractorPage> {
  final _session = FieldToolSession();
  final _smooth = TiltSmoother(alpha: 0.2);
  StreamSubscription<TiltSample>? _sub;
  Timer? _noSensorTimer;

  TiltSample? _last;
  bool _noSensor = false;
  bool _hold = false;
  double? _reference; // 기준으로 잡은 화면 돌림(°)

  // 화면 각도기 두 팔(°, 0 = 오른쪽, 180 = 왼쪽)
  double _armA = 0;
  double _armB = 60;

  @override
  void initState() {
    super.initState();
    _session.begin();
    _noSensorTimer = Timer(widget.noSensorAfter, () {
      if (mounted && _last == null) setState(() => _noSensor = true);
    });
    _sub = (widget.source ?? deviceTiltStream)().listen(
      (s) {
        if (!mounted) return;
        _noSensorTimer?.cancel();
        if (_hold) return;
        final v = _smooth.add(s.x, s.y, s.z);
        setState(() {
          _noSensor = false;
          _last = v;
        });
      },
      onError: (_) {
        if (mounted) setState(() => _noSensor = true);
      },
      cancelOnError: true,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _noSensorTimer?.cancel();
    _session.end();
    super.dispose();
  }

  double get _rotation =>
      _last == null ? 0 : screenRotation(_last!.x, _last!.y);

  bool get _tooFlat =>
      _last != null && tooFlatForRotation(_last!.x, _last!.y, _last!.z);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: _ink,
          title: const Text(
            "각도기",
            style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
          ),
          bottom: const TabBar(
            labelColor: _teal,
            unselectedLabelColor: _grey,
            indicatorColor: _teal,
            labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            tabs: [
              Tab(key: Key('tab_bend'), text: "벤딩 각도 재기"),
              Tab(key: Key('tab_screen'), text: "화면 각도기"),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            physics: const NeverScrollableScrollPhysics(), // 팔 끌기와 겹치지 않게
            children: [_bendTab(), _screenTab()],
          ),
        ),
      ),
    );
  }

  // ── ① 벤딩 각도 재기 ──

  // NixGame "각도 측정" 모양: 화면을 흰·파랑으로 나누는 선이 진짜 수직을 가리키고,
  // 기준을 잡으면 기준선과 지금 선 사이가 빨간 쐐기, 그 각이 굽힌 각이다.
  Widget _bendTab() {
    if (_noSensor) {
      return const Center(
        key: Key('protractor_no_sensor'),
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            "이 기기에서는 기울기 센서를 읽을 수 없습니다.\n폰에서 여시거나 '화면 각도기'를 쓰십시오.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: _grey, height: 1.5),
          ),
        ),
      );
    }
    final hasRef = _reference != null;
    final bend = hasRef ? angleDiff(_rotation, _reference!).abs() : null;
    final tilt = _edgeTilt(_rotation);
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final c = size.center(Offset.zero);
        final up = upOnScreen(_rotation);
        final right = Offset(-up.dy, up.dx);
        TextStyle big(Color color, double fs) => TextStyle(
          fontSize: fs,
          fontWeight: FontWeight.w500,
          color: _tooFlat ? _grey : color,
          height: 1,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
        Widget at(Offset p, Widget child) => Positioned(
          left: p.dx - 110,
          top: p.dy - 45,
          width: 220,
          height: 90,
          child: IgnorePointer(
            child: Center(
              child: FittedBox(fit: BoxFit.scaleDown, child: child),
            ),
          ),
        );
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: SplitLevelPainter(
                  rotationDeg: _rotation,
                  referenceDeg: _reference,
                ),
              ),
            ),
            // 흰 쪽: 지금 폰 옆면 기울기(작게)
            at(
              c - right * (size.width * 0.22) - up * (size.height * 0.10),
              Text(
                _last == null ? "--" : "${tilt.toStringAsFixed(1)}°",
                key: const Key('bend_tilt'),
                style: big(kLevelBlue, hasRef ? 40 : 60),
              ),
            ),
            // 파랑 쪽: 굽힌 각(크게)
            if (hasRef)
              at(
                c + right * (size.width * 0.20) + up * (size.height * 0.08),
                Text(
                  _last == null ? "--" : "${bend!.toStringAsFixed(1)}°",
                  key: const Key('bend_value'),
                  style: big(Colors.white, 64),
                ),
              ),
            // 위쪽 안내·경고
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _pill(
                    hasRef
                        ? "② 굽힌 다리에 대면 굽힌 각입니다"
                        : "① 폰을 세워 긴 옆면을 곧은 다리에 대고 '기준 잡기'",
                    _ink,
                  ),
                  if (hasRef && _last != null)
                    _pill(
                      "두 다리 사이 각 ${(180 - bend!).toStringAsFixed(1)}°",
                      kLevelBlue,
                      key: const Key('bend_inner'),
                    ),
                  if (_hold) _pill("고정됨", Colors.orange),
                  if (_tooFlat)
                    _pill(
                      "폰을 세워서 관에 대십시오. 눕히면 각을 잴 수 없습니다.",
                      _orange,
                      key: const Key('bend_too_flat'),
                    ),
                ],
              ),
            ),
            // 아래 단추
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('bend_reference'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        backgroundColor: kLevelBlue,
                      ),
                      onPressed: (_last == null || _tooFlat)
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _hold = false;
                                _reference = _rotation;
                              });
                            },
                      icon: const Icon(Icons.flag_outlined),
                      label: Text(hasRef ? "기준 다시" : "기준 잡기"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  RoundToolButton(
                    key: const Key('bend_hold'),
                    icon: _hold ? Icons.lock_open : Icons.pause,
                    tooltip: _hold ? "고정 풀기" : "값 고정",
                    color: _hold ? Colors.orange : kLevelBlue,
                    active: _hold,
                    onTap: _last == null
                        ? null
                        : () => setState(() => _hold = !_hold),
                  ),
                  if (hasRef) ...[
                    const SizedBox(width: 8),
                    RoundToolButton(
                      key: const Key('bend_clear'),
                      icon: Icons.restart_alt,
                      tooltip: "기준 지우기",
                      onTap: () => setState(() {
                        _reference = null;
                        _hold = false;
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _pill(String text, Color color, {Key? key}) => Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
    ),
  );

  /// 폰이 가장 가까운 수직·수평에서 벗어난 각(0~45°). NixGame "각도 측정"의 작은 숫자.
  double _edgeTilt(double rotation) =>
      angleDiff(rotation, (rotation / 90).round() * 90.0).abs();

  // ── ② 화면 각도기 ──

  Widget _screenTab() {
    final between = armsBetween(_armA, _armB);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            "${between.toStringAsFixed(1)}°",
            key: const Key('screen_value'),
            style: const TextStyle(
              fontSize: 60,
              fontWeight: FontWeight.w900,
              color: _ink,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const Text(
          "물건을 화면 아래 가운데에 대고 두 팔을 끌어 맞춥니다.",
          style: TextStyle(color: _grey),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final size = c.biggest;
              final center = Offset(size.width / 2, size.height - 24);
              void drag(Offset p) {
                final a = armAngle(center.dx, center.dy, p.dx, p.dy);
                setState(() {
                  // 가까운 팔을 옮긴다.
                  if ((a - _armA).abs() <= (a - _armB).abs()) {
                    _armA = a;
                  } else {
                    _armB = a;
                  }
                });
              }

              return GestureDetector(
                key: const Key('screen_protractor'),
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => drag(d.localPosition),
                onPanUpdate: (d) => drag(d.localPosition),
                onTapDown: (d) => drag(d.localPosition),
                child: CustomPaint(
                  size: size,
                  painter: _ProtractorPainter(
                    center: center,
                    armA: _armA,
                    armB: _armB,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 반원 눈금 + 두 팔.
class _ProtractorPainter extends CustomPainter {
  final Offset center;
  final double armA, armB;
  _ProtractorPainter({
    required this.center,
    required this.armA,
    required this.armB,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width / 2 - 12, size.height - 40);
    if (r <= 20) return;
    Offset at(double deg, double rr) {
      final t = deg * math.pi / 180;
      return center + Offset(math.cos(t) * rr, -math.sin(t) * rr);
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      math.pi,
      math.pi,
      true,
      Paint()..color = _bg,
    );
    final tick = Paint()
      ..color = _ink.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (int d = 0; d <= 180; d++) {
      final len = d % 10 == 0 ? 18.0 : (d % 5 == 0 ? 11.0 : 6.0);
      tick.strokeWidth = d % 10 == 0 ? 2 : 1;
      canvas.drawLine(at(d.toDouble(), r), at(d.toDouble(), r - len), tick);
      if (d % 10 == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: "$d",
            style: const TextStyle(fontSize: 11, color: _ink),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final p = at(d.toDouble(), r - 30);
        tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
      }
    }
    // 두 팔 사이 부채꼴
    final lo = math.min(armA, armB), hi = math.max(armA, armB);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r * 0.45),
      -hi * math.pi / 180,
      (hi - lo) * math.pi / 180,
      true,
      Paint()..color = _teal.withValues(alpha: 0.15),
    );
    void arm(double deg, Color color) {
      final p = Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final end = at(deg, r + 6);
      canvas.drawLine(center, end, p);
      canvas.drawCircle(end, 11, Paint()..color = color);
      canvas.drawCircle(end, 5, Paint()..color = Colors.white);
    }

    arm(armA, _teal);
    arm(armB, _orange);
    canvas.drawCircle(center, 6, Paint()..color = _ink);
  }

  @override
  bool shouldRepaint(_ProtractorPainter old) =>
      old.armA != armA || old.armB != armB || old.center != center;
}
