import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart'; // 🚀 Hive 연동을 위해 추가

class CuttingProject {
  final String id;
  final String name;
  final DateTime createdAt;
  double totalTubeUsed;
  int cutCount;

  // 🚀 [추가됨] 이 프로젝트에서 사용된 피팅들의 수량을 기록하는 장부
  Map<String, int> usedFittings;

  CuttingProject({
    required this.id,
    required this.name,
    required this.createdAt,
    this.totalTubeUsed = 0.0,
    this.cutCount = 0,
    Map<String, int>? usedFittings, // 생성자 추가
  }) : usedFittings = usedFittings ?? {}; // 기본값은 빈 맵

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'totalTubeUsed': totalTubeUsed,
      'cutCount': cutCount,
      'usedFittings': usedFittings, // 🚀 맵 변환 시 포함
    };
  }

  String get estimatedMeters => (totalTubeUsed / 1000).toStringAsFixed(1);

  // 기존 함수 (하위 호환성을 위해 남겨둠)
  void addCutLength(double length) {
    totalTubeUsed += length;
    cutCount += 1;
  }

  // 🚀 [핵심 연동 로직] 컷팅 스크린에서 넘어온 데이터를 Hive DB에 직접 꽂아줍니다!
  void recordUsage({
    required double tubeLengthMm,
    required Map<String, int> fittings,
    required int multiplier,
  }) {
    // 1. 현재 메모리(화면) 상태 업데이트
    totalTubeUsed += tubeLengthMm;
    cutCount += multiplier;
    fittings.forEach((fittingName, count) {
      usedFittings[fittingName] =
          (usedFittings[fittingName] ?? 0) + (count * multiplier);
    });

    // 2. 💡 가장 중요한 부분: Hive DB를 열어서 ProjectManagementPage와 동일한 형식으로 덮어쓰기
    try {
      var box = Hive.box('projectsBox');
      String? jsonStr = box.get('projectList');

      if (jsonStr != null) {
        List<dynamic> decoded = jsonDecode(jsonStr);
        List<Map<String, dynamic>> projects = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        // 현재 작업 중인 프로젝트를 ID로 찾기
        int index = projects.indexWhere((p) => p['id'] == id);

        if (index != -1) {
          // 관리 페이지에서 쓰는 materials 리스트 가져오기 (없으면 빈 리스트)
          List<dynamic> materials = projects[index]['materials'] ?? [];

          // -----------------------------------------
          // [A] 튜브 사용량 (TUBE) 합산 로직
          // -----------------------------------------
          int tubeIndex = materials.indexWhere((m) => m['type'] == 'TUBE');
          if (tubeIndex != -1) {
            materials[tubeIndex]['qty_mm'] =
                (materials[tubeIndex]['qty_mm'] ?? 0) + tubeLengthMm.toInt();
          } else {
            materials.add({
              "db_name": "TUBE_기본규격", // Firebase 재고 DB에 등록된 튜브 이름과 맞춰주세요!
              "type": "TUBE",
              "qty_mm": tubeLengthMm.toInt(),
            });
          }

          // -----------------------------------------
          // [B] 피팅 사용량 (FITTING) 합산 로직
          // -----------------------------------------
          fittings.forEach((fittingName, count) {
            int totalCount = count * multiplier;
            int fitIndex = materials.indexWhere(
              (m) => m['db_name'] == fittingName,
            );

            if (fitIndex != -1) {
              materials[fitIndex]['qty_ea'] =
                  (materials[fitIndex]['qty_ea'] ?? 0) + totalCount;
            } else {
              materials.add({
                "db_name": fittingName,
                "type": "FITTING",
                "qty_ea": totalCount,
              });
            }
          });

          // 업데이트된 materials를 다시 프로젝트에 넣고 Hive에 저장!
          projects[index]['materials'] = materials;
          box.put('projectList', jsonEncode(projects));
        }
      }
    } catch (e) {
      print("Hive 데이터 업데이트 실패: $e");
    }
  }
}

class CutRecord {
  final String id;
  final String projectId;
  final DateTime timestamp;

  final String tubeSize;
  final double originalLength;
  final String startFitting;
  final String endFitting;
  final double cutLength;

  CutRecord({
    required this.id,
    required this.projectId,
    required this.timestamp,
    required this.tubeSize,
    required this.originalLength,
    required this.startFitting,
    required this.endFitting,
    required this.cutLength,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'timestamp': timestamp.toIso8601String(),
      'tubeSize': tubeSize,
      'originalLength': originalLength,
      'startFitting': startFitting,
      'endFitting': endFitting,
      'cutLength': cutLength,
    };
  }
}
