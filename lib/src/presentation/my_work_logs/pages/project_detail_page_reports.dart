// ignore_for_file: invalid_use_of_protected_member
part of 'project_detail_page.dart';

// 🚀 reports 부분(화면 클래스에서 옮겨 온 메서드들, 동작은 그대로).
extension _ProjectDetailReports on _ProjectDetailPageState {
  // ───────────────────────── 일지 타임라인 ─────────────────────────
  // 날짜는 "MM/dd" 문자열이라 월 단위로 묶어 헤더를 붙이고, 카드마다 요약 한 줄,
  // 사진 썸네일, 단계/이슈/일정완료 칩을 보여준다.
  List<Widget> _buildReportTimeline(List reports) {
    final phaseNames = {
      for (final p in phasesOf(log)) p['id'].toString(): p['name'].toString(),
    };
    final out = <Widget>[];
    String? lastMonth;
    for (final r in reports) {
      if (r is! Map) continue;
      final date = r['date']?.toString() ?? '';
      final rd = reportDateOf(r);
      final month = date.contains('/')
          ? "${rd.year == DateTime.now().year ? '' : '${rd.year}년 '}${rd.month}월"
          : '';
      if (month != lastMonth) {
        lastMonth = month;
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Text(
              month,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: tossSubText,
              ),
            ),
          ),
        );
      }
      final card = _reportCard(r, phaseNames);
      out.add(
        _selectMode
            ? Row(
                children: [
                  Checkbox(
                    value: _sel.contains(r),
                    activeColor: tossBlue,
                    onChanged: (_) => setState(() {
                      _sel.contains(r) ? _sel.remove(r) : _sel.add(r);
                    }),
                  ),
                  Expanded(child: card),
                ],
              )
            : card,
      );
    }
    return out;
  }

  Widget _reportCard(Map r, Map<String, String> phaseNames) {
    final note = (r['note']?.toString() ?? '').trim();
    final summary = (note.isEmpty || note == '특이사항 없음')
        ? (r['materials_used']?.toString().isNotEmpty == true
              ? "자재: ${r['materials_used']}"
              : "특이사항 없음")
        : note.split('\n').first;
    final types = (r['work_type'] is List)
        ? (r['work_type'] as List).join(' · ')
        : (r['work_type']?.toString() ?? '');
    final phaseChips = reportIds(
      r,
      'workedPhaseIds',
    ).map((id) => phaseNames[id]).whereType<String>().toList();
    final imgTags = Map<String, dynamic>.from((r['image_tags'] as Map?) ?? {});
    final imgs = (r['image_paths'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    final issueCnt = reportIds(r, 'linkedIssueIds').length;
    final doneCnt = reportIds(r, 'completedScheduleIds').length;
    final pt = (r['points'] as num?)?.toInt() ?? 0;
    final wp = (r['wiring_points'] as num?)?.toInt() ?? 0;

    Widget chip(String t, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        t,
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (_selectMode) {
            setState(() {
              _sel.contains(r) ? _sel.remove(r) : _sel.add(r);
            });
          } else {
            _run(() => widget.actions.openReport(r as Map<String, dynamic>));
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "${r['date'] ?? ''}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: tossText,
                    ),
                  ),
                  if (r['locked'] == true)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 14,
                        color: tossSubText,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "$types · ${r['worker_count'] ?? 1}명${r['is_overtime'] == true ? ' · 연장' : ''}",
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: tossSubText),
                    ),
                  ),
                  if (pt > 0 || wp > 0)
                    Text(
                      [if (pt > 0) "${pt}pt", if (wp > 0) "결선 $wp"].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: tossBlue,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: tossText,
                  height: 1.4,
                ),
              ),
              if (phaseChips.isNotEmpty ||
                  issueCnt > 0 ||
                  doneCnt > 0 ||
                  r['is_as_built'] == true) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final n in phaseChips) chip(n, tossBlue),
                    if (issueCnt > 0) chip("이슈 처리 $issueCnt", warningRed),
                    if (doneCnt > 0) chip("일정 완료 $doneCnt", Colors.green),
                    if (r['is_as_built'] == true)
                      chip("도면 수정 요청", const Color(0xFFC77700)),
                  ],
                ),
              ],
              if (imgs.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: imgs.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          PhotoImage(imgs[i], width: 56, height: 56),
                          if (imgTags[imgs[i]] != null)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                color: Colors.black54,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 1,
                                ),
                                child: Text(
                                  imgTags[imgs[i]].toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    final reports = (log['daily_reports'] as List? ?? []);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _run(widget.actions.openReportCalendar),
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: const Text("달력/통계"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tossBlue,
                  side: const BorderSide(color: tossBlue),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showReportExport,
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text("내보내기"),
                style: OutlinedButton.styleFrom(foregroundColor: tossText),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  WorkRoute(builder: (_) => ProjectPhotosPage(log: log)),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text("사진 모아보기"),
                style: OutlinedButton.styleFrom(foregroundColor: tossText),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (reports.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: _selectMode
                ? Row(
                    children: [
                      TextButton(
                        onPressed: () => setState(() {
                          _selectMode = false;
                          _sel.clear();
                        }),
                        child: const Text("취소"),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _sel
                            ..clear()
                            ..addAll(reports.whereType<Map>());
                        }),
                        child: const Text("전체 선택"),
                      ),
                      TextButton(
                        onPressed: _sel.isEmpty
                            ? null
                            : () => _lockReports(_sel.toList()),
                        child: const Text("확정"),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _sel.isEmpty ? null : _exportSelected,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tossBlue,
                        ),
                        child: Text(
                          keepWords("${_sel.length}건 내보내기"),
                          style: const TextStyle(color: pureWhite),
                        ),
                      ),
                    ],
                  )
                : Wrap(
                    children: [
                      TextButton.icon(
                        onPressed: () => setState(() => _selectMode = true),
                        icon: const Icon(Icons.checklist_rounded, size: 18),
                        label: const Text("선택해서 내보내기/확정"),
                        style: TextButton.styleFrom(
                          foregroundColor: tossSubText,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            _lockReports(reports.whereType<Map>().toList()),
                        icon: const Icon(Icons.lock_outline_rounded, size: 18),
                        label: const Text("전부 확정"),
                        style: TextButton.styleFrom(
                          foregroundColor: tossSubText,
                        ),
                      ),
                    ],
                  ),
          ),
        const SizedBox(height: 10),
        if (reports.isEmpty)
          _emptyText("작성된 일지가 없습니다.")
        else
          ..._buildReportTimeline(reports),
      ],
    );
  }
}
