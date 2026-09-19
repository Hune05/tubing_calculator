import 'package:flutter/material.dart';

import '../../../data/repositories/work_project_repository.dart';
import '../models/report_tools.dart';
import '../widgets/work_theme.dart';
import '../models/weekly_plan.dart';

const Color _teal = Color(0xFF007580);
const Color _text = Color(0xFF191F28);
const Color _sub = Color(0xFF8B95A1);
const Color _bg = Color(0xFFF2F4F6);

// 알림을 눌렀을 때: 프로젝트를 불러와 주간 업무 보고 화면을 바로 연다.
Future<void> openWeeklyReportFromNotification(NavigatorState nav) async {
  try {
    final logs = await WorkProjectRepository().fetchAllProjects();
    nav.push(WorkRoute(builder: (_) => WeeklyReportPage(logs: logs)));
  } catch (_) {}
}

// 🚀 [주간 업무 보고] 지난주 실적 · 이번주 진행/예정 · 다음주 계획을 한 번에 정리해
// 미리 보고, 텍스트(카톡)나 PDF로 공유한다.
class WeeklyReportPage extends StatefulWidget {
  final List<Map<String, dynamic>> logs;
  const WeeklyReportPage({super.key, required this.logs});

  @override
  State<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<WeeklyReportPage> {
  String? _projectId; // null = 진행중 전체
  bool _photos = false;

  List<Map<String, dynamic>> get _active =>
      widget.logs.where((l) => l['status'] != 'DONE').toList();

  ReportDoc get _doc => buildWeeklyPlanDoc(
    widget.logs,
    onlyIds: _projectId == null ? null : {_projectId!},
    includePhotos: _photos,
  );

  Future<void> _pdf(ReportDoc doc) async {
    try {
      await shareReportPdf(doc);
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
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    subtitle: Text(
                      _photos
                          ? "지난주·이번주 일보 사진 ${doc.photos.length}장(최근 12장까지)"
                          : "지난주·이번주 일보에 붙인 사진",
                      style: const TextStyle(fontSize: 12, color: _sub),
                    ),
                    value: _photos,
                    onChanged: (v) => setState(() => _photos = v),
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
                        for (final l in s.lines)
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
