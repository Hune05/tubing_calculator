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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tubing_calculator/src/presentation/field/field_marking.dart';

const Color _paper = Color(0xFFF2F0E9);
const Color _ink = Color(0xFF2D2D2D);
const Color _red = Color(0xFFD32F2F);
const Color _orange = Colors.deepOrange;
const Color _stripBg = Color(0xFFDFDDD3);
const Color _amber = Color(0xFFC77700);

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

  const FieldMarkingScreen({
    super.key,
    required this.listenable,
    required this.compute,
    this.onCloseTab,
    this.isActive = true,
  });

  @override
  State<FieldMarkingScreen> createState() => _FieldMarkingScreenState();
}

class _FieldMarkingScreenState extends State<FieldMarkingScreen> {
  static const double _scale = 2.0; // 1mm = 2px
  static const double _padLeft = 48;
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
  static const String _hcKey = 'field_high_contrast';
  static const String _gapKey = 'field_show_gap';
  bool _highContrast = false;
  bool _showGap = false;

  Color get _bg => _highContrast ? Colors.white : _paper;
  Color get _strip => _highContrast ? Colors.white : _stripBg;

  Future<void> _loadViewPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _highContrast = prefs.getBool(_hcKey) ?? false;
        _showGap = prefs.getBool(_gapKey) ?? false;
      });
    } catch (_) {}
  }

  Future<void> _saveViewPref(String key, bool v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, v);
    } catch (_) {}
  }

  bool _stepMode = false;
  int _current = 0;
  final Set<int> _done = {};
  int? _selectedStep;
  String _signature = '';
  FieldMarkingData _data = FieldMarkingData.empty;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _setLandscape();
    _loadViewPrefs();
  }

  @override
  void didUpdateWidget(covariant FieldMarkingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _setLandscape();
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

  void _setLandscape() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _restorePortrait() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _close() {
    _syncVolumeCapture(forceOff: true);
    _restorePortrait();
    if (widget.onCloseTab != null) {
      widget.onCloseTab!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  // ---------------- 단계 움직이기 ----------------

  void _go(int to, int count) {
    if (count == 0) return;
    final next = to.clamp(0, count - 1);
    if (next == _current) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (next > _current) _done.add(_current);
      _current = next;
      _selectedStep = next;
    });
  }

  void _next(int count) {
    if (_current == count - 1) {
      // 마지막(자르기)까지 끝냈다.
      HapticFeedback.heavyImpact();
      setState(() => _done.add(_current));
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
    if (!_tapeScroll.hasClients || i >= steps.length) return;
    final x = _padLeft + steps[i].at * _scale;
    final view = _tapeScroll.position.viewportDimension;
    final target = (x - view / 2).clamp(
      0.0,
      _tapeScroll.position.maxScrollExtent,
    );
    _tapeScroll.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // ---------------- 그리기 ----------------

  @override
  Widget build(BuildContext context) {
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
                data.error != null ? '이 도면은 셈할 수 없습니다' : '입력한 배관이 없습니다',
                style: const TextStyle(
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
            icon: const Icon(Icons.close_rounded, color: _ink, size: 28),
            onPressed: _close,
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(FieldMarkingData data, List<FieldStep> steps) {
    final int doneCount = _done.length;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _ink.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: '절단 ',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                TextSpan(
                  text: data.totalCut.round().toString(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
                const TextSpan(
                  text: ' mm',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          if (data.warnings.isNotEmpty) ...[
            const SizedBox(width: 10),
            ActionChip(
              key: const Key('field_warning_chip'),
              avatar: const Icon(
                Icons.warning_amber_rounded,
                color: _amber,
                size: 18,
              ),
              label: Text(
                '확인 ${data.warnings.length}',
                style: const TextStyle(
                  color: _amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: const Color(0xFFFFF3DF),
              side: BorderSide(color: _amber.withValues(alpha: 0.4)),
              onPressed: () => _showWarnings(data.warnings),
            ),
          ],
          const SizedBox(width: 12),
          if (_stepMode)
            Expanded(
              child: Row(
                children: [
                  Text(
                    '${_current + 1} / ${steps.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: steps.isEmpty ? 0 : doneCount / steps.length,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade300,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 8),
          SegmentedButton<bool>(
            key: const Key('field_gap_toggle'),
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              // 고르지 않은 칸도 또렷하게(흐리면 햇빛 아래서 안 보인다).
              foregroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected) ? Colors.white : _ink,
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected) ? _ink : Colors.white,
              ),
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            segments: const [
              ButtonSegment(value: false, label: Text('누적')),
              ButtonSegment(value: true, label: Text('간격')),
            ],
            selected: {_showGap},
            onSelectionChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _showGap = v.first);
              _saveViewPref(_gapKey, _showGap);
            },
          ),
          IconButton(
            key: const Key('field_contrast_toggle'),
            tooltip: '햇빛 아래(흰 바탕·큰 숫자)',
            isSelected: _highContrast,
            icon: Icon(
              _highContrast ? Icons.wb_sunny : Icons.wb_sunny_outlined,
              color: _highContrast ? Colors.orange.shade800 : _ink,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _highContrast = !_highContrast);
              _saveViewPref(_hcKey, _highContrast);
            },
          ),
          const SizedBox(width: 4),
          FilledButton.tonalIcon(
            key: const Key('field_mode_toggle'),
            onPressed: _toggleMode,
            icon: Icon(
              _stepMode ? Icons.view_timeline_outlined : Icons.touch_app,
              size: 18,
            ),
            label: Text(_stepMode ? '전체 보기' : '한 단계씩'),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: _ink, size: 26),
            onPressed: _close,
          ),
        ],
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
    final double width = _padLeft * 2 + maxMm * _scale;

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
    return LayoutBuilder(
      builder: (context, c) {
        final scroll = SingleChildScrollView(
          controller: _tapeScroll,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: stack,
        );
        if (c.maxHeight >= contentH) {
          return Align(alignment: Alignment.center, child: scroll);
        }
        return SingleChildScrollView(child: scroll);
      },
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
    Widget child;
    if (l.isCut) {
      border = _ink;
      bg = _ink;
      child = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '✂ 자르기',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _showGap
                ? '+${fieldStepGap(_data, FieldStep.cut(l.position)).round()}'
                : l.position.round().toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
    } else if (!l.mark!.isBend) {
      border = Colors.grey.shade400;
      bg = Colors.white.withValues(alpha: 0.7);
      child = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '직관 끝',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            l.position.round().toString(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      );
    } else {
      final m = l.mark!;
      border = isSel ? _orange : _ink;
      bg = Colors.white;
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
              const SizedBox(width: 4),
              Text(
                _showGap ? '+${m.gap.round()}' : l.position.round().toString(),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
            ],
          ),
          Text(
            '$angleText · ${fieldDirectionLabel(m.rotation).split(' ').first}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: _red,
              fontWeight: FontWeight.bold,
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
          border: Border.all(color: border, width: isSel ? 2.5 : 1.5),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 3,
              offset: Offset(1, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _numberBadge(int n, {bool done = false, bool small = false}) {
    final double size = small ? 20 : 34;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? Colors.green.shade600 : _red,
        shape: BoxShape.circle,
      ),
      child: done
          ? Icon(Icons.check, color: Colors.white, size: small ? 14 : 22)
          : Text(
              '$n',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: small ? 12 : 18,
              ),
            ),
    );
  }

  Widget _buildStepStrip(List<FieldStep> steps) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: _strip,
        border: _highContrast
            ? const Border(top: BorderSide(color: Colors.black, width: 1.5))
            : null,
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
                color: isSel
                    ? _orange.withValues(alpha: 0.12)
                    : (s.isCut ? _ink : Colors.white),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSel ? _orange : _ink.withValues(alpha: 0.5),
                  width: isSel ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (s.isCut)
                    Icon(
                      done ? Icons.check : Icons.content_cut,
                      size: 18,
                      color: isSel ? _orange : Colors.white,
                    )
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
                          fontWeight: FontWeight.w900,
                          color: s.isCut && !isSel ? Colors.white : _ink,
                        ),
                      ),
                      Text(
                        s.isCut
                            ? '자르기'
                            : '${_fmt(s.mark!.angle)}° · ${fieldDirectionLabel(s.mark!.rotation).split(' ').first}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: s.isCut && !isSel
                              ? Colors.white70
                              : Colors.black54,
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
  }

  // ---------------- 한 단계씩 ----------------

  Widget _buildStepView(FieldMarkingData data, List<FieldStep> steps) {
    if (steps.isEmpty) return const SizedBox.shrink();
    final s = steps[_current];
    final bool done = _done.contains(_current);
    final bool isLast = _current == steps.length - 1;

    Widget body;
    if (s.isCut) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.content_cut, size: 28, color: _ink),
              const SizedBox(width: 8),
              Text(
                done ? '자르기 끝' : '여기서 자릅니다',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
            ],
          ),
          _bigNumber(s.at, gap: fieldStepGap(data, s), inch: data.inch(s.at)),
          Text(
            _showGap ? '마지막 마킹에서 · 줄자 눈금 ${s.at.round()} mm' : '관 끝 0에서 잰 자리',
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      );
    } else {
      final m = s.mark!;
      body = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _numberBadge(m.number, done: done),
                  const SizedBox(width: 8),
                  const Text(
                    '번 마킹',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ],
              ),
              _bigNumber(m.position, gap: m.gap, inch: data.inch(m.position)),
              Text(
                _showGap
                    ? (m.number == 1
                          ? '관 끝 0에서 · 줄자 눈금 ${m.position.round()} mm'
                          : '앞 마킹에서 · 줄자 눈금 ${m.position.round()} mm')
                    : (m.number == 1
                          ? '관 끝 0에서'
                          : '앞 마킹에서 ${m.gap >= 0 ? '+' : ''}${m.gap.round()} mm'),
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 40),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_fmt(m.angle)}°',
                style: const TextStyle(
                  fontSize: 52,
                  height: 1.0,
                  fontWeight: FontWeight.w900,
                  color: _red,
                ),
              ),
              if (m.hasOverBend)
                Text(
                  '${_fmt(m.targetAngle)}°까지 꺾기(스프링백)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _orange,
                  ),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _ink.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_dirIcon(m.rotation), size: 22, color: _ink),
                    const SizedBox(width: 6),
                    Text(
                      fieldDirectionLabel(m.rotation),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (m.roll != null) ...[
                const SizedBox(height: 6),
                Text(
                  '꺾기 전에 관을 ${m.roll!.round()}° 굴립니다',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        _navButton(
          icon: Icons.chevron_left_rounded,
          label: '이전',
          onTap: _current > 0 ? () => _prev(steps.length) : null,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => GestureDetector(
              key: const Key('field_step_area'),
              behavior: HitTestBehavior.opaque,
              // 가운데를 기준으로 왼쪽을 누르면 이전, 오른쪽은 다음.
              onTapUp: (d) => d.localPosition.dx < c.maxWidth / 2
                  ? _prev(steps.length)
                  : _next(steps.length),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: FittedBox(fit: BoxFit.scaleDown, child: body),
                ),
              ),
            ),
          ),
        ),
        _navButton(
          icon: isLast ? Icons.check_rounded : Icons.chevron_right_rounded,
          label: isLast ? '끝' : '다음',
          onTap: () => _next(steps.length),
          strong: true,
        ),
      ],
    );
  }

  /// 한 단계씩의 큰 숫자. 간격 보기면 앞 마킹에서 잰 값을 크게.
  /// 인치 설정이면 아래에 인치를 같이 적는다.
  Widget _bigNumber(double v, {double? gap, String inch = ''}) {
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
                fontSize: _highContrast ? 120 : 96,
                height: 1.05,
                fontWeight: FontWeight.w900,
                color: _highContrast ? Colors.black : _ink,
                letterSpacing: -2,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'mm',
              style: TextStyle(
                fontSize: _highContrast ? 26 : 22,
                fontWeight: FontWeight.bold,
                color: _highContrast ? Colors.black87 : Colors.black54,
              ),
            ),
          ],
        ),
        if (inch.isNotEmpty)
          Text(
            asGap ? '+${_data.inch(gap)}' : inch,
            key: const Key('field_step_inch'),
            style: TextStyle(
              fontSize: _highContrast ? 30 : 24,
              fontWeight: FontWeight.w800,
              color: Colors.indigo.shade700,
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
  }) {
    final enabled = onTap != null;
    return SizedBox(
      width: 88,
      child: Material(
        color: strong && enabled ? _ink : Colors.white.withValues(alpha: 0.6),
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 44,
                color: !enabled
                    ? Colors.black26
                    : (strong ? Colors.white : _ink),
              ),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: !enabled
                      ? Colors.black26
                      : (strong ? Colors.white : _ink),
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
      color: _strip,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(height: 4, color: Colors.grey.shade400),
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
                          ? _orange
                          : (_done.contains(i) ? Colors.green.shade600 : _red),
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
        return Icons.arrow_back;
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
    canvas.drawRRect(
      pipeRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey.shade600,
            Colors.grey.shade300,
            Colors.grey.shade700,
          ],
        ).createShader(pipeRect.outerRect),
    );
    canvas.drawRRect(
      pipeRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _ink,
    );

    // 줄자 바탕
    final tapeRect = Rect.fromLTWH(padLeft, tapeTop, maxMm * scale, tapeH);
    canvas.drawRect(tapeRect, Paint()..color = const Color(0xFFFFD54F));
    canvas.drawRect(
      tapeRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _ink.withValues(alpha: 0.6),
    );

    // 눈금: 10mm 짧게, 50mm 중간, 100mm 길게 + 숫자
    final tick = Paint()
      ..color = _ink
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
            color: _ink,
            fontSize: 12,
            fontWeight: FontWeight.w800,
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
              ..color = l.selected ? _orange : _red
              ..strokeWidth = l.selected ? 3 : 2,
          );
          break;
        case _LineKind.straight:
          _dashed(
            canvas,
            Offset(l.x, l.top),
            Offset(l.x, bottom),
            Paint()
              ..color = Colors.grey.shade600
              ..strokeWidth = 1.2,
          );
          break;
        case _LineKind.cut:
          canvas.drawLine(
            Offset(l.x, l.top),
            Offset(l.x, bottom),
            Paint()
              ..color = _ink
              ..strokeWidth = l.selected ? 3 : 2,
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
