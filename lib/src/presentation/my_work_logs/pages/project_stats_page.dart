import 'package:flutter/material.dart';

import '../models/project_phase.dart';
import '../models/report_tools.dart';

const Color _teal = Color(0xFF007580);
const Color _text = Color(0xFF191F28);
const Color _sub = Color(0xFF8B95A1);
const Color _bg = Color(0xFFF2F4F6);

// 🚀 [투입 통계] 일보에 쌓인 인원/연장/작업량을 프로젝트·단계·월별로 모아, 다음
// 견적이나 일정 잡을 때 "이런 공사는 인원-일이 이만큼 들었다"를 참고하게 한다.
// [logs]가 1개면 단계별, 여러 개면 프로젝트별 표를 보여준다.
class ProjectStatsPage extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  final String title;

  const ProjectStatsPage({super.key, required this.logs, required this.title});

  static double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    final reports = <(Map<String, dynamic>, Map)>[
      for (final l in logs)
        for (final r in (l['daily_reports'] as List? ?? []).whereType<Map>())
          (l, r),
    ];

    int days = reports.length;
    int manDays = 0;
    double otHours = 0, pt = 0, wiring = 0;
    final Map<String, int> monthMan = {};
    for (final (_, r) in reports) {
      final w = (r['worker_count'] as num?)?.toInt() ?? 1;
      manDays += w;
      otHours += _num(r['overtime_hours']);
      pt += _num(r['points']);
      wiring += _num(r['wiring_points']);
      final d = reportDateOf(r);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      monthMan[key] = (monthMan[key] ?? 0) + w;
    }
    final months = monthMan.keys.toList()..sort();

    // 행: 단일 프로젝트면 단계별, 여러 개면 프로젝트별
    final rows = <_Row>[];
    if (logs.length == 1) {
      final log = logs.first;
      for (final p in phasesOf(log)) {
        final id = p['id'].toString();
        final st = phaseWorkStats(log, id);
        final s = phaseStart(p), e = phaseEnd(p);
        rows.add(
          _Row(
            p['name'].toString(),
            st.manDays.toDouble(),
            "${st.days}일 · ${st.manDays}인·일",
            (s != null && e != null) ? "계획 ${e.difference(s).inDays + 1}일" : "",
          ),
        );
      }
    } else {
      for (final log in logs) {
        final rs = (log['daily_reports'] as List? ?? []).whereType<Map>();
        final m = rs.fold<int>(
          0,
          (a, r) => a + ((r['worker_count'] as num?)?.toInt() ?? 1),
        );
        rows.add(
          _Row(
            log['name']?.toString() ?? '이름 없음',
            m.toDouble(),
            "${rs.length}일 · $m인·일",
            "",
          ),
        );
      }
    }
    final maxRow = rows.fold<double>(0, (a, r) => r.value > a ? r.value : a);
    final maxMonth = monthMan.values.fold<int>(0, (a, b) => b > a ? b : a);

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
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: max == 0 ? 0 : v / max,
                  minHeight: 8,
                  backgroundColor: _bg,
                  color: _teal,
                ),
              ),
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
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: days == 0
          ? const Center(
              child: Text("아직 작성된 일보가 없어요.", style: TextStyle(color: _sub)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    tile("작업일수", "$days일"),
                    tile("투입 인원-일", "$manDays 인·일"),
                    tile("하루 평균 인원", (manDays / days).toStringAsFixed(1)),
                    tile("연장/야간", "${otHours.toStringAsFixed(1)}시간"),
                    tile("벤딩 합계", "${pt.round()} pt"),
                    tile("결선 합계", "${wiring.round()} 개소"),
                  ],
                ),
                if (manDays > 0 && pt > 0)
                  section("작업 효율 참고", [
                    Text(
                      "1인·일당 벤딩 ${(pt / manDays).toStringAsFixed(1)} pt"
                      "${wiring > 0 ? ' · 결선 ${(wiring / manDays).toStringAsFixed(1)} 개소' : ''}",
                      style: const TextStyle(
                        color: _text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "다음 견적/일정에서 필요한 인원-일을 어림할 때 참고하세요.",
                      style: TextStyle(color: _sub, fontSize: 12),
                    ),
                  ]),
                if (rows.isNotEmpty)
                  section(logs.length == 1 ? "단계별 투입" : "프로젝트별 투입", [
                    for (final r in rows)
                      bar(
                        r.label,
                        r.value,
                        maxRow,
                        r.right,
                        r.sub.isEmpty ? "" : r.sub,
                      ),
                    if (logs.length == 1 && rows.every((r) => r.value == 0))
                      const Text(
                        "일보에서 '작업한 단계'를 선택하면 단계별로 집계돼요.",
                        style: TextStyle(color: _sub, fontSize: 12),
                      ),
                  ]),
                section("월별 투입 인원-일", [
                  for (final m in months)
                    bar(
                      "${m.substring(0, 4)}년 ${int.parse(m.substring(5))}월",
                      monthMan[m]!.toDouble(),
                      maxMonth.toDouble(),
                      "${monthMan[m]} 인·일",
                      "",
                    ),
                ]),
              ],
            ),
    );
  }
}

class _Row {
  final String label;
  final double value;
  final String right;
  final String sub;
  _Row(this.label, this.value, this.right, this.sub);
}
