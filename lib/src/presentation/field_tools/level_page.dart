// 수평계. 플레이 스토어에서 많이 쓰는 기포 수평계 앱의 모양을 따랐다:
// 눕히면 둥근 기포(두 방향), 세우면 기포관(한 방향), 큰 숫자, 수평이면 초록.
// 배관 구배를 보려고 %·mm/m 단위, 영점 맞추기, 값 고정을 둔다.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tilt_math.dart';
import 'tilt_sensor.dart';

const Color _teal = Color(0xFF007580);
const Color _ink = Color(0xFF191F28);
const Color _grey = Color(0xFF8B95A1);
const Color _bg = Color(0xFFF2F4F6);
const Color _ok = Color(0xFF16A34A);
const Color _okSoft = Color(0xFFDCFCE7);
const Color _liquid = Color(0xFFD9F99D);

const String kLevelCalibKey = 'field_level_calib_v1';
const String kLevelUnitKey = 'field_level_unit_v1';

class LevelPage extends StatefulWidget {
  /// 센서 흐름. 비우면 폰 가속도 센서(검사에서는 가짜 흐름을 넣는다).
  final Stream<TiltSample> Function()? source;

  /// 센서 값이 이만큼 안 오면 "센서 없음"으로 본다.
  final Duration noSensorAfter;

  const LevelPage({
    super.key,
    this.source,
    this.noSensorAfter = const Duration(seconds: 3),
  });

  @override
  State<LevelPage> createState() => _LevelPageState();
}

class _LevelPageState extends State<LevelPage> {
  final _session = FieldToolSession();
  final _smooth = TiltSmoother();
  StreamSubscription<TiltSample>? _sub;
  Timer? _noSensorTimer;

  TiltSample? _last; // 부드럽게 한 값
  TiltPose _pose = TiltPose.flat;
  bool _noSensor = false;
  bool _hold = false;
  bool _wasLevel = false;
  SlopeUnit _unit = SlopeUnit.degree;

  // 영점: flat_x, flat_y, upright_x, sideways_y (°)
  Map<String, double> _calib = {};

  @override
  void initState() {
    super.initState();
    _session.begin();
    _loadPrefs();
    _noSensorTimer = Timer(widget.noSensorAfter, () {
      if (mounted && _last == null) setState(() => _noSensor = true);
    });
    _sub = (widget.source ?? deviceTiltStream)().listen(
      _onSample,
      onError: (_) {
        if (mounted) setState(() => _noSensor = true);
      },
      cancelOnError: true,
    );
  }

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(kLevelCalibKey);
      final unit = p.getInt(kLevelUnitKey);
      if (!mounted) return;
      setState(() {
        if (raw != null) {
          _calib = (jsonDecode(raw) as Map).map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
          );
        }
        if (unit != null && unit >= 0 && unit < SlopeUnit.values.length) {
          _unit = SlopeUnit.values[unit];
        }
      });
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(kLevelCalibKey, jsonEncode(_calib));
      await p.setInt(kLevelUnitKey, _unit.index);
    } catch (_) {}
  }

  void _onSample(TiltSample s) {
    if (!mounted) return;
    _noSensorTimer?.cancel();
    if (_hold) return;
    final v = _smooth.add(s.x, s.y, s.z);
    setState(() {
      _noSensor = false;
      _last = v;
      _pose = poseFor(v.x, v.y, v.z, current: _pose);
    });
    final level = _isLevelNow();
    if (level && !_wasLevel) HapticFeedback.selectionClick();
    _wasLevel = level;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _noSensorTimer?.cancel();
    _session.end();
    super.dispose();
  }

  // ── 지금 각도 ──

  double _raw(String axis) {
    final v = _last!;
    final a = axis == 'x' ? v.x : v.y;
    return axisElevation(a, v.x, v.y, v.z);
  }

  /// 눕힘: (좌우, 앞뒤). 세움: 한 값(두 번째는 0).
  (double, double) _angles() {
    if (_last == null) return (0, 0);
    switch (_pose) {
      case TiltPose.flat:
        return (
          _raw('x') - (_calib['flat_x'] ?? 0),
          _raw('y') - (_calib['flat_y'] ?? 0),
        );
      case TiltPose.upright:
        return (_raw('x') - (_calib['upright_x'] ?? 0), 0);
      case TiltPose.sideways:
        return (_raw('y') - (_calib['sideways_y'] ?? 0), 0);
    }
  }

  bool _isLevelNow() {
    final (a, b) = _angles();
    return isLevel(a) && isLevel(b);
  }

  bool get _calibrated => switch (_pose) {
    TiltPose.flat => _calib.containsKey('flat_x'),
    TiltPose.upright => _calib.containsKey('upright_x'),
    TiltPose.sideways => _calib.containsKey('sideways_y'),
  };

  void _calibrate() {
    if (_last == null) return;
    setState(() {
      switch (_pose) {
        case TiltPose.flat:
          _calib['flat_x'] = _raw('x');
          _calib['flat_y'] = _raw('y');
        case TiltPose.upright:
          _calib['upright_x'] = _raw('x');
        case TiltPose.sideways:
          _calib['sideways_y'] = _raw('y');
      }
    });
    _savePrefs();
    _snack("지금 놓인 자리를 0으로 맞췄습니다. 길게 누르면 영점을 지웁니다.");
  }

  void _clearCalib() {
    setState(() => _calib = {});
    _savePrefs();
    _snack("영점을 지웠습니다.");
  }

  void _cycleUnit() {
    setState(
      () =>
          _unit = SlopeUnit.values[(_unit.index + 1) % SlopeUnit.values.length],
    );
    _savePrefs();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
  }

  // ── 화면 ──

  String get _poseLabel => switch (_pose) {
    TiltPose.flat => "눕혀서 · 두 방향",
    TiltPose.upright => "세워서 · 좌우",
    TiltPose.sideways => "옆으로 세워서 · 긴 변",
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _ink,
        title: const Text(
          "수평계",
          style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              key: const Key('level_unit'),
              label: Text("단위 ${slopeUnitLabel(_unit)}"),
              onPressed: _cycleUnit,
              backgroundColor: _bg,
              side: BorderSide.none,
            ),
          ),
        ],
      ),
      body: SafeArea(child: _noSensor ? _noSensorView() : _levelView()),
    );
  }

  Widget _noSensorView() => const Center(
    key: Key('level_no_sensor'),
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Text(
        "이 기기에서는 기울기 센서를 읽을 수 없습니다.\n폰에서 여십시오.",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: _grey, height: 1.5),
      ),
    ),
  );

  Widget _levelView() {
    final (a, b) = _angles();
    final level = _last != null && isLevel(a) && isLevel(b);
    return Column(
      children: [
        _readout(a, b, level),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, c) => _vial(c.biggest, a, b, level),
            ),
          ),
        ),
        _buttons(),
      ],
    );
  }

  Widget _readout(double a, double b, bool level) {
    final big = TextStyle(
      fontSize: 56,
      fontWeight: FontWeight.w900,
      color: level ? _ok : _ink,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final Widget numbers = _pose == TiltPose.flat
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(child: _axisNumber("좌우", a, big)),
              const SizedBox(width: 12),
              Expanded(child: _axisNumber("앞뒤", b, big)),
            ],
          )
        // 좁은 폰·긴 값(예: 1000.0mm/m)에서도 넘치지 않게 글자를 줄여 맞춘다.
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _last == null ? "--" : formatSlope(a, _unit),
              key: const Key('level_value'),
              style: big.copyWith(fontSize: 72),
            ),
          );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: level ? _okSoft : _bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              Text(
                _poseLabel,
                style: const TextStyle(
                  color: _grey,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_calibrated) ...[
                const SizedBox(width: 8),
                const Text(
                  "· 영점 맞춤",
                  style: TextStyle(color: _teal, fontWeight: FontWeight.w700),
                ),
              ],
              if (_hold) ...[
                const SizedBox(width: 8),
                const Text(
                  "· 고정됨",
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          numbers,
          const SizedBox(height: 8),
          Text(
            _last == null ? "센서를 읽는 중입니다" : (level ? "수평입니다" : "기포 쪽이 높습니다"),
            key: const Key('level_status'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: level ? _ok : _grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _axisNumber(String label, double v, TextStyle style) => Column(
    children: [
      Text(label, style: const TextStyle(color: _grey, fontSize: 13)),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(_last == null ? "--" : formatSlope(v, _unit), style: style),
      ),
    ],
  );

  Widget _vial(Size size, double a, double b, bool level) {
    switch (_pose) {
      case TiltPose.flat:
        final d = size.shortestSide;
        return Center(
          child: SizedBox(
            width: d,
            height: d,
            child: CustomPaint(
              key: const Key('level_bullseye'),
              painter: _BullseyePainter(
                // 기포는 높은 쪽으로: 오른쪽이 높으면 오른쪽, 위쪽이 높으면 위(화면 y는 아래로 +).
                bubble: Offset(bubbleOffset(a), -bubbleOffset(b)),
                level: level,
              ),
            ),
          ),
        );
      case TiltPose.upright:
        return Center(
          child: SizedBox(
            width: size.width,
            height: 90,
            child: CustomPaint(
              key: const Key('level_tube'),
              painter: _TubePainter(offset: bubbleOffset(a), level: level),
            ),
          ),
        );
      case TiltPose.sideways:
        return Center(
          child: SizedBox(
            width: 90,
            height: size.height,
            child: CustomPaint(
              key: const Key('level_tube'),
              painter: _TubePainter(
                offset: -bubbleOffset(a), // 위쪽이 높으면 기포가 위로
                level: level,
                vertical: true,
              ),
            ),
          ),
        );
    }
  }

  Widget _buttons() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Row(
      children: [
        Expanded(
          child: GestureDetector(
            onLongPress: _clearCalib,
            child: OutlinedButton.icon(
              key: const Key('level_calibrate'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: _teal,
              ),
              onPressed: _last == null ? null : _calibrate,
              icon: const Icon(Icons.adjust),
              label: const Text("영점 맞추기"),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            key: const Key('level_hold'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: _hold ? Colors.orange : _teal,
            ),
            onPressed: _last == null
                ? null
                : () => setState(() => _hold = !_hold),
            icon: Icon(_hold ? Icons.lock_open : Icons.lock),
            label: Text(_hold ? "고정 풀기" : "값 고정"),
          ),
        ),
      ],
    ),
  );
}

/// 둥근 기포(눕혔을 때).
class _BullseyePainter extends CustomPainter {
  final Offset bubble; // -1~1
  final bool level;
  _BullseyePainter({required this.bubble, required this.level});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 4;
    canvas.drawCircle(c, r, Paint()..color = level ? _okSoft : _liquid);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = _ink.withValues(alpha: 0.25)
      ..strokeWidth = 1.5;
    canvas.drawCircle(c, r, ring..strokeWidth = 3);
    ring.strokeWidth = 1.5;
    for (final f in [0.66, 0.33]) {
      canvas.drawCircle(c, r * f, ring);
    }
    canvas.drawLine(c - Offset(r, 0), c + Offset(r, 0), ring);
    canvas.drawLine(c - Offset(0, r), c + Offset(0, r), ring);
    final br = r * 0.16;
    final pos = c + Offset(bubble.dx, bubble.dy) * (r - br);
    canvas.drawCircle(pos, br, Paint()..color = Colors.white);
    canvas.drawCircle(
      pos,
      br,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = level ? _ok : _ink.withValues(alpha: 0.5),
    );
    // 가운데 과녁(기포가 들어가야 할 자리)
    canvas.drawCircle(
      c,
      br * 1.15,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = level ? _ok : _teal,
    );
  }

  @override
  bool shouldRepaint(_BullseyePainter old) =>
      old.bubble != bubble || old.level != level;
}

/// 기포관(세웠을 때). [vertical]이면 세로로 그린다.
class _TubePainter extends CustomPainter {
  final double offset; // -1~1
  final bool level;
  final bool vertical;
  _TubePainter({
    required this.offset,
    required this.level,
    this.vertical = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final long = vertical ? size.height : size.width;
    final short = vertical ? size.width : size.height;
    canvas.save();
    if (vertical) {
      canvas.translate(size.width, 0);
      canvas.rotate(1.5707963267948966);
    }
    final rect = Rect.fromLTWH(0, short * 0.15, long, short * 0.7);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2));
    canvas.drawRRect(rr, Paint()..color = level ? _okSoft : _liquid);
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _ink.withValues(alpha: 0.25),
    );
    final bw = rect.height * 1.3;
    final mid = rect.center.dx;
    // 가운데 두 줄(기포가 이 사이에 오면 수평)
    final mark = Paint()
      ..color = level ? _ok : _teal
      ..strokeWidth = 2.5;
    for (final dx in [-bw / 2 - 4, bw / 2 + 4]) {
      canvas.drawLine(
        Offset(mid + dx, rect.top - 6),
        Offset(mid + dx, rect.bottom + 6),
        mark,
      );
    }
    final travel = (long - bw) / 2 - rect.height / 2;
    final bx = mid + offset * travel;
    final bubble = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(bx, rect.center.dy),
        width: bw,
        height: rect.height * 0.72,
      ),
      Radius.circular(rect.height),
    );
    canvas.drawRRect(bubble, Paint()..color = Colors.white);
    canvas.drawRRect(
      bubble,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = level ? _ok : _ink.withValues(alpha: 0.5),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TubePainter old) =>
      old.offset != offset || old.level != level || old.vertical != vertical;
}
