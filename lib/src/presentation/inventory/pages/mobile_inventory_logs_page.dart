import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';

// 🎨 토스 스타일 미니멀 컬러 팔레트
const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate300 = Color(0xFFCBD5E1); // 💡 이 줄이 추가되었습니다!
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);

/// 기록 한 줄이 어느 작업에서 나온 것인지. 작업 것이 아니면 빈 글.
///
/// 🚀 [고침] 예전에는 'project_name' 한 칸을 작업 이름과 "왜 썼는지"에
/// 같이 써서, 칩에 "자재 목록에서 넣음" 같은 것까지 섞여 나왔다.
/// 컷팅·형강에서 뺀 기록만 작업으로 본다(차감할 때 'job_name'을 남긴다.
/// 그 칸이 없는 옛 기록은 무엇을 한 기록인지로 가린다).
String jobNameOfLog(Map<String, dynamic> data) {
  final job = (data['job_name'] ?? '').toString().trim();
  if (job.isNotEmpty) return job;

  final action = (data['action'] ?? '').toString();
  const jobActions = ['컷팅 사용', '형강 재단', '차감 되돌림'];
  if (!jobActions.contains(action)) return '';
  return (data['project_name'] ?? '').toString().trim();
}

/// 자재 기록. 작업별로 걸러 볼 수 있다.
///
/// 🚀 [추가] 예전에는 모든 기록이 한 줄로 쌓여서, "이 작업에 자재가 얼마나
/// 들었나"를 보려면 눈으로 골라야 했다. 작업 이름으로 걸러 본다.
class MobileInventoryLogsPage extends StatefulWidget {
  /// 이 작업 것만 보고 싶을 때 넣는다(비우면 전체).
  final String projectName;

  const MobileInventoryLogsPage({super.key, this.projectName = ''});

  @override
  State<MobileInventoryLogsPage> createState() =>
      _MobileInventoryLogsPageState();
}

class _MobileInventoryLogsPageState extends State<MobileInventoryLogsPage> {
  late String _picked = widget.projectName;

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "시간 정보 없음";
    DateTime dt = timestamp.toDate();
    return "${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pureWhite, // 🌟 전체 배경을 하얗게 변경
      appBar: AppBar(
        backgroundColor: pureWhite,
        scrolledUnderElevation: 0,
        elevation: 0,
        iconTheme: const IconThemeData(color: slate900),
        centerTitle: true,
        title: Text(
          _picked.isEmpty ? "자재 기록" : "자재 기록 · $_picked",
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: slate900,
            fontSize: 18,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('inventory_logs')
            .orderBy('timestamp', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: slate300),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "기록이 없습니다",
                style: TextStyle(
                  color: slate600,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          final all = snapshot.data!.docs;

          // 기록에 적힌 작업 이름을 모은다(최근 것부터, 너무 많으면 자른다).
          final jobs = <String>[];
          for (final d in all) {
            final n = jobNameOfLog(d.data() as Map<String, dynamic>);
            if (n.isEmpty || jobs.contains(n)) continue;
            jobs.add(n);
            if (jobs.length >= 12) break;
          }

          final logs = _picked.isEmpty
              ? all
              : all
                    .where(
                      (d) =>
                          jobNameOfLog(d.data() as Map<String, dynamic>) ==
                          _picked,
                    )
                    .toList();

          return Column(
            children: [
              // 고른 작업이 있으면 칩이 없어도 "전체"로 돌아갈 수 있게 보여 준다.
              if (jobs.isNotEmpty || _picked.isNotEmpty)
                SizedBox(
                  key: const Key('logs_job_filter'),
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _jobChip('전체', _picked.isEmpty, () {
                        setState(() => _picked = '');
                      }),
                      if (_picked.isNotEmpty && !jobs.contains(_picked))
                        _jobChip(_picked, true, () {}),
                      for (final j in jobs)
                        _jobChip(j, _picked == j, () {
                          setState(() => _picked = j);
                        }),
                    ],
                  ),
                ),
              if (logs.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      "이 작업에 쓴 기록이 없습니다",
                      style: TextStyle(
                        color: slate600,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final data = logs[index].data() as Map<String, dynamic>;

                      String itemName =
                          data['material_name'] ??
                          data['itemName'] ??
                          data['name'] ??
                          "이름 없음";
                      String workerName =
                          data['worker_name'] ?? data['workerName'] ?? "작업자 모름";
                      String reason =
                          data['project_name'] ?? data['reason'] ?? "";

                      // 🚀 [버그 해결 핵심] action과 type을 모두 읽어서 정확한 행동을 판별합니다.
                      String rawType = data['type'] ?? "";
                      String rawAction = data['action'] ?? "";
                      // 예전 컷팅 차감 기록은 type·action이 없고 deducted_qty만 있었다.
                      if (rawType.isEmpty &&
                          rawAction.isEmpty &&
                          data['deducted_qty'] != null) {
                        rawType = 'OUT';
                        rawAction = '컷팅 사용';
                      }

                      String displayAction = "작업";
                      Color actionColor = slate600;
                      Object actionIcon = Icons.info_outline;
                      String displayQtyPrefix = "";

                      // 1. 신규 등록 및 실사 조정인지 먼저 확인 (가장 우선순위)
                      if (rawAction.contains('신규') ||
                          rawAction.contains('추가') ||
                          rawAction.contains('등록')) {
                        // 자재 목록에서 넣기만 한 것은 수량이 0이라 "+0"이 어색하다.
                        final justAdded =
                            ((data['qty'] as num?)?.toInt() ?? 0) == 0;
                        displayAction = justAdded ? "자재 등록" : "신규 등록";
                        actionColor = Colors.blue.shade600;
                        actionIcon = AppGlyph.stockNew;
                        displayQtyPrefix = justAdded ? "" : "+";
                      } else if (rawAction.contains('실사') ||
                          rawAction.contains('수정') ||
                          rawAction.contains('조정')) {
                        displayAction = "재고 실사 (수정)";
                        actionColor = slate900;
                        actionIcon = AppGlyph.stockAudit;
                        displayQtyPrefix =
                            "="; // 실사는 증감이 아니라 '해당 수량으로 맞춤'의 의미가 강함
                      } else if (rawAction.contains('삭제')) {
                        displayAction = "목록에서 삭제";
                        actionColor = Colors.red.shade800;
                        actionIcon = LucideIcons.trash2;
                        displayQtyPrefix = "";
                      }
                      // 2. 그 외 일반적인 입고/출고 판별
                      else if (rawType == 'OUT' ||
                          rawAction.contains('출고') ||
                          rawAction.contains('불출')) {
                        displayAction = "불출 (출고)";
                        actionColor = Colors.orange.shade700;
                        actionIcon = AppGlyph.stockOut;
                        displayQtyPrefix = "-";
                      } else if (rawType == 'IN' ||
                          rawAction.contains('입고') ||
                          rawAction.contains('반납')) {
                        displayAction = "반납 (입고)";
                        actionColor = makitaTeal;
                        actionIcon = AppGlyph.stockIn;
                        displayQtyPrefix = "+";
                      }

                      // 예전 컷팅 차감 기록은 수량을 'deducted_qty'에 넣었다. 그대로 두면
                      // 기록 화면에 0으로 보이니 그 칸도 같이 읽는다.
                      int qty =
                          ((data['qty'] ?? data['deducted_qty'] ?? 0) as num)
                              .toInt();
                      String unit = data['unit'] ?? "EA";

                      return Container(
                        margin: const EdgeInsets.only(
                          bottom: 24,
                        ), // 🌟 아이템 간 여백 확대
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 좌측 아이콘 (토스 스타일의 부드러운 원형 배경)
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: actionColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: anyIcon(
                                actionIcon,
                                color: actionColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),

                            // 중앙 텍스트 정보 영역
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayAction,
                                    style: TextStyle(
                                      color: actionColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    itemName,
                                    style: const TextStyle(
                                      color: slate900,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800, // 볼드체 강조
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    workerName +
                                        (reason.isNotEmpty ? " • $reason" : ""),
                                    style: const TextStyle(
                                      color: slate600,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDate(
                                      data['timestamp'] as Timestamp?,
                                    ),
                                    style: TextStyle(
                                      color: slate600.withValues(alpha: 0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 우측 수량 영역
                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const SizedBox(height: 4), // 텍스트 높이 맞춤
                                Text(
                                  "$displayQtyPrefix$qty",
                                  style: TextStyle(
                                    color: actionColor,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                                ),
                                Text(
                                  unit,
                                  style: const TextStyle(
                                    color: slate600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// 작업 고르는 칩 하나.
  Widget _jobChip(String label, bool picked, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 10, bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: picked ? makitaTeal : slate100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: picked ? pureWhite : slate600,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
