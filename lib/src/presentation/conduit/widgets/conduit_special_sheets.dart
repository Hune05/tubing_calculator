import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tubing_calculator/src/core/engine/bend_path.dart';
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_sheet_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/opposite_rotation.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_special_calc.dart';

// 🚀 전선관 특수 벤딩 시트 넷: 킥, 분할 90°, 백투백 90°, 스터브업. 오프셋·새들 시트와 같이 목록에 줄을 넣는다.
// 셈은 conduit_special_calc.dart(엔진으로 끝 위치·접선까지 시험), 이 파일은 입력과 결과 보여 주기만 맡는다.

const Color _teal = AppColors.brand;
const Color _ink = AppColors.text;
const Color _sub = AppColors.textSub;
const Color _bg = AppColors.background;

/// 꺾는 방향 여섯 축(값은 꺾은 뒤 관이 향할 절대 방향).
const List<(String, double, IconData)> _kDirs = [
  ('위', 0.0, Icons.arrow_upward),
  ('앞', 360.0, Icons.call_made),
  ('왼쪽', 270.0, AppIcons.back),
  ('오른쪽', 90.0, Icons.arrow_forward),
  ('아래', 180.0, Icons.arrow_downward),
  ('뒤', 450.0, Icons.call_received),
];

String _fmt(double v, [int d = 1]) {
  final s = v.toStringAsFixed(d);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

double? _read(TextEditingController c) =>
    double.tryParse(c.text.trim().replaceAll(',', '.'));

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
    required void Function(List<Map<String, dynamic>>) onAddBends,
    required BendSheetSpecs specs,
  }) => _open(
    context,
    _KickSheet(currentRotation: currentRotation, onAddBends: onAddBends, specs: specs),
  );

  static void showSegmented(
    BuildContext context, {
    required double currentRotation,
    required void Function(List<Map<String, dynamic>>) onAddBends,
    required BendSheetSpecs specs,
  }) => _open(
    context,
    _SegmentedSheet(currentRotation: currentRotation, onAddBends: onAddBends, specs: specs),
  );

  static void showBackToBack(
    BuildContext context, {
    required double currentRotation,
    required void Function(List<Map<String, dynamic>>) onAddBends,
    required BendSheetSpecs specs,
    double? conduitOd,
  }) => _open(
    context,
    _BackToBackSheet(
      currentRotation: currentRotation,
      onAddBends: onAddBends,
      specs: specs,
      conduitOd: conduitOd,
    ),
  );

  static void showStubUp(
    BuildContext context, {
    required double currentRotation,
    required void Function(List<Map<String, dynamic>>) onAddBends,
    required BendSheetSpecs specs,
  }) => _open(
    context,
    _StubUpSheet(currentRotation: currentRotation, onAddBends: onAddBends, specs: specs),
  );
}

// ───────────────────────── 공용 부품 ─────────────────────────

class _Shell extends StatelessWidget {
  final String title;
  final String help;
  final List<Widget> children;
  const _Shell({required this.title, required this.help, required this.children});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: _sub),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(help, style: const TextStyle(color: _sub, fontSize: 13, height: 1.4)),
              const SizedBox(height: 16),
              ...children,
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }
}

class _Num extends StatelessWidget {
  final Key fieldKey;
  final String label;
  final TextEditingController ctrl;
  final String unit;
  final VoidCallback onChanged;
  final String? hint;
  const _Num({
    required this.fieldKey,
    required this.label,
    required this.ctrl,
    required this.unit,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      key: fieldKey,
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged: (_) => onChanged(),
      style: const TextStyle(color: _teal, fontSize: 20, fontWeight: FontWeight.w900),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: unit,
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    ),
  );
}

class _DirPicker extends StatelessWidget {
  final double? value;
  final ValueChanged<double> onPick;
  final String label;
  const _DirPicker({required this.value, required this.onPick, this.label = '꺾는 방향 (꺾은 뒤 관이 향할 쪽)'});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text.rich(
        TextSpan(
          text: label,
          style: TextStyle(
            color: value == null ? Colors.red.shade700 : _sub,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          children: [
            if (value == null)
              TextSpan(
                text: '  *필수',
                style: TextStyle(color: Colors.red.shade700, fontSize: 14, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final d in _kDirs)
            ChoiceChip(
              key: Key('cs_dir_${d.$2.toInt()}'),
              avatar: Icon(d.$3, size: 16, color: value == d.$2 ? Colors.white : _sub),
              label: Text(d.$1),
              selected: value == d.$2,
              selectedColor: _teal,
              labelStyle: TextStyle(
                color: value == d.$2 ? Colors.white : _ink,
                fontWeight: FontWeight.bold,
              ),
              onSelected: (_) => onPick(d.$2),
            ),
        ],
      ),
    ],
  );
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  const _Line(this.label, this.value, {this.strong = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(label, style: const TextStyle(color: _sub, fontSize: 14)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: strong ? _teal : _ink,
              fontSize: strong ? 17 : 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ResultBox extends StatelessWidget {
  final List<Widget> children;
  const _ResultBox(this.children);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _teal.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _teal.withValues(alpha: 0.25)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );
}

Widget _warn(String text) => Padding(
  padding: const EdgeInsets.only(top: 8),
  child: Text(text, style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.bold, height: 1.4)),
);

/// 지금 진행 방향에서 [rot] 방향으로 꺾을 수 있는지(나란하거나 반대면 안 된다).
bool _canBend(double heading, double rot) =>
    canBendToward(directionForRotation(heading), directionForRotation(rot));

class _AddButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  final String label;
  const _AddButton({required this.enabled, required this.onTap, this.label = '목록에 추가'});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: ElevatedButton(
      key: const Key('cs_add'),
      onPressed: enabled
          ? () {
              HapticFeedback.mediumImpact();
              onTap();
            }
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
    ),
  );
}

// ───────────────────────── 킥 ─────────────────────────

class _KickSheet extends StatefulWidget {
  final double currentRotation;
  final void Function(List<Map<String, dynamic>>) onAddBends;
  final BendSheetSpecs specs;
  const _KickSheet({required this.currentRotation, required this.onAddBends, required this.specs});

  @override
  State<_KickSheet> createState() => _KickSheetState();
}

class _KickSheetState extends State<_KickSheet> {
  final _h = TextEditingController();
  final _a = TextEditingController(text: '30');
  final _start = TextEditingController(text: '0');
  double? _dir;

  @override
  void dispose() {
    _h.dispose();
    _a.dispose();
    _start.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double? h = _read(_h), a = _read(_a);
    final double start = _read(_start) ?? 0;
    final kick = (h != null && a != null) ? conduitKick(height: h, angle: a) : null;
    final bool dirOk = _dir != null && _canBend(widget.currentRotation, _dir!);
    final double? lenForList = kick == null ? null : widget.specs.firstLength(start, a!, 0);
    final markOff = a == null ? 0.0 : widget.specs.markOffset(a);
    return _Shell(
      title: '킥',
      help: '한 번만 꺾어 높이를 올립니다(오프셋처럼 되돌아오지 않습니다). 높이와 각도로 비스듬한 관 길이와 축소값을 구하고, 꺾는 자리를 목록에 넣습니다.',
      children: [
        _Num(fieldKey: const Key('cs_height'), label: '올릴 높이', ctrl: _h, unit: 'mm', onChanged: () => setState(() {})),
        _Num(fieldKey: const Key('cs_angle'), label: '꺾는 각도', ctrl: _a, unit: '°', onChanged: () => setState(() {})),
        Wrap(
          spacing: 8,
          children: [
            for (final v in const [10.0, 22.5, 30.0, 45.0, 60.0])
              ActionChip(label: Text('${_fmt(v)}°'), onPressed: () => setState(() => _a.text = _fmt(v))),
          ],
        ),
        const SizedBox(height: 12),
        _Num(
          fieldKey: const Key('cs_start'),
          label: '시작 거리 (관 끝에서 1번 마킹까지)',
          ctrl: _start,
          unit: 'mm',
          onChanged: () => setState(() {}),
        ),
        _DirPicker(value: _dir, onPick: (v) => setState(() => _dir = v)),
        const SizedBox(height: 14),
        if (kick != null)
          _ResultBox([
            _Line('비스듬한 관 길이', '${_fmt(kick.travel)} mm', strong: true),
            _Line('앞으로 가는 거리', '${_fmt(kick.run)} mm'),
            _Line('축소값 (관이 덜 쓰이는 양)', '${_fmt(kick.shrink)} mm'),
            _Line('배수', _fmt(kick.multiplier, 3)),
            _Line('1번 마킹', '${_fmt(start)} mm'),
            _Line('꺾이는 점 (마킹 + 테이크업 ${_fmt(markOff)})', '${_fmt(lenForList!)} mm'),
          ])
        else
          const Text('높이와 각도(0° 초과 90° 미만)를 넣으십시오.', style: TextStyle(color: _sub, fontSize: 13)),
        if (_dir != null && !dirOk) _warn('지금 진행 방향과 같거나 반대 쪽으로는 꺾을 수 없습니다. 다른 방향을 고르십시오.'),
        _AddButton(
          enabled: kick != null && dirOk,
          onTap: () {
            widget.onAddBends([
              {'length': (lenForList! * 10).roundToDouble() / 10, 'angle': a, 'rotation': _dir},
            ]);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

// ───────────────────────── 분할 90° ─────────────────────────

class _SegmentedSheet extends StatefulWidget {
  final double currentRotation;
  final void Function(List<Map<String, dynamic>>) onAddBends;
  final BendSheetSpecs specs;
  const _SegmentedSheet({required this.currentRotation, required this.onAddBends, required this.specs});

  @override
  State<_SegmentedSheet> createState() => _SegmentedSheetState();
}

class _SegmentedSheetState extends State<_SegmentedSheet> {
  final _r = TextEditingController(text: '300');
  final _corner = TextEditingController();
  int _n = 5;
  double? _dir;

  @override
  void dispose() {
    _r.dispose();
    _corner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double? r = _read(_r), corner = _read(_corner);
    final seg = r == null ? null : conduitSegmented(radius: r, bends: _n);
    final bool dirOk = _dir != null && _canBend(widget.currentRotation, _dir!);
    final list = (seg != null && corner != null && dirOk)
        ? conduitSegmentedBends(cornerDistance: corner, radius: r!, bends: _n, rotation: _dir!)
        : null;
    final bool tooBig = seg != null && corner != null && corner - seg.lead <= 0;
    final double? mark1 = list == null ? null : (list.first['length'] as num).toDouble() - widget.specs.markOffset(seg!.angle);
    return _Shell(
      title: '분할 90°',
      help: '큰 반경으로 90°를 돌릴 때 작은 각을 여러 번 이어 꺾습니다. 가상의 직각 모서리까지 거리를 넣으면 꺾이는 점 간격과 첫 마킹을 구합니다.',
      children: [
        _Num(fieldKey: const Key('cs_radius'), label: '원하는 반경 R', ctrl: _r, unit: 'mm', onChanged: () => setState(() {})),
        _Num(
          fieldKey: const Key('cs_corner'),
          label: '직각 모서리까지 거리 (관 끝에서)',
          ctrl: _corner,
          unit: 'mm',
          onChanged: () => setState(() {}),
        ),
        const Text('나눌 횟수', style: TextStyle(color: _sub, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (var n = 3; n <= 9; n++)
              ChoiceChip(
                key: Key('cs_n_$n'),
                label: Text('$n번'),
                selected: _n == n,
                selectedColor: _teal,
                labelStyle: TextStyle(color: _n == n ? Colors.white : _ink, fontWeight: FontWeight.bold),
                onSelected: (_) => setState(() => _n = n),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _DirPicker(value: _dir, onPick: (v) => setState(() => _dir = v)),
        const SizedBox(height: 14),
        if (seg != null)
          _ResultBox([
            _Line('한 번에 꺾는 각', '${_fmt(seg.angle, 2)}°', strong: true),
            _Line('꺾이는 점 사이 간격', '${_fmt(seg.spacing)} mm', strong: true),
            _Line('모서리에서 첫·끝 꺾이는 점까지', '${_fmt(seg.lead)} mm'),
            _Line('호 길이 (반 원호)', '${_fmt(seg.arcLength)} mm'),
            if (list != null) _Line('첫 줄 길이 (꺾이는 점)', '${_fmt((list.first['length'] as num).toDouble())} mm'),
            if (mark1 != null) _Line('1번 마킹', '${_fmt(mark1)} mm'),
          ])
        else
          const Text('반경(0 초과)을 넣으십시오.', style: TextStyle(color: _sub, fontSize: 13)),
        if (tooBig) _warn('반경이 모서리 거리에 비해 너무 큽니다. 반경을 줄이거나 거리를 늘리십시오.'),
        if (_dir != null && !dirOk) _warn('지금 진행 방향과 같거나 반대 쪽으로는 꺾을 수 없습니다. 다른 방향을 고르십시오.'),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            '이어지는 다음 구간은 목록에서 직접 넣으십시오. 마지막 꺾이는 점은 모서리에서 위 "첫·끝 꺾이는 점" 거리만큼 앞에 있습니다.',
            style: TextStyle(color: _sub, fontSize: 12, height: 1.4),
          ),
        ),
        _AddButton(
          enabled: list != null,
          label: '목록에 $_n줄 추가',
          onTap: () {
            widget.onAddBends(list!);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

// ───────────────────────── 백투백 90° ─────────────────────────

class _BackToBackSheet extends StatefulWidget {
  final double currentRotation;
  final void Function(List<Map<String, dynamic>>) onAddBends;
  final BendSheetSpecs specs;
  final double? conduitOd;
  const _BackToBackSheet({
    required this.currentRotation,
    required this.onAddBends,
    required this.specs,
    this.conduitOd,
  });

  @override
  State<_BackToBackSheet> createState() => _BackToBackSheetState();
}

class _BackToBackSheetState extends State<_BackToBackSheet> {
  final _first = TextEditingController();
  final _dist = TextEditingController();
  late final TextEditingController _od = TextEditingController(
    text: widget.conduitOd == null ? '' : _fmt(widget.conduitOd!),
  );
  bool _outside = true;
  double? _dir;

  @override
  void dispose() {
    _first.dispose();
    _dist.dispose();
    _od.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double? first = _read(_first), dist = _read(_dist), od = _read(_od);
    final double heading = widget.currentRotation;
    final double second = oppositeRotation(heading);
    final bool dirOk = _dir != null && _canBend(heading, _dir!);
    // 첫 90°는 진행 방향에 수직으로 꺾어야 U자가 된다.
    final bool perpendicular = _dir == null
        ? true
        : directionForRotation(heading).dot(directionForRotation(_dir!)).abs() < 1e-6;
    final double? spacing = (dist != null && od != null && od > 0)
        ? conduitBackToBackSpacing(distance: dist, od: od, outside: _outside)
        : null;
    final list = (first != null && spacing != null && dirOk && perpendicular)
        ? conduitBackToBackBends(firstLength: first, spacing: spacing, firstRotation: _dir!, secondRotation: second)
        : null;
    return _Shell(
      title: '백투백 90°',
      help: '같은 평면에서 90°를 두 번 꺾어 U자로 만듭니다. 두 다리 사이 거리를 넣으면 꺾이는 점 간격을 구해 목록에 두 줄을 넣습니다.',
      children: [
        _Num(
          fieldKey: const Key('cs_first'),
          label: '첫 다리 길이 (관 끝에서 첫 꺾이는 점까지)',
          ctrl: _first,
          unit: 'mm',
          onChanged: () => setState(() {}),
        ),
        _Num(fieldKey: const Key('cs_dist'), label: '두 다리 사이 거리', ctrl: _dist, unit: 'mm', onChanged: () => setState(() {})),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('cs_outside'),
              label: const Text('바깥~바깥 (등 사이)'),
              selected: _outside,
              selectedColor: _teal,
              labelStyle: TextStyle(color: _outside ? Colors.white : _ink, fontWeight: FontWeight.bold),
              onSelected: (_) => setState(() => _outside = true),
            ),
            ChoiceChip(
              key: const Key('cs_inside'),
              label: const Text('안쪽~안쪽'),
              selected: !_outside,
              selectedColor: _teal,
              labelStyle: TextStyle(color: !_outside ? Colors.white : _ink, fontWeight: FontWeight.bold),
              onSelected: (_) => setState(() => _outside = false),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Num(
          fieldKey: const Key('cs_od'),
          label: '관 바깥지름',
          ctrl: _od,
          unit: 'mm',
          hint: '예: 후강 22 = 26.5',
          onChanged: () => setState(() {}),
        ),
        _DirPicker(value: _dir, onPick: (v) => setState(() => _dir = v), label: '첫 90°를 꺾는 방향'),
        const SizedBox(height: 14),
        if (spacing != null)
          _ResultBox([
            _Line('꺾이는 점 사이 간격', '${_fmt(spacing)} mm', strong: true),
            _Line('두 번째 90° 방향', '처음 진행 방향의 반대'),
            if (first != null) _Line('1번 마킹', '${_fmt(first - widget.specs.markOffset(90))} mm'),
          ])
        else
          const Text('두 다리 사이 거리와 관 바깥지름을 넣으십시오.', style: TextStyle(color: _sub, fontSize: 13)),
        if (spacing != null && spacing <= 0) _warn('두 다리 사이 거리가 관 바깥지름보다 작아 만들 수 없습니다.'),
        if (_dir != null && dirOk && !perpendicular) _warn('U자는 진행 방향에 수직인 방향으로 꺾어야 합니다.'),
        if (_dir != null && !dirOk) _warn('지금 진행 방향과 같거나 반대 쪽으로는 꺾을 수 없습니다. 다른 방향을 고르십시오.'),
        _AddButton(
          enabled: list != null,
          label: '목록에 2줄 추가',
          onTap: () {
            widget.onAddBends(list!);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

// ───────────────────────── 스터브업 ─────────────────────────

class _StubUpSheet extends StatefulWidget {
  final double currentRotation;
  final void Function(List<Map<String, dynamic>>) onAddBends;
  final BendSheetSpecs specs;
  const _StubUpSheet({required this.currentRotation, required this.onAddBends, required this.specs});

  @override
  State<_StubUpSheet> createState() => _StubUpSheetState();
}

class _StubUpSheetState extends State<_StubUpSheet> {
  final _stub = TextEditingController();
  double? _dir;

  @override
  void dispose() {
    _stub.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double? s = _read(_stub);
    final bool dirOk = _dir != null && _canBend(widget.currentRotation, _dir!);
    final list = (s != null && dirOk) ? conduitStubBends(stub: s, rotation: _dir!) : null;
    final double off = widget.specs.markOffset(90);
    return _Shell(
      title: '스터브업 (90°)',
      help: '관 끝에서 한 번 90°로 꺾어 세웁니다. 스터브 길이를 넣으면 마킹 자리(길이 − 테이크업)를 알려 주고 목록에 넣습니다.',
      children: [
        _Num(fieldKey: const Key('cs_stub'), label: '스터브 길이 (관 끝에서)', ctrl: _stub, unit: 'mm', onChanged: () => setState(() {})),
        _DirPicker(value: _dir, onPick: (v) => setState(() => _dir = v)),
        const SizedBox(height: 14),
        if (s != null && s > 0)
          _ResultBox([
            _Line('마킹 자리', '${_fmt(s - off)} mm', strong: true),
            _Line('테이크업', '${_fmt(off)} mm'),
          ])
        else
          const Text('스터브 길이를 넣으십시오.', style: TextStyle(color: _sub, fontSize: 13)),
        if (s != null && s - off <= 0) _warn('스터브가 테이크업보다 짧아 마킹이 관 끝 안쪽에 찍힙니다.'),
        if (_dir != null && !dirOk) _warn('지금 진행 방향과 같거나 반대 쪽으로는 꺾을 수 없습니다. 다른 방향을 고르십시오.'),
        _AddButton(
          enabled: list != null,
          onTap: () {
            widget.onAddBends(list!);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
