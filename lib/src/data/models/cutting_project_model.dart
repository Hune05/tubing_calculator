class CuttingProject {
  final String id;
  final String name;
  final DateTime createdAt;
  double totalTubeUsed;
  int cutCount;

  CuttingProject({
    required this.id,
    required this.name,
    required this.createdAt,
    this.totalTubeUsed = 0.0,
    this.cutCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'totalTubeUsed': totalTubeUsed,
      'cutCount': cutCount,
    };
  }

  String get estimatedMeters => (totalTubeUsed / 1000).toStringAsFixed(1);

  // ★ 이 함수가 반드시 있어야 합니다!
  void addCutLength(double length) {
    totalTubeUsed += length;
    cutCount += 1;
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
