import 'package:flutter/material.dart';

import '../models/project_phase.dart';
import '../models/report_tools.dart';

const Color _teal = Color(0xFF007580);
const Color _text = Color(0xFF191F28);
const Color _sub = Color(0xFF8B95A1);
const Color _bg = Color(0xFFF2F4F6);
const Color _red = Color(0xFFF04438);

// 🚀 [회고 모아보기] 완료한 프로젝트들의 계획 대비 실제 기간, 인원-일, 원인·교훈을
// 한곳에 모아 "이런 공사는 대략 이 정도 걸린다"를 파악하게 한다.
class RetroOverviewPage extends StatefulWidget {
  final List<Map<String, dynamic>> logs;
  const RetroOverviewPage({super.key, required this.logs});

  @override
  State<RetroOverviewPage> createState() => _RetroOverviewPageState();
}

class _RetroOverviewPageState extends State<RetroOverviewPage> {
  String? _type;

  static String _typeOf(Map<String, dynamic> l) =>
      (l['workType']?.toString() ?? '').isEmpty
      ? '미분류'
      : l['workType'].toString();

  List<Map<String, dynamic>> get logs =>
      widget.logs.where((l) => _type == null || _typeOf(l) == _type).toList();

  static int? _planned(Map<String, dynamic> log) {
    final s = projectStart(log), e = projectDue(log);
    return (s != null && e != null) ? e.difference(s).inDays + 1 : null;
  }

  static int? _actual(Map<String, dynamic> log) {
    final dates = [
      for (final r in (log['daily_reports'] as List? ?? []).whereType<Map>())
        reportDateOf(r),
    ]..sort();
    if (dates.isEmpty) return null;
    final end = log['completedAt'] != null
        ? dayOnly(asDate(log['completedAt']))
        : dates.last;
    return end.difference(dates.first).inDays + 1;
  }

  static String _typeLine(List<Map<String, dynamic>> ls) {
    final plans = ls.map(_planned).whereType<int>().toList();
    final actuals = ls.map(_actual).whereType<int>().toList();
    final man = ls.map(_manDays).toList();
    String avg(List<num> v) => v.isEmpty
        ? '-'
        // reduce는 List<int>를 List<num>으로 받을 때 실행 중 형식 오류가 나므로 fold<num>을 쓴다.
        : (v.fold<num>(0, (a, b) => a + b) / v.length).round().toString();
    return "계획 ${avg(plans)}일 → 실제 ${avg(actuals)}일 · 투입 ${avg(man)}인·일";
  }

  static int _manDays(Map<String, dynamic> log) =>
      (log['daily_reports'] as List? ?? []).whereType<Map>().fold<int>(
        0,
        (a, r) => a + ((r['worker_count'] as num?)?.toInt() ?? 1),
      );

  @override
  Widget build(BuildContext context) {
    final done = logs.where((l) => l['status'] == 'DONE').toList();

    final withBoth = done
        .where((l) => _planned(l) != null && _actual(l) != null)
        .toList();
    final onTime = withBoth.where((l) => _actual(l)! <= _planned(l)!).length;
    final avgPlan = withBoth.isEmpty
        ? null
        : withBoth.fold<int>(0, (a, l) => a + _planned(l)!) / withBoth.length;
    final avgActual = withBoth.isEmpty
        ? null
        : withBoth.fold<int>(0, (a, l) => a + _actual(l)!) / withBoth.length;

    // 공사 유형별 묶음
    final Map<String, List<Map<String, dynamic>>> byType = {};
    for (final l in done) {
      final t = (l['workType']?.toString() ?? '').isEmpty
          ? '미분류'
          : l['workType'].toString();
      byType.putIfAbsent(t, () => []).add(l);
    }

    // 단계 이름별 평균(작업일 / 인원-일 / 계획일)
    final Map<String, List<(int, int, int)>> byPhase = {};
    for (final l in done) {
      for (final p in phasesOf(l)) {
        final st = phaseWorkStats(l, p['id'].toString());
        if (st.days == 0) continue;
        final s = phaseStart(p), e = phaseEnd(p);
        final planned = (s != null && e != null)
            ? e.difference(s).inDays + 1
            : 0;
        byPhase.putIfAbsent(p['name'].toString(), () => []).add((
          st.days,
          st.manDays,
          planned,
        ));
      }
    }

    Widget card(List<Widget> children) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );

    Widget h(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        t,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 15,
          color: _text,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          "회고 모아보기",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: done.isEmpty
          ? const Center(
              child: Text("완료한 프로젝트가 아직 없어요.", style: TextStyle(color: _sub)),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final t in <String?>[
                        null,
                        ...{
                          for (final l in widget.logs)
                            if (l['status'] == 'DONE') _typeOf(l),
                        },
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
                const SizedBox(height: 12),
                card([
                  h("전체 요약 (완료 ${done.length}건)"),
                  if (avgPlan != null && avgActual != null) ...[
                    Text(
                      "평균 계획 ${avgPlan.round()}일 → 평균 실제 ${avgActual.round()}일",
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "기간 내 완료 $onTime / ${withBoth.length}건 "
                      "(${(onTime * 100 / withBoth.length).round()}%)",
                      style: const TextStyle(color: _sub, fontSize: 13),
                    ),
                  ] else
                    const Text(
                      "계획 기간(단계 설정)과 일보가 있는 프로젝트가 생기면 평균이 계산돼요.",
                      style: TextStyle(color: _sub, fontSize: 13),
                    ),
                ]),
                if (byType.isNotEmpty)
                  card([
                    h("공사 유형별 평균"),
                    for (final e in byType.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${e.key}  (${e.value.length}건)",
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _text,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _typeLine(e.value),
                              style: const TextStyle(
                                color: _teal,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ]),
                if (byPhase.isNotEmpty)
                  card([
                    h("단계별 평균 (일보 기준)"),
                    for (final e in byPhase.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                "${e.key}  (${e.value.length}건)",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _text,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              "작업 ${(e.value.fold<int>(0, (a, v) => a + v.$1) / e.value.length).toStringAsFixed(1)}일 · "
                              "${(e.value.fold<int>(0, (a, v) => a + v.$2) / e.value.length).toStringAsFixed(1)}인·일",
                              style: const TextStyle(
                                color: _teal,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ]),
                for (final l in done)
                  Builder(
                    builder: (_) {
                      final p = _planned(l), a = _actual(l);
                      final diff = (p != null && a != null) ? a - p : null;
                      final retro = Map<String, dynamic>.from(
                        (l['retro'] as Map?) ?? {},
                      );
                      final cause = retro['cause']?.toString() ?? '';
                      final lesson = retro['lesson']?.toString() ?? '';
                      return card([
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l['name']?.toString() ?? '이름 없음',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: _text,
                                ),
                              ),
                            ),
                            if (diff != null)
                              Text(
                                diff == 0
                                    ? "계획대로"
                                    : diff > 0
                                    ? "+$diff일 지연"
                                    : "${-diff}일 단축",
                                style: TextStyle(
                                  color: diff > 0 ? _red : _teal,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "계획 ${p ?? '-'}일 · 실제 ${a ?? '-'}일 · 투입 ${_manDays(l)}인·일",
                          style: const TextStyle(color: _sub, fontSize: 12),
                        ),
                        if (cause.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            "원인: $cause",
                            style: const TextStyle(
                              color: _text,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (lesson.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            "참고: $lesson",
                            style: const TextStyle(
                              color: _teal,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ]);
                    },
                  ),
              ],
            ),
    );
  }
}
