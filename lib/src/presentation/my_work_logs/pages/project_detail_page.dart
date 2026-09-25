import '../widgets/work_theme.dart';
import '../widgets/korean_text.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/project_phase.dart';
import '../widgets/work_log_card.dart';
import '../models/report_tools.dart';
import '../models/photo_store.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/address_book.dart';
import '../models/report_style.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../../core/utils/image_picker_helper.dart' show ImagePickerHelper;
import '../models/summary_image.dart';
import 'package:share_plus/share_plus.dart';
import '../models/phase_templates.dart';
import '../models/project_merge.dart' show authorLabel, markItemDeleted;
import '../../../data/repositories/work_project_repository.dart';
import 'report_search_page.dart' show ProjectPhotosPage;
import 'project_stats_page.dart';
import '../../calculator/widgets/app_dialog.dart' show confirmDeleteDialog;

part 'project_detail_page_overview.dart';
part 'project_detail_page_phases.dart';
part 'project_detail_page_issues.dart';
part 'project_detail_page_reports.dart';

// 🚀 [프로젝트 상세 - 신규] 예전엔 프로젝트 카드를 펼치면 일정/일지/이슈가 한 카드
// 안에 길게 쌓였고, 프로젝트가 "지금 어떤 상태인지"는 한눈에 안 보였다. 프로젝트를
// 열면 진행률·D-day·현재 단계가 먼저 보이고, 아래 탭(개요/단계·일정/이슈/일지)으로
// 나눠 본다. 저장/이동 같은 실제 동작은 목록 화면(WorkLogMainScreen)이 이미 갖고
// 있던 것을 [ProjectActions]로 그대로 넘겨받아 재사용한다.
class ProjectActions {
  final Future<void> Function() addPunch;
  final Future<void> Function(Map<String, dynamic> punch) openPunch;
  final Future<void> Function() addReport;
  final Future<void> Function(Map<String, dynamic> report) openReport;
  final Future<void> Function() openReportCalendar;
  final Future<void> Function({String? phaseId, bool add}) openSchedule;
  final void Function() save;
  final void Function() toggleStatus;
  final void Function() toggleArchive;
  final void Function() delete;

  const ProjectActions({
    required this.addPunch,
    required this.openPunch,
    required this.addReport,
    required this.openReport,
    required this.openReportCalendar,
    required this.openSchedule,
    required this.save,
    required this.toggleStatus,
    required this.toggleArchive,
    required this.delete,
  });
}

class ProjectDetailPage extends StatefulWidget {
  final Map<String, dynamic> log;
  final ProjectActions actions;
  final int initialTab;
  final bool openExport;

  const ProjectDetailPage({
    super.key,
    required this.log,
    required this.actions,
    this.initialTab = 0,
    this.openExport = false,
  });

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final Set<String> _expandedPhases = {};

  Map<String, dynamic> get log => widget.log;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    if (widget.openExport) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showReportExport();
      });
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  bool get _isActive => log['status'] != 'DONE';

  Future<void> _run(Future<void> Function() f) async {
    await f();
    if (mounted) setState(() {});
  }

  void _changed() {
    widget.actions.save();
    setState(() {});
  }

  String _md(DateTime d) => "${d.month}/${d.day}";

  String _dday(DateTime due) {
    final diff = due.difference(dayOnly(DateTime.now())).inDays;
    if (diff == 0) return "D-Day";
    return diff > 0 ? "D-$diff" : "D+${-diff}";
  }

  Color _ddayColor(DateTime due) {
    final diff = due.difference(dayOnly(DateTime.now())).inDays;
    if (diff < 0) return warningRed;
    if (diff <= 7) return const Color(0xFFC77700);
    return tossBlue;
  }

  // ───────────────────────── 요약 헤더 ─────────────────────────
  Widget _buildHeader() {
    final progress = projectProgress(log);
    final due = projectDue(log);
    final cur = currentPhase(log);
    final issues = unresolvedIssueCount(log);
    return Container(
      color: pureWhite,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "${(progress * 100).round()}%",
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: tossText,
                    letterSpacing: -1,
                  ),
                ),
              ),
              if (due != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _ddayColor(due).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "납기 ${_dday(due)}",
                    style: TextStyle(
                      color: _ddayColor(due),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: tossBg,
              color: progress >= 1 ? Colors.green : tossBlue,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              if (cur != null)
                _miniInfo(Icons.flag_rounded, "현재 ${cur['name']}", tossBlue),
              if (due != null)
                _miniInfo(
                  Icons.event_rounded,
                  "종료 예정 ${due.year}.${due.month}.${due.day}",
                  tossSubText,
                ),
              _miniInfo(
                Icons.error_outline_rounded,
                "미해결 이슈 $issues",
                issues > 0 ? warningRed : tossSubText,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniInfo(IconData icon, String text, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _buildContactsSection() {
    final list = _contacts;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.contacts_outlined, size: 18, color: tossBlue),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  "연락처",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: tossText,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _editContact(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("추가"),
              ),
            ],
          ),
          if (list.isEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 6, right: 8),
              child: Text(
                keepWords("현장 담당자, 협력사, 자재 업체 연락처를 적어 두면 바로 전화·문자할 수 있습니다."),
                style: TextStyle(color: tossSubText, fontSize: 12, height: 1.4),
              ),
            ),
          for (int i = 0; i < list.length; i++)
            InkWell(
              onLongPress: () => _editContact(index: i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${list[i]['name']}  ·  ${list[i]['role']}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: tossText,
                              fontSize: 14,
                            ),
                          ),
                          if ((list[i]['phone']?.toString() ?? '').isNotEmpty)
                            Text(
                              list[i]['phone'].toString(),
                              style: const TextStyle(
                                color: tossSubText,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if ((list[i]['phone']?.toString() ?? '').isNotEmpty) ...[
                      IconButton(
                        tooltip: "전화",
                        icon: const Icon(
                          Icons.call_rounded,
                          color: Colors.green,
                        ),
                        onPressed: () => _call(list[i]['phone'].toString()),
                      ),
                      IconButton(
                        tooltip: "문자",
                        icon: const Icon(Icons.sms_outlined, color: tossBlue),
                        onPressed: () =>
                            _call(list[i]['phone'].toString(), sms: true),
                      ),
                    ],
                    IconButton(
                      tooltip: "수정",
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: tossSubText,
                      ),
                      onPressed: () => _editContact(index: i),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ───────────────────────── 공사 유형 ─────────────────────────
  Widget _buildTypeRow() {
    final t = log['workType']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: const Icon(
            Icons.category_outlined,
            size: 16,
            color: tossBlue,
          ),
          label: Text(t.isEmpty ? "공사 유형 지정" : "공사 유형: $t"),
          backgroundColor: pureWhite,
          side: BorderSide.none,
          labelStyle: const TextStyle(
            color: tossBlue,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          onPressed: _pickType,
        ),
      ),
    );
  }

  Future<void> _pickType() async {
    final ctrl = TextEditingController();
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "공사 유형",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in kProjectTypes)
                  ActionChip(
                    label: Text(t),
                    onPressed: () => Navigator.pop(ctx, t),
                  ),
                ActionChip(
                  label: const Text("지정 안 함"),
                  onPressed: () => Navigator.pop(ctx, ''),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: "직접 입력 (예: 반도체 라인 이설)",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_rounded),
                  onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                ),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    if (picked.isEmpty) {
      log.remove('workType');
    } else {
      log['workType'] = picked;
    }
    _changed();
  }

  // ───────────────────────── 완료 결과 정리 ─────────────────────────
  Map<String, dynamic> get _retro =>
      Map<String, dynamic>.from((log['retro'] as Map?) ?? {});

  // 결과 정리(원인 또는 참고할 점)가 한 줄이라도 적혀 있는지.
  bool get _retroFilled {
    final r = _retro;
    return (r['cause']?.toString() ?? '').trim().isNotEmpty ||
        (r['lesson']?.toString() ?? '').trim().isNotEmpty;
  }

  // 완료 처리 직후: 결과 정리를 바로 쓰겠는지 묻고, 쓰겠다고 하면 입력 창을 연다.
  Future<void> _offerRetro() async {
    if (_retroFilled) return;
    final write = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(keepWords("결과 정리를 작성하시겠습니까?")),
        content: Text(keepWords("지연 원인과 다음에 참고할 점을 적어 두면 마무리 보고서에 함께 들어갑니다.")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("나중에"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("작성"),
          ),
        ],
      ),
    );
    if (write == true && mounted) await _editRetro();
  }

  Future<void> _editRetro() async {
    final r = _retro;
    final cause = TextEditingController(text: r['cause']?.toString() ?? '');
    final lesson = TextEditingController(text: r['lesson']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("프로젝트 결과 정리"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: cause,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "지연/문제 원인",
                  hintText: "예: 자재 입고가 2주 늦어짐",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lesson,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "다음에 참고할 점",
                  hintText: "예: 자재는 시작하기 전에 미리 발주",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("저장"),
          ),
        ],
      ),
    );
    if (ok == true) {
      log['retro'] = {
        'cause': cause.text.trim(),
        'lesson': lesson.text.trim(),
        'updatedAt': DateTime.now(),
      };
      _changed();
    }
  }

  List<Widget> _buildRetroSection() {
    if (_isActive) return [];
    final ps = projectStart(log), pd = projectDue(log);
    final dates = [
      for (final r in (log['daily_reports'] as List? ?? []).whereType<Map>())
        reportDateOf(r),
    ]..sort();
    final actualStart = dates.isNotEmpty ? dates.first : null;
    final actualEnd = log['completedAt'] != null
        ? dayOnly(asDate(log['completedAt']))
        : (dates.isNotEmpty ? dates.last : null);
    final planned = (ps != null && pd != null)
        ? pd.difference(ps).inDays + 1
        : null;
    final actual = (actualStart != null && actualEnd != null)
        ? actualEnd.difference(actualStart).inDays + 1
        : null;
    final r = _retro;
    final cause = r['cause']?.toString() ?? '';
    final lesson = r['lesson']?.toString() ?? '';
    final finalShare = finalReportShareLabel(log);

    Widget line(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: tossSubText, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? tossText,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );

    final diff = (planned != null && actual != null) ? actual - planned : null;
    final phaseLines = <Widget>[];
    for (final p in phasesOf(log)) {
      final s = phaseStart(p), e = phaseEnd(p);
      final st = phaseWorkStats(log, p['id'].toString());
      if (s == null || e == null) continue;
      final plannedDays = e.difference(s).inDays + 1;
      phaseLines.add(
        line(
          p['name'].toString(),
          "계획 $plannedDays일 → 작업 ${st.days}일 (${st.manDays}인·일)",
        ),
      );
    }

    return [
      Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.flag_circle_outlined,
                  color: tossBlue,
                  size: 20,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    "프로젝트 결과 정리",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: tossText,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _editRetro,
                  child: Text(cause.isEmpty && lesson.isEmpty ? "작성" : "수정"),
                ),
              ],
            ),
            if (finalShare != null) line("마무리 보고서", finalShare),
            if (planned != null) line("계획 기간", "$planned일"),
            if (actual != null) line("실제 기간", "$actual일"),
            if (diff != null)
              line(
                "차이",
                diff == 0
                    ? "계획대로 완료"
                    : diff > 0
                    ? "$diff일 지연"
                    : "${-diff}일 단축",
                color: diff > 0 ? warningRed : Colors.green.shade700,
              ),
            if (phaseLines.isNotEmpty) ...[
              const Divider(height: 20),
              ...phaseLines,
            ],
            if (cause.isNotEmpty) ...[
              const Divider(height: 20),
              const Text(
                "지연/문제 원인",
                style: TextStyle(color: tossSubText, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(cause, style: const TextStyle(color: tossText, height: 1.4)),
            ],
            if (lesson.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                "다음에 참고할 점",
                style: TextStyle(color: tossSubText, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                lesson,
                style: const TextStyle(color: tossText, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  // ───────────────────────── 지연 경고 ─────────────────────────
  List<Widget> _buildDelayBanner() {
    final d = delayedPhase(log);
    if (d == null) return [];
    final after = phasesOf(log).length - d.index - 1;
    return [
      Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: warningRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: warningRed.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: warningRed,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    keepWords("'${d.phase['name']}' 단계가 ${d.days}일 지연되고 있습니다"),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: warningRed,
                    ),
                  ),
                ),
              ],
            ),
            if (after > 0) ...[
              const SizedBox(height: 6),
              Text(
                keepWords("뒤 단계 $after개의 일정도 그만큼 밀릴 수 있습니다."),
                style: const TextStyle(fontSize: 12, color: tossSubText),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _confirmShift(d.index, d.days),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: warningRed,
                    side: const BorderSide(color: warningRed),
                  ),
                  child: Text(keepWords("뒤 단계도 ${d.days}일 밀기")),
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  Future<void> _confirmShift(int index, int days) async {
    bool withSchedules = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text("뒤 단계 일정 밀기"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                keepWords("지연된 단계의 종료일을 오늘로 늘리고, 뒤 단계의 시작/종료일을 $days일씩 미룹니다."),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: withSchedules,
                onChanged: (v) => setD(() => withSchedules = v == true),
                title: Text(
                  keepWords("뒤 단계의 미완료 세부 일정도 함께 밀기 (알림도 새 날짜로 다시 보냅니다)"),
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("밀기"),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      shiftPhasesAfterDelay(log, index, days, includeSchedules: withSchedules);
      _changed();
    }
  }

  // ───────────────────────── 기간 보고서 ─────────────────────────
  void _showReportExport() {
    int mode = 0; // 0=최근 7일 1=최근 14일 2=이번 달 3=전체
    bool withPhotos = ReportStyle.current.defaultPhotos;
    showModalBottomSheet(
      context: context,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          ReportDoc build() {
            final now = dayOnly(DateTime.now());
            final from = switch (mode) {
              0 => now.subtract(const Duration(days: 6)),
              1 => now.subtract(const Duration(days: 13)),
              2 => DateTime(now.year, now.month, 1),
              _ => DateTime(2000),
            };
            return buildReportDoc(log, from, now);
          }

          const labels = ['최근 7일', '최근 14일', '이번 달', '전체'];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "작업 보고서 내보내기",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (int i = 0; i < labels.length; i++)
                        ChoiceChip(
                          label: Text(labels[i]),
                          selected: mode == i,
                          onSelected: (_) => setS(() => mode = i),
                        ),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: withPhotos,
                    onChanged: (v) => setS(() => withPhotos = v == true),
                    title: Text(
                      keepWords("PDF에 사진 포함 (최대 24장, 만드는 데 시간이 걸립니다)"),
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await shareReportText(build());
                          },
                          icon: const Icon(Icons.chat_outlined, size: 18),
                          label: const Text("텍스트(카톡)"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            try {
                              await shareReportPdf(
                                build(),
                                withPhotos: withPhotos,
                              );
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(keepWords("PDF 생성 실패: $e")),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 18,
                          ),
                          label: const Text("PDF"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────────────────────── 자재 현황 ─────────────────────────
  List<Widget> _buildMaterialCard() {
    final mats = schedulesOf(log).where(isMaterialSchedule).toList();
    if (mats.isEmpty) return [];
    final counts = {'pending': 0, 'expected': 0, 'late': 0, 'done': 0};
    for (final m in mats) {
      counts[materialState(m)] = counts[materialState(m)]! + 1;
    }
    final open = mats.where((m) => materialState(m) != 'done').toList()
      ..sort((a, b) {
        int rank(Map m) => switch (materialState(m)) {
          'late' => 0,
          'pending' => 1,
          _ => 2,
        };
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        if (a['dateTime'] == null || b['dateTime'] == null) return 0;
        return asDate(a['dateTime']).compareTo(asDate(b['dateTime']));
      });
    Widget stat(String label, String key, Color c) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: c.withValues(alpha: counts[key]! > 0 ? 0.12 : 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              "${counts[key]}",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: counts[key]! > 0 ? c : tossSubText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: counts[key]! > 0 ? c : tossSubText,
              ),
            ),
          ],
        ),
      ),
    );
    return [
      _sectionTitle("자재 현황"),
      const SizedBox(height: 10),
      Row(
        children: [
          stat("입고일 미정", 'pending', const Color(0xFFC77700)),
          const SizedBox(width: 8),
          stat("입고 예정", 'expected', tossBlue),
          const SizedBox(width: 8),
          stat("입고 지연", 'late', warningRed),
          const SizedBox(width: 8),
          stat("입고 완료", 'done', Colors.green),
        ],
      ),
      const SizedBox(height: 6),
      ...(() {
        final used = mats
            .where(
              (m) => materialUsageCount(log, m['id']?.toString() ?? '') > 0,
            )
            .toList();
        if (used.isEmpty) return <Widget>[];
        return <Widget>[
          const SizedBox(height: 10),
          const Text(
            "작업 일지에 적힌 사용 기록",
            style: TextStyle(
              color: tossSubText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final m in used.take(6))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                keepWords(
                  "• ${m['title'] ?? m['type']} · ${materialUsageCount(log, m['id'].toString())}일 사용",
                ),
                style: const TextStyle(color: tossText, fontSize: 13),
              ),
            ),
          const SizedBox(height: 6),
        ];
      })(),
      ...(() {
        final unused = unusedReceivedMaterials(log);
        if (unused.isEmpty) return <Widget>[];
        return <Widget>[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFC77700).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "입고됐지만 사용 기록이 없습니다",
                  style: TextStyle(
                    color: Color(0xFFC77700),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                for (final m in unused.take(4))
                  Text(
                    "• ${m['title'] ?? m['type']}",
                    style: const TextStyle(color: tossText, fontSize: 13),
                  ),
                if (unused.length > 4)
                  Text(
                    "외 ${unused.length - 4}건",
                    style: const TextStyle(color: tossSubText, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ];
      })(),
      ...(() {
        final vs = _contacts
            .where(
              (c) =>
                  c['role'] == '자재 업체' &&
                  (c['phone']?.toString() ?? '').isNotEmpty,
            )
            .toList();
        if (vs.isEmpty) return <Widget>[];
        return <Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final v in vs)
                ActionChip(
                  avatar: const Icon(Icons.call_rounded, size: 14),
                  label: Text("${v['name']}에 전화"),
                  backgroundColor: pureWhite,
                  onPressed: () => _call(v['phone'].toString()),
                ),
            ],
          ),
        ];
      })(),
      ...open.take(5).map(_scheduleRow),
      if (open.length > 5)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _tab.animateTo(1),
            child: Text(keepWords("나머지 ${open.length - 5}건 더 보기")),
          ),
        ),
      const SizedBox(height: 22),
    ];
  }

  String _workStatText(String phaseId) {
    final st = phaseWorkStats(log, phaseId);
    if (st.days == 0) return "";
    return "  ·  투입 ${st.days}일 (${st.manDays}인·일)";
  }

  // ───────────────────────── 작업 일지 선택 내보내기 ─────────────────────────
  bool _selectMode = false;
  final Set<Map> _sel = {};

  // 작업 일지 확정: 확정한 작업 일지는 수정하려면 사유를 남기고 확정을 풀어야 한다.
  Future<void> _lockReports(List<Map> reps) async {
    final targets = reps.where((r) => r['locked'] != true).toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(keepWords("확정할 작업 일지가 없습니다."))));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("작업 일지 확정"),
        content: Text(
          keepWords(
            "작업 일지 ${targets.length}건을 확정본으로 잠그시겠습니까?\n확정한 뒤 수정하려면 사유를 남기고 확정을 풀어야 합니다(기록이 남습니다).",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("확정"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final now = DateTime.now();
    for (final r in targets) {
      r['locked'] = true;
      r['lockedAt'] = now;
    }
    setState(() {
      _selectMode = false;
      _sel.clear();
    });
    _changed();
  }

  // 이 프로젝트만 다른 시간에 작업 일지 알림을 받고 싶을 때(기본 시간은 ⋮ 메뉴의 알림 설정).
  // 완료된 프로젝트에 남은 미해결 이슈를 한꺼번에 처리 완료로 정리한다.
  Future<void> _resolveAllOpenIssues() async {
    final n = openIssueCount(log);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(keepWords("남은 이슈를 모두 완료하시겠습니까?")),
        content: Text(
          keepWords(
            "미해결 이슈 $n건을 '처리 완료'로 바꿉니다. 처리 내용에는 '프로젝트 완료 시 한꺼번에 처리'라고 남습니다.",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("모두 처리 완료"),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final done = resolveOpenIssues(log);
    widget.actions.save();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(keepWords("이슈 $done건을 처리 완료로 바꿨습니다."))),
    );
  }

  Future<void> _editProjectReminder() async {
    final cur = (log['reportReminderMinutes'] as num?)?.toInt();
    final base = (await loadReportReminder()).minutes;
    String hm(int m) =>
        "${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}";
    if (!mounted) return;
    final pick = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(keepWords("이 프로젝트 작업 일지 알림 시간")),
        content: Text(
          cur == null
              ? "지금은 기본 시간(${hm(base)})에 알림을 보냅니다."
              : "지금은 ${hm(cur)}에 알림을 보냅니다. (기본 시간 ${hm(base)})",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text("취소"),
          ),
          if (cur != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'default'),
              child: const Text("기본 시간 쓰기"),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'pick'),
            child: const Text("시간 설정"),
          ),
        ],
      ),
    );
    if (!mounted || pick == null || pick == 'cancel') return;
    if (pick == 'default') {
      log.remove('reportReminderMinutes');
    } else {
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: (cur ?? base) ~/ 60,
          minute: (cur ?? base) % 60,
        ),
      );
      if (t == null || !mounted) return;
      log['reportReminderMinutes'] = t.hour * 60 + t.minute;
    }
    widget.actions.save(); // 저장하면 알림도 다시 맞춘다
    setState(() {});
    if (mounted) {
      final m = (log['reportReminderMinutes'] as num?)?.toInt();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            m == null ? "기본 시간으로 알림을 보내겠습니다." : "${hm(m)}에 알림을 보내겠습니다.",
          ),
        ),
      );
    }
  }

  // 프로젝트를 완료 처리하면 마무리 보고서(PDF, 사진 포함)를 바로 만들지 묻는다.
  Future<void> _offerFinalReport() async {
    final make = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(keepWords("마무리 보고서를 만드시겠습니까?")),
        content: Text(
          keepWords("시작부터 지금까지의 전체 기록을 사진 포함 PDF로 만들어 공유할 수 있습니다."),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("나중에"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("PDF 만들기"),
          ),
        ],
      ),
    );
    if (make != true || !mounted) return;
    try {
      final r = await shareReportPdf(
        buildFinalReportDoc(log),
        withPhotos: true,
      );
      recordFinalReportShare(log, r.status);
      widget.actions.save();
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(keepWords(pdfShareNotice(r.status, '마무리 보고서'))),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(keepWords("PDF 생성 실패: $e"))));
      }
    }
  }

  Future<void> _exportSelected() async {
    if (_sel.isEmpty) return;
    final doc = buildReportDoc(
      log,
      DateTime(2000),
      DateTime.now().add(const Duration(days: 1)),
      only: _sel.toList(),
    );
    final fmt = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text("텍스트로 공유 (카톡)"),
              onTap: () => Navigator.pop(ctx, 'text'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text("PDF로 공유"),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text("PDF로 공유 (사진 포함)"),
              onTap: () => Navigator.pop(ctx, 'pdfp'),
            ),
          ],
        ),
      ),
    );
    try {
      if (fmt == 'text') await shareReportText(doc);
      if (fmt == 'pdf') await shareReportPdf(doc);
      if (fmt == 'pdfp') await shareReportPdf(doc, withPhotos: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(keepWords("내보내기 실패: $e"))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tossBg,
      appBar: AppBar(
        backgroundColor: pureWhite,
        foregroundColor: tossText,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Flexible(
              child: Text(
                log['name']?.toString() ?? '이름 없음',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            if (!_isActive) ...[
              const SizedBox(width: 8),
              const Text(
                "완료됨",
                style: TextStyle(color: tossSubText, fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          // 🚀 [고침] 저장 대기 표시가 메인 목록에만 있어, 일지를 쓰는 이 화면에서는
          // 통신이 없을 때 폰에만 있는지 알 수 없었다.
          ValueListenableBuilder<int>(
            valueListenable: WorkProjectRepository.pendingWrites,
            builder: (context, pending, _) => pending == 0
                ? const SizedBox.shrink()
                : Tooltip(
                    message: "서버에 저장하는 중입니다. 통신이 없으면 연결될 때 자동으로 올라갑니다.",
                    child: Padding(
                      key: const Key('project_pending_sync'),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 18,
                            color: tossBlue,
                          ),
                          SizedBox(width: 4),
                          Text(
                            "저장 중",
                            style: TextStyle(
                              color: tossBlue,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          PopupMenuButton<String>(
            tooltip: "더보기",
            onSelected: (v) {
              if (v == 'optimize') _optimizePhotos();
              if (v == 'summary') _shareSummaryImage();
              if (v == 'header') _editReportHeader();
              if (v == 'reminder') _editProjectReminder();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'summary', child: Text("현황 요약 이미지 공유")),
              PopupMenuItem(value: 'header', child: Text("이 프로젝트 보고서 머리말")),
              PopupMenuItem(
                value: 'reminder',
                child: Text("이 프로젝트 작업 일지 알림 시간"),
              ),
              PopupMenuItem(value: 'optimize', child: Text("사진 용량 정리")),
            ],
          ),
          IconButton(
            tooltip: "투입 통계",
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => Navigator.push(
              context,
              WorkRoute(
                builder: (_) => ProjectStatsPage(
                  logs: [log],
                  title: "${log['name'] ?? '프로젝트'} 통계",
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tab.animation!,
        builder: (context, _) {
          final i = _tab.index;
          if (i == 0 || !_isActive) return const SizedBox.shrink();
          final (label, icon, action) = switch (i) {
            1 => (
              "일정 추가",
              Icons.add_task_rounded,
              () => _run(() => widget.actions.openSchedule(add: true)),
            ),
            2 => (
              "이슈 등록",
              Icons.error_outline_rounded,
              () => _run(widget.actions.addPunch),
            ),
            _ => (
              "일지 작성",
              Icons.edit_document,
              () => _run(widget.actions.addReport),
            ),
          };
          return FloatingActionButton.extended(
            onPressed: action,
            backgroundColor: tossBlue,
            foregroundColor: pureWhite,
            icon: Icon(icon),
            label: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          );
        },
      ),
      body: Column(
        children: [
          _buildHeader(),
          Container(
            color: pureWhite,
            child: TabBar(
              controller: _tab,
              labelColor: tossBlue,
              unselectedLabelColor: tossSubText,
              indicatorColor: tossBlue,
              labelPadding: EdgeInsets.zero,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: "개요"),
                Tab(text: "단계·일정"),
                Tab(text: "이슈"),
                Tab(text: "일지"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildOverviewTab(),
                _buildPhasesTab(),
                _buildIssuesTab(),
                _buildReportsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
