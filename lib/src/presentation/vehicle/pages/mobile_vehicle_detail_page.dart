import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔥 파이어베이스 임포트

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);

class MobileVehicleDetailPage extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final String currentUser; // 🚀 예약자 정보를 위해 추가

  const MobileVehicleDetailPage({
    super.key,
    required this.vehicle,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    bool isAvailable = vehicle['status'] == "사용 가능";
    bool hasFixedTeam =
        vehicle['fixedTeam'] != null &&
        vehicle['fixedTeam'].toString().isNotEmpty;

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
        title: const Text(
          "차량 상세 정보",
          style: TextStyle(
            color: slate900,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderInfo(isAvailable, hasFixedTeam),
            const SizedBox(height: 24),
            const Text(
              "정비 및 소모품 현황",
              style: TextStyle(
                color: slate900,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _buildMaintenanceCard(),
            const SizedBox(height: 24),
            const Text(
              "사고 접수 및 보험 정보",
              style: TextStyle(
                color: slate900,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _buildInsuranceCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
          top: 16,
        ),
        decoration: const BoxDecoration(
          color: pureWhite,
          border: Border(top: BorderSide(color: Colors.black12)),
        ),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: isAvailable
                ? () {
                    HapticFeedback.mediumImpact();
                    _showReservationBottomSheet(context); // 🚀 예약 모달 띄우기
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isAvailable ? tossBlue : slate600,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              isAvailable ? "배차 예약하기" : "운행 종료 대기 중",
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: pureWhite,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🚀 배차 예약 바텀시트 및 Firebase 업데이트 로직
  void _showReservationBottomSheet(BuildContext context) {
    final destinationCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();
    final returnTimeCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "운행 정보 입력",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: slate900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${vehicle['number']} 배차를 위해 아래 정보를 입력해주세요.",
              style: const TextStyle(color: slate600, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildInputLabel("목적지"),
                  _buildTextField(destinationCtrl, "예: 명지동 자재상"),
                  const SizedBox(height: 16),
                  _buildInputLabel("운행 목적"),
                  _buildTextField(purposeCtrl, "예: A동 자재 수급"),
                  const SizedBox(height: 16),
                  _buildInputLabel("예상 반납 시간"),
                  _buildTextField(returnTimeCtrl, "예: 오늘 오후 3시"),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  HapticFeedback.mediumImpact();

                  if (destinationCtrl.text.isEmpty ||
                      returnTimeCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("목적지와 예상 반납 시간을 입력해주세요.")),
                    );
                    return;
                  }

                  // 🚀 1. 차량 상태 '운행 중'으로 업데이트
                  await FirebaseFirestore.instance
                      .collection('vehicles')
                      .doc(vehicle['id'])
                      .update({
                        'status': '운행 중',
                        'currentUser': currentUser,
                        'destination': destinationCtrl.text.trim(),
                        'returnTime': returnTimeCtrl.text.trim(),
                      });

                  // 🚀 2. 운행 로그(내역) 추가
                  await FirebaseFirestore.instance.collection('vehicle_logs').add({
                    'userId': currentUser,
                    'type': vehicle['type'],
                    'number': vehicle['number'],
                    'date':
                        "${DateTime.now().year}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().day.toString().padLeft(2, '0')}",
                    'time': "출발 ~ ${returnTimeCtrl.text.trim()}",
                    'destination': destinationCtrl.text.trim(),
                    'purpose': purposeCtrl.text.trim(),
                    'status': '운행 중', // 추후 반납 기능이 추가되면 '반납 완료'로 업데이트 할 수 있습니다.
                  });

                  if (context.mounted) {
                    Navigator.pop(context); // 바텀시트 닫기
                    Navigator.pop(context); // 상세페이지 닫고 메인으로 복귀
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("배차 예약이 완료되었습니다."),
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
                child: const Text(
                  "예약 완료하기",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: pureWhite,
                  ),
                ),
              ),
            ),
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

  Widget _buildHeaderInfo(bool isAvailable, bool hasFixedTeam) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                vehicle['type'] ?? "-",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: slate900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? tossBlue.withValues(alpha: 0.1)
                      : warningRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  vehicle['status'] ?? "-",
                  style: TextStyle(
                    color: isAvailable ? tossBlue : warningRed,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "차량 번호: ${vehicle['number'] ?? "-"}",
            style: const TextStyle(
              color: slate600,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          if (hasFixedTeam)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF8A2BE2).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.users,
                    size: 16,
                    color: Color(0xFF8A2BE2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "이 차량은 [${vehicle['fixedTeam']}] 우선 배차 차량입니다.",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8A2BE2),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCard() {
    bool isOilWarning = (vehicle['oilNext'] ?? "").toString().contains("임박");

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: slate100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.wrench,
                  color: slate600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "엔진 오일",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: slate900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicle['oilNext'] ?? "-",
                      style: TextStyle(
                        fontSize: 13,
                        color: isOilWarning ? warningRed : slate600,
                        fontWeight: isOilWarning
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: tossGrey),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: slate100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.circleDashed,
                  color: slate600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "타이어 교체 주기",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: slate900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicle['tireNext'] ?? "-",
                      style: const TextStyle(fontSize: 13, color: slate600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsuranceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tossBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.shieldCheck,
              color: tossBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "가입 보험사",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: slate900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  vehicle['insurance'] ?? "-",
                  style: const TextStyle(
                    fontSize: 16,
                    color: tossBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                  },
                  icon: const Icon(LucideIcons.phoneCall, size: 16),
                  label: const Text("사고/긴급출동 전화걸기"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: slate900,
                    side: const BorderSide(color: Colors.black12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
