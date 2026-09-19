import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🚀 [보고서 양식] 내보내는 보고서(PDF/텍스트)의 머리말(회사명·로고·담당자), 서명란,
// 포함할 항목, PDF 사진 기본값을 저장해 두고 매번 그대로 쓴다. Firestore
// (my_project_settings/report_style)와 이 기기에 같이 보관한다.
class ReportStyle {
  String company;
  String manager;
  String? logoB64; // 작은 로고(PNG/JPG)를 base64로 보관
  bool signature;
  String sig1;
  String sig2;
  bool defaultPhotos;
  Set<String> hiddenSections;

  ReportStyle({
    this.company = '',
    this.manager = '',
    this.logoB64,
    this.signature = false,
    this.sig1 = '작성자',
    this.sig2 = '확인자',
    this.defaultPhotos = false,
    Set<String>? hiddenSections,
  }) : hiddenSections = hiddenSections ?? {};

  // 내보내기 코드가 어디서든 바로 읽을 수 있게 현재 값을 들고 있는다(앱 시작 때 로드).
  static ReportStyle current = ReportStyle();

  // 숨길 수 있는 보고서 항목(제목이 이 이름으로 시작하는 섹션).
  static const List<String> optionalSections = [
    '단계별 작업일',
    '완료한 일정',
    '자재 현황',
    '미해결 이슈',
    '다음 계획',
  ];

  Map<String, dynamic> toJson() => {
    'company': company,
    'manager': manager,
    'logoB64': logoB64,
    'signature': signature,
    'sig1': sig1,
    'sig2': sig2,
    'defaultPhotos': defaultPhotos,
    'hidden': hiddenSections.toList(),
  };

  static ReportStyle fromJson(Map<String, dynamic> j) => ReportStyle(
    company: j['company']?.toString() ?? '',
    manager: j['manager']?.toString() ?? '',
    logoB64: (j['logoB64']?.toString() ?? '').isEmpty
        ? null
        : j['logoB64'].toString(),
    signature: j['signature'] == true,
    sig1: j['sig1']?.toString() ?? '작성자',
    sig2: j['sig2']?.toString() ?? '확인자',
    defaultPhotos: j['defaultPhotos'] == true,
    hiddenSections: ((j['hidden'] as List?) ?? [])
        .map((e) => e.toString())
        .toSet(),
  );
}

const _kPref = 'report_style_v1';

DocumentReference<Map<String, dynamic>> get _doc => FirebaseFirestore.instance
    .collection('my_project_settings')
    .doc('report_style');

// 이 기기 값을 먼저 적용하고, 클라우드 값이 있으면 그걸로 덮어쓴다.
Future<ReportStyle> loadReportStyle() async {
  try {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kPref);
    if (raw != null) {
      ReportStyle.current = ReportStyle.fromJson(_decode(raw));
    }
  } catch (_) {}
  try {
    final snap = await _doc.get().timeout(const Duration(seconds: 6));
    final d = snap.data();
    if (d != null) {
      ReportStyle.current = ReportStyle.fromJson(d);
      await _saveLocal(ReportStyle.current);
    }
  } catch (_) {}
  return ReportStyle.current;
}

Map<String, dynamic> _decode(String raw) {
  final m = <String, dynamic>{};
  for (final line in raw.split('')) {
    final i = line.indexOf('');
    if (i > 0) m[line.substring(0, i)] = line.substring(i + 1);
  }
  return {
    ...m,
    'signature': m['signature'] == 'true',
    'defaultPhotos': m['defaultPhotos'] == 'true',
    'hidden': (m['hidden'] ?? '')
        .toString()
        .split('')
        .where((e) => e.isNotEmpty)
        .toList(),
  };
}

Future<void> _saveLocal(ReportStyle s) async {
  final j = s.toJson();
  final raw = [
    for (final k in ['company', 'manager', 'logoB64', 'sig1', 'sig2'])
      '$k${j[k] ?? ''}',
    'signature${s.signature}',
    'defaultPhotos${s.defaultPhotos}',
    'hidden${s.hiddenSections.join('')}',
  ].join('');
  final p = await SharedPreferences.getInstance();
  await p.setString(_kPref, raw);
}

Future<void> saveReportStyle(ReportStyle s) async {
  ReportStyle.current = s;
  await _saveLocal(s);
  try {
    await _doc.set(s.toJson());
  } catch (_) {}
}
