// 형강 브라켓 단면(10-11 개편, 상용 앱 비교 2·8·10번): 규격 이름("앵글 50x50x5")을 읽어 단면 모양·도면 표기
// (L-50×50×5)·무게·놓는 방향을 정한다. 화면 없이 계산만.
//  · 단면 좌표: u = 붙는 면(벽에 붙는 면, 가로대 위 면)에서 그림 면 안쪽으로, z = 그림 면 깊이(앞뒤).
//    그림(정면·측면)에는 u 방향 폭 [BracketSectionView.depth]만 보이고, z 방향 깊이는 단면 표시·부재도에 나온다.
//  · 붙는 면 구멍(벽 볼트·U볼트)은 그림 면과 직각인 면에 뚫리니 그림에는 숨은선(점선)으로, 부재도에는 원으로 그린다.
//    평철을 세워 쓰면(그림 면이 넓은 면) 구멍이 그림 면에 보인다([BracketSectionView.holesFront]).
//  · 단면 성능(넓이·단면 2차 모멘트·단면 계수·최소 회전 반경)은 직사각형 조각으로 계산한다(모서리 둥글림·
//    플랜지 기울기는 뺌, 하중 확인 참고값용).
library;

import 'dart:math' as math;
import 'dart:ui' show Rect;

import '../steel_cutting/steel_weight.dart' show steelKgPerM;

enum BracketProfileKind {
  angle,
  unequalAngle,
  channel,
  flat,
  pipe,
  hBeam,
  strut,
  lipChannel,
  rod,
  other,
}

/// 부재가 맡는 일: 벽에 붙는 기둥(붙는 면 = 벽), 위에 물건을 얹는 가로대(붙는 면 = 위), 붙는 면 없음(가새·문형 기둥).
enum BracketRole { wall, top, none }

class BracketProfile {
  final BracketProfileKind kind;

  /// 앱 규격 이름('앵글 50x50x5'). 형강 컷팅·무게 계산이 이 이름을 쓴다.
  final String label;

  /// 이름의 숫자들(앵글 [변, 변, t], 찬넬 [춤, 폭, t], 평철 [폭, t], 각파이프 [가로, 세로, t],
  /// H형강 [춤, 폭, 웨브 t, 플랜지 t], 스트럿 [폭, 높이, t], 립C [춤, 폭, 립, t], 전산볼트 [지름]).
  final List<double> n;

  /// 모르는 규격일 때 그림 폭(직접 넣은 부재 폭).
  final double fallback;

  const BracketProfile._(this.kind, this.label, this.n, [this.fallback = 0]);

  /// 규격 이름을 읽는다. 모르는 이름이면 [BracketProfileKind.other]이고 그림 폭은 [fallbackDepth].
  factory BracketProfile.parse(String label, {double fallbackDepth = 0}) {
    final s = label.trim();
    final sp = s.indexOf(' ');
    if (sp > 0) {
      final kind = s.substring(0, sp);
      final size = s.substring(sp + 1).trim();
      final nums = _nums(size);
      BracketProfile? mk(BracketProfileKind k, int count) =>
          nums != null && nums.length == count
          ? BracketProfile._(k, s, nums, fallbackDepth)
          : null;
      final p = switch (kind) {
        '앵글' => mk(BracketProfileKind.angle, 3),
        '부등변앵글' => mk(BracketProfileKind.unequalAngle, 3),
        '찬넬' => mk(BracketProfileKind.channel, 3),
        '평철' => mk(BracketProfileKind.flat, 2),
        '각파이프' => mk(BracketProfileKind.pipe, 3),
        'H형강' => mk(BracketProfileKind.hBeam, 4),
        '스트럿' => mk(BracketProfileKind.strut, 3),
        '립C형강' => mk(BracketProfileKind.lipChannel, 4),
        '전산볼트' => _rod(s, size),
        _ => null,
      };
      if (p != null && p._sane) return p;
    }
    return BracketProfile._(
      BracketProfileKind.other,
      s,
      const [],
      fallbackDepth,
    );
  }

  static BracketProfile? _rod(String label, String size) {
    final m = RegExp(r'^[Mm]\s*(\d+(?:\.\d+)?)$').firstMatch(size);
    final d = m == null ? null : double.tryParse(m.group(1)!);
    return d == null || d <= 0
        ? null
        : BracketProfile._(BracketProfileKind.rod, label, [d]);
  }

  bool get known => kind != BracketProfileKind.other;

  /// 두께가 변보다 작은가(잘못 적은 이름 거르기).
  bool get _sane => switch (kind) {
    BracketProfileKind.angle ||
    BracketProfileKind.unequalAngle => n[2] < math.min(n[0], n[1]),
    BracketProfileKind.channel => 2 * n[2] < n[0] && n[2] < n[1],
    BracketProfileKind.flat => n[1] <= n[0],
    BracketProfileKind.pipe => 2 * n[2] < math.min(n[0], n[1]),
    BracketProfileKind.hBeam => 2 * n[3] < n[0] && n[2] < n[1],
    BracketProfileKind.strut => 2 * n[2] < math.min(n[0], n[1]),
    BracketProfileKind.lipChannel =>
      2 * n[3] < n[0] && n[2] < n[1] && n[3] < n[2],
    _ => true,
  };

  /// 도면 표기(KS 관례): L-50×50×5, ㄷ-100×50×5, FB-50×6, □-50×50×2.3, H-100×100×6×8, C-100×50×20×2.3.
  String get ks {
    String j() => n.map(_f).join('×');
    return switch (kind) {
      BracketProfileKind.angle || BracketProfileKind.unequalAngle => 'L-${j()}',
      BracketProfileKind.channel => 'ㄷ-${j()}',
      BracketProfileKind.flat => 'FB-${j()}',
      BracketProfileKind.pipe => '□-${j()}',
      BracketProfileKind.hBeam => 'H-${j()}',
      BracketProfileKind.lipChannel => 'C-${j()}',
      BracketProfileKind.strut => '스트럿 ${j()}',
      BracketProfileKind.rod => '전산볼트 M${_f(n[0])}',
      BracketProfileKind.other => label,
    };
  }

  /// 1m 무게(kg). 형강 컷팅과 같은 이론 중량, 없으면 단면 넓이로. 모르면 null.
  double? get kgPerM {
    final t = steelKgPerM(label);
    if (t != null) return t;
    if (!known || kind == BracketProfileKind.rod) return null;
    return view(0, BracketRole.none).area * 0.00785;
  }

  /// 두께(평철·각파이프·앵글은 t, 찬넬·H는 웨브 t). 용접 각장 기본값에 쓴다.
  double get thickness => switch (kind) {
    BracketProfileKind.angle ||
    BracketProfileKind.unequalAngle ||
    BracketProfileKind.channel ||
    BracketProfileKind.pipe ||
    BracketProfileKind.strut => n[2],
    BracketProfileKind.flat => n[1],
    BracketProfileKind.hBeam => math.min(n[2], n[3]),
    BracketProfileKind.lipChannel => n[3],
    _ => 0,
  };

  /// 찬넬 플랜지 두께: 경량 찬넬(두께 3.2 이하)은 웨브와 같고, 열간압연 찬넬은 KS 단위 중량에서 거꾸로
  /// 구한다(넓이 = 웨브 + 플랜지 둘, 모서리 둥글림은 플랜지에 넣어 계산).
  double get _channelTf {
    final h = n[0], b = n[1], tw = n[2];
    if (tw <= 3.2) return tw;
    final kg = steelKgPerM(label);
    if (kg == null) return tw * 1.5;
    final a = kg / 0.00785;
    final tf = (a - h * tw) / (2 * (b - tw));
    return tf.isFinite && tf > tw * 0.8 && tf < b / 2 ? tf : tw * 1.5;
  }

  /// 놓는 방향 수(0번부터). 등변 앵글·각관(정사각)·H형강·평철 하나짜리는 1.
  int get orientCount => switch (kind) {
    BracketProfileKind.unequalAngle => n[0] == n[1] ? 1 : 2,
    BracketProfileKind.channel ||
    BracketProfileKind.lipChannel ||
    BracketProfileKind.flat ||
    BracketProfileKind.strut => 2,
    BracketProfileKind.pipe => n[0] == n[1] ? 1 : 2,
    _ => 1,
  };

  /// 방향 이름(맡은 일에 따라 "벽에"·"위로"·"앞으로").
  String orientName(int o, BracketRole role) {
    final to = switch (role) {
      BracketRole.wall => '벽에',
      BracketRole.top => '위로',
      BracketRole.none => '앞으로',
    };
    final v = view(o, role);
    final w = '(그림 폭 ${_f(v.depth)})';
    return switch (kind) {
      BracketProfileKind.unequalAngle =>
        o == 0 ? '긴 변이 $to $w' : '짧은 변이 $to $w',
      BracketProfileKind.channel ||
      BracketProfileKind.lipChannel => o == 0 ? '등이 $to $w' : '날개가 $to $w',
      BracketProfileKind.flat => o == 0 ? '눕힘 $w' : '세움 $w',
      BracketProfileKind.strut => o == 0 ? '등이 $to $w' : '슬롯이 $to $w',
      BracketProfileKind.pipe =>
        o == 0 ? '${_f(n[0])} 면이 $to $w' : '${_f(n[1])} 면이 $to $w',
      _ => '그대로 $w',
    };
  }

  /// 맡은 일마다 흔히 쓰는 방향: 찬넬 가로대는 세워서(날개 위), 평철 기둥은 벽에 눕혀, 가로대·가새는 세워서.
  int defaultOrient(BracketRole role) => switch (kind) {
    BracketProfileKind.channel || BracketProfileKind.lipChannel => 1,
    BracketProfileKind.flat => role == BracketRole.wall ? 0 : 1,
    BracketProfileKind.unequalAngle => role == BracketRole.wall ? 0 : 1,
    _ => 0,
  };

  /// 방향 [o]로 놓은 단면.
  BracketSectionView view(int o, BracketRole role) {
    final oo = o.clamp(0, orientCount - 1);
    Rect r(double u0, double z0, double u1, double z1) =>
        Rect.fromLTRB(u0, z0, u1, z1);
    switch (kind) {
      case BracketProfileKind.angle:
      case BracketProfileKind.unequalAngle:
        // 붙는 변(a)과 보이는 변(d). 앵글 이름은 [긴 변, 짧은 변, t].
        final t = n[2];
        final a = oo == 0 ? n[0] : n[1], d = oo == 0 ? n[1] : n[0];
        return BracketSectionView(
          depth: d,
          width: a,
          rects: [r(0, 0, t, a), r(t, 0, d, t)],
          attachT: t,
          zone: (t, a),
          gauge: (a + t) / 2,
          lines: [t],
        );
      case BracketProfileKind.channel:
      case BracketProfileKind.lipChannel:
        final lip = kind == BracketProfileKind.lipChannel;
        final h = n[0], b = n[1];
        final tw = lip ? n[3] : n[2];
        final tf = lip ? n[3] : _channelTf;
        final c = lip ? n[2] : 0.0;
        if (oo == 0) {
          // 등(웨브)이 붙는 면: 보이는 폭 = 날개 폭
          return BracketSectionView(
            depth: b,
            width: h,
            rects: [
              r(0, 0, tw, h),
              r(tw, 0, b, tf),
              r(tw, h - tf, b, h),
              if (lip) ...[r(b - tf, tf, b, c), r(b - tf, h - c, b, h - tf)],
            ],
            attachT: tw,
            zone: (tf, h - tf),
            gauge: h / 2,
            lines: [tw, if (lip) b - tf],
          );
        }
        // 날개가 붙는 면: 보이는 폭 = 춤
        return BracketSectionView(
          depth: h,
          width: b,
          rects: [
            r(0, 0, tf, b),
            r(tf, 0, h - tf, tw),
            r(h - tf, 0, h, b),
            if (lip) ...[r(tf, b - tf, c, b), r(h - c, b - tf, h - tf, b)],
          ],
          attachT: tf,
          zone: (tw, b),
          gauge: (b + tw) / 2,
          lines: [tf, h - tf],
        );
      case BracketProfileKind.flat:
        final w = n[0], t = n[1];
        return oo == 0
            ? BracketSectionView(
                depth: t,
                width: w,
                rects: [r(0, 0, t, w)],
                attachT: t,
                zone: (0, w),
                gauge: w / 2,
                lines: const [],
              )
            : BracketSectionView(
                depth: w,
                width: t,
                rects: [r(0, 0, w, t)],
                attachT: w,
                zone: (0, w),
                gauge: w / 2,
                lines: const [],
                holesFront: true,
              );
      case BracketProfileKind.pipe:
        final t = n[2];
        final a = oo == 0 ? n[0] : n[1], d = oo == 0 ? n[1] : n[0];
        return BracketSectionView(
          depth: d,
          width: a,
          rects: [
            r(0, 0, t, a),
            r(d - t, 0, d, a),
            r(t, 0, d - t, t),
            r(t, a - t, d - t, a),
          ],
          attachT: t,
          zone: (t, a - t),
          gauge: a / 2,
          lines: [t, d - t],
          hollow: true,
        );
      case BracketProfileKind.hBeam:
        final h = n[0], b = n[1], tw = n[2], tf = n[3];
        return BracketSectionView(
          depth: h,
          width: b,
          rects: [
            r(0, 0, tf, b),
            r(tf, (b - tw) / 2, h - tf, (b + tw) / 2),
            r(h - tf, 0, h, b),
          ],
          attachT: tf,
          zone: (0, b),
          gauge: (b - tw) / 4,
          lines: [tf, h - tf],
          twoLines: true,
          web: tw,
        );
      case BracketProfileKind.strut:
        // 폭 x 높이 x t, 안쪽으로 접힌 입술 약 10(형강 컷팅 무게 계산과 같은 가정)
        final w = n[0], h = n[1], t = n[2];
        const lip = 10.0;
        final rs = [
          r(0, 0, t, w),
          r(t, 0, h, t),
          r(t, w - t, h, w),
          r(h - t, t, h, t + lip),
          r(h - t, w - t - lip, h, w - t),
        ];
        if (oo == 0) {
          return BracketSectionView(
            depth: h,
            width: w,
            rects: rs,
            attachT: t,
            zone: (t, w - t),
            gauge: w / 2,
            lines: [t, h - t],
          );
        }
        // 슬롯이 붙는 면: u를 뒤집는다. 구멍 대신 채널 너트.
        return BracketSectionView(
          depth: h,
          width: w,
          rects: [
            for (final q in rs)
              Rect.fromLTRB(h - q.right, q.top, h - q.left, q.bottom),
          ],
          attachT: t,
          zone: (0, 0),
          gauge: w / 2,
          lines: [t, h - t],
          slot: true,
        );
      case BracketProfileKind.rod:
        final d = n[0];
        return BracketSectionView(
          depth: d,
          width: d,
          rects: [r(0, 0, d, d)],
          attachT: d,
          zone: (0, 0),
          gauge: d / 2,
          lines: const [],
          round: true,
        );
      case BracketProfileKind.other:
        final d = fallback > 0 ? fallback : 1.0;
        return BracketSectionView(
          depth: d,
          width: d,
          rects: [r(0, 0, d, d)],
          attachT: d,
          zone: (0, d),
          gauge: d / 2,
          lines: const [],
          unknown: true,
        );
    }
  }
}

/// 놓은 단면 하나.
class BracketSectionView {
  /// 그림 면에서 보이는 폭(u 방향), 그림 면 깊이(z 방향).
  final double depth, width;

  /// 단면 직사각형 조각들(left·right = u, top·bottom = z). 겹치지 않게 나눠 둔다.
  final List<Rect> rects;

  /// 붙는 면 판 두께(그림에서 붙는 쪽 가장자리 띠).
  final double attachT;

  /// 붙는 면에서 구멍 중심이 올 수 있는 z 범위(가장자리, 구멍 반지름은 빼지 않음). (0, 0)이면 구멍을 못 낸다.
  final (double, double) zone;

  /// 기본 게이지: 붙는 면 z = 0 쪽 가장자리(앵글은 등, 찬넬 날개는 웨브 쪽)에서 구멍 줄까지.
  final double gauge;

  /// 그림 면에 길이 방향으로 보이는 선(붙는 면에서 거리): 다른 변·날개·웨브 자리.
  final List<double> lines;

  /// 구멍이 그림 면(앞)에 보이는가(평철을 세운 경우).
  final bool holesFront;

  /// 속이 빈 관(각파이프): 선이 숨은선.
  final bool hollow;

  /// H형강처럼 구멍이 웨브 양쪽 두 줄인가([web] = 웨브 두께).
  final bool twoLines;
  final double web;

  /// 스트럿을 슬롯 쪽으로 붙임(구멍 대신 채널 너트).
  final bool slot;

  /// 전산볼트(둥근 단면).
  final bool round;

  /// 모르는 규격(그림 폭만 앎, 단면 성능 없음).
  final bool unknown;

  const BracketSectionView({
    required this.depth,
    required this.width,
    required this.rects,
    required this.attachT,
    required this.zone,
    required this.gauge,
    required this.lines,
    this.holesFront = false,
    this.hollow = false,
    this.twoLines = false,
    this.web = 0,
    this.slot = false,
    this.round = false,
    this.unknown = false,
  });

  bool get canHole => zone.$2 > zone.$1;

  double get area {
    if (round) return math.pi / 4 * depth * depth;
    var a = 0.0;
    for (final r in rects) {
      a += r.width * r.height;
    }
    return a;
  }

  /// 단면 성능: 넓이, 그림 면 안 굽힘(u 방향으로 휘는) 단면 2차 모멘트·단면 계수, 최소 회전 반경, 중립축 u.
  BracketSectionProps get props {
    if (round) {
      final d = depth;
      final i = math.pi * math.pow(d, 4) / 64;
      return BracketSectionProps(
        area: area,
        inertia: i,
        modulus: i / (d / 2),
        rMin: d / 4,
        centroid: d / 2,
      );
    }
    var a = 0.0, su = 0.0, sz = 0.0;
    for (final r in rects) {
      final ar = r.width * r.height;
      a += ar;
      su += ar * r.center.dx;
      sz += ar * r.center.dy;
    }
    if (a <= 0) {
      return const BracketSectionProps(
        area: 0,
        inertia: 0,
        modulus: 0,
        rMin: 0,
        centroid: 0,
      );
    }
    final cu = su / a, cz = sz / a;
    var iu = 0.0, iz = 0.0, iuz = 0.0;
    for (final r in rects) {
      final w = r.width, h = r.height, ar = w * h;
      final du = r.center.dx - cu, dz = r.center.dy - cz;
      iu += h * w * w * w / 12 + ar * du * du;
      iz += w * h * h * h / 12 + ar * dz * dz;
      iuz += ar * du * dz;
    }
    final avg = (iu + iz) / 2;
    final rad = math.sqrt(math.pow((iu - iz) / 2, 2) + iuz * iuz);
    final iMin = math.max(avg - rad, 1e-9);
    final c = math.max(cu, depth - cu);
    return BracketSectionProps(
      area: a,
      inertia: iu,
      modulus: c > 0 ? iu / c : 0,
      rMin: math.sqrt(iMin / a),
      centroid: cu,
    );
  }
}

class BracketSectionProps {
  /// 넓이(mm²), 단면 2차 모멘트(mm⁴), 단면 계수(mm³), 최소 회전 반경(mm), 중립축(붙는 면에서 mm).
  final double area, inertia, modulus, rMin, centroid;
  const BracketSectionProps({
    required this.area,
    required this.inertia,
    required this.modulus,
    required this.rMin,
    required this.centroid,
  });
}

/// 강판 도면 표기: PL-9×150×150(두께×가로×세로).
String plateKs(double t, double w, double l) => 'PL-${_f(t)}×${_f(w)}×${_f(l)}';

List<double>? _nums(String size) {
  final parts = size.split(RegExp(r'[xX×*]'));
  final out = <double>[];
  for (final p in parts) {
    final v = double.tryParse(p.trim());
    if (v == null || v <= 0) return null;
    out.add(v);
  }
  return out;
}

String _f(double v) {
  var s = v.toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  }
  return s;
}
