// 정렬 작업 기록(회차): 재고 → 심을 넣고 빼고 옆으로 밀고 → 다시 재는 일을 회차마다 남긴다.
// 회차에는 그때 잰 결과와 "실제로 한 일"(네 발 각각 넣고 뺀 심, 옆으로 민 양)을 적고, 네 발의 심 누계를 보여 준다.
// 작업 중인 회차는 폰에 그대로 두어(화면을 나가도 남는다) 끝나면 정렬 기록에 같이 저장한다.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'alignment_math.dart';

/// 모터 네 발. 왼쪽·오른쪽은 고정 쪽(펌프)에서 모터를 볼 때.
enum AlignFoot {
  frontLeft('앞발 왼쪽'),
  frontRight('앞발 오른쪽'),
  rearLeft('뒷발 왼쪽'),
  rearRight('뒷발 오른쪽');

  final String label;
  const AlignFoot(this.label);
}

class AlignRound {
  final DateTime at;

  /// 그때 잰 결과.
  final double offset;
  final double angle100;
  final AlignVerdict verdict;
  final double shimFront; // 계산이 말한 값(넣기 +, 빼기 −)
  final double shimRear;
  final double moveFront; // 계산이 말한 옆 이동(오른쪽 +)
  final double moveRear;

  /// 실제로 한 일: 발마다 넣은(+)·뺀(−) 심 mm. 아직 안 적었으면 null.
  final Map<AlignFoot, double>? done;
  final double doneMoveFront; // 실제로 옆으로 민 양(오른쪽 +)
  final double doneMoveRear;
  final String note;

  const AlignRound({
    required this.at,
    required this.offset,
    required this.angle100,
    required this.verdict,
    required this.shimFront,
    required this.shimRear,
    required this.moveFront,
    required this.moveRear,
    this.done,
    this.doneMoveFront = 0,
    this.doneMoveRear = 0,
    this.note = '',
  });

  AlignRound withDone(Map<AlignFoot, double> done, {required double moveFront, required double moveRear, required String note}) => AlignRound(
    at: at,
    offset: offset,
    angle100: angle100,
    verdict: verdict,
    shimFront: shimFront,
    shimRear: shimRear,
    moveFront: this.moveFront,
    moveRear: this.moveRear,
    done: done,
    doneMoveFront: moveFront,
    doneMoveRear: moveRear,
    note: note,
  );

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'offset': offset,
    'angle100': angle100,
    'verdict': verdict.name,
    'shimFront': shimFront,
    'shimRear': shimRear,
    'moveFront': moveFront,
    'moveRear': moveRear,
    if (done != null) 'done': {for (final e in done!.entries) e.key.name: e.value},
    'doneMoveFront': doneMoveFront,
    'doneMoveRear': doneMoveRear,
    'note': note,
  };

  static AlignRound fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    final raw = j['done'];
    return AlignRound(
      at: DateTime.tryParse((j['at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0),
      offset: d('offset'),
      angle100: d('angle100'),
      verdict: AlignVerdict.values.firstWhere((v) => v.name == j['verdict'], orElse: () => AlignVerdict.ok),
      shimFront: d('shimFront'),
      shimRear: d('shimRear'),
      moveFront: d('moveFront'),
      moveRear: d('moveRear'),
      done: raw is Map
          ? {
              for (final f in AlignFoot.values)
                if (raw[f.name] is num) f: (raw[f.name] as num).toDouble(),
            }
          : null,
      doneMoveFront: d('doneMoveFront'),
      doneMoveRear: d('doneMoveRear'),
      note: (j['note'] ?? '').toString(),
    );
  }
}

List<AlignRound> roundsFromJson(Object? raw) {
  if (raw is! List) return const [];
  final out = <AlignRound>[];
  for (final e in raw) {
    try {
      out.add(AlignRound.fromJson(Map<String, dynamic>.from(e as Map)));
    } catch (_) {}
  }
  return out;
}

/// 네 발의 심 누계(지금까지 넣은 것 − 뺀 것).
Map<AlignFoot, double> shimTotals(List<AlignRound> rounds) {
  final out = {for (final f in AlignFoot.values) f: 0.0};
  for (final r in rounds) {
    final d = r.done;
    if (d == null) continue;
    for (final e in d.entries) {
      out[e.key] = out[e.key]! + e.value;
    }
  }
  return out;
}

/// 옆으로 민 누계(앞·뒤, 오른쪽 +).
(double, double) moveTotals(List<AlignRound> rounds) {
  var f = 0.0, r = 0.0;
  for (final x in rounds) {
    if (x.done == null) continue;
    f += x.doneMoveFront;
    r += x.doneMoveRear;
  }
  return (f, r);
}

String signedMm(double v) => v.abs() < 0.005 ? '0' : '${v > 0 ? '+' : '−'}${v.abs().toStringAsFixed(2)}';

String _two(int n) => n.toString().padLeft(2, '0');

/// 한 회차에 한 일을 한 줄로.
String doneLine(AlignRound r) {
  final d = r.done;
  if (d == null) return '한 일 안 적음';
  final parts = <String>[];
  double v(AlignFoot f) => d[f] ?? 0;
  void pair(String name, AlignFoot l, AlignFoot rt) {
    if (v(l).abs() < 0.005 && v(rt).abs() < 0.005) return;
    if ((v(l) - v(rt)).abs() < 0.005) {
      parts.add('$name 심 ${signedMm(v(l))}');
    } else {
      parts.add('$name 심 왼 ${signedMm(v(l))} / 오른 ${signedMm(v(rt))}');
    }
  }

  pair('앞발', AlignFoot.frontLeft, AlignFoot.frontRight);
  pair('뒷발', AlignFoot.rearLeft, AlignFoot.rearRight);
  if (r.doneMoveFront.abs() >= 0.005) parts.add('앞 옆으로 ${moveText(r.doneMoveFront)}');
  if (r.doneMoveRear.abs() >= 0.005) parts.add('뒤 옆으로 ${moveText(r.doneMoveRear)}');
  if (parts.isEmpty) parts.add('손대지 않음');
  if (r.note.isNotEmpty) parts.add(r.note);
  return parts.join(', ');
}

/// 회차 기록을 글로(카톡·기록용).
String buildRoundsText(List<AlignRound> rounds) {
  if (rounds.isEmpty) return '';
  final b = StringBuffer('정렬 작업 ${rounds.length}회차');
  for (var i = 0; i < rounds.length; i++) {
    final r = rounds[i];
    b.write('\n${i + 1}회차 ${_two(r.at.hour)}:${_two(r.at.minute)}  평행 ${r.offset.toStringAsFixed(3)} mm · 각도 ${r.angle100.toStringAsFixed(3)} mm/100mm');
    if (r.done != null) b.write('\n  한 일: ${doneLine(r)}');
  }
  final t = shimTotals(rounds);
  if (t.values.any((v) => v.abs() >= 0.005)) {
    b.write('\n심 누계(mm): ${[for (final f in AlignFoot.values) '${f.label} ${signedMm(t[f]!)}'].join(', ')}');
  }
  return b.toString();
}

/// 작업 중인 회차를 폰에 둔다.
class AlignSessionStore {
  static const String key = 'align_session_v1';

  static Future<List<AlignRound>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return roundsFromJson(jsonDecode(raw));
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<AlignRound> rounds) async {
    final p = await SharedPreferences.getInstance();
    if (rounds.isEmpty) {
      await p.remove(key);
    } else {
      await p.setString(key, jsonEncode([for (final r in rounds) r.toJson()]));
    }
  }
}
