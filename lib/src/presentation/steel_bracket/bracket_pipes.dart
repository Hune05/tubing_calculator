// 형강 브라켓 가로대 위 관 자리(10-12, 사용자 "U볼트 홀 간격 … 단순 일자로 쭉 뚫어서는 안 되고 현업 작업 살펴보고"):
// U볼트는 관 하나에 다리 둘이라 가로대 구멍이 "관 중심 ± 다리 간격/2" 한 쌍으로 나온다.
//  · 다리 간격(다리 중심 사이) = U볼트 내경 + 나사 지름. 내경·나사는 호칭별 표 값(아래 출처), 가진 U볼트가 다르면 재서 고친다.
//  · 관 자리: 첫 관 중심(구멍 기준 끝에서) + 관 사이 중심 거리. 비우면 자동 = 두 관 반지름 + 틈 25
//    (배관 랙 어림 "관끼리 + 1인치", 보온·플랜지가 있으면 그만큼 더 넣을 것). 다만 이웃 U볼트 다리 사이에
//    너트·와셔가 들어가야 하니(와셔 지름 어림 + 5) 그보다 좁으면 그만큼 벌린다.
//  · 저장: 관마다 글 하나 "호칭|나사|다리 간격"(빈 칸 = 자동). 예) "25A||", "50A|16|", "D48.6|12|62".
// 출처: 강관 외경 KS D 3507, U볼트 내경·나사 decreyellow.co.kr "U볼트 규격표"(판매 자료, DIN 3570과 나사가 다른 곳 있음),
// 후강 전선관 외경 KS C 8401. 전선관·튜브·직접 외경의 U볼트 값은 어림(approx).
library;

import 'dart:math' as math;

/// 관 크기 하나: 이름, 바깥지름, U볼트 내경·나사(M), 어림 값인가.
typedef BracketPipeSize = ({
  String name,
  String group,
  double od,
  double uId,
  int thread,
  bool approx,
});

/// 관 종류 단추 차례.
const List<String> kBracketPipeGroups = ['강관', '전선관', '튜브'];

const List<BracketPipeSize> kBracketPipeSizes = [
  // 강관(KS D 3507 외경) · U볼트 내경·나사(판매 규격표)
  (name: '15A', group: '강관', od: 21.7, uId: 22, thread: 8, approx: false),
  (name: '20A', group: '강관', od: 27.2, uId: 28, thread: 8, approx: false),
  (name: '25A', group: '강관', od: 34.0, uId: 36, thread: 10, approx: false),
  (name: '32A', group: '강관', od: 42.7, uId: 45, thread: 10, approx: false),
  (name: '40A', group: '강관', od: 48.6, uId: 51, thread: 12, approx: false),
  (name: '50A', group: '강관', od: 60.5, uId: 63, thread: 12, approx: false),
  (name: '65A', group: '강관', od: 76.3, uId: 79, thread: 12, approx: false),
  (name: '80A', group: '강관', od: 89.1, uId: 92, thread: 16, approx: false),
  (name: '100A', group: '강관', od: 114.3, uId: 118, thread: 16, approx: false),
  // 후강 전선관(KS C 8401 외경) · 바깥지름이 가까운 강관 U볼트와 같게(어림)
  (name: '16C', group: '전선관', od: 21.0, uId: 22, thread: 8, approx: true),
  (name: '22C', group: '전선관', od: 26.5, uId: 28, thread: 8, approx: true),
  (name: '28C', group: '전선관', od: 33.3, uId: 36, thread: 10, approx: true),
  (name: '36C', group: '전선관', od: 41.9, uId: 45, thread: 10, approx: true),
  (name: '42C', group: '전선관', od: 47.8, uId: 51, thread: 12, approx: true),
  (name: '54C', group: '전선관', od: 59.6, uId: 63, thread: 12, approx: true),
  // 계장 튜브(인치 × 25.4) · 작은 U볼트(어림)
  (name: '1/4"', group: '튜브', od: 6.35, uId: 7.5, thread: 6, approx: true),
  (name: '3/8"', group: '튜브', od: 9.53, uId: 10.5, thread: 6, approx: true),
  (name: '1/2"', group: '튜브', od: 12.7, uId: 14, thread: 6, approx: true),
  (name: '3/4"', group: '튜브', od: 19.05, uId: 20, thread: 8, approx: true),
  (name: '1"', group: '튜브', od: 25.4, uId: 27, thread: 8, approx: true),
];

/// 나사 단추(M).
const List<int> kBracketUThreads = [6, 8, 10, 12, 16];

/// 나사에 맞는 구멍 지름(앱 펀치 금형 표와 같은 값, M6은 φ7).
double bracketUHole(int m) => switch (m) {
  6 => 7,
  8 => 9,
  10 => 11,
  12 => 13.5,
  16 => 17.5,
  20 => 22,
  _ => m + 1.5,
};

/// 관 사이 자동 간격에 넣는 틈(mm).
const double kBracketPipeGap = 25;

/// 나사에 끼우는 평와셔 지름 어림(mm) + 공구 여유 5. 이웃 U볼트 다리 사이 최소 거리를 셀 때 쓴다.
double bracketUWasher(int m) => switch (m) {
  6 => 12 + 5,
  8 => 16 + 5,
  10 => 20 + 5,
  12 => 24 + 5,
  16 => 30 + 5,
  _ => 2.0 * m + 5,
};

/// 관 하나(계산 입력): 이름, 바깥지름, 중심 자리(구멍 기준 끝에서), U볼트 다리 간격·나사·구멍 지름.
class BracketPipe {
  final String name;
  final double od;
  final double at;
  final double spacing;
  final int thread;
  final double hole;

  /// U볼트 값이 어림(표에 없는 크기)인가.
  final bool approx;
  const BracketPipe({
    required this.name,
    required this.od,
    required this.at,
    required this.spacing,
    required this.thread,
    required this.hole,
    this.approx = false,
  });

  /// "25A U볼트 M10(다리 간격 46)".
  String get uText => '$name U볼트 M$thread(다리 간격 ${_f(spacing)})';
}

/// 관마다 저장 글 하나를 풀어 쓴 것.
class BracketPipeSpec {
  /// 호칭('25A') 또는 직접 외경('D48.6').
  final String size;

  /// 0이면 표 값.
  final int thread;

  /// 0이면 자동(내경 + 나사).
  final double spacing;
  const BracketPipeSpec(this.size, {this.thread = 0, this.spacing = 0});

  static BracketPipeSpec parse(String? s) {
    final t = (s ?? '').split('|');
    final size = t.first.trim().isEmpty ? '25A' : t.first.trim();
    final m = t.length > 1 ? int.tryParse(t[1].trim()) ?? 0 : 0;
    final c = t.length > 2 ? double.tryParse(t[2].trim()) ?? 0 : 0.0;
    return BracketPipeSpec(size, thread: m < 0 ? 0 : m, spacing: c < 0 ? 0 : c);
  }

  String get text =>
      '$size|${thread > 0 ? thread : ''}|${spacing > 0 ? _f(spacing) : ''}';

  /// 표 줄(직접 외경이면 어림 줄을 만든다). 못 읽으면 null.
  BracketPipeSize? get row {
    for (final r in kBracketPipeSizes) {
      if (r.name == size) return r;
    }
    if (size.startsWith('D')) {
      final od = double.tryParse(size.substring(1));
      if (od == null || od <= 0) return null;
      // 표 흐름을 따른 어림: 내경 = 외경 + 2, 나사는 굵기에 따라
      final m = od <= 13
          ? 6
          : od <= 28
          ? 8
          : od <= 46
          ? 10
          : od <= 80
          ? 12
          : 16;
      return (
        name: '외경 ${_f(od)}',
        group: '직접',
        od: od,
        uId: od + 2,
        thread: m,
        approx: true,
      );
    }
    return null;
  }

  int get threadUsed => thread > 0 ? thread : (row?.thread ?? 10);

  /// 다리 간격(자동이면 내경 + 나사).
  double get spacingUsed {
    if (spacing > 0) return spacing;
    final r = row;
    return r == null ? 0 : r.uId + threadUsed;
  }

  String get label => row?.name ?? size;
}

/// 관 사이 자동 중심 거리: 두 관 반지름 + 틈 25, 이웃 다리 사이에 너트·와셔가 안 들어가면 그만큼 더(5단위 올림).
double bracketPipeAutoPitch(BracketPipeSpec a, BracketPipeSpec b) {
  final ra = a.row, rb = b.row;
  if (ra == null || rb == null) return 0;
  final body = ra.od / 2 + rb.od / 2 + kBracketPipeGap;
  final legs =
      a.spacingUsed / 2 +
      b.spacingUsed / 2 +
      (bracketUWasher(a.threadUsed) + bracketUWasher(b.threadUsed)) / 2;
  return (math.max(body, legs) / 5).ceil() * 5.0;
}

/// 관 자리 만들기: [first] 첫 관 중심, [pitch] 관 사이(0이면 자동, 이웃마다 두 관 크기로).
List<BracketPipe> bracketPipeLayout(
  List<BracketPipeSpec> specs, {
  required double first,
  double pitch = 0,
}) {
  final out = <BracketPipe>[];
  var x = first;
  BracketPipeSpec? prev;
  for (final s in specs) {
    final r = s.row;
    if (r == null) continue;
    if (prev != null) {
      x += pitch > 0 ? pitch : bracketPipeAutoPitch(prev, s);
    }
    final m = s.threadUsed;
    out.add(
      BracketPipe(
        name: r.name,
        od: r.od,
        at: x,
        spacing: s.spacingUsed,
        thread: m,
        hole: bracketUHole(m),
        approx: r.approx && s.spacing <= 0,
      ),
    );
    prev = s;
  }
  return out;
}

/// 관 사이 자동 거리 글("자동 59" 또는 이웃마다 다르면 "자동 59·72").
String bracketPipeAutoPitchText(List<BracketPipeSpec> specs) {
  final ok = [
    for (final s in specs)
      if (s.row != null) s,
  ];
  if (ok.length < 2) return '자동';
  final ps = <String>[
    for (var k = 1; k < ok.length; k++)
      _f(bracketPipeAutoPitch(ok[k - 1], ok[k])),
  ];
  final uniq = ps.toSet().toList();
  return '자동 ${uniq.length == 1 ? uniq.first : ps.join('·')}';
}

String _f(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s;
}
