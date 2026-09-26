// 전기 기준(KEC) 탭의 요약과 새 개정 공고 정보.
//
// 요약은 앱에 든 assets/reference/kec_content.json(= functions/kec_content.json)과
// 서버 reference_content/kec 문서 중 판 번호(version)가 높은 쪽을 쓴다. 서버 문서는
// 서버 함수 checkKecNotice(functions/index.js)가 매일 아침 쓰고, 법제처 API로 읽은 현행
// 공고(latest)와 확인 결과(check)도 같이 적는다. 통신이 없으면 폰에 남은 것을 쓰고,
// 그것도 없으면 앱에 든 요약만 보인다.
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;

const String kKecContentAsset = 'assets/reference/kec_content.json';

/// 요약을 쓸 때 기준으로 삼은(그때 현행이던) 공고.
class KecBasis {
  final String serial;
  final String noticeNo;
  final String issued; // yyyy-MM-dd
  final String checked; // 요약을 쓰며 현행을 확인한 날
  const KecBasis({
    this.serial = '',
    this.noticeNo = '',
    this.issued = '',
    this.checked = '',
  });

  factory KecBasis.fromJson(Map<String, dynamic>? j) => KecBasis(
    serial: j?['serial']?.toString() ?? '',
    noticeNo: j?['noticeNo']?.toString() ?? '',
    issued: j?['issued']?.toString() ?? '',
    checked: j?['checked']?.toString() ?? '',
  );
}

/// 요약 한 덩어리: steps(번호 붙은 줄) 또는 rows(이름 + 설명, 접는 카드).
class KecSection {
  final String type;
  final String title;
  final String? subtitle;
  final String icon;
  final String color;
  final List<String> steps;
  final List<({String label, String text})> rows;
  const KecSection({
    required this.type,
    required this.title,
    this.subtitle,
    this.icon = '',
    this.color = '',
    this.steps = const [],
    this.rows = const [],
  });

  factory KecSection.fromJson(Map<String, dynamic> j) {
    final type = j['type']?.toString() ?? 'rows';
    final items = (j['items'] as List?) ?? const [];
    return KecSection(
      type: type,
      title: j['title']?.toString() ?? '',
      subtitle: j['subtitle']?.toString(),
      icon: j['icon']?.toString() ?? '',
      color: j['color']?.toString() ?? '',
      steps: type == 'steps' ? [for (final s in items) s.toString()] : const [],
      rows: type == 'steps'
          ? const []
          : [
              for (final r in items.whereType<Map>())
                (
                  label: r['label']?.toString() ?? '',
                  text: r['text']?.toString() ?? '',
                ),
            ],
    );
  }
}

class KecContent {
  final int version;
  final KecBasis basis;
  final String warn;
  final List<KecSection> sections;
  const KecContent({
    required this.version,
    required this.basis,
    required this.warn,
    required this.sections,
  });

  /// 틀린 모양이면 null(서버 문서가 깨져도 앱에 든 요약으로 버틴다).
  static KecContent? tryParse(Object? raw) {
    if (raw is! Map) return null;
    try {
      final j = Map<String, dynamic>.from(raw);
      final version = (j['version'] as num?)?.toInt();
      final sections = j['sections'];
      if (version == null || sections is! List) return null;
      return KecContent(
        version: version,
        basis: KecBasis.fromJson(
          j['basis'] is Map ? Map<String, dynamic>.from(j['basis']) : null,
        ),
        warn: j['warn']?.toString() ?? '',
        sections: [
          for (final s in sections.whereType<Map>())
            KecSection.fromJson(Map<String, dynamic>.from(s)),
        ],
      );
    } catch (_) {
      return null;
    }
  }
}

/// 법제처에서 읽은 현행 공고.
class KecLatest {
  final String serial;
  final String noticeNo;
  final String revision; // 일부개정 등
  final String issued; // 발령일 yyyy-MM-dd
  final String effective; // 시행일
  final String url;
  const KecLatest({
    required this.serial,
    this.noticeNo = '',
    this.revision = '',
    this.issued = '',
    this.effective = '',
    this.url = '',
  });

  static KecLatest? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final serial = raw['serial']?.toString() ?? '';
    if (serial.isEmpty) return null;
    return KecLatest(
      serial: serial,
      noticeNo: raw['noticeNo']?.toString() ?? '',
      revision: raw['revision']?.toString() ?? '',
      issued: raw['issued']?.toString() ?? '',
      effective: raw['effective']?.toString() ?? '',
      url: raw['url']?.toString() ?? '',
    );
  }
}

/// 서버의 마지막 개정 확인.
class KecCheck {
  final bool ok;
  final DateTime? at;
  final String message;
  const KecCheck({required this.ok, this.at, this.message = ''});

  static KecCheck? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final at = raw['at'];
    return KecCheck(
      ok: raw['ok'] == true,
      at: at is Timestamp
          ? at.toDate()
          : (at is DateTime ? at : DateTime.tryParse(at?.toString() ?? '')),
      message: raw['message']?.toString() ?? '',
    );
  }
}

/// [latest]가 요약 기준 공고보다 새 공고인가. 일련번호가 다르고 발령일이 같거나 늦을 때만
/// (서버 함수 functions/kec.js isNewerNotice와 같은 규칙).
bool isNewerKecNotice(KecLatest? latest, KecBasis basis) {
  if (latest == null || latest.serial.isEmpty) return false;
  if (basis.serial.isEmpty) return true;
  if (latest.serial == basis.serial) return false;
  return latest.issued.compareTo(basis.issued) >= 0;
}

class KecState {
  final KecContent content;
  final KecLatest? latest;
  final KecCheck? check;
  const KecState({required this.content, this.latest, this.check});

  bool get hasNewerNotice => isNewerKecNotice(latest, content.basis);
}

/// 앱에 든 요약과 서버 문서를 합친다: 요약은 판 번호가 높은 쪽, 공고·확인은 서버 것.
KecState mergeKecState(KecContent bundled, Map<String, dynamic>? server) {
  final serverContent = KecContent.tryParse(server?['content']);
  final content =
      serverContent != null && serverContent.version > bundled.version
      ? serverContent
      : bundled;
  return KecState(
    content: content,
    latest: KecLatest.tryParse(server?['latest']),
    check: KecCheck.tryParse(server?['check']),
  );
}

Future<Map<String, dynamic>?> _readServerDoc() async {
  try {
    final ref = FirebaseFirestore.instance
        .collection('reference_content')
        .doc('kec');
    try {
      final snap = await ref.get().timeout(const Duration(seconds: 6));
      return snap.data();
    } catch (_) {
      // 통신이 느리거나 없으면 폰에 남은 것.
      final snap = await ref.get(const GetOptions(source: Source.cache));
      return snap.data();
    }
  } catch (_) {
    return null; // 한 번도 못 받았거나 Firebase가 없음(시험)
  }
}

/// KEC 탭에 보일 것을 읽는다. [readServer]·[readBundled]는 시험용.
Future<KecState> loadKecState({
  Future<Map<String, dynamic>?> Function()? readServer,
  Future<String> Function()? readBundled,
}) async {
  // 작은 파일이라 캐시 없이 읽는다(캐시한 Future가 시험마다 새 시간대에서 안 끝나던 것).
  final text =
      await (readBundled ??
          () => rootBundle.loadString(kKecContentAsset, cache: false))();
  final bundled = KecContent.tryParse(jsonDecode(text))!;
  final server = await (readServer ?? _readServerDoc)();
  return mergeKecState(bundled, server);
}
