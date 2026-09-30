// 서버에 아직 닿지 않은 저장이 "어느 프로젝트의 무엇"인지 적어 두는 메모(앱이 켜져 있는 동안만).
// 통신이 없으면 저장은 폰에 먼저 쓰이고 연결될 때 올라가는데, 그동안 몇 건인지만 알았지
// 어느 프로젝트인지는 몰랐다. 화면(저장 대기 목록)이 이걸 읽는다.
import 'package:flutter/foundation.dart';

/// 서버 확인을 기다리는 저장 하나.
class PendingWrite {
  final int token;
  final String projectId;
  final String projectName;
  final String kind; // kPendingKindSave / kPendingKindSchedule
  final DateTime since;
  const PendingWrite({
    required this.token,
    required this.projectId,
    required this.projectName,
    required this.kind,
    required this.since,
  });
}

const String kPendingKindSave = '변경 내용 저장';
const String kPendingKindSchedule = '일정 완료 표시';

/// 프로젝트 하나에 몰린 대기 저장.
class PendingProjectGroup {
  final String projectId;
  final String projectName;
  final int count;
  final DateTime oldest;
  final List<String> kinds; // 중복 없이, 처음 나온 순서
  const PendingProjectGroup({
    required this.projectId,
    required this.projectName,
    required this.count,
    required this.oldest,
    required this.kinds,
  });
}

class PendingWriteLog {
  final ValueNotifier<List<PendingWrite>> entries = ValueNotifier(const []);
  int _next = 0;

  /// 저장을 시작할 때 부르고, 돌려받은 번호로 끝날 때 [end]를 부른다.
  int begin({
    required String projectId,
    required String projectName,
    required String kind,
    DateTime? now,
  }) {
    final token = _next++;
    entries.value = [
      ...entries.value,
      PendingWrite(
        token: token,
        projectId: projectId,
        projectName: projectName.trim().isEmpty ? '이름 없는 프로젝트' : projectName,
        kind: kind,
        since: now ?? DateTime.now(),
      ),
    ];
    return token;
  }

  void end(int token) {
    final next = entries.value.where((e) => e.token != token).toList();
    if (next.length != entries.value.length) entries.value = next;
  }

  /// 프로젝트별로 묶는다. 가장 오래 기다린 것이 위로 온다.
  static List<PendingProjectGroup> groupByProject(List<PendingWrite> list) {
    final byId = <String, List<PendingWrite>>{};
    for (final e in list) {
      (byId[e.projectId] ??= []).add(e);
    }
    final groups = [
      for (final g in byId.values)
        PendingProjectGroup(
          projectId: g.first.projectId,
          projectName: g.first.projectName,
          count: g.length,
          oldest: g.map((e) => e.since).reduce((a, b) => a.isBefore(b) ? a : b),
          kinds: [
            for (final k in {for (final e in g) e.kind}) k,
          ],
        ),
    ];
    groups.sort((a, b) => a.oldest.compareTo(b.oldest));
    return groups;
  }

  /// "루마" / "루마 외 2곳".
  static String namesLabel(List<PendingWrite> list) {
    final groups = groupByProject(list);
    if (groups.isEmpty) return '';
    if (groups.length == 1) return groups.first.projectName;
    return '${groups.first.projectName} 외 ${groups.length - 1}곳';
  }
}

/// "방금", "12분째", "3시간째", "2일째".
String waitingLabel(DateTime since, DateTime now) {
  final d = now.difference(since);
  if (d.inMinutes < 1) return '방금부터';
  if (d.inMinutes < 60) return '${d.inMinutes}분째';
  if (d.inHours < 24) return '${d.inHours}시간째';
  return '${d.inDays}일째';
}
