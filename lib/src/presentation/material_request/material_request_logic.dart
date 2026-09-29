// 자재 요청 정리의 순수 계산: 카톡에 보낼 글 만들기, 카탈로그와 이름 맞추기. 화면과 분리해 테스트한다.
import '../../core/utils/ai_material_note.dart';
import '../inventory/material_catalog.dart';

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// 수량을 글로. 정수면 소수점 없이(50), 아니면 필요한 만큼(2.5).
String formatQty(double q) {
  if (q == q.roundToDouble()) return q.round().toString();
  var s = q.toStringAsFixed(2);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// "튜브 6mm SS316  50m" 꼴의 한 줄(번호 제외). 수량이 없으면 빈 채로 둔다(사용자가 채우도록 화면이 막는다).
String itemLine(MaterialNoteItem it) {
  final head = [it.name, if (it.spec.isNotEmpty) it.spec].join(' ');
  if (it.qty == null) return head;
  final unit = it.unit;
  // 한 글자 단위(m, 개)는 붙이고, 그 밖(EA, 본 등)도 붙여 짧게 쓴다.
  return '$head  ${formatQty(it.qty!)}$unit';
}

/// 카톡으로 보낼 글.
///   [자재 요청] 9/30 (수) 루마
///   1. 튜브 6mm SS316  50m
String buildMaterialRequestText(
  List<MaterialNoteItem> items, {
  required DateTime date,
  String site = '',
}) {
  final head = StringBuffer(
    '[자재 요청] ${date.month}/${date.day} (${_weekdays[date.weekday - 1]})',
  );
  if (site.trim().isNotEmpty) head.write(' ${site.trim()}');
  final lines = <String>[head.toString()];
  for (var i = 0; i < items.length; i++) {
    lines.add('${i + 1}. ${itemLine(items[i])}');
  }
  return lines.join('\n');
}

String _norm(String s) => s
    .toLowerCase()
    .replaceAll('"', '인치')
    .replaceAll(RegExp(r'[\s\-_/(),.·]'), '');

/// 카탈로그를 한 번만 정리해 두고, 읽은 줄이 카탈로그의 한 항목과 분명히 맞는지 찾는다.
class CatalogMatcher {
  final List<CatalogItem> _catalog;
  final List<String> _hay;

  CatalogMatcher(List<CatalogItem> catalog)
    : _catalog = catalog,
      _hay = [for (final c in catalog) _norm('${c.name} ${c.spec}')];

  /// 이름+규격의 모든 조각이 카탈로그 이름·규격 안에 들어 있는 항목 가운데, 군더더기가 가장
  /// 적은 하나만 돌려준다(동점이면 애매하니 null). 이미 카탈로그 이름 그대로면 null.
  CatalogItem? match(MaterialNoteItem it) {
    final tokens = [
      ...it.name.split(RegExp(r's+')),
      ...it.spec.split(RegExp(r's+')),
    ].map(_norm).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return null;
    final total = tokens.fold<int>(0, (a, t) => a + t.length);
    int? best;
    var bestExtra = 1 << 30;
    var tie = false;
    for (var i = 0; i < _catalog.length; i++) {
      final hay = _hay[i];
      if (!tokens.every(hay.contains)) continue;
      final extra = hay.length - total;
      if (extra < bestExtra) {
        best = i;
        bestExtra = extra;
        tie = false;
      } else if (extra == bestExtra) {
        tie = true;
      }
    }
    if (best == null || tie) return null;
    final c = _catalog[best];
    final already = _norm(c.name) == _norm(it.name) &&
        (it.spec.isEmpty || _norm(c.name).contains(_norm(it.spec)));
    return already ? null : c;
  }
}

/// 카탈로그 항목으로 이름을 맞춘 줄. 수량·확인 표시는 그대로 두고, 단위는 비어 있을 때만 채운다.
MaterialNoteItem applyCatalog(MaterialNoteItem it, CatalogItem c) {
  final specInName = c.spec.isEmpty || _norm(c.name).contains(_norm(c.spec));
  return it.copyWith(
    name: c.name,
    spec: specInName ? '' : c.spec,
    unit: it.unit.isEmpty ? c.unit : it.unit,
  );
}
