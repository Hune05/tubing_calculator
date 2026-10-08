import 'package:flutter/material.dart';

import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/core/engine/bend_path.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_sheet_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/opposite_rotation.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/quick_kick_guide.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/sheet_direction_gate.dart' show BendRule;
import 'package:tubing_calculator/src/presentation/conduit/conduit_special_calc.dart';
import 'package:tubing_calculator/src/presentation/conduit/widgets/conduit_special_guides.dart';
import 'package:tubing_calculator/src/presentation/conduit/widgets/conduit_special_ui.dart';

// 🚀 전선관 특수 벤딩 시트 넷: 킥, 분할 90°, 백투백 90°, 스터브업. 오프셋·새들·롤링 오프셋 시트와 같은 틀
// (머리 줄 · 그림 · 시작 거리 상자 · 입력 칸 · 6축 방향 · 결과 상자 · 경고 창)이고, 줄을 목록에 넣는 방식도 같다.
// 셈은 conduit_special_calc.dart(엔진으로 끝 위치·접선까지 시험), 틀은 conduit_special_ui.dart.

typedef ConduitAddBends = void Function(List<Map<String, dynamic>> bends);

class ConduitSpecialSheets {
  static void _open(BuildContext context, Widget child) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => child,
  );

  static void showKick(
    BuildContext context, {
    required double currentRotation,
    required ConduitAddBends onAddBends,
    required BendSheetSpecs specs,
    BendRule? canBendTo,
  }) => _open(
    context,
    _KickSheet(currentRotation: currentRotation, onAddBends: onAddBends, specs: specs, canBendTo: canBendTo),
  );

  static void showSegmented(
    BuildContext context, {
    required double currentRotation,
    required ConduitAddBends onAddBends,
    required BendSheetSpecs specs,
    BendRule? canBendTo,
  }) => _open(
    context,
    _SegmentedSheet(currentRotation: currentRotation, onAddBends: onAddBends, specs: specs, canBendTo: canBendTo),
  );

  static void showBackToBack(
    BuildContext context, {
    required double currentRotation,
    required ConduitAddBends onAddBends,
    required BendSheetSpecs specs,
    double? conduitOd,
    BendRule? canBendTo,
  }) => _open(
    context,
    _BackToBackSheet(
      currentRotation: currentRotation,
      onAddBends: onAddBends,
      specs: specs,
      conduitOd: conduitOd,
      canBendTo: canBendTo,
    ),
  );

  static void showStubUp(
    BuildContext context, {
    required double currentRotation,
    required ConduitAddBends onAddBends,
    required BendSheetSpecs specs,
    BendRule? canBendTo,
  }) => _open(
    context,
    _StubUpSheet(currentRotation: currentRotation, onAddBends: onAddBends, specs: specs, canBendTo: canBendTo),
  );
}

/// 지금 진행 방향에서 [rot] 방향으로 꺾을 수 있는지(나란하거나 반대면 안 된다).
bool _canBend(double heading, double rot) =>
    canBendToward(directionForRotation(heading), directionForRotation(rot));

double _r1(double v) => double.parse(v.toStringAsFixed(1));

const String _kCannotBend = '넣을 수 없습니다. 지금 진행 방향과 같거나 반대 쪽으로는 꺾을 수 없습니다.';

/// 네 시트가 같이 쓰는 뼈대: 값 칸 변화에 다시 그리기, 방향 고르기, 넣기 전 검사.
abstract class _SheetState<T extends StatefulWidget> extends State<T> {
  double? dir;
  final List<TextEditingController> _ctrls = [];

  TextEditingController ctrl([String text = '']) {
    final c = TextEditingController(text: text)..addListener(() => setState(() {}));
    _ctrls.add(c);
    return c;
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  /// 방향을 안 골랐으면 경고 창, 지금 진행 방향과 나란하면 알림. 문제가 없으면 true.
  bool checkDirection(double heading, {BendRule? rule}) {
    if (dir == null) {
      csShowDirectionWarning(context);
      return false;
    }
    // 규칙(실제 경로 기준)이 있으면 그것으로, 없으면 진행 방향값(heading)으로 따진다.
    final ok = rule != null ? rule(dir!) : _canBend(heading, dir!);
    if (!ok) {
      csSnackMissing(context, _kCannotBend);
      return false;
    }
    return true;
  }
}

// ───────────────────────── 킥 ─────────────────────────

class _KickSheet extends StatefulWidget {
  final double currentRotation;
  final ConduitAddBends onAddBends;
  final BendSheetSpecs specs;

  /// 지금 진행 방향(실제 경로 기준)에서 그 방향으로 꺾을 수 있는지. 없으면 진행 방향값으로 따진다.
  final BendRule? canBendTo;
  const _KickSheet({required this.currentRotation, required this.onAddBends, required this.specs, this.canBendTo});

  @override
  State<_KickSheet> createState() => _KickSheetState();
}

class _KickSheetState extends _SheetState<_KickSheet> {
  late final _h = ctrl();
  late final _a = ctrl('30');
  late final _start = ctrl('0');

  void _apply(double? h, double? a) {
    if (!checkDirection(widget.currentRotation, rule: widget.canBendTo)) return;
    final kick = (h != null && a != null) ? conduitKick(height: h, angle: a) : null;
    if (kick == null) {
      csSnackMissing(
        context,
        (a != null && a >= 90) ? '넣을 수 없습니다. 각도는 90°보다 작아야 합니다.' : '넣을 수 없습니다. 높이와 각도를 넣으십시오.',
      );
      return;
    }
    final double start = csRead(_start) ?? 0;
    final double len = _r1(widget.specs.firstLength(start, a!, 0));
    widget.onAddBends([
      {'length': len, 'angle': _r1(a), 'rotation': dir},
    ]);
    csSnackAdded(
      context,
      '1번 마킹이 ${start.toStringAsFixed(0)}mm 자리에 찍힙니다. 축소값 ${csFmt(kick.shrink)}mm만큼 직진 거리가 줄어듭니다.',
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final double? h = csRead(_h), a = csRead(_a);
    final kick = (h != null && a != null) ? conduitKick(height: h, angle: a) : null;
    final double gain = kick == null
        ? 0
        : effectiveGain(
            radius: widget.specs.radius,
            angleDeg: a!,
            measuredGain90: widget.specs.gain90,
          );
    return CsFrame(
      title: '킥',
      guide: QuickKickGuide(
        heightMm: h ?? 0,
        runMm: kick?.run ?? 0,
        travelMm: kick?.travel ?? 0,
        angleDeg: a ?? 0,
      ),
      children: [
        CsInfoBox(
          title: '장애물 앞 시작 거리 (선택)',
          note: '1번 마킹이 이 거리에 찍힙니다.',
          field: CsField(fieldKey: const Key('cs_start'), ctrl: _start, hint: '거리 mm'),
        ),
        const SizedBox(height: 16),
        const CsLabel('올릴 높이 (H)'),
        Row(
          children: [
            Expanded(child: CsField(fieldKey: const Key('cs_height'), ctrl: _h, hint: '높이 mm')),
            const SizedBox(width: 12),
            CsQuickBtn(ctrl: _h, amount: -5, label: '-5'),
            const SizedBox(width: 4),
            CsQuickBtn(ctrl: _h, amount: 5, label: '+5'),
          ],
        ),
        const SizedBox(height: 16),
        const CsLabel('각도 (∠)'),
        Wrap(
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(width: 120, child: CsField(fieldKey: const Key('cs_angle'), ctrl: _a, hint: '각도 °')),
            const SizedBox(width: 12),
            for (final v in const [15.0, 22.5, 30.0, 45.0, 60.0]) CsQuickAngleBtn(ctrl: _a, value: v),
          ],
        ),
        const SizedBox(height: 24),
        CsDirectionSelector(
          value: dir,
          onPick: (v) => setState(() => dir = v),
          canBendTo: widget.canBendTo,
        ),
        const SizedBox(height: 16),
        CsResultBox(
          title: '계산된 빗변 (Travel)',
          value: kick == null ? null : '${csFmt(kick.travel)} mm',
          onPressed: () => _apply(h, a),
          details: kick == null
              ? const []
              : [
                  CsDetail(
                    label: '수평 거리 (Run)',
                    value: '${csFmt(kick.run)} mm',
                    note: '(킥 구간의 수평 거리 · 배수 ${csFmt(kick.multiplier, 3)})',
                  ),
                  CsShrinkGainRow(
                    shrink: '+${csFmt(kick.shrink)} mm',
                    shrinkNote: '(직진 거리가 이만큼 줄어듭니다)',
                    gainLabel: '게인 (벤드 1곳)',
                    gain: '-${csFmt(gain)} mm',
                  ),
                ],
        ),
      ],
    );
  }
}

// ───────────────────────── 분할 90° ─────────────────────────

class _SegmentedSheet extends StatefulWidget {
  final double currentRotation;
  final ConduitAddBends onAddBends;
  final BendSheetSpecs specs;

  /// 지금 진행 방향(실제 경로 기준)에서 그 방향으로 꺾을 수 있는지. 없으면 진행 방향값으로 따진다.
  final BendRule? canBendTo;
  const _SegmentedSheet({required this.currentRotation, required this.onAddBends, required this.specs, this.canBendTo});

  @override
  State<_SegmentedSheet> createState() => _SegmentedSheetState();
}

class _SegmentedSheetState extends _SheetState<_SegmentedSheet> {
  late final _r = ctrl('300');
  late final _corner = ctrl();
  int _n = 5;

  void _apply(double? r, double? corner) {
    if (!checkDirection(widget.currentRotation, rule: widget.canBendTo)) return;
    final seg = r == null ? null : conduitSegmented(radius: r, bends: _n);
    if (seg == null) {
      csSnackMissing(context, '넣을 수 없습니다. 반경을 넣으십시오.');
      return;
    }
    if (corner == null || corner <= 0) {
      csSnackMissing(context, '넣을 수 없습니다. 직각 모서리까지 거리를 넣으십시오.');
      return;
    }
    final list = conduitSegmentedBends(cornerDistance: corner, radius: r!, bends: _n, rotation: dir!);
    if (list == null) {
      csSnackMissing(context, '넣을 수 없습니다. 반경이 모서리 거리에 비해 너무 큽니다. 반경을 줄이거나 거리를 늘리십시오.');
      return;
    }
    widget.onAddBends(list);
    final double first = (list.first['length'] as num).toDouble();
    csSnackAdded(
      context,
      '$_n줄을 넣었습니다. 1번 마킹이 ${csFmt(first - widget.specs.markOffset(seg.angle), 0)}mm 자리에 찍힙니다.',
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final double? r = csRead(_r), corner = csRead(_corner);
    final seg = r == null ? null : conduitSegmented(radius: r, bends: _n);
    final list = (seg != null && corner != null && dir != null)
        ? conduitSegmentedBends(cornerDistance: corner, radius: r!, bends: _n, rotation: dir!)
        : null;
    final bool tooBig = seg != null && corner != null && corner - seg.lead <= 0;
    final double gainPer = seg == null
        ? 0
        : effectiveGain(radius: widget.specs.radius, angleDeg: seg.angle, measuredGain90: widget.specs.gain90);
    return CsFrame(
      title: '분할 90°',
      guide: SegmentedGuide(
        radiusMm: r ?? 0,
        bends: _n,
        spacingMm: seg?.spacing ?? 0,
        angleDeg: seg?.angle ?? 0,
      ),
      children: [
        CsInfoBox(
          title: '직각 모서리까지 거리',
          // 10-09: 어디까지 재는지 적음(관 등까지 재면 바깥지름 절반만큼 어긋난다).
          note: '관 끝에서 가상의 직각 모서리까지입니다. 모서리는 두 관의 가운데 선이 만나는 자리로 잽니다(관 등까지 재면 관 굵기 절반만큼 어긋납니다). 첫 꺾이는 점은 모서리보다 조금 앞에 옵니다.',
          field: CsField(fieldKey: const Key('cs_corner'), ctrl: _corner, hint: '거리 mm'),
        ),
        const SizedBox(height: 16),
        const CsLabel('원하는 반경 (R)'),
        CsField(fieldKey: const Key('cs_radius'), ctrl: _r, hint: '반경 mm'),
        const SizedBox(height: 16),
        const CsLabel('나눌 횟수'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var n = 3; n <= 9; n++)
              CsChoice(
                choiceKey: Key('cs_n_$n'),
                label: '$n번',
                selected: _n == n,
                onTap: () => setState(() => _n = n),
              ),
          ],
        ),
        const SizedBox(height: 24),
        CsDirectionSelector(
          value: dir,
          onPick: (v) => setState(() => dir = v),
          canBendTo: widget.canBendTo,
        ),
        const SizedBox(height: 16),
        CsResultBox(
          title: '한 번에 꺾는 각',
          value: seg == null ? null : '${csFmt(seg.angle, 2)} °',
          btnText: '목록에 넣기',
          onPressed: () => _apply(r, corner),
          details: seg == null
              ? const []
              : [
                  CsDetail(
                    label: '꺾이는 점 사이 간격',
                    value: '${csFmt(seg.spacing)} mm',
                    note: '(2 × R × tan(각 ÷ 2))',
                  ),
                  CsDetail(
                    label: '모서리에서 첫·끝 꺾이는 점까지',
                    value: '${csFmt(seg.lead)} mm',
                    note: '(R × (1 − tan(각 ÷ 2)) · 호 길이 ${csFmt(seg.arcLength)} mm)',
                  ),
                  if (list != null)
                    CsDetail(
                      label: '1번 마킹',
                      value: '${csFmt((list.first['length'] as num).toDouble() - widget.specs.markOffset(seg.angle))} mm',
                      note: '(첫 꺾이는 점 ${csFmt((list.first['length'] as num).toDouble())} − 테이크업)',
                    ),
                  if (tooBig)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        '반경이 모서리 거리에 비해 너무 큽니다. 반경을 줄이거나 거리를 늘리십시오.',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  CsShrinkGainRow(
                    gainLabel: '게인 (벤드 $_n곳)',
                    gain: '-${csFmt(gainPer * _n)} mm',
                  ),
                ],
        ),
      ],
    );
  }
}

// ───────────────────────── 백투백 90° ─────────────────────────

class _BackToBackSheet extends StatefulWidget {
  final double currentRotation;
  final ConduitAddBends onAddBends;
  final BendSheetSpecs specs;

  /// 지금 진행 방향(실제 경로 기준)에서 그 방향으로 꺾을 수 있는지. 없으면 진행 방향값으로 따진다.
  final BendRule? canBendTo;
  final double? conduitOd;
  const _BackToBackSheet({
    required this.currentRotation,
    required this.onAddBends,
    required this.specs,
    this.conduitOd,
    this.canBendTo,
  });

  @override
  State<_BackToBackSheet> createState() => _BackToBackSheetState();
}

class _BackToBackSheetState extends _SheetState<_BackToBackSheet> {
  late final _first = ctrl();
  late final _dist = ctrl();
  late final _od = ctrl(widget.conduitOd == null ? '' : csFmt(widget.conduitOd!));
  bool _outside = true;

  bool get _perpendicular =>
      dir == null ||
      directionForRotation(widget.currentRotation).dot(directionForRotation(dir!)).abs() < 1e-6;

  void _apply(double? first, double? spacing) {
    if (!checkDirection(widget.currentRotation, rule: widget.canBendTo)) return;
    if (!_perpendicular) {
      csSnackMissing(context, '넣을 수 없습니다. U자는 진행 방향에 수직인 방향으로 꺾어야 합니다.');
      return;
    }
    if (first == null || first <= 0) {
      csSnackMissing(context, '넣을 수 없습니다. 첫 다리 길이를 넣으십시오.');
      return;
    }
    if (spacing == null) {
      csSnackMissing(context, '넣을 수 없습니다. 두 다리 사이 거리와 관 바깥지름을 넣으십시오.');
      return;
    }
    final list = conduitBackToBackBends(
      firstLength: first,
      spacing: spacing,
      firstRotation: dir!,
      secondRotation: oppositeRotation(widget.currentRotation),
    );
    if (list == null) {
      csSnackMissing(context, '넣을 수 없습니다. 두 다리 사이 거리가 관 바깥지름보다 작아 만들 수 없습니다.');
      return;
    }
    // 마킹이 관 끝 안쪽에 찍히면 꺾을 수 없으니 넣지 않는다(10-08).
    final off = widget.specs.markOffset(90);
    if (first - off <= 0) {
      csSnackMissing(context, '넣을 수 없습니다. 첫 다리가 테이크업(${csFmt(off)}mm)보다 짧아 꺾을 수 없습니다. ${csFmt(off)}mm보다 길게 넣으십시오.');
      return;
    }
    widget.onAddBends(list);
    csSnackAdded(
      context,
      '2줄을 넣었습니다. 1번 마킹이 ${csFmt(first - widget.specs.markOffset(90), 0)}mm 자리에 찍힙니다.',
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final double? first = csRead(_first), dist = csRead(_dist), od = csRead(_od);
    final double? spacing = (dist != null && od != null && od > 0)
        ? conduitBackToBackSpacing(distance: dist, od: od, outside: _outside)
        : null;
    final double gainPer = effectiveGain(
      radius: widget.specs.radius,
      angleDeg: 90,
      measuredGain90: widget.specs.gain90,
    );
    return CsFrame(
      title: '백투백 90°',
      guide: BackToBackGuide(
        spacingMm: (spacing != null && spacing > 0) ? spacing : 0,
        distanceMm: dist ?? 0,
        firstMm: first ?? 0,
        outside: _outside,
      ),
      children: [
        CsInfoBox(
          title: '첫 다리 길이',
          note: '관 끝에서 첫 꺾이는 점까지입니다. 1번 마킹은 여기서 테이크업을 뺀 자리입니다.',
          field: CsField(fieldKey: const Key('cs_first'), ctrl: _first, hint: '길이 mm'),
        ),
        const SizedBox(height: 16),
        const CsLabel('두 다리 사이 거리'),
        CsField(fieldKey: const Key('cs_dist'), ctrl: _dist, hint: '거리 mm'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            CsChoice(
              choiceKey: const Key('cs_outside'),
              label: '바깥~바깥 (등 사이)',
              selected: _outside,
              onTap: () => setState(() => _outside = true),
            ),
            CsChoice(
              choiceKey: const Key('cs_inside'),
              label: '안쪽~안쪽',
              selected: !_outside,
              onTap: () => setState(() => _outside = false),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const CsLabel('관 바깥지름'),
        CsField(fieldKey: const Key('cs_od'), ctrl: _od, hint: '바깥지름 mm (후강 22 = 26.5)'),
        const SizedBox(height: 24),
        CsDirectionSelector(
          value: dir,
          onPick: (v) => setState(() => dir = v),
          canBendTo: widget.canBendTo,
          title: '첫 90°를 꺾는 방향 (6축)',
        ),
        const SizedBox(height: 16),
        CsResultBox(
          title: '꺾이는 점 사이 간격',
          value: (spacing != null && spacing > 0) ? '${csFmt(spacing)} mm' : null,
          onPressed: () => _apply(first, spacing),
          details: (spacing != null && spacing > 0)
              ? [
                  const CsDetail(
                    label: '두 번째 90° 방향',
                    value: '처음 진행 방향의 반대',
                    note: '(같은 평면에서 U자로 돌아옵니다)',
                  ),
                  if (first != null && first > 0)
                    CsDetail(
                      label: '1번 마킹',
                      value: '${csFmt(first - widget.specs.markOffset(90))} mm',
                      note: '(첫 다리 ${csFmt(first)} − 테이크업)',
                    ),
                  if (first != null && first > 0 && first - widget.specs.markOffset(90) <= 0)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        '첫 다리가 테이크업보다 짧아 꺾을 수 없습니다.',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  if (dir != null && !_perpendicular)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'U자는 진행 방향에 수직인 방향으로 꺾어야 합니다.',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  CsShrinkGainRow(gainLabel: '게인 (벤드 2곳)', gain: '-${csFmt(gainPer * 2)} mm'),
                ]
              : const [],
        ),
        if (spacing != null && spacing <= 0)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '두 다리 사이 거리가 관 바깥지름보다 작아 만들 수 없습니다.',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── 스터브업 ─────────────────────────

class _StubUpSheet extends StatefulWidget {
  final double currentRotation;
  final ConduitAddBends onAddBends;
  final BendSheetSpecs specs;

  /// 지금 진행 방향(실제 경로 기준)에서 그 방향으로 꺾을 수 있는지. 없으면 진행 방향값으로 따진다.
  final BendRule? canBendTo;
  const _StubUpSheet({required this.currentRotation, required this.onAddBends, required this.specs, this.canBendTo});

  @override
  State<_StubUpSheet> createState() => _StubUpSheetState();
}

class _StubUpSheetState extends _SheetState<_StubUpSheet> {
  late final _stub = ctrl();

  void _apply(double? s) {
    if (!checkDirection(widget.currentRotation, rule: widget.canBendTo)) return;
    final list = (s == null) ? null : conduitStubBends(stub: s, rotation: dir!);
    if (list == null) {
      csSnackMissing(context, '넣을 수 없습니다. 스터브 길이를 넣으십시오.');
      return;
    }
    // 마킹이 관 끝 안쪽에 찍히면 꺾을 수 없으니 넣지 않는다(10-08: 경고만 뜨고 목록에 들어갔다).
    final off = widget.specs.markOffset(90);
    if (s! - off <= 0) {
      csSnackMissing(context, '넣을 수 없습니다. 스터브가 테이크업(${csFmt(off)}mm)보다 짧아 꺾을 수 없습니다. ${csFmt(off)}mm보다 길게 넣으십시오.');
      return;
    }
    widget.onAddBends(list);
    csSnackAdded(
      context,
      '1번 마킹이 ${csFmt(s - off, 0)}mm 자리에 찍힙니다.',
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final double? s = csRead(_stub);
    final double off = widget.specs.markOffset(90);
    final bool ok = s != null && s > 0;
    final double gain = effectiveGain(
      radius: widget.specs.radius,
      angleDeg: 90,
      measuredGain90: widget.specs.gain90,
    );
    return CsFrame(
      title: '스터브업 (90°)',
      guide: StubUpGuide(stubMm: ok ? s : 0, markMm: ok ? s - off : 0),
      children: [
        CsInfoBox(
          title: '스터브 길이',
          note: '관 끝에서 꺾이는 점까지입니다. 1번 마킹은 여기서 테이크업을 뺀 자리입니다.',
          field: CsField(fieldKey: const Key('cs_stub'), ctrl: _stub, hint: '길이 mm'),
        ),
        const SizedBox(height: 24),
        CsDirectionSelector(
          value: dir,
          onPick: (v) => setState(() => dir = v),
          canBendTo: widget.canBendTo,
        ),
        const SizedBox(height: 16),
        CsResultBox(
          title: '마킹 자리',
          value: ok ? '${csFmt(s - off)} mm' : null,
          onPressed: () => _apply(s),
          details: ok
              ? [
                  CsDetail(
                    label: '테이크업 (90°)',
                    value: '${csFmt(off)} mm',
                    note: '(스터브 길이에서 뺍니다)',
                  ),
                  if (s - off <= 0)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        '스터브가 테이크업보다 짧아 꺾을 수 없습니다.',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  CsShrinkGainRow(gainLabel: '게인 (벤드 1곳)', gain: '-${csFmt(gain)} mm'),
                ]
              : const [],
        ),
      ],
    );
  }
}
