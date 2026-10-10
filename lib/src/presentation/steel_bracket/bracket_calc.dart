// 형강 브라켓 제작도(10-10): 앵글·찬넬·평철·각파이프로 ㄱ자·삼각(가새)·문형·T자 브라켓을 만들 때
// 자를 길이·끝 모양·구멍 위치·베이스 판·원자재 본수와 그림(부재 모양·구멍·치수선)을 계산한다. 화면 없이 계산만.
//  · 치수는 모두 바깥 치수(mm). 그림 좌표는 왼쪽 위 바깥 모서리가 (0, 0)이고 아래로 갈수록 y가 커진다.
//  · ㄱ자·삼각: 기둥(벽에 붙는 쪽)이 왼쪽, 가로대가 위에서 오른쪽으로 나간다. A = 기둥 바깥면에서 가로대 끝까지,
//    B = 가로대 윗면에서 기둥 끝까지.
//  · 문형: 기둥 둘 + 위 가로대. W = 기둥 바깥면 사이, H = 바닥(베이스 판 밑면)에서 가로대 윗면까지.
//  · T자: 가운데 기둥 + 위 가로대(W = 0이면 기둥만). H는 문형과 같다.
//  · 이음: 기둥 통과(가로대가 기둥 옆에 붙어 가로대가 짧아짐), 가로대 통과(기둥이 가로대 밑에 붙어 기둥이 짧아짐),
//    45° 연귀(둘 다 바깥 치수 그대로, 맞닿는 끝을 45°로).
//  · 가새(삼각): 중심선이 가로대 밑면의 a(바깥 모서리에서)와 기둥 안쪽 면의 b(위 바깥에서)를 잇는다.
//    끝은 가로대 면·기둥 면에 맞게 비스듬히 자른다. 긴 변 = 중심선 + d/2·(cotθ + tanθ), 짧은 변 = 중심선 − 같은 값.
//  · 무게는 형강 컷팅과 같은 이론 중량(steel_weight.dart), 베이스 판은 철 7.85 g/cm³(구멍 안 뺌).
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../steel_cutting/steel_weight.dart' show steelKgPerM;
import '../tube_cutting/cutting_optimizer.dart';

enum BracketShape { l, brace, frame, tee }

/// 이음: 기둥 통과, 가로대 통과, 45° 연귀.
enum BracketJoint { postThrough, armThrough, miter }

/// 한 줄로 늘어선 구멍들: 개수·지름·첫 구멍 거리·피치.
class HoleRow {
  final int count;
  final double dia, first, pitch;
  const HoleRow({this.count = 0, this.dia = 0, this.first = 0, this.pitch = 0});
  bool get on => count > 0 && dia > 0;
}

class BracketInput {
  final BracketShape shape;

  /// 형강 규격 이름('앵글 50x50x5'), 그림 면에서 보이는 부재 폭 d(mm).
  final String spec;
  final double d;

  /// ㄱ자·삼각: A 가로대 길이, B 기둥 높이. 문형·T자: A = 폭 W, B = 높이 H.
  final double a, b;
  final BracketJoint joint;

  /// 삼각: 가새가 붙는 자리(바깥 모서리에서) — 가로대 쪽 [braceA], 기둥 쪽 [braceB].
  final double braceA, braceB;

  /// ㄱ자·삼각: 기둥 구멍(위 바깥에서), 가로대 구멍(가로대 끝에서). 문형·T자: 가로대 구멍(왼쪽 끝에서).
  final HoleRow postHoles, armHoles;

  /// 문형·T자 베이스 판: 한 변 [plateSize], 두께 [plateT], 구멍 0·2·4개, 지름, 가장자리에서 구멍 중심까지.
  final bool plate;
  final double plateSize, plateT;
  final int plateHoles;
  final double plateHoleDia, plateEdge;

  /// 만들 개수(세트), 원자재 길이, 톱날 여유.
  final int sets;
  final double stockLength, kerf;

  const BracketInput({
    required this.shape,
    required this.spec,
    required this.d,
    required this.a,
    required this.b,
    this.joint = BracketJoint.postThrough,
    this.braceA = 0,
    this.braceB = 0,
    this.postHoles = const HoleRow(),
    this.armHoles = const HoleRow(),
    this.plate = false,
    this.plateSize = 150,
    this.plateT = 9,
    this.plateHoles = 4,
    this.plateHoleDia = 13.5,
    this.plateEdge = 25,
    this.sets = 1,
    this.stockLength = 6000,
    this.kerf = 2,
  });
}

/// 자른 토막에 뚫는 구멍 하나: 이름, 토막 기준 끝에서 거리, 지름.
class PieceHole {
  final String label;
  final double fromEnd, dia;
  const PieceHole(this.label, this.fromEnd, this.dia);
}

/// 자를 토막 하나(한 세트에 [qty]개).
class BracketPiece {
  final String name, spec;

  /// 자를 길이(가새는 긴 변). [short]는 가새의 짧은 변.
  final double length;
  final double? short;
  final int qty;

  /// 끝 모양 글: '양 끝 직각', '한쪽 45°', '양 끝 비스듬히(위 45° · 아래 45°)'.
  final String ends;

  /// 구멍과 그 거리를 재는 끝 이름('위 끝', '가로대 끝', '왼쪽 끝').
  final List<PieceHole> holes;
  final String holeFrom;
  final double kgEach;

  const BracketPiece({
    required this.name,
    required this.spec,
    required this.length,
    this.short,
    required this.qty,
    required this.ends,
    this.holes = const [],
    this.holeFrom = '',
    required this.kgEach,
  });
}

/// 그림: 부재·판 모양(닫힌 다각형), 구멍, 치수선, 용접 자리, 글.
/// 치수선 하나. [vertical]이면 a·b의 높이 차(세로)를, 아니면 가로 차를 잰다. 치수선은 두 점 중
/// 바깥쪽(음수면 왼쪽·위, 양수면 오른쪽·아래)에서 [offset]만큼(화면 점) 떨어진다.
class BracketDim {
  final Offset a, b;
  final double offset;
  final String text;
  final bool vertical;
  const BracketDim(
    this.a,
    this.b,
    this.offset,
    this.text, {
    this.vertical = false,
  });
}

class BracketHoleMark {
  final Offset at;
  final double dia;
  const BracketHoleMark(this.at, this.dia);
}

/// 글: 그림 자리 [at](mm)에서 화면 점으로 [shift]만큼 옮겨 쓴다.
class BracketLabel {
  final Offset at;
  final String text;
  final Offset shift;
  const BracketLabel(this.at, this.text, {this.shift = Offset.zero});
}

class BracketDrawing {
  final List<List<Offset>> members, plates;
  final List<BracketHoleMark> holes;
  final List<BracketDim> dims;
  final List<Offset> welds;
  final List<BracketLabel> labels;
  const BracketDrawing({
    required this.members,
    required this.plates,
    required this.holes,
    required this.dims,
    required this.welds,
    required this.labels,
  });

  /// 부재·판을 감싸는 상자(mm). 치수선·글은 화면 점으로 떨어지니 그리는 쪽이 여백을 둔다.
  (double, double, double, double) bounds() {
    var x0 = double.infinity, y0 = double.infinity;
    var x1 = -double.infinity, y1 = -double.infinity;
    void add(Offset p) {
      x0 = math.min(x0, p.dx);
      y0 = math.min(y0, p.dy);
      x1 = math.max(x1, p.dx);
      y1 = math.max(y1, p.dy);
    }

    for (final poly in [...members, ...plates]) {
      poly.forEach(add);
    }
    if (x0 == double.infinity) return (0, 0, 1, 1);
    return (x0, y0, x1, y1);
  }
}

class BracketPlate {
  final double size, t;
  final int qty;
  final List<Offset> holes; // 판 가운데가 (0, 0)
  final double holeDia;
  final double kgEach;
  const BracketPlate({
    required this.size,
    required this.t,
    required this.qty,
    required this.holes,
    required this.holeDia,
    required this.kgEach,
  });
}

class BracketPlan {
  final List<BracketPiece> pieces;
  final BracketPlate? plate;
  final BracketDrawing drawing;

  /// 가새 기울기(가로에서, °). 가새가 없으면 null.
  final double? braceAngle;

  /// 한 세트·전체 무게(kg). 모르는 규격이면 형강 몫은 0이고 [weightKnown]이 false.
  final double kgPerSet, kgTotal;
  final bool weightKnown;

  /// 볼트 구멍(부재) 지름 → 전체 개수, 베이스 판 앵커 구멍 지름 → 전체 개수.
  final Map<double, int> boltHoles, anchorHoles;

  /// 원자재 계획(규격 → 결과).
  final Map<String, CuttingOptimizationResult> stock;

  final List<String> notes, problems;
  bool get ok => problems.isEmpty;

  const BracketPlan({
    required this.pieces,
    required this.plate,
    required this.drawing,
    required this.braceAngle,
    required this.kgPerSet,
    required this.kgTotal,
    required this.weightKnown,
    required this.boltHoles,
    required this.anchorHoles,
    required this.stock,
    required this.notes,
    required this.problems,
  });
}

/// 강판 무게(kg/mm³): 7.85 g/cm³.
const double kSteelKgPerMm3 = 7.85e-6;

/// 규격 이름에서 그림 면에 보이는 부재 폭(앵글 변·찬넬 춤·평철 폭·각파이프 변). 모르면 null.
double? bracketMemberWidth(String spec) {
  final label = spec.trim();
  final sp = label.indexOf(' ');
  if (sp <= 0) return null;
  final first = label.substring(sp + 1).split(RegExp(r'[xX×*]')).first.trim();
  final v = double.tryParse(first);
  return v == null || v <= 0 ? null : v;
}

String _f(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s;
}

List<Offset> _rect(double x0, double y0, double x1, double y1) => [
  Offset(x0, y0),
  Offset(x1, y0),
  Offset(x1, y1),
  Offset(x0, y1),
];

/// 두 직선(점 p + 방향 u, 점 q + 방향 v)의 만나는 점.
Offset _meet(Offset p, Offset u, Offset q, Offset v) {
  final den = u.dx * v.dy - u.dy * v.dx;
  final t = ((q.dx - p.dx) * v.dy - (q.dy - p.dy) * v.dx) / den;
  return p + u * t;
}

BracketPlan bracketPlan(BracketInput i) {
  final notes = <String>[], problems = <String>[];
  void warn(String s) {
    if (!problems.contains(s)) problems.add(s);
  }

  final d = i.d;
  final sets = i.sets < 1 ? 1 : i.sets;
  final kgM = steelKgPerM(i.spec);
  double kgOf(double len) => kgM == null ? 0 : kgM * len / 1000;

  final pieces = <BracketPiece>[];
  final members = <List<Offset>>[];
  final plates = <List<Offset>>[];
  final holeMarks = <BracketHoleMark>[];
  final dims = <BracketDim>[];
  final welds = <Offset>[];
  final labels = <BracketLabel>[];
  double? braceAngle;
  BracketPlate? plateOut;

  if (d <= 0) warn('부재 폭을 넣으십시오.');

  /// 줄 구멍을 토막 기준 거리로: [first] + k·[pitch]. 토막 길이 [len] 밖이면 알린다.
  List<PieceHole> rowHoles(String name, HoleRow r, double len) {
    if (!r.on) return const [];
    final out = <PieceHole>[];
    for (var k = 0; k < r.count; k++) {
      final at = r.first + k * r.pitch;
      out.add(PieceHole('$name ${k + 1}', at, r.dia));
      if (at - r.dia / 2 < -1e-9 || at + r.dia / 2 > len + 1e-9) {
        warn(
          '$name 구멍 ${k + 1}번이 부재 밖으로 나옵니다(토막 ${_f(len)}mm). 첫 구멍·피치를 줄이십시오.',
        );
      }
    }
    if (r.count > 1 && r.pitch <= r.dia) {
      warn('$name 구멍 피치가 구멍 지름 이하라 구멍이 서로 겹칩니다.');
    }
    if (r.dia >= d) warn('$name 구멍 지름이 부재 폭보다 크거나 같습니다.');
    return out;
  }

  switch (i.shape) {
    case BracketShape.l:
    case BracketShape.brace:
      final a = i.a, b = i.b;
      if (a <= d || b <= d) warn('가로대 길이와 기둥 높이는 부재 폭(${_f(d)}mm)보다 커야 합니다.');
      final j = i.joint;
      final postStart = j == BracketJoint.armThrough ? d : 0.0;
      final armStart = j == BracketJoint.postThrough ? d : 0.0;
      final postLen = b - postStart, armLen = a - armStart;
      if (j == BracketJoint.miter) {
        members.add([
          const Offset(0, 0),
          Offset(d, d),
          Offset(d, b),
          Offset(0, b),
        ]);
        members.add([
          const Offset(0, 0),
          Offset(a, 0),
          Offset(a, d),
          Offset(d, d),
        ]);
        welds.add(Offset(d / 2, d / 2));
      } else {
        members.add(_rect(0, postStart, d, b));
        members.add(_rect(armStart, 0, a, d));
        welds.add(
          j == BracketJoint.postThrough ? Offset(d, d / 2) : Offset(d / 2, d),
        );
      }
      final postHoles = rowHoles('기둥', i.postHoles, postLen + postStart);
      final armHoles = rowHoles('가로대', i.armHoles, armLen);
      for (final h in postHoles) {
        holeMarks.add(BracketHoleMark(Offset(d / 2, h.fromEnd), h.dia));
      }
      for (final h in armHoles) {
        holeMarks.add(BracketHoleMark(Offset(a - h.fromEnd, d / 2), h.dia));
      }
      final miterEnd = j == BracketJoint.miter
          ? '한쪽 45°(모서리 쪽), 한쪽 직각'
          : '양 끝 직각';
      pieces.add(
        BracketPiece(
          name: '기둥',
          spec: i.spec,
          length: postLen,
          qty: 1,
          ends: miterEnd,
          // 기둥 구멍은 브라켓 위 바깥에서 잰 값을 토막 위 끝 기준으로 옮긴다.
          holes: [
            for (final h in postHoles)
              PieceHole(h.label, h.fromEnd - postStart, h.dia),
          ],
          holeFrom: '위 끝',
          kgEach: kgOf(postLen),
        ),
      );
      pieces.add(
        BracketPiece(
          name: '가로대',
          spec: i.spec,
          length: armLen,
          qty: 1,
          ends: miterEnd,
          holes: armHoles,
          holeFrom: '가로대 끝(벽 반대쪽)',
          kgEach: kgOf(armLen),
        ),
      );
      for (final h in postHoles) {
        if (h.fromEnd - postStart - h.dia / 2 < -1e-9) {
          warn(
            '기둥 구멍이 가로대 자리에 걸립니다. 첫 구멍을 ${_f(postStart + h.dia / 2)}mm 이상으로 하십시오.',
          );
        }
      }
      // 전체 치수는 바깥 줄, 삼각의 가새 자리는 안쪽 줄(화면 점).
      final brace = i.shape == BracketShape.brace;
      final outer = brace ? -56.0 : -30.0;
      dims.add(BracketDim(const Offset(0, 0), Offset(a, 0), outer, _f(a)));
      dims.add(
        BracketDim(
          const Offset(0, 0),
          Offset(0, b),
          outer,
          _f(b),
          vertical: true,
        ),
      );
      labels.add(
        BracketLabel(
          Offset(brace ? (d + i.braceA) / 2 : a * 0.6, d),
          '가로대',
          shift: const Offset(0, 14),
        ),
      );
      labels.add(
        BracketLabel(Offset(d, b * 0.93), '기둥', shift: const Offset(24, 0)),
      );

      if (i.shape == BracketShape.brace) {
        final p1 = Offset(i.braceA, d), p2 = Offset(d, i.braceB);
        final dx = i.braceA - d, dy = i.braceB - d;
        if (dx <= d || dy <= d) {
          warn('가새 자리가 모서리에 너무 가깝습니다. 가새 자리(가로대 쪽·기둥 쪽)를 부재 폭의 2배보다 크게 하십시오.');
        } else {
          final theta = math.atan2(dy, dx); // 가로에서 아래로 기운 각
          braceAngle = theta * 180 / math.pi;
          final u = (p2 - p1) / (p2 - p1).distance;
          final nrm = Offset(-u.dy, u.dx);
          final half = d / 2;
          final horiz = const Offset(1, 0), vert = const Offset(0, 1);
          // 두 변(±d/2)이 가로대 밑면(y = d)·기둥 안쪽 면(x = d)과 만나는 점
          final topA = _meet(p1 + nrm * half, u, Offset(0, d), horiz);
          final topB = _meet(p1 - nrm * half, u, Offset(0, d), horiz);
          final botA = _meet(p1 + nrm * half, u, Offset(d, 0), vert);
          final botB = _meet(p1 - nrm * half, u, Offset(d, 0), vert);
          members.add([topA, topB, botB, botA]);
          final edgeA = (botA - topA).distance, edgeB = (botB - topB).distance;
          final long = math.max(edgeA, edgeB), short = math.min(edgeA, edgeB);
          if (short <= 0 || math.max(topA.dx, topB.dx) > i.a + 1e-9) {
            warn('가새가 가로대 끝을 넘어갑니다. 가로대 쪽 자리를 줄이십시오.');
          }
          if (math.max(botA.dy, botB.dy) > i.b + 1e-9) {
            warn('가새가 기둥 끝을 넘어갑니다. 기둥 쪽 자리를 줄이십시오.');
          }
          final topCut = 90 - braceAngle, botCut = braceAngle;
          pieces.add(
            BracketPiece(
              name: '가새',
              spec: i.spec,
              length: long,
              short: short,
              qty: 1,
              ends:
                  '양 끝 비스듬히(가로대 쪽 ${_f(topCut)}° · 기둥 쪽 ${_f(botCut)}°, 각도절단기 직각 = 0°)',
              kgEach: kgOf(long),
            ),
          );
          welds.add((topA + topB) / 2);
          welds.add((botA + botB) / 2);
          // 가새 끝이 붙는 자리에 기둥 구멍이 있으면 볼트(너트)를 돌릴 자리가 없다.
          final footTop = math.min(botA.dy, botB.dy);
          final footBot = math.max(botA.dy, botB.dy);
          final blocked = [
            for (final h in postHoles)
              if (h.fromEnd + h.dia / 2 > footTop &&
                  h.fromEnd - h.dia / 2 < footBot)
                h,
          ];
          if (blocked.isNotEmpty) {
            notes.add(
              '가새 끝 자리(위에서 ${_f(footTop)}~${_f(footBot)}mm)에 기둥 구멍이 걸립니다(${blocked.map((h) => '${_f(h.fromEnd)}mm').join(', ')}). 볼트를 조이기 어려울 수 있으니 구멍을 옮기십시오.',
            );
          }
          if (braceAngle < 30 || braceAngle > 60) {
            notes.add(
              '가새 기울기 ${_f(braceAngle)}°입니다. 보통 30~60°(45°가 흔함)로 둡니다. 가새 자리를 맞추십시오.',
            );
          }
          dims.add(
            BracketDim(
              const Offset(0, 0),
              Offset(i.braceA, 0),
              -28,
              '가새 ${_f(i.braceA)}',
            ),
          );
          dims.add(
            BracketDim(
              const Offset(0, 0),
              Offset(0, i.braceB),
              -28,
              '가새 ${_f(i.braceB)}',
              vertical: true,
            ),
          );
          labels.add(BracketLabel((p1 + p2) / 2, '가새 ${_f(braceAngle)}°'));
        }
      }
    case BracketShape.frame:
    case BracketShape.tee:
      final w = i.a, h = i.b;
      final tp = i.plate ? i.plateT : 0.0;
      final frame = i.shape == BracketShape.frame;
      final hasArm = frame || w > 0;
      // T자는 가로대가 기둥 위에 얹힌다(기둥 통과·연귀는 없음).
      final j = frame ? i.joint : BracketJoint.armThrough;
      if (frame && w <= 2 * d) warn('폭은 부재 폭의 2배(${_f(2 * d)}mm)보다 커야 합니다.');
      if (!frame && hasArm && w <= d) warn('가로대 길이는 부재 폭보다 커야 합니다.');
      final topOfPost = hasArm && j == BracketJoint.armThrough ? d : 0.0;
      final postLen = h - tp - topOfPost;
      if (postLen <= 0) warn('높이가 너무 낮습니다(가로대·베이스 판 두께보다 커야 합니다).');
      final postXs = frame ? [0.0, w - d] : [hasArm ? w / 2 - d / 2 : 0.0];
      for (final x in postXs) {
        if (frame && j == BracketJoint.miter) {
          final left = x == 0;
          members.add(
            left
                ? [
                    const Offset(0, 0),
                    Offset(d, d),
                    Offset(d, h - tp),
                    Offset(0, h - tp),
                  ]
                : [
                    Offset(w, 0),
                    Offset(w, h - tp),
                    Offset(w - d, h - tp),
                    Offset(w - d, d),
                  ],
          );
        } else {
          members.add(_rect(x, topOfPost, x + d, h - tp));
        }
      }
      var armLen = 0.0, armStart = 0.0;
      if (hasArm) {
        if (frame && j == BracketJoint.postThrough) {
          armStart = d;
          armLen = w - 2 * d;
          members.add(_rect(d, 0, w - d, d));
          welds.addAll([Offset(d, d / 2), Offset(w - d, d / 2)]);
        } else if (frame && j == BracketJoint.miter) {
          armLen = w;
          members.add([
            const Offset(0, 0),
            Offset(w, 0),
            Offset(w - d, d),
            Offset(d, d),
          ]);
          welds.addAll([Offset(d / 2, d / 2), Offset(w - d / 2, d / 2)]);
        } else {
          armLen = w;
          members.add(_rect(0, 0, w, d));
          for (final x in postXs) {
            welds.add(Offset(x + d / 2, d));
          }
        }
      }
      final armHoles = hasArm
          ? rowHoles('가로대', i.armHoles, armLen + armStart)
          : const <PieceHole>[];
      for (final hh in armHoles) {
        holeMarks.add(BracketHoleMark(Offset(hh.fromEnd, d / 2), hh.dia));
        if (hh.fromEnd - armStart - hh.dia / 2 < -1e-9 ||
            hh.fromEnd + hh.dia / 2 > armStart + armLen + 1e-9) {
          warn('가로대 구멍이 기둥 자리에 걸립니다. 첫 구멍·피치를 고치십시오.');
        }
      }
      final postEnds = frame && j == BracketJoint.miter
          ? '위 45°, 아래 직각'
          : '양 끝 직각';
      pieces.add(
        BracketPiece(
          name: '기둥',
          spec: i.spec,
          length: postLen,
          qty: postXs.length,
          ends: postEnds,
          kgEach: kgOf(postLen),
        ),
      );
      if (hasArm) {
        pieces.add(
          BracketPiece(
            name: '가로대',
            spec: i.spec,
            length: armLen,
            qty: 1,
            ends: frame && j == BracketJoint.miter ? '양 끝 45°' : '양 끝 직각',
            holes: [
              for (final hh in armHoles)
                PieceHole(hh.label, hh.fromEnd - armStart, hh.dia),
            ],
            holeFrom: '왼쪽 끝',
            kgEach: kgOf(armLen),
          ),
        );
      }
      if (hasArm) {
        dims.add(BracketDim(const Offset(0, 0), Offset(w, 0), -30, _f(w)));
      }
      // 높이: 위 왼쪽 모서리에서 맨 왼쪽 발(베이스 판이면 판 가장자리)까지 세로로.
      final footLeft = i.plate
          ? postXs.first + d / 2 - i.plateSize / 2
          : postXs.first;
      dims.add(
        BracketDim(
          const Offset(0, 0),
          Offset(footLeft, h),
          -30,
          _f(h),
          vertical: true,
        ),
      );
      // 베이스 판: 기둥마다 하나. 앞에서 본 모양 + 오른쪽에 위에서 본 판(구멍 자리).
      if (i.plate) {
        final p = i.plateSize, e = i.plateEdge;
        if (p <= d) warn('베이스 판이 부재 폭보다 작습니다.');
        for (final x in postXs) {
          final cx = x + d / 2;
          plates.add(_rect(cx - p / 2, h - tp, cx + p / 2, h));
          welds.add(Offset(cx, h - tp));
        }
        final ph = <Offset>[
          if (i.plateHoles == 4) ...[
            Offset(-(p / 2 - e), -(p / 2 - e)),
            Offset(p / 2 - e, -(p / 2 - e)),
            Offset(-(p / 2 - e), p / 2 - e),
            Offset(p / 2 - e, p / 2 - e),
          ] else if (i.plateHoles == 2) ...[
            Offset(-(p / 2 - e), 0),
            Offset(p / 2 - e, 0),
          ],
        ];
        if (ph.isNotEmpty) {
          if (e < i.plateHoleDia / 2) {
            warn('베이스 판 구멍이 판 가장자리를 뚫습니다. 가장자리 거리를 늘리십시오.');
          }
          if (p / 2 - e - i.plateHoleDia / 2 < d / 2) {
            warn('베이스 판 구멍이 기둥 자리와 겹칩니다. 판을 키우거나 가장자리 거리를 줄이십시오.');
          }
        }
        plateOut = BracketPlate(
          size: p,
          t: tp,
          qty: postXs.length,
          holes: ph,
          holeDia: i.plateHoleDia,
          kgEach: p * p * tp * kSteelKgPerMm3,
        );
        // 위에서 본 판: 그림 오른쪽 아래, 앞모습(기둥·판)과 90mm 띄워서
        var maxX = 0.0;
        for (final poly in [...members, ...plates]) {
          for (final q in poly) {
            maxX = math.max(maxX, q.dx);
          }
        }
        final ox = maxX + 90 + p / 2, oy = h - p / 2;
        plates.add(_rect(ox - p / 2, oy - p / 2, ox + p / 2, oy + p / 2));
        members.add(_rect(ox - d / 2, oy - d / 2, ox + d / 2, oy + d / 2));
        for (final q in ph) {
          holeMarks.add(BracketHoleMark(Offset(ox, oy) + q, i.plateHoleDia));
        }
        dims.add(
          BracketDim(
            Offset(ox - p / 2, oy + p / 2),
            Offset(ox + p / 2, oy + p / 2),
            22,
            _f(p),
          ),
        );
        if (ph.length >= 2) {
          dims.add(
            BracketDim(
              Offset(ox - (p / 2 - e), oy - p / 2),
              Offset(ox + (p / 2 - e), oy - p / 2),
              -18,
              _f(p - 2 * e),
            ),
          );
        }
        labels.add(
          BracketLabel(
            Offset(ox, oy - p / 2),
            '베이스 판',
            shift: const Offset(0, -40),
          ),
        );
      }
      if (hasArm) {
        labels.add(
          BracketLabel(
            Offset(frame ? w / 2 : w * 0.15, d),
            '가로대',
            shift: const Offset(0, 14),
          ),
        );
      }
  }

  // 무게·구멍 수
  var kgSet = 0.0;
  for (final p in pieces) {
    kgSet += p.kgEach * p.qty;
  }
  if (plateOut != null) kgSet += plateOut.kgEach * plateOut.qty;
  final boltHoles = <double, int>{};
  for (final p in pieces) {
    for (final h in p.holes) {
      boltHoles[h.dia] = (boltHoles[h.dia] ?? 0) + p.qty * sets;
    }
  }
  final anchorHoles = <double, int>{};
  if (plateOut != null && plateOut.holes.isNotEmpty) {
    anchorHoles[plateOut.holeDia] = plateOut.holes.length * plateOut.qty * sets;
  }
  if (kgM == null) {
    notes.add(
      '규격 "${i.spec}"의 중량을 몰라 무게에서 형강을 뺐습니다("앵글 50x50x5"처럼 적으면 계산합니다).',
    );
  }

  // 원자재: 규격마다 토막 길이 × 개수 × 세트
  final stock = <String, CuttingOptimizationResult>{};
  if (i.stockLength > 0) {
    final lens = <double>[
      for (final p in pieces)
        if (p.length > 0)
          for (var k = 0; k < p.qty * sets; k++) p.length,
    ];
    if (lens.isNotEmpty) {
      final r = optimizeCutting(
        pieces: lens,
        stockLength: i.stockLength,
        kerf: i.kerf,
      );
      stock[i.spec] = r;
      if (r.oversizedPieces.isNotEmpty) {
        warn(
          '원자재 ${_f(i.stockLength)}mm보다 긴 토막이 있습니다(${r.oversizedPieces.map(_f).join(', ')}mm).',
        );
      }
    }
  }

  return BracketPlan(
    pieces: pieces,
    plate: plateOut,
    drawing: BracketDrawing(
      members: members,
      plates: plates,
      holes: holeMarks,
      dims: dims,
      welds: welds,
      labels: labels,
    ),
    braceAngle: braceAngle,
    kgPerSet: kgSet,
    kgTotal: kgSet * sets,
    weightKnown: kgM != null,
    boltHoles: boltHoles,
    anchorHoles: anchorHoles,
    stock: stock,
    notes: notes,
    problems: problems,
  );
}
