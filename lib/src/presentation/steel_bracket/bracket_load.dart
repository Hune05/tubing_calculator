// 형강 브라켓 하중 확인(10-11, 상용 앱 비교 17번 — 참고값): 가로대에 얹는 무게(kg)를 넣으면 부재가 얼마나 쓰이는지
// (사용률 %), 처짐, 가새 누름, 전산볼트 당김, 벽·바닥 앵커 힘을 대략 계산한다. 설계 검토를 대신하지 못한다.
//  · 허용 응력: AISC 360 허용응력(ASD) 꼴. 휨 Ma = Fy·S / 1.67(탄성 단면 계수, 앵글은 0.8배 — AISC F10 횡비틀림
//    받침 없는 앵글), 누름 Pa = Fcr·A / 1.67(E3식, 유효 길이 계수 K: 가새 1, 문형 기둥 2), 전산볼트 당김
//    0.75·Fu·Ab / 2.0(J3.6, 강도 구분 4.6 Fu 400MPa로 봄).
//  · 처짐 기준(참고): 캔틸레버 길이/180, 양쪽 받친 보 길이/360(건축 기준 활하중 처짐 한도, 캔틸레버는 길이 2배로 봄).
//  · 모형: ㄱ자 가로대는 기둥 면에서 고정된 캔틸레버, 삼각은 기둥 면·가새 자리 두 곳에 핀, 문형·매달기는 기둥 중심·볼트
//    자리에 핀(이음을 핀으로 보니 실제보다 휨이 크게 나온다), T자는 기둥 면에서 양쪽 캔틸레버. 용접·앵커 자체 강도,
//    부재가 비틀리며 넘어지는 것, 옆에서 미는 힘(지진·바람)은 보지 않는다.
library;

import 'dart:math' as math;

import 'bracket_calc.dart';

/// 재질: 이름 → (항복 강도 Fy MPa, 탄성 계수 E MPa). 두께 16mm 이하 기준.
const Map<String, (double, double)> kBracketMaterials = {
  'SS275': (275, 200000),
  'SS235': (235, 200000),
  'SM355': (355, 200000),
  'SUS304': (205, 193000),
};

/// 무게를 얹는 방식: 끝에 한 점(문형·매달기는 가운데, T자는 양 끝 반씩), 고르게, 가로대 구멍 자리마다 나눠.
enum BracketLoadMode { point, uniform, holes }

class BracketLoadCheck {
  final String name;

  /// 쓰인 몫(1 = 100%).
  final double ratio;
  final String detail;
  const BracketLoadCheck(this.name, this.ratio, this.detail);
  bool get ok => ratio <= 1 + 1e-9;
}

class BracketLoadResult {
  final List<BracketLoadCheck> checks;

  /// 앵커·볼트 힘 같은 값 줄(합격·불합격 없이).
  final List<String> forces;
  final List<String> notes;
  const BracketLoadResult(this.checks, this.forces, this.notes);
  bool get ok => checks.every((c) => c.ok);
  double get worst => checks.fold(0.0, (m, c) => math.max(m, c.ratio));
}

const double _g = 9.80665;

String _f(double v, [int d = 1]) {
  var s = v.toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  }
  return s == '-0' ? '0' : s;
}

// 셀 수 없는 값(받침 사이가 0 등)은 "-"(점검 20: NaN이 round()에서 화면을 깨뜨렸다)
String _pct(double r) => r.isFinite ? '${(r * 100).round()}%' : '-';

/// 보 하나: 길이 [len], 점 하중 [pts](자리, N), 고른 하중 [w](N/mm, 전체). [fixed]면 x = 0 고정 캔틸레버, 아니면
/// [s1]·[s2] 두 핀.
class _Beam {
  final double len;
  final List<(double, double)> pts;
  final double w;
  final bool fixed;
  final double s1, s2;
  _Beam(
    this.len,
    this.pts,
    this.w, {
    this.fixed = false,
    this.s1 = 0,
    this.s2 = 0,
  });

  double get total => pts.fold(0.0, (s, p) => s + p.$2) + w * len;

  /// 받침 반력(핀 둘일 때).
  (double, double) get reactions {
    final m =
        pts.fold(0.0, (s, p) => s + p.$2 * (p.$1 - s1)) +
        w * len * (len / 2 - s1);
    final r2 = m / (s2 - s1);
    return (total - r2, r2);
  }

  /// 처지는 쪽(+) 휨 모멘트.
  double moment(double x) {
    if (fixed) {
      var m = 0.0;
      for (final (xi, p) in pts) {
        if (xi > x) m -= p * (xi - x);
      }
      return m - w * (len - x) * (len - x) / 2;
    }
    final (r1, r2) = reactions;
    var m = 0.0;
    if (x > s1) m += r1 * (x - s1);
    if (x > s2) m += r2 * (x - s2);
    for (final (xi, p) in pts) {
      if (xi < x) m -= p * (x - xi);
    }
    return m - w * x * x / 2;
  }

  double get maxMoment {
    var m = 0.0;
    const n = 400;
    for (var k = 0; k <= n; k++) {
      m = math.max(m, moment(len * k / n).abs());
    }
    for (final (xi, _) in pts) {
      m = math.max(m, moment(xi).abs());
    }
    if (!fixed) {
      m = math.max(m, moment(s1).abs());
      m = math.max(m, moment(s2).abs());
    }
    return m;
  }

  /// 가장 큰 처짐(mm): EI y'' = M을 두 번 적분.
  double maxDeflection(double ei) {
    const n = 600;
    final h = len / n;
    final y = List<double>.filled(n + 1, 0);
    final yp = List<double>.filled(n + 1, 0);
    for (var k = 1; k <= n; k++) {
      final x0 = (k - 1) * h, x1 = k * h;
      final c0 = moment(x0) / ei, c1 = moment(x1) / ei;
      yp[k] = yp[k - 1] + (c0 + c1) / 2 * h;
      y[k] = y[k - 1] + (yp[k - 1] + yp[k]) / 2 * h;
    }
    double at(List<double> v, double x) {
      final t = (x / h).clamp(0, n.toDouble());
      final k = t.floor().clamp(0, n - 1);
      return v[k] + (v[k + 1] - v[k]) * (t - k);
    }

    var best = 0.0;
    if (fixed) {
      for (final v in y) {
        best = math.max(best, v.abs());
      }
      return best;
    }
    // y = c0 + c1 x + Y, 두 핀에서 0
    final ys1 = at(y, s1), ys2 = at(y, s2);
    final c1 = -(ys2 - ys1) / (s2 - s1);
    final c0 = -ys1 - c1 * s1;
    for (var k = 0; k <= n; k++) {
      best = math.max(best, (c0 + c1 * k * h + y[k]).abs());
    }
    return best;
  }
}

/// 하중 확인. [kg] 가로대 한 단에 얹는 무게, [mode] 얹는 방식, [material] 재질 이름.
/// 셀 수 없는 값(NaN·무한대)이 나온 줄은 빼고 알림 한 줄로(점검 20, 10-11: 입력 중간 값에서 화면이 깨졌다).
BracketLoadResult bracketLoad(
  BracketPlan plan, {
  required double kg,
  BracketLoadMode mode = BracketLoadMode.uniform,
  String material = 'SS275',
}) {
  final r = _bracketLoad(plan, kg: kg, mode: mode, material: material);
  final ok = [
    for (final c in r.checks)
      if (c.ratio.isFinite && c.ratio >= 0) c,
  ];
  if (ok.length == r.checks.length) return r;
  return BracketLoadResult(ok, r.forces, [
    ...r.notes,
    '치수가 맞지 않아 셀 수 없는 줄은 뺐습니다(받침 사이 거리를 보십시오).',
  ]);
}

BracketLoadResult _bracketLoad(
  BracketPlan plan, {
  required double kg,
  BracketLoadMode mode = BracketLoadMode.uniform,
  String material = 'SS275',
}) {
  final checks = <BracketLoadCheck>[];
  final forces = <String>[];
  final notes = <String>[];
  if (kg <= 0) return const BracketLoadResult([], [], []);
  final (fy, e) = kBracketMaterials[material] ?? kBracketMaterials['SS275']!;
  final p = kg * _g; // N
  final i = plan.input;
  BracketMember? find(String name) {
    for (final m in plan.members) {
      if (m.name == name) return m;
    }
    return null;
  }

  final arm = find('가로대');
  if (arm == null) {
    notes.add('가로대가 없어 하중을 확인하지 않았습니다.');
    return BracketLoadResult(checks, forces, notes);
  }
  if (arm.view.unknown) {
    notes.add('가로대 규격의 단면을 몰라 하중을 확인하지 않았습니다.');
    return BracketLoadResult(checks, forces, notes);
  }

  double allowM(BracketMember m) {
    final f =
        m.profile.kind == BracketProfileKind.angle ||
            m.profile.kind == BracketProfileKind.unequalAngle
        ? 0.8
        : 1.0;
    return f * fy * m.view.props.modulus / 1.67;
  }

  double allowP(BracketMember m, double klen) {
    final pr = m.view.props;
    if (pr.rMin <= 0) return 0;
    final lam = klen / pr.rMin;
    if (lam > 200) {
      notes.add(
        '${m.name}이 가늘어(KL/r ${_f(lam, 0)}, 200 넘음) 쉽게 휩니다. 굵은 규격을 쓰십시오.',
      );
    }
    final fe = math.pi * math.pi * e / (lam * lam);
    final fcr = lam <= 4.71 * math.sqrt(e / fy)
        ? math.pow(0.658, fy / fe) * fy
        : 0.877 * fe;
    return fcr * pr.area / 1.67;
  }

  void bendCheck(BracketMember m, double mMax, String what) {
    final ma = allowM(m);
    if (ma <= 0) return;
    final stress = mMax / m.view.props.modulus;
    checks.add(
      BracketLoadCheck(
        '$what 휨',
        mMax / ma,
        '휨 응력 ${_f(stress)}MPa · 허용 ${_f(ma / m.view.props.modulus)}MPa',
      ),
    );
  }

  void deflCheck(double d, double span, bool cantilever, String what) {
    final lim = span / (cantilever ? 180 : 360);
    if (lim <= 0) return;
    checks.add(
      BracketLoadCheck(
        '$what 처짐',
        d / lim,
        '${_f(d, 2)}mm (길이/${d > 0 ? _f(span / d, 0) : '∞'}) · 기준 길이/${cantilever ? 180 : 360} = ${_f(lim, 1)}mm',
      ),
    );
  }

  /// 가로대 위 하중을 보 좌표로: [toBeam]은 가로대 기준 끝에서 거리 → 보 좌표.
  (List<(double, double)>, double) loads(
    double len,
    double Function(double) toBeam, {
    required double pointAt,
    List<double>? pointsAt,
  }) {
    switch (mode) {
      case BracketLoadMode.point:
        final ps = pointsAt ?? [pointAt];
        return ([for (final x in ps) (x, p / ps.length)], 0);
      case BracketLoadMode.uniform:
        return (const [], p / len);
      case BracketLoadMode.holes:
        final xs = <double>{
          for (final h in arm.holes)
            if (!h.label.startsWith('볼트')) toBeam(h.fromEnd),
        }.where((x) => x >= -1e-6 && x <= len + 1e-6).toList();
        if (xs.isEmpty) {
          notes.add('가로대 구멍이 없어 무게를 고르게 얹은 것으로 계산했습니다.');
          return (const [], p / len);
        }
        return ([for (final x in xs) (x, p / xs.length)], 0);
    }
  }

  final ei = e * arm.view.props.inertia;
  switch (i.shape) {
    case BracketShape.l:
    case BracketShape.brace:
      final post = find('기둥')!;
      final px = i.wallPlate ? i.wall.t : 0.0;
      final face = px + post.depth; // 벽에서 기둥 안쪽 면까지
      final span = i.a - face;
      if (span <= 0) return BracketLoadResult(checks, forces, notes);
      // 보 좌표: 기둥 면에서 가로대 끝 쪽으로. 가로대 구멍(가로대 끝에서) → span − fromEnd
      final (pts, w) = loads(span, (x) => span - x, pointAt: span);
      final brace = i.shape == BracketShape.brace ? find('가새') : null;
      if (brace == null) {
        final beam = _Beam(span, pts, w, fixed: true);
        final m = beam.maxMoment;
        bendCheck(arm, m, '가로대');
        if (!post.view.unknown) bendCheck(post, m, '기둥');
        deflCheck(beam.maxDeflection(ei), span, true, '가로대 끝');
      } else if (i.braceA - face <= 1) {
        notes.add('가새가 기둥 면에 붙어 가로대를 받치지 못합니다. 가새 가로대 쪽 자리를 늘리십시오.');
      } else {
        final sb = i.braceA - face;
        final beam = _Beam(span, pts, w, s1: 0, s2: sb);
        bendCheck(arm, beam.maxMoment, '가로대');
        final (_, r2) = beam.reactions;
        final th = (plan.braceAngle ?? 45) * math.pi / 180;
        final c = r2 / math.sin(th);
        final lb = math.sqrt(
          math.pow(i.braceA - face, 2) + math.pow(i.braceB - arm.depth, 2),
        );
        if (!brace.view.unknown) {
          final pa = allowP(brace, lb);
          if (pa > 0) {
            checks.add(
              BracketLoadCheck(
                '가새 누름',
                c / pa,
                '${_f(c / 1000, 2)}kN · 허용 ${_f(pa / 1000, 2)}kN (길이 ${_f(lb, 0)}, K 1)',
              ),
            );
          }
        }
        deflCheck(beam.maxDeflection(ei), span, sb < span - 1, '가로대');
      }
      // 벽 앵커: 벽(x = 0)에 걸리는 모멘트를 아래(삼각은 가새 끝)를 받침점으로 볼트 줄이 나눠 받는다
      final mw =
          pts.fold(0.0, (s, q) => s + q.$2 * (q.$1 + face)) +
          w * span * (span / 2 + face);
      final pivot = brace != null ? i.braceB : i.b;
      final rows = <double>[];
      var perRow = 1;
      if (i.wallPlate && plan.plate != null) {
        final ys = plan.plate!.holes.map((q) => q.dy).toSet().toList()..sort();
        rows.addAll(ys);
        perRow = ys.isEmpty ? 1 : plan.plate!.holes.length ~/ ys.length;
      } else {
        // 기둥 구멍은 기둥 위 끝(따내기 혀 끝)에서 잰 값 → 그림 자리(점검 32: 혀만큼 어긋났다)
        final hs = post.holes;
        final ys = hs.map((h) => post.origin.dy + h.fromEnd).toSet().toList()
          ..sort();
        rows.addAll(ys);
        perRow = ys.isEmpty ? 1 : hs.length ~/ ys.length;
      }
      final ds = [
        for (final y in rows)
          if (pivot - y > 1) pivot - y,
      ];
      final total = p;
      if (ds.isEmpty) {
        forces.add('벽 고정 구멍이 없거나 받침점 아래에만 있어 앵커 힘은 계산하지 않았습니다.');
      } else {
        final sum = ds.fold(0.0, (s, d) => s + d * d);
        final tTop = mw * ds.reduce(math.max) / sum / perRow;
        final nb = rows.length * perRow;
        forces.add(
          '벽 앵커: 맨 위 볼트 당김 약 ${_f(tTop / 1000, 2)}kN, 볼트마다 밀림 약 ${_f(total / nb / 1000, 2)}kN(볼트 $nb개). 앵커 허용 하중과 비교하십시오.',
        );
      }
    case BracketShape.frame:
    case BracketShape.tee:
      final post = find('기둥')!;
      final dp = post.depth;
      if (i.shape == BracketShape.frame) {
        final len = arm.length;
        final x0 = arm.origin.dx; // 가로대 왼쪽 끝(그림)
        final s1 = dp / 2 - x0, s2 = i.a - dp / 2 - x0;
        if (s2 - s1 <= 1) {
          notes.add('기둥 사이가 없어 하중을 계산하지 않았습니다.');
          return BracketLoadResult(checks, forces, notes);
        }
        final (pts, w) = loads(len, (x) => x, pointAt: (s1 + s2) / 2);
        final beam = _Beam(len, pts, w, s1: s1, s2: s2);
        bendCheck(arm, beam.maxMoment, '가로대');
        deflCheck(beam.maxDeflection(ei), s2 - s1, false, '가로대');
        final tiers = find('아래 가로대') == null ? 1 : 2;
        final (r1, r2) = beam.reactions;
        final pc = math.max(r1, r2) * tiers;
        if (!post.view.unknown) {
          final lc = i.b - (i.basePlate ? i.base.t : 0);
          final pa = allowP(post, 2 * lc);
          if (pa > 0) {
            checks.add(
              BracketLoadCheck(
                '기둥 누름',
                pc / pa,
                '${_f(pc / 1000, 2)}kN · 허용 ${_f(pa / 1000, 2)}kN (높이 ${_f(lc, 0)}, K 2)',
              ),
            );
          }
        }
        if (tiers == 2) notes.add('아래 가로대에도 같은 무게를 얹은 것으로 기둥을 계산했습니다.');
        forces.add('바닥 앵커: 무게는 누름으로만 받습니다(옆에서 미는 힘은 계산하지 않음).');
      } else {
        // T자: 기둥 양쪽 캔틸레버
        final w0 = i.a;
        final side = w0 / 2 - dp / 2;
        if (side <= 0) return BracketLoadResult(checks, forces, notes);
        // 가로대 구멍(왼쪽 끝에서) → 왼쪽 팔은 기둥 면에서 왼쪽으로, 오른쪽 팔은 오른쪽으로
        final leftPts = <(double, double)>[], rightPts = <(double, double)>[];
        double wl = 0, wr = 0;
        switch (mode) {
          case BracketLoadMode.point:
            leftPts.add((side, p / 2));
            rightPts.add((side, p / 2));
          case BracketLoadMode.uniform:
            wl = wr = p / w0;
          case BracketLoadMode.holes:
            final xs = <double>{for (final h in arm.holes) h.fromEnd}.toList();
            if (xs.isEmpty) {
              notes.add('가로대 구멍이 없어 무게를 고르게 얹은 것으로 계산했습니다.');
              wl = wr = p / w0;
            } else {
              for (final x in xs) {
                final d = x - w0 / 2;
                if (d.abs() <= dp / 2) continue;
                final arm0 = d.abs() - dp / 2;
                (d < 0 ? leftPts : rightPts).add((arm0, p / xs.length));
              }
            }
        }
        final bl = _Beam(side, leftPts, wl, fixed: true);
        final br = _Beam(side, rightPts, wr, fixed: true);
        final m = math.max(bl.maxMoment, br.maxMoment);
        bendCheck(arm, m, '가로대');
        deflCheck(
          math.max(bl.maxDeflection(ei), br.maxDeflection(ei)),
          side,
          true,
          '가로대 끝',
        );
        final mb = (bl.moment(0) - br.moment(0)).abs();
        if (!post.view.unknown) {
          final lc = i.b - (i.basePlate ? i.base.t : 0) - arm.depth;
          final pa = allowP(post, 2 * lc);
          final ma = allowM(post);
          if (pa > 0 && ma > 0) {
            final pr = p / pa, mr = mb / ma;
            final r = pr >= 0.2 ? pr + 8 / 9 * mr : pr / 2 + mr;
            checks.add(
              BracketLoadCheck(
                '기둥 누름·휨',
                r,
                '누름 ${_f(p / 1000, 2)}kN · 한쪽으로 쏠린 모멘트 ${_f(mb / 1e6, 2)}kN·m (K 2)',
              ),
            );
          }
        }
        if (mb > 1 && plan.plate != null && plan.plate!.holes.length >= 2) {
          final xs = plan.plate!.holes.map((q) => q.dx).toSet().toList()
            ..sort();
          if (xs.length >= 2) {
            final s = xs.last - xs.first;
            final per = plan.plate!.holes.length ~/ xs.length;
            forces.add(
              '바닥 앵커: 한쪽으로 쏠린 무게 때문에 한 줄 볼트 당김 약 ${_f(mb / s / per / 1000, 2)}kN(볼트마다).',
            );
          }
        } else {
          forces.add('바닥 앵커: 양쪽 무게가 같으면 누름으로만 받습니다.');
        }
      }
    case BracketShape.hanger:
      final len = arm.length;
      final rods = plan.members.where((m) => m.name == '전산볼트').toList();
      final xs = [for (final r in rods) r.origin.dx + r.depth / 2]..sort();
      if (xs.length < 2 || xs.last - xs.first <= 1) {
        notes.add('전산볼트 사이가 없어 하중을 계산하지 않았습니다.');
        return BracketLoadResult(checks, forces, notes);
      }
      final (pts, w) = loads(len, (x) => x, pointAt: len / 2);
      final beam = _Beam(len, pts, w, s1: xs.first, s2: xs.last);
      bendCheck(arm, beam.maxMoment, '가로대');
      deflCheck(beam.maxDeflection(ei), xs.last - xs.first, false, '가로대');
      final (r1, r2) = beam.reactions;
      final t = math.max(r1, r2);
      final d = rods.first.depth;
      final ab = math.pi / 4 * d * d;
      final allow = 0.75 * 400 * ab / 2.0;
      checks.add(
        BracketLoadCheck(
          '전산볼트 당김',
          t / allow,
          '한 개 ${_f(t / 1000, 2)}kN · 허용 ${_f(allow / 1000, 2)}kN (M${_f(d, 0)}, 강도 4.6)',
        ),
      );
      forces.add(
        '천장 앵커(인서트): 한 개 당김 약 ${_f(t / 1000, 2)}kN. 앵커 허용 하중과 비교하십시오.',
      );
  }
  return BracketLoadResult(checks, forces, notes);
}

/// 사용률 글("63%").
String bracketLoadPct(double r) => _pct(r);
