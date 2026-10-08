/// 보관함 도면을 저장할 때의 장비 설정과 지금 설정이 다른 곳을 글로 알려 준다.
/// 마킹 값은 지금 설정으로 계산하므로, 다르면 저장 때와 마킹 자리가 달라진다.
library;

const _labels = <(String, String)>[
  ('benderType', '벤더 종류'),
  ('manufacturer', '제조사'),
  ('conduitType', '전선관 종류'),
  ('conduitSize', '규격'),
  ('takeUp', '테이크업'),
  ('gain', '게인'),
  ('clr', 'CLR'),
];

String _show(String key, Object? v) {
  if (key == 'benderType') {
    return switch (v) {
      'hand' => '수동',
      'ram' => '유압식',
      'chicago' => '시카고식',
      _ => '$v',
    };
  }
  if (v is num) {
    final r = (v * 10).round() / 10;
    return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();
  }
  return '$v';
}

bool _same(Object? a, Object? b) {
  if (a is num && b is num) return (a - b).abs() < 0.05;
  return '$a' == '$b';
}

/// 저장 때 값 중 지금과 다른 것만 모은 설정(지금 설정에 덮어 씌울 값). 다른 게 없으면 빈 맵.
Map<String, dynamic> conduitSettingChanges(
  Map<String, dynamic> saved,
  Map<String, dynamic> now,
) {
  final out = <String, dynamic>{};
  for (final (key, _) in _labels) {
    final s = saved[key];
    final n = now[key];
    if (s == null || '$s'.isEmpty || n == null) continue;
    if (!_same(s, n)) out[key] = s;
  }
  return out;
}

/// 저장 때 값이 있고 지금 값과 다른 항목만 "게인: 저장 때 70 → 지금 81.2" 꼴로 돌려준다.
/// 저장 때 값이 없던 항목(옛 도면)은 비교하지 않는다.
List<String> conduitSettingDiffs(
  Map<String, dynamic> saved,
  Map<String, dynamic> now,
) {
  final out = <String>[];
  for (final (key, label) in _labels) {
    final s = saved[key];
    final n = now[key];
    if (s == null || '$s'.isEmpty || n == null) continue;
    if (_same(s, n)) continue;
    out.add('$label: 저장 때 ${_show(key, s)} → 지금 ${_show(key, n)}');
  }
  return out;
}
