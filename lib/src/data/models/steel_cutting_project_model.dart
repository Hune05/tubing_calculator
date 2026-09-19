import 'package:cloud_firestore/cloud_firestore.dart';

// 🚀 [형강 컷팅 신규] 튜브 컷팅(cutting_project_model.dart)과 컬렉션을
// 분리했다 - 형강은 피팅/공제/재고차감 개념이 전혀 없는 완전히 다른
// 데이터라, 같은 컬렉션에 섞으면 두 화면이 서로의 필드를 몰라도 되는
// 필드까지 신경 써야 한다.
const String kSteelCuttingProjectsCollection = 'steel_cutting_projects';
const String kSteelChangeLogSubcollection = 'change_log';

class SteelCutItem {
  final String id;
  final String category; // 'ANGLE' | 'CHANNEL' | 'CUSTOM'
  final String shapeLabel;
  final double length; // mm
  final int qty;
  final String note;

  const SteelCutItem({
    required this.id,
    required this.category,
    required this.shapeLabel,
    required this.length,
    required this.qty,
    this.note = '',
  });

  double get totalLength => length * qty;

  Map<String, dynamic> toMap() => {
    'id': id,
    'category': category,
    'shapeLabel': shapeLabel,
    'length': length,
    'qty': qty,
    'note': note,
  };

  factory SteelCutItem.fromMap(Map<String, dynamic> map) => SteelCutItem(
    id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
    category: map['category'] ?? 'CUSTOM',
    shapeLabel: map['shapeLabel'] ?? '규격 미지정',
    length: (map['length'] as num?)?.toDouble() ?? 0.0,
    qty: (map['qty'] as num?)?.toInt() ?? 1,
    note: map['note'] ?? '',
  );
}

// 🚀 [형강 컷팅 기록 신규] 형강은 튜브처럼 "완료" 시점에 세션을 저장하는
// 개념이 없다 - 항목이 계속 살아있는 목록에 바로바로 반영된다. 그래서
// "컷팅 기록"은 튜브의 CutRecord(완료한 절단 세션)와 다르게, 언제 어떤
// 항목을 추가/수정/삭제/복제했는지 자동으로 남기는 변경 기록이다.
class SteelChangeLogEntry {
  final String id;
  final String action; // 'ADD' | 'EDIT' | 'DELETE' | 'DUPLICATE'
  final String category;
  final String shapeLabel;
  final double length;
  final int qty;
  final String note;
  final DateTime timestamp;

  const SteelChangeLogEntry({
    required this.id,
    required this.action,
    required this.category,
    required this.shapeLabel,
    required this.length,
    required this.qty,
    this.note = '',
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'action': action,
    'category': category,
    'shapeLabel': shapeLabel,
    'length': length,
    'qty': qty,
    'note': note,
    'timestamp': FieldValue.serverTimestamp(),
  };

  factory SteelChangeLogEntry.fromMap(String id, Map<String, dynamic> map) {
    final rawTs = map['timestamp'];
    final timestamp = rawTs is Timestamp ? rawTs.toDate() : DateTime.now();
    return SteelChangeLogEntry(
      id: id,
      action: map['action'] ?? 'ADD',
      category: map['category'] ?? 'CUSTOM',
      shapeLabel: map['shapeLabel'] ?? '규격 미지정',
      length: (map['length'] as num?)?.toDouble() ?? 0.0,
      qty: (map['qty'] as num?)?.toInt() ?? 1,
      note: map['note'] ?? '',
      timestamp: timestamp,
    );
  }
}

class SteelCuttingProject {
  final String id;
  final String name;
  final DateTime createdAt;
  final String currentWorker;
  double stockLength;
  int setMultiplier;
  List<SteelCutItem> items;

  SteelCuttingProject({
    required this.id,
    required this.name,
    required this.createdAt,
    this.currentWorker = '',
    this.stockLength = 6000.0,
    this.setMultiplier = 1,
    List<SteelCutItem>? items,
  }) : items = items ?? [];

  int get totalPieces => items.fold(0, (sum, i) => sum + i.qty) * setMultiplier;
  double get totalLength =>
      items.fold(0.0, (sum, i) => sum + i.totalLength) * setMultiplier;

  Map<String, dynamic> toMap() => {
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'currentWorker': currentWorker,
    'stockLength': stockLength,
    'setMultiplier': setMultiplier,
    'items': items.map((e) => e.toMap()).toList(),
  };

  factory SteelCuttingProject.fromMap(String docId, Map<String, dynamic> map) {
    final rawDate = map['createdAt'];
    final createdAt = rawDate is String
        ? (DateTime.tryParse(rawDate) ?? DateTime.now())
        : DateTime.now();
    return SteelCuttingProject(
      id: docId,
      name: map['name'] ?? '이름 없음',
      createdAt: createdAt,
      currentWorker: map['currentWorker'] ?? '',
      stockLength: (map['stockLength'] as num?)?.toDouble() ?? 6000.0,
      setMultiplier: (map['setMultiplier'] as num?)?.toInt() ?? 1,
      items: ((map['items'] as List?) ?? [])
          .map((e) => SteelCutItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
