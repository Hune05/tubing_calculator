// 🚀 [형강 컷팅 신규] 튜브 컷팅(cutting_project_model.dart)과 컬렉션을
// 분리했다 - 형강은 피팅/공제/재고차감 개념이 전혀 없는 완전히 다른
// 데이터라, 같은 컬렉션에 섞으면 두 화면이 서로의 필드를 몰라도 되는
// 필드까지 신경 써야 한다.
const String kSteelCuttingProjectsCollection = 'steel_cutting_projects';

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

class SteelCuttingProject {
  final String id;
  final String name;
  final DateTime createdAt;
  final String currentWorker;
  double stockLength;
  List<SteelCutItem> items;

  SteelCuttingProject({
    required this.id,
    required this.name,
    required this.createdAt,
    this.currentWorker = '',
    this.stockLength = 6000.0,
    List<SteelCutItem>? items,
  }) : items = items ?? [];

  int get totalPieces => items.fold(0, (sum, i) => sum + i.qty);
  double get totalLength => items.fold(0.0, (sum, i) => sum + i.totalLength);

  Map<String, dynamic> toMap() => {
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'currentWorker': currentWorker,
    'stockLength': stockLength,
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
      items: ((map['items'] as List?) ?? [])
          .map((e) => SteelCutItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
