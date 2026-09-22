import 'dart:math' as math;
import 'dart:ui';

// 🚀 튜브 피팅을 "조각 목록"으로 적어 그린다. 카탈로그 표의 길이·육각을 그대로 옮기면
// 모양과 크기가 같이 나온다(피팅 종류마다 그림 함수를 따로 만들지 않는다).
//
// 곧은 것  "fs:조각,조각,…"  조각 = 종류:길이mm:높이mm (왼쪽부터)
//   n 너트 육각 · h 몸통 육각 · t 수나사 · s 관(스텁) · l 벌크헤드 잠금 너트
// 엘보·티 "fl:b=몸통mm;팔;팔…"  팔 = 방향=종류,가운데~끝mm,굵기mm
//   방향 r 오른쪽 · l 왼쪽 · d 아래 · u 위 · x 왼쪽 아래 45°
//   종류 n 튜브 끝(목+너트) · t 수나사 · f 암나사 몸통(육각)

/// 곧은 피팅 조각 하나.
class FitSeg {
  final String kind;
  final double len;
  final double h;
  const FitSeg(this.kind, this.len, this.h);
}

/// 엘보·티의 팔 하나.
class FitArm {
  final String dir;
  final String kind;
  final double len;
  final double thick;
  const FitArm(this.dir, this.kind, this.len, this.thick);
}

bool isFittingSpec(String shape) =>
    shape.startsWith('fs:') ||
    shape.startsWith('fl:') ||
    shape.startsWith('fv:');

List<FitSeg> parseStraight(String shape) => [
  for (final part in shape.substring(3).split(','))
    if (part.split(':').length == 3)
      FitSeg(
        part.split(':')[0],
        double.tryParse(part.split(':')[1]) ?? 0,
        double.tryParse(part.split(':')[2]) ?? 0,
      ),
];

/// (몸통 크기, 팔 목록)
(double, List<FitArm>) parseElbow(String shape) {
  double body = 10;
  final arms = <FitArm>[];
  for (final part in shape.substring(3).split(';')) {
    final kv = part.split('=');
    if (kv.length != 2) continue;
    if (kv[0] == 'b') {
      body = double.tryParse(kv[1]) ?? body;
      continue;
    }
    final v = kv[1].split(',');
    if (v.length != 3) continue;
    arms.add(
      FitArm(
        kv[0],
        v[0],
        double.tryParse(v[1]) ?? 0,
        double.tryParse(v[2]) ?? 0,
      ),
    );
  }
  return (body, arms);
}

/// 엘보·티가 차지하는 칸(가운데 기준). left·top은 음수.
Rect elbowBounds(double body, List<FitArm> arms) {
  double l = -body / 2, r = body / 2, t = -body / 2, b = body / 2;
  for (final a in arms) {
    final double half = a.thick / 2;
    switch (a.dir) {
      case 'r':
        r = math.max(r, a.len);
        t = math.min(t, -half);
        b = math.max(b, half);
      case 'l':
        l = math.min(l, -a.len);
        t = math.min(t, -half);
        b = math.max(b, half);
      case 'd':
        b = math.max(b, a.len);
        l = math.min(l, -half);
        r = math.max(r, half);
      case 'u':
        t = math.min(t, -a.len);
        l = math.min(l, -half);
        r = math.max(r, half);
      case 'x':
        final double d = a.len * math.sqrt1_2 + half * math.sqrt1_2;
        l = math.min(l, -d);
        b = math.max(b, d);
    }
  }
  return Rect.fromLTRB(l, t, r, b);
}

/// 조각 목록으로 적은 피팅의 가로×세로(mm). 조각 목록이 아니면 null.
Size? fittingSpecSize(String shape) {
  if (shape.startsWith('fv:')) return valveSpecSize(shape);
  if (shape.startsWith('fs:')) {
    final segs = parseStraight(shape);
    if (segs.isEmpty) return null;
    return Size(
      segs.fold<double>(0, (s, e) => s + e.len),
      segs.map((e) => e.h).reduce(math.max),
    );
  }
  if (shape.startsWith('fl:')) {
    final (body, arms) = parseElbow(shape);
    return elbowBounds(body, arms).size;
  }
  return null;
}

// 밸브 "fv:종류;L=…;top=…;bot=…;end=n|f|m;bar=…;reach=…;pipe=…;out=…"
//   종류 needle(니들)·gb(유니언 보닛 니들)·toggle(토글)·ball(레버 볼)·wing(날개 손잡이 볼·플러그)·relief
//   L 끝~끝(릴리프는 입구 축~출구 끝), top 관 가운데~손잡이 꼭대기, bot 관 가운데~몸통 밑,
//   bar T 손잡이 길이, reach 손잡이가 축에서 옆으로 뻗은 길이, pipe 끝 너트·육각 굵기, out 출구 높이
Map<String, String> parseValve(String shape) {
  final out = <String, String>{};
  final parts = shape.substring(3).split(';');
  out['kind'] = parts.first;
  for (final p in parts.skip(1)) {
    final kv = p.split('=');
    if (kv.length == 2) out[kv[0]] = kv[1];
  }
  return out;
}

double valveNum(Map<String, String> v, String k, [double d = 0]) =>
    double.tryParse(v[k] ?? '') ?? d;

Size? valveSpecSize(String shape) {
  if (!shape.startsWith('fv:')) return null;
  final v = parseValve(shape);
  final double l = valveNum(v, 'L'), top = valveNum(v, 'top');
  final double bot = valveNum(v, 'bot', 10);
  switch (v['kind']) {
    case 'ball':
    case 'wing':
      return Size(math.max(l, l / 2 + valveNum(v, 'reach')), top + bot);
    case 'relief':
      return Size(l + bot, top);
    default:
      return Size(math.max(l, valveNum(v, 'bar')), top + bot);
  }
}
