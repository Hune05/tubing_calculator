// ignore_for_file: invalid_use_of_protected_member
part of 'project_detail_page.dart';

// 🚀 overview 부분(화면 클래스에서 옮겨 온 메서드들, 동작은 그대로).
extension _ProjectDetailOverview on _ProjectDetailPageState {
  // ───────────────────────── 개요 탭 ─────────────────────────
  Widget _buildOverviewTab() {
    final phases = phasesOf(log);
    final today = dayOnly(DateTime.now());
    final weekEnd = today.add(const Duration(days: 7));
    final upcoming =
        schedulesOf(log).where((s) {
          if (s['isCompleted'] == true) return false;
          // 자재 요청/입고일은 위의 "자재 현황" 카드에서 보여주므로 여기선 뺀다(중복 방지).
          if (isMaterialSchedule(s)) return false;
          if (s['dateTime'] == null) return true;
          return !dayOnly(asDate(s['dateTime'])).isAfter(weekEnd);
        }).toList()..sort((a, b) {
          if (a['dateTime'] == null) return -1;
          if (b['dateTime'] == null) return 1;
          return asDate(a['dateTime']).compareTo(asDate(b['dateTime']));
        });
    final punches =
        (log['punch_lists'] as List? ?? [])
            .whereType<Map>()
            .where((p) => p['is_completed'] != true)
            .map((p) => p as Map<String, dynamic>)
            .toList()
          ..sort((a, b) {
            const order = {'긴급': 0, '보통': 1, '여유': 2};
            return (order[a['priority']] ?? 1).compareTo(
              order[b['priority']] ?? 1,
            );
          });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _buildTypeRow(),
        _buildContactsSection(),
        Row(
          children: [
            Expanded(
              child: _quickButton(
                Icons.add_task_rounded,
                "일정 추가",
                () => _run(() => widget.actions.openSchedule(add: true)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickButton(
                Icons.edit_document,
                "일지 작성",
                () => _run(widget.actions.addReport),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickButton(
                Icons.error_outline_rounded,
                "이슈 등록",
                () => _run(widget.actions.addPunch),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ..._buildRetroSection(),
        ..._buildDelayBanner(),
        if (phases.isNotEmpty) ...[
          _sectionTitle("단계 진행"),
          const SizedBox(height: 10),
          _buildPhaseStrip(phases),
          const SizedBox(height: 22),
        ],
        ..._buildMaterialCard(),
        _sectionTitle("금주 · 지연 일정 (${upcoming.length})"),
        const SizedBox(height: 8),
        if (upcoming.isEmpty)
          _emptyText("금주에 확인할 일정이 없습니다.")
        else
          ...upcoming.take(6).map(_scheduleRow),
        const SizedBox(height: 22),
        _sectionTitle("미해결 이슈 (${punches.length})"),
        const SizedBox(height: 8),
        if (punches.isEmpty)
          _emptyText("미해결 이슈가 없습니다.")
        else
          ...punches
              .take(4)
              .map(
                (p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    p['content']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tossText,
                    ),
                  ),
                  subtitle: Text(
                    keepWords(
                      "${p['location'] ?? ''}  ·  ${p['priority'] ?? '보통'}${issueOverdueDays(p) > 0 ? '  ·  기한 초과 ${issueOverdueDays(p)}일' : ''}",
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: issueOverdueDays(p) > 0
                          ? const Color(0xFFE5484D)
                          : tossSubText,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _run(() => widget.actions.openPunch(p)),
                ),
              ),
        const SizedBox(height: 28),
        Center(
          child: TextButton.icon(
            onPressed: () async {
              // 완료로 바꾸려는데 미해결 이슈가 남아 있으면 한 번 더 확인한다.
              if (_isActive) {
                final open = openIssueCount(log);
                if (open > 0) {
                  final go = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(keepWords("미해결 이슈가 남아 있습니다")),
                      content: Text(
                        keepWords("이슈 $open건이 아직 해결되지 않았습니다. 그래도 완료 처리하시겠습니까?"),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, 'cancel'),
                          child: const Text("취소"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, 'issues'),
                          child: const Text("이슈 보기"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, 'done'),
                          child: const Text("그래도 완료"),
                        ),
                      ],
                    ),
                  );
                  if (!mounted) return;
                  if (go == 'issues') {
                    _tab.animateTo(2); // 이슈 탭
                    return;
                  }
                  if (go != 'done') return;
                }
              }
              widget.actions.toggleStatus();
              setState(() {});
              if (!_isActive) {
                // 1) 결과 정리(원인·다음에 참고할 점)를 아직 안 썼으면 바로 이어서 묻는다.
                //    마무리 보고서에 들어가야 하므로 보고서보다 먼저 묻는다.
                await _offerRetro();
                if (!mounted) return;
                // 2) 마무리 보고서(PDF)
                await _offerFinalReport();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(keepWords("프로젝트를 완료 처리했습니다.")),
                    persist: false,
                    action: _retroFilled
                        ? null
                        : SnackBarAction(
                            label: "결과 정리 작성",
                            onPressed: _editRetro,
                          ),
                  ),
                );
              }
            },
            icon: Icon(
              _isActive
                  ? Icons.check_circle_outline_rounded
                  : Icons.replay_rounded,
              size: 18,
            ),
            label: Text(_isActive ? "프로젝트 완료 처리" : "다시 진행중으로"),
            style: TextButton.styleFrom(
              foregroundColor: _isActive ? Colors.green : tossBlue,
            ),
          ),
        ),
        if (!_isActive && openIssueCount(log) > 0)
          Center(
            child: TextButton.icon(
              onPressed: _resolveAllOpenIssues,
              icon: const Icon(Icons.task_alt_rounded, size: 18),
              label: Text(keepWords("남은 이슈 ${openIssueCount(log)}건 모두 처리 완료")),
              style: TextButton.styleFrom(foregroundColor: tossSubText),
            ),
          ),
        if (!_isActive)
          Center(
            child: TextButton.icon(
              onPressed: () {
                final was = log['archived'] == true;
                widget.actions.toggleArchive();
                if (!was) {
                  Navigator.pop(context);
                } else {
                  setState(() {});
                }
              },
              icon: Icon(
                log['archived'] == true
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                size: 18,
              ),
              label: Text(log['archived'] == true ? "보관 해제" : "보관함으로 이동"),
              style: TextButton.styleFrom(foregroundColor: tossSubText),
            ),
          ),
        Center(
          child: TextButton(
            onPressed: _confirmDelete,
            style: TextButton.styleFrom(foregroundColor: tossSubText),
            child: const Text("이 프로젝트 삭제하기"),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("프로젝트 삭제"),
        content: Text(keepWords("일정·일지·이슈가 모두 함께 삭제됩니다. 계속하시겠습니까?")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("삭제", style: TextStyle(color: warningRed)),
          ),
        ],
      ),
    );
    if (ok == true) {
      widget.actions.delete();
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _quickButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: pureWhite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: tossBlue, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: tossText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: 15,
      color: tossText,
    ),
  );

  // 빈 상태는 아이콘과 함께 옅은 상자로 보여줘서 "비어 있음"이 한눈에 보이게 한다.
  Widget _emptyText(String t) => Container(
    margin: const EdgeInsets.symmetric(vertical: 6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: tossSubText.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded, size: 16, color: tossSubText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            t,
            style: const TextStyle(
              color: tossSubText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildPhaseStrip(List<Map<String, dynamic>> phases) {
    final cur = currentPhase(log);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < phases.length; i++) ...[
            InkWell(
              onTap: () => _tab.animateTo(1),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: phaseIsDone(log, phases[i])
                      ? Colors.green.withValues(alpha: 0.14)
                      : (cur != null && cur['id'] == phases[i]['id']
                            ? tossBlue
                            : tossBg),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  phases[i]['name'].toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: phaseIsDone(log, phases[i])
                        ? Colors.green.shade700
                        : (cur != null && cur['id'] == phases[i]['id']
                              ? pureWhite
                              : tossSubText),
                  ),
                ),
              ),
            ),
            if (i < phases.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: tossSubText,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _scheduleRow(Map<String, dynamic> s) {
    final dt = s['dateTime'] == null ? null : asDate(s['dateTime']);
    final overdue = dt != null && dt.isBefore(DateTime.now());
    String badge;
    if (dt == null) {
      badge = "미정";
    } else {
      final diff = dayOnly(dt).difference(dayOnly(DateTime.now())).inDays;
      badge = diff < 0 ? "${-diff}일 지남" : (diff == 0 ? "오늘" : "D-$diff");
    }
    final color = (dt == null || overdue) ? warningRed : tossBlue;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        s['title']?.toString() ?? s['type']?.toString() ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, color: tossText),
      ),
      subtitle: Text(
        "${s['type'] ?? ''}${dt != null ? '  ·  ${_md(dt)}' : ''}",
        style: const TextStyle(fontSize: 12, color: tossSubText),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          badge,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      onTap: () => _run(() => widget.actions.openSchedule()),
    );
  }

  // ───────────────────────── 단계·일정 탭 ─────────────────────────
  void _toggleSchedule(Map<String, dynamic> s) {
    // 검사일정은 합격/불합격 결과를 남겨야 하므로 일정 화면에서 처리한다.
    if (s['type'] == '검사일정') {
      _run(
        () => widget.actions.openSchedule(phaseId: s['phaseId']?.toString()),
      );
      return;
    }
    final list = log['schedules'] as List? ?? [];
    for (final e in list) {
      if (e is Map && e['id'] == s['id']) {
        e['isCompleted'] = !(e['isCompleted'] == true);
        break;
      }
    }
    _changed();
  }
}
