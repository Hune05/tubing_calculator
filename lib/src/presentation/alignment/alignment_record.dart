// 축 정렬 기록: 정렬 전·후 값을 남긴다. 폰 저장이 먼저이고 다른 폰과 맞춘다(record_sync.dart).
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/record_sync.dart';
import 'alignment_math.dart';
import 'alignment_session.dart';

/// 정렬 전인지 후인지.
enum AlignStage {
  before('before', '정렬 전'),
  after('after', '정렬 후');

  final String id;
  final String label;
  const AlignStage(this.id, this.label);

  static AlignStage of(String? id) =>
      values.firstWhere((s) => s.id == id, orElse: () => AlignStage.before);
}

class AlignRecord {
  final String id; // 만든 시각(마이크로초)
  final DateTime at;
  final String machine; // 기계 이름(예: 1호기 급수펌프)
  final AlignMethod method;
  final AlignStage stage;
  final int rpm;
  final String equipmentId; // 장비 대장의 장비(없으면 빈 글)
  final String note;

  /// 화면에 넣은 값 그대로(다시 열어 볼 수 있게).
  final Map<String, String> inputs;

  /// 결과 요약(커플링 중심 평행 어긋남 mm, 각도 mm/100mm, 발 값).
  final double offset;
  final double angle100;
  final double shimFront;
  final double shimRear;
  final double moveFront;
  final double moveRear;
  final AlignVerdict verdict;

  /// 정렬 작업 회차(재고 → 심·옆 이동 → 다시 재기). 없으면 빈 목록.
  final List<AlignRound> rounds;
  const AlignRecord({
    required this.id,
    required this.at,
    this.machine = '',
    required this.method,
    required this.stage,
    required this.rpm,
    this.equipmentId = '',
    this.note = '',
    this.inputs = const {},
    required this.offset,
    required this.angle100,
    required this.shimFront,
    required this.shimRear,
    required this.moveFront,
    required this.moveRear,
    required this.verdict,
    this.rounds = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'machine': machine,
    'method': method.name,
    'stage': stage.id,
    'rpm': rpm,
    'equipmentId': equipmentId,
    'note': note,
    'inputs': inputs,
    'offset': offset,
    'angle100': angle100,
    'shimFront': shimFront,
    'shimRear': shimRear,
    'moveFront': moveFront,
    'moveRear': moveRear,
    'verdict': verdict.name,
    if (rounds.isNotEmpty) 'rounds': [for (final r in rounds) r.toJson()],
  };

  static AlignRecord fromJson(Map<String, dynamic> j) {
    final at = DateTime.tryParse((j['at'] ?? '').toString());
    if (j['id'] == null || at == null) {
      throw const FormatException('정렬 기록이 아닙니다');
    }
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    final raw = j['inputs'];
    return AlignRecord(
      id: j['id'].toString(),
      at: at,
      machine: (j['machine'] ?? '').toString(),
      method: AlignMethod.values.firstWhere(
        (m) => m.name == j['method'],
        orElse: () => AlignMethod.reverse,
      ),
      stage: AlignStage.of(j['stage']?.toString()),
      rpm: (j['rpm'] as num?)?.toInt() ?? 0,
      equipmentId: (j['equipmentId'] ?? '').toString(),
      note: (j['note'] ?? '').toString(),
      inputs: raw is Map
          ? {for (final e in raw.entries) e.key.toString(): e.value.toString()}
          : const {},
      offset: d('offset'),
      angle100: d('angle100'),
      shimFront: d('shimFront'),
      shimRear: d('shimRear'),
      moveFront: d('moveFront'),
      moveRear: d('moveRear'),
      verdict: AlignVerdict.values.firstWhere(
        (v) => v.name == j['verdict'],
        orElse: () => AlignVerdict.ok,
      ),
      rounds: roundsFromJson(j['rounds']),
    );
  }
}

String verdictLabel(AlignVerdict v) => switch (v) {
  AlignVerdict.ok => '허용 안',
  AlignVerdict.offsetOut => '평행 어긋남 초과',
  AlignVerdict.angleOut => '각도 어긋남 초과',
  AlignVerdict.bothOut => '평행·각도 모두 초과',
};

String _two(int n) => n.toString().padLeft(2, '0');

String methodLabel(AlignMethod m) => m == AlignMethod.reverse ? '리버스 다이얼' : '림·페이스';

/// 카톡으로 보내는 글.
String buildAlignText(AlignRecord r) {
  final b = StringBuffer(
    '[축 정렬 ${r.stage.label}] ${r.at.month}/${r.at.day} ${_two(r.at.hour)}:${_two(r.at.minute)}',
  );
  if (r.machine.isNotEmpty) b.write('\n기계: ${r.machine}');
  b.write('\n방식: ${methodLabel(r.method)}${r.rpm > 0 ? ' · ${r.rpm}rpm' : ''}');
  b.write('\n평행 어긋남 ${r.offset.toStringAsFixed(3)} mm · 각도 ${r.angle100.toStringAsFixed(3)} mm/100mm');
  b.write('\n판정: ${verdictLabel(r.verdict)}');
  b.write('\n앞발 심 ${shimText(r.shimFront)} · 옆 ${moveText(r.moveFront)}');
  b.write('\n뒷발 심 ${shimText(r.shimRear)} · 옆 ${moveText(r.moveRear)}');
  if (r.note.isNotEmpty) b.write('\n메모: ${r.note}');
  if (r.rounds.isNotEmpty) b.write('\n${buildRoundsText(r.rounds)}');
  return b.toString();
}

/// 같은 기계의 정렬 전 → 정렬 후 비교 글(전 기록이 없으면 null).
String? compareText(AlignRecord after, List<AlignRecord> all) {
  if (after.stage != AlignStage.after) return null;
  AlignRecord? before;
  for (final r in all) {
    if (r.id == after.id || r.stage != AlignStage.before) continue;
    if (r.machine != after.machine || r.at.isAfter(after.at)) continue;
    if (before == null || r.at.isAfter(before.at)) before = r;
  }
  if (before == null) return null;
  return '평행 어긋남 ${before.offset.toStringAsFixed(3)} → ${after.offset.toStringAsFixed(3)} mm, '
      '각도 ${before.angle100.toStringAsFixed(3)} → ${after.angle100.toStringAsFixed(3)} mm/100mm';
}

class AlignStore {
  static const String key = 'align_records_v1';
  static const String lastMachineKey = 'align_last_machine_v1';
  static const int cap = 200;

  static final RecordSync sync = RecordSync(
    key: key,
    collection: 'align_records',
    isValid: _readable,
  );

  static bool _readable(Map<String, dynamic> j) {
    try {
      AlignRecord.fromJson(j);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<AlignRecord>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      final out = <AlignRecord>[];
      for (final e in list) {
        try {
          out.add(AlignRecord.fromJson(Map<String, dynamic>.from(e as Map)));
        } catch (_) {}
      }
      out.sort((a, b) => b.at.compareTo(a.at));
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _write(List<AlignRecord> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode([for (final r in list.take(cap)) r.toJson()]));
  }

  static Future<void> put(AlignRecord r) async {
    final list = await load();
    list.removeWhere((e) => e.id == r.id);
    list.insert(0, r);
    await _write(list);
    await sync.saved(r.id);
    final p = await SharedPreferences.getInstance();
    await p.setString(lastMachineKey, r.machine);
  }

  static Future<void> delete(String id) async {
    final list = await load();
    list.removeWhere((e) => e.id == id);
    await _write(list);
    await sync.removed(id);
  }

  static Future<String> lastMachine() async =>
      (await SharedPreferences.getInstance()).getString(lastMachineKey) ?? '';
}
