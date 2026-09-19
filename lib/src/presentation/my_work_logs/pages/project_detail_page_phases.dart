// ignore_for_file: invalid_use_of_protected_member
part of 'project_detail_page.dart';

// 🚀 phases 부분(화면 클래스에서 옮겨 온 메서드들, 동작은 그대로).
extension _ProjectDetailPageState_phases on _ProjectDetailPageState {
  Widget _buildPhasesTab() {
    final phases = phasesOf(log);
    final unassigned = schedulesInPhase(log, null);

    if (phases.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
        children: [
          const Icon(Icons.account_tree_outlined, size: 52, color: tossSubText),
          const SizedBox(height: 16),
          Text(
            keepWords("프로젝트를 단계로 나눠 관리해 보십시오"),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: tossText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            keepWords(
              "설계 → 자재 입고 → 제작 → 설치 → 시운전·검사 → 납품\n표준 단계를 시작일/납기일에 맞춰 자동으로 나눠 드립니다.",
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: tossSubText, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showStandardSetup,
            icon: const Icon(Icons.auto_awesome_rounded, color: pureWhite),
            label: const Text(
              "표준 단계로 시작하기",
              style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: tossBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _showPhaseEditor(),
            icon: const Icon(Icons.add_rounded),
            label: const Text("단계 직접 추가"),
          ),
          if (unassigned.isNotEmpty) ...[
            const SizedBox(height: 28),
            _sectionTitle("단계 없는 일정 (${unassigned.length})"),
            ...unassigned.map(_phaseScheduleTile),
          ],
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
      children: [
        ..._buildDelayBanner(),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: (oldI, newI) {
            if (newI > oldI) newI -= 1;
            final list = phasesOf(log);
            final moved = list.removeAt(oldI);
            list.insert(newI, moved);
            setPhases(log, list);
            _changed();
          },
          children: [
            for (int i = 0; i < phases.length; i++)
              _phaseCard(phases[i], i, key: ValueKey(phases[i]['id'])),
          ],
        ),
        if (unassigned.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionTitle("단계 없는 일정 (${unassigned.length})"),
          const SizedBox(height: 6),
          ...unassigned.map(_phaseScheduleTile),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showPhaseEditor(),
          icon: const Icon(Icons.add_rounded),
          label: const Text("단계 추가"),
          style: OutlinedButton.styleFrom(
            foregroundColor: tossBlue,
            side: const BorderSide(color: tossBlue),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        TextButton.icon(
          onPressed: _saveAsTemplate,
          icon: const Icon(Icons.bookmark_add_outlined, size: 18),
          label: const Text("이 단계 구성을 템플릿으로 저장"),
          style: TextButton.styleFrom(foregroundColor: tossSubText),
        ),
      ],
    );
  }

  Widget _phaseCard(Map<String, dynamic> p, int index, {required Key key}) {
    final id = p['id'].toString();
    final items = schedulesInPhase(log, id);
    final progress = phaseProgress(log, p);
    final done = progress >= 1.0;
    final cur = currentPhase(log);
    final isCurrent = cur != null && cur['id'] == p['id'];
    final s = phaseStart(p), e = phaseEnd(p);
    final expanded = _expandedPhases.contains(id);
    final accent = done ? Colors.green : (isCurrent ? tossBlue : tossSubText);

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? tossBlue : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() {
              expanded ? _expandedPhases.remove(id) : _expandedPhases.add(id);
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 8, 12),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: tossSubText,
                        size: 20,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                p['name'].toString(),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: done ? tossSubText : tossText,
                                  decoration: done
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: tossBlue,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  "진행중",
                                  style: TextStyle(
                                    color: pureWhite,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ((s != null && e != null)
                                  ? "${_md(s)} ~ ${_md(e)}  ·  일정 ${items.length}건"
                                  : "기간 미정  ·  일정 ${items.length}건") +
                              _workStatText(p['id'].toString()),
                          style: const TextStyle(
                            color: tossSubText,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: tossBg,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: p['isCompleted'] == true || done,
                    activeColor: Colors.green,
                    onChanged: (v) {
                      final list = phasesOf(log);
                      list[index]['isCompleted'] = v == true;
                      setPhases(log, list);
                      _changed();
                    },
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: tossSubText,
                    ),
                    onSelected: (v) {
                      if (v == 'edit') _showPhaseEditor(existing: p);
                      if (v == 'delete') _deletePhase(p);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text("단계 수정")),
                      PopupMenuItem(value: 'delete', child: Text("단계 삭제")),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  const Divider(height: 1),
                  if (items.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        keepWords("이 단계에 등록된 세부 일정이 없습니다."),
                        style: TextStyle(color: tossSubText, fontSize: 13),
                      ),
                    )
                  else
                    ...items.map(_phaseScheduleTile),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _run(
                            () => widget.actions.openSchedule(
                              phaseId: id,
                              add: true,
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text("세부 일정 추가"),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _run(
                            () => widget.actions.openSchedule(phaseId: id),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text("일정 화면에서 보기"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _phaseScheduleTile(Map<String, dynamic> s) {
    final dt = s['dateTime'] == null ? null : asDate(s['dateTime']);
    final done = s['isCompleted'] == true;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Checkbox(
        value: done,
        activeColor: Colors.green,
        onChanged: (_) => _toggleSchedule(s),
      ),
      title: Text(
        s['title']?.toString() ?? s['type']?.toString() ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: done ? tossSubText : tossText,
          decoration: done ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        keepWords(
          "${s['type'] ?? ''}${dt != null ? '  ·  ${_md(dt)}' : '  ·  날짜 미정'}",
        ),
        style: const TextStyle(fontSize: 12, color: tossSubText),
      ),
      onTap: () => _run(
        () => widget.actions.openSchedule(phaseId: s['phaseId']?.toString()),
      ),
    );
  }

  void _deletePhase(Map<String, dynamic> p) {
    final id = p['id'].toString();
    final list = phasesOf(log)..removeWhere((e) => e['id'] == id);
    setPhases(log, list);
    // 이 단계의 일정은 지우지 않고 "단계 없음"으로 돌린다.
    for (final e in (log['schedules'] as List? ?? [])) {
      if (e is Map && e['phaseId']?.toString() == id) e['phaseId'] = null;
    }
    _changed();
  }

  Future<void> _showPhaseEditor({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(
      text: existing?['name']?.toString() ?? '',
    );
    DateTime? start = existing == null ? null : phaseStart(existing);
    DateTime? end = existing == null ? null : phaseEnd(existing);

    Future<DateTime?> pick(DateTime? initial, DateTime? first) =>
        showDatePicker(
          context: context,
          initialDate: initial ?? first ?? DateTime.now(),
          firstDate: first ?? DateTime(2020),
          lastDate: DateTime(2035),
        );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            decoration: const BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null ? "단계 추가" : "단계 수정",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: tossText,
                  ),
                ),
                const SizedBox(height: 16),
                if (existing == null)
                  Wrap(
                    spacing: 8,
                    children: kStandardPhaseNames
                        .where((n) => !phasesOf(log).any((p) => p['name'] == n))
                        .map(
                          (n) => ActionChip(
                            label: Text(n),
                            backgroundColor: tossBg,
                            side: BorderSide.none,
                            onPressed: () => nameCtrl.text = n,
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  autofocus: existing == null,
                  decoration: InputDecoration(
                    labelText: "단계 이름",
                    filled: true,
                    fillColor: tossBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final d = await pick(start, null);
                          if (d != null) {
                            setSheet(() {
                              start = d;
                              if (end != null && end!.isBefore(d)) end = d;
                            });
                          }
                        },
                        child: Text(
                          start == null
                              ? "시작일"
                              : "${start!.month}/${start!.day} 시작",
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final d = await pick(end ?? start, start);
                          if (d != null) setSheet(() => end = d);
                        },
                        child: Text(
                          end == null ? "종료일" : "${end!.month}/${end!.day} 종료",
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final list = phasesOf(log);
                      if (existing == null) {
                        list.add(makePhase(name, start: start, end: end));
                      } else {
                        final i = list.indexWhere(
                          (p) => p['id'] == existing['id'],
                        );
                        if (i != -1) {
                          list[i]['name'] = name;
                          list[i]['startDate'] = start;
                          list[i]['endDate'] = end;
                        }
                      }
                      setPhases(log, list);
                      Navigator.pop(ctx);
                      _changed();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tossBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      existing == null ? "추가" : "저장",
                      style: const TextStyle(
                        color: pureWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 표준 6단계를 시작일~납기일에 맞춰 비중대로 자동 배분한다.
  Future<void> _showStandardSetup() async {
    DateTime start = dayOnly(DateTime.now());
    DateTime end = start.add(const Duration(days: 55));
    var templates = await loadPhaseTemplates();
    // 프로젝트 공사 유형과 같은 유형으로 저장된 템플릿이 있으면 그걸 먼저 고른다.
    final myType = log['workType']?.toString() ?? '';
    var tpl = templates.firstWhere(
      (t) => myType.isNotEmpty && t.workType == myType,
      orElse: () => templates.first,
    );
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final preview = buildPhasesFromWeights(
            tpl.names,
            tpl.weights,
            start,
            end,
          );
          return Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            decoration: const BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "단계 만들기",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: tossText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    keepWords(
                      "시작일과 납기일만 정하면 각 단계 기간이 자동으로 나뉩니다. 나중에 단계별로 수정할 수 있습니다.",
                    ),
                    style: TextStyle(
                      color: tossSubText,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final t in templates)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onLongPress: t.builtIn
                                  ? null
                                  : () async {
                                      await deletePhaseTemplate(t.name);
                                      final all = await loadPhaseTemplates();
                                      setSheet(() {
                                        templates = all;
                                        tpl = all.first;
                                      });
                                    },
                              child: ChoiceChip(
                                label: Text(
                                  (myType.isNotEmpty && t.workType == myType)
                                      ? "${t.name} ★추천"
                                      : t.name,
                                ),
                                selected:
                                    identical(tpl, t) || tpl.name == t.name,
                                showCheckmark: false,
                                selectedColor: tossBlue,
                                backgroundColor: tossBg,
                                side: BorderSide.none,
                                labelStyle: TextStyle(
                                  color: tpl.name == t.name
                                      ? pureWhite
                                      : tossSubText,
                                  fontWeight: FontWeight.w700,
                                ),
                                onSelected: (_) => setSheet(() => tpl = t),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (templates.length > 1)
                    Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        keepWords("저장한 템플릿은 길게 누르면 삭제됩니다."),
                        style: TextStyle(color: tossSubText, fontSize: 11),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: start,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (d != null) {
                              setSheet(() {
                                start = dayOnly(d);
                                if (end.isBefore(start)) end = start;
                              });
                            }
                          },
                          child: Text("시작 ${start.month}/${start.day}"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: end,
                              firstDate: start,
                              lastDate: DateTime(2035),
                            );
                            if (d != null) setSheet(() => end = dayOnly(d));
                          },
                          child: Text("납기 ${end.month}/${end.day}"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final w in [1, 2, 4, 6, 8, 12])
                        ActionChip(
                          label: Text("$w주"),
                          backgroundColor: tossBg,
                          side: BorderSide.none,
                          onPressed: () => setSheet(
                            () => end = start.add(Duration(days: w * 7 - 1)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...preview.map(
                    (p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 90,
                            child: Text(
                              p['name'].toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: tossText,
                              ),
                            ),
                          ),
                          Text(
                            "${_md(phaseStart(p)!)} ~ ${_md(phaseEnd(p)!)}",
                            style: const TextStyle(color: tossSubText),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setPhases(log, preview);
                        Navigator.pop(ctx);
                        _changed();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tossBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "이대로 만들기",
                        style: TextStyle(
                          color: pureWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
