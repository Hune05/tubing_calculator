import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔥 파이어베이스 임포트

// 🚀 차량 상세 페이지 임포트 (경로는 프로젝트에 맞게 수정하세요)
import 'mobile_vehicle_detail_page.dart';

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);
const Color successGreen = Color(0xFF00C853);
const Color purpleBadge = Color(0xFF8A2BE2);

class MobileVehicleManagementPage extends StatefulWidget {
  final String currentUser; // 현재 로그인한 사용자 이름 또는 ID

  const MobileVehicleManagementPage({super.key, required this.currentUser});

  @override
  State<MobileVehicleManagementPage> createState() =>
      _MobileVehicleManagementPageState();
}

class _MobileVehicleManagementPageState
    extends State<MobileVehicleManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slate900),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "차량 및 장비 운행 관리",
          style: TextStyle(
            color: slate900,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: tossBlue,
          indicatorWeight: 3,
          labelColor: tossBlue,
          unselectedLabelColor: slate600,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          tabs: const [
            Tab(text: "실시간 배차 현황"),
            Tab(text: "내 운행 내역"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildVehicleStatusTab(), _buildMyLogsTab()],
      ),
    );
  }

  // 🔴 1. 실시간 배차 현황 탭 (vehicles 컬렉션 연동)
  Widget _buildVehicleStatusTab() {
    return StreamBuilder<QuerySnapshot>(
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
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          itemCount: vehicles.length,
          itemBuilder: (context, index) {
            final vehicleData = vehicles[index].data() as Map<String, dynamic>;
            vehicleData['id'] = vehicles[index].id; // Firestore 문서 ID 추가

            bool isAvailable = vehicleData['status'] == "사용 가능";
            bool hasFixedTeam =
                vehicleData['fixedTeam'] != null &&
                vehicleData['fixedTeam'].toString().isNotEmpty;
            bool isLongTerm = vehicleData['useType'] == "장기 출장";

            return InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MobileVehicleDetailPage(
                      vehicle: vehicleData,
                      currentUser: widget.currentUser, // 🚀 로그인 유저 정보 넘기기
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
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
                  border: Border.all(
                    color: isAvailable
                        ? tossBlue.withValues(alpha: 0.3)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasFixedTeam || isLongTerm)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            if (hasFixedTeam)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: purpleBadge.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  vehicleData['fixedTeam'],
                                  style: const TextStyle(
                                    color: purpleBadge,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (isLongTerm)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: warningRed.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  "장기 출장 중",
                                  style: TextStyle(
                                    color: warningRed,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              (vehicleData['type'] ?? "").contains("지게차")
                                  ? LucideIcons.forklift
                                  : LucideIcons.truck,
                              color: isAvailable ? tossBlue : slate600,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              vehicleData['type'] ?? "-",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: slate900,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isAvailable
                                ? tossBlue.withValues(alpha: 0.1)
                                : tossGrey,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            vehicleData['status'] ?? "-",
                            style: TextStyle(
                              color: isAvailable ? tossBlue : slate600,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "차량 번호: ${vehicleData['number'] ?? ""}",
                      style: const TextStyle(
                        color: slate600,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1, color: tossGrey),
                    ),
                    if (isAvailable)
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "현재 배차 대기 중입니다.",
                            style: TextStyle(
                              color: tossBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: tossBlue),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: slate100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.user,
                              size: 20,
                              color: slate600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${vehicleData['currentUser']} 운행 중",
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: slate900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      LucideIcons.mapPin,
                                      size: 14,
                                      color: warningRed,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        "목적지: ${vehicleData['destination'] ?? ""}",
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: slate900,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.calendarClock,
                                      size: 14,
                                      color: slate600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isLongTerm
                                          ? "복귀 예정: ${vehicleData['returnTime'] ?? ""}"
                                          : "반납 예정: ${vehicleData['returnTime'] ?? ""}",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isLongTerm
                                            ? warningRed
                                            : slate600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 🔴 2. 내 운행 내역 탭 (vehicle_logs 컬렉션 연동)
  Widget _buildMyLogsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vehicle_logs')
          .where('userId', isEqualTo: widget.currentUser) // 내 기록만 필터링
          .snapshots(),
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
            child: Text("운행 내역이 없습니다.", style: TextStyle(color: slate600)),
          );
        }

        final myLogs = snapshot.data!.docs;

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          itemCount: myLogs.length,
          itemBuilder: (context, index) {
            final log = myLogs[index].data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: pureWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        log['date'] ?? "",
                        style: const TextStyle(
                          color: slate600,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        log['status'] ?? "",
                        style: const TextStyle(
                          color: slate600,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    log['type'] ?? "-",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: slate900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "차량번호: ${log['number'] ?? ""}",
                    style: const TextStyle(fontSize: 14, color: slate600),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tossGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.mapPin,
                              size: 16,
                              color: slate600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "목적지: ${log['destination'] ?? ""}",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: slate900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.clipboardList,
                              size: 16,
                              color: slate600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "목적: ${log['purpose'] ?? ""}",
                              style: const TextStyle(
                                fontSize: 13,
                                color: slate600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.clock,
                              size: 16,
                              color: slate600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              log['time'] ?? "",
                              style: const TextStyle(
                                fontSize: 13,
                                color: slate600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
