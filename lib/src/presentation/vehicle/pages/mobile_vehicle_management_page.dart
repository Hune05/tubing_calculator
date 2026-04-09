import 'dart:async'; // 🚀 타이머 사용을 위해 추가
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'mobile_vehicle_detail_page.dart';
import 'mobile_vehicle_return_page.dart';

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);
const Color successGreen = Color(0xFF00C853);
const Color makitaTeal = Color(0xFF007580); // 🚀 내 차량 강조 컬러

class MobileVehicleManagementPage extends StatefulWidget {
  final String currentUser;

  const MobileVehicleManagementPage({super.key, required this.currentUser});

  @override
  State<MobileVehicleManagementPage> createState() =>
      _MobileVehicleManagementPageState();
}

class _MobileVehicleManagementPageState
    extends State<MobileVehicleManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = '전체';

  final List<String> _filters = ['전체', '내 차량', '사용 가능', '트럭', '지게차', '전기차'];

  // 🚀 타이머와 알림 중복 방지 변수
  Timer? _statusMonitorTimer;
  final Set<String> _shownAlerts = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 🚀 화면 켜질 때부터 1분마다 내 차량 상태 감시 시작!
    _statusMonitorTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkMyVehicleStatus();
    });

    // 최초 진입 시 즉시 검사
    _checkMyVehicleStatus();
  }

  @override
  void dispose() {
    _statusMonitorTimer?.cancel(); // 🚀 화면 나갈 때 타이머 끄기
    _tabController.dispose();
    super.dispose();
  }

  // =======================================================
  // 🚨 핵심: 예약/운행 시간에 따른 백그라운드 상태 감시 로직
  // =======================================================
  Future<void> _checkMyVehicleStatus() async {
    if (!mounted) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('vehicles')
        .where('currentUser', isEqualTo: widget.currentUser)
        .get();

    if (snapshot.docs.isEmpty) return;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final status = data['status'];
      final docId = doc.id;
      final number = data['number'] ?? '차량';

      if (data['startTimeStamp'] == null || data['returnTimeStamp'] == null)
        continue;

      final DateTime startTime = (data['startTimeStamp'] as Timestamp).toDate();
      final DateTime returnTime = (data['returnTimeStamp'] as Timestamp)
          .toDate();
      final DateTime now = DateTime.now();

      // 🌟 [시나리오 1] 예약 중일 때 (노쇼 감시)
      if (status == '예약 중') {
        int diffStart = startTime.difference(now).inMinutes; // 시작까지 남은 시간
        int overStart = now.difference(startTime).inMinutes; // 시작 지나간 시간

        // 1-1. 예약 시간 전 알림
        if (diffStart <= 60 &&
            diffStart > 58 &&
            !_shownAlerts.contains('res_60_$docId')) {
          _showAlert("예약하신 [$number] 운행 시작 1시간 전입니다.");
          _shownAlerts.add('res_60_$docId');
        } else if (diffStart <= 30 &&
            diffStart > 28 &&
            !_shownAlerts.contains('res_30_$docId')) {
          _showAlert("예약하신 [$number] 운행 시작 30분 전입니다.");
          _shownAlerts.add('res_30_$docId');
        }

        // 1-2. 예약 시간 경과 후 미사용 알림
        if (overStart >= 5 &&
            overStart < 15 &&
            !_shownAlerts.contains('over_5_$docId')) {
          _showAlert("[$number] 예약 시간이 5분 지났습니다. 운행을 시작해주세요.");
          _shownAlerts.add('over_5_$docId');
        } else if (overStart >= 15 &&
            overStart < 30 &&
            !_shownAlerts.contains('over_15_$docId')) {
          _showAlert("[$number] 예약 시간이 15분 지났습니다. 미사용 시 배차가 취소될 수 있습니다.");
          _shownAlerts.add('over_15_$docId');
        } else if (overStart >= 30 &&
            overStart < 35 &&
            !_shownAlerts.contains('over_30_$docId')) {
          _showCancelWarningDialog(docId, number);
          _shownAlerts.add('over_30_$docId');
        } else if (overStart >= 35 &&
            !_shownAlerts.contains('over_35_$docId')) {
          // 🚀 35분 경과: 강제 취소 (DB 업데이트)
          _shownAlerts.add('over_35_$docId');
          await FirebaseFirestore.instance
              .collection('vehicles')
              .doc(docId)
              .update({
                'status': '사용 가능',
                'currentUser': null,
                'destination': null,
                'returnTime': null,
                'startTimeStamp': null,
                'returnTimeStamp': null,
              });
          if (mounted) {
            _showAlert("[$number] 예약 후 35분이 경과하여 배차가 자동 취소되었습니다.");
          }
        }
      }

      // 🌟 [시나리오 2] 운행 중일 때 (반납 지연 감시)
      if (status == '운행 중') {
        int overReturn = now.difference(returnTime).inMinutes;

        if (overReturn >= 5 &&
            overReturn < 15 &&
            !_shownAlerts.contains('ret_5_$docId')) {
          _showExtendDialog(
            docId,
            number,
            "반납 시간이 5분 지났습니다.\n운행 시간을 연장하시겠습니까?",
            returnTime,
          );
          _shownAlerts.add('ret_5_$docId');
        } else if (overReturn >= 15 &&
            !_shownAlerts.contains('ret_15_$docId')) {
          _showExtendDialog(
            docId,
            number,
            "반납 시간이 15분 지났습니다!\n(2차 알림) 연장이 필요합니다.",
            returnTime,
          );
          _shownAlerts.add('ret_15_$docId');
        }
      }
    }
  }

  // 스낵바 알림 헬퍼
  void _showAlert(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: slate900,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 노쇼 30분 경과 취소 경고 팝업
  void _showCancelWarningDialog(String vehicleId, String number) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(LucideIcons.alertTriangle, color: warningRed),
            const SizedBox(width: 8),
            const Text(
              "예약 취소 경고",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          "[$number] 예약 시간이 30분 지났습니다.\n5분 뒤 자동으로 배차가 취소됩니다.\n지금 운행을 시작하시겠습니까?",
          style: const TextStyle(color: slate600, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("닫기", style: TextStyle(color: slate600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: tossBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('vehicles')
                  .doc(vehicleId)
                  .update({'status': '운행 중'});
              _showAlert("운행이 시작되었습니다. 안전 운행하세요!");
            },
            child: const Text(
              "지금 운행 시작",
              style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // 운행 지연 연장 팝업
  void _showExtendDialog(
    String vehicleId,
    String number,
    String message,
    DateTime currentReturnTime,
  ) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(LucideIcons.clock, color: warningRed),
            const SizedBox(width: 8),
            const Text(
              "반납 시간 초과",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: slate600, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("곧 반납할게요", style: TextStyle(color: slate600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: tossBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              DateTime newReturnTime = currentReturnTime.add(
                const Duration(hours: 1),
              );
              String newTimeStr =
                  "${newReturnTime.month}월 ${newReturnTime.day}일 ${newReturnTime.hour.toString().padLeft(2, '0')}:${newReturnTime.minute.toString().padLeft(2, '0')}";
              await FirebaseFirestore.instance
                  .collection('vehicles')
                  .doc(vehicleId)
                  .update({
                    'returnTimeStamp': Timestamp.fromDate(newReturnTime),
                    'returnTime': newTimeStr,
                  });
              _showAlert("운행 시간이 1시간 연장되었습니다.");
            },
            child: const Text(
              "1시간 연장하기",
              style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
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

  Widget _buildVehicleStatusTab() {
    return Column(
      children: [
        // 🚀 퀵 필터 바
        Container(
          height: 60,
          color: pureWhite,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: _filters.length,
            itemBuilder: (context, index) {
              final filter = _filters[index];
              bool isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (selected) {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedFilter = filter);
                  },
                  selectedColor: slate900,
                  labelStyle: TextStyle(
                    color: isSelected ? pureWhite : slate600,
                    fontWeight: FontWeight.bold,
                  ),
                  backgroundColor: slate100,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('vehicles')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(
                  child: CircularProgressIndicator(color: tossBlue),
                );
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.docs.isEmpty)
                return const Center(
                  child: Text(
                    "등록된 차량이 없습니다.",
                    style: TextStyle(color: slate600),
                  ),
                );

              var vehicles = snapshot.data!.docs.map((doc) {
                var data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                return data;
              }).toList();

              // 🚀 필터 로직
              vehicles = vehicles.where((v) {
                bool amIUsing =
                    (v['status'] == '예약 중' || v['status'] == '운행 중') &&
                    v['currentUser'] == widget.currentUser;
                if (_selectedFilter == '내 차량') return amIUsing;
                if (_selectedFilter == '사용 가능') return v['status'] == '사용 가능';
                if (_selectedFilter == '트럭')
                  return (v['type'] ?? '').contains('트럭');
                if (_selectedFilter == '지게차')
                  return (v['type'] ?? '').contains('지게차');
                if (_selectedFilter == '전기차') return v['fuelType'] == '전기';
                return true;
              }).toList();

              // 🚀 정렬 로직: 내 차량 무조건 최상단
              vehicles.sort((a, b) {
                bool amIUsingA = a['currentUser'] == widget.currentUser;
                bool amIUsingB = b['currentUser'] == widget.currentUser;
                if (amIUsingA && !amIUsingB) return -1;
                if (!amIUsingA && amIUsingB) return 1;
                return 0;
              });

              if (vehicles.isEmpty)
                return const Center(
                  child: Text(
                    "조건에 맞는 차량이 없습니다.",
                    style: TextStyle(color: slate600),
                  ),
                );

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                itemCount: vehicles.length,
                itemBuilder: (context, index) {
                  final vehicleData = vehicles[index];
                  bool isAvailable = vehicleData['status'] == "사용 가능";
                  bool isReserved = vehicleData['status'] == "예약 중";
                  bool inUse = vehicleData['status'] == "운행 중";
                  bool amIUsing =
                      (!isAvailable) &&
                      vehicleData['currentUser'] == widget.currentUser;

                  return InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => amIUsing && inUse
                              ? MobileVehicleReturnPage(
                                  vehicle: vehicleData,
                                  currentUser: widget.currentUser,
                                )
                              : MobileVehicleDetailPage(
                                  vehicle: vehicleData,
                                  currentUser: widget.currentUser,
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
                          color: amIUsing
                              ? makitaTeal.withValues(alpha: 0.5)
                              : (isAvailable
                                    ? tossBlue.withValues(alpha: 0.2)
                                    : Colors.transparent),
                          width: amIUsing ? 2.0 : 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (amIUsing)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: makitaTeal,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isReserved ? "현재 내 예약 차량" : "현재 내 운행 차량",
                                  style: const TextStyle(
                                    color: pureWhite,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
                                    color: isAvailable
                                        ? tossBlue
                                        : (amIUsing ? makitaTeal : slate600),
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (vehicleData['parkingLocation'] != null &&
                                    vehicleData['parkingLocation']
                                        .toString()
                                        .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      "📍 위치: ${vehicleData['parkingLocation']}",
                                      style: const TextStyle(
                                        color: slate900,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "현재 배차 대기 중입니다.",
                                      style: TextStyle(
                                        color: tossBlue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: tossBlue,
                                    ),
                                  ],
                                ),
                              ],
                            )
                          else
                            Column(
                              children: [
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${vehicleData['currentUser']} ${vehicleData['status']}",
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: amIUsing
                                                  ? makitaTeal
                                                  : slate900,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "목적: ${vehicleData['destination'] ?? "미정"}",
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: slate900,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "예정: ${vehicleData['returnTime'] ?? "미정"}",
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: slate600,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                // 🚀 메인에서 바로 상태를 바꿀 수 있는 액션 버튼
                                if (amIUsing) ...[
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isReserved
                                            ? tossBlue
                                            : slate900,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      onPressed: () async {
                                        HapticFeedback.mediumImpact();
                                        if (isReserved) {
                                          await FirebaseFirestore.instance
                                              .collection('vehicles')
                                              .doc(vehicleData['id'])
                                              .update({'status': '운행 중'});
                                          _showAlert("안전 운행하세요!");
                                        } else {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  MobileVehicleReturnPage(
                                                    vehicle: vehicleData,
                                                    currentUser:
                                                        widget.currentUser,
                                                  ),
                                            ),
                                          );
                                        }
                                      },
                                      child: Text(
                                        isReserved ? "지금 운행 시작하기" : "차량 반납하기",
                                        style: const TextStyle(
                                          color: pureWhite,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMyLogsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vehicle_logs')
          .where('userId', isEqualTo: widget.currentUser)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(
            child: CircularProgressIndicator(color: tossBlue),
          );
        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.docs.isEmpty)
          return const Center(
            child: Text("운행 내역이 없습니다.", style: TextStyle(color: slate600)),
          );

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
