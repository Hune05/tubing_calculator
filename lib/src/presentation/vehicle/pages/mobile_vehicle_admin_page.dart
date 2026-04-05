import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔥 Firebase 임포트 필수

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);

class MobileVehicleAdminPage extends StatefulWidget {
  const MobileVehicleAdminPage({super.key});

  @override
  State<MobileVehicleAdminPage> createState() => _MobileVehicleAdminPageState();
}

class _MobileVehicleAdminPageState extends State<MobileVehicleAdminPage> {
  // 🔥 더미 데이터(_adminVehicles) 삭제! Firestore에서 직접 가져옵니다.

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
              "차량 통합 세팅",
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
      // 🔥 StreamBuilder로 실시간 차량 목록 감시
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vehicles').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: tossBlue),
            );
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("등록된 차량이 없습니다.", style: TextStyle(color: slate600)),
            );
          }

          final vehicles = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final vehicleData =
                  vehicles[index].data() as Map<String, dynamic>;
              vehicleData['id'] = vehicles[index].id; // 문서 ID 삽입

              bool inUse = vehicleData['status'] == "운행 중";

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
                          vehicleData['number'] ?? '번호 없음',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: tossBlue,
                          ),
                        ),
                        if (inUse)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: warningRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "운행 중",
                              style: TextStyle(
                                color: warningRed,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: tossBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "차고지 대기",
                              style: TextStyle(
                                color: tossBlue,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicleData['type'] ?? '-',
                      style: const TextStyle(
                        fontSize: 15,
                        color: slate900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tossGrey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "배정 현황",
                                style: TextStyle(color: slate600, fontSize: 13),
                              ),
                              Text(
                                vehicleData['fixedTeam'] ?? "없음 (공용)",
                                style: const TextStyle(
                                  color: slate900,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (inUse) ...[
                            const Divider(height: 16, color: Colors.black12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "현재 사용자",
                                  style: TextStyle(
                                    color: slate600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  "${vehicleData['currentUser']}",
                                  style: const TextStyle(
                                    color: warningRed,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _showEditBottomSheet(vehicleData);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: slate900,
                              side: const BorderSide(color: Colors.black12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text("정보/정비 수정"),
                          ),
                        ),
                        if (inUse) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                HapticFeedback.heavyImpact();
                                // 🔥 강제 회수(반납) 처리 로직
                                await FirebaseFirestore.instance
                                    .collection('vehicles')
                                    .doc(vehicleData['id'])
                                    .update({
                                      'status': '사용 가능',
                                      'currentUser': null,
                                      'destination': null,
                                      'returnTime': null,
                                    });

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("관리자 권한으로 강제 반납 처리되었습니다."),
                                      backgroundColor: slate900,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: warningRed,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                "강제 회수",
                                style: TextStyle(
                                  color: pureWhite,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
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
          _showEditBottomSheet(null); // 신규 등록 모드
        },
        backgroundColor: slate900,
        icon: const Icon(Icons.add, color: pureWhite),
        label: const Text(
          "신규 차량 등록",
          style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // 🚀 차량 등록/수정 바텀시트
  void _showEditBottomSheet(Map<String, dynamic>? vehicle) {
    bool isNew = vehicle == null;

    // 🔥 텍스트 컨트롤러 생성 (수정 시 기존 데이터 삽입)
    final numCtrl = TextEditingController(text: isNew ? '' : vehicle['number']);
    final typeCtrl = TextEditingController(text: isNew ? '' : vehicle['type']);
    final teamCtrl = TextEditingController(
      text: isNew ? '' : vehicle['fixedTeam'],
    );
    final insCtrl = TextEditingController(
      text: isNew ? '' : vehicle['insurance'],
    );
    final oilCtrl = TextEditingController(
      text: isNew ? '' : vehicle['oilNext'],
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isNew ? "신규 차량 등록" : "차량 정보 수정",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: slate900,
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildInputLabel("차량 번호"),
                  _buildTextField(numCtrl, isNew ? "예: 12가 3456" : "차량 번호 입력"),
                  const SizedBox(height: 16),

                  _buildInputLabel("차종 및 설명"),
                  _buildTextField(typeCtrl, isNew ? "예: 1톤 포터 (카고)" : "차종 입력"),
                  const SizedBox(height: 16),

                  _buildInputLabel("고정 팀 배정 (선택)"),
                  _buildTextField(
                    teamCtrl,
                    isNew ? "예: 수리팀 전용 (비워두면 공용)" : "팀 배정 입력",
                  ),
                  const SizedBox(height: 16),

                  const Divider(height: 32, color: tossGrey),

                  _buildInputLabel("보험사 연락처"),
                  _buildTextField(
                    insCtrl,
                    isNew ? "예: 삼성화재 1588-5114" : "보험사 정보 입력",
                  ),
                  const SizedBox(height: 16),

                  _buildInputLabel("다음 엔진오일 교체 주기"),
                  _buildTextField(
                    oilCtrl,
                    isNew ? "예: 80,000km" : "엔진오일 정보 입력",
                  ),
                ],
              ),
            ),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  HapticFeedback.mediumImpact();

                  // 🔥 Firebase 저장 데이터 구성
                  final saveInfo = {
                    'number': numCtrl.text.trim(),
                    'type': typeCtrl.text.trim(),
                    'fixedTeam': teamCtrl.text.trim().isEmpty
                        ? null
                        : teamCtrl.text.trim(),
                    'insurance': insCtrl.text.trim(),
                    'oilNext': oilCtrl.text.trim(),
                  };

                  if (isNew) {
                    // 신규 등록 시 기본 상태값 추가
                    saveInfo['status'] = "사용 가능";
                    saveInfo['currentUser'] = null;
                    saveInfo['destination'] = null;
                    saveInfo['returnTime'] = null;
                    saveInfo['useType'] = "단기/일반"; // 기본값
                    saveInfo['tireNext'] = "점검 요망"; // 기본값

                    await FirebaseFirestore.instance
                        .collection('vehicles')
                        .add(saveInfo);
                  } else {
                    // 기존 데이터 수정
                    await FirebaseFirestore.instance
                        .collection('vehicles')
                        .doc(vehicle['id'])
                        .update(saveInfo);
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isNew ? "새 차량이 등록되었습니다." : "차량 정보가 수정되었습니다.",
                        ),
                        backgroundColor: tossBlue,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: tossBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  isNew ? "차량 등록하기" : "수정 사항 저장",
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: pureWhite,
                  ),
                ),
              ),
            ),
            // 하단 키보드 공간 확보
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: slate600,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  // 🔥 컨트롤러를 받도록 수정
  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black26),
        filled: true,
        fillColor: tossGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
