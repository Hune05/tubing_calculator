// 아이소 + 캐드식 치수 + 검사 실측(길이·각도) 넣기(10-18, 튜브 벤딩 앱 10-17 기능을 튜브·전선관 공용으로).
// 현장 탭이 저장한 진행(실측)·도면별 각도를 읽어 치수에 붙이고, 치수·꺾이는 점을 누르면
// 현장 탭과 같은 창으로 넣는다. 굽힌 관을 잰 값이라 마킹은 안 바뀐다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/common_widgets/app_components.dart';
import '../bend_check/bend_check_model.dart';
import '../calculator/widgets/mobile_pipe_visualizer.dart';
import 'angle_measure_dialog.dart';
import 'field_marking.dart';
import 'field_marking_screen.dart';
import 'field_progress_bus.dart';

class MeasuredPipeVisualizer extends StatefulWidget {
  final List<Map<String, dynamic>> bendList;
  final double tailLength;
  final bool startFit;
  final bool endFit;
  final double bendRadius;
  final double outerDiameter;
  final double fittingDepth;
  final double totalCutLength;
  final String initialStartDir;
  final ValueChanged<String>? onStartDirChanged;
  final bool useSavedDirection;

  /// 시작 방향을 폰에 적는 칸(튜브·전선관 따로).
  final String startDirPrefKey;

  /// 현장 탭과 같은 마킹 자료(실측 단계 번호를 맞추는 데 쓴다).
  final FieldMarkingData Function() compute;

  /// 현장 탭 진행 칸(튜브 field_progress_v1, 전선관 field_progress_conduit_v1).
  final String progressKey;

  /// 배관 목록이 바뀌면 실측을 다시 읽는다.
  final Listenable dataListenable;

  /// 벤딩 실측 기록 묶음·장비 값·출처(현장 탭과 같은 값).
  final String Function() measureGroup;
  final String Function() measureSetup;
  final String? Function()? measureRef;
  final String source;

  /// 길이 0짜리 직관 줄을 벤드 순서에서 건너뛸지(튜브 현장 마킹은 건너뛴다).
  final bool skipEmptyStraight;

  const MeasuredPipeVisualizer({
    super.key,
    required this.bendList,
    required this.compute,
    required this.progressKey,
    required this.dataListenable,
    required this.measureGroup,
    required this.measureSetup,
    required this.source,
    this.measureRef,
    this.skipEmptyStraight = true,
    this.tailLength = 0.0,
    this.startFit = false,
    this.endFit = false,
    this.bendRadius = 0.0,
    this.outerDiameter = 0.0,
    this.fittingDepth = 0.0,
    this.totalCutLength = 0.0,
    this.initialStartDir = 'RIGHT',
    this.onStartDirChanged,
    this.useSavedDirection = true,
    this.startDirPrefKey = 'mobile_saved_start_dir',
  });

  @override
  State<MeasuredPipeVisualizer> createState() => _MeasuredPipeVisualizerState();
}

class _MeasuredPipeVisualizerState extends State<MeasuredPipeVisualizer> {
  Map<int, double> _measuredDiff = const {};
  double? _cutDiff;
  Map<int, double> _measuredAngle = const {};
  double _tol = kBendTolDefault;
  int _readSeq = 0;

  @override
  void initState() {
    super.initState();
    fieldProgressRev.addListener(_reload);
    widget.dataListenable.addListener(_reload);
    _reload();
  }

  @override
  void didUpdateWidget(covariant MeasuredPipeVisualizer old) {
    super.didUpdateWidget(old);
    if (old.dataListenable != widget.dataListenable) {
      old.dataListenable.removeListener(_reload);
      widget.dataListenable.addListener(_reload);
    }
    if (old.initialStartDir != widget.initialStartDir) _reload();
  }

  @override
  void dispose() {
    fieldProgressRev.removeListener(_reload);
    widget.dataListenable.removeListener(_reload);
    super.dispose();
  }

  /// 벤드 순서(현장 단계 번호)마다 배관 줄 번호.
  List<int> _bendRows() {
    final rows = <int>[];
    final list = widget.bendList;
    for (var i = 0; i < list.length; i++) {
      final len = (list[i]['length'] as num?)?.toDouble() ?? 0.0;
      final ang = (list[i]['angle'] as num?)?.toDouble() ?? 0.0;
      if (widget.skipEmptyStraight && ang == 0.0 && len <= 0.01) continue;
      if (ang > 0) rows.add(i);
    }
    return rows;
  }

  Future<void> _reload() async {
    final seq = ++_readSeq;
    final data = widget.compute();
    final tol = await loadBendTolerance();
    final byStep = data.isEmpty
        ? const <int, double>{}
        : await readFieldMeasured(widget.progressKey, data.signature);
    final angleByStep = data.isEmpty
        ? const <int, double>{}
        : await readAngleMeasured(
            data.signature,
            progressKey: widget.progressKey,
          );
    if (!mounted || seq != _readSeq) return;
    final rows = _bendRows();
    final out = <int, double>{};
    double? cut;
    byStep.forEach((step, diff) {
      if (step < rows.length) {
        out[rows[step]] = diff;
      } else if (step == data.bends.length && data.totalCut > 0) {
        cut = diff;
      }
    });
    final angles = <int, double>{};
    angleByStep.forEach((step, a) {
      if (step < rows.length) angles[rows[step]] = a;
    });
    setState(() {
      _measuredDiff = out;
      _cutDiff = cut;
      _tol = tol;
      _measuredAngle = angles;
    });
  }

  String _deg(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  /// 치수를 눌러 구간 길이(또는 절단 길이) 실측. [row] -1이면 절단 길이.
  Future<void> _onLegTap(int row) async {
    final data = widget.compute();
    if (data.isEmpty || data.error != null) return;
    final bends = data.bends;
    final k = row >= 0 ? _bendRows().indexOf(row) : -1;
    final ref = widget.measureRef?.call();
    final int step;
    final double calc;
    final String what, how, kind;
    final double? angle;
    if (row >= 0 && k >= 0 && k < bends.length && (bends[k].leg ?? 0) > 0) {
      final m = bends[k];
      step = k;
      calc = m.leg!;
      angle = m.angle;
      kind = kBendKindLeg;
      what = '${_deg(m.angle)}° ${m.number}번 구간 길이';
      how =
          '${m.number == 1 ? '관 끝' : '${m.number - 1}번 꺾이는 점'}에서 '
          '${m.number}번 꺾이는 점까지${ref == null ? '' : ' $ref 기준으로'} 재서 넣으십시오.';
    } else if (row < 0 && data.totalCut > 0) {
      step = bends.length;
      calc = data.totalCut;
      angle = null;
      kind = kBendKindCut;
      what = '절단 길이';
      how = '절단한 관 길이를 재서 넣으십시오.';
    } else {
      return;
    }
    final group = widget.measureGroup();
    final setup = widget.measureSetup();
    final res = await showDialog<({double calc, double actual})>(
      context: context,
      builder: (_) => FieldMeasureDialog(
        what: what,
        how: how,
        calc: calc,
        group: group,
        kindKey: bendKindKey(kind, angle),
        setup: setup,
        inchMode: data.inchMode,
        inchDenominator: data.inchDenominator,
      ),
    );
    if (res == null || !mounted) return;
    final ids = await readFieldMeasuredIds(widget.progressKey, data.signature);
    final at = DateTime.now();
    final id = ids[step] ?? at.millisecondsSinceEpoch.toString();
    await addBendCheck(
      BendCheck(
        id: id,
        at: at,
        group: group,
        what: what,
        calc: res.calc,
        actual: res.actual,
        kind: kind,
        angle: angle,
        setup: setup,
        source: widget.source,
      ),
    );
    final diff = res.actual - res.calc;
    await writeFieldMeasured(
      progressKey: widget.progressKey,
      signature: data.signature,
      step: step,
      diff: diff,
      id: id,
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    showAppSnack(context, '실측을 기록했습니다 (${signedMm(diff)})');
  }

  /// 꺾이는 점을 눌러 각도 실측.
  Future<void> _onBendTap(int row) async {
    final data = widget.compute();
    if (data.isEmpty || data.error != null) return;
    final k = _bendRows().indexOf(row);
    if (k < 0 || k >= data.bends.length) return;
    final m = data.bends[k];
    final res = await showDialog<({bool clear, double? value})>(
      context: context,
      builder: (_) => AngleMeasureDialog(
        number: m.number,
        design: m.angle,
        current: _measuredAngle[row],
      ),
    );
    if (res == null || !mounted) return;
    await writeAngleMeasured(
      data.signature,
      k,
      res.clear ? null : res.value,
      progressKey: widget.progressKey,
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    if (res.clear) {
      showAppSnack(context, '${m.number}번 각도 실측을 지웠습니다');
    } else {
      final r = ((res.value! - m.angle) * 10).round() / 10;
      showAppSnack(context, '각도 실측을 기록했습니다 (${r > 0 ? '+' : ''}${_deg(r)}°)');
    }
  }

  @override
  Widget build(BuildContext context) => MobilePipeVisualizer(
    bendList: widget.bendList,
    tailLength: widget.tailLength,
    initialStartDir: widget.initialStartDir,
    onStartDirChanged: widget.onStartDirChanged,
    useSavedDirection: widget.useSavedDirection,
    startDirPrefKey: widget.startDirPrefKey,
    startFit: widget.startFit,
    endFit: widget.endFit,
    isLightMode: false,
    totalCutLength: widget.totalCutLength,
    bendRadius: widget.bendRadius,
    outerDiameter: widget.outerDiameter,
    fittingDepth: widget.fittingDepth,
    showDimControl: true,
    onLegTap: _onLegTap,
    onBendTap: _onBendTap,
    measuredAngle: _measuredAngle,
    angleTolerance: kAngleTolDefault,
    measuredDiff: _measuredDiff,
    cutDiff: _cutDiff,
    tolerance: _tol,
  );
}
