// 수평계. NixGame "Bubble Level, Spirit Level"(플레이 스토어 500만+) 모양을 따랐다:
//  세우면 화면 전체가 흰·파랑 두 색으로 나뉘고 경계선이 진짜 수직을 가리킨다(빨간 쐐기 =
//  폰 축과의 차이), 눕히면 초록 화면에 큰 원 기포, 왼쪽 가장자리 cm 자, 오른쪽 아래 흰
//  동그라미 단추(설정·영점·고정), 오른쪽 위 모드 단추(A = 자동).
// 배관 구배를 보려고 %·mm/m 단위도 둔다.
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'level_painters.dart';
import 'tilt_math.dart';
import 'tilt_sensor.dart';

Color get _ink => fc.text;
Color get _grey => fc.textSub;
Color get _ok =>
    fieldPick(const Color(0xFF16A34A), sunlight: fc.ok, night: fc.ok);

const String kLevelCalibKey = 'field_level_calib_v1';
const String kLevelUnitKey = 'field_level_unit_v1';
const String kLevelSoundKey = 'field_level_sound_v1';
const String kLevelDecimalsKey = 'field_level_decimals_v1';
const String kRulerDpPerMmKey = 'field_ruler_dp_per_mm_v1';

/// 안드로이드 기준(160 논리 픽셀 = 1인치). 폰마다 조금 달라 "자 맞추기"로 고친다.
const double kDefaultDpPerMm = 160 / 25.4;

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
  bool _sound = true; // 수평이 되면 딸깍 소리
  bool _decimals = true; // 소수점 보이기
  bool _poseLocked = false; // 눕힘·세움 자동 바뀜 멈추기
  double _dpPerMm = kDefaultDpPerMm; // 자 눈금

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
      final sound = p.getBool(kLevelSoundKey);
      final decimals = p.getBool(kLevelDecimalsKey);
      final ruler = p.getDouble(kRulerDpPerMmKey);
      if (!mounted) return;
      setState(() {
        if (ruler != null && ruler > 0) _dpPerMm = ruler;
        if (sound != null) _sound = sound;
        if (decimals != null) _decimals = decimals;
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
      await p.setBool(kLevelSoundKey, _sound);
      await p.setBool(kLevelDecimalsKey, _decimals);
      await p.setDouble(kRulerDpPerMmKey, _dpPerMm);
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
      if (!_poseLocked) _pose = poseFor(v.x, v.y, v.z, current: _pose);
    });
    final level = _isLevelNow();
    if (level && !_wasLevel) {
      HapticFeedback.selectionClick();
      // 폰의 "터치음"이 꺼져 있으면 소리가 안 날 수 있다(시스템 소리를 쓴다).
      if (_sound) SystemSound.play(SystemSoundType.click);
    }
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

  /// 지금 자세의 영점 칸들.
  List<String> get _poseCalibKeys => switch (_pose) {
    TiltPose.flat => const ['flat_x', 'flat_y'],
    TiltPose.upright => const ['upright_x'],
    TiltPose.sideways => const ['sideways_y'],
  };

  // 🚀 [고침] 길게 누르면 세 자세의 영점이 한꺼번에, 묻지도 않고 지워졌다.
  // 지금 자세 것만 지우고, 잘못 눌렀으면 되돌릴 수 있게 한다.
  void _clearCalib() {
    final keys = _poseCalibKeys;
    final before = {
      for (final k in keys)
        if (_calib.containsKey(k)) k: _calib[k]!,
    };
    if (before.isEmpty) {
      _snack("이 자세는 맞춘 영점이 없습니다.");
      return;
    }
    setState(() => _calib.removeWhere((k, _) => keys.contains(k)));
    _savePrefs();
    _snack(
      "이 자세의 영점을 지웠습니다.",
      action: SnackBarAction(
        key: const Key('level_calib_undo'),
        label: "되돌리기",
        onPressed: () {
          if (!mounted) return;
          setState(() => _calib.addAll(before));
          _savePrefs();
        },
      ),
    );
  }

  void _snack(String msg, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          action: action,
          duration: Duration(seconds: action == null ? 2 : 4),
        ),
      );
  }

  // ── 화면 ──

  String get _poseLabel => switch (_pose) {
    TiltPose.flat => "눕혀서 · 두 방향",
    TiltPose.upright => "세워서 · 좌우",
    TiltPose.sideways => "옆으로 세워서 · 긴 변",
  };

  /// 세웠을 때 폰 축(0·90·180·-90)과, 그 축에서 진짜 수직까지 돌아간 각(그림용).
  (double axis, double dev) _edgeGeometry(double a) {
    final r = screenRotation(_last!.x, _last!.y);
    final axis = (r / 90).round() * 90.0;
    // 표시 각(a, 영점 반영)을 화면 돌림 방향으로 바꾼다.
    final sgn = switch (axis) {
      0 => 1.0,
      90 => -1.0,
      -90 => 1.0,
      _ => -1.0, // ±180
    };
    return (axis, sgn * a);
  }

  // 현장 보기(보통·햇빛·야간) 테마로 감싼다: 기본 위젯(입력칸·스위치·창)도 같은 색(D-D).
  @override
  Widget build(BuildContext context) =>
      FieldViewTheme(child: Builder(builder: _buildPage));

  Widget _buildPage(BuildContext context) {
    return Scaffold(
      backgroundColor: fc.surface,
      body: _noSensor
          ? SafeArea(child: _noSensorView())
          : LayoutBuilder(builder: (context, c) => _levelView(c.biggest)),
    );
  }

  Widget _noSensorView() => Stack(
    children: [
      Center(
        key: Key('level_no_sensor'),
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            "이 기기에서는 기울기 센서를 읽을 수 없습니다.\n폰에서 여십시오.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: _grey, height: 1.5),
          ),
        ),
      ),
      Positioned(top: 8, left: 8, child: BackButton(color: _ink)),
    ],
  );

  // 수평계 화면 폭(숫자가 자 밑에 깔리지 않게 자리를 잡을 때 쓴다).
  double _areaWidth = 400;

  Widget _levelView(Size size) {
    _areaWidth = size.width;
    final (a, b) = _angles();
    final level = _last != null && isLevel(a) && isLevel(b);
    final flat = _pose == TiltPose.flat;
    final c = size.center(Offset.zero);
    String fmt(double v) =>
        _last == null ? "--" : formatSlope(v, _unit, decimals: _decimals);

    final children = <Widget>[];

    if (flat) {
      children.add(
        Positioned.fill(
          child: CustomPaint(
            key: const Key('level_bullseye'),
            painter: BubbleLevelPainter(
              // 기포는 높은 쪽으로: 오른쪽이 높으면 오른쪽, 위쪽이 높으면 위(화면 y는 아래로 +).
              bubble: Offset(bubbleOffset(a), -bubbleOffset(b)),
              level: level,
            ),
          ),
        ),
      );
      // NixGame처럼 좌우 값은 오른쪽 위, 앞뒤 값은 왼쪽 아래.
      children.add(
        _number(
          fmt(a),
          Offset(size.width * 0.70, size.height * 0.30),
          Colors.white,
          key: const Key('level_value_x'),
          caption: "좌우",
        ),
      );
      children.add(
        _number(
          fmt(b),
          Offset(size.width * 0.38, size.height * 0.70),
          Colors.white,
          key: const Key('level_value_y'),
          caption: "앞뒤",
        ),
      );
    } else {
      final (axis, dev) = _last == null ? (0.0, 0.0) : _edgeGeometry(a);
      final rot = axis + dev;
      children.add(
        Positioned.fill(
          child: CustomPaint(
            key: const Key('level_tube'),
            painter: SplitLevelPainter(
              rotationDeg: rot,
              referenceDeg: level ? null : axis,
              background: fc.surface,
            ),
          ),
        ),
      );
      // 숫자는 흰 쪽에, 글자는 진짜 위쪽을 향하게(옆으로 세우면 돌려서).
      final up = upOnScreen(rot);
      final right = Offset(-up.dy, up.dx);
      final at = c - right * (size.width * 0.20) - up * (size.height * 0.06);
      children.add(
        _number(
          fmt(a),
          at,
          fc.brand,
          key: const Key('level_value'),
          turn: axis * math.pi / 180,
          big: true,
        ),
      );
    }

    // 왼쪽 cm 자(화면 맨 위가 0)
    children.add(
      Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: 46,
        child: Container(
          color: flat ? Colors.transparent : fc.surface.withValues(alpha: 0.92),
          child: CustomPaint(
            key: const Key('level_ruler'),
            painter: EdgeRulerPainter(
              dpPerMm: _dpPerMm,
              color: flat ? Colors.white : kLevelBlue,
            ),
          ),
        ),
      ),
    );

    // 위쪽 알림(수평·영점·고정·모양 고정)
    final tags = <Widget>[
      if (_last == null) _tag("센서를 읽는 중입니다", _grey),
      if (level) _tag("수평입니다", _ok, key: const Key('level_status')),
      if (_calibrated) _tag("영점 맞춤", kLevelBlue),
      if (_poseLocked)
        _tag(
          "모양 고정 · $_poseLabel",
          fieldPick(Colors.orange, sunlight: fc.caution, night: fc.caution),
        ),
      if (_hold)
        _tag(
          "고정됨",
          fieldPick(Colors.orange, sunlight: fc.caution, night: fc.caution),
        ),
    ];
    children.add(
      Positioned(
        top: MediaQuery.paddingOf(context).top + 12,
        left: 56,
        right: 110,
        child: Wrap(spacing: 6, runSpacing: 6, children: tags),
      ),
    );

    // 오른쪽 위: 모드(A = 자동 / 자물쇠) + 나가기
    final btnColor = flat ? kLevelGreen : kLevelBlue;
    children.add(
      Positioned(
        top: MediaQuery.paddingOf(context).top + 8,
        right: 12,
        child: Row(
          children: [
            RoundToolButton(
              key: const Key('level_pose_lock'),
              icon: _poseLocked ? Icons.lock : Icons.hdr_auto,
              tooltip: _poseLocked ? "모양 고정 풀기" : "모양 고정",
              color: btnColor,
              active: _poseLocked,
              onTap: () {
                setState(() => _poseLocked = !_poseLocked);
                _snack(
                  _poseLocked
                      ? "지금 모양($_poseLabel)으로 고정했습니다. 폰을 돌려도 안 바뀝니다."
                      : "폰을 놓는 모양에 따라 다시 자동으로 바뀝니다.",
                );
              },
            ),
            const SizedBox(width: 8),
            RoundToolButton(
              key: const Key('level_back'),
              icon: AppIcons.close,
              tooltip: "닫기",
              color: btnColor,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );

    // 오른쪽 아래: 설정 · 영점 · 값 고정
    children.add(
      Positioned(
        right: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 96,
        child: Column(
          children: [
            RoundToolButton(
              key: const Key('level_settings'),
              icon: AppIcons.settings,
              tooltip: "설정",
              color: btnColor,
              onTap: _openSettings,
            ),
            const SizedBox(height: 14),
            RoundToolButton(
              key: const Key('level_calibrate'),
              icon: Icons.center_focus_strong,
              tooltip: "영점 맞추기 (길게 누르면 지움)",
              color: btnColor,
              onTap: _last == null ? null : _calibrate,
              onLongPress: _clearCalib,
            ),
            const SizedBox(height: 14),
            RoundToolButton(
              key: const Key('level_hold'),
              icon: _hold ? Icons.lock_open : Icons.pause,
              tooltip: _hold ? "고정 풀기" : "값 고정",
              color: _hold
                  ? fieldPick(
                      Colors.orange,
                      sunlight: fc.caution,
                      night: fc.caution,
                    )
                  : btnColor,
              active: _hold,
              onTap: _last == null
                  ? null
                  : () => setState(() => _hold = !_hold),
            ),
          ],
        ),
      ),
    );

    return Stack(children: children);
  }

  Widget _tag(String text, Color color, {Key? key}) => Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: fc.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
    ),
  );

  /// 큰 숫자 하나를 [at] 가운데에 둔다.
  Widget _number(
    String text,
    Offset at,
    Color color, {
    Key? key,
    String? caption,
    double turn = 0,
    bool big = false,
  }) {
    final style = TextStyle(
      fontSize: big ? 64 : 52,
      fontWeight: FontWeight.w500,
      color: color,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    // 🚀 [고침] 좁은 폰(320·360 폭)에서 큰 숫자 왼쪽이 왼쪽 자(46) 밑에 깔렸다.
    // 숫자 칸을 자 오른쪽 안으로 줄이고 옮긴다(옆으로 돌린 글은 칸 높이가 가로 폭).
    const rulerRight = 46.0 + 8;
    // 오른쪽 단추 줄(설정·영점·값 고정: 오른쪽 16 + 폭 52)과도 겹치지 않게.
    const edge = 16.0 + 52 + 8;
    final areaW = _areaWidth;
    final boxW = math.min(240.0, areaW - rulerRight - edge);
    final sideways = math.sin(turn).abs() > 0.5;
    final half = (sideways ? 100.0 : boxW) / 2;
    final lo = rulerRight + half, hi = areaW - edge - half;
    final cx = lo <= hi ? at.dx.clamp(lo, hi) : at.dx;
    return Positioned(
      left: cx - boxW / 2,
      top: at.dy - 50,
      width: boxW,
      height: 100,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: turn,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (caption != null)
                    Text(
                      caption,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  Text(text, key: key, style: style),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 설정 ──

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: fc.surface,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void update(VoidCallback f) {
            setState(f);
            setSheet(() {});
            _savePrefs();
          }

          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              children: [
                Text(
                  "단위",
                  style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final u in SlopeUnit.values)
                      ChoiceChip(
                        key: Key('unit_${u.name}'),
                        label: Text(switch (u) {
                          SlopeUnit.degree => "도(°)",
                          SlopeUnit.percent => "퍼센트(%)",
                          SlopeUnit.mmPerM => "구배(mm/m)",
                        }),
                        selected: _unit == u,
                        onSelected: (_) => update(() => _unit = u),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  key: const Key('set_sound'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text("수평이면 소리"),
                  subtitle: const Text("폰 터치음이 꺼져 있으면 안 날 수 있습니다"),
                  value: _sound,
                  onChanged: (v) => update(() => _sound = v),
                ),
                SwitchListTile(
                  key: const Key('set_decimals'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text("소수점 보이기"),
                  value: _decimals,
                  onChanged: (v) => update(() => _decimals = v),
                ),
                ListTile(
                  key: const Key('set_ruler'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.straighten),
                  title: const Text("자 길이 맞추기"),
                  subtitle: const Text("신용카드를 화면에 대고 맞춥니다"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openRulerCalibration();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 신용카드를 화면에 세워 대고(가로 54mm × 세로 85.6mm), 그림 상자가 카드와 같아지게
  /// 맞춘다. 카드 긴 변은 폰 폭보다 길어서 세워서 댄다.
  Future<void> _openRulerCalibration() async {
    final v = await Navigator.of(context).push<double>(
      MaterialPageRoute(
        builder: (_) => RulerCalibrationPage(initial: _dpPerMm),
      ),
    );
    if (v != null && mounted) {
      setState(() => _dpPerMm = v);
      _savePrefs();
    }
  }
}

/// 자 길이 맞추기 화면.
class RulerCalibrationPage extends StatefulWidget {
  final double initial;
  const RulerCalibrationPage({super.key, required this.initial});

  @override
  State<RulerCalibrationPage> createState() => _RulerCalibrationPageState();
}

class _RulerCalibrationPageState extends State<RulerCalibrationPage> {
  late double _v = widget.initial.clamp(4.5, 8.5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fc.surface,
      appBar: AppBar(
        backgroundColor: fc.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _ink,
        title: const Text("자 길이 맞추기"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                "신용카드(교통카드)를 세로로 세워 아래 상자 위에 대고, 상자가 카드와 같아지게 밉니다.",
                style: TextStyle(color: _grey, height: 1.4),
              ),
            ),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    key: const Key('ruler_card'),
                    width: 54 * _v,
                    height: 85.6 * _v,
                    decoration: BoxDecoration(
                      border: Border.all(color: kLevelBlue, width: 2),
                      borderRadius: BorderRadius.circular(3.2 * _v),
                    ),
                  ),
                ),
              ),
            ),
            Slider(
              key: const Key('ruler_slider'),
              min: 4.5,
              max: 8.5,
              value: _v,
              onChanged: (x) => setState(() => _v = x),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() => _v = kDefaultDpPerMm),
                    child: const Text("처음 값으로"),
                  ),
                  const Spacer(),
                  FilledButton(
                    key: const Key('ruler_ok'),
                    onPressed: () => Navigator.pop(context, _v),
                    child: const Text("맞춤"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
