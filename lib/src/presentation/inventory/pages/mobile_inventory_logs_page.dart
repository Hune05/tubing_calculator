import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);
const Color slate300 = Color(0xFFCBD5E1); // 🚀 이거 한 줄만 추가해 주세요!

class MobileInventoryLogsPage extends StatelessWidget {
  const MobileInventoryLogsPage({super.key});

  // 🕒 날짜 포맷 변환 도우미 함수
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
        backgroundColor: makitaTeal,
        elevation: 0,
        iconTheme: const IconThemeData(color: pureWhite),
        title: const Text(
          "자재 입출고 로그 기록",
          style: TextStyle(fontWeight: FontWeight.bold, color: pureWhite),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🚀 inventory_logs 컬렉션에서 최근 100개만 시간 역순으로 불러옵니다.
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

              // 🚀 데이터 파싱 (여기서 모바일이 던진 이름을 확인할 수 있습니다)
              String itemName = data['itemName'] ?? "이름 없음 (데이터 누락)";
              String action = data['action'] ?? "알 수 없는 작업";
              int qty = data['qty'] ?? 0;
              String workerName = data['workerName'] ?? "작업자 미상";
              String device = data['device'] ?? "Unknown";
              String reason = data['reason'] ?? "";

              // 작업 종류에 따른 색상 및 아이콘 설정
              Color actionColor;
              IconData actionIcon;

              if (action.contains('불출')) {
                actionColor = Colors.orange.shade700;
                actionIcon = LucideIcons.arrowUpRight;
              } else if (action.contains('반납') || action.contains('입고')) {
                actionColor = makitaTeal;
                actionIcon = LucideIcons.arrowDownLeft;
              } else if (action.contains('신규')) {
                actionColor = Colors.blue.shade600;
                actionIcon = LucideIcons.plusCircle;
              } else {
                actionColor = slate600;
                actionIcon = LucideIcons.activity;
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
                    // 좌측 아이콘
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: actionColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(actionIcon, color: actionColor, size: 20),
                    ),
                    const SizedBox(width: 12),

                    // 중앙 내용
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
                              const Text(
                                " • ",
                                style: TextStyle(color: slate300),
                              ),
                              Text(
                                device,
                                style: const TextStyle(
                                  color: slate600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          if (reason.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              "사유: $reason",
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

                    // 우측 수량
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          qty > 0 ? "+$qty" : "$qty",
                          style: TextStyle(
                            color: actionColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
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
