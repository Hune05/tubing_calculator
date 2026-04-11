import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class LocalArchiveService {
  // 기존 프로젝트 박스 이름을 그대로 사용 (데이터 호환 유지)
  final Box _myBox = Hive.box('projectsBox');

  /// 저장된 작업 일지 리스트 불러오기
  List<Map<String, dynamic>> loadLogs() {
    final String? jsonString = _myBox.get('projectList');
    if (jsonString != null) {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// 작업 일지 리스트 저장하기
  void saveLogs(List<Map<String, dynamic>> logs) {
    _myBox.put('projectList', jsonEncode(logs));
  }
}
