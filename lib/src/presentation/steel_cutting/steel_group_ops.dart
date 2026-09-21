import '../../data/models/steel_cutting_project_model.dart';
import '../../data/models/steel_shape_db.dart';

// 입력 탭의 "규격 묶음" 작업과 입력 검사. 화면·저장과 떨어진 순수 계산이라 테스트로 지킨다.

// 한 규격 묶음의 규격을 다른 규격으로 바꾼다(길이·개수·비고·순서는 그대로, id도 그대로).
List<SteelCutItem> changeShapeOfGroup(
  List<SteelCutItem> items,
  String fromShape,
  SteelShapeItem to,
) => [
  for (final i in items)
    if (i.shapeLabel == fromShape)
      SteelCutItem(
        id: i.id,
        category: to.category,
        shapeLabel: to.label,
        length: i.length,
        qty: i.qty,
        note: i.note,
      )
    else
      i,
];

// 한 규격 묶음을 다른 규격으로 복제한 새 항목들(길이·개수·비고 그대로, 새 id).
List<SteelCutItem> duplicateGroupTo(
  List<SteelCutItem> items,
  String fromShape,
  SteelShapeItem to, {
  required String idPrefix,
}) {
  final out = <SteelCutItem>[];
  for (final i in items) {
    if (i.shapeLabel != fromShape) continue;
    out.add(
      SteelCutItem(
        id: '${idPrefix}_${out.length}',
        category: to.category,
        shapeLabel: to.label,
        length: i.length,
        qty: i.qty,
        note: i.note,
      ),
    );
  }
  return out;
}

String _lenKey(double v) => v.toStringAsFixed(1);

// 같은 규격·같은 길이로 두 건 이상 나뉘어 있는 묶음(합칠 수 있는 것).
class MergeGroup {
  final String shape;
  final double length;
  final List<String> ids;
  const MergeGroup(this.shape, this.length, this.ids);
}

List<MergeGroup> findMergeGroups(List<SteelCutItem> items) {
  final byKey = <String, List<SteelCutItem>>{};
  for (final i in items) {
    if (i.length <= 0 || i.qty <= 0) continue;
    byKey.putIfAbsent('${i.shapeLabel}|${_lenKey(i.length)}', () => []).add(i);
  }
  return [
    for (final e in byKey.values)
      if (e.length > 1)
        MergeGroup(e.first.shapeLabel, e.first.length, [
          for (final i in e) i.id,
        ]),
  ];
}

class MergeResult {
  final List<SteelCutItem> items; // 합친 뒤의 전체 목록(첫 항목 자리에 합친 항목이 온다)
  final List<SteelCutItem> kept; // 개수가 늘어난 항목(합친 결과)
  final List<SteelCutItem> removed; // 없어진 항목
  const MergeResult(this.items, this.kept, this.removed);
}

// 같은 규격·같은 길이 항목을 하나로 합친다(개수 합산, 비고는 겹치지 않게 " · "로 잇는다). 합칠 것이 없으면 그대로.
MergeResult mergeSameItems(List<SteelCutItem> items) {
  final groups = findMergeGroups(items);
  if (groups.isEmpty) return MergeResult(items, const [], const []);
  final firstOf = <String, SteelCutItem>{};
  final merged = <String, SteelCutItem>{};
  final removed = <SteelCutItem>[];
  final mergeIds = {for (final g in groups) ...g.ids};
  final out = <SteelCutItem>[];
  for (final i in items) {
    if (!mergeIds.contains(i.id)) {
      out.add(i);
      continue;
    }
    final k = '${i.shapeLabel}|${_lenKey(i.length)}';
    final first = firstOf[k];
    if (first == null) {
      firstOf[k] = i;
      merged[k] = i;
      out.add(i); // 자리 표시(아래에서 합친 값으로 바꾼다)
    } else {
      final base = merged[k]!;
      final notes = <String>[
        for (final n in base.note.split(' · '))
          if (n.trim().isNotEmpty) n.trim(),
      ];
      final add = i.note.trim();
      if (add.isNotEmpty && !notes.contains(add)) notes.add(add);
      merged[k] = SteelCutItem(
        id: base.id,
        category: base.category,
        shapeLabel: base.shapeLabel,
        length: base.length,
        qty: base.qty + i.qty,
        note: notes.join(' · '),
      );
      removed.add(i);
    }
  }
  final kept = <SteelCutItem>[];
  final result = <SteelCutItem>[];
  for (final i in out) {
    final k = '${i.shapeLabel}|${_lenKey(i.length)}';
    if (mergeIds.contains(i.id) && merged.containsKey(k)) {
      final m = merged[k]!;
      result.add(m);
      kept.add(m);
    } else {
      result.add(i);
    }
  }
  return MergeResult(result, kept, removed);
}

// 원자재 길이 [maxStock]보다 긴 항목(어떻게 배치해도 한 본에서 나오지 않는다).
List<SteelCutItem> overLengthItems(List<SteelCutItem> items, double maxStock) =>
    [
      for (final i in items)
        if (maxStock > 0 && i.length > maxStock) i,
    ];

// 원자재 기준 길이의 위쪽 한계(mm).
const double kMaxStockLengthMm = 20000;

// 원자재 기준 길이 창에 적은 글이 잘못됐으면 그 까닭, 괜찮으면 null.
String? stockLengthError(String text) {
  final v = double.tryParse(text.trim());
  if (v == null || !v.isFinite) return '숫자로 적어 주십시오.';
  if (v <= 0) return '0보다 큰 길이를 적어 주십시오.';
  if (v > kMaxStockLengthMm) return '20000mm 이하로 적어 주십시오.';
  return null;
}

// 한 규격 묶음의 항목을 [ordered] 순서로 다시 놓는다. 그 묶음이 쓰던 자리(전체 목록에서의 위치)는 그대로
// 두고 그 자리에만 새 순서로 넣어서, 다른 규격 항목은 움직이지 않는다.
List<SteelCutItem> applyShapeOrder(
  List<SteelCutItem> items,
  String shape,
  List<SteelCutItem> ordered,
) {
  final slots = [
    for (var i = 0; i < items.length; i++)
      if (items[i].shapeLabel == shape) i,
  ];
  if (slots.length != ordered.length) return items;
  final out = List.of(items);
  for (var k = 0; k < slots.length; k++) {
    out[slots[k]] = ordered[k];
  }
  return out;
}
