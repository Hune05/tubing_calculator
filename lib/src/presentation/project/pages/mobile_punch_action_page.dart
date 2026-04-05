import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔥 파이어베이스 연동

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);
const Color successGreen = Color(0xFF00C853);

class MobilePunchActionPage extends StatefulWidget {
  final String projectName;

  const MobilePunchActionPage({super.key, required this.projectName});

  @override
  State<MobilePunchActionPage> createState() => _MobilePunchActionPageState();
}

class _MobilePunchActionPageState extends State<MobilePunchActionPage> {
  // 💡 입력된 텍스트들을 관리하기 위한 컨트롤러 맵 (문서 ID를 키로 사용)
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    _controllers.values.forEach((ctrl) => ctrl.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tossGrey,
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slate900),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "펀치 조치 및 보고",
              style: TextStyle(
                color: slate900,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              widget.projectName,
              style: const TextStyle(
                color: slate600,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      // 🔥 StreamBuilder로 특정 프로젝트의 펀치 리스트 실시간 로드
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('project_punches')
            .where('projectName', isEqualTo: widget.projectName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: tossBlue),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "등록된 펀치(지적사항)가 없습니다.",
                style: TextStyle(color: slate600),
              ),
            );
          }

          final punches = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: punches.length,
            itemBuilder: (context, index) {
              final doc = punches[index];
              final punch = doc.data() as Map<String, dynamic>;
              bool isResolved = punch['status'] == "조치 완료";

              // 텍스트 컨트롤러 할당
              if (!_controllers.containsKey(doc.id)) {
                _controllers[doc.id] = TextEditingController(
                  text: punch['actionText'] ?? "",
                );
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: pureWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isResolved
                        ? successGreen.withValues(alpha: 0.3)
                        : warningRed.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          punch['code'] ?? '-',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isResolved ? successGreen : warningRed,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isResolved
                                ? successGreen.withValues(alpha: 0.1)
                                : warningRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            punch['status'] ?? '미해결',
                            style: TextStyle(
                              color: isResolved ? successGreen : warningRed,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      punch['desc'] ?? '-',
                      style: const TextStyle(
                        fontSize: 16,
                        color: slate900,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "지적일: ${punch['date'] ?? '-'}",
                      style: const TextStyle(fontSize: 13, color: slate600),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1, color: tossGrey),
                    ),

                    if (isResolved) ...[
                      // 🟢 조치 완료 상태일 때
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            LucideIcons.checkCircle2,
                            color: successGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "조치 완료 보고내용",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: successGreen,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  punch['actionText'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: slate900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // 🔴 미해결 상태일 때 (조치 입력창 활성화)
                      const Text(
                        "생산팀 조치 결과 입력",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: slate600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _controllers[doc.id],
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: "조치 내용을 상세히 적어주세요.",
                          hintStyle: const TextStyle(color: Colors.black26),
                          filled: true,
                          fillColor: tossGrey,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            HapticFeedback.heavyImpact();
                            final actionText = _controllers[doc.id]!.text
                                .trim();

                            if (actionText.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("조치 내용을 먼저 입력해주세요."),
                                ),
                              );
                              return;
                            }

                            // 🔥 Firestore 문서 업데이트 (상태 변경)
                            await FirebaseFirestore.instance
                                .collection('project_punches')
                                .doc(doc.id)
                                .update({
                                  'status': '조치 완료',
                                  'actionText': actionText,
                                });
                          },
                          icon: const Icon(
                            LucideIcons.checkCircle,
                            color: pureWhite,
                            size: 18,
                          ),
                          label: const Text(
                            "조치 완료 꼬리표 달기",
                            style: TextStyle(
                              color: pureWhite,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: successGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
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
