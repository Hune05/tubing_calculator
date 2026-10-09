// 형강 컷팅 항목 목록을 저장 직전에 서버 것과 합치는 셈(8차, 10-09).
//
// 예전에는 화면을 열 때 받은 항목 목록을 통째로 다시 써서(update items), 그 사이 다른 기기에서 넣은
// 줄이 사라졌다. 통신 없이 두 기기가 따로 고친 뒤 올라가도 마지막에 쓴 쪽만 남았다.
// 이제 저장할 때마다 서버(폰 사본) 목록을 읽어 아이디로 합친다.
// - [base]: 이 화면이 마지막으로 서버와 맞춘 목록. "내가 고쳤나"를 가리는 기준.
// - 지운 항목 아이디는 문서의 [kSteelDeletedIdsField]에 남긴다(다른 기기 목록에 남은 것이 되살아나지 않게).
library;

import '../../data/models/steel_cutting_project_model.dart';

/// 지운 항목 아이디 칸(최근 500개).
const String kSteelDeletedIdsField = 'deletedItemIds';
const int _kMaxDeletedIds = 500;

bool sameSteelItem(SteelCutItem a, SteelCutItem b) =>
    a.id == b.id &&
    a.category == b.category &&
    a.shapeLabel == b.shapeLabel &&
    a.length == b.length &&
    a.qty == b.qty &&
    a.note == b.note;

bool sameSteelItems(List<SteelCutItem> a, List<SteelCutItem> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!sameSteelItem(a[i], b[i])) return false;
  }
  return true;
}

class SteelItemsMerge {
  final List<SteelCutItem> items;
  final List<String> deletedIds;
  const SteelItemsMerge(this.items, this.deletedIds);
}

/// 폰([local])을 기준으로 서버([server])와 합친다.
/// - 내가 넣었거나 고친 항목(기준에 없거나 기준과 다름)은 내 것.
/// - 내가 손대지 않은 항목은 서버 것(다른 기기가 고친 길이·개수를 따른다). 서버가 지웠다고 적었으면 뺀다.
/// - 서버에만 있는 항목은 다른 기기가 넣은 것이라 뒤에 붙인다. 내가 지운 것(기준에 있고 지금 없음)이나
///   지운 아이디에 든 것은 뺀다.
/// - 지운 아이디: 서버 것 + 내가 이번에 지운 것, 지금 내 목록에 있는 것(되돌리기로 살린 것)은 뺀다.
SteelItemsMerge mergeSteelItems({
  required List<SteelCutItem> base,
  required List<SteelCutItem> local,
  required List<SteelCutItem> server,
  List<String> serverDeletedIds = const [],
}) {
  final baseById = {for (final b in base) b.id: b};
  final serverById = {for (final s in server) s.id: s};
  final localIds = {for (final l in local) l.id};
  final serverDeleted = serverDeletedIds.toSet();

  final out = <SteelCutItem>[];
  final kept = <String>{};
  for (final l in local) {
    final b = baseById[l.id];
    final untouched = b != null && sameSteelItem(l, b);
    if (untouched) {
      if (serverDeleted.contains(l.id)) continue; // 다른 기기가 지움
      out.add(serverById[l.id] ?? l);
    } else {
      out.add(l);
    }
    kept.add(l.id);
  }
  final deleted = <String>[
    ...serverDeletedIds,
    for (final b in base)
      if (!localIds.contains(b.id)) b.id,
  ];
  final deletedSet = deleted.toSet();
  for (final s in server) {
    if (kept.contains(s.id) || deletedSet.contains(s.id)) continue;
    if (baseById.containsKey(s.id)) continue; // 내가 지운 것
    out.add(s);
    kept.add(s.id);
  }
  final seen = <String>{};
  final tomb = <String>[
    for (final id in deleted)
      if (!kept.contains(id) && seen.add(id)) id,
  ];
  final capped = tomb.length > _kMaxDeletedIds
      ? tomb.sublist(tomb.length - _kMaxDeletedIds)
      : tomb;
  return SteelItemsMerge(out, capped);
}
