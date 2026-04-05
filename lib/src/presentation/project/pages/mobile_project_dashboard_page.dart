import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔥 파이어베이스 연동

import 'package:tubing_calculator/src/presentation/project/pages/mobile_punch_action_page.dart';

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFE5E8EB);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);
const Color successGreen = Color(0xFF00C853);

class MobileProjectDashboardPage extends StatefulWidget {
  final String projectName;

  const MobileProjectDashboardPage({super.key, required this.projectName});

  @override
  State<MobileProjectDashboardPage> createState() =>
      _MobileProjectDashboardPageState();
}

class _MobileProjectDashboardPageState
    extends State<MobileProjectDashboardPage> {
  // 공정 단계 텍스트를 인덱스 숫자로 변환하는 도우미 함수
  int _getStageIndex(String? stage) {
    if (stage == null) return 0;
    if (stage.contains("발주")) return 0;
    if (stage.contains("검사") && !stage.contains("펀치")) return 1;
    if (stage.contains("진행") || stage.contains("펀치") || stage.contains("수정"))
      return 2;
    if (stage.contains("완료")) return 3;
    return 0; // 기본값
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tossGrey,
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: slate900,
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.projectName,
          style: const TextStyle(
            color: slate900,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressSection(),
            const SizedBox(height: 12),
            _buildMajorMaterialsSection(),
            const SizedBox(height: 12),
            _buildInspectionAndPunchSection(),
          ],
        ),
      ),
    );
  }

  // 1. 전체 작업 진척도 (projects 컬렉션 감시)
  Widget _buildProgressSection() {
    final stages = ["자재 발주", "자재 검사", "작업 진행", "완료"];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .where('name', isEqualTo: widget.projectName)
          .snapshots(),
      builder: (context, snapshot) {
        String currentStageStr = "자재 발주";

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          currentStageStr = snapshot.data!.docs.first['stage'] ?? "자재 발주";
        }
        int currentStageIndex = _getStageIndex(currentStageStr);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: const BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "현재 공정 단계",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: slate900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "현재 '$currentStageStr' 단계가 진행 중입니다.",
                style: const TextStyle(
                  fontSize: 14,
                  color: slate600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(stages.length, (index) {
                  bool isCompleted = index < currentStageIndex;
                  bool isCurrent = index == currentStageIndex;

                  return Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? tossBlue
                                : (isCurrent ? pureWhite : slate100),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isCurrent
                                  ? tossBlue
                                  : (isCompleted
                                        ? tossBlue
                                        : Colors.transparent),
                              width: isCurrent ? 2.5 : 0,
                            ),
                          ),
                          child: isCompleted
                              ? const Icon(
                                  Icons.check,
                                  color: pureWhite,
                                  size: 16,
                                )
                              : (isCurrent
                                    ? Center(
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            color: tossBlue,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      )
                                    : null),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          stages[index],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isCurrent || isCompleted
                                ? slate900
                                : slate600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  // 2. 주요 사급 자재 현황 (project_materials 컬렉션 감시)
  Widget _buildMajorMaterialsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('project_materials')
          .where('projectName', isEqualTo: widget.projectName)
          .snapshots(),
      builder: (context, snapshot) {
        List<Widget> materialCards = [];

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final mat = doc.data() as Map<String, dynamic>;
            materialCards.add(_buildMaterialCard(mat));
          }
        }

        return Container(
          color: pureWhite,
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "사급 및 대형 자재 일정",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: slate900,
                ),
              ),
              const SizedBox(height: 16),
              if (materialCards.isEmpty)
                const Text("등록된 자재가 없습니다.", style: TextStyle(color: slate600))
              else
                ...materialCards,
            ],
          ),
        );
      },
    );
  }

  Widget _buildMaterialCard(Map<String, dynamic> mat) {
    String status = mat['status'] ?? '대기 중';
    bool isDelayed = status.contains("지연");
    bool isCompleted = status == "입고 완료";

    Color badgeColor = isDelayed
        ? warningRed
        : (isCompleted ? successGreen : slate600);
    Color bgColor = isDelayed ? warningRed.withValues(alpha: 0.05) : pureWhite;
    Color borderColor = isDelayed
        ? warningRed.withValues(alpha: 0.3)
        : slate100;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mat['name'] ?? '-',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: slate900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(LucideIcons.calendar, size: 14, color: slate600),
                    const SizedBox(width: 4),
                    Text(
                      mat['date'] ?? '-',
                      style: const TextStyle(
                        fontSize: 13,
                        color: slate600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: badgeColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. 검사 및 펀치(Punch) 사항 (project_inspections, project_punches 컬렉션 감시)
  Widget _buildInspectionAndPunchSection() {
    return Container(
      color: pureWhite,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "검사 일정 및 펀치 현황",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: slate900,
            ),
          ),
          const SizedBox(height: 16),

          // 💡 검사 일정 Stream
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('project_inspections')
                .where('projectName', isEqualTo: widget.projectName)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text(
                  "등록된 검사 일정이 없습니다.",
                  style: TextStyle(color: slate600),
                );
              }

              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final insp = doc.data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: slate100.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: tossBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            LucideIcons.clipboardCheck,
                            color: tossBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                insp['name'] ?? '-',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: slate900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "예정일: ${insp['date'] ?? '-'}",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: slate600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 12),

          // 💡 펀치 리스트 Stream
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('project_punches')
                .where('projectName', isEqualTo: widget.projectName)
                .snapshots(),
            builder: (context, snapshot) {
              int unresolvedCount = 0;
              List<Widget> punchWidgets = [];

              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final punch = doc.data() as Map<String, dynamic>;
                  if (punch['status'] != '조치 완료') {
                    unresolvedCount++;
                  }
                  punchWidgets.add(
                    _buildPunchItem(punch['code'] ?? '-', punch['desc'] ?? '-'),
                  );
                  punchWidgets.add(const Divider(height: 24, color: tossGrey));
                }
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: slate100),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              LucideIcons.alertTriangle,
                              color: warningRed,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "미해결 펀치",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: slate900,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: unresolvedCount > 0
                                ? warningRed
                                : successGreen,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "${unresolvedCount}건",
                            style: const TextStyle(
                              color: pureWhite,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (punchWidgets.isEmpty)
                      const Text(
                        "등록된 펀치가 없습니다.",
                        style: TextStyle(color: slate600),
                      )
                    else
                      ...punchWidgets,

                    const SizedBox(height: 12),

                    // 조치 보고 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MobilePunchActionPage(
                                projectName: widget.projectName,
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: slate900,
                          side: const BorderSide(color: slate100, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "펀치 상세 내용 및 조치 보고",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPunchItem(String code, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          code,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: warningRed,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            desc,
            style: const TextStyle(
              fontSize: 14,
              color: slate900,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
