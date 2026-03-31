import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';

// 🎨 토스 스타일 미니멀 컬러 팔레트
const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate300 = Color(0xFFCBD5E1); // 💡 이 줄이 추가되었습니다!
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileInventoryLogsPage extends StatelessWidget {
  const MobileInventoryLogsPage({super.key});

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
        title: const Text(
          "자재 기록",
          style: TextStyle(
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
                "기록이 없어요",
                style: TextStyle(
                  color: slate600,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          final logs = snapshot.data!.docs;

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final data = logs[index].data() as Map<String, dynamic>;

              String itemName =
                  data['material_name'] ??
                  data['itemName'] ??
                  data['name'] ??
                  "이름 없음";
              String workerName =
                  data['worker_name'] ?? data['workerName'] ?? "작업자 미상";
              String reason = data['project_name'] ?? data['reason'] ?? "";

              // 🚀 [버그 해결 핵심] action과 type을 모두 읽어서 정확한 행동을 판별합니다.
              String rawType = data['type'] ?? "";
              String rawAction = data['action'] ?? "";

              String displayAction = "작업";
              Color actionColor = slate600;
              IconData actionIcon = Icons.info_outline;
              String displayQtyPrefix = "";

              // 1. 신규 등록 및 실사 조정인지 먼저 확인 (가장 우선순위)
              if (rawAction.contains('신규') || rawAction.contains('추가')) {
                displayAction = "신규 등록";
                actionColor = Colors.blue.shade600;
                actionIcon = LucideIcons.boxSelect;
                displayQtyPrefix = "+";
              } else if (rawAction.contains('실사') ||
                  rawAction.contains('수정') ||
                  rawAction.contains('조정')) {
                displayAction = "재고 실사 (수정)";
                actionColor = slate900;
                actionIcon = LucideIcons.clipboardEdit;
                displayQtyPrefix = "="; // 실사는 증감이 아니라 '해당 수량으로 맞춤'의 의미가 강함
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
                actionIcon = LucideIcons.arrowUpRight;
                displayQtyPrefix = "-";
              } else if (rawType == 'IN' ||
                  rawAction.contains('입고') ||
                  rawAction.contains('반납')) {
                displayAction = "반납 (입고)";
                actionColor = makitaTeal;
                actionIcon = LucideIcons.arrowDownLeft;
                displayQtyPrefix = "+";
              }

              int qty = data['qty'] ?? 0;
              String unit = data['unit'] ?? "EA";

              return Container(
                margin: const EdgeInsets.only(bottom: 24), // 🌟 아이템 간 여백 확대
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
                      child: Icon(actionIcon, color: actionColor, size: 20),
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
                            _formatDate(data['timestamp'] as Timestamp?),
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
          );
        },
      ),
    );
  }
}
