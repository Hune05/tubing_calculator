// 시퀀스(래더) 회로 동작 계산(10-03): 접점(a·b)·코일·타이머로 된 가로줄(렁)을 위에서부터 풀어,
// 버튼을 누르고 뗄 때마다 어떤 코일이 여자되는지 계산한다. 화면은 circuit_reading_page.dart.
// 접점 번호는 IEC 60947·EN 50005 관례(주접점 1-2·3-4·5-6, 보조 a접점 13-14, b접점 21-22,
// 과부하계전기 b접점 95-96)를 쓴다.
library;

/// 회로 요소. [LContact]는 접점, [LPar]는 병렬 묶음.
sealed class LNode {
  const LNode();
}

/// 접점: [tag] 상태가 참이면 a접점(nc = false)은 닫히고 b접점(nc = true)은 열린다.
class LContact extends LNode {
  const LContact(this.tag, this.label, {this.nc = false});
  final String tag;
  final String label;
  final bool nc;
}

/// 병렬 묶음: [paths] 중 하나라도 모두 닫히면 통한다.
class LPar extends LNode {
  const LPar(this.paths);
  final List<List<LNode>> paths;
}

enum LOutKind { coil, timer, lamp }

/// 한 줄(렁): 왼쪽 모선에서 [series]를 지나 [out](코일·타이머·램프)에 닿는다.
class LRung {
  const LRung(this.series, this.outTag, this.outLabel, {this.kind = LOutKind.coil});
  final List<LNode> series;
  final String outTag;
  final String outLabel;
  final LOutKind kind;
}

/// 회로 하나: 줄 목록과 누름 버튼(순간 접점) 목록.
class LadderCircuit {
  const LadderCircuit({
    required this.title,
    required this.rungs,
    required this.buttons,
    this.toggles = const [],
    this.timerTag,
  });
  final String title;
  final List<LRung> rungs;

  /// 누르면 참, 떼면 거짓으로 돌아가는 버튼: (tag, 이름).
  final List<(String, String)> buttons;

  /// 눌러 두면 그대로 있는 것(과부하 트립 등): (tag, 이름).
  final List<(String, String)> toggles;

  /// 한시 동작 타이머 코일 tag. 다 차면 '$timerTag.done'이 참이 된다.
  final String? timerTag;
}

/// 접점이 닫혔는지.
bool contactClosed(LContact c, Map<String, bool> s) {
  final v = s[c.tag] ?? false;
  return c.nc ? !v : v;
}

/// 직렬 경로가 통하는지.
bool pathConducts(List<LNode> series, Map<String, bool> s) {
  for (final n in series) {
    final ok = switch (n) {
      LContact() => contactClosed(n, s),
      LPar() => n.paths.any((p) => pathConducts(p, s)),
    };
    if (!ok) return false;
  }
  return true;
}

/// 상태 [s]에서 회로가 안정될 때까지 줄을 위에서부터 다시 푼다(자기유지·인터록 반영).
/// 타이머 코일이 꺼지면 '$tag.done'도 꺼진다. 돌려준 지도는 새것이다.
Map<String, bool> solve(LadderCircuit c, Map<String, bool> s) {
  final m = Map<String, bool>.from(s);
  for (final r in c.rungs) {
    m[r.outTag] ??= false;
  }
  if (c.timerTag != null) m['${c.timerTag}.done'] ??= false;
  for (var round = 0; round < 20; round++) {
    var changed = false;
    for (final r in c.rungs) {
      final on = pathConducts(r.series, m);
      if ((m[r.outTag] ?? false) != on) {
        m[r.outTag] = on;
        changed = true;
        if (r.kind == LOutKind.timer && !on) m['${r.outTag}.done'] = false;
      }
    }
    if (!changed) break;
  }
  return m;
}

/// 버튼 [tag]를 눌렀다 뗀다. 누른 순간과 뗀 뒤의 상태를 차례로 돌려준다.
(Map<String, bool>, Map<String, bool>) pressButton(
  LadderCircuit c,
  Map<String, bool> s,
  String tag,
) {
  final pressed = solve(c, {...s, tag: true});
  final released = solve(c, {...pressed, tag: false});
  return (pressed, released);
}

/// 두 상태를 비교해 켜지거나 꺼진 출력(코일·타이머·램프)을 줄 순서대로 적는다.
List<String> describeChanges(
  LadderCircuit c,
  Map<String, bool> before,
  Map<String, bool> after,
) {
  final out = <String>[];
  for (final r in c.rungs) {
    final b = before[r.outTag] ?? false, a = after[r.outTag] ?? false;
    if (a == b) continue;
    final what = switch (r.kind) {
      LOutKind.coil => a ? '여자' : '소자',
      LOutKind.timer => a ? '시간 재기 시작' : '복귀',
      LOutKind.lamp => a ? '켜짐' : '꺼짐',
    };
    out.add('${r.outLabel} $what');
  }
  final t = c.timerTag;
  if (t != null && (before['$t.done'] ?? false) != (after['$t.done'] ?? false)) {
    out.add((after['$t.done'] ?? false) ? '타이머 시간 다 됨: 한시 접점 동작' : '타이머 한시 접점 복귀');
  }
  return out;
}

// ── 기본 회로 4가지 ──

/// 직입 기동(자기유지): 정지 b접점·과부하 b접점·기동 a접점에 MC 보조 a접점을 병렬로.
const LadderCircuit kDolCircuit = LadderCircuit(
  title: '직입 기동 (자기유지)',
  rungs: [
    LRung([
      LContact('OL', '과부하 95-96', nc: true),
      LContact('PB0', '정지 PB0', nc: true),
      LPar([
        [LContact('PB1', '기동 PB1')],
        [LContact('MC', 'MC 13-14')],
      ]),
    ], 'MC', 'MC 코일'),
    LRung([LContact('MC', 'MC 보조 a')], 'RL', '운전등 RL', kind: LOutKind.lamp),
    LRung([LContact('MC', 'MC 보조 b', nc: true)], 'GL', '정지등 GL', kind: LOutKind.lamp),
  ],
  buttons: [('PB1', '기동 PB1'), ('PB0', '정지 PB0')],
  toggles: [('OL', '과부하 트립')],
);

/// 정역 운전: 정·역 자기유지에 상대 접촉기 b접점(전기적 인터록)을 넣는다.
const LadderCircuit kFwdRevCircuit = LadderCircuit(
  title: '정역 운전 (인터록)',
  rungs: [
    LRung([
      LContact('OL', '과부하 95-96', nc: true),
      LContact('PB0', '정지 PB0', nc: true),
      LPar([
        [LContact('PBF', '정회전 PBF')],
        [LContact('MCF', 'MCF 13-14')],
      ]),
      LContact('MCR', 'MCR 21-22', nc: true),
    ], 'MCF', 'MCF 코일(정)'),
    LRung([
      LContact('OL', '과부하 95-96', nc: true),
      LContact('PB0', '정지 PB0', nc: true),
      LPar([
        [LContact('PBR', '역회전 PBR')],
        [LContact('MCR', 'MCR 13-14')],
      ]),
      LContact('MCF', 'MCF 21-22', nc: true),
    ], 'MCR', 'MCR 코일(역)'),
  ],
  buttons: [('PBF', '정회전 PBF'), ('PBR', '역회전 PBR'), ('PB0', '정지 PB0')],
  toggles: [('OL', '과부하 트립')],
);

/// Y-Δ 기동: MC-M과 MC-Y로 Y 기동, 타이머 T가 다 차면 MC-Y가 떨어지고 MC-Δ가 붙어 자기유지한다.
/// MC-Y와 MC-Δ는 서로의 b접점으로 인터록하고, MC-Δ가 붙으면 타이머는 복귀한다.
const LadderCircuit kStarDeltaCircuit = LadderCircuit(
  title: 'Y-Δ 기동 (타이머)',
  rungs: [
    LRung([
      LContact('OL', '과부하 95-96', nc: true),
      LContact('PB0', '정지 PB0', nc: true),
      LPar([
        [LContact('PB1', '기동 PB1')],
        [LContact('MCM', 'MC-M 13-14')],
      ]),
    ], 'MCM', 'MC-M 코일(주)'),
    LRung([LContact('MCM', 'MC-M 보조 a'), LContact('MCD', 'MC-Δ 21-22', nc: true)], 'T', '타이머 T', kind: LOutKind.timer),
    LRung([
      LContact('MCM', 'MC-M 보조 a'),
      LContact('T.done', 'T 한시 b', nc: true),
      LContact('MCD', 'MC-Δ 21-22', nc: true),
    ], 'MCY', 'MC-Y 코일'),
    LRung([
      LContact('MCM', 'MC-M 보조 a'),
      LPar([
        [LContact('T.done', 'T 한시 a')],
        [LContact('MCD', 'MC-Δ 13-14')],
      ]),
      LContact('MCY', 'MC-Y 21-22', nc: true),
    ], 'MCD', 'MC-Δ 코일'),
  ],
  buttons: [('PB1', '기동 PB1'), ('PB0', '정지 PB0')],
  toggles: [('OL', '과부하 트립')],
  timerTag: 'T',
);
