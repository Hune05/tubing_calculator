import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

const String kWorkProjectsCollection = 'my_projects';

// 🚀 [추가] "내 프로젝트"(모바일 WorkLogMainScreen + 데스크톱
// ProjectManagementPage가 공유하던 기능)를 기기 로컬(Hive) 저장에서
// Firestore(클라우드) 저장으로 이전한다.
//
// 기존 두 화면은 프로젝트를 전부 List<Map<String,dynamic>>로 다루고,
// 뭔가 하나만 바뀌어도 전체 리스트를 통째로 jsonEncode해서 Hive에
// 다시 쓰는 구조였다. 화면 쪽 로직(자재/일일보고/펀치리스트를 그
// Map 안에서 직접 List.insert/remove하는 부분)을 전부 다시 짜면
// 위험이 너무 커지므로, 저장 방식만 이 저장소를 거치도록 바꿨다:
// 프로젝트 하나 = Firestore 문서 하나(문서 ID는 기존에 쓰던
// `id`(생성 시각 epoch millis 문자열)를 그대로 사용), 무언가 바뀌면
// 그 프로젝트 문서 하나만 다시 쓴다 - 화면은 여전히 Map을 그대로
// 주고받고, 저장 시점만 비동기(Firestore)로 바뀐 셈이다.
class WorkProjectRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(kWorkProjectsCollection);

  // 🚀 id가 전부 DateTime.now().millisecondsSinceEpoch.toString()라서
  // 자릿수가 같은 한(2286년까지는 13자리 고정) 문자열 정렬 = 숫자 정렬과
  // 같다. 그래서 별도 createdAt 타임스탬프 없이 이 필드 하나로 최신순
  // 정렬이 가능하다 - 기존 Hive 리스트가 insert(0, ...)로 최신을 맨
  // 앞에 두던 것과 동일한 순서.
  Future<List<Map<String, dynamic>>> fetchAllProjects() async {
    await _migrateFromHiveIfNeeded();
    final snapshot = await _col.orderBy('id', descending: true).get();
    return snapshot.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data['id'] = d.id;
      return data;
    }).toList();
  }

  // 🚀 프로젝트 하나를 통째로 저장(신규 생성이든, 자재/보고/펀치 항목이
  // 바뀐 기존 프로젝트든 동일하게 이걸로 덮어쓴다) - 기존 _saveData()가
  // "지금 메모리에 있는 걸 그대로 다시 쓴다"던 방식과 동일한 개념을
  // 프로젝트 단위로 축소한 것.
  Future<void> upsertProject(Map<String, dynamic> project) async {
    final String id =
        project['id']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final data = Map<String, dynamic>.from(project);
    data['id'] = id;
    await _col.doc(id).set(data);
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
  Future<void> _migrateFromHiveIfNeeded() async {
    try {
      final existing = await _col.limit(1).get();
      if (existing.docs.isNotEmpty) return;

      if (!Hive.isBoxOpen('projectsBox')) return;
      final box = Hive.box('projectsBox');
      final String? jsonString = box.get('projectList');
      if (jsonString == null) return;

      final List<dynamic> decoded = jsonDecode(jsonString);
      if (decoded.isEmpty) return;

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
      debugPrint("✅ 내 프로젝트 ${decoded.length}건을 Firestore로 이전했습니다.");
    } catch (e) {
      debugPrint("⚠️ 내 프로젝트 Hive→Firestore 이전 실패: $e");
    }
  }
}
