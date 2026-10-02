// 케이블 트레이 형상 계산기(10-03): 바닥 구조물을 넘어가거나 단을 오르내릴 때
// 트레이를 현장에서 잘라 꺾는 자리(V컷 마킹)와 길이를 계산한다. 화면 없이 계산만 한다.
//
// 모양은 트레이 바닥면 선(가로대 쪽 측판 아랫변)으로 본다. 장애물을 마주 보는 쪽이 늘 이 선이다.
//  · 위로 꺾기(안쪽이 트레이 위): 측판 윗변에 V컷, 아랫변은 남겨 접는다(접는 곳 = 마킹).
//  · 아래로 꺾기(안쪽이 트레이 바닥): 측판 아랫변에 V컷, 윗변은 남겨 접는다.
//  · V컷 폭 = 2 × 측판 높이 × tan(꺾는 각 ÷ 2). 꺾은 뒤 V 양쪽 면이 맞닿는다.
//  · 마킹은 자르기 전 곧은 트레이의 측판 아랫변을 따라 시작점에서 잰다.
//    위로 꺾기는 아랫변 길이가 그대로, 아래로 꺾기는 아랫변에서 V컷 폭만큼 줄어든다.
//  · 나눠 꺾기: 큰 각을 작은 각 여러 번으로(예: 90° = 30° 3번). 마디 간격 p, 한 번 각 δ이면
//    다각형에 내접하는 반경 R ≈ p ÷ (2 tan(δ/2)) — 케이블 최소 굽힘 반경과 견준다.
// 접는 곳의 플랜지 굽힘 반경과 판 두께는 무시한다(몇 mm 차이).
library;

import 'dart:math' as math;

/// 무엇을 하는지. 옆으로 비켜가기·옮겨가기는 위에서 본 모양으로 같은 계산을 한다:
/// 바닥면 선 → 장애물 쪽 측판, 측판 높이 → 트레이 폭(측판 사이), 위로 → 장애물 반대쪽으로.
enum TrayRouteKind { over, up, down, aside, shift }

String trayRouteKindLabel(TrayRouteKind k) => switch (k) {
  TrayRouteKind.over => '넘어가기',
  TrayRouteKind.up => '올라가기',
  TrayRouteKind.down => '내려가기',
  TrayRouteKind.aside => '옆으로 비켜가기',
  TrayRouteKind.shift => '옆으로 옮겨가기',
};

/// 옆으로(수평으로) 꺾는지.
bool trayRouteIsPlan(TrayRouteKind k) =>
    k == TrayRouteKind.aside || k == TrayRouteKind.shift;

/// 장애물을 지나 다시 제자리 줄로 돌아오는지(꺾는 곳 4무리).
bool trayRouteReturns(TrayRouteKind k) =>
    k == TrayRouteKind.over || k == TrayRouteKind.aside;

/// 꺾는 각도(°) 칩.
const List<double> kTrayRouteAngles = [30, 45, 60, 90];

/// 측판 높이(mm) 칩. 트레이 깊이와 같게 두는 것이 보통이다.
const List<double> kTrayRailHeights = [60, 75, 100, 150];

double _rad(double deg) => deg * math.pi / 180;

/// V컷 폭(mm): 측판 높이 [rail], 한 번에 꺾는 각 [deg].
double trayNotchWidth(double rail, double deg) =>
    2 * rail * math.tan(_rad(deg.abs()) / 2);

/// 나눠 꺾을 때 근사 반경(mm). 한 번에 꺾으면(마디 1) 0(날카로운 모서리).
double traySegmentRadius(double pitch, double deg, int pieces) {
  if (pieces <= 1 || pitch <= 0) return 0;
  final d = _rad(deg.abs() / pieces);
  return pitch / (2 * math.tan(d / 2));
}

/// 꺾는 곳 하나.
class TrayCorner {
  /// 바닥면 선 위 꺾는 점(mm). x = 진행 방향, y = 높이.
  final double x, y;

  /// 꺾는 각(°). + = 위로(측판 윗변 V컷), − = 아래로(측판 아랫변 V컷).
  final double turn;

  /// V컷 폭(mm, 잘린 변에서).
  final double notch;

  /// 자르기 전 측판 아랫변을 따라 시작점에서 잰 마킹(mm): V컷 가운데(= 접는 곳).
  final double mark;

  const TrayCorner({
    required this.x,
    required this.y,
    required this.turn,
    required this.notch,
    required this.mark,
  });

  bool get up => turn > 0;

  /// 아랫변 V컷이면 아랫변에서 [markFrom]~[markTo]를 따낸다. 윗변 V컷이면 윗변에서(아랫변은 [mark]에서 접음).
  double get markFrom => mark - notch / 2;
  double get markTo => mark + notch / 2;
}

/// 계산 결과.
class TrayRoute {
  final TrayRouteKind kind;
  final double rail;
  final double angle;
  final int pieces;
  final double pitch;

  /// 바닥면 선 꺾는 점(시작점·끝점 포함, 그리기용).
  final List<(double, double)> points;
  final List<TrayCorner> corners;

  /// 경사 구간 곧은 부분 길이(mm, 바닥면 선). 나눠 꺾으면 마디를 뺀 곧은 길이.
  final double leg;

  /// 올라가는(내려가는) 한쪽이 차지하는 수평 길이(mm).
  final double footprint;

  /// 넘어가기 윗면 길이(mm, 바닥면 선).
  final double top;

  /// 자르기 전 곧은 트레이 길이(mm, 측판 아랫변 기준).
  final double material;

  /// 첫 꺾는 점까지(mm).
  final double lead;

  /// 문제가 있으면 이유(계산은 그대로 둔다).
  final List<String> problems;

  const TrayRoute({
    required this.kind,
    required this.rail,
    required this.angle,
    required this.pieces,
    required this.pitch,
    required this.points,
    required this.corners,
    required this.leg,
    required this.footprint,
    required this.top,
    required this.material,
    required this.lead,
    required this.problems,
  });

  bool get ok => problems.isEmpty;

  /// 나눠 꺾은 근사 반경(mm). 한 번에 꺾으면 0.
  double get radius => traySegmentRadius(pitch, angle, pieces);

  /// 몇 m짜리 트레이가 몇 개 드는지(이음 여유 없이 길이만).
  int lengthsNeeded(double stock) =>
      stock <= 0 ? 0 : (material / stock - 1e-9).ceil().clamp(1, 1 << 20);
}

/// 트레이 경로 계산.
///  · [rise] 올라갈(내려갈) 높이(mm, 바닥면 기준). 넘어가기면 장애물 높이 + 위 여유 − 지금 트레이 바닥 높이.
///  · [obstacle] 넘어가기 장애물 길이(진행 방향, mm). [side] 장애물 앞뒤 여유(mm).
///  · [toFace] 시작점에서 장애물(단) 앞면까지(mm). 내려가기면 시작점에서 단 끝까지.
///  · [tail] 마지막 꺾는 점 뒤로 더 둘 곧은 길이(mm).
TrayRoute trayRoute({
  required TrayRouteKind kind,
  required double rise,
  required double angle,
  required double rail,
  double obstacle = 0,
  double side = 0,
  double toFace = 0,
  double tail = 0,
  int pieces = 1,
  double pitch = 0,
}) {
  final problems = <String>[];
  final n = pieces < 1 ? 1 : pieces;
  final p = n == 1 ? 0.0 : pitch;
  final th = _rad(angle);
  final d = th / n;
  // 한 무리(0 → θ)에 들어가는 마디(각 kδ, k = 1..n−1)의 높이·수평 길이
  var sRise = 0.0, sRun = 0.0;
  for (var k = 1; k < n; k++) {
    sRise += p * math.sin(k * d);
    sRun += p * math.cos(k * d);
  }
  var leg = (rise - 2 * sRise) / math.sin(th);
  final plan = trayRouteIsPlan(kind);
  if (rise <= 0) problems.add(plan ? '옮길 거리가 0입니다.' : '높이가 0입니다.');
  if (leg < -1e-6) {
    problems.add(
      '${plan ? '옮길 거리가 짧아' : '높이가 낮아'} 이 각도·마디 간격으로는 못 꺾습니다. 각도를 줄이거나 마디 간격을 줄이십시오.',
    );
    leg = 0;
  }
  final foot = 2 * sRun + leg * math.cos(th);
  final top = trayRouteReturns(kind) ? obstacle + 2 * side : 0.0;
  // 첫 꺾는 점: 올라가기·넘어가기는 장애물 앞면 − 여유 − 올라가는 수평 길이, 내려가기는 단 끝 + 여유
  final lead = kind == TrayRouteKind.down
      ? toFace + side
      : toFace - side - foot;
  if (lead < -1e-6) {
    problems.add(
      '시작점이 장애물에 너무 가깝습니다. 시작점을 ${(-lead).ceil()}mm 더 앞으로 잡거나 각도를 키우십시오.',
    );
  }
  final a = math.max(0.0, lead);

  // 바닥면 선을 따라 걷는다: (길이, 다음 꺾는 각)
  final steps = <(double, double)>[];
  void group(double sign) {
    // 0 → θ 한 무리: 마디 n번, 사이 마디 길이 p
    for (var k = 0; k < n; k++) {
      steps.add((k == 0 ? 0 : p, sign * angle / n));
    }
  }

  final first = kind == TrayRouteKind.down ? -1.0 : 1.0;
  steps.add((a, 0));
  group(first);
  steps.add((leg, 0));
  group(-first);
  if (trayRouteReturns(kind)) {
    steps.add((top, 0));
    group(-1);
    steps.add((leg, 0));
    group(1);
  }
  steps.add((tail, 0));

  final points = <(double, double)>[(0, 0)];
  final corners = <TrayCorner>[];
  var x = 0.0, y = 0.0, dir = 0.0, mark = 0.0;
  for (final (len, turn) in steps) {
    if (len > 0) {
      x += len * math.cos(dir);
      y += len * math.sin(dir);
      mark += len;
    }
    if (turn != 0) {
      final w = trayNotchWidth(rail, turn);
      // 아래로 꺾기는 아랫변에서 V가 빠지니 마킹(V 가운데)은 반 폭 뒤, 다음 길이는 한 폭 뒤부터
      final center = turn < 0 ? mark + w / 2 : mark;
      corners.add(TrayCorner(x: x, y: y, turn: turn, notch: w, mark: center));
      if (turn < 0) mark += w;
      dir += _rad(turn);
      if (points.last.$1 != x || points.last.$2 != y) points.add((x, y));
    }
  }
  if (points.last.$1 != x || points.last.$2 != y) points.add((x, y));
  return TrayRoute(
    kind: kind,
    rail: rail,
    angle: angle,
    pieces: n,
    pitch: p,
    points: points,
    corners: corners,
    leg: leg,
    footprint: foot,
    top: top,
    material: mark,
    lead: a,
    problems: problems,
  );
}

/// 트레이 한 개 길이(mm) 칩.
const List<double> kTrayStockLengths = [3000, 6000];

/// 현장에서 잘라 꺾을 때 작업 순서(개조식).
const List<String> kTrayFieldBendNotes = [
  '양쪽 측판에 같은 자리로 마킹. 직각자로 윗변·아랫변까지 선을 내릴 것',
  'V컷 범위에 가로대·타공 구멍이 걸리는지 확인. 걸리면 시작점을 옮겨 다시 계산',
  '접는 쪽 테두리는 자르지 말 것',
  '맞닿은 V면은 연결판·볼트로 체결. 볼트는 안에서 밖으로, 너트는 바깥',
  '용접·열가공 피할 것(SMCS·KRCCS, LH 시방서는 금지)',
  '절단면 날 제거, 아연 도료로 보수(맨살보다 13~25mm 넓게)',
  '꺾은 곳 양쪽 접지 본딩 점퍼(접지띠)',
  '아래로 꺾은 곳(장애물 위 모서리)에서 케이블 눌림. 굵은 케이블은 나눠 꺾거나 수직 엘보 OUT 사용',
  '시방서 원칙은 방향 전환에 기성 엘보 사용. 현장 꺾기는 감독 승인 후',
  '마킹 값은 판 두께·플랜지 굽힘 무시(몇 mm 차이). 첫 작업은 토막으로 맞춰 볼 것',
  '자르지 않고 라이저 커넥터(수직 가변 이음판)로 이어도 됨. 꺾는 곳은 경첩 가운데, 본딩 점퍼 필요',
];

/// 옆으로 꺾을 때 작업 순서(개조식).
const List<String> kTrayFieldBendPlanNotes = [
  '마킹은 장애물 쪽 측판을 따라 잴 것. 직각자로 반대쪽 측판까지 선을 넘길 것',
  '꺾는 안쪽 측판을 V컷 폭만큼 따내고 바깥 측판을 경첩으로 접음',
  'V컷 안에 든 가로대는 떼어 냄',
  '맞닿은 안쪽 측판은 각도 맞춘 이음판·볼트로 체결. 볼트는 안에서 밖으로, 너트는 바깥',
  '용접·열가공 피할 것(SMCS·KRCCS, LH 시방서는 금지)',
  '절단면 날 제거, 아연 도료로 보수(맨살보다 13~25mm 넓게)',
  '꺾은 곳 양쪽 접지 본딩 점퍼(접지띠)',
  '케이블은 꺾는 안쪽 측판으로 당겨짐. 굵은 케이블은 나눠 꺾거나 수평 엘보 사용',
  '시방서 원칙은 방향 전환에 기성 엘보 사용. 현장 꺾기는 감독 승인 후',
  '마킹 값은 측판 두께 무시(몇 mm 차이). 첫 작업은 토막으로 맞춰 볼 것',
  '양쪽 측판을 다 잘라 수평 가변 이음판으로 이어도 됨. 안쪽 짧은 이음판 먼저, 바깥 이음판은 경첩이 가운데, 양쪽 600mm 안에 지지대, 본딩 점퍼',
];

/// 근거 보기.
const List<String> kTrayRouteBasis = [
  'V컷 폭 = 2 × 측판 높이 × tan(꺾는 각 ÷ 2). 꺾임 안쪽 테두리에서 따고 반대 테두리를 접는 곳으로 남깁니다. 기하로 계산한 식이고, 중국 현장 자료 "측판 높이 × 0.8"(45°)과 영국 현장 글(45°에 중심선 양쪽 41.4mm)이 같은 값입니다. 정해 둔 표준·제조사 자료는 없습니다.',
  '마킹 간격: 위로 꺾는 곳 → 아래로 꺾는 곳 = 경사 길이 + V컷 폭 ÷ 2, 아래로 꺾는 두 곳 사이 = 윗면 길이 + V컷 폭. 경사 길이 = 높이 ÷ sin(각), 수평 길이 = 높이 ÷ tan(각).',
  '옆으로 꺾기: 같은 식에 측판 높이 대신 트레이 폭(측판 사이)을 넣고, 바닥(가로대)과 안쪽 측판을 따고 바깥 측판을 경첩으로 씁니다(중국 제조사 글, 트로프형 기준, 한 곳 자료). 기준선은 장애물 쪽 측판입니다. 수평 가변 이음판: NEMA VE 2 3.4.4.',
  '나눠 꺾은 반경 = 마디 간격 ÷ (2 × tan(한 번 각 ÷ 2)). 기하로 계산한 값입니다.',
  'SMCS 31 65 10 3.8.5(4)·KRCCS 3.1.5(4): 방향 전환은 수평·수직 엘보 사용. SMCS 3.8.1(5)·KRCCS 3.1.7: 현장 굴곡은 전기적 연속성과 케이블 지지 유지. 현장 가공은 용접·열가공을 되도록 피하고 볼트·클램프로 결합(LH 61014는 금지).',
  '절단면: 날카로운 모서리·거친 절단면 금지(SMCS·KRCCS·LH). 아연 보수: ASTM A780 아연 함량 높은 도료, 맨살보다 13~25mm 넓게(NEMA VE 2 3.6.4).',
  '접지: 연결 부분 양쪽 접지띠(SMCS·KRCCS), 가변 이음판에는 본딩 점퍼(NEMA VE 2 3.4.3). 볼트 방향: OBO 설치 설명서.',
  '케이블: 트레이 꺾임 반경 ≥ 가장 굵은 케이블의 최소 굽힘 반경(ABB·B-Line 자료), 국내 다심 6D·단심 8D. 120sq 이상 굵은 전력 케이블은 기성 큰 반경 엘보 권장(중국 제조사 글, 한 곳 자료).',
  '엘보 이름: 위로 꺾는 것 수직 엘보 IN(내측형), 아래로 꺾는 것 수직 엘보 OUT(외측형)(NEMA VE 2·아인텍·대양).',
  '트레이 길이: 3m(KS C 8464·LH 61014·대양), 6m(대양).',
];

// ── 기성 엘보로 넘어가기·비켜가기 ──
//
// 엘보 R은 꺾임 안쪽 테두리 반경으로 본다(대양 수평 엘보 R1 = 안쪽 레일, B-Line 수직 엘보
// VI = R + 끝 직선 + H, VO = R + 끝 직선). 기준선(바닥면·장애물 쪽 측판)의 반경은
// 위로(장애물 반대쪽으로) 꺾는 엘보 = R + 측판 높이(옆으로는 트레이 폭), 반대 = R.
// 엘보 양 끝에 곧은 부분(끝 직선 [tangent])이 있다. 대양 카탈로그 그림에는 100이라 적혀 있지만
// 표 치수는 125로 맞는다: 수평 90° A = R2 + 125, 수평 60° A·B(W150~900 18줄 1mm 안),
// 수직 90° A = R + 125(시험 cable_tray_route_test.dart). B-Line은 3" = 76.

/// 엘보 끝 직선 기본값(mm, 대양 카탈로그 표 치수에 맞는 값).
const double kTrayElbowTangent = 125;

/// 엘보 이름.
String trayElbowName(TrayRouteKind k, bool up) =>
    trayRouteIsPlan(k) ? '수평 엘보' : (up ? '수직 엘보 IN' : '수직 엘보 OUT');

/// 부품 하나(시작점부터 차례로).
class TrayPiece {
  /// 엘보면 true, 직선이면 false.
  final bool elbow;

  /// 직선 길이(mm). 엘보면 기준선을 따라 잰 길이(참고).
  final double length;

  /// 엘보 꺾는 각(°): + = 위로(장애물 반대쪽으로), − = 아래로(장애물 쪽으로).
  final double turn;

  /// 부품 시작·끝(기준선 위 점과 진행 방향 rad). 그림에서 이음 자리를 긋는다.
  final (double, double, double) from, to;

  const TrayPiece({
    required this.elbow,
    required this.length,
    required this.turn,
    required this.from,
    required this.to,
  });

  bool get up => turn > 0;
}

/// 기성 엘보 계산 결과.
class TrayElbowRoute {
  final TrayRouteKind kind;
  final double angle, radius, tangent, rail;

  /// 그림용(꺾는 점 없이 기준선만, 엘보는 잘게 나눈 점).
  final TrayRoute shape;
  final List<TrayPiece> pieces;

  /// 엘보 사이 경사(비스듬한) 직선 길이(mm).
  final double leg;
  final double footprint, top, lead;
  final List<String> problems;

  const TrayElbowRoute({
    required this.kind,
    required this.angle,
    required this.radius,
    required this.tangent,
    required this.rail,
    required this.shape,
    required this.pieces,
    required this.leg,
    required this.footprint,
    required this.top,
    required this.lead,
    required this.problems,
  });

  bool get ok => problems.isEmpty;
  int get elbows => pieces.where((p) => p.elbow).length;
  List<TrayPiece> get straights => [
    for (final p in pieces)
      if (!p.elbow && p.length > 1e-6) p,
  ];
  double get straightTotal => straights.fold(0.0, (s, p) => s + p.length);

  /// 직선을 몇 개 트레이에서 자르는지(이음 여유 없이 길이 합만).
  int lengthsNeeded(double stock) => stock <= 0 || straightTotal <= 0
      ? 0
      : (straightTotal / stock - 1e-9).ceil().clamp(1, 1 << 20);

  /// 90° 엘보 한 변(카탈로그 A): 수직은 R + 끝 직선, 수평은 바깥 레일까지라 R + 트레이 폭 + 끝 직선.
  double get sideA => radius + (trayRouteIsPlan(kind) ? rail : 0) + tangent;
}

TrayElbowRoute trayElbowRoute({
  required TrayRouteKind kind,
  required double rise,
  required double angle,
  required double rail,
  required double radius,
  double tangent = kTrayElbowTangent,
  double obstacle = 0,
  double side = 0,
  double toFace = 0,
  double tail = 0,
}) {
  final problems = <String>[];
  final plan = trayRouteIsPlan(kind);
  final th = _rad(angle);
  final t = math.max(0.0, tangent);
  final rIn = radius + rail, rOut = radius; // 기준선 반경: 위로 꺾는 엘보·아래로 꺾는 엘보
  if (rise <= 0) problems.add(plan ? '옮길 거리가 0입니다.' : '높이가 0입니다.');
  var leg =
      (rise - (rIn + rOut) * (1 - math.cos(th)) - 2 * t * math.sin(th)) /
      math.sin(th);
  if (leg < -1e-6) {
    problems.add(
      '${plan ? '옮길 거리가 짧아' : '높이가 낮아'} 이 엘보 두 개로는 못 ${plan ? '옮깁니다' : '올라갑니다'}(엘보끼리 바로 이어도 ${(rise - leg * math.sin(th)).round()}mm). 각도가 작거나 반경이 작은 엘보를 쓰십시오.',
    );
    leg = 0;
  }
  final foot =
      2 * t +
      (rIn + rOut) * math.sin(th) +
      2 * t * math.cos(th) +
      leg * math.cos(th);
  final top = trayRouteReturns(kind) ? obstacle + 2 * side : 0.0;
  final lead = kind == TrayRouteKind.down
      ? toFace + side
      : toFace - side - foot;
  if (lead < -1e-6) {
    problems.add(
      '시작점이 장애물에 너무 가깝습니다. 시작점을 ${(-lead).ceil()}mm 더 앞으로 잡거나 더 작은 엘보를 쓰십시오.',
    );
  }
  final a = math.max(0.0, lead);

  final points = <(double, double)>[(0, 0)];
  final pieces = <TrayPiece>[];
  var x = 0.0, y = 0.0, dir = 0.0;
  void addPoint() {
    if (points.last.$1 != x || points.last.$2 != y) points.add((x, y));
  }

  void straight(double len) {
    x += len * math.cos(dir);
    y += len * math.sin(dir);
    addPoint();
  }

  void piece(double len) {
    final f = (x, y, dir);
    straight(len);
    pieces.add(
      TrayPiece(elbow: false, length: len, turn: 0, from: f, to: (x, y, dir)),
    );
  }

  void elbow(double sign) {
    final f = (x, y, dir);
    final rb = sign > 0 ? rIn : rOut;
    straight(t);
    // 원호: 중심은 꺾는 쪽(위로 = 왼쪽 법선)으로 rb
    final cx = x - math.sin(dir) * rb * sign,
        cy = y + math.cos(dir) * rb * sign;
    final steps = math.max(2, (angle / 5).ceil());
    final start = dir;
    for (var k = 1; k <= steps; k++) {
      final d = start + sign * th * k / steps;
      x = cx + math.sin(d) * rb * sign;
      y = cy - math.cos(d) * rb * sign;
      addPoint();
    }
    dir = start + sign * th;
    straight(t);
    pieces.add(
      TrayPiece(
        elbow: true,
        length: 2 * t + rb * th,
        turn: sign * angle,
        from: f,
        to: (x, y, dir),
      ),
    );
  }

  final first = kind == TrayRouteKind.down ? -1.0 : 1.0;
  piece(a);
  elbow(first);
  piece(leg);
  elbow(-first);
  if (trayRouteReturns(kind)) {
    piece(top);
    elbow(-1);
    piece(leg);
    elbow(1);
  }
  piece(tail);

  final shape = TrayRoute(
    kind: kind,
    rail: rail,
    angle: angle,
    pieces: 1,
    pitch: 0,
    points: points,
    corners: const [],
    leg: leg,
    footprint: foot,
    top: top,
    material: 0,
    lead: a,
    problems: problems,
  );
  return TrayElbowRoute(
    kind: kind,
    angle: angle,
    radius: radius,
    tangent: t,
    rail: rail,
    shape: shape,
    pieces: pieces,
    leg: leg,
    footprint: foot,
    top: top,
    lead: a,
    problems: problems,
  );
}

/// 기성 엘보로 할 때 작업 순서(개조식).
const List<String> kTrayElbowNotes = [
  '직선은 직각으로 자르고, 이음판을 형판으로 대고 볼트 구멍을 뚫을 것',
  '엘보·직선은 이음판·볼트로 체결. 볼트는 안에서 밖으로, 너트는 바깥',
  '절단면 날 제거, 아연 도료로 보수(맨살보다 13~25mm 넓게)',
  '연결 부분 양쪽 접지띠(본딩 점퍼)',
  '이음 자리는 지지대와 경간 1/4 사이가 좋음',
  '엘보 반경 ≥ 가장 굵은 케이블의 최소 굽힘 반경',
  '계산은 R을 꺾임 안쪽 테두리로 봄. 카탈로그 그림과 다르면 끝 직선 칸으로 맞출 것',
];

/// 수직 엘보 지지(NEMA VE 2 3.5.1.6)와 수평 엘보 지지(OBO).
const String kTrayVerticalElbowSupport =
    '지지: 위쪽 엘보는 양 끝, 아래쪽 엘보는 윗끝과 아래 끝 600mm 안';
const String kTrayHorizontalElbowSupport =
    '지지: 엘보 끝에서 250~300mm 안, 폭 400 이상이면 엘보 밑에 하나 더';
