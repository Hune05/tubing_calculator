import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);
const Color slate300 = Color(0xFFCBD5E1);

class MobileInventoryLogsPage extends StatelessWidget {
  const MobileInventoryLogsPage({super.key});

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "시간 정보 없음";
    DateTime dt = timestamp.toDate();
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slate100,
      appBar: AppBar(
        backgroundColor: makitaTeal, // X-RAY 끄고 원래 예쁜 색으로 복구
        elevation: 0,
        iconTheme: const IconThemeData(color: pureWhite),
        title: const Text(
          "자재 입출고 로그 기록",
          style: TextStyle(fontWeight: FontWeight.bold, color: pureWhite),
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
              child: CircularProgressIndicator(color: makitaTeal),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "로그 기록이 없습니다.",
                style: TextStyle(color: slate600, fontSize: 16),
              ),
            );
          }

          final logs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final data = logs[index].data() as Map<String, dynamic>;

              // 🚀 [완벽 해결] 태블릿이 쓰는 material_name, worker_name, type을 먼저 찾습니다!
              String itemName =
                  data['material_name'] ??
                  data['itemName'] ??
                  data['name'] ??
                  "이름 없음";
              String workerName =
                  data['worker_name'] ?? data['workerName'] ?? "작업자 미상";
              String reason = data['project_name'] ?? data['reason'] ?? "";

              // IN/OUT 이면 한글로 변환, 아니면 기존 action 사용
              String action = "";
              if (data['type'] == 'OUT')
                action = "출고 (불출)";
              else if (data['type'] == 'IN')
                action = "입고 (반납)";
              else
                action = data['action'] ?? "작업";

              int qty = data['qty'] ?? 0;
              String unit = data['unit'] ?? "EA";

              Color actionColor;
              IconData actionIcon;

              if (action.contains('출고') || action.contains('불출')) {
                actionColor = Colors.orange.shade700;
                actionIcon = LucideIcons.arrowUpRight;
              } else if (action.contains('입고') || action.contains('반납')) {
                actionColor = makitaTeal;
                actionIcon = LucideIcons.arrowDownLeft;
              } else {
                actionColor = Colors.blue.shade600;
                actionIcon = LucideIcons.plusCircle;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: pureWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: actionColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(actionIcon, color: actionColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            itemName,
                            style: const TextStyle(
                              color: slate900,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                action,
                                style: TextStyle(
                                  color: actionColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const Text(
                                " • ",
                                style: TextStyle(color: slate300),
                              ),
                              Text(
                                workerName,
                                style: const TextStyle(
                                  color: slate600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (reason.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              "프로젝트/사유: $reason",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            _formatDate(data['timestamp'] as Timestamp?),
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          action.contains('출고') ? "-$qty" : "+$qty",
                          style: TextStyle(
                            color: actionColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          unit,
                          style: const TextStyle(
                            color: slate600,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
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
