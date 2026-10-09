/// 현장 탭(가로 줄자 화면). 튜브·전선관 계산기가 같이 쓴다.
///
/// 🚀 [바꿈] 예전 화면은 세 벌이었고, 가로 화면 높이(폰 344dp)를 넘겨 줄자
/// 숫자가 아래 칸에 가려졌다. 가까운 마킹은 말풍선이 겹쳤고, 직관 끝 표시와
/// 벤드 마킹이 똑같이 생겼으며, 꺾을 각도·자르는 자리가 없었다.
/// - 전체 보기: 줄자(100mm마다 숫자), 벤드는 빨간 실선·번호, 직관 끝은 회색
///   점선, 자르는 자리 표시, 말풍선은 두 줄로 나눠 겹치지 않게.
/// - 한 단계씩: 지금 할 마킹 하나를 크게. 화면 오른쪽·볼륨 올림은 다음,
///   왼쪽·볼륨 내림은 이전. 끝낸 단계는 ✓.
library;

import 'dart:convert';

import 'package:tubing_calculator/src/presentation/common/number_text.dart';
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/common_widgets/field_view_picker.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:tubing_calculator/src/core/common_widgets/app_frame.dart'
    show kAppSystemUiMode;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tubing_calculator/src/presentation/bend_check/bend_check_model.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking.dart';

// 🚀 [바꿈] 색을 줄였다. 바탕은 흰색 계열 하나, 누를 수 있는 것·켜진 것은
// 앱의 청록, 벤드 마킹만 빨강. 테두리는 얇게, 그림자는 없앤다.
Color get _paper => fieldPick(
  const Color(0xFFF8FAFC),
  sunlight: fc.background,
  night: fc.background,
);
Color get _ink => fc.text;
Color get _kMuted =>
    fieldPick(const Color(0xFF64748B), sunlight: fc.textSub, night: fc.textSub);
Color get _kFaint => fieldPick(
  const Color(0xFF94A3B8),
  sunlight: fc.textFaint,
  night: fc.textFaint,
);
Color get _line => fc.line;
Color get _teal => fc.brand;
Color get _red =>
    fieldPick(const Color(0xFFD32F2F), sunlight: fc.danger, night: fc.danger);
Color get _stripBg => fc.surface;
Color get _amber => fc.caution;

class FieldMarkingScreen extends StatefulWidget {
  /// 자료가 바뀔 때 알려 주는 것(목록 관리자·설정).
  final Listenable listenable;

  /// 지금 자료를 셈한다.
  final FieldMarkingData Function() compute;

  /// 닫기(탭으로 쓸 때는 마킹 탭으로, 따로 띄웠으면 null → 뒤로).
  final VoidCallback? onCloseTab;

  /// IndexedStack 안에서 이 화면이 보이고 있는지. 보일 때만 가로로 돌리고
  /// 뒤로가기를 가로챈다.
  final bool isActive;

  /// 실측 기록에 적을 묶음 이름("1/2\" SUS · 스웨이지락 수동" 같은 규격·장비 한 줄).
  /// 없으면 한 단계씩 화면의 "실측 기록" 단추를 안 보인다.
  final String Function()? measureGroup;

  /// 진행 기록을 남길 칸 이름. 튜브와 전선관이 같은 칸을 써서 오가면 진행이 처음으로 돌아갔다(10-08).
  final String progressKey;

  const FieldMarkingScreen({
    super.key,
    required this.listenable,
    required this.compute,
    this.onCloseTab,
    this.isActive = true,
    this.measureGroup,
    this.progressKey = 'field_progress_v1',
  });

  @override
  State<FieldMarkingScreen> createState() => _FieldMarkingScreenState();
}

class _FieldMarkingScreenState extends State<FieldMarkingScreen> {
  static const double _defaultScale = 2.0;
  static const double _minScale = 0.3;
  static const double _maxScale = 8.0;
  static const String _scaleKey = 'field_tape_scale';

  /// 1mm가 몇 px인지. 두 손가락·확대 단추로 바꾸고 폰에 기억한다.
  double _scale = _defaultScale;

  /// 줄자를 지금 할 마킹 쪽으로 옮겨야 한다(처음 열 때·도면이 바뀔 때·한 단계씩에서 돌아올 때).
  /// 줄자는 길어서 (1007mm 같은) 첫 마킹과 말풍선이 처음엔 화면 밖에 있었다.
  bool _needsFollow = true;
  double _tapeViewW = 0;
  final Map<int, Offset> _pointers = {};
  double _pinchStartDist = 0;
  double _pinchStartScale = _defaultScale;
  bool _pinching = false;
  static const double _padLeft = 48;
  // 맨 끝(자르기) 말풍선이 줄자 끝에서 반 폭만큼 더 나가므로 오른쪽 여백은 그만큼 둔다.
  static const double _padRight = 58;
  static const double _labelW = 108;
  static const double _labelH = 46;
  static const double _laneGap = 6;

  final ScrollController _tapeScroll = ScrollController();
  final FocusNode _focus = FocusNode(debugLabel: 'field_steps');

  // 볼륨 단추: 안드로이드 본체(MainActivity)가 가로채 이 통로로 넘겨준다.
  // 한 단계씩 화면이 보일 때만 켠다(그 밖에는 원래대로 음량 조절).
  static const MethodChannel _volumeChannel = MethodChannel(
    'field/volume_keys',
  );
  bool _capturingVolume = false;
  int _stepCount = 0;

  // 햇빛 아래(흰 바탕·더 큰 숫자)와 간격 보기. 폰에 기억해 둔다.
  static const String _gapKey = 'field_show_gap';
  // 햇빛 보기는 앱 설정(현장 보기)과 같은 것이다(D-D). 여기 단추로 바꾸면 설정도 바뀐다.
  bool get _highContrast => FieldColors.isSunlight;
  bool _showGap = false;

  Color get _bg => _highContrast ? Colors.white : _paper;

  // 🚀 [고침] 햇빛 모드를 켜도 줄자 화면의 회색 작은 글씨(각도·방향·자르기·
  // 직관 끝)는 그대로라 바뀌는 것이 없었다. 켜면 검게, 3px 크게 한다.
  Color get _muted => _highContrast ? Colors.black : _kMuted;
  Color get _faint => _highContrast
      ? fieldPick(Colors.black87, sunlight: fc.text, night: fc.text)
      : _kFaint;
  double _small(double size) => _highContrast ? size + 3 : size;
  Color get _strip => _highContrast ? Colors.white : _stripBg;

  Future<void> _loadViewPrefs() async {
    try {
      // 현장 보기(보통·햇빛·야간)는 앱 설정 하나다. 예전 햇빛 단추 값도 여기서 옮겨진다.
      await FieldColors.load();
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _showGap = prefs.getBool(_gapKey) ?? false;
        _sound = prefs.getBool(_soundKey) ?? false;
        final raw = prefs.getString(widget.progressKey);
        if (raw != null && raw.isNotEmpty) {
          try {
            final j = jsonDecode(raw);
            if (j is Map<String, dynamic>) _savedProgress = j;
          } catch (_) {}
        }
        // 도면은 이미 떠 있는데 저장된 진행이 늦게 읽힌 경우.
        if (_signature.isNotEmpty &&
            _done.isEmpty &&
            _current == 0 &&
            _measured.isEmpty) {
          _applySavedProgress(_signature);
        }
        final sc = prefs.getDouble(_scaleKey);
        if (sc != null) _scale = sc.clamp(_minScale, _maxScale);
      });
    } catch (_) {}
  }

  Future<void> _saveViewPref(String key, bool v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, v);
    } catch (_) {}
  }

  // 한 단계씩 진행(어디까지 했는지·실측)을 같은 도면이면 앱을 나갔다 와도 이어 한다.
  Map<String, dynamic>? _savedProgress;

  // 단계 넘길 때 "딸깍" 소리(진동은 늘 난다). 폰에 기억한다.
  static const String _soundKey = 'field_step_sound';
  bool _sound = false;

  /// 이 도면에서 실측을 적은 단계(번호 → 실측 − 계산 mm). 도면이 바뀌면 비운다.
  final Map<int, double> _measured = {};

  bool _stepMode = false;
  int _current = 0;
  final Set<int> _done = {};
  int? _selectedStep;
  String _signature = '';
  FieldMarkingData _data = FieldMarkingData.empty;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _applyOrientation();
    _loadViewPrefs();
  }

  @override
  void didUpdateWidget(covariant FieldMarkingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _applyOrientation();
      _focus.requestFocus();
    } else if (!widget.isActive && oldWidget.isActive) {
      _restorePortrait();
    }
    _syncVolumeCapture();
  }

  void _syncVolumeCapture({bool forceOff = false}) {
    final want = !forceOff && widget.isActive && _stepMode;
    if (want == _capturingVolume) return;
    _capturingVolume = want;
    if (want) {
      _volumeChannel.setMethodCallHandler((call) async {
        if (call.method != 'volume' || !mounted) return;
        // 10-09: 실측 기록·처음부터 같은 창이 떠 있으면 뒤에서 단계를 넘기지 않는다
        // (예전에는 실측 값을 넣는 동안 볼륨을 누르면 뒤 단계가 넘어가고 ✓가 남았다).
        if (ModalRoute.of(context)?.isCurrent == false) return;
        if (call.arguments == 'up') {
          _next(_stepCount);
        } else {
          _prev(_stepCount);
        }
      });
    }
    _volumeChannel.invokeMethod<void>('setCapture', want).catchError((_) {});
  }

  @override
  void dispose() {
    _syncVolumeCapture(forceOff: true);
    _restorePortrait();
    _tapeScroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// 현장 탭은 화면 방향을 묶지 않는다(가로·세로 모두 허용, 기기를 돌리는 대로 따라간다).
  /// 한때 줄자는 가로·한 단계씩은 세로로 묶었다가 사용자가 풀어 달라고 해서 처음처럼 풀었다.
  /// 두 화면 모두 세로·가로 레이아웃을 가지고 있다.
  void _applyOrientation() {
    SystemChrome.setPreferredOrientations(const []);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// 🚀 [고침] 예전에는 나갈 때 세로(portraitUp/Down)만 허용으로 바꿔, 현장 탭을 한 번
  /// 열면 앱 전체(배치도·PDF 미리보기·펼친 폴더블)가 세로로 묶였다. 원래 앱은 방향을
  /// 묶지 않으므로 풀어 준다(기울기 도구와 같게).
  void _restorePortrait() {
    SystemChrome.setPreferredOrientations(const []);
    SystemChrome.setEnabledSystemUIMode(kAppSystemUiMode);
  }

  void _close() {
    _syncVolumeCapture(forceOff: true);
    _restorePortrait();
    if (widget.onCloseTab != null) {
      widget.onCloseTab!();
    } else {
      // 10-09: 따로 띄운 화면(전선관 "가로 도면 보기")은 PopScope가 뒤로를 막으므로 maybePop은
      // 다시 막혀 여기로 돌아와 끝없이 돌았다(앱 멈춤). 막는 것을 넘어 바로 닫는다.
      Navigator.of(context).pop();
    }
  }

  // ---------------- 단계 움직이기 ----------------

  /// 저장된 진행이 [sig] 도면 것이면 현재 단계·끝낸 단계·실측 표시를 되살린다.
  void _applySavedProgress(String sig) {
    final p = _savedProgress;
    if (p == null || p['sig'] != sig) return;
    final cur = p['current'];
    if (cur is int) _current = cur;
    final done = p['done'];
    if (done is List) {
      _done
        ..clear()
        ..addAll(done.whereType<int>());
    }
    final measured = p['measured'];
    if (measured is Map) {
      _measured.clear();
      measured.forEach((k, v) {
        final i = int.tryParse('$k');
        if (i != null && v is num) _measured[i] = v.toDouble();
      });
    }
    _selectedStep = _current;
  }

  /// 지금 진행을 폰에 적는다(도면 구분 글 `_signature`와 함께).
  Future<void> _persistProgress() async {
    final p = <String, dynamic>{
      'sig': _signature,
      'current': _current,
      'done': _done.toList()..sort(),
      'measured': {for (final e in _measured.entries) '${e.key}': e.value},
    };
    _savedProgress = p;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(widget.progressKey, jsonEncode(p));
    } catch (_) {}
  }

  /// "처음부터": 진행·실측 표시를 비우고 1번 단계로(실측 기록 자체는 지우지 않는다).
  Future<void> _resetProgress() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('처음부터 다시 하시겠습니까?'),
        content: const Text('끝낸 단계 표시와 실측 표시가 지워집니다.\n실측 기록은 그대로 남습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            key: const Key('field_progress_reset_ok'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('처음부터'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _current = 0;
      _done.clear();
      _measured.clear();
      _selectedStep = null;
    });
    await _persistProgress();
  }

  void _go(int to, int count) {
    if (count == 0) return;
    final next = to.clamp(0, count - 1);
    if (next == _current) return;
    HapticFeedback.selectionClick();
    if (_sound) SystemSound.play(SystemSoundType.click);
    setState(() {
      if (next > _current) {
        _done.add(_current);
      } else {
        // 🚀 [고침] 돌아가면 그 단계부터는 다시 할 일이다(예전엔 ✓가 그대로 남았다).
        _done.removeWhere((d) => d >= next);
      }
      _current = next;
      _selectedStep = next;
    });
    _persistProgress();
  }

  void _next(int count) {
    if (_current == count - 1) {
      // 마지막(자르기)까지 끝냈다.
      HapticFeedback.heavyImpact();
      setState(() => _done.add(_current));
      _persistProgress();
      return;
    }
    _go(_current + 1, count);
  }

  void _prev(int count) => _go(_current - 1, count);

  KeyEventResult _onKey(KeyEvent e, int count) {
    if (!_stepMode || e is KeyUpEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.audioVolumeUp ||
        k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.space) {
      _next(count);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.audioVolumeDown ||
        k == LogicalKeyboardKey.arrowLeft) {
      _prev(count);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _toggleMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _stepMode = !_stepMode;
      if (_stepMode && _selectedStep != null) _current = _selectedStep!;
      if (!_stepMode) _needsFollow = true;
    });
    if (_stepMode) _focus.requestFocus();
    _syncVolumeCapture();
  }

  void _selectStep(int i, List<FieldStep> steps) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedStep = _selectedStep == i ? null : i;
      _current = i;
    });
    _scrollToStep(i, steps, animate: true);
  }

  /// 줄자를 [i]번째 단계의 눈금이 화면 가운데 오게 옮긴다.
  void _scrollToStep(int i, List<FieldStep> steps, {required bool animate}) {
    if (!_tapeScroll.hasClients || i < 0 || i >= steps.length) return;
    final x = _padLeft + steps[i].at * _scale;
    final view = _tapeScroll.position.viewportDimension;
    final target = (x - view / 2).clamp(
      0.0,
      _tapeScroll.position.maxScrollExtent,
    );
    if (animate) {
      _tapeScroll.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _tapeScroll.jumpTo(target);
    }
  }

  // ---------------- 줄자 확대·축소 ----------------

  Future<void> _saveScale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_scaleKey, _scale);
    } catch (_) {}
  }

  /// 확대 비율을 [next]로. 화면 가로 [focalX] 자리(기본은 가운데)의 눈금이 그대로 있게 줄자를 옮긴다.
  void _applyScale(double next, {double? focalX}) {
    next = next.clamp(_minScale, _maxScale);
    if ((next - _scale).abs() < 0.001) return;
    final fx = focalX ?? _tapeViewW / 2;
    final anchorMm = _tapeScroll.hasClients
        ? (_tapeScroll.offset + fx - _padLeft) / _scale
        : 0.0;
    setState(() => _scale = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_tapeScroll.hasClients) return;
      final off = (anchorMm * _scale + _padLeft - fx).clamp(
        0.0,
        _tapeScroll.position.maxScrollExtent,
      );
      _tapeScroll.jumpTo(off);
    });
  }

  void _zoomBy(double factor) {
    HapticFeedback.selectionClick();
    _applyScale(_scale * factor);
    _saveScale();
  }

  /// 관 전체가 한 화면에 들어오게(말풍선이 화면 밖으로 안 밀리게).
  void _zoomFit(double maxMm) {
    if (maxMm <= 0 || _tapeViewW <= 0) return;
    HapticFeedback.selectionClick();
    final next = ((_tapeViewW - _padLeft - _padRight) / maxMm).clamp(
      _minScale,
      _maxScale,
    );
    setState(() => _scale = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _tapeScroll.hasClients) _tapeScroll.jumpTo(0);
    });
    _saveScale();
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 2) {
      final p = _pointers.values.toList();
      _pinchStartDist = (p[0] - p[1]).distance;
      _pinchStartScale = _scale;
      setState(() => _pinching = true);
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    if (_pinching && _pointers.length >= 2 && _pinchStartDist > 8) {
      final p = _pointers.values.toList();
      final d = (p[0] - p[1]).distance;
      _applyScale(
        _pinchStartScale * d / _pinchStartDist,
        focalX: (p[0].dx + p[1].dx) / 2,
      );
    }
  }

  void _onPointerEnd(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pinching && _pointers.length < 2) {
      setState(() => _pinching = false);
      _saveScale();
    }
  }

  // ---------------- 실측 기록 ----------------

  /// 이 단계를 실제로 해 보고 잰 값을 "벤딩 실측 기록"에 남긴다(참고용, 마킹 값은 안 바뀐다).
  Future<void> _recordMeasure(FieldStep s, int index) async {
    final group = widget.measureGroup?.call() ?? '';
    final what = s.isCut
        ? '자르기'
        : '${_fmt(s.mark!.angle)}° ${s.mark!.number}번 마킹';
    final actual = await showDialog<double>(
      context: context,
      builder: (ctx) => _MeasureDialog(
        what: what,
        calc: s.at,
        group: group.isEmpty ? '현장' : group,
      ),
    );
    if (actual == null || !mounted) return;
    final at = DateTime.now();
    final checkId = at.millisecondsSinceEpoch.toString();
    await addBendCheck(
      BendCheck(
        id: checkId,
        at: at,
        group: group.isEmpty ? '현장' : group,
        what: what,
        calc: s.at,
        actual: actual,
      ),
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    final diff = actual - s.at;
    setState(() => _measured[index] = diff);
    _persistProgress();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('실측을 기록했습니다 (${signedMm(diff)})'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: '되돌리기',
            onPressed: () async {
              await deleteBendCheck(checkId);
              if (!mounted) return;
              setState(() => _measured.remove(index));
              _persistProgress();
            },
          ),
        ),
      );
  }

  Widget _measureButton(FieldStep s) => TextButton.icon(
    key: const Key('field_measure'),
    onPressed: () => _recordMeasure(s, _current),
    icon: Icon(
      _measured.containsKey(_current)
          ? Icons.check_circle_rounded
          : Icons.straighten_rounded,
      size: 18,
      color: _measured.containsKey(_current) ? _teal : _muted,
    ),
    label: Text(
      _measured.containsKey(_current)
          ? '실측 ${signedMm(_measured[_current]!)} · 다시 기록'
          : '실측 기록',
      style: TextStyle(
        fontSize: _small(13),
        fontWeight: FontWeight.w700,
        color: _muted,
      ),
    ),
  );

  Widget _zoomButton(Key key, IconData icon, String tip, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Material(
          color: fc.surface.withValues(alpha: 0.92),
          shape: CircleBorder(side: BorderSide(color: _line)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: key,
            onTap: onTap,
            child: Tooltip(
              message: tip,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(icon, size: 22, color: _muted),
              ),
            ),
          ),
        ),
      );

  // ---------------- 그리기 ----------------

  // 현장 보기(보통·햇빛·야간) 테마로 감싼다(D-D). 탭만 따로 띄워도 같은 색.
  @override
  Widget build(BuildContext context) =>
      FieldViewTheme(child: Builder(builder: _buildPage));

  Widget _buildPage(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.listenable,
      builder: (context, _) {
        final data = widget.compute();
        _data = data;
        final steps = fieldSteps(data);
        _stepCount = steps.length;
        if (data.signature != _signature) {
          // 목록이 바뀌면 진행을 처음으로.
          _signature = data.signature;
          _current = 0;
          _done.clear();
          _selectedStep = null;
          _measured.clear();
          _needsFollow = true;
          // 같은 도면을 다시 열었으면 하던 데까지 되살린다.
          if (!data.isEmpty) _applySavedProgress(data.signature);
        }
        if (_current >= steps.length) _current = 0;

        return PopScope(
          canPop: !widget.isActive,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && widget.isActive) _close();
          },
          child: Focus(
            focusNode: _focus,
            autofocus: widget.isActive,
            onKeyEvent: (_, e) => _onKey(e, steps.length),
            child: Scaffold(
              backgroundColor: _bg,
              body: SafeArea(
                child: data.isEmpty
                    ? _buildEmpty(data)
                    : Column(
                        children: [
                          _buildTopBar(data, steps),
                          Expanded(
                            child: _stepMode
                                ? _buildStepView(data, steps)
                                : _buildTapeView(data, steps),
                          ),
                          if (_stepMode)
                            _buildMiniStrip(data, steps)
                          else
                            _buildStepStrip(steps),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty(FieldMarkingData data) {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                data.error != null
                    ? Icons.error_outline_rounded
                    : Icons.straighten_rounded,
                size: 56,
                color: _ink.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                data.error != null ? '이 도면은 계산할 수 없습니다' : '입력한 배관이 없습니다',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data.error ?? '입력 탭에서 배관을 넣으면 여기에 줄자 도면이 나옵니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _ink.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 4,
          right: 8,
          child: IconButton(
            icon: Icon(AppIcons.close, color: _ink, size: 28),
            onPressed: _close,
          ),
        ),
      ],
    );
  }

  /// 위쪽 막대. 폭이 넉넉하면 화면 폭에 맞추고(예전과 같음), 모자라면 막대 길이만큼
  /// 그대로 두고 옆으로 밀어 본다. 현장 탭을 열면 가로로 돌기 전에 세로 폭(폰 344)으로
  /// 한 번 그려지는데, 그때 넘쳐 오류 기록이 남았다(2026-09-26 폰). 좁은 창에서도
  /// 닫기 단추까지 닿는다.
  Widget _buildTopBar(FieldMarkingData data, List<FieldStep> steps) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        key: const Key('field_top_bar_scroll'),
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: c.maxWidth),
          child: IntrinsicWidth(child: _topBarContent(data, steps)),
        ),
      ),
    );
  }

  Widget _topBarContent(FieldMarkingData data, List<FieldStep> steps) {
    final int doneCount = _done.length;
    final bool narrow =
        MediaQuery.sizeOf(context).height > MediaQuery.sizeOf(context).width;
    // 폭 420 미만(폴드 겉화면 344 등): "절단"·"mm" 글자, 진행 막대, 구분선을 빼서 한 줄에 다 넣는다.
    final bool compact = MediaQuery.sizeOf(context).width < 420;
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : (narrow ? 8 : 16)),
      decoration: BoxDecoration(
        color: fc.surface,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Text.rich(
            TextSpan(
              children: [
                if (!compact)
                  TextSpan(
                    text: '절단  ',
                    style: TextStyle(
                      fontSize: 13,
                      color: _muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                TextSpan(
                  text: data.totalCut.round().toString(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.5,
                  ),
                ),
                if (!compact)
                  TextSpan(
                    text: ' mm',
                    style: TextStyle(fontSize: 13, color: _muted),
                  ),
              ],
            ),
          ),
          if (data.warnings.isNotEmpty) ...[
            const SizedBox(width: 10),
            ActionChip(
              key: const Key('field_warning_chip'),
              avatar: Icon(AppIcons.warning, color: _amber, size: 18),
              label: Text(
                '확인 ${data.warnings.length}',
                style: TextStyle(color: _amber, fontWeight: FontWeight.bold),
              ),
              backgroundColor: fieldSoft(
                const Color(0xFFFFF7E8),
                (p) => p.caution,
              ),
              side: BorderSide.none,
              shape: const StadiumBorder(),
              visualDensity: VisualDensity.compact,
              onPressed: () => _showWarnings(data.warnings),
            ),
          ],
          SizedBox(width: narrow ? 6 : 12),
          if (_stepMode)
            Expanded(
              child: Row(
                children: [
                  Text(
                    compact ? '${_current + 1}/${steps.length}' : '${_current + 1} / ${steps.length}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                    ),
                  ),
                  if (!compact) const SizedBox(width: 12),
                  if (!compact)
                  Expanded(
                    // 넓으면 남는 폭을 다 쓰고, 좁은 폭(밀어 보기)에서도 60쯤은 보이게.
                    // 세로 화면(폭 좁음)에서는 막대를 짧게 해 "닫기"까지 한 줄에 들어오게 한다.
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).height >
                              MediaQuery.sizeOf(context).width
                          ? 8
                          : 60,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: steps.isEmpty ? 0 : doneCount / steps.length,
                          minHeight: 4,
                          backgroundColor: _line,
                          color: _teal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            // Spacer와 같지만 좁은 폭(밀어 보기)에서 여유 16을 둔다 — 경고 칩이
            // 스스로 셈한 폭이 실제보다 2px 작아, 딱 맞추면 넘친다.
            const Expanded(child: SizedBox(width: 16)),
          SizedBox(width: narrow ? 6 : 12),
          // 🚀 [바꿈] 앱 아래 탭과 같은 모양: 아이콘 + 짧은 이름, 테두리 없음.
          // 켜진 것만 청록 바탕을 옅게 깐다. 보기(누적·간격·햇빛)와
          // 움직임(한 단계·닫기) 사이에 가는 선.
          _viewSegments(),
          // 햇빛(보통·햇빛·야간)과 소리는 자주 안 바꿔서 단추 하나("보기")로 묶었다.
          // 보통이 아닌 보기이거나 소리가 켜져 있으면 켜진 모양으로 알린다.
          _toolButton(
            key: const Key('field_view_menu'),
            icon: AppGlyph.fieldSun,
            label: '보기',
            selected: FieldColors.mode.value != FieldViewMode.normal || _sound,
            onTap: _openViewMenu,
          ),
          if (!compact)
            Container(
              width: 1,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: _line,
            ),
          _toolButton(
            key: const Key('field_mode_toggle'),
            icon: AppGlyph.fieldSteps,
            label: '한 단계씩',
            selected: _stepMode,
            onTap: _toggleMode,
          ),
          _toolButton(
            key: const Key('field_close'),
            icon: AppIcons.close,
            label: '닫기',
            selected: false,
            onTap: _close,
          ),
        ],
      ),
    );
  }

  /// 위쪽 막대 단추 한 칸의 폭. 가로 54, 세로 44, 아주 좁은 폰(폭 420 미만)은 40.
  double _toolWidth() {
    final s = MediaQuery.sizeOf(context);
    if (s.height <= s.width) return 54;
    return s.width < 420 ? 38 : 44;
  }

  /// 누적 | 간격: 둘 중 하나만 고르는 설정이라 한 덩어리(전환 단추)로 둔다.
  Widget _viewSegments() {
    final bool narrow =
        MediaQuery.sizeOf(context).height > MediaQuery.sizeOf(context).width;
    Widget seg(
      Key key,
      Object icon,
      String label,
      bool selected,
      VoidCallback onTap,
    ) {
      final fg = selected ? _teal : _muted;
      return Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: selected ? _teal.withValues(alpha: 0.10) : Colors.transparent,
          child: InkWell(
            key: key,
            onTap: onTap,
            child: SizedBox(
              width: _toolWidth(),
              height: 46,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  anyIcon(icon, size: 21, color: fg),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.1,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: narrow ? 1 : 3),
      child: Container(
        key: const Key('field_gap_toggle'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            seg(
              const Key('field_cumulative'),
              AppGlyph.fieldCumulative,
              '누적',
              !_showGap,
              () => _setShowGap(false),
            ),
            Container(width: 1, height: 30, color: _line),
            seg(
              const Key('field_gap'),
              AppGlyph.fieldGap,
              '간격',
              _showGap,
              () => _setShowGap(true),
            ),
          ],
        ),
      ),
    );
  }

  /// "보기" 창: 현장 보기(보통·햇빛·야간)와 단계 소리. 고르면 바로 바뀐다.
  Future<void> _openViewMenu() async {
    HapticFeedback.selectionClick();
    await showDialog<void>(
      context: context,
      builder: (ctx) => FieldViewTheme(
        child: StatefulBuilder(
          builder: (ctx, setDialog) => AlertDialog(
            title: const Text('보기'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldViewModePicker(),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    key: const Key('field_view_sound'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('단계 넘길 때 소리'),
                    subtitle: const Text('딸깍 소리가 납니다(진동은 늘 납니다)'),
                    value: _sound,
                    onChanged: (v) {
                      setState(() => _sound = v);
                      setDialog(() {});
                      _saveViewPref(_soundKey, v);
                      if (v) SystemSound.play(SystemSoundType.click);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                key: const Key('field_view_close'),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('닫기'),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _setShowGap(bool v) {
    if (_showGap == v) return;
    HapticFeedback.selectionClick();
    setState(() => _showGap = v);
    _saveViewPref(_gapKey, v);
  }

  /// 위쪽 막대의 단추 하나. 모두 같은 크기(아이콘 + 짧은 이름)로 맞춘다.
  Widget _toolButton({
    required Key key,
    required Object icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final fg = selected ? _teal : _muted;
    // 세로 화면(폭 좁음)에서는 단추를 좁혀 위쪽 막대가 한 줄에 다 들어오게 한다.
    final bool narrow =
        MediaQuery.sizeOf(context).height > MediaQuery.sizeOf(context).width;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: narrow ? 1 : 3),
        child: Material(
          key: key,
          color: selected ? _teal.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: _toolWidth(),
              height: 46,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  anyIcon(icon, size: 21, color: fg),
                  const SizedBox(height: 2),
                  // 이름이 칸(54)보다 길면 두 줄로 넘치지 않게 한 줄로 줄여 보인다("한 단계씩").
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.1,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showWarnings(List<String> warnings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이대로는 만들 수 없습니다'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final w in warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $w'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // ---------------- 전체 보기(줄자) ----------------

  Widget _buildTapeView(FieldMarkingData data, List<FieldStep> steps) {
    final double maxMm = [
      data.totalCut,
      ...data.marks.map((m) => m.position),
    ].fold<double>(0, (a, b) => b > a ? b : a);
    final double width = _padLeft + _padRight + maxMm * _scale;

    // 말풍선: 마킹(직관 끝 포함)과 자르는 자리.
    final labels = <_Label>[
      for (final m in data.marks) _Label.mark(m),
      if (data.totalCut > 0) _Label.cut(data.totalCut),
    ];
    final lanes = assignLabelLanes(
      [for (final l in labels) _padLeft + l.position * _scale],
      width: _labelW,
      lanes: 2,
    );

    const double labelTop = 6;
    const double laneStep = _labelH + _laneGap;
    const double pipeTop = labelTop + laneStep * 2 + 4;
    const double pipeH = 22;
    const double tapeTop = pipeTop + pipeH + 2;
    const double tapeH = 40;
    const double contentH = tapeTop + tapeH + 4;

    FieldStep? selected;
    if (_selectedStep != null && _selectedStep! < steps.length) {
      selected = steps[_selectedStep!];
    }

    final stack = SizedBox(
      width: width,
      height: contentH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _TapePainter(
                totalCut: data.totalCut,
                maxMm: maxMm,
                scale: _scale,
                padLeft: _padLeft,
                pipeTop: pipeTop,
                pipeH: pipeH,
                tapeTop: tapeTop,
                tapeH: tapeH,
                lines: [
                  for (var i = 0; i < labels.length; i++)
                    _Line(
                      x: _padLeft + labels[i].position * _scale,
                      top: labelTop + lanes[i] * laneStep + _labelH,
                      kind: labels[i].kind,
                      selected:
                          identical(labels[i].mark, selected?.mark) &&
                          (selected?.isCut ?? false) == labels[i].isCut,
                    ),
                ],
              ),
            ),
          ),
          for (var i = 0; i < labels.length; i++)
            Positioned(
              left: _padLeft + labels[i].position * _scale - _labelW / 2,
              top: labelTop + lanes[i] * laneStep,
              width: _labelW,
              height: _labelH,
              child: _buildLabel(labels[i], steps, selected),
            ),
        ],
      ),
    );
    final tape = LayoutBuilder(
      builder: (context, c) {
        // 화면이 가로로 돌아 폭이 바뀌면(처음엔 세로 폭으로 셈한 뒤 가로가 된다) 다시 가운데로 맞춘다.
        if ((_tapeViewW - c.maxWidth).abs() > 1) _needsFollow = true;
        _tapeViewW = c.maxWidth;
        if (_needsFollow) {
          _needsFollow = false;
          final follow = (_selectedStep ?? _current).clamp(
            0,
            steps.isEmpty ? 0 : steps.length - 1,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToStep(follow, steps, animate: false);
          });
        }
        final scroll = SingleChildScrollView(
          controller: _tapeScroll,
          scrollDirection: Axis.horizontal,
          // 두 손가락으로 늘릴 때는 줄자가 같이 밀리지 않게 한다.
          physics: _pinching
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          child: stack,
        );
        final body = c.maxHeight >= contentH
            ? Align(alignment: Alignment.center, child: scroll)
            : SingleChildScrollView(child: scroll);
        return Listener(
          key: const Key('field_tape_pinch'),
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerEnd,
          onPointerCancel: _onPointerEnd,
          child: body,
        );
      },
    );
    return Stack(
      children: [
        Positioned.fill(child: tape),
        Positioned(
          right: 10,
          bottom: 10,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _zoomButton(
                const Key('field_zoom_out'),
                Icons.remove_rounded,
                '줄이기',
                () => _zoomBy(1 / 1.4),
              ),
              _zoomButton(
                const Key('field_zoom_fit'),
                Icons.fit_screen_rounded,
                '전체 보기',
                () => _zoomFit(maxMm),
              ),
              _zoomButton(
                const Key('field_zoom_in'),
                Icons.add_rounded,
                '키우기',
                () => _zoomBy(1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(_Label l, List<FieldStep> steps, FieldStep? selected) {
    final bool isSel =
        selected != null &&
        ((l.isCut && selected.isCut) ||
            (!l.isCut && identical(l.mark, selected.mark)));
    final int stepIndex = steps.indexWhere(
      (s) => l.isCut ? s.isCut : identical(s.mark, l.mark),
    );
    final bool done = stepIndex >= 0 && _done.contains(stepIndex);

    Color border;
    Color bg;
    double borderWidth = 1;
    Widget child;
    if (l.isCut) {
      border = isSel ? _teal : _ink;
      borderWidth = isSel ? 2 : 1.4;
      bg = fc.surface;
      child = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(AppGlyph.tubeCut, size: 17, color: _ink),
              const SizedBox(width: 4),
              // 자릿수가 많으면 말풍선 폭에 맞게 줄인다(예전에는 넘쳤다).
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _showGap
                        ? '+${fieldStepGap(_data, FieldStep.cut(l.position)).round()}'
                        : l.position.round().toString(),
                    style: TextStyle(
                      color: _ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Text(
            '자르기',
            style: TextStyle(
              color: _muted,
              height: _highContrast ? 1.0 : null,
              fontSize: _small(11),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    } else if (!l.mark!.isBend) {
      // 직관 끝은 금 긋는 자리가 아니라 상자 없이 흐린 글만.
      border = Colors.transparent;
      bg = Colors.transparent;
      child = Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '직관 끝',
            style: TextStyle(
              height: _highContrast ? 1.0 : null,
              fontSize: _small(10),
              color: _faint,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            l.position.round().toString(),
            style: TextStyle(
              height: _highContrast ? 1.0 : null,
              fontSize: _small(13),
              fontWeight: FontWeight.w700,
              color: _muted,
            ),
          ),
        ],
      );
    } else {
      final m = l.mark!;
      border = isSel ? _teal : _line;
      borderWidth = isSel ? 2 : 1;
      bg = fc.surface;
      final angleText = m.hasOverBend
          ? '${_fmt(m.angle)}°→${_fmt(m.targetAngle)}°'
          : '${_fmt(m.angle)}°';
      child = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _numberBadge(m.number, done: done, small: true),
              const SizedBox(width: 5),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _showGap
                        ? '+${m.gap.round()}'
                        : l.position.round().toString(),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Text(
            '$angleText · ${fieldDirectionLabel(m.rotation).split(' ').first}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              height: _highContrast ? 1.0 : null,
              fontSize: _small(11),
              color: _muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: stepIndex >= 0 ? () => _selectStep(stepIndex, steps) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: borderWidth),
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      ),
    );
  }

  Widget _numberBadge(int n, {bool done = false, bool small = false}) {
    final double size = small ? 19 : 30;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? _teal : _red,
        shape: BoxShape.circle,
      ),
      child: done
          ? Icon(Icons.check_rounded, color: fc.onBrand, size: small ? 13 : 20)
          : Text(
              '$n',
              style: TextStyle(
                color: fc.onBrand,
                fontWeight: FontWeight.w800,
                fontSize: small ? 11 : 16,
              ),
            ),
    );
  }

  Widget _buildStepStrip(List<FieldStep> steps) {
    return Container(
      // 햇빛 모드는 아래 글씨가 커지므로 띠도 조금 높인다.
      height: _highContrast ? 70 : 64,
      decoration: BoxDecoration(
        color: _strip,
        border: Border(
          top: BorderSide(
            color: _highContrast ? Colors.black : _line,
            width: _highContrast ? 1.5 : 1,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: steps.length,
        itemBuilder: (context, i) {
          final s = steps[i];
          final bool isSel = _selectedStep == i;
          final bool done = _done.contains(i);
          return GestureDetector(
            onTap: () => _selectStep(i, steps),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                // 10-09: 흰 바탕 고정이라 야간 보기(밝은 글씨)에서 숫자가 안 보였다 → 보기 색 바탕.
                color: isSel ? _teal.withValues(alpha: 0.06) : _stripBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSel ? _teal : (s.isCut ? _ink : _line),
                  width: isSel ? 2 : (s.isCut ? 1.4 : 1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (s.isCut)
                    (done
                        ? Icon(Icons.check_rounded, size: 18, color: _teal)
                        : AppIcon(AppGlyph.tubeCut, size: 20, color: _ink))
                  else
                    _numberBadge(s.mark!.number, done: done, small: true),
                  const SizedBox(width: 6),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _showGap
                            ? '+${fieldStepGap(_data, s).round()} mm'
                            : '${s.at.round()} mm',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      Text(
                        s.isCut
                            ? '자르기'
                            : '${_fmt(s.mark!.angle)}° · ${fieldDirectionLabel(s.mark!.rotation).split(' ').first}',
                        style: TextStyle(
                          fontSize: _small(11),
                          fontWeight: FontWeight.w600,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                  if (_measured.containsKey(i)) ...[
                    const SizedBox(width: 8),
                    Column(
                      key: Key('field_measured_$i'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.straighten_rounded, size: 14, color: _teal),
                        Text(
                          signedMm(_measured[i]!).replaceAll(' mm', ''),
                          style: TextStyle(
                            fontSize: _small(11),
                            fontWeight: FontWeight.w800,
                            color: _teal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------- 한 단계씩 ----------------

  Widget _buildStepView(FieldMarkingData data, List<FieldStep> steps) {
    if (steps.isEmpty) return const SizedBox.shrink();
    final s = steps[_current];
    final bool done = _done.contains(_current);
    final bool isLast = _current == steps.length - 1;
    // 세로 화면이면 숫자와 각도를 위아래로 쌓고, 이전·다음은 아래에 넓게 둔다.
    final bool portrait =
        MediaQuery.sizeOf(context).height > MediaQuery.sizeOf(context).width;
    // 세로 화면의 글자 키움 배율. 영역을 가득 채우게 키웠더니, 1.25배로 줄여도 "너무 크다"고 해서
    // 처음 크기(1.0, 가로 화면과 같은 크기)로 돌렸다. 바꾸려면 여기 숫자만.
    const double boost = 1.0;

    Widget body;
    if (s.isCut) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(AppGlyph.tubeCut, size: 24, color: _muted),
              const SizedBox(width: 6),
              Text(
                done ? '자르기 끝' : '여기서 자릅니다',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                ),
              ),
            ],
          ),
          _bigNumber(
            s.at,
            gap: fieldStepGap(data, s),
            inch: data.inch(s.at),
            inchGap: data.inchGap(s.at, fieldStepPrevious(data, s)),
            boost: boost,
          ),
          Text(
            _showGap ? '마지막 마킹에서 · 줄자 눈금 ${s.at.round()} mm' : '관 끝 0 기준 위치',
            style: TextStyle(fontSize: 14, color: _muted),
          ),
        ],
      );
    } else {
      final m = s.mark!;
      final parts = <Widget>[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // "1번 마킹"을 한 덩어리 이름표로(끝낸 단계는 청록).
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: done ? _teal : _red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (done) ...[
                      Icon(Icons.check_rounded, size: 16, color: fc.onBrand),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      '${m.number}번 마킹',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: fc.onBrand,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              _bigNumber(
                m.position,
                gap: m.gap,
                inch: data.inch(m.position),
                inchGap: data.inchGap(m.position, data.previousOf(m)),
                boost: boost,
              ),
              Text(
                _showGap
                    ? (m.number == 1
                          ? '관 끝 0에서 · 줄자 눈금 ${m.position.round()} mm'
                          : '앞 마킹에서 · 줄자 눈금 ${m.position.round()} mm')
                    : (m.number == 1
                          ? '관 끝 0에서'
                          : '앞 마킹에서 ${m.gap >= 0 ? '+' : ''}${m.gap.round()} mm'),
                style: TextStyle(
                  fontSize: 15,
                  color: _muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          portrait
              ? Container(
                  width: 180,
                  height: 1,
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  color: _line,
                )
              : Container(
                  width: 1,
                  height: 150,
                  margin: const EdgeInsets.symmetric(horizontal: 36),
                  color: _line,
                ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '각도',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
              Text(
                '${_fmt(m.angle)}°',
                style: TextStyle(
                  fontSize: 56 * boost,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  color: _red,
                  letterSpacing: -1,
                ),
              ),
              if (m.hasOverBend)
                Text(
                  '실제로 ${_fmt(m.targetAngle)}°까지 꺾기 · 스프링백',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _paper,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_dirIcon(m.rotation), size: 22, color: _ink),
                    const SizedBox(width: 8),
                    Text(
                      fieldDirectionLabel(m.rotation),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (m.roll != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.threesixty_rounded, size: 16, color: _muted),
                    const SizedBox(width: 4),
                    Text(
                      '꺾기 전에 관을 ${m.roll!.round()}° 롤링합니다',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
      ];
      body = portrait
          ? Column(mainAxisSize: MainAxisSize.min, children: parts)
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: parts);
    }

    final prevButton = _navButton(
      wide: portrait,
      icon: AppIcons.back,
      label: '이전',
      onTap: _current > 0 ? () => _prev(steps.length) : null,
    );
    final center = Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
            // 🚀 [고침] 예전에는 숫자 칸 아무 데나 닿아도 넘어가(폰을 관에 대다 손바닥이
            // 닿으면 안 한 마킹이 ✓가 됐다). 이제 양옆 이전·다음 단추와 볼륨 단추로만 넘긴다.
            builder: (context, c) => SizedBox(
              key: const Key('field_step_area'),
              // 세로 화면에서도 글자는 원래 크기(화면에 안 들어가면 줄어든다).
              // 아래 줄(다음 마킹까지·실측 기록)과 안 겹치게 아래 여백을 둔다.
              child: Center(
                child: Padding(
                  padding: portrait
                      ? const EdgeInsets.fromLTRB(8, 8, 8, 40)
                      : const EdgeInsets.all(8),
                  child: FittedBox(fit: BoxFit.scaleDown, child: body),
                ),
              ),
            ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 2,
                // 좁은 폭(세로 344)에서도 안 넘치게 폭에 맞춰 줄인다.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_current + 1 < steps.length)
                      Text(
                        '${steps[_current + 1].isCut ? '자르기까지' : '다음 마킹까지'} '
                        '${markGap(steps[_current + 1].at, s.at).round()} mm',
                        key: const Key('field_next_gap'),
                        style: TextStyle(
                          fontSize: _small(15),
                          fontWeight: FontWeight.w800,
                          color: _teal,
                        ),
                      ),
                    if (_current + 1 < steps.length &&
                        widget.measureGroup != null)
                      const SizedBox(width: 24),
                    if (widget.measureGroup != null) _measureButton(s),
                    if (_done.isNotEmpty || _current > 0) ...[
                      const SizedBox(width: 12),
                      TextButton.icon(
                        key: const Key('field_progress_reset'),
                        onPressed: _resetProgress,
                        icon: Icon(Icons.restart_alt_rounded, size: 18, color: _muted),
                        label: Text(
                          '처음부터',
                          style: TextStyle(
                            fontSize: _small(13),
                            fontWeight: FontWeight.w700,
                            color: _muted,
                          ),
                        ),
                      ),
                    ],
                  ],
                  ),
                ),
              ),
            ],
          );
    final nextButton = _navButton(
      wide: portrait,
      icon: isLast ? Icons.check_rounded : AppIcons.forward,
      label: isLast ? '끝' : '다음',
      onTap: () => _next(steps.length),
      strong: true,
    );
    if (portrait) {
      return Column(
        children: [
          Expanded(child: center),
          SizedBox(
            height: 96,
            child: Row(
              children: [
                Expanded(child: prevButton),
                Expanded(child: nextButton),
              ],
            ),
          ),
        ],
      );
    }
    return Row(
      children: [prevButton, Expanded(child: center), nextButton],
    );
  }

  /// 한 단계씩의 큰 숫자. 간격 보기면 앞 마킹에서 잰 값을 크게.
  /// 인치 설정이면 아래에 인치를 같이 적는다.
  Widget _bigNumber(
    double v, {
    double? gap,
    String inch = '',
    String inchGap = '',
    double boost = 1.0,
  }) {
    final bool asGap = _showGap && gap != null;
    final text = asGap ? '+${gap.round()}' : v.round().toString();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              text,
              key: const Key('field_step_number'),
              style: TextStyle(
                fontSize: (_highContrast ? 120 : 96) * boost,
                height: 1.05,
                fontWeight: FontWeight.w800,
                color: _highContrast ? Colors.black : _ink,
                letterSpacing: -3,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'mm',
              style: TextStyle(
                fontSize: (_highContrast ? 26 : 22) * boost,
                fontWeight: FontWeight.w600,
                color: _highContrast
                    ? fieldPick(
                        Colors.black87,
                        sunlight: fc.text,
                        night: fc.text,
                      )
                    : _muted,
              ),
            ),
          ],
        ),
        if (inch.isNotEmpty)
          Text(
            asGap ? '+${inchGap.isNotEmpty ? inchGap : _data.inch(gap)}' : inch,
            key: const Key('field_step_inch'),
            style: TextStyle(
              fontSize: (_highContrast ? 30 : 24) * boost,
              fontWeight: FontWeight.w700,
              color: _teal,
            ),
          ),
      ],
    );
  }

  Widget _navButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool strong = false,
    bool wide = false,
  }) {
    // 🚀 [바꿈] 검은 판 대신 옅은 바탕. "다음"만 청록으로 눈에 띄게.
    // 장갑 낀 손을 위해 누르는 자리는 그대로 넓게 둔다.
    final enabled = onTap != null;
    final Color fg = !enabled ? _line : (strong ? _teal : _muted);
    return SizedBox(
      width: wide ? null : 96,
      child: Material(
        color: strong && enabled
            ? _teal.withValues(alpha: 0.08)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: fg),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 한 단계씩 볼 때 아래에 깔리는 얇은 줄자(지금 자리 표시).
  Widget _buildMiniStrip(FieldMarkingData data, List<FieldStep> steps) {
    final total = data.totalCut > 0
        ? data.totalCut
        : steps.fold<double>(1, (a, s) => s.at > a ? s.at : a);
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _stripBg,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: _line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              for (var i = 0; i < steps.length; i++)
                Positioned(
                  left:
                      (steps[i].at / total).clamp(0.0, 1.0) * w -
                      (i == _current ? 7 : 4),
                  child: Container(
                    width: i == _current ? 14 : 8,
                    height: i == _current ? 14 : 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _current
                          ? _teal
                          : (_done.contains(i)
                                ? _teal.withValues(alpha: 0.45)
                                : _faint),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  IconData _dirIcon(double rot) {
    switch (rot.round()) {
      case 0:
        return Icons.arrow_upward;
      case 90:
        return Icons.arrow_forward;
      case 180:
        return Icons.arrow_downward;
      case 270:
        return AppIcons.back;
      case 360:
        return Icons.call_made;
      case 450:
        return Icons.call_received;
    }
    return Icons.rotate_right;
  }

  String _fmt(double a) => (a - a.roundToDouble()).abs() < 0.05
      ? a.round().toString()
      : a.toStringAsFixed(1);
}

enum _LineKind { bend, straight, cut }

class _Label {
  final FieldMark? mark;
  final double position;
  _Label.mark(FieldMark this.mark) : position = mark.position;
  _Label.cut(this.position) : mark = null;
  bool get isCut => mark == null;
  _LineKind get kind => isCut
      ? _LineKind.cut
      : (mark!.isBend ? _LineKind.bend : _LineKind.straight);
}

class _Line {
  final double x;
  final double top;
  final _LineKind kind;
  final bool selected;
  const _Line({
    required this.x,
    required this.top,
    required this.kind,
    this.selected = false,
  });
}

/// 실측 값 입력 창. 입력 컨트롤러를 이 창이 스스로 만들고 없앤다(닫히는 동안에도 안전하게).
class _MeasureDialog extends StatefulWidget {
  final String what;
  final double calc;

  /// 같은 규격·장비의 지난 실측 통계를 찾는 묶음 이름.
  final String group;
  const _MeasureDialog({
    required this.what,
    required this.calc,
    required this.group,
  });

  @override
  State<_MeasureDialog> createState() => _MeasureDialogState();
}

class _MeasureDialogState extends State<_MeasureDialog> {
  String? _measureErr;
  final TextEditingController _ctrl = TextEditingController();

  /// 지난 실측 참고 글(없으면 null, 읽는 중이면 빈 글).
  String? _reference;

  @override
  void initState() {
    super.initState();
    loadBendChecks().then((all) {
      if (!mounted) return;
      final st = statsFor(all, widget.group);
      setState(() {
        _reference = st == null
            ? '이 규격·장비의 지난 실측 기록은 아직 없습니다'
            : referenceText(st) +
                  (st.n < kBendReliableCount ? ' · 건수가 적어 참고만' : '');
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('실측 기록'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.what} · 계산 ${widget.calc.round()} mm'),
          if (_reference != null) ...[
            const SizedBox(height: 6),
            Text(
              _reference!,
              key: const Key('field_measure_reference'),
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            key: const Key('field_measure_input'),
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '실제로 잰 값 (mm)',
              suffixText: 'mm',
              errorText: _measureErr,
            ),
            onChanged: (_) {
              if (_measureErr != null) setState(() => _measureErr = null);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          key: const Key('field_measure_save'),
          onPressed: () {
            // "1,234.5"도 읽고, 못 읽으면 까닭을 보인다(10-08: 아무 반응이 없었다).
            final v = parseNumberText(_ctrl.text);
            if (v == null || !v.isFinite || v <= 0) {
              setState(() => _measureErr = '0보다 큰 숫자로 넣으십시오.');
              return;
            }
            Navigator.pop(context, v);
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

/// 관·줄자·마킹 선을 그린다.
class _TapePainter extends CustomPainter {
  final double totalCut;
  final double maxMm;
  final double scale;
  final double padLeft;
  final double pipeTop;
  final double pipeH;
  final double tapeTop;
  final double tapeH;
  final List<_Line> lines;

  _TapePainter({
    required this.totalCut,
    required this.maxMm,
    required this.scale,
    required this.padLeft,
    required this.pipeTop,
    required this.pipeH,
    required this.tapeTop,
    required this.tapeH,
    required this.lines,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double pipeLen = (totalCut > 0 ? totalCut : maxMm) * scale;

    // 관
    final pipeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(padLeft, pipeTop, pipeLen, pipeH),
      const Radius.circular(4),
    );
    // 관은 반짝이는 은색 대신 차분한 회색 하나(가장자리만 살짝 진하게).
    canvas.drawRRect(
      pipeRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFCBD5E1), fc.line, Color(0xFFCBD5E1)],
        ).createShader(pipeRect.outerRect),
    );
    canvas.drawRRect(
      pipeRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF94A3B8),
    );

    // 줄자 바탕
    final tapeRect = Rect.fromLTWH(padLeft, tapeTop, maxMm * scale, tapeH);
    canvas.drawRect(tapeRect, Paint()..color = const Color(0xFFFFE17A));
    canvas.drawRect(
      tapeRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x33000000),
    );

    // 눈금: 10mm 짧게, 50mm 중간, 100mm 길게 + 숫자.
    // 10-09: 줄자 바탕은 늘 노란색이라 눈금·숫자도 늘 진한 색(예전에는 보기 색 글씨라 야간에 안 보였다).
    const Color tapeInk = Color(0xFF1E293B);
    final tick = Paint()
      ..color = tapeInk
      ..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int mm = 0; mm <= maxMm.floor(); mm += 10) {
      final x = padLeft + mm * scale;
      double h;
      if (mm % 100 == 0) {
        h = 16;
        tick.strokeWidth = 1.6;
      } else if (mm % 50 == 0) {
        h = 11;
        tick.strokeWidth = 1.2;
      } else {
        h = 6;
        tick.strokeWidth = 1;
      }
      canvas.drawLine(Offset(x, tapeTop), Offset(x, tapeTop + h), tick);
      if (mm % 100 == 0) {
        tp.text = TextSpan(
          text: '$mm',
          style: const TextStyle(
            color: tapeInk,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        );
        tp.layout();
        tp.paint(canvas, Offset(x - tp.width / 2, tapeTop + 18));
      }
    }

    // 마킹 선
    for (final l in lines) {
      final bottom = tapeTop + tapeH;
      switch (l.kind) {
        case _LineKind.bend:
          canvas.drawLine(
            Offset(l.x, l.top),
            Offset(l.x, bottom),
            Paint()
              ..color = l.selected ? _teal : _red
              ..strokeWidth = l.selected ? 2.5 : 1.6,
          );
          break;
        case _LineKind.straight:
          _dashed(
            canvas,
            Offset(l.x, l.top),
            Offset(l.x, bottom),
            Paint()
              ..color = _kFaint
              ..strokeWidth = 1,
          );
          break;
        case _LineKind.cut:
          canvas.drawLine(
            Offset(l.x, l.top),
            Offset(l.x, bottom),
            Paint()
              ..color = l.selected ? _teal : _ink
              ..strokeWidth = l.selected ? 2.5 : 1.8,
          );
          break;
      }
    }
  }

  void _dashed(Canvas c, Offset a, Offset b, Paint p) {
    const dash = 5.0, space = 4.0;
    double y = a.dy;
    while (y < b.dy) {
      final y2 = (y + dash).clamp(a.dy, b.dy);
      c.drawLine(Offset(a.dx, y), Offset(a.dx, y2), p);
      y += dash + space;
    }
  }

  @override
  bool shouldRepaint(covariant _TapePainter old) =>
      old.totalCut != totalCut ||
      old.maxMm != maxMm ||
      old.scale != scale ||
      old.lines.length != lines.length ||
      !_sameLines(old.lines, lines);

  bool _sameLines(List<_Line> a, List<_Line> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].x != b[i].x ||
          a[i].top != b[i].top ||
          a[i].kind != b[i].kind ||
          a[i].selected != b[i].selected) {
        return false;
      }
    }
    return true;
  }
}
