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
import 'dart:math' as math;

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
import 'package:tubing_calculator/src/presentation/field/field_path_thumb.dart';
import 'package:tubing_calculator/src/presentation/unit_converter/unit_defs.dart'
    show parseInches;

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

  /// 실측 기록에 같이 남길 지금 장비 값(예: "게인 40"). 값을 고친 뒤 기록만 따로 센다(10-13).
  final String Function()? measureSetup;

  /// 길이를 어디까지 재는지(예: "관 중심(가상 중심선)"). 실측 창 안내에 쓴다. 없으면 말하지 않는다.
  final String Function()? measureRef;

  /// 실측 기록이 어디서 왔는지('tube'·'conduit'). 기록 화면에서 치우치면 어느 장비 설정을 열지 정한다.
  final String measureSource;

  /// 진행 기록을 남길 칸 이름. 튜브와 전선관이 같은 칸을 써서 오가면 진행이 처음으로 돌아갔다(10-08).
  final String progressKey;

  const FieldMarkingScreen({
    super.key,
    required this.listenable,
    required this.compute,
    this.onCloseTab,
    this.isActive = true,
    this.measureGroup,
    this.measureSetup,
    this.measureRef,
    this.measureSource = '',
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
  static const double _labelW = 118;

  /// 말풍선 높이 = 상자 46 + 꼭지 7(10-14).
  static const double _labelH = 53;
  static const double _pointerH = 7;
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
        _stock = prefs.getDouble(_stockKey) ?? 0;
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

  /// 원자재 길이(10-14 사용자 "5번"): 0이면 안 씀. 위 막대에 잔재(원자재 − 절단)를 보여 준다.
  /// 튜브(6m)·전선관(3m)이 달라 진행 칸 이름 뒤에 붙여 따로 기억한다.
  double _stock = 0;
  String get _stockKey => '${widget.progressKey}_stock';

  Future<void> _setStock(double v) async {
    setState(() => _stock = v < 0 ? 0 : v);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_stockKey, _stock);
    } catch (_) {}
  }

  /// 위 막대의 잔재 글. 원자재보다 길면 그만큼 깁니다.
  String _remnantText(double totalCut) {
    final double r = _stock - totalCut;
    return r >= 0 ? '잔재 ${r.round()}' : '원자재보다 ${(-r).round()} 깁니다';
  }

  /// 이 도면에서 실측을 적은 단계(번호 → 실측 − 계산 mm). 도면이 바뀌면 비운다.
  final Map<int, double> _measured = {};

  /// 그 단계 실측 기록의 번호. 다시 기록하면 같은 번호로 바꿔 적는다(10-13: 예전엔 한 건 더 쌓였다).
  final Map<int, String> _measuredIds = {};

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
    final ids = p['measuredIds'];
    _measuredIds.clear();
    if (ids is Map) {
      ids.forEach((k, v) {
        final i = int.tryParse('$k');
        if (i != null && v is String) _measuredIds[i] = v;
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
      'measuredIds': {
        for (final e in _measuredIds.entries) '${e.key}': e.value,
      },
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
      _measuredIds.clear();
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
  /// 10-13: 벤드는 구간 길이(입력 길이)와, 자르기는 절단 길이와 견준다. 예전에는 줄자 마킹 눈금과
  /// 견줘, 벤딩한 뒤 잰 구간 길이를 넣으면 테이크업만큼 틀린 차이가 쌓였다.
  Future<void> _recordMeasure(FieldStep s, int index) async {
    final m = s.mark;
    final double? calcRaw = s.isCut ? s.at : m!.leg;
    if (calcRaw == null || calcRaw <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('이 단계는 구간 길이를 알 수 없어 기록하지 않습니다.')),
        );
      return;
    }
    final group0 = widget.measureGroup?.call() ?? '';
    final group = group0.isEmpty ? '현장' : group0;
    final setup = widget.measureSetup?.call() ?? '';
    final ref = widget.measureRef?.call();
    final kind = s.isCut ? kBendKindCut : kBendKindLeg;
    final double? angle = s.isCut ? null : m!.angle;
    final what = s.isCut ? '절단 길이' : '${_fmt(m!.angle)}° ${m.number}번 구간 길이';
    final String how = s.isCut
        ? '절단한 관 길이를 재서 넣으십시오.'
        : '${m!.number == 1 ? '관 끝' : '${m.number - 1}번 꺾이는 점'}에서 '
              '${m.number}번 꺾이는 점까지${ref == null ? '' : ' $ref 기준으로'} 재서 넣으십시오.';
    final res = await showDialog<({double calc, double actual})>(
      context: context,
      builder: (ctx) => _MeasureDialog(
        what: what,
        how: how,
        calc: calcRaw,
        group: group,
        kindKey: bendKindKey(kind, angle),
        setup: setup,
        inchMode: _data.inchMode,
        inchDenominator: _data.inchDenominator,
      ),
    );
    if (res == null || !mounted) return;
    // 같은 단계를 다시 기록하면 같은 번호로 바꿔 적는다(되돌리기는 앞 기록으로 돌아간다).
    final oldId = _measuredIds[index];
    final prev = oldId == null
        ? null
        : (await loadBendChecks()).where((e) => e.id == oldId).firstOrNull;
    final at = DateTime.now();
    final checkId = prev?.id ?? at.millisecondsSinceEpoch.toString();
    await addBendCheck(
      BendCheck(
        id: checkId,
        at: at,
        group: group,
        what: what,
        calc: res.calc,
        actual: res.actual,
        kind: kind,
        angle: angle,
        setup: setup,
        source: widget.measureSource,
      ),
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    final diff = res.actual - res.calc;
    setState(() {
      _measured[index] = diff;
      _measuredIds[index] = checkId;
    });
    _persistProgress();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            prev == null
                ? '실측을 기록했습니다 (${signedMm(diff)})'
                : '실측을 다시 기록했습니다 (${signedMm(diff)})',
          ),
          duration: const Duration(seconds: 6),
          // 10-13: 단추 달린 알림은 Flutter가 기본으로 계속 띄워(persist) 실측·다음 단추를 가렸다.
          persist: false,
          action: SnackBarAction(
            label: '되돌리기',
            onPressed: () async {
              if (prev != null) {
                await addBendCheck(prev);
              } else {
                await deleteBendCheck(checkId);
              }
              if (!mounted) return;
              setState(() {
                if (prev != null) {
                  _measured[index] = prev.diff;
                } else {
                  _measured.remove(index);
                  _measuredIds.remove(index);
                }
              });
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
          _measuredIds.clear();
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
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : (narrow ? 8 : 16),
      ),
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
          // 10-14: 원자재 길이를 넣었으면 잔재. 원자재보다 길면 빨갛게.
          if (_stock > 0 && !compact) ...[
            const SizedBox(width: 10),
            Text(
              _remnantText(data.totalCut),
              key: const Key('field_remnant'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _stock - data.totalCut < 0 ? _red : _muted,
              ),
            ),
          ],
          // 10-14: 넓은 화면(700 이상)이면 규격·장비 한 줄. 좁으면 줄자 위 카드에 적는다.
          if (data.specLine != null && _wideBar) ...[
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                data.specLine!,
                key: const Key('field_spec_line'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ),
          ],
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
                    compact
                        ? '${_current + 1}/${steps.length}'
                        : '${_current + 1} / ${steps.length}',
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
                        width:
                            MediaQuery.sizeOf(context).height >
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
                  // 원자재 길이(10-14): 넣으면 위 막대에 잔재(원자재 − 절단)를 보여 준다.
                  // 글 칸은 창이 닫히는 동안에도 살아 있어야 해서 칸이 스스로 컨트롤러를 가진다.
                  const SizedBox(height: 12),
                  _StockPicker(
                    value: _stock,
                    muted: _muted,
                    onChanged: (v) {
                      _setStock(v);
                      setDialog(() {});
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
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
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
    // 직관 끝 표시가 자르는 자리와 같은 곳이면(마지막 직관) 자르기 말풍선만 둔다(10-14).
    final labels = <_Label>[
      for (final m in data.marks)
        if (m.isBend || (m.position - data.totalCut).abs() > 1) _Label.mark(m),
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
    const double pipeH = 26;
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
        // 10-14: 위가 비면(태블릿·세로 폰) 지금 할 단계 카드(관 모양 그림·벤더 값)를 줄자 위에 둔다.
        // 폰 가로(높이 344)는 전처럼 줄자만.
        final bool showCard =
            data.segments.isNotEmpty && c.maxHeight >= contentH + _cardH + 24;
        // 세로가 길수록(태블릿) 카드와 그림을 키운다(200~320).
        final double cardH = (c.maxHeight * 0.3).clamp(_cardH, 320.0);
        final Widget body = showCard
            ? Column(
                children: [
                  _buildStepCard(data, steps, c.maxWidth, cardH),
                  Expanded(
                    child: Align(alignment: Alignment.center, child: scroll),
                  ),
                ],
              )
            : (c.maxHeight >= contentH
                  ? Align(alignment: Alignment.center, child: scroll)
                  : SingleChildScrollView(child: scroll));
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

  // ---------------- 지금 할 단계 카드·관 모양 그림(10-14) ----------------

  static const double _cardH = 200;

  /// 위 막대에 규격 줄을 넣을 만큼 넓은지(700 이상). 좁으면 카드에 적는다.
  bool get _wideBar => MediaQuery.sizeOf(context).width >= 700;

  /// 지금 따라가는 단계(고른 것이 있으면 그것).
  FieldStep? _followStep(List<FieldStep> steps) {
    if (steps.isEmpty) return null;
    final i = (_selectedStep ?? _current).clamp(0, steps.length - 1);
    return steps[i];
  }

  Widget _thumb(
    FieldMarkingData data,
    FieldStep? step, {
    required double width,
    required double height,
  }) => SizedBox(
    width: width,
    height: height,
    child: FieldPathThumb(
      data: data,
      highlightBend: step == null || step.isCut ? null : step.mark!.number,
      highlightCut: step?.isCut ?? false,
      pipe: _teal,
      highlight: _red,
      muted: _muted,
      line: _line,
    ),
  );

  /// 줄자 위 "지금 할 단계" 카드: 관 모양 그림 + 번호·눈금·각도·방향·벤더 값·굴림.
  Widget _buildStepCard(
    FieldMarkingData data,
    List<FieldStep> steps,
    double maxWidth,
    double cardH,
  ) {
    final s = _followStep(steps);
    if (s == null) return const SizedBox.shrink();
    final bool narrowCard = maxWidth < 560;
    final TextStyle sub = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: _muted,
      height: 1.3,
    );
    final TextStyle big = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: _ink,
      letterSpacing: -0.5,
      height: 1.1,
    );
    final lines = <Widget>[
      if (data.specLine != null && !_wideBar)
        Text(data.specLine!, style: sub.copyWith(fontSize: 13)),
    ];
    if (s.isCut) {
      lines.addAll([
        Text(
          '여기서 자릅니다',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _muted,
          ),
        ),
        Text('${s.at.round()} mm', style: big),
        Text('마지막 마킹에서 +${fieldStepGap(data, s).round()} mm', style: sub),
      ]);
    } else {
      final m = s.mark!;
      lines.addAll([
        Text(
          '${m.number}번 마킹',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _done.contains(steps.indexOf(s)) ? _teal : _red,
          ),
        ),
        Text('${m.position.round()} mm', style: big),
        Text(
          m.number == 1 ? '관 끝 0에서' : '앞 마킹에서 +${m.gap.round()} mm',
          style: sub,
        ),
        Text(
          '${_fmt(m.angle)}°${m.hasOverBend ? ' (실제 ${_fmt(m.targetAngle)}°)' : ''}'
          ' · ${fieldDirectionLabel(m.rotation)}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        if (m.bender != null)
          Text(
            '벤더: ${m.bender}',
            key: const Key('field_card_bender'),
            style: sub,
          ),
        if (m.roll != null) Text('꺾기 전에 관을 ${m.roll!.round()}° 롤링', style: sub),
      ]);
    }
    return Container(
      key: const Key('field_step_card'),
      height: cardH,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          _thumb(
            data,
            s,
            width: narrowCard ? 150 : (cardH - 24) * 1.4,
            height: cardH - 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final w in lines)
                  DefaultTextStyle.merge(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: w,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 한 단계씩 화면: 세로로 넉넉하면(600 이상) 숫자 위에 관 모양 그림을 둔다.
  Widget _withThumb(Widget body, FieldMarkingData data, FieldStep s) {
    if (data.segments.isEmpty || MediaQuery.sizeOf(context).height < 600) {
      return body;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _thumb(data, s, width: 320, height: 190),
        const SizedBox(height: 10),
        body,
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

    // 10-14: 말풍선 — 상자 밑에 마킹 선을 가리키는 꼭지, 고른 것은 그림자로 띄운다.
    final bool boxed = bg != Colors.transparent;
    return GestureDetector(
      onTap: stepIndex >= 0 ? () => _selectStep(stepIndex, steps) : null,
      child: Column(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: border, width: borderWidth),
                borderRadius: BorderRadius.circular(10),
                boxShadow: boxed
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isSel ? 0.18 : 0.08,
                          ),
                          blurRadius: isSel ? 8 : 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: child,
            ),
          ),
          SizedBox(
            height: _pointerH,
            child: boxed
                ? CustomPaint(
                    size: const Size(14, _pointerH),
                    painter: _PointerPainter(
                      fill: bg,
                      border: border,
                      width: borderWidth,
                    ),
                  )
                : null,
          ),
        ],
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            // 벤더 앞에서 볼 값(10-14): 마킹 탭까지 안 가도 된다.
            if (m.bender != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.straighten_rounded, size: 16, color: _muted),
                  const SizedBox(width: 4),
                  Text(
                    '벤더: ${m.bender}',
                    key: const Key('field_step_bender'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ],
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
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _withThumb(body, data, s),
                  ),
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
                if (_current + 1 < steps.length && widget.measureGroup != null)
                  const SizedBox(width: 24),
                if (widget.measureGroup != null) _measureButton(s),
                if (_done.isNotEmpty || _current > 0) ...[
                  const SizedBox(width: 12),
                  TextButton.icon(
                    key: const Key('field_progress_reset'),
                    onPressed: _resetProgress,
                    icon: Icon(
                      Icons.restart_alt_rounded,
                      size: 18,
                      color: _muted,
                    ),
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
      children: [
        prevButton,
        Expanded(child: center),
        nextButton,
      ],
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

/// 말풍선 밑 꼭지(아래를 가리키는 작은 삼각형). 상자와 같은 바탕·테두리 색.
class _PointerPainter extends CustomPainter {
  final Color fill;
  final Color border;
  final double width;
  const _PointerPainter({
    required this.fill,
    required this.border,
    required this.width,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = border,
    );
    // 상자와 닿는 윗변은 바탕색으로 덮어 테두리가 이어져 보이게.
    canvas.drawLine(
      Offset(width, 0),
      Offset(size.width - width, 0),
      Paint()
        ..color = fill
        ..strokeWidth = width + 1,
    );
  }

  @override
  bool shouldRepaint(covariant _PointerPainter old) =>
      old.fill != fill || old.border != border || old.width != width;
}

/// 실측 값 입력 창. 입력 컨트롤러를 이 창이 스스로 만들고 없앤다(닫히는 동안에도 안전하게).
/// 돌려주는 값: 견줄 계산값(보인 대로 반올림한 값)과 실측값, 둘 다 mm.
class _MeasureDialog extends StatefulWidget {
  final String what;

  /// 어디서 어디까지 재는지 한 줄.
  final String how;

  /// 견줄 값(구간 길이·절단 길이, 반올림 전 mm).
  final double calc;

  /// 같은 규격·장비의 지난 실측 통계를 찾는 묶음 이름.
  final String group;

  /// 같은 종류(같은 각도 구간 길이·절단 길이)만 센다.
  final String kindKey;

  /// 지금 장비 값(비면 가리지 않는다).
  final String setup;

  /// 설정이 인치면 인치로도 받는다(10-13).
  final FieldInchMode inchMode;
  final int inchDenominator;
  const _MeasureDialog({
    required this.what,
    required this.how,
    required this.calc,
    required this.group,
    required this.kindKey,
    this.setup = '',
    this.inchMode = FieldInchMode.none,
    this.inchDenominator = 16,
  });

  @override
  State<_MeasureDialog> createState() => _MeasureDialogState();
}

class _MeasureDialogState extends State<_MeasureDialog> {
  String? _measureErr;
  final TextEditingController _ctrl = TextEditingController();

  /// 지난 실측 참고 글(없으면 null, 읽는 중이면 빈 글).
  String? _reference;

  /// 인치로 넣는지(설정이 인치면 처음부터 인치).
  late bool _inch = widget.inchMode != FieldInchMode.none;

  /// 허용 범위(± mm, 실측 기록 화면 설정).
  double _tol = kBendTolDefault;

  @override
  void initState() {
    super.initState();
    loadBendTolerance().then((v) {
      if (mounted) setState(() => _tol = v);
    });
    loadBendChecks().then((all) {
      if (!mounted) return;
      final label = bendKindLabel(widget.kindKey);
      final setup = widget.setup.isEmpty ? null : widget.setup;
      final st = statsFor(
        all,
        widget.group,
        kindKey: widget.kindKey,
        setup: setup,
      );
      setState(() {
        _reference = st == null
            ? '이 규격·장비의 지난 $label 실측은 아직 없습니다'
            : '$label · ${referenceText(st)}'
                  '${setup == null ? '' : ' · 지금 장비 값($setup)으로 잰 것만'}'
                  '${st.n < kBendReliableCount ? ' · 건수가 적어 참고만' : ''}';
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 견줄 계산값: 보이는 눈금 그대로(mm는 1mm, 인치는 분수·소수 눈금). 예전엔 248로 보이고
  /// 247.6을 적어, 248을 넣어도 +0.4가 쌓였다.
  double get _calcShown {
    final c = widget.calc;
    if (!_inch) return c.roundToDouble();
    if (widget.inchMode == FieldInchMode.decimal) {
      return (c / 25.4 * 100).round() / 100 * 25.4;
    }
    final d = widget.inchDenominator <= 0 ? 16 : widget.inchDenominator;
    return (c / 25.4 * d).round() / d * 25.4;
  }

  /// 차이와 합격/불합격(허용 범위 안이면 초록, 밖이면 빨강).
  Widget _liveDiff(double diff) {
    final ok = bendWithinTol(diff, _tol);
    final c = ok ? fc.ok : fc.danger;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '차이 ${signedMm(diff)} · ${ok ? '합격' : '허용 ±$_tolText mm 밖(불합격)'}',
        key: const Key('field_measure_live'),
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c),
      ),
    );
  }

  /// mm·인치 고르기 칩(골라지면 청록 바탕에 흰 글씨).
  Widget _unitChip(String key, String label, bool inch) {
    final selected = _inch == inch;
    return ChoiceChip(
      key: Key(key),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: fc.brand,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected ? fc.onBrand : null,
      ),
      onSelected: (_) => setState(() {
        _inch = inch;
        _measureErr = null;
      }),
    );
  }

  String get _calcText {
    final mm = '${widget.calc.round()} mm';
    if (!_inch) return mm;
    return '${formatInch(widget.calc, widget.inchMode, denominator: widget.inchDenominator)} ($mm)';
  }

  /// 넣은 값(mm). 못 읽으면 null.
  double? get _actualMm {
    final v = _inch
        ? (parseInches(_ctrl.text) == null
              ? null
              : parseInches(_ctrl.text)! * 25.4)
        : parseNumberText(_ctrl.text);
    return (v == null || !v.isFinite || v <= 0) ? null : v;
  }

  String get _tolText =>
      _tol == _tol.roundToDouble() ? _tol.round().toString() : '$_tol';

  @override
  Widget build(BuildContext context) {
    final bool canInch = widget.inchMode != FieldInchMode.none;
    return AlertDialog(
      title: const Text('실측 기록'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.what,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              widget.how,
              key: const Key('field_measure_how'),
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            if (_reference != null) ...[
              const SizedBox(height: 6),
              Text(
                _reference!,
                key: const Key('field_measure_reference'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
            if (canInch) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  _unitChip('field_measure_unit_mm', 'mm', false),
                  _unitChip('field_measure_unit_inch', '인치', true),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // 10-13: 실측 기록 화면처럼 계산과 잰 값을 큰 숫자로 나란히, 차이·합격을 바로.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    decoration: BoxDecoration(
                      color: fc.fill,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '계산',
                          style: TextStyle(fontSize: 12, color: fc.textSub),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _calcText,
                            key: const Key('field_measure_calc'),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const Key('field_measure_input'),
                    controller: _ctrl,
                    autofocus: true,
                    // 인치는 "37 3/16"처럼 띄어쓰기·빗금이 들어가 글자 자판으로.
                    keyboardType: _inch
                        ? TextInputType.text
                        : const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    decoration: InputDecoration(
                      labelText: _inch ? '잰 값 (인치)' : '잰 값 (mm)',
                      hintText: _inch ? '37 3/16' : null,
                      suffixText: _inch ? '"' : 'mm',
                      errorText: _measureErr,
                      errorMaxLines: 3,
                    ),
                    onChanged: (_) => setState(() => _measureErr = null),
                  ),
                ),
              ],
            ),
            if (_actualMm != null) _liveDiff(_actualMm! - _calcShown),
          ],
        ),
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
            final double? v = _actualMm;
            if (v == null) {
              setState(
                () => _measureErr = _inch
                    ? '0보다 큰 인치로 넣으십시오(예: 37 3/16).'
                    : '0보다 큰 숫자로 넣으십시오.',
              );
              return;
            }
            Navigator.pop(context, (calc: _calcShown, actual: v));
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
    final double pipeRight = padLeft + pipeLen;

    // ── 관: 둥근 관처럼(위 밝고 아래 어두운 음영 + 하이라이트 + 그림자). 10-14 사용자 "현실성 있게".
    final pipeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(padLeft, pipeTop, pipeLen, pipeH),
      Radius.circular(pipeH / 2),
    );
    canvas.drawRRect(
      pipeRect.shift(const Offset(0, 2)),
      Paint()
        ..color = const Color(0x22000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawRRect(
      pipeRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF8FAFC),
            Color(0xFFCBD5E1),
            Color(0xFF94A3B8),
            Color(0xFF5B6B7D),
          ],
          stops: [0.0, 0.35, 0.75, 1.0],
        ).createShader(pipeRect.outerRect),
    );
    // 하이라이트 한 줄(관 위쪽 1/4).
    canvas.drawLine(
      Offset(padLeft + 8, pipeTop + pipeH * 0.26),
      Offset(pipeRight - 8, pipeTop + pipeH * 0.26),
      Paint()
        ..color = const Color(0xAAFFFFFF)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(
      pipeRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF64748B),
    );
    // 관 끝(0): 조금 어두운 끝면.
    canvas.save();
    canvas.clipRRect(pipeRect);
    canvas.drawRect(
      Rect.fromLTWH(padLeft, pipeTop, 6, pipeH),
      Paint()..color = const Color(0x44334155),
    );
    canvas.restore();
    // 자르는 자리: 관 끝에 톱질 선(빗금)과 잘라 낼 나머지(점선 윤곽) 조금.
    if (totalCut > 0) {
      final cutPaint = Paint()
        ..color = const Color(0xFF334155)
        ..strokeWidth = 1.2;
      for (double y = pipeTop + 2; y < pipeTop + pipeH - 1; y += 4) {
        canvas.drawLine(
          Offset(pipeRight - 3, y),
          Offset(pipeRight + 1, y + 2),
          cutPaint,
        );
      }
      final rest = RRect.fromRectAndRadius(
        Rect.fromLTWH(pipeRight + 4, pipeTop, 44, pipeH),
        Radius.circular(pipeH / 2),
      );
      final restPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x5564748B);
      _dashedPath(canvas, Path()..addRRect(rest), restPaint);
    }

    // ── 줄자: 노란 본체에 두께감(위 어두운 선·아래 띠·그림자), 0에는 끝 고리.
    final tapeRect = Rect.fromLTWH(padLeft, tapeTop, maxMm * scale, tapeH);
    canvas.drawRect(
      tapeRect.shift(const Offset(0, 2)),
      Paint()
        ..color = const Color(0x22000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawRect(
      tapeRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFEB8F), Color(0xFFFFDE5C), Color(0xFFF2C94C)],
          stops: [0.0, 0.7, 1.0],
        ).createShader(tapeRect),
    );
    canvas.drawRect(
      Rect.fromLTWH(tapeRect.left, tapeRect.bottom - 3, tapeRect.width, 3),
      Paint()..color = const Color(0x22000000),
    );
    canvas.drawRect(
      tapeRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x55000000),
    );
    // 끝 고리(쇠): 0에 걸리는 금속 조각.
    final hook = Rect.fromLTWH(padLeft - 7, tapeTop - 3, 8, tapeH + 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(hook, const Radius.circular(2)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFE2E8F0), Color(0xFF94A3B8)],
        ).createShader(hook),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(hook, const Radius.circular(2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF475569),
    );

    // 눈금: 1mm(확대했을 때만)·5mm·10mm·50mm(숫자)·100mm(굵은 숫자).
    // 10-09: 줄자 바탕은 늘 노란색이라 눈금·숫자도 늘 진한 색(예전에는 보기 색 글씨라 야간에 안 보였다).
    const Color tapeInk = Color(0xFF1E293B);
    final tick = Paint()..color = tapeInk;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final int step = scale >= 3.0 ? 1 : (scale >= 1.2 ? 5 : 10);
    final bool fiftyNumbers = scale >= 0.9;
    for (int mm = 0; mm <= maxMm.floor(); mm += step) {
      final x = padLeft + mm * scale;
      double h;
      if (mm % 100 == 0) {
        h = 18;
        tick.strokeWidth = 1.8;
      } else if (mm % 50 == 0) {
        h = 14;
        tick.strokeWidth = 1.3;
      } else if (mm % 10 == 0) {
        h = 10;
        tick.strokeWidth = 1.0;
      } else if (mm % 5 == 0) {
        h = 7;
        tick.strokeWidth = 0.9;
      } else {
        h = 3.5;
        tick.strokeWidth = 0.6;
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
        // 0은 끝 고리에 가리지 않게 오른쪽으로 조금.
        tp.paint(
          canvas,
          Offset(mm == 0 ? x + 3 : x - tp.width / 2, tapeTop + 19),
        );
      } else if (fiftyNumbers && mm % 50 == 0) {
        tp.text = TextSpan(
          text: '$mm',
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        );
        tp.layout();
        tp.paint(canvas, Offset(x - tp.width / 2, tapeTop + 21));
      }
    }

    // ── 마킹 선: 관 위에는 굵은 금(마커로 그은 것처럼), 줄자까지 가는 선.
    for (final l in lines) {
      final bottom = tapeTop + tapeH;
      switch (l.kind) {
        case _LineKind.bend:
          final Color c = l.selected ? _teal : _red;
          canvas.drawLine(
            Offset(l.x, l.top),
            Offset(l.x, bottom),
            Paint()
              ..color = c
              ..strokeWidth = l.selected ? 2.5 : 1.6,
          );
          canvas.drawLine(
            Offset(l.x, pipeTop - 1),
            Offset(l.x, pipeTop + pipeH + 1),
            Paint()
              ..color = c.withValues(alpha: 0.85)
              ..strokeWidth = l.selected ? 5 : 4
              ..strokeCap = StrokeCap.round,
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
          final Color c = l.selected ? _teal : _ink;
          canvas.drawLine(
            Offset(l.x, l.top),
            Offset(l.x, bottom),
            Paint()
              ..color = c
              ..strokeWidth = l.selected ? 2.5 : 1.8,
          );
          break;
      }
    }
  }

  /// 점선 윤곽(잘라 낼 나머지 관).
  void _dashedPath(Canvas c, Path path, Paint p) {
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final double e = math.min(d + 4, metric.length);
        c.drawPath(metric.extractPath(d, e), p);
        d += 7;
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

/// 보기 창의 "원자재 길이" 칸(10-14): 안 씀·3 m·6 m 칩과 다른 길이 글 칸.
class _StockPicker extends StatefulWidget {
  final double value;
  final Color muted;
  final ValueChanged<double> onChanged;
  const _StockPicker({
    required this.value,
    required this.muted,
    required this.onChanged,
  });

  @override
  State<_StockPicker> createState() => _StockPickerState();
}

class _StockPickerState extends State<_StockPicker> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.value > 0 ? widget.value.round().toString() : '',
  );
  late double _value = widget.value;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _set(double v, {bool updateText = true}) {
    setState(() => _value = v);
    if (updateText) _ctrl.text = v > 0 ? v.round().toString() : '';
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('원자재 길이', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(
        '넣으면 위 막대에 잔재(원자재 − 절단)가 보이고, 절단이 더 길면 빨갛게 알립니다.',
        style: TextStyle(fontSize: 13, color: widget.muted),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (label, v) in const [
            ('안 씀', 0.0),
            ('3 m', 3000.0),
            ('6 m', 6000.0),
          ])
            ChoiceChip(
              key: Key('field_stock_${v.round()}'),
              label: Text(label),
              selected: _value == v,
              onSelected: (_) => _set(v),
            ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        key: const Key('field_stock_input'),
        controller: _ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: '다른 길이',
          suffixText: 'mm',
          isDense: true,
        ),
        onChanged: (t) => _set(
          double.tryParse(t.replaceAll(',', '')) ?? 0,
          updateText: false,
        ),
      ),
    ],
  );
}
