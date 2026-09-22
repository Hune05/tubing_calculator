// 프로젝트 문서를 여러 폰이 같이 쓸 때의 순수한 셈: 저장 전 합치기, 항목 아이디 붙이기,
// 누가 썼는지 남기기. 서버·화면 일은 저장소와 화면이 한다.
//
// 예전엔 저장이 문서를 통째로 덮어써서, 두 폰이 같은 프로젝트를 열고 있으면 한쪽이 넣은
// 일지·이슈가 다른 쪽 저장에 지워졌다. 이제 저장 직전에 서버 것을 읽어 아이디로 합친다.
import 'package:flutter/foundation.dart';

/// 지금 이 폰을 쓰는 사람 이름(내 프로젝트 화면이 열릴 때 넣는다). 일지·이슈에 작성자로 남기고
/// "내 이슈" 필터에 쓴다. 이름이 없으면 빈 글.
final ValueNotifier<String> currentWorkerName = ValueNotifier('');

/// 아이디로 합치는 목록 칸. 자재는 아이디가 없는 것이 많아 뺀다(폰 것이 이긴다).
const List<String> kMergedListKeys = [
  'daily_reports',
  'punch_lists',
  'schedules',
  'phases',
];

/// 지운 항목 아이디를 적어 두는 칸(합칠 때 서버에 남은 것이 되살아나지 않게). 최대 500개.
const String kDeletedIdsKey = 'deletedIds';
const int _kMaxDeletedIds = 500;

String? _idOf(dynamic m) => m is Map ? m['id']?.toString() : null;

DateTime? _updatedAt(dynamic m) {
  if (m is! Map) return null;
  final raw = m['updatedAt'];
  if (raw is String) return DateTime.tryParse(raw);
  if (raw is DateTime) return raw;
  return null;
}

/// 아이디 없는 일지에 아이디를 붙인다(한 번 저장되면 그 뒤로는 아이디로 합친다).
/// 이슈·일정·단계는 원래 아이디가 있다. 바뀐 게 있으면 true.
bool ensureItemIds(Map<String, dynamic> project) {
  var changed = false;
  for (final key in kMergedListKeys) {
    final list = project[key];
    if (list is! List) continue;
    for (var i = 0; i < list.length; i++) {
      final m = list[i];
      if (m is! Map) continue;
      if ((m['id']?.toString() ?? '').isEmpty) {
        m['id'] = '${key}_${DateTime.now().microsecondsSinceEpoch}_$i';
        changed = true;
      }
    }
  }
  return changed;
}

/// 저장 직전에 서버 문서와 합친다. 폰([local])이 기준이고, 서버([server])에만 있는
/// 아이디 항목은 살려 둔다(다른 폰이 그 사이 넣은 것). 같은 아이디는 updatedAt이 늦은 쪽,
/// 모르면 폰 것. 지운 아이디([kDeletedIdsKey])는 어느 쪽에 있어도 뺀다.
/// 아이디 없는 서버 항목은 예전처럼 폰 것으로 덮는다(무엇과 같은지 알 수 없어서).
Map<String, dynamic> mergeProjectDocs({
  required Map<String, dynamic> local,
  required Map<String, dynamic>? server,
}) {
  final out = Map<String, dynamic>.from(local);
  if (server == null) return out;

  final deleted = <String>{
    ...((local[kDeletedIdsKey] as List?) ?? const []).map((e) => e.toString()),
    ...((server[kDeletedIdsKey] as List?) ?? const []).map((e) => e.toString()),
  };
  if (deleted.isNotEmpty) {
    out[kDeletedIdsKey] = deleted
        .toList()
        .reversed
        .take(_kMaxDeletedIds)
        .toList()
        .reversed
        .toList();
  }

  for (final key in kMergedListKeys) {
    final localList = (local[key] as List?) ?? const [];
    final serverList = (server[key] as List?) ?? const [];
    final byId = <String, dynamic>{};
    final merged = <dynamic>[];
    for (final m in localList) {
      final id = _idOf(m);
      if (id != null && deleted.contains(id)) continue;
      merged.add(m);
      if (id != null) byId[id] = m;
    }
    for (final s in serverList) {
      final id = _idOf(s);
      if (id == null || deleted.contains(id)) continue;
      final mine = byId[id];
      if (mine == null) {
        // 다른 폰이 넣은 것. 일지는 최신이 앞이라 앞에, 나머지는 뒤에 둔다.
        if (key == 'daily_reports') {
          merged.insert(0, s);
        } else {
          merged.add(s);
        }
        byId[id] = s;
        continue;
      }
      final sAt = _updatedAt(s);
      final mAt = _updatedAt(mine);
      if (sAt != null && (mAt == null || sAt.isAfter(mAt))) {
        merged[merged.indexOf(mine)] = s;
        byId[id] = s;
      }
    }
    if (localList.isNotEmpty || serverList.isNotEmpty) out[key] = merged;
  }
  return out;
}

/// 항목을 지울 때 아이디를 적어 둔다(합칠 때 되살아나지 않게).
void markItemDeleted(Map<String, dynamic> project, String? id) {
  if (id == null || id.isEmpty) return;
  final list = List<String>.from(
    ((project[kDeletedIdsKey] as List?) ?? const []).map((e) => e.toString()),
  );
  if (!list.contains(id)) list.add(id);
  while (list.length > _kMaxDeletedIds) {
    list.removeAt(0);
  }
  project[kDeletedIdsKey] = list;
}

/// 일지·이슈에 누가 언제 썼는지 남긴다. 새로 만들 때는 author·createdAtBy, 고칠 때는 updatedBy.
/// [who]가 비어 있으면 이름은 안 적고 시각만 적는다.
void stampAuthor(
  Map<String, dynamic> item,
  String who, {
  required bool created,
}) {
  final now = DateTime.now().toIso8601String();
  final name = who.trim();
  if (created) {
    if ((item['author']?.toString() ?? '').isEmpty && name.isNotEmpty) {
      item['author'] = name;
    }
    item['authoredAt'] ??= now;
  } else {
    if (name.isNotEmpty) item['updatedBy'] = name;
  }
  item['updatedAt'] = now;
}

String _short(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.month}/${d.day} ${two(d.hour)}:${two(d.minute)}';
}

/// 목록 줄에 붙이는 "홍길동 · 9/23 18:02 고침" 같은 글. 아무것도 없으면 빈 글.
String authorLabel(Map item) {
  final author = item['author']?.toString().trim() ?? '';
  final updatedBy = item['updatedBy']?.toString().trim() ?? '';
  final at = _updatedAt(item);
  final authoredAt = item['authoredAt'] is String
      ? DateTime.tryParse(item['authoredAt'] as String)
      : null;
  final parts = <String>[];
  if (author.isNotEmpty) {
    parts.add(authoredAt != null ? '$author ${_short(authoredAt)}' : author);
  }
  if (updatedBy.isNotEmpty &&
      at != null &&
      (authoredAt == null ||
          at.isAfter(authoredAt.add(const Duration(minutes: 1))))) {
    parts.add('$updatedBy ${_short(at)} 고침');
  }
  return parts.join(' · ');
}
