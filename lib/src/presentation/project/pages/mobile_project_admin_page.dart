import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔥 파이어베이스 연동

import 'package:tubing_calculator/src/presentation/project/pages/mobile_project_create_page.dart';
import 'package:tubing_calculator/src/presentation/project/pages/mobile_project_admin_detail_page.dart';

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);

class MobileProjectAdminPage extends StatefulWidget {
  const MobileProjectAdminPage({super.key});

  @override
  State<MobileProjectAdminPage> createState() => _MobileProjectAdminPageState();
}

class _MobileProjectAdminPageState extends State<MobileProjectAdminPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tossGrey,
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slate900),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "프로젝트 통합 세팅",
              style: TextStyle(
                color: slate900,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              "관리자 전용 (마스터 권한)",
              style: TextStyle(
                color: warningRed,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      // 🔥 StreamBuilder로 파이어베이스 실시간 연동
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: tossBlue),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("등록된 프로젝트가 없습니다.", style: TextStyle(color: slate600)),
            );
          }

          final adminProjects = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: adminProjects.length,
            itemBuilder: (context, index) {
              final doc = adminProjects[index];
              final p = doc.data() as Map<String, dynamic>;
              p['id'] = doc.id; // 🔥 수정 페이지로 넘길 때 문서 ID 포함

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: pureWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          p['code'] ?? '-',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: tossBlue,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: slate100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "단계: ${p['stage'] ?? '대기'}",
                            style: const TextStyle(
                              color: slate900,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p['name'] ?? '이름 없음',
                      style: const TextStyle(
                        fontSize: 18,
                        color: slate900,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tossGrey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "설계: ${p['designer'] ?? '-'}",
                            style: const TextStyle(
                              fontSize: 13,
                              color: slate600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "QC: ${p['qc'] ?? '-'}",
                            style: const TextStyle(
                              fontSize: 13,
                              color: slate600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  MobileProjectAdminDetailPage(project: p),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tossBlue,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "일정 관리 및 상세 설정",
                          style: TextStyle(
                            color: pureWhite,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MobileProjectCreatePage(),
            ),
          );
        },
        backgroundColor: slate900,
        icon: const Icon(Icons.add, color: pureWhite),
        label: const Text(
          "새 프로젝트 개설",
          style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
