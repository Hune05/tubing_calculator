import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'app_colors.dart';

class ProjectListItem extends StatelessWidget {
  final Map<String, dynamic> project;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onUpdateRevision;
  final VoidCallback onDeleteProject;
  final VoidCallback onUpdateProgress;
  final VoidCallback onAddDailyReport;
  final Function(int) onEditDailyReport;
  final Function(int) onDeleteDailyReport;
  final VoidCallback onAddPunch;
  final VoidCallback onDeductInventory;
  final VoidCallback onStateUpdate;
  final Function(int) onViewDailyReportDetail;
  final Function(int) onViewPunchDetail;
  final VoidCallback onOpenCutting;

  const ProjectListItem({
    super.key,
    required this.project,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onUpdateRevision,
    required this.onDeleteProject,
    required this.onUpdateProgress,
    required this.onAddDailyReport,
    required this.onEditDailyReport,
    required this.onDeleteDailyReport,
    required this.onAddPunch,
    required this.onDeductInventory,
    required this.onStateUpdate,
    required this.onViewDailyReportDetail,
    required this.onViewPunchDetail,
    required this.onOpenCutting,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDeducted = project['isDeducted'] ?? false;
    final double progress = project['progress'] ?? 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded ? makitaTeal : Colors.grey.shade300,
          width: isExpanded ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // 🔹 프로젝트 헤더
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isExpanded
                              ? makitaTeal.withValues(alpha: 0.1)
                              : slate50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          LucideIcons.folderKanban,
                          color: isExpanded ? makitaTeal : slate600,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project['name'] ?? '이름 없음',
                              style: const TextStyle(
                                color: slate900,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              project['date'] ?? '',
                              style: const TextStyle(
                                color: slate600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: onUpdateRevision,
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: slate100,
                                  border: Border.all(color: slate200),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.menu_book,
                                      size: 12,
                                      color: makitaTeal,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "기준: ${project['revision'] ?? ''}",
                                      style: const TextStyle(
                                        color: slate600,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: project['status'] == 'ONGOING'
                                      ? makitaTeal.withValues(alpha: 0.1)
                                      : slate100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  project['status'] ?? '',
                                  style: TextStyle(
                                    color: project['status'] == 'ONGOING'
                                        ? makitaTeal
                                        : slate600,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.more_horiz,
                                  color: slate600,
                                ),
                                onSelected: (value) {
                                  if (value == 'delete') onDeleteProject();
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "프로젝트 삭제",
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: slate600,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: onUpdateProgress,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: slate100,
                              color: progress == 1.0
                                  ? Colors.green.shade500
                                  : makitaTeal,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "${(progress * 100).toInt()}%",
                            style: TextStyle(
                              color: progress == 1.0
                                  ? Colors.green.shade700
                                  : slate900,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🔹 확장 영역
          if (isExpanded) ...[
            const Divider(height: 1),
            Container(
              decoration: const BoxDecoration(
                color: slate50,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 소모 자재 (BOM)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "📦 소모 자재 집계 (BOM)",
                              style: TextStyle(
                                color: slate900,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: onOpenCutting,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(
                                  0xFF004D54,
                                ), // 안전하게 색상 코드 하드코딩
                                foregroundColor: pureWhite,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              icon: const Icon(Icons.straighten, size: 14),
                              label: const Text(
                                "컷팅 작업하기",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (project['materials'] == null ||
                            project['materials'].isEmpty)
                          const Text(
                            "자재 내역이 없습니다.\n'컷팅 작업하기' 버튼을 눌러 작업을 시작하세요.",
                            style: TextStyle(
                              color: slate600,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        if (project['materials'] != null)
                          ...project['materials']
                              .map<Widget>((mat) => _buildMaterialRow(mat))
                              .toList(),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // 2. 작업 일보
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "📝 작업 일보 (터치하여 상세/사진)",
                              style: TextStyle(
                                color: slate900,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            InkWell(
                              onTap: onAddDailyReport,
                              child: const Icon(
                                Icons.add_circle,
                                color: makitaTeal,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (project['daily_reports'] == null ||
                            project['daily_reports'].isEmpty)
                          const Text(
                            "등록된 작업 일보가 없습니다.",
                            style: TextStyle(color: slate600, fontSize: 13),
                          ),
                        if (project['daily_reports'] != null)
                          ...project['daily_reports'].asMap().entries.map<
                            Widget
                          >((entry) {
                            final int reportIdx = entry.key;
                            final report = entry.value;
                            final bool isAsBuilt =
                                report['is_as_built'] ?? false;

                            List<dynamic> imagePaths =
                                report['image_paths'] ??
                                (report['image_path'] != null
                                    ? [report['image_path']]
                                    : []);
                            final bool hasImage =
                                (report['has_image'] == true) ||
                                imagePaths.isNotEmpty;

                            return InkWell(
                              onTap: () => onViewDailyReportDetail(reportIdx),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8.0),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isAsBuilt
                                      ? Colors.orange.shade50
                                      : pureWhite,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isAsBuilt
                                        ? Colors.orange.shade300
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: slate200,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            report['date'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: slate900,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "${report['points'] ?? 0} Pts",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: makitaTeal,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                report['note'] ?? '',
                                                style: const TextStyle(
                                                  color: slate600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              if (hasImage &&
                                                  imagePaths.isNotEmpty)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                    top: 4,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: slate100,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    border: Border.all(
                                                      color: slate200,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.image,
                                                        size: 10,
                                                        color: slate600,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        "사진 ${imagePaths.length}장",
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          color: slate600,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          width: 30,
                                          height: 24,
                                          child: PopupMenuButton<String>(
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(
                                              Icons.more_vert,
                                              color: slate600,
                                              size: 18,
                                            ),
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                onEditDailyReport(reportIdx);
                                              } else if (value == 'delete') {
                                                onDeleteDailyReport(reportIdx);
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Text(
                                                  "수정하기",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Text(
                                                  "삭제하기",
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (isAsBuilt) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.warning_rounded,
                                            color: Colors.orange.shade700,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              "As-Built 반영 필요: ${report['as_built_reason'] ?? ''}",
                                              style: TextStyle(
                                                color: Colors.orange.shade800,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // 3. 펀치 리스트
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "🔴 펀치 리스트 (터치하여 상세/사진)",
                              style: TextStyle(
                                color: slate900,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            InkWell(
                              onTap: onAddPunch,
                              child: Icon(
                                Icons.add_circle,
                                color: Colors.red.shade400,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (project['punch_lists'] == null ||
                            project['punch_lists'].isEmpty)
                          const Text(
                            "남은 결함이나 잔여 작업이 없습니다.",
                            style: TextStyle(color: slate600, fontSize: 13),
                          ),
                        if (project['punch_lists'] != null)
                          ...project['punch_lists'].asMap().entries.map<
                            Widget
                          >((entry) {
                            final int punchIdx = entry.key;
                            final punch = entry.value;

                            List<dynamic> imagePaths =
                                punch['image_paths'] ??
                                (punch['image_path'] != null
                                    ? [punch['image_path']]
                                    : []);
                            final bool hasImage =
                                (punch['has_image'] == true) ||
                                imagePaths.isNotEmpty;

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2.0,
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: punch['is_completed'] ?? false,
                                    activeColor: makitaTeal,
                                    onChanged: (val) {
                                      punch['is_completed'] = val;
                                      onStateUpdate();
                                    },
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => onViewPunchDetail(punchIdx),
                                      borderRadius: BorderRadius.circular(4),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8.0,
                                          horizontal: 4.0,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                punch['content'] ?? '',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      (punch['is_completed'] ==
                                                          true)
                                                      ? FontWeight.normal
                                                      : FontWeight.bold,
                                                  color:
                                                      (punch['is_completed'] ==
                                                          true)
                                                      ? Colors.grey
                                                      : slate900,
                                                  decoration:
                                                      (punch['is_completed'] ==
                                                          true)
                                                      ? TextDecoration
                                                            .lineThrough
                                                      : null,
                                                ),
                                              ),
                                            ),
                                            if (hasImage &&
                                                imagePaths.isNotEmpty)
                                              Row(
                                                children: [
                                                  Text(
                                                    "${imagePaths.length}장 ",
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color:
                                                          (punch['is_completed'] ==
                                                              true)
                                                          ? Colors.grey
                                                          : slate600,
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons.photo_camera,
                                                    size: 16,
                                                    color:
                                                        (punch['is_completed'] ==
                                                            true)
                                                        ? Colors.grey
                                                        : slate600,
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                      ],
                    ),
                  ),

                  // 하단 재고 차감 버튼
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDeducted ? slate200 : makitaTeal,
                          foregroundColor: isDeducted ? slate600 : pureWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(
                          isDeducted
                              ? Icons.check_circle
                              : LucideIcons.packageMinus,
                          size: 18,
                        ),
                        label: Text(
                          isDeducted ? "재고 차감 완료됨" : "창고 재고에서 일괄 차감",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: isDeducted ? null : onDeductInventory,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMaterialRow(Map<String, dynamic> mat) {
    bool isTube = mat['type'] == 'TUBE';
    // 🚨 [핵심 해결] as int 때문에 발생하던 타입 에러를 as num으로 변경해 완벽 해결!
    int tubeSticks = isTube ? ((mat['qty_mm'] as num) / 6000).ceil() : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(
            isTube ? Icons.line_weight : LucideIcons.gitMerge,
            size: 18,
            color: slate600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mat['db_name'] ?? mat['name'] ?? '알 수 없는 자재',
                  style: const TextStyle(
                    color: slate900,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (isTube && mat['qty_mm'] != null)
                  Text(
                    "총 ${((mat['qty_mm'] as num) / 1000).toStringAsFixed(1)}m",
                    style: const TextStyle(color: slate600, fontSize: 11),
                  ),
              ],
            ),
          ),
          Text(
            isTube ? "$tubeSticks 본" : "${mat['qty_ea'] ?? 0} EA",
            style: const TextStyle(
              color: makitaTeal,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
