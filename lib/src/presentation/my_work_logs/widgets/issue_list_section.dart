// 프로젝트 이슈 탭의 목록(10-14 개편). 예전에는 빨간 글 한 줄에 담당·위치·상태를 이어 붙이고 5개씩
// 넘겨 봐서, 무엇이 급한지·어디 것인지 한눈에 안 보였다.
// - 위: 미해결·긴급·기한 초과 수(누르면 그것만 보기), 아래 칩: 내 이슈·처리 완료·전체·주간 제외.
// - 이슈가 6개 넘으면 찾기 칸.
// - 줄: 왼쪽 색 띠(기한 초과·긴급=빨강, 임박=주황, 완료=초록), 유형·기한 표시, 내용 두 줄,
//   위치·담당·사진 수, 오른쪽에 첫 사진. 밀면 지우기(되돌리기는 화면 쪽에서).
// - 순서는 issue_view.dart의 sortIssues(기한 초과 → 긴급 → 기한 빠른 것).
import 'package:flutter/material.dart';

import '../../../core/common_widgets/swipe_to_delete.dart';
import '../../../core/theme/app_tokens.dart';
import '../models/issue_view.dart';
import '../models/photo_store.dart' show PhotoImage;
import '../models/project_merge.dart' show currentWorkerName;
import '../models/project_phase.dart'
    show issueWeeklyExcluded, setIssueWeeklyExcluded;

enum IssueFilter { open, urgent, overdue, mine, done, all, weeklyExcluded }

class IssueListSection extends StatefulWidget {
  final List punches;
  final List schedules;
  final void Function(Map<String, dynamic> punch) onOpen;

  /// 밀어서 지울 때. 목록에서 빼고 저장·되돌리기는 부르는 쪽이 한다.
  final void Function(Map<String, dynamic> punch)? onDelete;

  /// 주간 보고 포함을 한꺼번에 바꾼 뒤(저장하라고 알림).
  final VoidCallback? onBulkChanged;
  final VoidCallback? onExport;
  final VoidCallback? onOpenPlan;
  final DateTime Function()? now;

  const IssueListSection({
    super.key,
    required this.punches,
    this.schedules = const [],
    required this.onOpen,
    this.onDelete,
    this.onBulkChanged,
    this.onExport,
    this.onOpenPlan,
    this.now,
  });

  @override
  State<IssueListSection> createState() => _IssueListSectionState();
}

class _IssueListSectionState extends State<IssueListSection> {
  IssueFilter _filter = IssueFilter.open;
  final _search = TextEditingController();
  int _shown = 30;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _pick(IssueFilter f) => setState(() {
    _filter = _filter == f && f != IssueFilter.open ? IssueFilter.open : f;
    _shown = 30;
  });

  @override
  Widget build(BuildContext context) {
    final now = (widget.now ?? DateTime.now)();
    final me = currentWorkerName.value.trim();
    final all = [
      for (final p in widget.punches)
        if (p is Map<String, dynamic>) p,
    ];
    final open = all.where((p) => p['is_completed'] != true).toList();
    IssueState st(Map p) =>
        issueStateOf(p, schedules: widget.schedules, now: now);
    final urgent = open.where((p) => p['priority'] == '긴급').toList();
    final overdue = open.where((p) => st(p) == IssueState.overdue).toList();
    final mine = me.isEmpty
        ? const <Map<String, dynamic>>[]
        : open.where((p) => p['assignee']?.toString() == me).toList();
    final done = all.where((p) => p['is_completed'] == true).toList();
    final excluded = open.where(issueWeeklyExcluded).toList();
    if (_filter == IssueFilter.weeklyExcluded && excluded.isEmpty) {
      _filter = IssueFilter.open;
    }
    final base = switch (_filter) {
      IssueFilter.open => open,
      IssueFilter.urgent => urgent,
      IssueFilter.overdue => overdue,
      IssueFilter.mine => mine,
      IssueFilter.done => done,
      IssueFilter.all => all,
      IssueFilter.weeklyExcluded => excluded,
    };
    final q = _search.text;
    final visible = sortIssues(
      base.where((p) => issueMatches(p, q)),
      schedules: widget.schedules,
      now: now,
    );
    final page = visible.take(_shown).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(open),
        const SizedBox(height: 10),
        Row(
          children: [
            _stat(
              'issue_stat_open',
              '미해결',
              open.length,
              IssueFilter.open,
              AppColors.text,
            ),
            const SizedBox(width: 8),
            _stat(
              'issue_stat_urgent',
              '긴급',
              urgent.length,
              IssueFilter.urgent,
              AppColors.danger,
            ),
            const SizedBox(width: 8),
            _stat(
              'issue_stat_overdue',
              '기한 초과',
              overdue.length,
              IssueFilter.overdue,
              AppColors.danger,
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (me.isNotEmpty)
                _chip(
                  'issue_filter_mine',
                  '내 이슈 ${mine.length}',
                  IssueFilter.mine,
                ),
              _chip(
                'issue_filter_done',
                '처리 완료 ${done.length}',
                IssueFilter.done,
              ),
              _chip('issue_filter_all', '전체 ${all.length}', IssueFilter.all),
              if (excluded.isNotEmpty)
                _chip(
                  'issue_filter_weekly',
                  '주간 제외 ${excluded.length}',
                  IssueFilter.weeklyExcluded,
                ),
            ],
          ),
        ),
        if (all.length >= 6) ...[
          const SizedBox(height: 10),
          TextField(
            key: const Key('issue_search'),
            controller: _search,
            onChanged: (_) => setState(() => _shown = 30),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '내용·위치·담당자로 찾기',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '지우기',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(_search.clear),
                    ),
              isDense: true,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              _emptyText(all.isEmpty, done.length),
              key: const Key('issue_empty'),
              textAlign: TextAlign.center,
              style: AppText.sub,
            ),
          )
        else ...[
          for (final p in page) _row(p, now),
          if (visible.length > page.length)
            TextButton(
              key: const Key('issue_more'),
              onPressed: () => setState(() => _shown += 30),
              child: Text('${visible.length - page.length}건 더 보기'),
            ),
        ],
      ],
    );
  }

  String _emptyText(bool none, int doneCount) {
    if (none) return '등록된 이슈가 없습니다.\n아래 "이슈 등록"으로 넣습니다.';
    if (_search.text.trim().isNotEmpty) return '찾는 이슈가 없습니다.';
    return switch (_filter) {
      IssueFilter.open =>
        doneCount > 0
            ? '미해결 이슈가 없습니다. 처리 완료 $doneCount건은 "처리 완료"에서 봅니다.'
            : '미해결 이슈가 없습니다.',
      IssueFilter.urgent => '긴급 이슈가 없습니다.',
      IssueFilter.overdue => '기한을 넘긴 이슈가 없습니다.',
      IssueFilter.mine => '내가 담당인 미해결 이슈가 없습니다.',
      IssueFilter.done => '처리 완료한 이슈가 없습니다.',
      IssueFilter.all => '이슈가 없습니다.',
      IssueFilter.weeklyExcluded => '주간 보고에서 뺀 미해결 이슈가 없습니다.',
    };
  }

  Widget _header(List<Map<String, dynamic>> open) => Row(
    children: [
      const Expanded(child: Text('이슈', style: AppText.title)),
      if (widget.onOpenPlan != null)
        IconButton(
          key: const Key('issue_plan_open_button'),
          tooltip: '도면에서 보기',
          icon: const Icon(Icons.map_outlined),
          onPressed: widget.onOpenPlan,
        ),
      if (widget.onExport != null && widget.punches.isNotEmpty)
        IconButton(
          key: const Key('issue_export_button'),
          tooltip: '이슈 보고서 내보내기',
          icon: const Icon(Icons.ios_share_rounded),
          onPressed: widget.onExport,
        ),
      if (widget.onBulkChanged != null && open.isNotEmpty)
        PopupMenuButton<bool>(
          key: const Key('issue_more_menu'),
          tooltip: '주간 보고 설정',
          onSelected: (exclude) {
            for (final p in open) {
              setIssueWeeklyExcluded(p, exclude);
            }
            setState(() {});
            widget.onBulkChanged!();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: true, child: Text('미해결 이슈 모두 주간 보고에서 빼기')),
            PopupMenuItem(value: false, child: Text('미해결 이슈 모두 주간 보고에 넣기')),
          ],
        ),
    ],
  );

  Widget _stat(String key, String label, int n, IssueFilter f, Color color) {
    final on = _filter == f;
    return Expanded(
      child: Material(
        color: on ? AppColors.brandSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: InkWell(
          key: Key(key),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          onTap: () => _pick(f),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(
                color: on ? AppColors.brand : AppColors.line,
                width: on ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  '$n',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: AppText.bold,
                    color: n == 0 ? AppColors.textFaint : color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String key, String label, IssueFilter f) {
    final on = _filter == f;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        key: Key(key),
        label: Text(label),
        selected: on,
        showCheckmark: false,
        selectedColor: AppColors.brandSoft,
        backgroundColor: AppColors.surface,
        side: BorderSide(color: on ? AppColors.brand : AppColors.line),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: on ? AppColors.brand : AppColors.textSub,
        ),
        onSelected: (_) => _pick(f),
      ),
    );
  }

  Widget _row(Map<String, dynamic> p, DateTime now) {
    final id = p['id']?.toString() ?? '${identityHashCode(p)}';
    final card = IssueCard(
      punch: p,
      schedules: widget.schedules,
      now: now,
      onTap: () => widget.onOpen(p),
    );
    if (widget.onDelete == null) {
      return Padding(padding: const EdgeInsets.only(bottom: 8), child: card);
    }
    return SwipeToDelete(
      itemKey: ValueKey('issue_swipe_$id'),
      radius: AppRadius.medium,
      onDelete: () => widget.onDelete!(p),
      child: card,
    );
  }
}

/// 이슈 한 줄(카드). 대시보드 등 다른 목록에서도 쓸 수 있게 따로 둔다.
class IssueCard extends StatelessWidget {
  final Map<String, dynamic> punch;
  final List schedules;
  final DateTime? now;
  final VoidCallback? onTap;

  /// 프로젝트 이름(여러 프로젝트를 한 목록에 보일 때).
  final String? projectName;

  const IssueCard({
    super.key,
    required this.punch,
    this.schedules = const [],
    this.now,
    this.onTap,
    this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    final p = punch;
    final state = issueStateOf(p, schedules: schedules, now: now);
    final done = state == IssueState.done;
    final urgent = p['priority'] == '긴급';
    final barColor = switch (state) {
      IssueState.done => AppColors.ok,
      IssueState.overdue => AppColors.danger,
      IssueState.dueSoon => urgent ? AppColors.danger : AppColors.caution,
      IssueState.open => urgent ? AppColors.danger : AppColors.line,
    };
    final dueText = issueDueLabel(p, schedules: schedules, now: now);
    final type = (p['defect_type'] ?? '').toString().trim();
    final loc = issueLocation(p);
    final who = (p['assignee'] ?? '').toString().trim();
    final before = issueBeforePhotos(p);
    final after = issueAfterPhotos(p);
    final photos = before.length + after.length;
    final thumb = done && after.isNotEmpty
        ? after.first
        : (before.isNotEmpty ? before.first : null);
    final content = (p['content'] ?? '').toString().trim();
    final resolvedAt = issueDate(p['resolved_at']);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('issue_card_${p['id'] ?? content}'),
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: barColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (projectName != null)
                                  _Pill(projectName!, AppColors.brand),
                                if (urgent && !done)
                                  const _Pill('긴급', AppColors.danger),
                                if (done)
                                  _Pill(
                                    resolvedAt == null
                                        ? '처리 완료'
                                        : '처리 완료 ${resolvedAt.month}/${resolvedAt.day}',
                                    AppColors.ok,
                                  )
                                else if (dueText.isNotEmpty)
                                  _Pill(dueText, switch (state) {
                                    IssueState.overdue => AppColors.danger,
                                    IssueState.dueSoon => AppColors.caution,
                                    _ => AppColors.idle,
                                  }),
                                if (type.isNotEmpty)
                                  _Pill(type, AppColors.idle),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              content.isEmpty ? '내용 없음 (사진 참조)' : content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                                color: done
                                    ? AppColors.textSub
                                    : AppColors.text,
                              ),
                            ),
                            if (loc.isNotEmpty ||
                                who.isNotEmpty ||
                                photos > 0) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 10,
                                runSpacing: 2,
                                children: [
                                  if (loc.isNotEmpty)
                                    _Meta(Icons.place_outlined, loc),
                                  if (who.isNotEmpty)
                                    _Meta(Icons.person_outline, who),
                                  if (photos > 0)
                                    _Meta(Icons.photo_outlined, '사진 $photos'),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (thumb != null) ...[
                        const SizedBox(width: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.small),
                          child: Opacity(
                            opacity: done ? 0.7 : 1,
                            child: PhotoImage(thumb, width: 58, height: 58),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppColors.textSub),
      const SizedBox(width: 3),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5, color: AppColors.textSub),
        ),
      ),
    ],
  );
}
