// 전기 기준(KEC) 탭: 한국전기설비규정(KEC)은 부처 공고로, 개정이 들쭉날쭉하다
// (한 해 0~5번 — 2023년 5번, 2024년 1번. 2026-09-26 law.go.kr·kec.kea.kr 확인).
// 조문 번호·수치는 넣지 않고 "개정 때 바뀔 수 있어 다시 확인할 항목"만 둔다.
// 정확한 값은 공식 원문에서 확인해야 한다.
//
// 글은 코드가 아니라 kec_content.json에 있다 — 서버(reference_content/kec)에 더 높은 판이
// 있으면 그것을 보여 앱을 다시 깔지 않아도 요약이 바뀐다. 서버 함수가 법제처에서 요약 기준
// 공고보다 새 공고를 찾으면 맨 위에 알린다(kec_content.dart).
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../kec_content.dart';
import 'reference_widgets.dart';

const Map<String, IconData> _icons = {
  'search': LucideIcons.search,
  'zapOff': LucideIcons.zapOff,
  'zap': LucideIcons.zap,
  'ruler': LucideIcons.ruler,
  'trendingUp': LucideIcons.trendingUp,
  'alertTriangle': LucideIcons.alertTriangle,
  'plug': LucideIcons.plug,
  'sun': LucideIcons.sun,
  'battery': LucideIcons.battery,
  'fileText': LucideIcons.fileText,
};

const Map<String, Color> _colors = {
  'blueGrey': Colors.blueGrey,
  'redAccent': Colors.redAccent,
  'deepOrange': Colors.deepOrange,
  'orange': Colors.orange,
  'green': Colors.green,
  'teal': Colors.teal,
  'indigo': Colors.indigo,
};

String _ymdHm(DateTime t) {
  final l = t.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

class RefKecTab extends StatefulWidget {
  /// 시험용. 없으면 앱에 든 요약 + 서버 문서.
  final Future<KecState> Function()? load;
  const RefKecTab({super.key, this.load});

  @override
  State<RefKecTab> createState() => _RefKecTabState();
}

class _RefKecTabState extends State<RefKecTab> {
  late final Future<KecState> _future = (widget.load ?? loadKecState)();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<KecState>(
      future: _future,
      builder: (context, snap) {
        final s = snap.data;
        if (s == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final c = s.content;
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            if (s.hasNewerNotice) ...[
              _newNoticeBox(s.latest!, c.basis),
              const SizedBox(height: 12),
            ],
            refWarnBox(c.warn),
            const SizedBox(height: 10),
            _basisLines(s),
            for (final sec in c.sections) ...[
              const SizedBox(height: 16),
              _section(sec),
            ],
          ],
        );
      },
    );
  }

  Widget _section(KecSection sec) {
    final icon = _icons[sec.icon] ?? LucideIcons.fileText;
    final color = _colors[sec.color] ?? refTeal;
    if (sec.type == 'steps') {
      return refCard(
        title: sec.title,
        subtitle: sec.subtitle,
        icon: icon,
        iconColor: color,
        children: [
          for (var i = 0; i < sec.steps.length; i++) refStep(i + 1, sec.steps[i]),
        ],
      );
    }
    return refExpandCard(
      title: sec.title,
      subtitle: sec.subtitle,
      icon: icon,
      iconColor: color,
      children: [for (final r in sec.rows) refDataRow(r.label, r.text)],
    );
  }

  /// 요약 기준 공고·마지막 개정 확인·출처.
  Widget _basisLines(KecState s) {
    final b = s.content.basis;
    final check = s.check;
    final lines = <String>[
      if (b.noticeNo.isNotEmpty)
        '요약 기준: 공고 제${b.noticeNo}호'
            '${b.issued.isNotEmpty ? '(${b.issued} 발령)' : ''}'
            '${b.checked.isNotEmpty ? ' · ${b.checked} 확인' : ''}',
      if (check != null && check.ok)
        '개정 확인: ${check.at != null ? _ymdHm(check.at!) : ''}'
            '${s.hasNewerNotice ? '' : ' · 새 공고 없음'}',
      if (check != null && !check.ok)
        '개정 확인을 못 했습니다'
            '${check.at != null ? '(${_ymdHm(check.at!)})' : ''}'
            '${check.message.isNotEmpty ? ': ${check.message}' : ''}',
      '출처: 법제처 국가법령정보센터',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        lines.join('\n'),
        key: const Key('kec_basis_lines'),
        style: TextStyle(fontSize: 12, color: refTextSub, height: 1.5),
      ),
    );
  }

  Widget _newNoticeBox(KecLatest n, KecBasis basis) {
    final detail = [
      if (n.revision.isNotEmpty) n.revision,
      if (n.issued.isNotEmpty) '${n.issued} 발령',
      if (n.effective.isNotEmpty) '${n.effective} 시행',
    ].join(', ');
    return Container(
      key: const Key('kec_new_notice'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: refWarnBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: refWarnBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.campaign_rounded, color: refWarnIcon, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '새 개정 공고가 났습니다 — 공고 제${n.noticeNo}호'
                  '${detail.isNotEmpty ? '($detail)' : ''}. 아래 요약은 그 전 '
                  '공고${basis.noticeNo.isNotEmpty ? '(제${basis.noticeNo}호)' : ''} '
                  '기준이니 원문을 확인하십시오.',
                  style: TextStyle(
                    fontSize: 13,
                    color: refWarnText,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (n.url.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(n.url),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('원문 보기'),
              ),
            ),
        ],
      ),
    );
  }
}
