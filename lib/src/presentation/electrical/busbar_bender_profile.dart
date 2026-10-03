// 벤더 프로필·시험 조각 보정(10-03): 시험 조각을 실제로 꺾어 잰 값으로 k(중립선 계수)와 스프링백 비율을 구하고,
// 벤더 이름으로 보관해 부스바 절곡·접지바 계산기에 한 번에 적용한다.
//  · k: 바깥 치수 A·B로 꺾은 시험 조각의 실제 자른 길이 L에서 거꾸로 푼다.
//    L = A + B − BD, BD = 2(r + t)·tan(θ/2) − θ·(r + k·t) → k = ((2(r+t)·tan(θ/2) − (A + B − L)) / θ − r) / t.
//  · 스프링백: 기계에서 [setDeg]°로 꺾었더니 놓은 뒤 [measDeg]°가 되면 비율 = setDeg ÷ measDeg.
//    목표 각도 θ를 만들려면 기계를 θ × 비율로 꺾는다(경험식. 각도가 크게 다르면 시험으로 다시 맞춘다).
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 구리 부스바 k의 말이 되는 범위(Rittal·PayaPress 0.33~0.5, 여유를 두어 넓게 봄).
const double kBenderKMin = 0.2, kBenderKMax = 0.7;

class BenderProfile {
  final String name;

  /// 벤더 어댑터(꺾는 날) 안쪽 반경(mm).
  final double radius;

  /// 중립선 계수 k.
  final double k;

  /// 스프링백 비율(기계 세팅 ÷ 목표). 1이면 보정 없음.
  final double spring;

  const BenderProfile({
    required this.name,
    required this.radius,
    required this.k,
    this.spring = 1.0,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'r': radius,
    'k': k,
    'sp': spring,
  };

  static BenderProfile? fromJson(Object? m) {
    if (m is! Map) return null;
    final n = m['name'], r = m['r'], k = m['k'], sp = m['sp'];
    if (n is! String || r is! num || k is! num) return null;
    return BenderProfile(
      name: n,
      radius: r.toDouble(),
      k: k.toDouble(),
      spring: sp is num && sp > 0 ? sp.toDouble() : 1.0,
    );
  }
}

/// 시험 조각 길이에서 k를 구한다. 입력이 말이 안 되면 null.
/// [t] 두께, [r] 안쪽 반경, [a]·[b] 바깥 치수(꺾인 바깥 모서리까지), [flat] 실제 자른 길이, [deg] 꺾은 각.
double? benderKFromTest({
  required double t,
  required double r,
  required double a,
  required double b,
  required double flat,
  double deg = 90,
}) {
  if (t <= 0 || r < 0 || a <= 0 || b <= 0 || flat <= 0 || deg <= 0) return null;
  final th = deg * math.pi / 180;
  final bd = a + b - flat;
  final k = ((2 * (r + t) * math.tan(th / 2) - bd) / th - r) / t;
  return k.isFinite ? k : null;
}

/// 스프링백 비율(기계 세팅 ÷ 놓은 뒤 측정). 입력이 말이 안 되면 null.
double? benderSpringRatio(double setDeg, double measDeg) {
  if (setDeg <= 0 || measDeg <= 0) return null;
  final v = setDeg / measDeg;
  return v >= 0.8 && v <= 1.5 ? v : null;
}

/// 목표 각도를 만들기 위해 기계에서 꺾을 각도(°).
double benderMachineAngle(double target, double spring) => target * spring;

const String _storeKey = 'busbar_bender_profiles_v1';

Future<List<BenderProfile>> loadBenderProfiles() async {
  try {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_storeKey);
    if (raw == null) return [];
    final l = jsonDecode(raw);
    if (l is! List) return [];
    return [for (final e in l) ?BenderProfile.fromJson(e)];
  } catch (_) {
    return [];
  }
}

Future<void> saveBenderProfiles(List<BenderProfile> l) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(_storeKey, jsonEncode([for (final e in l) e.toJson()]));
  } catch (_) {}
}

/// 프로필 창. 고르면 [onApply]로 돌려주고, "시험 조각으로 만들기"로 새 프로필을 만든다.
/// [thickness]·[radius]는 시험 조각 입력의 기본값이다.
Future<void> openBenderProfiles(
  BuildContext context, {
  required double thickness,
  required double radius,
  required void Function(BenderProfile) onApply,
  required Color surface,
  required Color text,
  required Color textSub,
}) async {
  var list = await loadBenderProfiles();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: surface,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '벤더 프로필',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '시험 조각을 꺾어 잰 값으로 k와 스프링백을 구해 벤더별로 보관합니다. 고르면 안쪽 반경·k·스프링백이 계산기에 들어갑니다.',
                  style: TextStyle(fontSize: 13, color: textSub),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('bp_new'),
                    onPressed: () async {
                      final made = await showDialog<BenderProfile>(
                        context: ctx,
                        builder: (_) => _CalibrateDialog(
                          thickness: thickness,
                          radius: radius,
                        ),
                      );
                      if (made == null) return;
                      final l = await loadBenderProfiles();
                      l.removeWhere((e) => e.name == made.name);
                      l.insert(0, made);
                      await saveBenderProfiles(l);
                      list = l;
                      setSheet(() {});
                    },
                    icon: const Icon(Icons.straighten),
                    label: const Text('시험 조각으로 새 프로필 만들기'),
                  ),
                ),
                const SizedBox(height: 8),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      '저장한 벤더 프로필이 없습니다.',
                      key: const Key('bp_empty'),
                      style: TextStyle(color: textSub),
                    ),
                  )
                else
                  for (final e in list)
                    ListTile(
                      key: Key('bp_item_${e.name}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        e.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: text,
                        ),
                      ),
                      subtitle: Text(
                        '안쪽 반경 ${_n(e.radius)}mm · k ${_n(e.k, 3)} · 스프링백 ×${_n(e.spring, 3)}',
                        style: TextStyle(color: textSub),
                      ),
                      onTap: () {
                        onApply(e);
                        Navigator.pop(ctx);
                      },
                      trailing: IconButton(
                        key: Key('bp_del_${e.name}'),
                        tooltip: '지우기',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: ctx,
                            builder: (d) => AlertDialog(
                              content: Text('"${e.name}" 프로필을 지울까요?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(d, false),
                                  child: const Text('취소'),
                                ),
                                TextButton(
                                  key: const Key('bp_del_ok'),
                                  onPressed: () => Navigator.pop(d, true),
                                  child: const Text('지우기'),
                                ),
                              ],
                            ),
                          );
                          if (ok != true) return;
                          list.removeWhere((x) => x.name == e.name);
                          await saveBenderProfiles(list);
                          setSheet(() {});
                        },
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

String _n(double v, [int d = 1]) {
  var s = v.toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// 시험 조각 입력 창: 값을 넣는 대로 k와 스프링백 비율을 바로 보여 주고, 이름을 붙여 만든다.
class _CalibrateDialog extends StatefulWidget {
  const _CalibrateDialog({required this.thickness, required this.radius});
  final double thickness, radius;

  @override
  State<_CalibrateDialog> createState() => _CalibrateDialogState();
}

class _CalibrateDialogState extends State<_CalibrateDialog> {
  late final _name = TextEditingController();
  late final _t = TextEditingController(text: _n(widget.thickness));
  late final _r = TextEditingController(text: _n(widget.radius));
  final _a = TextEditingController();
  final _b = TextEditingController();
  final _flat = TextEditingController();
  final _setDeg = TextEditingController();
  final _measDeg = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _t, _r, _a, _b, _flat, _setDeg, _measDeg]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _v(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', ''));

  double? get _k {
    final t = _v(_t), r = _v(_r), a = _v(_a), b = _v(_b), f = _v(_flat);
    if (t == null || r == null || a == null || b == null || f == null) {
      return null;
    }
    return benderKFromTest(t: t, r: r, a: a, b: b, flat: f);
  }

  double? get _sp {
    final s = _v(_setDeg), m = _v(_measDeg);
    if (s == null || m == null) return null;
    return benderSpringRatio(s, m);
  }

  Widget _field(
    String key,
    String label,
    TextEditingController c, [
    String? h,
  ]) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      key: Key(key),
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        helperText: h,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final k = _k, sp = _sp;
    final kOk = k != null && k >= kBenderKMin && k <= kBenderKMax;
    final canSave = _name.text.trim().isNotEmpty && kOk && _v(_r) != null;
    return AlertDialog(
      title: const Text('시험 조각 보정'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '같은 규격 부스바를 L 90°로 꺾어 보고 재서 넣으십시오. 바깥 치수는 꺾인 바깥 모서리까지 잰 길이입니다.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('bp_name'),
              controller: _name,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: '프로필 이름 (벤더·어댑터)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            _field('bp_t', '두께 (mm)', _t),
            _field('bp_r', '안쪽 반경 (mm, 어댑터)', _r),
            _field('bp_a', '다리 1 바깥 치수 (mm)', _a),
            _field('bp_b', '다리 2 바깥 치수 (mm)', _b),
            _field('bp_flat', '실제 자른 길이 (mm)', _flat, '꺾기 전 곧은 막대를 잰 길이'),
            Container(
              key: const Key('bp_k_result'),
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: k == null
                    ? const Color(0xFFF1F5F9)
                    : (kOk ? const Color(0xFFE6F2F3) : const Color(0xFFFDECEC)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                k == null
                    ? 'k: 값을 넣으면 바로 계산합니다'
                    : kOk
                    ? '구한 k = ${_n(k, 3)}'
                    : '구한 k = ${_n(k, 3)} — 구리 범위(${_n(kBenderKMin)}~${_n(kBenderKMax)})를 벗어났습니다. 치수를 다시 재십시오.',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const Text(
              '스프링백(선택): 기계에서 꺾은 각도와 놓은 뒤 잰 각도를 넣으면 보정 비율을 구합니다.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 6),
            _field('bp_set', '기계에서 꺾은 각도 (°)', _setDeg),
            _field('bp_meas', '놓은 뒤 잰 각도 (°)', _measDeg),
            Container(
              key: const Key('bp_sp_result'),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sp == null
                    ? '스프링백: 넣지 않으면 보정 없음(×1)'
                    : '스프링백 비율 ×${_n(sp, 3)} (목표 90° → 기계 ${_n(benderMachineAngle(90, sp))}°)',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          key: const Key('bp_make'),
          onPressed: canSave
              ? () => Navigator.pop(
                  context,
                  BenderProfile(
                    name: _name.text.trim(),
                    radius: _v(_r)!,
                    k: double.parse(k.toStringAsFixed(3)),
                    spring: sp == null
                        ? 1.0
                        : double.parse(sp.toStringAsFixed(3)),
                  ),
                )
              : null,
          child: const Text('만들기'),
        ),
      ],
    );
  }
}
