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
  ('measureRef', '치수 기준'),
  ('springback', '스프링백(°)'),
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
  if (key == 'measureRef') return v == 'center' ? '관 중심' : '관 등';
  if (v is num) {
    final r = (v * 10).round() / 10;
    return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();
  }
  return '$v';
}

/// 저장 때 값. 10-09 전에 저장한 도면에는 치수 기준이 없는데, 그때는 관 등 기준뿐이었다 — 테이크업·게인이
/// 같이 남아 있으면 관 등으로 보고 비교한다(10-13: 건너뛰어 관 등 값이 관 중심 설정에 섞였다,
/// 22 EMT 스텁 약 12mm·절단 약 23mm). 테이크업·게인도 없으면 기준만 바꾸면 값이 섞이므로 그대로 건너뛴다.
Object? _saved(Map<String, dynamic> saved, String key) {
  final v = saved[key];
  if (key == 'measureRef' &&
      v == null &&
      (saved['takeUp'] != null || saved['gain'] != null)) {
    return 'back';
  }
  return v;
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
    final s = _saved(saved, key);
    final n = now[key];
    if (s == null || '$s'.isEmpty || n == null) continue;
    if (!_same(s, n)) out[key] = s;
  }
  return out;
}

/// 저장 때 값이 있고 지금 값과 다른 항목만 "게인: 저장 때 70 → 지금 81.2" 꼴로 돌려준다.
/// 저장 때 값이 없던 항목(옛 도면)은 비교하지 않는다(치수 기준은 위 _saved).
List<String> conduitSettingDiffs(
  Map<String, dynamic> saved,
  Map<String, dynamic> now,
) {
  final out = <String>[];
  for (final (key, label) in _labels) {
    final s = _saved(saved, key);
    final n = now[key];
    if (s == null || '$s'.isEmpty || n == null) continue;
    if (_same(s, n)) continue;
    out.add('$label: 저장 때 ${_show(key, s)} → 지금 ${_show(key, n)}');
  }
  return out;
}
