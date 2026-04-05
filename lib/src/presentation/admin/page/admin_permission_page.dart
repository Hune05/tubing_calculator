import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';

// 기존 색상 재사용
const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);
const Color makitaTeal = Color(0xFF007580);

class AdminPermissionPage extends StatefulWidget {
  const AdminPermissionPage({super.key});

  @override
  State<AdminPermissionPage> createState() => _AdminPermissionPageState();
}

class _AdminPermissionPageState extends State<AdminPermissionPage> {
  // 파이어베이스 사용자 컬렉션 참조
  final CollectionReference _usersRef = FirebaseFirestore.instance.collection(
    'users',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tossGrey,
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slate900),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "직원 권한 관리",
          style: TextStyle(
            color: slate900,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _usersRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: tossBlue),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text("에러가 발생했습니다: ${snapshot.error}"));
          }

          final users = snapshot.data?.docs ?? [];

          if (users.isEmpty) {
            return const Center(
              child: Text(
                "등록된 직원이 없습니다.",
                style: TextStyle(color: slate600, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userDoc = users[index];
              final userData = userDoc.data() as Map<String, dynamic>;
              return _buildUserCard(userDoc.id, userData);
            },
          );
        },
      ),
    );
  }

  Widget _buildUserCard(String docId, Map<String, dynamic> data) {
    String name = data['name'] ?? '이름 없음';
    String email = data['email'] ?? '이메일 없음';
    bool isMaster = data['isMaster'] ?? false;

    // 권한 상태 (기본값 설정)
    bool canOrder = data['canOrder'] ?? false;
    bool canApprove = data['canApprove'] ?? false;
    bool canReceive = data['canReceive'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMaster ? warningRed.withValues(alpha: 0.3) : Colors.black12,
          width: isMaster ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. 프로필 영역 (이름, 이메일, 마스터 뱃지)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isMaster
                      ? warningRed.withValues(alpha: 0.1)
                      : tossBlue.withValues(alpha: 0.1),
                  child: Icon(
                    isMaster ? LucideIcons.crown : LucideIcons.user,
                    color: isMaster ? warningRed : tossBlue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: slate900,
                            ),
                          ),
                          if (isMaster) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: warningRed,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "마스터",
                                style: TextStyle(
                                  color: pureWhite,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: slate600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.black12),

          // 2. 권한 설정 스위치 영역
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                _buildPermissionSwitch(
                  docId: docId,
                  title: "자재 발주 요청",
                  subtitle: "현장에서 필요한 자재를 카트에 담아 발주",
                  field: "canOrder",
                  currentValue: canOrder,
                  isDisabled: isMaster, // 마스터는 권한 해제 불가
                ),
                _buildPermissionSwitch(
                  docId: docId,
                  title: "발주 승인 및 관리",
                  subtitle: "발주 내역 확인, 상태 변경 및 반려 처리",
                  field: "canApprove",
                  currentValue: canApprove,
                  isDisabled: isMaster,
                ),
                _buildPermissionSwitch(
                  docId: docId,
                  title: "현장 수령 확인",
                  subtitle: "도착한 자재의 최종 수령 확인 및 종결",
                  field: "canReceive",
                  currentValue: canReceive,
                  isDisabled: isMaster,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionSwitch({
    required String docId,
    required String title,
    required String subtitle,
    required String field,
    required bool currentValue,
    required bool isDisabled,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: isDisabled ? slate600 : slate900,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.black45),
      ),
      trailing: Switch.adaptive(
        value: currentValue,
        activeColor: tossBlue,
        onChanged: isDisabled
            ? null
            : (newValue) async {
                HapticFeedback.lightImpact();
                // Firestore에 즉시 업데이트
                await _usersRef.doc(docId).update({field: newValue});

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "$title 권한이 ${newValue ? '부여' : '해제'}되었습니다.",
                      ),
                      backgroundColor: slate900,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
      ),
    );
  }
}
