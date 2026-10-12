// 형강 브라켓 제작도(10-10, 10-11 개편): 앵글·찬넬·평철·각파이프·H형강·스트럿·립C로 ㄱ자·삼각(가새)·문형(2단)·
// T자·천장 매달기 브라켓을 만들 때 자를 길이·끝 모양·구멍·판·용접·품번과 그림(조립도·부재도)을 계산한다. 화면 없이 계산만.
//  · 치수는 모두 바깥 치수(mm). 그림 좌표는 왼쪽 위 바깥 모서리가 (0, 0)이고 아래로 갈수록 y가 커진다.
//  · ㄱ자·삼각: 옆에서 본 그림. 벽이 왼쪽(x = 0, 벽 붙임 판이 있으면 판 뒷면), 가로대가 위에서 오른쪽으로 나간다.
//    A = 벽에서 가로대 끝까지, B = 가로대 윗면에서 기둥 끝까지.
//  · 문형: 앞에서 본 그림. 기둥 둘 + 위 가로대(+ 아래 가로대). W = 기둥 바깥면 사이, H = 바닥(베이스 판 밑면)에서 가로대 윗면까지.
//  · T자: 가운데 기둥 + 위 가로대(W = 0이면 기둥만). 천장 매달기: 천장(y = 0)에서 전산볼트 둘로 가로대를 매단다
//    (W = 가로대 길이, H = 천장에서 가로대 윗면까지).
//  · 부재마다 단면을 놓는 방향이 있다(bracket_profile.dart). 그림에 보이는 폭은 그 방향의 폭이고, 붙는 면(벽·위) 구멍은
//    그림 면과 직각이라 조립도에는 숨은선, 부재도(붙는 면에서 본 그림)에는 원으로 나온다(점검: 예전 그림은 구멍을
//    보이는 면 위에 원으로 찍어 다른 변에 뚫게 될 수 있었다).
//  · 품번: ① 기둥 ② 가로대 ③ 아래 가로대 ④ 가새 ⑤ 전산볼트 ⑥ 판 ⑦ 리브 차례로, 있는 것만 번호를 매긴다.
//  · 가새(삼각): 중심선이 가로대 밑면의 a(벽에서)와 기둥 안쪽 면의 b(위 바깥에서)를 잇는다. 끝은 가로대 면·기둥 면에
//    맞게 비스듬히 자른다.
//  · 무게는 형강 컷팅과 같은 이론 중량(steel_weight.dart), 판은 철 7.85 g/cm³(구멍 안 뺌).
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../tube_cutting/cutting_optimizer.dart';
import 'bracket_pipes.dart';
import 'bracket_profile.dart';

export 'bracket_pipes.dart';
export 'bracket_profile.dart';

enum BracketShape { l, brace, frame, tee, hanger }

/// 이음: 기둥 통과, 가로대 통과, 연귀(맞닿는 끝을 비스듬히), V컷 꺾기(한 본의 세운 변을 V로 따내고 꺾음, 10-11 사용자).
/// 기둥·가로대 통과(맞대기)는 앵글·찬넬처럼 날개가 있으면 현장처럼 따내기를 넣어 틈 없이 맞춘다([BracketExt]).
enum BracketJoint { postThrough, armThrough, miter, vbend }

/// 맞대기 따내기 한 구간: 부재 깊이(z) [z0]~[z1]은 끝을 [ext]만큼 더 길게(상대 부재의 얕은 면까지 들어감).
/// 나머지(상대 부재의 날개·세운 변과 겹치는 곳)는 잘라 낸다(따냄). 10-11 사용자: "앵글 형태 때문에 구멍이
/// 뻥뻥 뚫리는데 현업에서는 가공하거나 그라인더로 잘라내서 작업".
typedef BracketExt = ({double z0, double z1, double ext});

/// 맞대기 이음에서 [butt] 부재 끝을 [through] 부재 안으로 얼마나 넣는가(깊이 구간별). through의 붙는 쪽에서 잰
/// 단면 깊이 중 그 z에 있는 가장 깊은 면까지(= through.depth − 그 z의 가장 안쪽 면).
List<BracketExt> bracketNotchExt(
  BracketSectionView through,
  BracketSectionView butt,
) {
  // 날개 없는 평철(조각 하나)은 따내기가 없다(1mm 남짓 삐져나온 조각이 늘어나지 않게)
  if (through.round ||
      butt.round ||
      through.unknown ||
      butt.unknown ||
      through.rects.length < 2 ||
      butt.rects.length < 2) {
    return const [];
  }
  final w = butt.width;
  final zs = <double>{0, w};
  for (final r in [...through.rects, ...butt.rects]) {
    for (final z in [r.top, r.bottom]) {
      if (z > 1e-9 && z < w - 1e-9) zs.add(z);
    }
  }
  final sorted = zs.toList()..sort();
  final out = <BracketExt>[];
  for (var k = 0; k + 1 < sorted.length; k++) {
    final z0 = sorted[k], z1 = sorted[k + 1];
    if (z1 - z0 < 1e-9) continue;
    final zm = (z0 + z1) / 2;
    if (!butt.rects.any((r) => r.top <= zm && r.bottom >= zm)) continue;
    double? maxU;
    for (final r in through.rects) {
      if (r.top <= zm && r.bottom >= zm) {
        maxU = math.max(maxU ?? -double.infinity, r.right);
      }
    }
    if (maxU == null) continue;
    final ext = through.depth - maxU;
    if (ext <= 1e-6) continue;
    if (out.isNotEmpty &&
        (out.last.z1 - z0).abs() < 1e-9 &&
        (out.last.ext - ext).abs() < 1e-9) {
      out[out.length - 1] = (z0: out.last.z0, z1: z1, ext: ext);
    } else {
      out.add((z0: z0, z1: z1, ext: ext));
    }
  }
  return out;
}

/// 깊이 [z]에서 따내기 길이(없으면 0).
double bracketExtAt(List<BracketExt> es, double z) {
  for (final e in es) {
    if (z >= e.z0 - 1e-9 && z <= e.z1 + 1e-9) return e.ext;
  }
  return 0;
}

/// 한 줄로 늘어선 구멍들: 개수·지름·첫 구멍 거리·피치, 장공 길이, 게이지, 두 줄.
class HoleRow {
  final int count;
  final double dia, first, pitch;

  /// 장공 전체 길이(부재 길이 방향). 지름 이하면 둥근 구멍.
  final double slot;

  /// 게이지: 붙는 면의 등 쪽 가장자리(앵글은 등, 찬넬 날개는 웨브 쪽)에서 구멍 중심까지. null이면 단면 기본.
  final double? gauge;

  /// 두 줄: 양쪽 가장자리에서 게이지만큼(H형강은 늘 두 줄).
  final bool two;

  const HoleRow({
    this.count = 0,
    this.dia = 0,
    this.first = 0,
    this.pitch = 0,
    this.slot = 0,
    this.gauge,
    this.two = false,
  });
  bool get on => count > 0 && dia > 0;
  bool get slotted => slot > dia + 1e-9;

  /// 길이 방향으로 차지하는 길이.
  double get along => slotted ? slot : dia;
}

/// 판(베이스 판·벽 붙임 판).
class BracketPlateInput {
  /// 베이스 판: [w] 그림 가로, [l] 깊이(앞뒤). 벽 붙임 판: [w] 판 폭(앞뒤), [l] 판 높이(0이면 기둥 높이).
  final double w, l, t;

  /// 앵커 구멍 0·2·4개, 지름, 판 가장자리에서 구멍 중심까지.
  final int holes;
  final double dia, edge;

  /// 리브(베이스 판만): 0·2(그림 면 양옆)·4(앞뒤까지), 높이·길이(기둥 면에서)·두께.
  final int ribs;
  final double ribH, ribL, ribT;

  const BracketPlateInput({
    this.w = 150,
    this.l = 150,
    this.t = 9,
    this.holes = 4,
    this.dia = 13.5,
    this.edge = 25,
    this.ribs = 0,
    this.ribH = 80,
    this.ribL = 40,
    this.ribT = 6,
  });
}

class BracketInput {
  final BracketShape shape;

  /// 주 부재 규격(기둥·가로대, 천장 매달기는 가로대). [armSpec]·[braceSpec]이 있으면 가로대·가새만 그 규격.
  final String spec;
  final String? armSpec, braceSpec;

  /// 놓는 방향(-1이면 그 부재에 흔한 방향, bracket_profile.dart의 defaultOrient).
  final int postOrient, armOrient, braceOrient;

  /// 모르는 규격일 때 그림 폭(mm).
  final double fallbackD;

  /// ㄱ자·삼각: A 가로대 길이, B 기둥 높이. 문형·T자: A = 폭 W, B = 높이 H. 천장 매달기: A = 가로대 길이, B = 천장에서 가로대 윗면까지.
  final double a, b;
  final BracketJoint joint;

  /// 삼각: 가새 중심이 가로대 밑면에 닿는 자리(벽에서) [braceA], 기둥 안쪽 면에 닿는 자리(위 바깥에서) [braceB].
  final double braceA, braceB;

  /// ㄱ자·삼각: 기둥 구멍(위 바깥에서), 가로대 구멍(가로대 끝에서). 문형·T자·매달기: 가로대 구멍(왼쪽 바깥에서).
  final HoleRow postHoles, armHoles;

  /// 가로대 위 관(U볼트 한 쌍씩). 있으면 가로대 구멍은 이것으로 만들고 [armHoles]는 장공·게이지만 쓴다.
  final List<BracketPipe> pipes;

  /// 문형 2단: 바닥에서 아래 가로대 윗면까지(0이면 없음). [lowerHoles]면 위 가로대와 같은 자리에 구멍.
  final double lowerAt;
  final bool lowerHoles;

  /// 문형·T자 베이스 판, ㄱ자·삼각 벽 붙임 판.
  final bool basePlate;
  final BracketPlateInput base;
  final bool wallPlate;
  final BracketPlateInput wall;

  /// 천장 매달기: 전산볼트 규격, 가로대 끝에서 볼트 중심까지, 천장 쪽 물림 길이, 가로대 붙는 면 아래로 나오는 길이.
  final String rodSpec;
  final double rodEdge, rodTop, rodBelow;

  /// 용접 각장(mm, 0이면 이음마다 얇은 쪽 두께로).
  final double weld;

  /// V컷 꺾기 공제값(mm, 0이면 붙는 변 두께 × 2 — 날카롭게 꺾을 때 어림): 펼친 길이 = 바깥 치수 합 − 꺾는 곳마다 이 값.
  final double vBend;

  /// 만들 개수(세트), 원자재 길이, 톱날 여유.
  final int sets;
  final double stockLength, kerf;

  const BracketInput({
    required this.shape,
    required this.spec,
    this.armSpec,
    this.braceSpec,
    this.postOrient = -1,
    this.armOrient = -1,
    this.braceOrient = -1,
    this.fallbackD = 0,
    required this.a,
    required this.b,
    this.joint = BracketJoint.postThrough,
    this.braceA = 0,
    this.braceB = 0,
    this.postHoles = const HoleRow(),
    this.armHoles = const HoleRow(),
    this.pipes = const [],
    this.lowerAt = 0,
    this.lowerHoles = false,
    this.basePlate = false,
    this.base = const BracketPlateInput(),
    this.wallPlate = false,
    this.wall = const BracketPlateInput(w: 150, l: 0, t: 9),
    this.rodSpec = '전산볼트 M12',
    this.rodEdge = 50,
    this.rodTop = 25,
    this.rodBelow = 30,
    this.weld = 0,
    this.vBend = 0,
    this.sets = 1,
    this.stockLength = 6000,
    this.kerf = 2,
  });
}

/// 자른 토막·판의 구멍 하나. 부재: [fromEnd] 기준 끝에서 길이 방향, [z] 게이지(붙는 면 등 쪽에서, 평철을 세우면
/// 그림 폭 방향). 판: [fromEnd] 가로, [z] 세로(판 왼쪽 위에서).
class PieceHole {
  final String label;
  final double fromEnd, dia;
  final double z;
  final double slot;

  /// U볼트 구멍이면 관 이름('25A')과 관 중심(같은 기준 끝에서).
  final String? pipe;
  final double? pipeAt;
  const PieceHole(
    this.label,
    this.fromEnd,
    this.dia, {
    this.z = 0,
    this.slot = 0,
    this.pipe,
    this.pipeAt,
  });
  bool get slotted => slot > dia + 1e-9;
  double get along => slotted ? slot : dia;

  /// 기준 끝을 옮긴 같은 구멍(관 중심도 같이).
  PieceHole moved(double dx) => PieceHole(
    label,
    fromEnd + dx,
    dia,
    z: z,
    slot: slot,
    pipe: pipe,
    pipeAt: pipeAt == null ? null : pipeAt! + dx,
  );
}

enum BracketPieceKind { member, plate, rib, rod }

/// 부재 하나(그림 자리). 기둥 둘처럼 같은 품번이 여럿일 수 있다.
class BracketMember {
  final int mark;
  final String name;
  final BracketRole role;
  final BracketProfile profile;
  final int orient;
  final BracketSectionView view;

  /// 그림 자리: [origin] 붙는 쪽·기준 끝 모서리, [ex] 길이 방향, [ey] 붙는 면에서 안쪽(그림 폭 방향).
  final Offset origin, ex, ey;

  /// 옆 모양(x = 길이 방향 0.., y = 0(붙는 쪽)..그림 폭).
  final List<Offset> local;
  final List<PieceHole> holes;

  /// 기준 끝·반대 끝 이름('위 끝', '아래 끝').
  final (String, String) endNames;

  /// 맞대기 따내기(기준 끝·반대 끝). [local]은 따내기 전 모양이고, 기준 끝 따내기만큼 이미 뒤로 밀어 두어
  /// 가장 긴 끝(혀)이 x = 0이다.
  final List<BracketExt> extStart, extEnd;

  const BracketMember({
    required this.mark,
    required this.name,
    required this.role,
    required this.profile,
    required this.orient,
    required this.view,
    required this.origin,
    required this.ex,
    required this.ey,
    required this.local,
    this.holes = const [],
    required this.endNames,
    this.extStart = const [],
    this.extEnd = const [],
  });

  Offset at(double x, double y) => origin + ex * x + ey * y;

  /// 조립도·입체에 쓰는 모양(따내기로 들어간 혀는 상대 부재 뒤라 숨은선으로 따로 그린다).
  List<Offset> get poly => [for (final q in local) at(q.dx, q.dy)];
  double get depth => view.depth;

  double get _y0 => local.map((q) => q.dy).reduce(math.min);
  double get _y1 => local.map((q) => q.dy).reduce(math.max);

  /// 따내기 전 모양의 붙는 쪽·반대쪽 구간(끝 각도·입체용).
  /// (부재 좌표는 만들 때 1e-9로 다듬어 두어 가장자리 y에서 바로 잘라도 된다.)
  (double, double) get baseNear => bracketSpanAt(local, _y0) ?? (0, 0);
  (double, double) get baseFar => bracketSpanAt(local, _y1) ?? (0, 0);

  double get extStartMax => extStart.fold(0.0, (m, e) => math.max(m, e.ext));
  double get extEndMax => extEnd.fold(0.0, (m, e) => math.max(m, e.ext));

  /// 따내기 구간에 있는 단면의 그림 폭 범위(u).
  (double, double) extU(List<BracketExt> es) {
    var lo = double.infinity, hi = -double.infinity;
    for (final r in view.rects) {
      if (es.any((e) => r.top < e.z1 - 1e-9 && r.bottom > e.z0 + 1e-9)) {
        lo = math.min(lo, r.left);
        hi = math.max(hi, r.right);
      }
    }
    return lo.isFinite ? (lo, hi) : (0, 0);
  }

  /// 따내기 구간의 단면 그림 폭 띠들(이어진 것끼리, 점검 39: 찬넬·H는 위아래 날개가 따로 남는다).
  List<(double, double)> extStrips(List<BracketExt> es) {
    final segs = <(double, double)>[
      for (final r in view.rects)
        if (es.any((e) => r.top < e.z1 - 1e-9 && r.bottom > e.z0 + 1e-9))
          (r.left, r.right),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final out = <(double, double)>[];
    for (final sg in segs) {
      if (out.isNotEmpty && sg.$1 <= out.last.$2 + 1e-9) {
        out[out.length - 1] = (out.last.$1, math.max(out.last.$2, sg.$2));
      } else {
        out.add(sg);
      }
    }
    return out;
  }

  /// 따내기 혀까지 넣은 옆 모양(부재도·자를 길이).
  List<Offset> get outline {
    final s = extStartMax, e = extEndMax;
    if (s <= 0 && e <= 0) return local;
    final (b0, b1) = baseNear;
    final (f0, f1) = baseFar;
    final y0 = _y0, y1 = _y1;
    final (sa, sb) = extU(extStart);
    final (ea, eb) = extU(extEnd);
    final pts = <Offset>[
      Offset(s > 0 && sa <= y0 + 1e-9 ? b0 - s : b0, y0),
      Offset(e > 0 && ea <= y0 + 1e-9 ? b1 + e : b1, y0),
      if (e > 0) ...[
        if (ea > y0 + 1e-9) ...[Offset(b1, ea), Offset(b1 + e, ea)],
        Offset(b1 + e, eb),
        Offset(b1, eb),
      ],
      Offset(f1, y1),
      Offset(f0, y1),
      if (s > 0) ...[
        Offset(b0, sb),
        Offset(b0 - s, sb),
        if (sa > y0 + 1e-9) ...[Offset(b0 - s, sa), Offset(b0, sa)],
      ],
    ];
    return pts;
  }

  /// 붙는 쪽(y = 0)과 반대쪽(y = 그림 폭) 길이 구간(따내기 혀 포함).
  (double, double) get nearSpan => bracketSpanAt(outline, _y0) ?? (0, 0);
  (double, double) get farSpan => bracketSpanAt(outline, _y1) ?? (0, 0);
  double get nearLength => nearSpan.$2 - nearSpan.$1;
  double get farLength => farSpan.$2 - farSpan.$1;
  double get length => math.max(nearLength, farLength);

  /// 끝을 자른 각(직각에서 몇 °, 각도절단기 각). [start]면 기준 끝.
  double endAngle(bool start) {
    final a = baseNear, b = baseFar;
    final dx = start ? (b.$1 - a.$1) : (b.$2 - a.$2);
    return math.atan2(dx.abs(), depth) * 180 / math.pi;
  }
}

/// 자를 토막·판 하나(한 세트에 [qty]개).
class BracketPiece {
  final int mark;
  final String name;
  final BracketPieceKind kind;

  /// 앱 규격 이름(형강 컷팅으로 보낼 때, 판·리브는 빈 글자)과 도면 표기.
  final String spec, ks;

  /// 형강: 자를 길이(긴 쪽), [short] 짧은 쪽. 판: 가로 [length] × 세로 [width] × 두께 [thick]. 리브: 길이 × 높이 × 두께.
  final double length;
  final double? short;
  final double width, thick;
  final int qty;

  /// 끝 모양 글('양 끝 직각', '위 끝 45°, 아래 끝 직각').
  final String ends;

  final List<PieceHole> holes;

  /// 구멍 거리를 재는 끝('위 끝'), 구멍 뚫는 면('벽 붙는 면').
  final String holeFrom, holeFace;
  final double kgEach;

  /// 부재도용: 형강·전산볼트는 그림 자리 부재(첫 번째).
  final BracketMember? member;

  /// V컷 꺾기 토막: V 꼭짓점 자리(기준 끝에서, 펼친 토막).
  final List<double> vNotches;

  const BracketPiece({
    required this.mark,
    required this.name,
    required this.kind,
    this.spec = '',
    required this.ks,
    required this.length,
    this.short,
    this.width = 0,
    this.thick = 0,
    required this.qty,
    required this.ends,
    this.holes = const [],
    this.holeFrom = '',
    this.holeFace = '',
    required this.kgEach,
    this.member,
    this.vNotches = const [],
  });

  String get markText => bracketMarkText(mark);

  /// 표·글에 쓰는 이름("① 기둥").
  String get title => '$markText $name';
}

/// 품번 글: ①~⑳, 그 뒤는 (21).
String bracketMarkText(int n) =>
    n >= 1 && n <= 20 ? String.fromCharCode(0x2460 + n - 1) : '($n)';

/// 용접 한 곳: 그림 자리, 지시선 방향(화면), 각장, 전둘레, 무엇과 무엇.
class BracketWeld {
  final Offset at;
  final Offset dir;
  final double size;
  final bool allAround;
  final String what;

  /// 그림에 기호를 그리는가. 같은 이음이 여러 곳이면 한 곳만 그리고 "2곳"으로 적는다.
  final bool show;

  /// V 홈 맞대기 용접(V컷 꺾은 곳, 점검 24: 필릿 "z5 양면"으로 적혔다). 아니면 필릿.
  final bool groove;
  const BracketWeld(
    this.at,
    this.dir,
    this.size,
    this.what, {
    this.allAround = true,
    this.show = true,
    this.groove = false,
  });
}

/// 베이스 판 리브 하나(기둥 단면 좌표): 뿌리 [u]·[z](기둥 살이 있는 면 위), 뻗는 방향 [du]·[dz](±1, 둘 중 하나).
/// 점검 26: 판 가운데에 못박아 앵글 열린 쪽에서는 기둥에 안 닿았다.
class BracketRib {
  final double u, z, du, dz;
  const BracketRib(this.u, this.z, this.du, this.dz);
}

/// 단면에서 [u](또는 [z]) 줄에 살이 있는 구간 중 가장 긴 것의 가운데. 살이 없으면 null.
double? bracketMaterialCenter(BracketSectionView v, {double? u, double? z}) {
  const eps = 1e-6;
  final segs = <(double, double)>[
    for (final r in v.rects)
      if (u != null && r.left <= u + eps && r.right >= u - eps)
        (r.top, r.bottom)
      else if (z != null && r.top <= z + eps && r.bottom >= z - eps)
        (r.left, r.right),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  if (segs.isEmpty) return null;
  final merged = <(double, double)>[];
  for (final sg in segs) {
    if (merged.isNotEmpty && sg.$1 <= merged.last.$2 + eps) {
      merged[merged.length - 1] = (
        merged.last.$1,
        math.max(merged.last.$2, sg.$2),
      );
    } else {
      merged.add(sg);
    }
  }
  final best = merged.reduce((a, b) => (b.$2 - b.$1) > (a.$2 - a.$1) ? b : a);
  return (best.$1 + best.$2) / 2;
}

/// 판 크기 자동: 앵커 구멍이 기둥에서 5mm 떨어지고 리브가 들어가게, 10 단위로 올리고 150 이상(점검 33).
double bracketAutoPlate(
  double post, {
  double edge = 25,
  double dia = 13.5,
  int holes = 4,
  double rib = 0,
}) {
  var need = post + 10;
  if (holes > 0) need = math.max(need, post + 2 * (edge + dia / 2 + 5));
  if (rib > 0) need = math.max(need, post + 2 * rib);
  return math.max(150, (need / 10).ceil() * 10.0);
}

// ── 그림 ──

/// 치수선 하나. [vertical]이면 a·b의 높이 차(세로)를, 아니면 가로 차를 잰다. 치수선은 두 점 중
/// 바깥쪽(음수면 왼쪽·위, 양수면 오른쪽·아래)에서 [offset]만큼(화면 점) 떨어진다.
class BracketDim {
  final Offset a, b;
  final double offset;
  final String text;
  final bool vertical;

  /// 치수선 기준 자리(mm, 가로 치수는 y·세로 치수는 x). 있으면 두 점 대신 여기에서 [offset]만큼 띄운다
  /// (부재도에서 비스듬한 끝의 반대쪽 길이를 위 줄에 달 때).
  final double? base;
  const BracketDim(
    this.a,
    this.b,
    this.offset,
    this.text, {
    this.vertical = false,
    this.base,
  });
}

/// 그림 면에 보이는 구멍(원·장공). 장공은 [dir] 방향으로 [slot] 길이.
class BracketHoleMark {
  final Offset at;
  final double dia;
  final double slot;
  final Offset dir;
  const BracketHoleMark(
    this.at,
    this.dia, {
    this.slot = 0,
    this.dir = const Offset(1, 0),
  });
}

/// 글: 그림 자리 [at](mm)에서 화면 점으로 [shift]만큼 옮겨 쓴다.
class BracketLabel {
  final Offset at;
  final String text;
  final Offset shift;
  final bool bold;

  /// 그림 제목 같은 덧글(휴대폰 그림 칸처럼 좁으면 뺀다, 점검 43).
  final bool minor;
  const BracketLabel(
    this.at,
    this.text, {
    this.shift = Offset.zero,
    this.bold = false,
    this.minor = false,
  });
}

enum BracketFill { member, plate, rod, nut, ceiling, pipe }

class BracketPoly {
  final List<Offset> pts;
  final BracketFill fill;
  const BracketPoly(this.pts, this.fill);
}

enum BracketLineStyle { solid, hidden, center }

class BracketLine {
  final Offset a, b;
  final BracketLineStyle style;
  const BracketLine(this.a, this.b, this.style);
}

/// 품번 풍선: 부재 위 [at]에서 화면 점 방향 [dir]으로 뽑는다.
class BracketBalloon {
  final Offset at;
  final int mark;
  final Offset dir;
  const BracketBalloon(this.at, this.mark, this.dir);
}

/// 단면 표시(그림 오른쪽 칸): 품번, 놓은 단면, 붙는 쪽 이름, 그림에서 부재 길이 방향이 세로인가, 붙는 쪽이 오른쪽인가.
class BracketSectionMark {
  final int mark;
  final BracketSectionView view;
  final String side;
  final bool vertical;
  final bool flip;
  const BracketSectionMark(
    this.mark,
    this.view,
    this.side, {
    this.vertical = false,
    this.flip = false,
  });
}

class BracketDrawing {
  final List<BracketPoly> polys;
  final List<BracketLine> lines;
  final List<BracketHoleMark> holes;
  final List<BracketDim> dims;
  final List<BracketWeld> welds;
  final List<BracketBalloon> balloons;
  final List<BracketSectionMark> sections;
  final List<BracketLabel> labels;
  const BracketDrawing({
    this.polys = const [],
    this.lines = const [],
    this.holes = const [],
    this.dims = const [],
    this.welds = const [],
    this.balloons = const [],
    this.sections = const [],
    this.labels = const [],
  });

  /// 모양을 감싸는 상자(mm). 치수선·글은 화면 점으로 떨어지니 그리는 쪽이 여백을 둔다.
  (double, double, double, double) bounds() {
    var x0 = double.infinity, y0 = double.infinity;
    var x1 = -double.infinity, y1 = -double.infinity;
    void add(Offset p) {
      x0 = math.min(x0, p.dx);
      y0 = math.min(y0, p.dy);
      x1 = math.max(x1, p.dx);
      y1 = math.max(y1, p.dy);
    }

    for (final p in polys) {
      p.pts.forEach(add);
    }
    for (final l in lines) {
      add(l.a);
      add(l.b);
    }
    if (x0 == double.infinity) return (0, 0, 1, 1);
    return (x0, y0, x1, y1);
  }
}

/// 판 정보(베이스 판·벽 붙임 판).
class BracketPlate {
  final String name;
  final double w, l, t;
  final int qty;

  /// 판 좌표(왼쪽 위 (0, 0), x 가로, y 세로)의 구멍 중심.
  final List<Offset> holes;
  final double holeDia;

  /// 판 위 기둥 자리(판 좌표 직사각형 조각들)와 리브 자리.
  final List<List<Offset>> footprint;
  final List<List<Offset>> ribs;
  final double kgEach;
  final bool wall;

  /// 리브(기둥 단면 좌표)와 높이·길이·두께. 입체·조립도가 같은 자리를 쓴다.
  final List<BracketRib> ribSpecs;
  final double ribH, ribL, ribT;
  const BracketPlate({
    required this.name,
    required this.w,
    required this.l,
    required this.t,
    required this.qty,
    required this.holes,
    required this.holeDia,
    this.footprint = const [],
    this.ribs = const [],
    required this.kgEach,
    this.wall = false,
    this.ribSpecs = const [],
    this.ribH = 0,
    this.ribL = 0,
    this.ribT = 0,
  });
}

class BracketPlan {
  final BracketInput input;
  final List<BracketMember> members;
  final List<BracketPiece> pieces;
  final BracketPlate? plate;
  final BracketDrawing drawing;
  final List<BracketWeld> welds;

  /// 가새 기울기(가로에서, °). 가새가 없으면 null.
  final double? braceAngle;

  /// 한 세트·전체 무게(kg). 모르는 규격이 있으면 그 몫은 0이고 [weightKnown]이 false.
  final double kgPerSet, kgTotal;
  final bool weightKnown;

  /// 지름 → 전체 개수: 벽 고정 구멍(기둥·벽 판), 가로대 구멍(U볼트·클램프), 베이스 판 앵커 구멍.
  final Map<double, int> wallHoles, armHoles, anchorHoles;

  /// 원자재 계획(규격 → 결과).
  final Map<String, CuttingOptimizationResult> stock;

  final List<String> notes, problems;
  bool get ok => problems.isEmpty;

  const BracketPlan({
    required this.input,
    required this.members,
    required this.pieces,
    required this.plate,
    required this.drawing,
    required this.welds,
    required this.braceAngle,
    required this.kgPerSet,
    required this.kgTotal,
    required this.weightKnown,
    required this.wallHoles,
    required this.armHoles,
    required this.anchorHoles,
    required this.stock,
    required this.notes,
    required this.problems,
  });

  BracketPiece? pieceOf(int mark) {
    for (final p in pieces) {
      if (p.mark == mark) return p;
    }
    return null;
  }
}

/// 강판 무게(kg/mm³): 7.85 g/cm³.
const double kSteelKgPerMm3 = 7.85e-6;

/// 볼트 구멍 끝 거리 최소: 구멍 지름의 1.2배(EN 1993-1-8 표 3.3 e1·e2 최소값).
const double kBracketEdgeFactor = 1.2;

/// 규격 이름에서 그림에 보이는 폭(흔한 방향). 모르면 null.
double? bracketMemberWidth(String spec) {
  final p = BracketProfile.parse(spec);
  if (!p.known) return null;
  return p.view(p.defaultOrient(BracketRole.top), BracketRole.top).depth;
}

/// 전산볼트가 지나는 구멍 지름(M8 9, M10 11, M12 13.5, M16 17.5, M20 22 — 펀치 금형 기본값과 같은 줄).
double bracketRodHole(double d) => switch (d) {
  6 => 7,
  8 => 9,
  10 => 11,
  12 => 13.5,
  16 => 17.5,
  20 => 22,
  _ => d + 2,
};

String _f(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s == '-0' ? '0' : s;
}

List<Offset> _rect(double x0, double y0, double x1, double y1) => [
  Offset(x0, y0),
  Offset(x1, y0),
  Offset(x1, y1),
  Offset(x0, y1),
];

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

/// 두 직선(점 p + 방향 u, 점 q + 방향 v)의 만나는 점.
Offset _meet(Offset p, Offset u, Offset q, Offset v) {
  final den = u.dx * v.dy - u.dy * v.dx;
  final t = ((q.dx - p.dx) * v.dy - (q.dy - p.dy) * v.dx) / den;
  return p + u * t;
}

/// 다각형을 가로선 y로 자른 구간(가장 왼쪽·오른쪽). 안 걸리면 null.
(double, double)? bracketSpanAt(List<Offset> poly, double y) {
  double? lo, hi;
  for (var k = 0; k < poly.length; k++) {
    final a = poly[k], b = poly[(k + 1) % poly.length];
    if ((a.dy - y) * (b.dy - y) > 0) continue;
    if ((a.dy - b.dy).abs() < 1e-12) {
      for (final x in [a.dx, b.dx]) {
        lo = lo == null ? x : math.min(lo, x);
        hi = hi == null ? x : math.max(hi, x);
      }
      continue;
    }
    final x = a.dx + (b.dx - a.dx) * (y - a.dy) / (b.dy - a.dy);
    lo = lo == null ? x : math.min(lo, x);
    hi = hi == null ? x : math.max(hi, x);
  }
  return lo == null ? null : (lo, hi!);
}

BracketPlan bracketPlan(BracketInput i) {
  final notes = <String>[], problems = <String>[];
  void warn(String s) {
    if (!problems.contains(s)) problems.add(s);
  }

  void note(String s) {
    if (!notes.contains(s)) notes.add(s);
  }

  final sets = i.sets < 1 ? 1 : i.sets;
  final shape = i.shape;
  final lLike = shape == BracketShape.l || shape == BracketShape.brace;
  final mainP = BracketProfile.parse(i.spec, fallbackDepth: i.fallbackD);
  final armP = i.armSpec == null || i.armSpec!.trim().isEmpty
      ? mainP
      : BracketProfile.parse(i.armSpec!, fallbackDepth: i.fallbackD);
  final braceP = i.braceSpec == null || i.braceSpec!.trim().isEmpty
      ? mainP
      : BracketProfile.parse(i.braceSpec!, fallbackDepth: i.fallbackD);
  final postRole = lLike ? BracketRole.wall : BracketRole.none;
  int ori(BracketProfile p, int o, BracketRole r) =>
      o < 0 || o >= p.orientCount ? p.defaultOrient(r) : o;
  final postO = ori(mainP, i.postOrient, postRole);
  final armO = ori(armP, i.armOrient, BracketRole.top);
  final braceO = ori(braceP, i.braceOrient, BracketRole.none);
  final postV = mainP.view(postO, postRole);
  final armV = armP.view(armO, BracketRole.top);
  final braceV = braceP.view(braceO, BracketRole.none);
  final dp = postV.depth, da = armV.depth, db = braceV.depth;
  for (final p in {mainP, armP, if (shape == BracketShape.brace) braceP}) {
    if (!p.known) {
      if (i.fallbackD <= 0) {
        warn('규격 "${p.label}"을 읽지 못했습니다. "앵글 50x50x5"처럼 적거나 부재 폭을 넣으십시오.');
      } else {
        note(
          '규격 "${p.label}"의 단면을 몰라 그림 폭 ${_f(i.fallbackD)}mm 네모로 그렸고 무게에서 뺐습니다.',
        );
      }
    }
  }

  final members = <BracketMember>[];
  final polys = <BracketPoly>[];
  final lines = <BracketLine>[];
  final holeMarks = <BracketHoleMark>[];
  final dims = <BracketDim>[];
  final welds = <BracketWeld>[];
  // 풍선·단면은 부재 이름(열쇠)으로 모아 두고 품번은 끝에 매긴다
  final balloons = <(Offset, String, Offset)>[];
  final sections = <(String, BracketSectionView, String, bool)>[];
  final labels = <BracketLabel>[];
  double? braceAngle;
  BracketPlate? plateOut;

  // 품번: 있는 부재만 차례로
  const order = ['post', 'arm', 'lower', 'brace', 'rod', 'plate', 'rib'];
  final present = <String>{};
  // V컷 꺾기가 되면 기둥·가로대가 한 토막(한 품번)
  var vMerge = false;
  int markOf(String key) {
    final k = vMerge && key == 'arm' ? 'post' : key;
    return order
            .where((x) => present.contains(x) && !(vMerge && x == 'arm'))
            .toList()
            .indexOf(k) +
        1;
  }

  /// 그림 자리 다각형 [poly]를 부재 좌표로 옮겨 부재를 만든다.
  BracketMember member({
    required String key,
    required String name,
    required BracketRole role,
    required BracketProfile profile,
    required int orient,
    required BracketSectionView view,
    required List<Offset> poly,
    required Offset origin,
    required Offset ex,
    required Offset ey,
    List<PieceHole> holes = const [],
    required (String, String) endNames,
    List<BracketExt> extStart = const [],
    List<BracketExt> extEnd = const [],
  }) {
    present.add(key);
    var local = [
      // 계산 찌꺼기(1e-15)를 지워 가장자리 자르기가 어긋나지 않게
      for (final p in poly)
        Offset(
          _dot(p - origin, ex),
          (_dot(p - origin, ey) * 1e9).round() / 1e9,
        ),
    ];
    // 기준 끝 가장 앞이 0이 되게
    final minX = local.map((q) => q.dx).reduce(math.min);
    var o = origin;
    var hs = holes;
    if (minX.abs() > 1e-9) {
      local = [for (final q in local) q - Offset(minX, 0)];
      o = origin + ex * minX;
      hs = [for (final h in holes) h.moved(-minX)];
    }
    // 기준 끝 따내기 혀가 x = 0이 되게(구멍은 혀 끝, 곧 그 변의 실제 끝에서 잰다)
    final sMax = extStart.fold(0.0, (m, e) => math.max(m, e.ext));
    if (sMax > 0) {
      local = [for (final q in local) q + Offset(sMax, 0)];
      o = o - ex * sMax;
      hs = [for (final h in hs) h.moved(sMax)];
    }
    return BracketMember(
      mark: 0,
      name: name,
      role: role,
      profile: profile,
      orient: orient,
      view: view,
      origin: o,
      ex: ex,
      ey: ey,
      local: local,
      holes: hs,
      endNames: endNames,
      extStart: extStart,
      extEnd: extEnd,
    );
  }

  final keyOf = <BracketMember, String>{};
  void addMember(String key, BracketMember m) {
    members.add(m);
    keyOf[m] = key;
  }

  /// 줄 구멍을 부재 좌표로: 기준 끝에서 [first0] + k·피치, 게이지(두 줄이면 양쪽).
  List<PieceHole> rowHoles(
    String name,
    HoleRow r,
    BracketSectionView v, {
    double shift = 0,
  }) {
    if (!r.on) return const [];
    if (!v.canHole) {
      warn(
        '$name 쪽은 ${v.slot ? '스트럿 슬롯이라 홀 대신 채널 너트로 고정합니다' : '홀을 낼 수 없는 면입니다'}. 방향을 바꾸거나 홀을 빼십시오.',
      );
      return const [];
    }
    final rad = r.dia / 2;
    final g = r.gauge ?? v.gauge;
    final two = r.two || v.twoLines;
    final zs = <double>[];
    if (v.holesFront) {
      // 평철을 세운 면: 게이지는 그림 폭 방향
      zs.add(g);
      if (g - rad < -1e-9 || g + rad > v.depth + 1e-9) {
        warn('$name 홀이 평철 폭(${_f(v.depth)})에 다 들어가지 않습니다. 게이지·지름을 고치십시오.');
      }
    } else {
      final (lo, hi) = v.zone;
      final w = v.width;
      zs.add(g);
      if (two) zs.add(w - g);
      bool fits(double z) {
        if (v.twoLines) {
          // H형강: 웨브 양쪽 날개
          final wl = (w - v.web) / 2, wr = (w + v.web) / 2;
          return (z - rad >= -1e-9 && z + rad <= wl + 1e-9) ||
              (z - rad >= wr - 1e-9 && z + rad <= w + 1e-9);
        }
        return z - rad >= lo - 1e-9 && z + rad <= hi + 1e-9;
      }

      if (!zs.every(fits)) {
        warn(
          '$name 홀이 붙는 면에 다 들어가지 않습니다(게이지 ${_f(g)}, 지름 ${_f(r.dia)}, 홀 중심이 올 수 있는 곳 ${_f(lo + rad)}~${_f(hi - rad)}). 게이지·지름을 고치십시오.',
        );
      } else if (two && (w - 2 * g).abs() < r.dia) {
        warn('$name 홀 두 줄이 서로 겹칩니다. 게이지를 줄이십시오.');
      }
    }
    if (r.count > 1 && r.pitch <= r.along + 1e-9) {
      warn('$name 홀 피치가 홀 길이 이하라 홀이 서로 겹칩니다.');
    }
    return [
      for (var k = 0; k < r.count; k++)
        for (final z in zs)
          PieceHole(
            '$name ${k + 1}',
            r.first + k * r.pitch - shift,
            r.dia,
            z: z,
            slot: r.slotted ? r.slot : 0,
          ),
    ];
  }

  /// 가로대 구멍: 관 자리면 관마다 U볼트 한 쌍(관 중심 ± 다리 간격/2), 아니면 일자 줄.
  List<PieceHole> armRow(
    String name,
    BracketSectionView v, {
    double shift = 0,
  }) {
    if (i.pipes.isEmpty) return rowHoles(name, i.armHoles, v, shift: shift);
    final out = <PieceHole>[];
    for (var k = 0; k < i.pipes.length; k++) {
      final p = i.pipes[k];
      if (p.spacing < p.od - 1e-9) {
        warn(
          '${k + 1}번 관(${p.name}) U볼트 다리 간격 ${_f(p.spacing)}이 관 외경 ${_f(p.od)}보다 작아 관이 들어가지 않습니다. 다리 간격을 고치십시오.',
        );
      }
      final pair = rowHoles(
        name,
        HoleRow(
          count: 2,
          dia: p.hole,
          first: p.at - p.spacing / 2,
          pitch: p.spacing,
          slot: i.armHoles.slot,
          gauge: i.armHoles.gauge,
        ),
        v,
        shift: shift,
      );
      for (final h in pair) {
        out.add(
          PieceHole(
            '$name ${out.length + 1}',
            h.fromEnd,
            h.dia,
            z: h.z,
            slot: h.slot,
            pipe: p.name,
            pipeAt: p.at - shift,
          ),
        );
      }
    }
    // 이웃 관: 몸끼리 닿음, 다리 사이에 너트·와셔가 들어가는가(와셔 지름 어림 + 5)
    for (var k = 1; k < i.pipes.length; k++) {
      final a = i.pipes[k - 1], b = i.pipes[k];
      final d = b.at - a.at;
      if (d < (a.od + b.od) / 2 - 1e-9) {
        warn(
          '$k번·${k + 1}번 관이 서로 겹칩니다(중심 거리 ${_f(d)}, 닿지 않으려면 ${_f((a.od + b.od) / 2)} 이상). 관 사이를 늘리십시오.',
        );
        continue;
      }
      final legs = d - a.spacing / 2 - b.spacing / 2;
      final need = (bracketUWasher(a.thread) + bracketUWasher(b.thread)) / 2;
      if (legs < need - 1e-9) {
        warn(
          '$k번·${k + 1}번 관 U볼트 다리 사이가 ${_f(legs)}mm라 너트·와셔가 닿습니다(${_f(need)}mm 이상). 관 사이를 늘리십시오.',
        );
      }
    }
    return out;
  }

  /// 부재 구멍 검사: 붙는 쪽 길이 밖, 끝에서 너무 가까움.
  void checkHoles(BracketMember m, String name) {
    final (s0, s1) = m.nearSpan;
    final seen = <double>{};
    for (final h in m.holes) {
      if (!seen.add(h.fromEnd)) continue;
      final half = h.along / 2;
      if (h.fromEnd - half < s0 - 1e-9 || h.fromEnd + half > s1 + 1e-9) {
        warn(
          '$name 홀 ${h.label.split(' ').last}번이 부재 밖으로 나옵니다(붙는 면 길이 ${_f(s1 - s0)}mm). 첫 홀·피치를 줄이십시오.',
        );
        continue;
      }
      // 끝 거리: 장공은 가까운 반원 중심에서
      final reach = (h.along - h.dia) / 2;
      final e = math.min(h.fromEnd - reach - s0, s1 - h.fromEnd - reach);
      if (e < kBracketEdgeFactor * h.dia - 1e-9) {
        note(
          '$name 홀 ${h.label.split(' ').last}번이 끝에서 ${_f(e)}mm입니다. 홀 지름의 1.2배(${_f(kBracketEdgeFactor * h.dia)}mm)보다 가까우면 끝이 찢어질 수 있습니다.',
        );
      }
    }
  }

  final jName = i.joint;

  /// V컷 꺾기가 되는가: 기둥·가로대가 같은 규격·같은 방향의 앵글·찬넬. 안 되면 알리고 연귀 모양으로 둔다.
  bool vbendOk() {
    const bendable = {
      BracketProfileKind.angle,
      BracketProfileKind.unequalAngle,
      BracketProfileKind.channel,
      BracketProfileKind.lipChannel,
    };
    if (!bendable.contains(mainP.kind)) {
      warn('V컷 꺾기는 앵글·찬넬만 됩니다. 이음을 바꾸십시오.');
      return false;
    }
    if (armP.label != mainP.label || armO != postO) {
      warn('V컷 꺾기는 기둥·가로대가 같은 규격·같은 방향이어야 합니다(부재 탭).');
      return false;
    }
    return true;
  }

  double weldOf(Iterable<BracketProfile> ps, [double? plateT]) {
    if (i.weld > 0) return i.weld;
    var t = double.infinity;
    for (final p in ps) {
      if (p.known && p.thickness > 0) t = math.min(t, p.thickness);
    }
    if (plateT != null && plateT > 0) t = math.min(t, plateT);
    if (!t.isFinite) return 3;
    return math.max(2.0, (math.min(t, 6.0) * 2).floor() / 2);
  }

  switch (shape) {
    case BracketShape.l:
    case BracketShape.brace:
      final wp = i.wallPlate;
      final tpl = wp ? i.wall.t : 0.0;
      final px = tpl;
      final a = i.a, b = i.b;
      if (a <= px + dp + 1 || b <= da + 1) {
        warn(
          '가로대 길이는 기둥 폭${wp ? '과 벽 판 두께' : ''}(${_f(px + dp)}mm)보다, 기둥 높이는 가로대 폭(${_f(da)}mm)보다 커야 합니다.',
        );
      }
      final j = jName;
      if (j == BracketJoint.vbend) vMerge = vbendOk();
      // V컷 꺾기는 꺾은 뒤 모양이 연귀와 같다(바깥 변은 이어지고 세운 변은 45° 맞댐)
      final miterLike = j == BracketJoint.miter || j == BracketJoint.vbend;
      if (miterLike && (dp - da).abs() > 0.05) {
        note(
          '기둥과 가로대 그림 폭이 달라(${_f(dp)} · ${_f(da)}) 연귀가 45°가 아닙니다. 끝 각도는 자를 것 표를 보십시오.',
        );
      }
      final postTop = j == BracketJoint.armThrough ? da : 0.0;
      final armX0 = j == BracketJoint.postThrough ? px + dp : px;
      final postPoly = miterLike
          ? [
              Offset(px, 0),
              Offset(px + dp, da),
              Offset(px + dp, b),
              Offset(px, b),
            ]
          : _rect(px, postTop, px + dp, b);
      final armPoly = miterLike
          ? [Offset(px, 0), Offset(a, 0), Offset(a, da), Offset(px + dp, da)]
          : _rect(armX0, 0, a, da);
      // 기둥: 붙는 면 = 벽(왼쪽), 기준 끝 = 위
      final pHoles = wp
          ? const <PieceHole>[]
          : rowHoles('기둥', i.postHoles, postV, shift: postTop);
      final post = member(
        key: 'post',
        name: '기둥',
        role: BracketRole.wall,
        profile: mainP,
        orient: postO,
        view: postV,
        poly: postPoly,
        origin: Offset(px, miterLike ? 0 : postTop),
        ex: const Offset(0, 1),
        ey: const Offset(1, 0),
        holes: pHoles,
        endNames: ('위 끝', '아래 끝'),
        // 가로대 통과: 기둥 벽 쪽 변이 가로대 위 변 밑까지 올라가고 나머지는 따냄
        extStart: j == BracketJoint.armThrough
            ? bracketNotchExt(armV, postV)
            : const [],
      );
      addMember('post', post);
      for (final h in post.holes) {
        if (h.fromEnd - h.along / 2 < -1e-9) {
          warn(
            '기둥 홀이 가로대 자리에 걸립니다. 첫 홀을 ${_f(post.origin.dy + h.along / 2)}mm 이상으로 하십시오.',
          );
          break;
        }
      }
      final aHoles = armRow('가로대', armV);
      final arm = member(
        key: 'arm',
        name: '가로대',
        role: BracketRole.top,
        profile: armP,
        orient: armO,
        view: armV,
        poly: armPoly,
        origin: Offset(a, 0),
        ex: const Offset(-1, 0),
        ey: const Offset(0, 1),
        holes: aHoles,
        endNames: ('가로대 끝', '기둥 쪽 끝'),
        // 기둥 통과: 가로대 위 변(혀)이 기둥 벽 쪽 변까지 들어가고 세운 변·모서리는 따냄
        extEnd: j == BracketJoint.postThrough
            ? bracketNotchExt(postV, armV)
            : const [],
      );
      addMember('arm', arm);
      // 가로대가 기둥 위를 지나는 이음(가로대 통과·연귀·V컷)에서 기둥 바로 위 구멍은 볼트가 기둥에 걸린다(점검 37)
      if (j != BracketJoint.postThrough) {
        for (final h in arm.holes) {
          final x = arm.at(h.fromEnd, 0).dx;
          if (x + h.along / 2 > px - 1e-9 && x - h.along / 2 < px + dp + 1e-9) {
            warn('가로대 홀이 기둥 바로 위라 볼트가 기둥에 걸립니다. 홀을 기둥 밖으로 옮기십시오.');
            break;
          }
        }
      }
      final wJoint = weldOf([mainP, armP]);
      welds.add(
        BracketWeld(
          switch (j) {
            BracketJoint.postThrough => Offset(px + dp, da / 2),
            BracketJoint.armThrough => Offset(px + dp / 2, da),
            _ => Offset(px + dp / 2, da / 2),
          },
          const Offset(1, 1),
          wJoint,
          vMerge ? '꺾은 곳 V 이음' : '가로대–기둥',
          allAround: !vMerge,
          groove: vMerge,
        ),
      );
      // 전체 치수는 바깥 줄, 삼각의 가새 자리는 안쪽 줄(화면 점).
      final brace = shape == BracketShape.brace;
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
      if (brace) {
        final p1 = Offset(i.braceA, da), p2 = Offset(px + dp, i.braceB);
        final dx = i.braceA - (px + dp), dy = i.braceB - da;
        if (dx <= db || dy <= db) {
          warn(
            '가새 자리가 모서리에 너무 가깝습니다. 가새 가로대 쪽 자리는 ${_f(px + dp + db)}mm보다, 기둥 쪽 자리는 ${_f(da + db)}mm보다 크게 하십시오.',
          );
        } else {
          final theta = math.atan2(dy, dx); // 가로에서 아래로 기운 각
          braceAngle = theta * 180 / math.pi;
          final u = (p2 - p1) / (p2 - p1).distance;
          final nrm = Offset(-u.dy, u.dx);
          final half = db / 2;
          const horiz = Offset(1, 0), vert = Offset(0, 1);
          final topA = _meet(p1 + nrm * half, u, Offset(0, da), horiz);
          final topB = _meet(p1 - nrm * half, u, Offset(0, da), horiz);
          final botA = _meet(p1 + nrm * half, u, Offset(px + dp, 0), vert);
          final botB = _meet(p1 - nrm * half, u, Offset(px + dp, 0), vert);
          if (math.max(topA.dx, topB.dx) > a + 1e-9) {
            warn('가새가 가로대 끝을 넘어갑니다. 가로대 쪽 자리를 줄이십시오.');
          }
          if (math.max(botA.dy, botB.dy) > b + 1e-9) {
            warn('가새가 기둥 끝을 넘어갑니다. 기둥 쪽 자리를 줄이십시오.');
          }
          // 부재 좌표: 길이 방향 = 가로대 쪽에서 기둥 쪽, 폭 방향 = 위(모서리) 쪽에서
          final ey = nrm.dy < 0 ? -nrm : nrm;
          final side = ey == nrm ? -1.0 : 1.0;
          final br = member(
            key: 'brace',
            name: '가새',
            role: BracketRole.none,
            profile: braceP,
            orient: braceO,
            view: braceV,
            poly: [topA, topB, botB, botA],
            origin: p1 + nrm * (half * side),
            ex: u,
            ey: ey,
            endNames: ('가로대 쪽', '기둥 쪽'),
          );
          addMember('brace', br);
          final wb = weldOf([braceP, armP]);
          welds.add(
            BracketWeld((topA + topB) / 2, const Offset(1, 1), wb, '가새–가로대'),
          );
          welds.add(
            BracketWeld(
              (botA + botB) / 2,
              const Offset(1, 0.6),
              weldOf([braceP, mainP]),
              '가새–기둥',
            ),
          );
          // 가새 끝이 붙는 자리에 기둥 구멍이 있으면 볼트(너트)를 돌릴 자리가 없다.
          final footTop = math.min(botA.dy, botB.dy);
          final footBot = math.max(botA.dy, botB.dy);
          final blocked = <double>{
            for (final h in pHoles)
              if (h.fromEnd + postTop + h.along / 2 > footTop &&
                  h.fromEnd + postTop - h.along / 2 < footBot)
                h.fromEnd + postTop,
          };
          if (blocked.isNotEmpty) {
            note(
              '가새 끝 자리(위에서 ${_f(footTop)}~${_f(footBot)}mm)에 기둥 홀이 걸립니다(${blocked.map((v) => '${_f(v)}mm').join(', ')}). 볼트를 조이기 어려울 수 있으니 홀을 옮기십시오.',
            );
          }
          if (braceAngle < 30 || braceAngle > 60) {
            note(
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
          labels.add(
            BracketLabel((p1 + p2) / 2, '${_f(braceAngle)}°', bold: true),
          );
        }
      }
      // 벽 붙임 판: 기둥 뒤에 세운 판, 앵커 구멍은 판에
      if (wp) {
        final hp = i.wall.l > 0 ? i.wall.l : b;
        final e = i.wall.edge;
        // 판 폭 0이면 기둥 폭에 맞춰 자동(점검 33)
        final wpw = i.wall.w > 0
            ? i.wall.w
            : bracketAutoPlate(
                postV.width,
                edge: e,
                dia: i.wall.dia,
                holes: i.wall.holes,
              );
        // 판은 위(0)에서 시작하니 기둥 아래 끝(b)까지 닿아야 한다(점검 36)
        if (hp + 1e-9 < b) {
          note(
            '벽 붙임 판 높이(${_f(hp)})가 기둥 아래 끝(${_f(b)})보다 짧습니다. 기둥 아래가 판 밖에 남습니다.',
          );
        }
        polys.add(BracketPoly(_rect(0, 0, tpl, hp), BracketFill.plate));
        final bw = postV.width;
        if (wpw < bw) warn('벽 붙임 판 폭(${_f(wpw)})이 기둥 폭(${_f(bw)})보다 좁습니다.');
        final ph = <Offset>[
          if (i.wall.holes == 4) ...[
            Offset(e, e),
            Offset(wpw - e, e),
            Offset(e, hp - e),
            Offset(wpw - e, hp - e),
          ] else if (i.wall.holes == 2) ...[
            Offset(e, hp / 2),
            Offset(wpw - e, hp / 2),
          ],
        ];
        final fx0 = (wpw - bw) / 2, fx1 = (wpw + bw) / 2;
        final fy0 = j == BracketJoint.miter ? 0.0 : postTop;
        final rr = i.wall.dia / 2;
        if (ph.isNotEmpty) {
          if (e < rr) warn('벽 붙임 판 홀이 판 가장자리를 뚫습니다. 가장자리 거리를 늘리십시오.');
          final hit = ph.any(
            (q) =>
                q.dx + rr > fx0 &&
                q.dx - rr < fx1 &&
                q.dy + rr > fy0 &&
                q.dy - rr < b,
          );
          if (hit) {
            warn('벽 붙임 판 홀이 기둥 자리와 겹칩니다. 판 폭을 키우거나 가장자리 거리를 줄이십시오.');
          }
          for (final q in ph) {
            // 옆에서 보면 판에 숨은 구멍
            for (final s in [-rr, rr]) {
              lines.add(
                BracketLine(
                  Offset(0, q.dy + s),
                  Offset(tpl, q.dy + s),
                  BracketLineStyle.hidden,
                ),
              );
            }
          }
        }
        present.add('plate');
        plateOut = BracketPlate(
          name: '벽 붙임 판',
          w: wpw,
          l: hp,
          t: tpl,
          qty: 1,
          holes: ph,
          holeDia: i.wall.dia,
          footprint: [_rect(fx0, fy0, fx1, math.min(b, hp))],
          kgEach: wpw * hp * tpl * kSteelKgPerMm3,
          wall: true,
        );
        welds.add(
          BracketWeld(
            Offset(px, (fy0 + b) * 0.62),
            const Offset(1, 0.5),
            weldOf([mainP], tpl),
            '기둥–벽 판',
          ),
        );
        // 벽 쪽에서 본 판: 그림 오른쪽
        final ox = a + 110, oy = 0.0;
        polys.add(
          BracketPoly(_rect(ox, oy, ox + wpw, oy + hp), BracketFill.plate),
        );
        for (final (s, e2) in [
          (Offset(ox + fx0, oy + fy0), Offset(ox + fx1, oy + fy0)),
          (Offset(ox + fx1, oy + fy0), Offset(ox + fx1, oy + math.min(b, hp))),
          (
            Offset(ox + fx1, oy + math.min(b, hp)),
            Offset(ox + fx0, oy + math.min(b, hp)),
          ),
          (Offset(ox + fx0, oy + math.min(b, hp)), Offset(ox + fx0, oy + fy0)),
        ]) {
          lines.add(BracketLine(s, e2, BracketLineStyle.hidden));
        }
        for (final q in ph) {
          holeMarks.add(BracketHoleMark(Offset(ox, oy) + q, i.wall.dia));
        }
        dims.add(
          BracketDim(Offset(ox, oy), Offset(ox + wpw, oy), -22, _f(wpw)),
        );
        dims.add(
          BracketDim(
            Offset(ox + wpw, oy),
            Offset(ox + wpw, oy + hp),
            22,
            _f(hp),
            vertical: true,
          ),
        );
        if (ph.length >= 2) {
          final xs = ph.map((q) => q.dx).toSet().toList()..sort();
          if (xs.length >= 2) {
            dims.add(
              BracketDim(
                Offset(ox + xs.first, oy + hp),
                Offset(ox + xs.last, oy + hp),
                22,
                _f(xs.last - xs.first),
              ),
            );
          }
          final ys = ph.map((q) => q.dy).toSet().toList()..sort();
          if (ys.length >= 2) {
            dims.add(
              BracketDim(
                Offset(ox, oy + ys.first),
                Offset(ox, oy + ys.last),
                -22,
                _f(ys.last - ys.first),
                vertical: true,
              ),
            );
          }
        }
        labels.add(
          BracketLabel(
            Offset(ox + wpw / 2, oy + hp),
            '벽 붙임 판(벽 쪽에서 봄)',
            minor: true,
            shift: const Offset(0, 58),
          ),
        );
      }
      // 풍선·단면
      balloons.add((
        post.at(post.nearLength * 0.82, dp),
        'post',
        const Offset(1, 0.3),
      ));
      balloons.add((
        arm.at(arm.nearLength * 0.12, da),
        'arm',
        const Offset(0.2, 1),
      ));
      sections.add(('post', postV, '벽', true));
      sections.add(('arm', armV, '위', false));
      if (brace) {
        final br = members.where((m) => keyOf[m] == 'brace');
        if (br.isNotEmpty) {
          final m = br.first;
          balloons.add((
            m.at(m.length * 0.62, db),
            'brace',
            const Offset(1, 0.2),
          ));
        }
      }
      if (wp) {
        balloons.add((
          Offset(tpl / 2, b * 0.95),
          'plate',
          const Offset(-0.4, 1),
        ));
      }
    case BracketShape.frame:
    case BracketShape.tee:
      final w = i.a, h = i.b;
      final tp = i.basePlate ? i.base.t : 0.0;
      final frame = shape == BracketShape.frame;
      final hasArm = frame || w > 0;
      // T자는 가로대가 기둥 위에 얹힌다(기둥 통과·연귀는 없음).
      final j = frame ? jName : BracketJoint.armThrough;
      if (frame && w <= 2 * dp) warn('폭은 기둥 폭의 2배(${_f(2 * dp)}mm)보다 커야 합니다.');
      if (!frame && hasArm && w <= dp) {
        warn('가로대 길이는 기둥 폭(${_f(dp)}mm)보다 커야 합니다.');
      }
      if (frame && j == BracketJoint.vbend) vMerge = vbendOk();
      final miterF =
          frame && (j == BracketJoint.miter || j == BracketJoint.vbend);
      if (miterF && (dp - da).abs() > 0.05) {
        note(
          '기둥과 가로대 그림 폭이 달라(${_f(dp)} · ${_f(da)}) 연귀가 45°가 아닙니다. 끝 각도는 자를 것 표를 보십시오.',
        );
      }
      final topOfPost = hasArm && j == BracketJoint.armThrough ? da : 0.0;
      final postLen = h - tp - topOfPost;
      if (postLen <= 0) warn('높이가 너무 낮습니다(가로대·베이스 판 두께보다 커야 합니다).');
      final postXs = frame ? [0.0, w - dp] : [hasArm ? w / 2 - dp / 2 : 0.0];
      final wPost = weldOf([mainP, armP]);
      for (final x in postXs) {
        final left = x == 0 || !frame;
        final miter = miterF;
        final poly = miter
            ? (left
                  ? [
                      const Offset(0, 0),
                      Offset(dp, da),
                      Offset(dp, h - tp),
                      Offset(0, h - tp),
                    ]
                  : [
                      Offset(w, 0),
                      Offset(w, h - tp),
                      Offset(w - dp, h - tp),
                      Offset(w - dp, da),
                    ])
            : _rect(x, topOfPost, x + dp, h - tp);
        final m = member(
          key: 'post',
          name: '기둥',
          role: BracketRole.none,
          profile: mainP,
          orient: postO,
          view: postV,
          poly: poly,
          origin: left
              ? Offset(x, miter ? 0 : topOfPost)
              : Offset(x + dp, miter ? 0 : topOfPost),
          ex: const Offset(0, 1),
          ey: left ? const Offset(1, 0) : const Offset(-1, 0),
          endNames: ('위 끝', '아래 끝'),
          // 가로대가 위에 얹히면 기둥 바깥 변이 가로대 위 변 밑까지 올라가고 나머지는 따냄
          extStart: hasArm && j == BracketJoint.armThrough
              ? bracketNotchExt(armV, postV)
              : const [],
        );
        addMember('post', m);
      }
      var armStart = 0.0;
      BracketMember? armM;
      if (hasArm) {
        List<Offset> poly;
        if (frame && j == BracketJoint.postThrough) {
          armStart = dp;
          poly = _rect(dp, 0, w - dp, da);
          welds.add(
            BracketWeld(
              Offset(dp, da / 2),
              const Offset(1, 1),
              wPost,
              '가로대–기둥',
            ),
          );
          welds.add(
            BracketWeld(
              Offset(w - dp, da / 2),
              const Offset(-1, 1),
              wPost,
              '가로대–기둥',
              show: false,
            ),
          );
        } else if (miterF) {
          poly = [
            const Offset(0, 0),
            Offset(w, 0),
            Offset(w - dp, da),
            Offset(dp, da),
          ];
          welds.add(
            BracketWeld(
              Offset(dp / 2, da / 2),
              const Offset(1, 1),
              wPost,
              vMerge ? '꺾은 곳 V 이음' : '가로대–기둥',
              allAround: !vMerge,
              groove: vMerge,
            ),
          );
          welds.add(
            BracketWeld(
              Offset(w - dp / 2, da / 2),
              const Offset(-1, 1),
              wPost,
              vMerge ? '꺾은 곳 V 이음' : '가로대–기둥',
              allAround: !vMerge,
              groove: vMerge,
              show: false,
            ),
          );
        } else {
          poly = _rect(0, 0, w, da);
          for (final x in postXs) {
            final left = x == 0 || !frame;
            welds.add(
              BracketWeld(
                Offset(x + dp / 2, da),
                left ? const Offset(1, 1) : const Offset(-1, 1),
                wPost,
                '가로대–기둥',
                show: left,
              ),
            );
          }
        }
        final aHoles = armRow('가로대', armV, shift: armStart);
        armM = member(
          key: 'arm',
          name: '가로대',
          role: BracketRole.top,
          profile: armP,
          orient: armO,
          view: armV,
          poly: poly,
          origin: Offset(armStart, 0),
          ex: const Offset(1, 0),
          ey: const Offset(0, 1),
          holes: aHoles,
          endNames: ('왼쪽 끝', '오른쪽 끝'),
          extStart: frame && j == BracketJoint.postThrough
              ? bracketNotchExt(postV, armV)
              : const [],
          extEnd: frame && j == BracketJoint.postThrough
              ? bracketNotchExt(postV, armV)
              : const [],
        );
        addMember('arm', armM);
        if (!frame) {
          for (final hh in armM.holes) {
            final x = armM.at(hh.fromEnd, 0).dx;
            final x0 = postXs.first;
            if (x + hh.along / 2 > x0 - 1e-9 &&
                x - hh.along / 2 < x0 + dp + 1e-9) {
              warn('가로대 홀이 기둥 바로 위라 볼트가 기둥에 걸립니다. 홀을 기둥 밖으로 옮기십시오.');
              break;
            }
          }
        }
        for (final hh in aHoles) {
          final xb = hh.fromEnd + armStart;
          if (frame &&
              (xb - hh.along / 2 < dp - 1e-9 ||
                  xb + hh.along / 2 > w - dp + 1e-9)) {
            warn('가로대 홀이 기둥 자리에 걸립니다. 첫 홀·피치를 고치십시오.');
            break;
          }
        }
        dims.add(BracketDim(const Offset(0, 0), Offset(w, 0), -30, _f(w)));
      }
      // 2단: 기둥 사이 아래 가로대
      BracketMember? lowM;
      if (frame && i.lowerAt > 0) {
        final y2 = h - i.lowerAt;
        if (y2 < da + da || y2 + da > h - tp - 1e-9) {
          warn(
            '아래 가로대 높이는 바닥에서 ${_f(tp + da)}mm보다 높고 위 가로대보다 ${_f(da)}mm 이상 낮아야 합니다.',
          );
        } else {
          final lh = i.lowerHoles
              ? armRow('아래 가로대', armV, shift: dp)
              : const <PieceHole>[];
          final lp = _rect(dp, y2, w - dp, y2 + da);
          lowM = member(
            key: 'lower',
            name: '아래 가로대',
            role: BracketRole.top,
            profile: armP,
            orient: armO,
            view: armV,
            poly: lp,
            origin: Offset(dp, y2),
            ex: const Offset(1, 0),
            ey: const Offset(0, 1),
            holes: lh,
            endNames: ('왼쪽 끝', '오른쪽 끝'),
            extStart: bracketNotchExt(postV, armV),
            extEnd: bracketNotchExt(postV, armV),
          );
          addMember('lower', lowM);
          if (lh.any(
            (q) =>
                q.fromEnd - q.along / 2 < -1e-9 ||
                q.fromEnd + q.along / 2 > w - 2 * dp + 1e-9,
          )) {
            warn('아래 가로대 홀이 기둥 자리에 걸립니다. 첫 홀·피치를 고치십시오.');
          }
          welds.add(
            BracketWeld(
              Offset(dp, y2 + da / 2),
              const Offset(1, -1),
              wPost,
              '아래 가로대–기둥',
              show: false,
            ),
          );
          welds.add(
            BracketWeld(
              Offset(w - dp, y2 + da / 2),
              const Offset(-1, -1),
              wPost,
              '아래 가로대–기둥',
            ),
          );
          dims.add(
            BracketDim(
              Offset(0, y2),
              Offset(0, h),
              -30,
              _f(i.lowerAt),
              vertical: true,
            ),
          );
        }
      }
      // 높이: 위 왼쪽 모서리에서 맨 왼쪽 발(베이스 판이면 판 가장자리)까지 세로로.
      final footLeft = i.basePlate
          ? postXs.first + dp / 2 - i.base.w / 2
          : postXs.first;
      dims.add(
        BracketDim(
          const Offset(0, 0),
          Offset(math.min(0, footLeft), h),
          lowM != null ? -58 : -30,
          _f(h),
          vertical: true,
        ),
      );
      // 베이스 판: 기둥마다 하나. 앞에서 본 모양 + 오른쪽에 위에서 본 판(구멍 자리).
      if (i.basePlate) {
        final e = i.base.edge;
        final bp = postV.width;
        final ribsN = i.base.ribs;
        final pw = i.base.w > 0
            ? i.base.w
            : bracketAutoPlate(
                dp,
                edge: e,
                dia: i.base.dia,
                holes: i.base.holes,
                rib: ribsN > 0 ? i.base.ribL : 0,
              );
        final pl = i.base.l > 0
            ? i.base.l
            : bracketAutoPlate(
                bp,
                edge: e,
                dia: i.base.dia,
                holes: i.base.holes == 4 ? 4 : 0,
                rib: ribsN == 4 ? i.base.ribL : 0,
              );
        // 리브: 기둥 살이 있는 면에(앵글 열린 쪽은 세운 변 끝, 점검 26)
        final ribSpecs = <BracketRib>[
          if (ribsN > 0) ...[
            if (bracketMaterialCenter(postV, u: 0) case final z?)
              BracketRib(0, z, -1, 0),
            if (bracketMaterialCenter(postV, u: dp) case final z?)
              BracketRib(dp, z, 1, 0),
          ],
          if (ribsN == 4) ...[
            if (bracketMaterialCenter(postV, z: 0) case final u?)
              BracketRib(u, 0, 0, -1),
            if (bracketMaterialCenter(postV, z: bp) case final u?)
              BracketRib(u, bp, 0, 1),
          ],
        ];
        if (pw <= dp || pl <= bp) warn('베이스 판이 기둥보다 작습니다.');
        final ribs = i.base.ribs;
        final rh = i.base.ribH, rl = i.base.ribL, rt = i.base.ribT;
        if (ribs > 0) {
          if (rl > (pw - dp) / 2 + 1e-9 ||
              (ribs == 4 && rl > (pl - bp) / 2 + 1e-9)) {
            warn(
              '리브 길이가 판 밖으로 나옵니다. 리브 길이를 ${_f(math.min((pw - dp) / 2, ribs == 4 ? (pl - bp) / 2 : double.infinity))}mm 이하로 하십시오.',
            );
          }
          if (rh > postLen) warn('리브 높이가 기둥보다 높습니다.');
        }
        final wBase = weldOf([mainP], tp);
        for (final x in postXs) {
          final cx = x + dp / 2;
          polys.add(
            BracketPoly(
              _rect(cx - pw / 2, h - tp, cx + pw / 2, h),
              BracketFill.plate,
            ),
          );
          final left = x == 0 || !frame;
          welds.add(
            BracketWeld(
              Offset(left ? x + dp : x, h - tp),
              left ? const Offset(1, -0.35) : const Offset(-1, -0.35),
              wBase,
              '기둥–베이스 판',
              show: left,
            ),
          );
          // 리브(앞에서 본 모양): 그림 면 양옆은 삼각, 앞쪽(z = 0)은 얇은 띠, 뒤쪽은 기둥 뒤라 안 그림
          final outer = left ? x : x + dp, sgn = left ? 1.0 : -1.0;
          for (final rb in ribSpecs) {
            final rx = outer + sgn * rb.u;
            if (rb.du != 0) {
              polys.add(
                BracketPoly([
                  Offset(rx, h - tp),
                  Offset(rx + sgn * rb.du * rl, h - tp),
                  Offset(rx, h - tp - rh),
                ], BracketFill.plate),
              );
            } else if (rb.dz < 0) {
              polys.add(
                BracketPoly(
                  _rect(rx - rt / 2, h - tp - rh, rx + rt / 2, h - tp),
                  BracketFill.plate,
                ),
              );
            }
          }
          for (final rb in ribSpecs) {
            welds.add(
              BracketWeld(
                Offset(outer + sgn * rb.u, h - tp - rh * 0.5),
                const Offset(0.4, -1),
                weldOf([mainP], rt),
                '리브(양면)',
                allAround: false,
                show: false,
              ),
            );
          }
        }
        final ph = <Offset>[
          if (i.base.holes == 4) ...[
            Offset(e, e),
            Offset(pw - e, e),
            Offset(e, pl - e),
            Offset(pw - e, pl - e),
          ] else if (i.base.holes == 2) ...[
            Offset(e, pl / 2),
            Offset(pw - e, pl / 2),
          ],
        ];
        // 판 위 기둥 자리(단면 그대로)와 리브 자리
        final fx0 = (pw - dp) / 2, fz0 = (pl - bp) / 2;
        final foot = [
          for (final r in postV.rects)
            _rect(fx0 + r.left, fz0 + r.top, fx0 + r.right, fz0 + r.bottom),
        ];
        final ribFoot = <List<Offset>>[
          for (final rb in ribSpecs)
            if (rb.du != 0)
              _rect(
                fx0 + rb.u + math.min(0, rb.du * rl),
                fz0 + rb.z - rt / 2,
                fx0 + rb.u + math.max(0, rb.du * rl),
                fz0 + rb.z + rt / 2,
              )
            else
              _rect(
                fx0 + rb.u - rt / 2,
                fz0 + rb.z + math.min(0, rb.dz * rl),
                fx0 + rb.u + rt / 2,
                fz0 + rb.z + math.max(0, rb.dz * rl),
              ),
        ];
        final rr = i.base.dia / 2;
        if (ph.isNotEmpty) {
          if (e < rr) warn('베이스 판 홀이 판 가장자리를 뚫습니다. 가장자리 거리를 늘리십시오.');
          bool hits(List<Offset> r) {
            final x0 = r.map((q) => q.dx).reduce(math.min);
            final x1 = r.map((q) => q.dx).reduce(math.max);
            final y0 = r.map((q) => q.dy).reduce(math.min);
            final y1 = r.map((q) => q.dy).reduce(math.max);
            return ph.any(
              (q) =>
                  q.dx + rr > x0 &&
                  q.dx - rr < x1 &&
                  q.dy + rr > y0 &&
                  q.dy - rr < y1,
            );
          }

          if ([_rect(fx0, fz0, fx0 + dp, fz0 + bp)].any(hits)) {
            warn('베이스 판 홀이 기둥 자리와 겹칩니다. 판을 키우거나 가장자리 거리를 줄이십시오.');
          } else if (ribFoot.any(hits)) {
            warn('베이스 판 홀이 리브 자리와 겹칩니다. 리브를 짧게 하거나 홀 자리를 옮기십시오.');
          }
        }
        present.add('plate');
        if (ribs > 0) present.add('rib');
        plateOut = BracketPlate(
          name: '베이스 판',
          w: pw,
          l: pl,
          t: tp,
          qty: postXs.length,
          holes: ph,
          holeDia: i.base.dia,
          footprint: foot,
          ribs: ribFoot,
          kgEach: pw * pl * tp * kSteelKgPerMm3,
          ribSpecs: ribSpecs,
          ribH: rh,
          ribL: rl,
          ribT: rt,
        );
        // 위에서 본 판: 그림 오른쪽 아래, 앞모습(기둥·판)과 90mm 띄워서
        var maxX = 0.0;
        for (final m in members) {
          for (final q in m.poly) {
            maxX = math.max(maxX, q.dx);
          }
        }
        maxX = math.max(maxX, postXs.last + dp / 2 + pw / 2);
        final ox = maxX + 90, oy = h - pl;
        polys.add(
          BracketPoly(_rect(ox, oy, ox + pw, oy + pl), BracketFill.plate),
        );
        for (final r in foot) {
          polys.add(
            BracketPoly([
              for (final q in r) q + Offset(ox, oy),
            ], BracketFill.member),
          );
        }
        for (final r in ribFoot) {
          polys.add(
            BracketPoly([
              for (final q in r) q + Offset(ox, oy),
            ], BracketFill.member),
          );
        }
        for (final q in ph) {
          holeMarks.add(BracketHoleMark(Offset(ox, oy) + q, i.base.dia));
        }
        dims.add(
          BracketDim(Offset(ox, oy + pl), Offset(ox + pw, oy + pl), 22, _f(pw)),
        );
        dims.add(
          BracketDim(
            Offset(ox + pw, oy),
            Offset(ox + pw, oy + pl),
            22,
            _f(pl),
            vertical: true,
          ),
        );
        final xs = ph.map((q) => q.dx).toSet().toList()..sort();
        if (xs.length >= 2) {
          dims.add(
            BracketDim(
              Offset(ox + xs.first, oy),
              Offset(ox + xs.last, oy),
              -18,
              _f(xs.last - xs.first),
            ),
          );
        }
        final ys = ph.map((q) => q.dy).toSet().toList()..sort();
        if (ys.length >= 2) {
          dims.add(
            BracketDim(
              Offset(ox, oy + ys.first),
              Offset(ox, oy + ys.last),
              -18,
              _f(ys.last - ys.first),
              vertical: true,
            ),
          );
        }
        labels.add(
          BracketLabel(
            Offset(ox + pw / 2, oy),
            '베이스 판(위에서 봄)',
            shift: const Offset(0, -40),
            minor: true,
          ),
        );
        // 판 풍선은 왼쪽 판 아래로, 리브 풍선은 오른쪽(마지막) 기둥 안쪽 리브에서 위 왼쪽으로
        balloons.add((
          Offset(postXs.first + dp / 2 - pw / 2 + 6, h),
          'plate',
          const Offset(-0.3, 1),
        ));
        if (ribs > 0) {
          final rx = frame
              ? postXs.last - rl * 0.3
              : postXs.last + dp + rl * 0.3;
          balloons.add((
            Offset(rx, h - tp - rh * 0.25),
            'rib',
            frame ? const Offset(-1, -0.5) : const Offset(1, -0.5),
          ));
          // 리브 용접 기호는 그림 면 안쪽 리브 하나에만(곳 수는 리브 수만큼, 점검 35)
          welds.add(
            BracketWeld(
              Offset(postXs.first + dp + rl * 0.5, h - tp - rh * 0.5),
              const Offset(0.4, -1),
              weldOf([mainP], rt),
              '리브(양면)',
              allAround: false,
            ),
          );
          welds.remove(welds.lastWhere((w) => w.what == '리브(양면)' && !w.show));
        }
      }
      final p0 = members.firstWhere((m) => keyOf[m] == 'post');
      // 기둥 풍선: 2단이면 두 가로대 사이, 아니면 가운데 조금 위
      final pY = lowM != null
          ? (da + (i.b - i.lowerAt)) / 2 - p0.origin.dy
          : p0.nearLength * 0.45;
      balloons.add((p0.at(pY, dp), 'post', const Offset(1, 0.25)));
      sections.add(('post', postV, '바깥', true));
      if (armM != null) {
        balloons.add((
          armM.at(armM.nearLength * 0.32, da),
          'arm',
          const Offset(0, 1),
        ));
        sections.add(('arm', armV, '위', false));
      }
      if (lowM != null) {
        balloons.add((
          lowM.at(lowM.nearLength * 0.68, 0),
          'lower',
          const Offset(0, -1),
        ));
      }
    case BracketShape.hanger:
      final w = i.a, h = i.b;
      final rodP = BracketProfile.parse(i.rodSpec);
      final rd = rodP.kind == BracketProfileKind.rod ? rodP.n[0] : 12.0;
      if (rodP.kind != BracketProfileKind.rod) {
        warn('전산볼트 규격 "${i.rodSpec}"을 읽지 못했습니다("전산볼트 M12"처럼).');
      }
      final e = i.rodEdge;
      if (w <= 2 * e + 2 * rd) {
        warn('가로대 길이는 볼트 자리 둘(끝에서 ${_f(e)}씩)보다 길어야 합니다.');
      }
      if (h <= 0) warn('천장에서 가로대까지 높이를 넣으십시오.');
      final hole = bracketRodHole(rd);
      final aHoles = armRow('가로대', armV);
      final rodHoles = <PieceHole>[
        for (final (k, x) in [(1, e), (2, w - e)])
          PieceHole('볼트 $k', x, hole, z: armV.gauge),
      ];
      if (!armV.canHole || armV.holesFront) {
        warn('가로대 위 면에 전산볼트 홀을 낼 수 없는 방향입니다(평철은 눕히십시오). 방향을 바꾸십시오.');
      }
      // 볼트가 지나는 깊이: 닫힌 관(각파이프)은 위아래 두 면을 관통(점검 25)
      final thru = armV.hollow ? da : armV.attachT;
      if (armV.hollow) {
        note('각파이프 가로대는 전산볼트 홀을 위아래 두 면에 같이 뚫습니다(너트는 아래 면 밑).');
      }
      final armM = member(
        key: 'arm',
        name: '가로대',
        role: BracketRole.top,
        profile: armP,
        orient: armO,
        view: armV,
        poly: _rect(0, h, w, h + da),
        origin: Offset(0, h),
        ex: const Offset(1, 0),
        ey: const Offset(0, 1),
        holes: [...rodHoles, ...aHoles],
        endNames: ('왼쪽 끝', '오른쪽 끝'),
      );
      addMember('arm', armM);
      for (final hh in aHoles) {
        if (rodHoles.any(
          (r) => (r.fromEnd - hh.fromEnd).abs() < (r.dia + hh.along) / 2,
        )) {
          warn('가로대 홀이 전산볼트 홀과 겹칩니다. 홀 자리를 옮기십시오.');
          break;
        }
      }
      final rodLen = i.rodTop + h + thru + i.rodBelow;
      final rodV = rodP.view(0, BracketRole.none);
      for (final x in [e, w - e]) {
        final rm = member(
          key: 'rod',
          name: '전산볼트',
          role: BracketRole.none,
          profile: rodP,
          orient: 0,
          view: rodV,
          poly: _rect(x - rd / 2, -i.rodTop, x + rd / 2, h + thru + i.rodBelow),
          origin: Offset(x - rd / 2, -i.rodTop),
          ex: const Offset(0, 1),
          ey: const Offset(1, 0),
          endNames: ('위 끝', '아래 끝'),
        );
        addMember('rod', rm);
        // 너트·와셔: 가로대 붙는 면 위아래
        final nh = 0.8 * rd, nw = 1.8 * rd;
        polys.add(
          BracketPoly(
            _rect(x - nw / 2, h - nh - 2, x + nw / 2, h - 2),
            BracketFill.nut,
          ),
        );
        polys.add(
          BracketPoly(
            _rect(x - nw * 0.6, h - 2, x + nw * 0.6, h),
            BracketFill.nut,
          ),
        );
        final yb = h + thru;
        polys.add(
          BracketPoly(
            _rect(x - nw * 0.6, yb, x + nw * 0.6, yb + 2),
            BracketFill.nut,
          ),
        );
        polys.add(
          BracketPoly(
            _rect(x - nw / 2, yb + 2, x + nw / 2, yb + 2 + nh),
            BracketFill.nut,
          ),
        );
        // 천장 속(물림) 부분은 숨은선
        lines.add(
          BracketLine(
            Offset(x - rd / 2, 0),
            Offset(x - rd / 2, -i.rodTop),
            BracketLineStyle.hidden,
          ),
        );
        lines.add(
          BracketLine(
            Offset(x + rd / 2, 0),
            Offset(x + rd / 2, -i.rodTop),
            BracketLineStyle.hidden,
          ),
        );
      }
      // 천장
      polys.add(
        BracketPoly(_rect(-30, -i.rodTop - 14, w + 30, 0), BracketFill.ceiling),
      );
      final yLow = math.max(h + da, h + thru + i.rodBelow + 0.8 * rd + 2);
      dims.add(BracketDim(Offset(0, yLow), Offset(w, yLow), 30, _f(w)));
      dims.add(
        BracketDim(
          Offset(e, yLow),
          Offset(w - e, yLow),
          58,
          '볼트 ${_f(w - 2 * e)}',
        ),
      );
      dims.add(
        BracketDim(
          const Offset(0, 0),
          Offset(0, h),
          -30,
          _f(h),
          vertical: true,
        ),
      );
      dims.add(
        BracketDim(
          Offset(w - e, -i.rodTop),
          Offset(w - e, h + armV.attachT + i.rodBelow),
          46,
          '볼트 ${_f(rodLen)}',
          vertical: true,
        ),
      );
      labels.add(
        BracketLabel(
          Offset(w / 2, -i.rodTop - 14),
          '천장',
          shift: const Offset(0, -12),
        ),
      );
      balloons.add((armM.at(w * 0.5, 0), 'arm', const Offset(0, -1)));
      final r0 = members.firstWhere((m) => keyOf[m] == 'rod');
      balloons.add((r0.at(rodLen * 0.4, rd), 'rod', const Offset(1, 0)));
      sections.add(('arm', armV, '위', false));
  }

  // 품번 매기기
  final marked = <BracketMember>[
    for (final m in members)
      BracketMember(
        mark: markOf(keyOf[m]!),
        name: m.name,
        role: m.role,
        profile: m.profile,
        orient: m.orient,
        view: m.view,
        origin: m.origin,
        ex: m.ex,
        ey: m.ey,
        local: m.local,
        holes: m.holes,
        endNames: m.endNames,
        extStart: m.extStart,
        extEnd: m.extEnd,
      ),
  ];
  final plateMark = present.contains('plate') ? markOf('plate') : 0;
  final ribMark = present.contains('rib') ? markOf('rib') : 0;

  // 부재 그림: 모양·길이 방향 선·숨은 구멍(붙는 면)·보이는 구멍(평철 세움)
  for (final m in marked) {
    final round = m.view.round;
    polys.add(
      BracketPoly(m.poly, round ? BracketFill.rod : BracketFill.member),
    );
    if (round) {
      lines.add(
        BracketLine(
          m.at(-3, m.depth / 2),
          m.at(m.length + 3, m.depth / 2),
          BracketLineStyle.center,
        ),
      );
      continue;
    }
    // 따내기 혀(상대 부재 세운 변 뒤라 숨은선)
    for (final (es, start) in [(m.extStart, true), (m.extEnd, false)]) {
      if (es.isEmpty) continue;
      final ext = start ? m.extStartMax : m.extEndMax;
      final (b0, b1) = m.baseNear;
      final x0 = start ? b0 : b1, x1 = start ? b0 - ext : b1 + ext;
      final (ua, ub) = m.extU(es);
      for (final (p, q) in [
        (Offset(x0, ua), Offset(x1, ua)),
        (Offset(x1, ua), Offset(x1, ub)),
        (Offset(x1, ub), Offset(x0, ub)),
      ]) {
        lines.add(
          BracketLine(
            m.at(p.dx, p.dy),
            m.at(q.dx, q.dy),
            BracketLineStyle.hidden,
          ),
        );
      }
    }
    for (final u in m.view.lines) {
      final s = bracketSpanAt(m.local, u);
      if (s == null) continue;
      lines.add(
        BracketLine(
          m.at(s.$1, u),
          m.at(s.$2, u),
          m.view.hollow ? BracketLineStyle.hidden : BracketLineStyle.solid,
        ),
      );
    }
    final seen = <double>{};
    for (final h in m.holes) {
      if (m.view.holesFront) {
        holeMarks.add(
          BracketHoleMark(m.at(h.fromEnd, h.z), h.dia, slot: h.slot, dir: m.ex),
        );
        continue;
      }
      if (!seen.add(h.fromEnd)) continue;
      final t = m.view.attachT;
      final half = h.along / 2;
      for (final s in [-half, half]) {
        lines.add(
          BracketLine(
            m.at(h.fromEnd + s, 0),
            m.at(h.fromEnd + s, t),
            BracketLineStyle.hidden,
          ),
        );
      }
      final ext = math.max(2.0, t * 0.6);
      lines.add(
        BracketLine(
          m.at(h.fromEnd, -ext),
          m.at(h.fromEnd, t + ext),
          BracketLineStyle.center,
        ),
      );
    }
  }
  // 가로대 위 관(관 자리일 때): 관 단면 원, U볼트 가운데 선(관을 감싸고 가로대를 지나 아래 너트까지), 관 이름
  if (i.pipes.isNotEmpty) {
    final armM = marked.where((m) => m.name == '가로대').firstOrNull;
    if (armM != null && !armM.view.holesFront) {
      final t = armM.view.attachT;
      final up = -armM.ey;
      final ats = <double>[];
      for (final h in armM.holes) {
        final at = h.pipeAt;
        if (at != null && !ats.any((x) => (x - at).abs() < 1e-6)) ats.add(at);
      }
      var top = double.infinity;
      for (var k = 0; k < ats.length && k < i.pipes.length; k++) {
        final p = i.pipes[k];
        final r = p.od / 2, rr = p.spacing / 2;
        final c = armM.at(ats[k], 0) + up * r;
        polys.add(
          BracketPoly([
            for (var j = 0; j < 36; j++)
              c +
                  armM.ex * (r * math.cos(j * math.pi / 18)) +
                  up * (r * math.sin(j * math.pi / 18)),
          ], BracketFill.pipe),
        );
        // U볼트: 위 반원(다리 중심 간격) + 다리 둘
        final arc = [
          for (var j = 0; j <= 18; j++)
            c +
                armM.ex * (rr * math.cos(j * math.pi / 18)) +
                up * (rr * math.sin(j * math.pi / 18)),
        ];
        for (var j = 0; j + 1 < arc.length; j++) {
          lines.add(BracketLine(arc[j], arc[j + 1], BracketLineStyle.solid));
        }
        final nh = p.thread * 0.8, nw = p.thread * 1.7;
        for (final sx in [-rr, rr]) {
          final x = ats[k] + sx;
          lines.add(
            BracketLine(
              c + armM.ex * sx,
              armM.at(x, t + nh + p.thread * 0.6),
              BracketLineStyle.solid,
            ),
          );
          polys.add(
            BracketPoly([
              armM.at(x - nw / 2, t),
              armM.at(x + nw / 2, t),
              armM.at(x + nw / 2, t + nh),
              armM.at(x - nw / 2, t + nh),
            ], BracketFill.nut),
          );
        }
        final tp = c + up * rr;
        top = math.min(top, tp.dy);
        labels.add(
          BracketLabel(tp, p.name, shift: const Offset(0, -9), minor: true),
        );
      }
      // 가로대 품번 풍선이 관·U볼트 자리에 걸리면 가로대 위 가장 넓은 빈 자리로
      final busy = <(double, double)>[
        for (var k = 0; k < ats.length && k < i.pipes.length; k++)
          (
            ats[k] - i.pipes[k].spacing / 2 - i.pipes[k].thread,
            ats[k] + i.pipes[k].spacing / 2 + i.pipes[k].thread,
          ),
        // 매달기 전산볼트 자리
        for (final h in armM.holes)
          if (h.label.startsWith('볼트')) (h.fromEnd - 20, h.fromEnd + 20),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      for (var k = 0; k < balloons.length; k++) {
        final (at, key, dir) = balloons[k];
        if (key != 'arm') continue;
        final x = _dot(at - armM.origin, armM.ex);
        if (!busy.any((b) => x > b.$1 - 1e-9 && x < b.$2 + 1e-9)) continue;
        final (s0, s1) = armM.nearSpan;
        var best = (s0, s0);
        var cur = s0;
        for (final b in [...busy, (s1, s1)]) {
          if (b.$1 - cur > best.$2 - best.$1) best = (cur, b.$1);
          cur = math.max(cur, b.$2);
        }
        if (best.$2 - best.$1 > 1) {
          balloons[k] = (armM.at((best.$1 + best.$2) / 2, 0), key, dir);
        }
      }
      // 위 치수가 관을 지나가지 않게 관 꼭대기 위로
      if (top.isFinite) {
        for (var k = 0; k < dims.length; k++) {
          final d = dims[k];
          if (d.vertical || d.offset >= 0 || d.base != null) continue;
          if (math.max(d.a.dy, d.b.dy) <= top) continue;
          dims[k] = BracketDim(d.a, d.b, d.offset, d.text, base: top);
        }
      }
    }
  }
  // 풍선·단면 품번 채우기
  final fixedBalloons = <BracketBalloon>[];
  final usedMarks = <int>{};
  for (final (at, key, dir) in balloons) {
    if (!present.contains(key)) continue;
    final mk = markOf(key);
    if (!usedMarks.add(mk)) continue;
    fixedBalloons.add(BracketBalloon(at, mk, dir));
  }
  final secs = <BracketSectionMark>[];
  for (final (key, view, side, vertical) in sections) {
    if (!present.contains(key)) continue;
    final mk = markOf(key);
    if (secs.any((x) => x.mark == mk)) continue;
    secs.add(BracketSectionMark(mk, view, side, vertical: vertical));
  }

  /// V컷 꺾기 한 토막: 펼친 길이 = 바깥 치수 합 − 꺾는 곳마다 공제값, 세운 변에 90° V 따내기.
  BracketPiece vPiece(int mk, List<BracketMember> ms) {
    final t = postV.attachT, dd = postV.depth;
    final bd = i.vBend > 0 ? i.vBend : 2 * t;
    final armMm = ms.firstWhere((m) => m.name == '가로대');
    final posts = ms.where((m) => m.name == '기둥').toList();
    final hs = <PieceHole>[];
    double total;
    List<double> apex;
    (String, String) names;
    if (lLike) {
      final px = i.wallPlate ? i.wall.t : 0.0;
      final la = i.a - px;
      total = la + i.b - bd;
      apex = [la - bd / 2];
      names = ('가로대 끝', '기둥 아래 끝');
      hs.addAll(armMm.holes);
      for (final h in posts.first.holes) {
        hs.add(h.moved(la - bd));
      }
    } else {
      final hp = i.b - (i.basePlate ? i.base.t : 0);
      total = 2 * hp + i.a - 2 * bd;
      apex = [hp - bd / 2, hp + i.a - 1.5 * bd];
      names = ('왼쪽 기둥 아래 끝', '오른쪽 기둥 아래 끝');
      for (final h in armMm.holes) {
        hs.add(h.moved(hp - bd));
      }
    }
    final v = dd - t;
    final outline = <Offset>[
      Offset.zero,
      Offset(total, 0),
      Offset(total, dd),
      for (final ap in apex.reversed) ...[
        Offset(ap + v, dd),
        Offset(ap, t),
        Offset(ap - v, dd),
      ],
      Offset(0, dd),
    ];
    final dev = BracketMember(
      mark: mk,
      name: lLike ? '기둥·가로대' : '기둥·가로대·기둥',
      role: lLike ? BracketRole.wall : BracketRole.none,
      profile: mainP,
      orient: postO,
      view: postV,
      origin: Offset.zero,
      ex: const Offset(1, 0),
      ey: const Offset(0, 1),
      local: outline,
      holes: hs,
      endNames: names,
    );
    checkHoles(dev, dev.name);
    for (final h in hs) {
      if (apex.any((ap) => (h.fromEnd - ap).abs() < h.along / 2 + bd / 2 + t)) {
        note(
          '${dev.name} ${h.label}이 꺾는 곳에 가깝습니다(꺾을 때 홀이 찌그러질 수 있음). 홀을 옮기십시오.',
        );
        break;
      }
    }
    final kgM = mainP.kgPerM;
    return BracketPiece(
      mark: mk,
      name: dev.name,
      kind: BracketPieceKind.member,
      spec: mainP.label,
      ks: mainP.ks,
      length: total,
      qty: 1,
      ends:
          '양 끝 직각 · V컷 ${apex.length}곳(세운 변 90° V, 깊이 ${_f(v)}) · 꺾는 곳마다 공제 ${_f(bd)}',
      holes: hs,
      holeFrom: names.$1,
      holeFace: lLike ? '바깥 변(벽·위)' : '바깥 변',
      kgEach: kgM == null ? 0 : kgM * total / 1000,
      member: dev,
      vNotches: apex,
    );
  }

  // 토막
  final pieces = <BracketPiece>[];
  final byMark = <int, List<BracketMember>>{};
  for (final m in marked) {
    byMark.putIfAbsent(m.mark, () => []).add(m);
  }
  var unknownKg = false;
  final vMark = vMerge ? markOf('post') : -1;
  for (final mk in byMark.keys.toList()..sort()) {
    final ms = byMark[mk]!;
    if (mk == vMark) {
      pieces.add(vPiece(mk, ms));
      continue;
    }
    final m = ms.first;
    final near = m.nearLength, far = m.farLength;
    final long = math.max(near, far);
    // 비스듬한 끝일 때만 짧은 쪽(따내기 혀 길이 차이는 끝 모양 글에)
    final angled = m.endAngle(true) > 0.05 || m.endAngle(false) > 0.05;
    final short = angled ? math.min(near, far) : long;
    final kgM = m.profile.kgPerM;
    if (kgM == null) unknownKg = true;
    final rod = m.profile.kind == BracketProfileKind.rod;
    if (!rod) checkHoles(m, m.name);
    final a0 = m.endAngle(true), a1 = m.endAngle(false);
    String endText;
    if (rod) {
      endText = '양 끝 직각(전체 나사)';
    } else if (a0 < 0.05 && a1 < 0.05) {
      endText = '양 끝 직각';
    } else {
      String one(String n, double a) => a < 0.05 ? '$n 직각' : '$n ${_f(a)}°';
      endText =
          '${one(m.endNames.$1, a0)} · ${one(m.endNames.$2, a1)} (각도절단기 직각 = 0°)';
    }
    final notch = [
      if (m.extStartMax > 0) '${m.endNames.$1} ${_f(m.extStartMax)} 따냄',
      if (m.extEndMax > 0) '${m.endNames.$2} ${_f(m.extEndMax)} 따냄',
    ];
    if (notch.isNotEmpty) endText += ' · ${notch.join(' · ')}(부재도)';
    pieces.add(
      BracketPiece(
        mark: mk,
        name: m.name,
        kind: rod ? BracketPieceKind.rod : BracketPieceKind.member,
        spec: m.profile.label,
        // 전산볼트는 이름이 이미 "전산볼트"라 규격만(점검 45)
        ks: rod ? 'M${_f(m.profile.n[0])}' : m.profile.ks,
        length: long,
        short: (long - short).abs() > 0.05 ? short : null,
        qty: ms.length,
        ends: endText,
        holes: m.holes,
        holeFrom: m.endNames.$1,
        holeFace: m.view.holesFront
            ? '넓은 면'
            : switch (m.role) {
                BracketRole.wall => '벽 붙는 면',
                BracketRole.top => '위 면',
                BracketRole.none => '붙는 면',
              },
        kgEach: kgM == null ? 0 : kgM * long / 1000,
        member: m,
      ),
    );
  }
  final pl = plateOut;
  if (pl != null) {
    pieces.add(
      BracketPiece(
        mark: plateMark,
        name: pl.name,
        kind: BracketPieceKind.plate,
        ks: plateKs(pl.t, pl.w, pl.l),
        length: pl.w,
        width: pl.l,
        thick: pl.t,
        qty: pl.qty,
        ends: '',
        holes: [
          for (final (k, q) in pl.holes.indexed)
            PieceHole('앵커 ${k + 1}', q.dx, pl.holeDia, z: q.dy),
        ],
        holeFrom: '판 왼쪽 위',
        holeFace: '판',
        kgEach: pl.kgEach,
      ),
    );
    if (ribMark > 0) {
      final rb = i.base;
      final n = rb.ribs * pl.qty;
      pieces.add(
        BracketPiece(
          mark: ribMark,
          name: '리브',
          kind: BracketPieceKind.rib,
          ks: 'PL-${_f(rb.ribT)}×${_f(rb.ribL)}×${_f(rb.ribH)} 삼각',
          length: rb.ribL,
          width: rb.ribH,
          thick: rb.ribT,
          qty: n,
          ends: '',
          kgEach: rb.ribL * rb.ribH / 2 * rb.ribT * kSteelKgPerMm3,
        ),
      );
    }
  }

  // 무게·구멍 수
  var kgSet = 0.0;
  for (final p in pieces) {
    kgSet += p.kgEach * p.qty;
  }
  final wallHoles = <double, int>{}, armHoles = <double, int>{};
  final anchorHoles = <double, int>{};
  for (final p in pieces) {
    if (p.kind == BracketPieceKind.plate) {
      final into = pl != null && pl.wall ? wallHoles : anchorHoles;
      for (final h in p.holes) {
        into[h.dia] = (into[h.dia] ?? 0) + p.qty * sets;
      }
      continue;
    }
    if (p.kind != BracketPieceKind.member) continue;
    // 이름표로 나눈다(V컷 한 토막은 기둥·가로대 구멍이 섞여 있다, 점검 22)
    for (final h in p.holes) {
      if (shape == BracketShape.hanger && h.label.startsWith('볼트')) continue;
      final into = h.label.startsWith('기둥') ? wallHoles : armHoles;
      into[h.dia] = (into[h.dia] ?? 0) + p.qty * sets;
    }
  }
  if (unknownKg) {
    note('모르는 규격이 있어 그 무게를 뺐습니다("앵글 50x50x5"처럼 적으면 계산합니다).');
  }
  if (i.weld > 0) {
    for (final m in byMark.values.map((l) => l.first)) {
      final t = m.profile.thickness;
      if (m.profile.known && t > 0 && t < 6 && i.weld > t + 1e-9) {
        note(
          '용접 각장 ${_f(i.weld)}이 ${m.name} 두께(${_f(t)})보다 큽니다. 6mm 안쪽 판은 보통 판 두께를 넘지 않게 합니다.',
        );
        break;
      }
    }
  }

  // 원자재: 규격마다 토막 길이 × 개수 × 세트(전산볼트·판은 빼고)
  final stock = <String, CuttingOptimizationResult>{};
  if (i.stockLength > 0) {
    final bySpec = <String, List<double>>{};
    for (final p in pieces) {
      if (p.kind != BracketPieceKind.member || p.length <= 0) continue;
      final l = bySpec.putIfAbsent(p.spec, () => []);
      for (var k = 0; k < p.qty * sets; k++) {
        l.add(p.length);
      }
    }
    for (final e in bySpec.entries) {
      final r = optimizeCutting(
        pieces: e.value,
        stockLength: i.stockLength,
        kerf: i.kerf,
      );
      stock[e.key] = r;
      if (r.oversizedPieces.isNotEmpty) {
        warn(
          '원자재 ${_f(i.stockLength)}mm보다 긴 토막이 있습니다(${e.key} ${r.oversizedPieces.map(_f).join(', ')}mm).',
        );
      }
    }
  }

  return BracketPlan(
    input: i,
    members: marked,
    pieces: pieces,
    plate: plateOut,
    drawing: BracketDrawing(
      polys: polys,
      lines: lines,
      holes: holeMarks,
      dims: dims,
      welds: welds,
      balloons: fixedBalloons,
      sections: secs,
      labels: labels,
    ),
    welds: welds,
    braceAngle: braceAngle,
    kgPerSet: kgSet,
    kgTotal: kgSet * sets,
    weightKnown: !unknownKg,
    wallHoles: wallHoles,
    armHoles: armHoles,
    anchorHoles: anchorHoles,
    stock: stock,
    notes: notes,
    problems: problems,
  );
}
