import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'korean_text.dart';

import 'photo_detail_modal.dart';
import '../models/project_merge.dart' show currentWorkerName;
import '../models/project_phase.dart'
    show issueOverdueDays, issueWeeklyExcluded, setIssueWeeklyExcluded;

const Color tossBlue = AppColors.brand; // 🚀 마키타 틸로 통일
const Color tossText = AppColors.text;
const Color tossSubText = AppColors.textSub;
const Color tossBg = AppColors.background;
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = AppColors.danger;

// 리스트 아이템 (WorkLogCard와 아래 DailyReportPager가 함께 쓰므로
// 최상위 함수로 뺐다)
Widget _buildUnifiedRecordItem({
  required BuildContext context,
  required String title,
  required String content,
  required Map<String, dynamic> itemData,
  required IconData icon,
  required bool isWarning,
  bool isCompleted = false,
  VoidCallback? onTap,
}) {
  bool hasImg = itemData['has_image'] == true;

  return InkWell(
    onTap:
        onTap ??
        () {
          PhotoDetailModal.show(
            context: context,
            title: title,
            content: content,
            imagePaths:
                itemData['image_paths'] ??
                (itemData['image_path'] != null
                    ? [itemData['image_path']]
                    : []),
            isAsBuilt: itemData['is_as_built'] ?? false,
            asBuiltReason: itemData['as_built_reason'],
          );
        },
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.withValues(alpha: 0.12)
                  : tossBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check_rounded : icon,
              color: isCompleted ? Colors.green : tossText,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isCompleted
                        ? tossSubText
                        : (isWarning ? warningRed : tossText),
                    fontSize: 15,
                    letterSpacing: -0.3,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: tossSubText, fontSize: 13),
                ),
              ],
            ),
          ),
          if (hasImg)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: tossBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.image_rounded,
                size: 16,
                color: tossSubText,
              ),
            ),
        ],
      ),
    ),
  );
}

// 🚀 [신규] 이슈 목록도 시간이 지나면 계속 쌓이므로, 일정 관리와
// 동일하게 "완료 숨김"(기본 켜짐) 필터와 5개씩 페이지네이션을 둔다.
class PunchListSection extends StatefulWidget {
  final List<dynamic> punchLists;
  final void Function(Map<String, dynamic> punch) onOpenPunchDetail;
  // 주간 보고 포함 여부를 일괄로 바꾼 뒤 저장/새로고침하라고 알리는 콜백.
  final VoidCallback? onBulkChanged;

  const PunchListSection({
    super.key,
    required this.punchLists,
    required this.onOpenPunchDetail,
    this.onBulkChanged,
  });

  @override
  State<PunchListSection> createState() => PunchListSectionState();
}

class PunchListSectionState extends State<PunchListSection> {
  static const int _pageSize = 5;
  // 0=미해결 1=전체(미해결 먼저) 2=완료만
  int _mode = 0;
  int _page = 0;
  // 내가 담당자인 이슈만.
  bool _onlyMine = false;

  @override
  Widget build(BuildContext context) {
    final String me = currentWorkerName.value;
    final List<dynamic> source = _onlyMine && me.isNotEmpty
        ? widget.punchLists
              .where((p) => p is Map && p['assignee']?.toString() == me)
              .toList()
        : widget.punchLists;
    final openList = source.where((p) => p['is_completed'] != true).toList();
    final doneList = source.where((p) => p['is_completed'] == true).toList();
    // 주간 보고에서 뺀 미해결 이슈만 모아 보기(3). 없어지면 미해결(0)로 돌아간다.
    final excludedList = openList
        .where((p) => p is Map && issueWeeklyExcluded(p))
        .toList();
    if (_mode == 3 && excludedList.isEmpty) _mode = 0;
    final List<dynamic> visible = _mode == 0
        ? openList
        : (_mode == 2
              ? doneList
              : (_mode == 3 ? excludedList : [...openList, ...doneList]));

    final int totalPages = (visible.length / _pageSize).ceil().clamp(
      1,
      1 << 30,
    );
    final int page = _page.clamp(0, totalPages - 1);
    final int start = page * _pageSize;
    final int end = (start + _pageSize).clamp(0, visible.length);
    final List<dynamic> pageItems = visible.sublist(
      start.clamp(0, visible.length),
      end,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "이슈 목록",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tossSubText,
                    fontSize: 14,
                  ),
                ),
                if (widget.onBulkChanged != null && openList.isNotEmpty)
                  PopupMenuButton<bool>(
                    tooltip: "주간 보고 설정",
                    icon: const Icon(
                      Icons.summarize_outlined,
                      size: 18,
                      color: tossSubText,
                    ),
                    padding: EdgeInsets.zero,
                    onSelected: (exclude) {
                      // 미해결 이슈 전체를 주간 보고에서 빼거나 다시 넣는다.
                      for (final p in openList) {
                        if (p is! Map) continue;
                        setIssueWeeklyExcluded(p, exclude);
                      }
                      setState(() {});
                      widget.onBulkChanged!();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: true,
                        child: Text(keepWords("미해결 이슈 모두 주간 보고에서 제외")),
                      ),
                      PopupMenuItem(
                        value: false,
                        child: Text("미해결 이슈 모두 주간 보고에 포함"),
                      ),
                    ],
                  ),
              ],
            ),
            // 칩이 많아지면(주간 제외 칩 포함) 다음 줄로 넘어가도록 Wrap을 쓴다.
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.end,
                runSpacing: 6,
                children: [
                  if (me.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: GestureDetector(
                        key: const Key('punch_only_mine'),
                        onTap: () => setState(() {
                          _onlyMine = !_onlyMine;
                          _page = 0;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _onlyMine
                                ? warningRed.withValues(alpha: 0.12)
                                : pureWhite,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _onlyMine
                                  ? warningRed.withValues(alpha: 0.5)
                                  : AppColors.line,
                            ),
                          ),
                          child: Text(
                            "내 이슈",
                            style: TextStyle(
                              color: _onlyMine ? warningRed : tossSubText,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  for (final e in [
                    (0, "미해결 ${openList.length}"),
                    (1, "전체"),
                    (2, "완료 ${doneList.length}"),
                    if (excludedList.isNotEmpty)
                      (3, "주간 제외 ${excludedList.length}"),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _mode = e.$1;
                          _page = 0;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _mode == e.$1
                                ? tossBlue.withValues(alpha: 0.15)
                                : pureWhite,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            e.$2,
                            style: TextStyle(
                              color: _mode == e.$1 ? tossBlue : tossSubText,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Text(
            _mode == 3
                ? "주간 보고에서 제외한 미해결 이슈가 없습니다."
                : _mode == 2
                ? "처리 완료한 이슈가 없습니다."
                : (_mode == 0 && doneList.isNotEmpty
                      ? "미해결 이슈가 없습니다. 처리 완료한 ${doneList.length}건은 '완료' 또는 '전체'에서 확인하십시오."
                      : "미해결 이슈가 없습니다."),
            style: const TextStyle(
              color: tossSubText,
              fontSize: 13,
              height: 1.4,
            ),
          )
        else ...[
          ...pageItems.map((punch) {
            final bool isPunchDone = punch['is_completed'] == true;
            return _buildUnifiedRecordItem(
              context: context,
              // 위치를 제목에 보여줘서 어느 곳 이슈인지 목록에서 바로 알 수 있게 한다.
              title:
                  "${(punch['assignee']?.toString() ?? '').isEmpty ? '' : '${punch['assignee']} 담당 · '}${(punch['location']?.toString() ?? '').isEmpty || punch['location'] == '위치 모름' ? '' : '${punch['location']} · '}${isPunchDone ? '처리 완료' : (issueOverdueDays(punch) > 0 ? '기한 초과 ${issueOverdueDays(punch)}일' : '확인 필요')}${issueWeeklyExcluded(punch) ? ' · 주간 제외' : ''}",
              content: punch['priority'] == '긴급'
                  ? "[긴급] ${punch['content'] ?? ''}"
                  : (punch['content'] ?? '').toString(),
              itemData: punch,
              icon: Icons.priority_high_rounded,
              isWarning: true,
              isCompleted: isPunchDone,
              // 🚀 탭하면 언제 발생했고 어떻게 처리했는지 정리할 수 있는
              // 이슈 상세 화면으로 들어간다.
              onTap: () => widget.onOpenPunchDetail(punch),
            );
          }),
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: page > 0
                        ? () => setState(() => _page = page - 1)
                        : null,
                    icon: const Icon(AppIcons.back),
                    color: page > 0
                        ? tossText
                        : tossSubText.withValues(alpha: 0.4),
                    splashRadius: 20,
                  ),
                  Text(
                    "${page + 1} / $totalPages",
                    style: const TextStyle(
                      color: tossSubText,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  IconButton(
                    onPressed: page < totalPages - 1
                        ? () => setState(() => _page = page + 1)
                        : null,
                    icon: const Icon(AppIcons.forward),
                    color: page < totalPages - 1
                        ? tossText
                        : tossSubText.withValues(alpha: 0.4),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
