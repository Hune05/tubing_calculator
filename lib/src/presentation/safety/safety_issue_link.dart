// 안전 점검에서 "조치 필요"로 고른 항목을 프로젝트 이슈로 올린다(10-10).
// 이슈 목록의 처리·처리 후 사진·담당·기한 흐름을 그대로 쓴다. 같은 점검의 같은 항목은 두 번 올리지 않는다.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/common_widgets/snack_once.dart';
import '../../data/repositories/work_project_repository.dart';
import '../my_work_logs/models/project_merge.dart' show currentWorkerName, stampAuthor;
import 'safety_check_model.dart';

/// "조치 필요"로 고른 항목 이름들.
List<String> safetyFixLabels(SafetyRecord r) => [
  for (final l in r.lines)
    if (l.answer == SafetyAnswer.fix) l.label,
];

/// [project]에 넣을 이슈. 이미 이 점검에서 올린 항목은 뺀다.
List<Map<String, dynamic>> safetyIssuesFor(
  SafetyRecord r,
  Map<String, dynamic> project, {
  DateTime? now,
  String who = '',
}) {
  final have = <String>{
    for (final p in (project['punch_lists'] as List? ?? []).whereType<Map>())
      if (p['safetyRecordId']?.toString() == r.id) (p['safetyItem'] ?? '').toString(),
  };
  final base = now ?? DateTime.now();
  final site = r.site.trim();
  final work = r.work.trim();
  final out = <Map<String, dynamic>>[];
  for (final label in safetyFixLabels(r)) {
    if (have.contains(label)) continue;
    final m = <String, dynamic>{
      'id': '${base.millisecondsSinceEpoch + out.length}',
      'created_at': base,
      'location': site.isEmpty ? '위치 모름' : site,
      'defect_type': '안전',
      'priority': '긴급',
      'assignee': '',
      'content': '[안전 점검] $label${work.isEmpty ? '' : ' (작업: $work)'}',
      'is_completed': false,
      'has_image': false,
      'image_path': null,
      'image_paths': <String>[],
      'dueDate': null,
      'locationPinDx': null,
      'locationPinDy': null,
      'lastPunchReminderAt': null,
      'linkedScheduleId': null,
      'safetyRecordId': r.id,
      'safetyItem': label,
    };
    stampAuthor(m, who, created: true);
    out.add(m);
  }
  return out;
}

/// 프로젝트 저장소(시험에서 가짜로 바꿔 끼운다).
@visibleForTesting
WorkProjectRepository Function() safetyIssueRepo = WorkProjectRepository.new;

bool _activeProject(Map<String, dynamic> l) =>
    l['status'] != 'DONE' && l['archived'] != true;

/// 프로젝트를 골라 "조치 필요" 항목을 이슈로 올린다. 고르지 않으면 아무것도 안 한다.
Future<void> offerSafetyIssues(
  BuildContext context,
  SafetyRecord r, {
  WorkProjectRepository? repo,
}) async {
  final labels = safetyFixLabels(r);
  if (labels.isEmpty) return;
  final repository = repo ?? safetyIssueRepo();
  final messenger = ScaffoldMessenger.of(context);
  void say(String m) => showSnackOnce(messenger, SnackBar(content: Text(m)));

  // 폰에 있는 목록을 먼저(통신이 없어도 바로), 없으면 서버까지.
  var projects = <Map<String, dynamic>>[];
  try {
    projects = await repository.fetchCachedProjects();
  } catch (_) {}
  if (projects.isEmpty) {
    try {
      projects = await repository.fetchAllProjects();
    } catch (_) {}
  }
  projects = projects.where(_activeProject).toList();
  if (!context.mounted) return;
  if (projects.isEmpty) {
    say('이슈를 올릴 진행 중인 프로젝트가 없습니다.');
    return;
  }

  final picked = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                '조치 필요 ${labels.length}건을 이슈로 올릴 프로젝트',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                labels.join(', '),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in projects)
                    ListTile(
                      key: Key('safety_issue_project_${p['id']}'),
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(p['name']?.toString() ?? '이름 없음'),
                      onTap: () => Navigator.pop(ctx, p),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextButton(
                key: const Key('safety_issue_later'),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('나중에'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (picked == null) return;

  final adds = safetyIssuesFor(r, picked, who: currentWorkerName.value);
  final name = picked['name']?.toString() ?? '';
  if (adds.isEmpty) {
    say("이미 '$name' 이슈에 올린 항목입니다.");
    return;
  }
  picked['punch_lists'] = [...adds, ...(picked['punch_lists'] as List? ?? [])];
  // 폰에 쓰기를 넘기면 끝으로 본다(통신이 없으면 나중에 올라간다). 저장 직전에 서버 것과 합친다.
  final written = Completer<void>();
  Object? failed;
  unawaited(
    repository
        .upsertProject(
          picked,
          onWritten: () {
            if (!written.isCompleted) written.complete();
          },
        )
        .catchError((Object e) {
          failed = e;
          if (!written.isCompleted) written.complete();
        }),
  );
  try {
    await written.future.timeout(const Duration(seconds: 12));
  } on TimeoutException {
    failed = 'timeout';
  }
  if (failed != null) {
    say('이슈를 올리지 못했습니다. 통신을 확인하고 기록에서 다시 올리십시오.');
    return;
  }
  say("'$name' 이슈에 ${adds.length}건을 올렸습니다.");
}
