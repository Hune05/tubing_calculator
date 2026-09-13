// 🚀 [추가] 모바일 컷팅 프로젝트가 Firestore에 저장되는 컬렉션 이름.
// 프로젝트 목록 화면과 프로젝트 내부 화면(계산기/기록)이 같은 이름을
// 참조해야 해서 여기 한 곳에만 정의해두고 공유한다.
const String kCuttingProjectsCollection = 'cutting_projects';
const String kCutRecordsSubcollection = 'cut_records';

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

  // 🚀 [추가] Firestore 문서 등에서 역직렬화할 때 쓰는 팩토리 생성자.
  factory CuttingProject.fromMap(String docId, Map<String, dynamic> map) {
    DateTime parsedDate;
    final rawDate = map['createdAt'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }
    return CuttingProject(
      id: docId,
      name: map['name'] ?? '이름 없음',
      createdAt: parsedDate,
      totalTubeUsed: (map['totalTubeUsed'] as num?)?.toDouble() ?? 0.0,
      cutCount: (map['cutCount'] as num?)?.toInt() ?? 0,
      usedFittings: (map['usedFittings'] as Map?)?.map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      ),
    );
  }

  String get estimatedMeters => (totalTubeUsed / 1000).toStringAsFixed(1);

  // 기존 함수 (하위 호환성을 위해 남겨둠)
  void addCutLength(double length) {
    totalTubeUsed += length;
    cutCount += 1;
  }

  // 🚀 [버그 수정] 예전엔 이 함수가 자기 스스로 Hive DB 파일을 열어서
  // ProjectManagementPage의 projectList를 직접 덮어썼다. 그런데 그 화면은
  // onSaveCallback을 통해 이미 같은 데이터를 저장하고 있어서, 결국 같은
  // 정보가 두 경로로 중복 기록되는 fragile한 구조였다 (모델 클래스가
  // 화면 저장소 내부 구현을 직접 알고 건드리는 것 자체도 잘못된 설계).
  // 이 함수는 이제 순수하게 메모리 상의 이 객체 값만 갱신하고, 실제
  // 영속 저장은 호출한 화면(onSaveCallback)이 책임지도록 분리했다.
  void recordUsage({
    required double tubeLengthMm,
    required Map<String, int> fittings,
    required int multiplier,
  }) {
    totalTubeUsed += tubeLengthMm;
    cutCount += multiplier;
    fittings.forEach((fittingName, count) {
      usedFittings[fittingName] =
          (usedFittings[fittingName] ?? 0) + (count * multiplier);
    });
  }
}

// 🚀 [기존엔 만들어만 놓고 어디서도 안 쓰던 모델] "완료(저장)" 할 때마다
// 구간별로 하나씩 만들어서 Firestore 서브컬렉션에 기록한다 - 프로젝트
// 안의 "기록" 탭에서 날짜/요일별로 묶어서 보여주는 데 쓴다.
class CutRecord {
  final String id;
  final String projectId;
  final DateTime timestamp;

  final String tubeSize;
  final double originalLength;
  final String startFitting;
  final String endFitting;
  final double cutLength;
  final int multiplier;

  // 🚀 [추가] 나중에 똑같은 걸 다시 잘라야 할 때 재현 가능하도록 - 제조사와
  // 양쪽 부속의 공제값까지 남긴다. 이름만으로는 어느 제조사 제품인지,
  // 공제값이 얼마였는지 알 수 없어서 재주문/재작업 시 정보가 부족했다.
  final String maker;
  final double startDeduction;
  final double endDeduction;

  const CutRecord({
    required this.id,
    required this.projectId,
    required this.timestamp,
    required this.tubeSize,
    required this.originalLength,
    required this.startFitting,
    required this.endFitting,
    required this.cutLength,
    this.multiplier = 1,
    this.maker = '',
    this.startDeduction = 0.0,
    this.endDeduction = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'timestamp': timestamp.toIso8601String(),
      'tubeSize': tubeSize,
      'originalLength': originalLength,
      'startFitting': startFitting,
      'endFitting': endFitting,
      'cutLength': cutLength,
      'multiplier': multiplier,
      'maker': maker,
      'startDeduction': startDeduction,
      'endDeduction': endDeduction,
    };
  }

  factory CutRecord.fromMap(String id, Map<String, dynamic> map) {
    DateTime parsedDate;
    final rawDate = map['timestamp'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }
    return CutRecord(
      id: id,
      projectId: map['projectId'] ?? '',
      timestamp: parsedDate,
      tubeSize: map['tubeSize'] ?? '',
      originalLength: (map['originalLength'] as num?)?.toDouble() ?? 0.0,
      startFitting: map['startFitting'] ?? '',
      endFitting: map['endFitting'] ?? '',
      cutLength: (map['cutLength'] as num?)?.toDouble() ?? 0.0,
      multiplier: (map['multiplier'] as num?)?.toInt() ?? 1,
      maker: map['maker'] ?? '',
      startDeduction: (map['startDeduction'] as num?)?.toDouble() ?? 0.0,
      endDeduction: (map['endDeduction'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
