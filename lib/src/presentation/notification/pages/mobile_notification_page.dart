import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

// 프로젝트 공통 컬러
const Color tossBlue = Color(0xFF3182F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileNotificationPage extends StatelessWidget {
  const MobileNotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pureWhite,
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: slate900),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "알림 내역",
          style: TextStyle(
            color: slate900,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🔥 활성화된 공지와 최근 20개 내역을 불러옵니다.
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .orderBy('createdAt', descending: true)
            .limit(20)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: tossBlue),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              color: slate100,
              indent: 24,
              endIndent: 24,
            ),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final title = data['title'] ?? '알림';
              final content = data['content'] ?? '';
              final createdAt = data['createdAt'] as Timestamp?;

              // 키워드에 따른 아이콘 자동 매칭
              IconData icon = LucideIcons.bell;
              Color iconColor = slate600;
              Color bgColor = slate100;

              if (title.contains("회의") || title.contains("회식")) {
                icon = LucideIcons.calendarClock;
                iconColor = const Color(0xFF8A2BE2); // Purple
                bgColor = const Color(0xFF8A2BE2).withValues(alpha: 0.1);
              } else if (title.contains("긴급")) {
                icon = LucideIcons.alertTriangle;
                iconColor = const Color(0xFFF04438); // Red
                bgColor = const Color(0xFFF04438).withValues(alpha: 0.1);
              } else {
                icon = LucideIcons.clipboardList;
                iconColor = tossBlue;
                bgColor = tossBlue.withValues(alpha: 0.1);
              }

              String dateText = '';
              if (createdAt != null) {
                dateText = DateFormat(
                  'MM월 dd일 HH:mm',
                ).format(createdAt.toDate());
              }

              return InkWell(
                onTap: () {
                  // TODO: 필요시 상세 페이지로 이동
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: bgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: iconColor, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: slate900,
                              ),
                            ),
                            if (content.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                content,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: slate600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              dateText,
                              style: TextStyle(
                                fontSize: 12,
                                color: slate600.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.bellOff, size: 48, color: slate100),
          const SizedBox(height: 16),
          const Text(
            "새로운 알림이 없습니다.",
            style: TextStyle(
              color: slate600,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
