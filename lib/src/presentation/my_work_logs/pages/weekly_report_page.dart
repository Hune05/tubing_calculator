import 'dart:async' show FutureOr;

import 'package:flutter/material.dart';

import '../../../data/repositories/work_project_repository.dart';
import '../models/photo_store.dart';
import '../models/report_style.dart';
import '../models/report_tools.dart';
import '../widgets/work_theme.dart';
import '../models/weekly_plan.dart';

const Color _teal = Color(0xFF007580);
const Color _text = Color(0xFF191F28);
const Color _sub = Color(0xFF8B95A1);
const Color _bg = Color(0xFFF2F4F6);

// 알림을 눌렀을 때: 프로젝트를 불러와 주간 업무 보고 화면을 바로 연다.
Future<void> openWeeklyReportFromNotification(
  NavigatorState nav, {
  bool autoPdf = false,
}) async {
  try {
    await loadReportStyle(); // 알림으로 바로 열면 양식(로고·담당자)이 아직 안 읽혔을 수 있다.
    final logs = await WorkProjectRepository().fetchAllProjects();
    nav.push(WorkRoute(builder: (_) => WeeklyReportPage(logs: logs)));
    // 설정에서 켠 경우: 화면을 열자마자 PDF를 만들어 공유창까지 연다.
    if (autoPdf) await shareReportPdf(buildWeeklyPlanDoc(logs));
  } catch (_) {}
}

// 🚀 [주간 업무 보고] 전주 실적 · 금주 진행/예정 · 차주 계획을 한 번에 정리해
// 미리 보고, 텍스트(카톡)나 PDF로 공유한다.
class WeeklyReportPage extends StatefulWidget {
  final List<Map<String, dynamic>> logs;
  // 있으면 "■ 프로젝트" 줄을 눌러 그 프로젝트 화면으로 이동할 수 있다.
  final FutureOr<void> Function(Map<String, dynamic> log)? onOpenProject;
  // 있으면 미해결 이슈 줄을 눌러 이슈 상세로 이동할 수 있다.
  final FutureOr<void> Function(Map<String, dynamic> log, Map punch)?
  onOpenIssue;
  const WeeklyReportPage({
    super.key,
    required this.logs,
    this.onOpenProject,
    this.onOpenIssue,
  });

  @override
  State<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<WeeklyReportPage> {
  String? _projectId; // null = 진행중 전체
  bool _photos = false;
  bool _split = false;
  DateTime? _asOf; // null = 오늘

  List<Map<String, dynamic>> get _active =>
      widget.logs.where((l) => l['status'] != 'DONE').toList();

  ReportDoc get _doc => buildWeeklyPlanDoc(
    widget.logs,
    onlyIds: _projectId == null ? null : {_projectId!},
    includePhotos: _photos,
    perProject: _split && _projectId == null,
    asOf: _asOf,
  );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _asOf ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: "기준일을 고르면 그 날이 속한 주가 '금주'가 돼요",
    );
    if (picked != null) {
      setState(() {
        final d = DateTime(picked.year, picked.month, picked.day);
        _asOf = d == DateTime(now.year, now.month, now.day) ? null : d;
      });
    }
  }

  // "■ 프로젝트 이름 — ..." 줄이면 해당 프로젝트를 찾는다(이동 기능이 켜졌을 때만).
  Map<String, dynamic>? _projectFor(String line) {
    if (widget.onOpenProject == null || !line.startsWith('■ ')) return null;
    final name = line.substring(2).split(' — ').first.split(' · ').first.trim();
    for (final l in widget.logs) {
      if (l['name']?.toString() == name) return l;
    }
    return null;
  }

  Future<void> _pdf(ReportDoc doc) async {
    try {
      await shareReportPdf(doc, withPhotos: _photos);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("PDF 생성 실패: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          "주간 업무 보고",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          if (_active.length > 1)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
                children: [
                  for (final e in <MapEntry<String?, String>>[
                    const MapEntry(null, '진행중 전체'),
                    for (final l in _active)
                      MapEntry(
                        l['id']?.toString(),
                        l['name']?.toString() ?? '이름 없음',
                      ),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: _projectId == e.key,
                        showCheckmark: false,
                        selectedColor: _teal,
                        backgroundColor: Colors.white,
                        side: BorderSide.none,
                        labelStyle: TextStyle(
                          color: _projectId == e.key ? Colors.white : _sub,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) => setState(() => _projectId = e.key),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    onTap: _pickDate,
                    leading: const Icon(Icons.event_rounded, color: _teal),
                    title: Text(
                      _asOf == null
                          ? "기준일: 오늘"
                          : "기준일: ${_asOf!.year}.${_asOf!.month}.${_asOf!.day}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      "눌러서 다른 주의 보고서를 볼 수 있어요",
                      style: TextStyle(fontSize: 12, color: _sub),
                    ),
                    trailing: _asOf == null
                        ? const Icon(Icons.chevron_right_rounded)
                        : TextButton(
                            onPressed: () => setState(() => _asOf = null),
                            child: const Text("오늘로"),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 2),
                  child: Text(
                    "${doc.title} · ${doc.period}",
                    style: const TextStyle(
                      color: _sub,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    activeThumbColor: _teal,
                    title: const Text(
                      "PDF에 작업 사진 넣기",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      _photos
                          ? "전주·금주 일보 사진 ${doc.photos.length}장(최근 12장까지)"
                          : "전주·금주 일보에 붙인 사진",
                      style: const TextStyle(fontSize: 12, color: _sub),
                    ),
                    value: _photos,
                    onChanged: (v) => setState(() => _photos = v),
                  ),
                ),
                if (_projectId == null && _active.length > 1)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      activeThumbColor: _teal,
                      title: const Text(
                        "프로젝트별로 나눠 보기",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        "PDF에서는 프로젝트마다 새 페이지로 시작해요",
                        style: TextStyle(fontSize: 12, color: _sub),
                      ),
                      value: _split,
                      onChanged: (v) => setState(() => _split = v),
                    ),
                  ),
                if (_photos && doc.compares.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "작업 전 / 후",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _teal,
                          ),
                        ),
                        for (final c in doc.compares) ...[
                          const SizedBox(height: 10),
                          Text(
                            c.label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              for (final (i, path) in [
                                c.before,
                                c.after,
                              ].indexed)
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      left: i == 0 ? 0 : 6,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: AspectRatio(
                                        aspectRatio: 1.4,
                                        child: PhotoImage(path),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                if (_photos && doc.photos.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "사진 미리보기",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _teal,
                          ),
                        ),
                        for (final g in <String?>{
                          for (final p in doc.photos) p.group,
                        }) ...[
                          const SizedBox(height: 10),
                          if (g != null)
                            Text(
                              "■ $g",
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: _text,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final p in doc.photos)
                                if (p.group == g)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: PhotoImage(
                                      p.path,
                                      width: 64,
                                      height: 64,
                                    ),
                                  ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                for (final s in doc.sections)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.heading,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _teal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final (i, l) in s.lines.indexed)
                          if (widget.onOpenIssue != null &&
                              s.issueRefs?[i] != null)
                            InkWell(
                              onTap: () async {
                                await widget.onOpenIssue!(
                                  s.issueRefs![i]!.log,
                                  s.issueRefs![i]!.punch,
                                );
                                // 이슈를 고치고 돌아왔을 수 있으니 다시 계산한다.
                                if (mounted) setState(() {});
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.4,
                                          color: _sub,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color: _sub,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (_projectFor(l) != null)
                            InkWell(
                              onTap: () async {
                                await widget.onOpenProject!(_projectFor(l)!);
                                if (mounted) setState(() {});
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.4,
                                          color: _text,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color: _sub,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                l,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: l.startsWith('■') ? _text : _sub,
                                  fontWeight: l.startsWith('■')
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => shareReportText(doc),
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text("텍스트(카톡)"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pdf(doc),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text("PDF"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
