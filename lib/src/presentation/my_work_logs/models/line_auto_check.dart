// 압력시험·교정 기록을 프로젝트에 붙여 합격으로 저장하면 라인 진행 보드의 그 단계를 체크한다(10-10).
// 압력시험은 기록의 "라인" 칸, 교정은 태그(예: PT-101 → 라인 1F-PT-101, 딱 하나 맞을 때만)로 찾는다.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/work_project_repository.dart';
import 'line_progress.dart';

/// 프로젝트 저장소(시험에서 가짜로 바꿔 끼운다).
@visibleForTesting
WorkProjectRepository Function() lineCheckRepo = WorkProjectRepository.new;

/// 체크했으면 알림 글(예: "라인 진행에 표시: 1F-PT-101 압력시험"), 아니면 null.
/// 통신이 없어도 폰 사본으로 찾고 폰에 먼저 쓴다. 이미 체크된 단계는 건드리지 않는다.
Future<String?> autoCheckLineStage({
  required String projectId,
  required String name,
  required bool pressure,
  String who = '',
  DateTime? now,
}) async {
  if (projectId.isEmpty || name.trim().isEmpty) return null;
  final repo = lineCheckRepo();
  Map<String, dynamic>? log;
  Map<String, dynamic>? pick(List<Map<String, dynamic>> all) {
    for (final l in all) {
      if (l['id']?.toString() == projectId) return l;
    }
    return null;
  }

  try {
    log = pick(await repo.fetchCachedProjects());
  } catch (_) {}
  if (log == null) {
    try {
      log = pick(await repo.fetchAllProjects());
    } catch (_) {}
  }
  if (log == null) return null;

  final line = pressure
      ? (findLine(log, name) ?? findLineForTag(log, name))
      : findLineForTag(log, name);
  if (line == null) return null;
  final stage = stageForRecord(lineStagesOf(log), pressure: pressure);
  if (stage == null || lineStageDone(line, stage)) return null;

  final items = [
    for (final e in (log[kLineItemsKey] as List? ?? const []))
      if (e is Map) Map<String, dynamic>.from(e),
  ];
  final i = items.indexWhere((e) => e['id'] == line['id']);
  if (i < 0) return null;
  setLineStage(items[i], stage, true, who: who, now: now);
  log[kLineItemsKey] = items;

  // 폰에 쓰기를 넘기면 끝으로 본다(통신이 없으면 나중에 올라간다). 저장 직전에 서버 것과 합친다.
  final written = Completer<bool>();
  unawaited(
    repo
        .upsertProject(
          log,
          onWritten: () {
            if (!written.isCompleted) written.complete(true);
          },
        )
        .catchError((Object _) {
          if (!written.isCompleted) written.complete(false);
        }),
  );
  final ok = await written.future.timeout(
    const Duration(seconds: 5),
    onTimeout: () => false,
  );
  return ok ? '라인 진행에 표시: ${line['name']} $stage' : null;
}
