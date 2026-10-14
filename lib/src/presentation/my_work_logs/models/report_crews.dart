// 작업 일지의 업체·공종별 인력과 투입 장비(10-14, 상용 앱 Procore·Raken의 인력·장비 기록).
//
// 저장 칸(일지 Map):
//   'crews':     [{'company': 업체, 'trade': 공종, 'count': 인원, 'hours': 시간(없으면 0)}]
//   'equipment': [{'name': 장비, 'count': 대수, 'hours': 시간(없으면 0)}]
// 둘 다 고르는 칸이다. crews를 적으면 총원을 합으로 'worker_count'에도 적어, 예전 화면·공수 셈·
// 보고서가 그대로 돈다(crews가 없으면 예전처럼 +·−로 적은 인원 하나).
library;

num _n(Object? v) => v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);

String _fmtNum(num v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// 일지의 업체·공종별 인력(빈 줄·0명은 뺀다).
List<Map<String, dynamic>> crewsOf(Map report) => [
  for (final c in (report['crews'] as List?) ?? const [])
    if (c is Map && _n(c['count']) > 0)
      {
        'company': (c['company'] ?? '').toString().trim(),
        'trade': (c['trade'] ?? '').toString().trim(),
        'count': _n(c['count']).toInt(),
        'hours': _n(c['hours']),
      },
];

/// 일지의 투입 장비(이름 없는 줄은 뺀다).
List<Map<String, dynamic>> equipmentOf(Map report) => [
  for (final e in (report['equipment'] as List?) ?? const [])
    if (e is Map && (e['name'] ?? '').toString().trim().isNotEmpty)
      {
        'name': (e['name'] ?? '').toString().trim(),
        'count': _n(e['count']) <= 0 ? 1 : _n(e['count']).toInt(),
        'hours': _n(e['hours']),
      },
];

/// 업체·공종별 인원 합.
int crewTotal(Iterable<Map> crews) =>
    crews.fold(0, (a, c) => a + _n(c['count']).toInt());

/// 한 줄: "대성 배관 5명 8h · 한빛 전기 2명".
String crewsLine(Map report) => crewsOf(report)
    .map((c) {
      final who = [
        c['company'],
        c['trade'],
      ].where((s) => (s as String).isNotEmpty).join(' ');
      final h = c['hours'] as num;
      return '${who.isEmpty ? '인력' : who} ${c['count']}명${h > 0 ? ' ${_fmtNum(h)}h' : ''}';
    })
    .join(' · ');

/// 한 줄: "크레인 25t 1대 4h · 고소작업차 2대".
String equipmentLine(Map report) => equipmentOf(report)
    .map((e) {
      final h = e['hours'] as num;
      return '${e['name']} ${e['count']}대${h > 0 ? ' ${_fmtNum(h)}h' : ''}';
    })
    .join(' · ');
