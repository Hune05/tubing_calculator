// 각도기. 플레이 스토어에서 많이 쓰는 각도기 앱의 두 쓰임을 따랐다:
//  ① 벤딩 각도 재기: 폰 옆면을 관 한쪽 다리에 대고 "기준", 다른 다리에 대면 굽힌 각.
//  ② 화면 각도기: 화면 위 반원 눈금에 두 팔을 끌어 물건 각을 잰다.
//
// 10-15 점검으로 고친 것: 폰이 앞뒤로 기울면 값이 틀어지는 것(기울기 경고·막기), 관을 세워야 한다는 안내,
// [기준 잡기]·[값 고정]을 누를 때 손 떨림이 들어가던 것(누르기 직전 평균), 자동 고정·목표 각도 진동,
// 화면 각도기 팔이 서로 넘어가면 다른 팔이 끌려오던 것, 미세 조정 단추, 아무 데나 눌러 팔이 튀던 것.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'level_painters.dart';
import 'tilt_math.dart';
import 'tilt_sensor.dart';

Color get _teal => fc.brand;
Color get _ink => fc.text;
Color get _grey => fc.textSub;
Color get _bg => fc.background;
Color get _orange =>
    fieldPick(const Color(0xFFEA580C), sunlight: fc.caution, night: fc.caution);
Color get _green =>
    fieldPick(const Color(0xFF16A34A), sunlight: fc.ok, night: fc.ok);

/// 각도기 소수점 보이기(기본 끔 — 정수 1°).
const String kProtractorDecimalsKey = 'field_protractor_decimals_v1';

/// 자동 고정(굽힌 다리에 대고 1초 가만히 있으면 값을 고정, 기본 끔).
const String kProtractorAutoHoldKey = 'field_protractor_autohold_v1';

/// 목표 각도(°, 없으면 끔). 가까워지면 짧게, 맞으면 길게 떨린다.
const String kProtractorTargetKey = 'field_protractor_target_v1';

/// 목표 각도와 이만큼 안이면 "맞음"(°).
const double kTargetHit = 0.5;

/// 목표 각도와 이만큼 안이면 "가까움"(°).
const double kTargetNear = 3;

class ProtractorPage extends StatefulWidget {
  /// 센서 흐름. 비우면 폰 가속도 센서(검사에서는 가짜 흐름).
  final Stream<TiltSample> Function()? source;
  final Duration noSensorAfter;

  /// 처음 열 탭(0: 벤딩 각도, 1: 화면 각도기).
  final int initialTab;

  /// 지금 시각(ms). 검사에서 시간을 직접 넘긴다.
  final int Function()? clockMs;

  const ProtractorPage({
    super.key,
    this.source,
    this.noSensorAfter = const Duration(seconds: 3),
    this.initialTab = 0,
    this.clockMs,
  });

  @override
  State<ProtractorPage> createState() => _ProtractorPageState();
}

class _ProtractorPageState extends State<ProtractorPage>
    with SingleTickerProviderStateMixin {
  final _session = FieldToolSession();
  late final TabController _tab;
  final _smooth = TiltSmoother(alpha: 0.2);
  final _hist = TiltHistory();
  StreamSubscription<TiltSample>? _sub;
  Timer? _noSensorTimer;

  TiltSample? _last;
  bool _noSensor = false;
  bool _hold = false;
  bool _autoHeld = false; // 자동 고정으로 멈췄는지(알림 글만 다르다)
  double? _reference; // 기준으로 잡은 화면 돌림(°)

  // 🚀 [2026-09-26] 기본은 정수(1°). 소수 한 자리는 설정에서 켠다. 보이는 값은 0.3° 안쪽
  // 흔들림에는 그대로 둔다(숫자가 계속 떨어 "감도가 너무 높다"던 것).
  bool _decimals = false;
  bool _autoHold = false;
  double? _target;
  final _tiltBand = AngleDeadband();
  final _bendBand = AngleDeadband();

  // 자동 고정: 고정을 푼 뒤에는 값이 2° 넘게 바뀌어야 다시 고정한다(풀자마자 또 고정되지 않게).
  bool _autoArmed = true;
  double? _lastHeldBend;
  // 목표 각도: 0 멀다 · 1 가깝다 · 2 맞다. 안으로 들어갈 때만 떨린다.
  int _targetZone = 0;

  // 화면 각도기 두 팔(°, 0 = 오른쪽, 180 = 왼쪽)
  double _armA = 0;
  double _armB = 60;
  int? _dragArm; // 끄는 동안 잡은 팔(놓을 때까지 바꾸지 않는다)
  int _selArm = 1; // 미세 조정 단추가 움직이는 팔

  int _now() => widget.clockMs?.call() ?? DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    )..addListener(_onTabChanged);
    _loadPrefs();
    _session.begin();
    // 화면 각도기 탭은 센서를 안 쓰고 손으로 끄는 방식이라 가로도 맞게 계산된다.
    // 벤딩 각도 재기 탭은 센서 축이 세로 화면 기준이라 세로로만 둔다(tilt_math.dart).
    _applyOrientationForTab(widget.initialTab);
    _noSensorTimer = Timer(widget.noSensorAfter, () {
      if (mounted && _last == null) setState(() => _noSensor = true);
    });
    _sub = (widget.source ?? deviceTiltStream)().listen(
      (s) {
        if (!mounted) return;
        _noSensorTimer?.cancel();
        if (_hold) return;
        final v = _smooth.add(s.x, s.y, s.z);
        _hist.add(_now(), v.x, v.y, v.z);
        setState(() {
          _noSensor = false;
          _last = v;
          _afterSample();
        });
      },
      onError: (_) {
        if (mounted) setState(() => _noSensor = true);
      },
      cancelOnError: true,
    );
  }

  int _tabIndex = 0;

  void _onTabChanged() {
    if (_tab.indexIsChanging || _tab.index == _tabIndex) return;
    _tabIndex = _tab.index;
    _applyOrientationForTab(_tabIndex);
  }

  void _applyOrientationForTab(int index) {
    _tabIndex = index;
    final orientations = index == 1
        ? const [
            DeviceOrientation.portraitUp,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]
        : const [DeviceOrientation.portraitUp];
    SystemChrome.setPreferredOrientations(orientations).catchError((_) {});
  }

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _decimals = p.getBool(kProtractorDecimalsKey) ?? _decimals;
        _autoHold = p.getBool(kProtractorAutoHoldKey) ?? _autoHold;
        _target = p.getDouble(kProtractorTargetKey);
      });
    } catch (_) {}
  }

  void _savePrefs() {
    SharedPreferences.getInstance()
        .then((p) async {
          await p.setBool(kProtractorDecimalsKey, _decimals);
          await p.setBool(kProtractorAutoHoldKey, _autoHold);
          if (_target == null) {
            await p.remove(kProtractorTargetKey);
          } else {
            await p.setDouble(kProtractorTargetKey, _target!);
          }
        })
        .catchError((_) {});
  }

  String _deg(double v) => formatAngle(v, decimals: _decimals);

  @override
  void dispose() {
    _sub?.cancel();
    _noSensorTimer?.cancel();
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    _session.end();
    super.dispose();
  }

  double get _rotation =>
      _last == null ? 0 : screenRotation(_last!.x, _last!.y);

  /// 화면이 세로에서 앞뒤로 기운 각.
  double get _lean => _last == null ? 0 : screenLean(_last!.x, _last!.y, _last!.z);

  /// 너무 기울어 값을 믿을 수 없다(기준을 못 잡고 숫자를 흐리게).
  bool get _tooTilted => _last != null && _lean > kLeanBlock;

  /// 굽힌 각(기준이 있을 때, 흔들림 띠 없이).
  double? get _bendRaw =>
      _reference == null || _last == null ? null : angleDiff(_rotation, _reference!).abs();

  /// 누르기 직전 가만히 있던 값(없으면 지금 값). 누르는 손 떨림을 빼려고(10-15).
  TiltSample? _stableSample() => _hist.averageBefore(_now()) ?? _last;

  void _afterSample() {
    final bend = _bendRaw;
    if (bend == null || _hold) return;
    // 목표 각도: 안쪽 구역으로 들어갈 때만 떤다.
    if (_target != null) {
      final d = (bend - _target!).abs();
      final zone = d <= kTargetHit ? 2 : (d <= kTargetNear ? 1 : 0);
      if (zone > _targetZone) {
        if (zone == 2) {
          HapticFeedback.heavyImpact();
          HapticFeedback.vibrate();
        } else {
          HapticFeedback.selectionClick();
        }
      }
      _targetZone = zone;
    }
    // 자동 고정
    if (!_autoArmed &&
        (_lastHeldBend == null || (bend - _lastHeldBend!).abs() > 2)) {
      _autoArmed = true;
    }
    if (_autoHold && _autoArmed && bend > 3 && !_tooTilted && _hist.stillFor(_now())) {
      final avg = _hist.averageBefore(_now(), skipMs: 0, spanMs: 1000);
      if (avg != null) _last = avg;
      _hold = true;
      _autoHeld = true;
      _autoArmed = false;
      _lastHeldBend = _bendRaw;
      HapticFeedback.heavyImpact();
    }
  }

  void _setHold(bool on) {
    setState(() {
      if (on) {
        final s = _stableSample();
        if (s != null) _last = s;
        _lastHeldBend = _bendRaw;
        _autoArmed = false;
      } else {
        _hist.clear();
        _smooth.reset();
      }
      _hold = on;
      _autoHeld = false;
    });
  }

  // 현장 보기(보통·햇빛·야간) 테마로 감싼다: 기본 위젯(입력칸·스위치·창)도 같은 색(D-D).
  @override
  Widget build(BuildContext context) =>
      FieldViewTheme(child: Builder(builder: _buildPage));

  Widget _buildPage(BuildContext context) {
    return Scaffold(
      backgroundColor: fc.surface,
      appBar: AppBar(
        backgroundColor: fc.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _ink,
        title: Text(
          "각도기",
          style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
        ),
        actions: [
          IconButton(
            key: const Key('protractor_settings'),
            tooltip: "설정",
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
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
          controller: _tab,
          physics: const NeverScrollableScrollPhysics(), // 팔 끌기와 겹치지 않게
          children: [_bendTab(), _screenTab()],
        ),
      ),
    );
  }

  // ── 설정: 소수점 · 자동 고정 · 목표 각도 ──

  Future<void> _openSettings() async {
    final targetCtrl = TextEditingController(
      text: _target == null ? '' : _fmtPlain(_target!),
    );
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: fc.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void update(VoidCallback f) {
            setState(f);
            setSheet(() {});
            _savePrefs();
          }

          void setTarget(double? v) => update(() {
            _target = v;
            _targetZone = 0;
            targetCtrl.text = v == null ? '' : _fmtPlain(v);
          });

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  SwitchListTile(
                    key: const Key('protractor_decimals'),
                    contentPadding: EdgeInsets.zero,
                    title: Text("소수점 보기", style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
                    subtitle: Text("끄면 1° 단위(폰 센서는 ±0.5~1°가 한계)", style: TextStyle(color: _grey)),
                    value: _decimals,
                    onChanged: (v) => update(() => _decimals = v),
                  ),
                  SwitchListTile(
                    key: const Key('protractor_autohold'),
                    contentPadding: EdgeInsets.zero,
                    title: Text("자동 고정", style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      "굽힌 다리에 대고 1초 가만히 있으면 값을 고정하고 진동합니다",
                      style: TextStyle(color: _grey),
                    ),
                    value: _autoHold,
                    onChanged: (v) => update(() {
                      _autoHold = v;
                      _autoArmed = true;
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text("목표 각도", style: TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(
                    "가까워지면(±${_fmtPlain(kTargetNear)}°) 짧게, 맞으면(±${_fmtPlain(kTargetHit)}°) 길게 떨립니다",
                    style: TextStyle(color: _grey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ChoiceChip(
                        key: const Key('target_off'),
                        label: const Text("끄기"),
                        selected: _target == null,
                        onSelected: (_) => setTarget(null),
                      ),
                      for (final t in const [22.5, 30.0, 45.0, 60.0, 90.0])
                        ChoiceChip(
                          key: Key('target_${_fmtPlain(t)}'),
                          label: Text("${_fmtPlain(t)}°"),
                          selected: _target == t,
                          onSelected: (_) => setTarget(t),
                        ),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          key: const Key('protractor_target_field'),
                          controller: targetCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: "직접",
                            suffixText: "°",
                          ),
                          onChanged: (s) {
                            final v = double.tryParse(s.replaceAll(',', '.'));
                            update(() {
                              _target = (v != null && v > 0 && v <= 180) ? v : null;
                              _targetZone = 0;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    targetCtrl.dispose();
  }

  static String _fmtPlain(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  // ── ① 벤딩 각도 재기 ──

  // NixGame "각도 측정" 모양: 화면을 흰·파랑으로 나누는 선이 진짜 수직을 가리키고,
  // 기준을 잡으면 기준선과 지금 선 사이가 빨간 쐐기, 그 각이 굽힌 각이다.
  Widget _bendTab() {
    if (_noSensor) {
      return Center(
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
    final bend = hasRef && _last != null ? _bendBand.apply(_bendRaw!) : null;
    final tilt = _tiltBand.apply(_edgeTilt(_rotation));
    final lean = _lean;
    final holdColor = fieldPick(Colors.orange, sunlight: fc.caution, night: fc.caution);
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final c = size.center(Offset.zero);
        final up = upOnScreen(_rotation);
        final right = Offset(-up.dy, up.dx);
        TextStyle big(Color color, double fs) => TextStyle(
          fontSize: fs,
          fontWeight: FontWeight.w500,
          color: _tooTilted ? _grey : color,
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
                  background: fc.surface,
                ),
              ),
            ),
            // 흰 쪽: 지금 폰 옆면 기울기(작게)
            at(
              c - right * (size.width * 0.22) - up * (size.height * 0.10),
              Text(
                _last == null ? "--" : _deg(tilt),
                key: const Key('bend_tilt'),
                style: big(fc.brand, hasRef ? 40 : 60),
              ),
            ),
            // 파랑 쪽: 굽힌 각(크게)
            if (hasRef)
              at(
                c + right * (size.width * 0.20) + up * (size.height * 0.08),
                Text(
                  bend == null ? "--" : _deg(bend),
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
                        ? "② 굽힌 다리에 대면 벤딩 각도가 나옵니다"
                        : "① 관을 세워(굽힌 면이 위아래로) 폰 옆면을 곧은 다리에 대고 '기준 잡기'",
                    _ink,
                    key: const Key('bend_guide'),
                  ),
                  if (hasRef && bend != null)
                    _pill(
                      "두 다리 사이 각 ${_deg(180 - bend)}",
                      kLevelBlue,
                      key: const Key('bend_inner'),
                    ),
                  if (hasRef && bend != null && _target != null) _targetPill(_bendRaw!),
                  if (_hold)
                    _pill(_autoHeld ? "자동 고정됨" : "고정됨", holdColor, key: const Key('bend_held')),
                  if (_last != null && !_hold && lean > 60)
                    _pill(
                      "폰을 세워서 관에 대십시오. 눕히면 각을 잴 수 없습니다.",
                      _orange,
                      key: const Key('bend_too_flat'),
                    )
                  else if (_tooTilted && !_hold)
                    _pill(
                      "폰이 앞뒤로 ${lean.round()}° 기울었습니다. 똑바로 세워야 잴 수 있습니다.",
                      _orange,
                      key: const Key('bend_too_flat'),
                    )
                  else if (_last != null && !_hold && lean > kLeanWarn)
                    _pill(
                      "폰 기울기 ${lean.round()}° · 똑바로 세우면 더 정확합니다",
                      _orange,
                      key: const Key('bend_lean_warn'),
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
                      onPressed: (_last == null || _tooTilted)
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              final s = _stableSample()!;
                              setState(() {
                                _hold = false;
                                _autoHeld = false;
                                _autoArmed = true;
                                _lastHeldBend = null;
                                _targetZone = 0;
                                _reference = screenRotation(s.x, s.y);
                                _bendBand.reset();
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
                    color: _hold ? holdColor : kLevelBlue,
                    active: _hold,
                    onTap: _last == null ? null : () => _setHold(!_hold),
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
                        _autoHeld = false;
                        _targetZone = 0;
                        _bendBand.reset();
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

  /// 목표 각도까지 남은 각: "목표 90° · 3° 더" / "목표 90° 맞음" / "목표 90° · 2° 넘음".
  Widget _targetPill(double bend) {
    final t = _target!;
    final d = t - bend;
    final hit = d.abs() <= kTargetHit;
    final text = hit
        ? "목표 ${_deg(t)} 맞음"
        : "목표 ${_deg(t)} · ${_deg(d.abs())} ${d > 0 ? '더' : '넘음'}";
    return _pill(
      text,
      hit ? _green : (d.abs() <= kTargetNear ? _orange : _ink),
      key: const Key('bend_target'),
    );
  }

  Widget _pill(String text, Color color, {Key? key}) => Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: fc.surface.withValues(alpha: 0.94),
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

  double _armOf(int i) => i == 0 ? _armA : _armB;

  void _setArm(int i, double v) {
    final c = v.clamp(0.0, 180.0);
    if (i == 0) {
      _armA = c;
    } else {
      _armB = c;
    }
  }

  /// 미세 조정 한 번: 소수점을 켜면 0.1°, 끄면 1°.
  void _nudge(double dir) {
    HapticFeedback.selectionClick();
    final step = _decimals ? 0.1 : 1.0;
    setState(() {
      final v = ((_armOf(_selArm) + dir * step) / step).round() * step;
      _setArm(_selArm, v);
    });
  }

  Widget _screenTab() {
    final between = armsBetween(_armA, _armB);
    final value = Text(
      _deg(between),
      key: const Key('screen_value'),
      style: TextStyle(
        fontSize: 60,
        fontWeight: FontWeight.w900,
        color: _ink,
        height: 1.1,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final hint = Text(
      "물건을 화면 아래 가운데에 대고 팔 끝 동그라미를 끌어 맞춥니다.",
      textAlign: TextAlign.center,
      style: TextStyle(color: _grey),
    );
    final nudge = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          key: const Key('arm_minus'),
          tooltip: "조금 줄이기",
          onPressed: () => _nudge(-1),
          icon: const Icon(Icons.remove),
        ),
        const SizedBox(width: 6),
        for (final i in const [0, 1]) ...[
          if (i == 1) const SizedBox(width: 6),
          InkWell(
            key: Key('arm_chip_$i'),
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _selArm = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: _selArm == i ? _teal : null,
                border: Border.all(color: _selArm == i ? _teal : fc.line, width: 1.5),
              ),
              child: Text(
                _deg(_armOf(i)),
                style: TextStyle(
                  color: _selArm == i ? fc.onBrand : _ink,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(width: 6),
        IconButton.filledTonal(
          key: const Key('arm_plus'),
          tooltip: "조금 늘리기",
          onPressed: () => _nudge(1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
    final protractor = LayoutBuilder(
      builder: (context, c) {
        final size = c.biggest;
        final center = Offset(size.width / 2, size.height - 24);
        double angleAt(Offset p) => armAngle(center.dx, center.dy, p.dx, p.dy);
        int? hit(Offset p) =>
            armHit(angleAt(p), (p - center).distance, _armA, _armB);

        return GestureDetector(
          key: const Key('screen_protractor'),
          behavior: HitTestBehavior.opaque,
          // 팔을 잡았을 때만 끈다. 잡은 팔은 놓을 때까지 그대로(다른 팔을 넘어가도 바뀌지 않게).
          onPanStart: (d) {
            final i = hit(d.localPosition);
            setState(() {
              _dragArm = i;
              if (i != null) _selArm = i;
            });
          },
          onPanUpdate: (d) {
            final i = _dragArm;
            if (i == null) return;
            setState(() => _setArm(i, angleAt(d.localPosition)));
          },
          onPanEnd: (_) => _dragArm = null,
          onPanCancel: () => _dragArm = null,
          // 팔을 누르기만 하면 미세 조정 단추가 그 팔을 움직인다(팔은 그대로).
          onTapDown: (d) {
            final i = hit(d.localPosition);
            if (i != null) setState(() => _selArm = i);
          },
          child: CustomPaint(
            size: size,
            painter: _ProtractorPainter(
              center: center,
              armA: _armA,
              armB: _armB,
              selected: _selArm,
            ),
          ),
        );
      },
    );
    return LayoutBuilder(
      builder: (context, box) {
        // 가로로 눕히면 눈금은 왼쪽 크게, 값·단추는 오른쪽에.
        if (box.maxWidth > box.maxHeight * 1.3) {
          return Row(
            children: [
              Expanded(child: protractor),
              SizedBox(
                width: 240,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(child: value),
                      const SizedBox(height: 4),
                      hint,
                      const SizedBox(height: 12),
                      FittedBox(child: nudge),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            Padding(padding: const EdgeInsets.only(top: 12), child: value),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: hint),
            const SizedBox(height: 8),
            FittedBox(child: nudge),
            Expanded(child: protractor),
          ],
        );
      },
    );
  }
}

/// 반원 눈금 + 두 팔.
class _ProtractorPainter extends CustomPainter {
  final Offset center;
  final double armA, armB;
  final int selected;
  _ProtractorPainter({
    required this.center,
    required this.armA,
    required this.armB,
    required this.selected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 팔 끝 동그라미(반지름 11 + 고른 팔 고리 16)가 화면 옆에서 잘리지 않게 30을 남긴다.
    final r = math.min(size.width / 2 - 30, size.height - 40);
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
            style: TextStyle(fontSize: 12, color: _ink),
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
    void arm(double deg, Color color, bool sel) {
      final p = Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final end = at(deg, r + 6);
      canvas.drawLine(center, end, p);
      // 미세 조정할 팔은 바깥 고리로 표시
      if (sel) {
        canvas.drawCircle(
          end,
          16,
          Paint()
            ..color = color.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
      canvas.drawCircle(end, 11, Paint()..color = color);
      canvas.drawCircle(end, 5, Paint()..color = Colors.white);
    }

    arm(armA, _teal, selected == 0);
    arm(armB, _orange, selected == 1);
    canvas.drawCircle(center, 6, Paint()..color = _ink);
  }

  @override
  bool shouldRepaint(_ProtractorPainter old) =>
      old.armA != armA ||
      old.armB != armB ||
      old.center != center ||
      old.selected != selected;
}
