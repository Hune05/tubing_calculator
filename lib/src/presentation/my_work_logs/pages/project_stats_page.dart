import 'dart:io';
import '../widgets/korean_text.dart';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/project_phase.dart';
import '../models/report_tools.dart';

const Color _teal = Color(0xFF007580);
const Color _text = Color(0xFF191F28);
const Color _sub = Color(0xFF8B95A1);
const Color _bg = Color(0xFFF2F4F6);
const Color _red = Color(0xFFF04438);

// 🚀 [투입 통계] 일보에 쌓인 인원/연장/작업량을 프로젝트·단계·월별로 모아, 다음
// 견적이나 일정 잡을 때 "이런 공사는 인원-일이 이만큼 들었다"를 참고하게 한다.
// [logs]가 1개면 단계별, 여러 개면 프로젝트별 표를 보여준다. 기간 필터와
// CSV/PDF 내보내기를 지원한다.
class ProjectStatsPage extends StatefulWidget {
  final List<Map<String, dynamic>> logs;
  final String title;

  const ProjectStatsPage({super.key, required this.logs, required this.title});

  @override
  State<ProjectStatsPage> createState() => _ProjectStatsPageState();
}

class _Row {
  final String label;
  final double value;
  final String right;
  final String sub;
  _Row(this.label, this.value, this.right, this.sub);
}

class _ProjectStatsPageState extends State<ProjectStatsPage> {
  // 0=전체 1=이번 달 2=최근 3개월 3=올해
  int _period = 0;
  static const _periodLabels = ['전체', '이번 달', '최근 3개월', '올해'];

  String? _type;

  List<Map<String, dynamic>> get _logs =>
      widget.logs.where((l) => _type == null || _typeOf(l) == _type).toList();

  static String _typeOf(Map<String, dynamic> l) =>
      (l['workType']?.toString() ?? '').isEmpty
      ? '미분류'
      : l['workType'].toString();

  static double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

  DateTime? get _from {
    final now = dayOnly(DateTime.now());
    return switch (_period) {
      1 => DateTime(now.year, now.month, 1),
      2 => DateTime(now.year, now.month - 2, 1),
      3 => DateTime(now.year, 1, 1),
      _ => null,
    };
  }

  bool _inPeriod(Map r) {
    final f = _from;
    return f == null || !reportDateOf(r).isBefore(f);
  }

  List<(Map<String, dynamic>, Map)> get _reports => [
    for (final l in _logs)
      for (final r in (l['daily_reports'] as List? ?? []).whereType<Map>())
        if (_inPeriod(r)) (l, r),
  ];

  // ───────────── 내보내기 ─────────────
  Future<void> _exportCsv() async {
    final b = StringBuffer('﻿');
    b.writeln('프로젝트,날짜,작업유형,인원,연장시간,벤딩pt,결선개소,작업단계,특이사항');
    String q(String s) => '"${s.replaceAll('"', '""').replaceAll('\n', ' ')}"';
    for (final (l, r) in _reports) {
      final names = {
        for (final p in phasesOf(l)) p['id'].toString(): p['name'].toString(),
      };
      final types = r['work_type'] is List
          ? (r['work_type'] as List).join('/')
          : (r['work_type']?.toString() ?? '');
      final d = reportDateOf(r);
      b.writeln(
        [
          q(l['name']?.toString() ?? ''),
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
          q(types),
          r['worker_count'] ?? 1,
          r['overtime_hours'] ?? 0,
          r['points'] ?? 0,
          r['wiring_points'] ?? 0,
          q(
            reportIds(
              r,
              'workedPhaseIds',
            ).map((id) => names[id] ?? '').where((e) => e.isNotEmpty).join('/'),
          ),
          q(r['note']?.toString() ?? ''),
        ].join(','),
      );
    }
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/stats_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(b.toString());
    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(file.path)], text: '${widget.title} (CSV)');
  }

  Future<void> _exportPdf(_Summary s) async {
    final charts = <ReportChart>[
      if (s.rows.isNotEmpty)
        ReportChart(_logs.length == 1 ? '단계별 투입 (인원-일)' : '프로젝트별 투입 (인원-일)', [
          for (final r in s.rows) ReportChartRow(r.label, r.value, r.right),
        ]),
      if (s.plan.any((p) => p.$2 > 0))
        ReportChart('계획 대비 실제 (일)', [
          for (final p in s.plan)
            ReportChartRow(
              p.$1,
              p.$3.toDouble(),
              '계획 ${p.$2} → 실제 ${p.$3}',
              plan: p.$2.toDouble(),
            ),
        ]),
      if (s.months.isNotEmpty)
        ReportChart('월별 투입 (인원-일)', [
          for (final m in s.months)
            ReportChartRow(
              '${m.substring(0, 4)}년 ${int.parse(m.substring(5))}월',
              s.monthMan[m]!.toDouble(),
              '${s.monthMan[m]} 인·일',
            ),
        ]),
    ];
    final sections = <ReportSection>[
      ReportSection('요약 (${_periodLabels[_period]})', [
        '작업일수 ${s.days}일 / 투입 ${s.manDays}인·일 / 하루 평균 ${s.days == 0 ? 0 : (s.manDays / s.days).toStringAsFixed(1)}명',
        '연장/야간 ${s.otHours.toStringAsFixed(1)}시간 / 벤딩 ${s.pt.round()}pt / 결선 ${s.wiring.round()}개소',
      ]),
      ReportSection(_logs.length == 1 ? '단계별 투입' : '프로젝트별 투입', [
        for (final r in s.rows) '· ${r.label}: ${r.right}  ${r.sub}',
      ]),
      ReportSection('월별 투입 인원-일', [
        for (final m in s.months)
          '· ${m.substring(0, 4)}년 ${int.parse(m.substring(5))}월: ${s.monthMan[m]}인·일',
      ]),
    ];
    await shareReportPdf(
      ReportDoc(
        widget.title,
        '기간: ${_periodLabels[_period]}',
        [sections.first],
        charts: charts,
        heading: '투입 통계',
      ),
    );
  }

  // ───────────── 집계 ─────────────
  _Summary _summarize() {
    final reports = _reports;
    final s = _Summary();
    s.days = reports.length;
    for (final (_, r) in reports) {
      final w = (r['worker_count'] as num?)?.toInt() ?? 1;
      s.manDays += w;
      s.otHours += _num(r['overtime_hours']);
      s.pt += _num(r['points']);
      s.wiring += _num(r['wiring_points']);
      final d = reportDateOf(r);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      s.monthMan[key] = (s.monthMan[key] ?? 0) + w;
    }
    s.months = s.monthMan.keys.toList()..sort();

    if (_logs.length == 1) {
      final log = _logs.first;
      for (final p in phasesOf(log)) {
        final id = p['id'].toString();
        int d = 0, m = 0;
        for (final (_, r) in reports) {
          if (reportIds(r, 'workedPhaseIds').contains(id)) {
            d++;
            m += (r['worker_count'] as num?)?.toInt() ?? 1;
          }
        }
        final st = phaseStart(p), e = phaseEnd(p);
        final planned = (st != null && e != null)
            ? e.difference(st).inDays + 1
            : 0;
        s.rows.add(
          _Row(
            p['name'].toString(),
            m.toDouble(),
            "$d일 · $m인·일",
            planned > 0 ? "계획 $planned일" : "",
          ),
        );
        s.plan.add((p['name'].toString(), planned, d));
      }
    } else {
      for (final log in _logs) {
        final rs = reports.where((e) => identical(e.$1, log)).map((e) => e.$2);
        final m = rs.fold<int>(
          0,
          (a, r) => a + ((r['worker_count'] as num?)?.toInt() ?? 1),
        );
        s.rows.add(
          _Row(
            log['name']?.toString() ?? '이름 없음',
            m.toDouble(),
            "${rs.length}일 · $m인·일",
            "",
          ),
        );
      }
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final s = _summarize();
    final maxRow = s.rows.fold<double>(0, (a, r) => r.value > a ? r.value : a);
    final maxMonth = s.monthMan.values.fold<int>(0, (a, b) => b > a ? b : a);
    final maxPlan = s.plan.fold<int>(
      0,
      (a, p) => [a, p.$2, p.$3].reduce((x, y) => x > y ? x : y),
    );

    Widget tile(String label, String value) => Container(
      width: (MediaQuery.of(context).size.width - 32 - 10) / 2,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _sub,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: _text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );

    Widget barLine(double v, double max, Color c, {double h = 8}) => ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: max == 0 ? 0 : (v / max).clamp(0.0, 1.0),
        minHeight: h,
        backgroundColor: _bg,
        color: c,
      ),
    );

    Widget bar(String label, double v, double max, String right, String sub) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _text,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    right,
                    style: const TextStyle(
                      color: _teal,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              barLine(v, max, _teal),
              if (sub.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    sub,
                    style: const TextStyle(color: _sub, fontSize: 11),
                  ),
                ),
            ],
          ),
        );

    Widget section(String t, List<Widget> children) => Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: _text,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: "내보내기",
            icon: const Icon(Icons.ios_share_rounded),
            onSelected: (v) async {
              try {
                if (v == 'csv') await _exportCsv();
                if (v == 'pdf') await _exportPdf(s);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(keepWords("내보내기 실패: $e"))),
                  );
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'csv', child: Text("CSV (엑셀)")),
              PopupMenuItem(value: 'pdf', child: Text("PDF")),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < _periodLabels.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_periodLabels[i]),
                      selected: _period == i,
                      showCheckmark: false,
                      selectedColor: _teal,
                      backgroundColor: Colors.white,
                      side: BorderSide.none,
                      labelStyle: TextStyle(
                        color: _period == i ? Colors.white : _sub,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) => setState(() => _period = i),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.logs.length > 1) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final t in <String?>[
                    null,
                    ...{for (final l in widget.logs) _typeOf(l)},
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(t ?? '모든 유형'),
                        selected: _type == t,
                        showCheckmark: false,
                        selectedColor: _teal,
                        backgroundColor: Colors.white,
                        side: BorderSide.none,
                        labelStyle: TextStyle(
                          color: _type == t ? Colors.white : _sub,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) => setState(() => _type = t),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (s.days == 0)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(
                child: Text(
                  "이 기간에 작성된 일보가 없습니다.",
                  style: TextStyle(color: _sub),
                ),
              ),
            )
          else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                tile("작업일수", "${s.days}일"),
                tile("투입 인원-일", "${s.manDays} 인·일"),
                tile("하루 평균 인원", (s.manDays / s.days).toStringAsFixed(1)),
                tile("연장/야간", "${s.otHours.toStringAsFixed(1)}시간"),
                tile("벤딩 합계", "${s.pt.round()} pt"),
                tile("결선 합계", "${s.wiring.round()} 개소"),
              ],
            ),
            if (s.manDays > 0 && s.pt > 0)
              section("작업 효율 참고", [
                Text(
                  keepWords(
                    "1인·일당 벤딩 ${(s.pt / s.manDays).toStringAsFixed(1)} pt"
                    "${s.wiring > 0 ? ' · 결선 ${(s.wiring / s.manDays).toStringAsFixed(1)} 개소' : ''}",
                  ),
                  style: const TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  keepWords("다음 견적/일정에서 필요한 인원-일을 어림할 때 참고하십시오."),
                  style: TextStyle(color: _sub, fontSize: 12),
                ),
              ]),
            if (s.plan.any((p) => p.$2 > 0))
              section("계획 대비 실제 (일)", [
                for (final p in s.plan)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.$1,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _text,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              p.$2 == 0
                                  ? "실제 ${p.$3}일"
                                  : (p.$3 > p.$2
                                        ? "계획 ${p.$2} → 실제 ${p.$3} (+${p.$3 - p.$2})"
                                        : "계획 ${p.$2} → 실제 ${p.$3}"),
                              style: TextStyle(
                                color: p.$3 > p.$2 && p.$2 > 0 ? _red : _teal,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        barLine(
                          p.$2.toDouble(),
                          maxPlan.toDouble(),
                          const Color(0xFFB0B8C1),
                          h: 6,
                        ),
                        const SizedBox(height: 3),
                        barLine(
                          p.$3.toDouble(),
                          maxPlan.toDouble(),
                          p.$3 > p.$2 && p.$2 > 0 ? _red : _teal,
                          h: 6,
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    keepWords("회색=계획 기간, 색=일보에 그 단계로 기록한 작업일"),
                    style: TextStyle(color: _sub, fontSize: 11),
                  ),
                ),
              ]),
            if (s.rows.isNotEmpty)
              section(_logs.length == 1 ? "단계별 투입" : "프로젝트별 투입", [
                for (final r in s.rows)
                  bar(r.label, r.value, maxRow, r.right, r.sub),
                if (_logs.length == 1 && s.rows.every((r) => r.value == 0))
                  Text(
                    keepWords("일보에서 '작업한 단계'를 선택하면 단계별로 집계됩니다."),
                    style: TextStyle(color: _sub, fontSize: 12),
                  ),
              ]),
            if (_logs.length == 1 &&
                schedulesOf(_logs.first).any(isMaterialSchedule))
              section("자재 사용 현황", [
                for (final m in schedulesOf(
                  _logs.first,
                ).where(isMaterialSchedule))
                  Builder(
                    builder: (_) {
                      final id = m['id']?.toString() ?? '';
                      final used = reportsUsingMaterial(_logs.first, id);
                      final st = materialState(m);
                      DateTime? last;
                      for (final r in used) {
                        final d = reportDateOf(r);
                        if (last == null || d.isAfter(last)) last = d;
                      }
                      final unused = st == 'done' && used.isEmpty;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                (m['title'] ?? m['type']).toString(),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _text,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              unused
                                  ? "입고됨 · 미사용"
                                  : used.isEmpty
                                  ? (st == 'done' ? "-" : "입고 전")
                                  : "${used.length}일 사용 · 마지막 ${last!.month}/${last.day}",
                              style: TextStyle(
                                color: unused ? const Color(0xFFC77700) : _teal,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ]),
            section("월별 투입 인원-일", [
              for (final m in s.months)
                bar(
                  "${m.substring(0, 4)}년 ${int.parse(m.substring(5))}월",
                  s.monthMan[m]!.toDouble(),
                  maxMonth.toDouble(),
                  "${s.monthMan[m]} 인·일",
                  "",
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _Summary {
  int days = 0;
  int manDays = 0;
  double otHours = 0, pt = 0, wiring = 0;
  final Map<String, int> monthMan = {};
  List<String> months = [];
  final List<_Row> rows = [];
  final List<(String, int, int)> plan = []; // 이름, 계획일, 실제일
}
