import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../presentation/my_work_logs/models/project_merge.dart';

const String kWorkProjectsCollection = 'my_projects';

// [schedules](프로젝트 문서의 일정 목록)에서 id가 [scheduleId]인 일정의 완료 표시를 [done]으로 바꾼
// 새 목록. 그 일정이 없으면 null(아무것도 쓰지 않게).
List<Map<String, dynamic>>? scheduleListWithCompleted(
  Object? schedules,
  String scheduleId,
  bool done,
) {
  if (schedules is! List) return null;
  final list = [
    for (final e in schedules)
      if (e is Map) Map<String, dynamic>.from(e),
  ];
  final idx = list.indexWhere((s) => s['id']?.toString() == scheduleId);
  if (idx < 0) return null;
  list[idx]['isCompleted'] = done;
  return list;
}

// 🚀 [추가] "내 프로젝트"(모바일 WorkLogMainScreen + 데스크톱
// ProjectManagementPage가 공유하던 기능)를 기기 로컬(Hive) 저장에서
// Firestore(클라우드) 저장으로 이전한다.
//
// 기존 두 화면은 프로젝트를 전부 List<Map<String,dynamic>>로 다루고,
// 뭔가 하나만 바뀌어도 전체 리스트를 통째로 jsonEncode해서 Hive에
// 다시 쓰는 구조였다. 화면 쪽 로직(자재/일작업 일지고/펀치리스트를 그
// Map 안에서 직접 List.insert/remove하는 부분)을 전부 다시 짜면
// 위험이 너무 커지므로, 저장 방식만 이 저장소를 거치도록 바꿨다:
// 프로젝트 하나 = Firestore 문서 하나(문서 ID는 기존에 쓰던
// `id`(생성 시간 epoch millis 문자열)를 그대로 사용), 무언가 바뀌면
// 그 프로젝트 문서 하나만 다시 쓴다 - 화면은 여전히 Map을 그대로
// 주고받고, 저장 시점만 비동기(Firestore)로 바뀐 셈이다.
class WorkProjectRepository {
  // 처음 쓸 때 가져온다(테스트에서 이 저장소를 흉내 낸 것을 만들 때 Firebase가 없어도 되게).
  late final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 서버에 아직 반영되지 않은 저장 개수. Firestore는 오프라인에서도 로컬에 먼저
  // 쓰고 연결되면 자동으로 올리는데, 서버 확인이 올 때까지 이 값이 1 이상이라
  // 화면에서 "동기화 대기 중"을 보여줄 수 있다.
  static final ValueNotifier<int> pendingWrites = ValueNotifier<int>(0);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(kWorkProjectsCollection);

  // 🚀 id가 전부 DateTime.now().millisecondsSinceEpoch.toString()라서
  // 자릿수가 같은 한(2286년까지는 13자리 고정) 문자열 정렬 = 숫자 정렬과
  // 같다. 그래서 별도 createdAt 타임스탬프 없이 이 필드 하나로 최신순
  // 정렬이 가능하다 - 기존 Hive 리스트가 insert(0, ...)로 최신을 맨
  // 앞에 두던 것과 동일한 순서.
  Future<List<Map<String, dynamic>>> fetchAllProjects() async {
    await _migrateFromHiveIfNeeded();
    // 통신이 없으면 서버 확인이 끝나지 않아 목록이 영영 돌던 것: 6초 뒤 폰에 있는 것으로.
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _col
          .orderBy('id', descending: true)
          .get()
          .timeout(const Duration(seconds: 6));
    } on TimeoutException {
      snapshot = await _col
          .orderBy('id', descending: true)
          .get(const GetOptions(source: Source.cache));
    }
    return snapshot.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data['id'] = d.id;
      // 아이디 없는 예전 일지에 아이디를 붙인다(다음 저장부터 아이디로 합쳐진다).
      ensureItemIds(data);
      return data;
    }).toList();
  }

  // 🚀 프로젝트 하나를 통째로 저장(신규 생성이든, 자재/보고/펀치 항목이
  // 바뀐 기존 프로젝트든 동일하게 이걸로 덮어쓴다) - 기존 _saveData()가
  // "지금 메모리에 있는 걸 그대로 다시 쓴다"던 방식과 동일한 개념을
  // 프로젝트 단위로 축소한 것.
  Future<void> upsertProject(
    Map<String, dynamic> project, {
    bool merge = true,
  }) async {
    final String id =
        project['id']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();
    ensureItemIds(project);
    var data = Map<String, dynamic>.from(project);
    data['id'] = id;
    if (merge) {
      // 저장 직전에 서버 것을 읽어 아이디로 합친다(다른 폰이 그 사이 넣은 일지·이슈가
      // 안 지워지게). 통신이 없으면 5초 뒤 폰 캐시로, 그것도 없으면 예전처럼 그대로.
      Map<String, dynamic>? server;
      try {
        server = (await _col.doc(id).get().timeout(const Duration(seconds: 5)))
            .data();
      } catch (_) {
        try {
          server =
              (await _col.doc(id).get(const GetOptions(source: Source.cache)))
                  .data();
        } catch (_) {}
      }
      if (server != null) {
        data = mergeProjectDocs(local: data, server: server);
        // 화면이 들고 있는 것도 합친 대로(다른 폰이 넣은 것이 바로 보이게).
        for (final key in kMergedListKeys) {
          if (data.containsKey(key)) project[key] = data[key];
        }
        if (data.containsKey(kDeletedIdsKey)) {
          project[kDeletedIdsKey] = data[kDeletedIdsKey];
        }
      }
    }
    pendingWrites.value++;
    try {
      await _col.doc(id).set(data);
    } finally {
      pendingWrites.value--;
    }
  }

  // 프로젝트 일정 하나의 완료 표시만 바꾼다. 저장하기 직전에 문서를 다시 읽어 schedules 칸만
  // 고쳐 쓰므로, 화면을 연 뒤 다른 폰에서 넣은 일지·이슈·일정이 지워지지 않는다.
  // 문서나 일정을 찾지 못하면 아무것도 쓰지 않는다.
  Future<void> setScheduleCompleted(
    String projectId,
    String scheduleId,
    bool done,
  ) async {
    final ref = _col.doc(projectId);
    final snap = await ref.get();
    final updated = scheduleListWithCompleted(
      snap.data()?['schedules'],
      scheduleId,
      done,
    );
    if (updated == null) return;
    pendingWrites.value++;
    try {
      await ref.update({'schedules': updated});
    } finally {
      pendingWrites.value--;
    }
  }

  Future<void> deleteProject(String id) async {
    await _col.doc(id).delete();
  }

  // 🚀 [추가] 기존 Hive('projectsBox'/'projectList')에 남아있던 데이터를
  // 딱 한 번 Firestore로 올려준다. Firestore 쪽에 이미 프로젝트가
  // 하나라도 있으면(=이미 이전했거나 새로 클라우드에서 시작한 경우)
  // 다시 실행하지 않는다. Hive 데이터는 안전하게 그대로 남겨두고
  // (삭제하지 않음) 그냥 더 이상 읽지 않을 뿐이라, 뭔가 잘못돼도
  // 원본은 남아있다.
  static const String _migratedFlag = 'hive_projects_migrated_v1';

  Future<void> _migrateFromHiveIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_migratedFlag) == true) return;
      final existing = await _col.limit(1).get();
      // 통신이 없어 폰 캐시(비어 있을 수 있음)로 답하면 판단하지 않는다. 예전엔 이때
      // "서버에 없다"로 보고 옛 Hive 자료를 서버 것 위에 덮어썼다.
      if (existing.metadata.isFromCache) return;
      if (existing.docs.isNotEmpty) {
        await prefs.setBool(_migratedFlag, true);
        return;
      }

      if (!Hive.isBoxOpen('projectsBox')) return;
      final box = Hive.box('projectsBox');
      final String? jsonString = box.get('projectList');
      if (jsonString == null) {
        await prefs.setBool(_migratedFlag, true);
        return;
      }

      final List<dynamic> decoded = jsonDecode(jsonString);
      if (decoded.isEmpty) {
        await prefs.setBool(_migratedFlag, true);
        return;
      }

      final batch = _db.batch();
      for (final raw in decoded) {
        final project = Map<String, dynamic>.from(raw as Map);
        final String id =
            project['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString();
        project['id'] = id;
        batch.set(_col.doc(id), project);
      }
      await batch.commit();
      await prefs.setBool(_migratedFlag, true);
      debugPrint("✅ 내 프로젝트 ${decoded.length}건을 Firestore로 이전했습니다.");
    } catch (e) {
      debugPrint("⚠️ 내 프로젝트 Hive→Firestore 이전 실패: $e");
    }
  }
}
