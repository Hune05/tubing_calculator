// 작업 일지 확인 서명(10-14, 보고서 양식에서 켜야 보인다). 감독원·발주처가 일지를 확인하고 손가락으로
// 서명하면 일지에 남고, 일지는 확정(잠금)된다. 확정을 풀고 고치면 확인 서명은 지운다(고친 내용은
// 확인받은 것이 아니므로).
//
// 저장 칸(일지 Map): 'confirmations': [{'name','role','sig','at'(ISO)}]. 서명은 안전 점검과 같은
// 획 좌표 글(safety_check_model.dart의 encodeSignature).
library;

import 'project_phase.dart' show touchItem;

const String kReportConfirmKey = 'confirmations';

class ReportConfirm {
  /// 어느 일지인지(날짜 글, 예: "10/14").
  final String reportDate;
  final String name;
  final String role;
  final String sig;
  final DateTime? at;
  const ReportConfirm({
    required this.reportDate,
    required this.name,
    this.role = '',
    this.sig = '',
    this.at,
  });

  /// "홍길동(감독원)".
  String get who => role.isEmpty ? name : '$name($role)';
}

/// 일지의 확인 서명(이름 없는 것은 뺀다).
List<ReportConfirm> confirmationsOf(Map r) => [
  for (final c in (r[kReportConfirmKey] as List?) ?? const [])
    if (c is Map && (c['name'] ?? '').toString().trim().isNotEmpty)
      ReportConfirm(
        reportDate: (r['date'] ?? '').toString(),
        name: c['name'].toString().trim(),
        role: (c['role'] ?? '').toString().trim(),
        sig: (c['sig'] ?? '').toString(),
        at: DateTime.tryParse((c['at'] ?? '').toString()),
      ),
];

bool isReportConfirmed(Map r) => confirmationsOf(r).isNotEmpty;

/// 보고서 한 줄: "확인: 홍길동(감독원) 10/14 · 김철수(발주처) 10/15".
String confirmLine(Map r) => confirmationsOf(r)
    .map((c) => '${c.who}${c.at == null ? '' : ' ${c.at!.month}/${c.at!.day}'}')
    .join(' · ');

/// 확인 서명을 더하고 일지를 확정한다. 같은 이름이 이미 서명했으면 새 서명으로 바꾼다.
void addReportConfirmation(
  Map r, {
  required String name,
  String role = '',
  String sig = '',
  DateTime? at,
}) {
  final now = at ?? DateTime.now();
  final list = [
    for (final c in (r[kReportConfirmKey] as List?) ?? const [])
      if (c is Map && c['name']?.toString().trim() != name.trim()) c,
    {
      'name': name.trim(),
      if (role.trim().isNotEmpty) 'role': role.trim(),
      if (sig.isNotEmpty) 'sig': sig,
      'at': now.toIso8601String(),
    },
  ];
  r[kReportConfirmKey] = list;
  if (r['locked'] != true) {
    r['locked'] = true;
    r['lockedAt'] = now;
  }
  touchItem(r);
}

/// 확정을 풀고 고칠 때: 확인 서명을 지우고 지운 사람 이름을 돌려준다(풀기 기록에 남긴다).
List<String> clearReportConfirmations(Map r) {
  final names = confirmationsOf(r).map((c) => c.who).toList();
  r.remove(kReportConfirmKey);
  return names;
}
