import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);

class MobileVehicleDetailPage extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final String currentUser;

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
          "차량 상세 및 예약",
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

            if (isAvailable &&
                (vehicle['parkingLocation'] != null ||
                    vehicle['keyLocation'] != null)) ...[
              const Text(
                "마지막 주차 정보",
                style: TextStyle(
                  color: slate900,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: pureWhite,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.mapPin,
                          color: tossBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "위치: ${vehicle['parkingLocation'] ?? '미기재'}",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: tossGrey),
                    ),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.key,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "차키: ${vehicle['keyLocation'] ?? '미기재'}",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

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
            _buildInsuranceCard(context),
            const SizedBox(height: 32),

            const Text(
              "최근 운행 기록",
              style: TextStyle(
                color: slate900,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _buildVehicleLogs(),
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
                    _showSmartReservationSheet(context);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isAvailable ? tossBlue : slate600,
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

  void _showSmartReservationSheet(BuildContext context) {
    final destinationCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();

    bool isNow = true;
    bool isLongTerm = false;

    DateTime selectedStartTime = DateTime.now();
    DateTime selectedReturnTime = DateTime.now().add(const Duration(hours: 2));

    String? selectedPurpose;
    // 🚀 수정된 부분: '현장 순찰' -> '현장 작업'
    final List<String> purposeOptions = [
      '자재 수급',
      '현장 작업',
      '외근/미팅',
      '차량 정비',
      '직접 입력',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> pickTime(bool isStart) async {
            HapticFeedback.lightImpact();
            final DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: isStart ? selectedStartTime : selectedReturnTime,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 30)),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(primary: tossBlue),
                ),
                child: child!,
              ),
            );

            if (pickedDate != null && context.mounted) {
              final TimeOfDay? pickedTime = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(
                  isStart ? selectedStartTime : selectedReturnTime,
                ),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    timePickerTheme: const TimePickerThemeData(
                      dialHandColor: tossBlue,
                    ),
                  ),
                  child: child!,
                ),
              );

              if (pickedTime != null) {
                setSheetState(() {
                  final newDateTime = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    pickedTime.hour,
                    pickedTime.minute,
                  );
                  if (isStart) {
                    selectedStartTime = newDateTime;
                    if (selectedReturnTime.isBefore(selectedStartTime)) {
                      selectedReturnTime = selectedStartTime.add(
                        const Duration(hours: 2),
                      );
                    }
                  } else {
                    selectedReturnTime = newDateTime;
                  }
                });
              }
            }
          }

          String formatDateTime(DateTime dt) =>
              "${dt.month}월 ${dt.day}일 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "스마트 배차 예약",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: slate900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "${vehicle['number']} 차량의 운행 계획을 입력해주세요.",
                  style: const TextStyle(color: slate600, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildInputLabel("사용 시점"),
                      Row(
                        children: [
                          Expanded(
                            child: _buildChoiceBtn(
                              text: "지금 당장 운행",
                              isSelected: isNow,
                              onTap: () => setSheetState(() {
                                isNow = true;
                                selectedStartTime = DateTime.now();
                              }),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildChoiceBtn(
                              text: "나중에 (예약)",
                              isSelected: !isNow,
                              onTap: () => setSheetState(() => isNow = false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _buildInputLabel("이용 구분"),
                      Row(
                        children: [
                          Expanded(
                            child: _buildChoiceBtn(
                              text: "단기 / 일반",
                              isSelected: !isLongTerm,
                              onTap: () =>
                                  setSheetState(() => isLongTerm = false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildChoiceBtn(
                              text: "장기 / 출장",
                              isSelected: isLongTerm,
                              onTap: () =>
                                  setSheetState(() => isLongTerm = true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _buildInputLabel("목적지"),
                      _buildTextField(destinationCtrl, "예: 명지동 자재상"),
                      const SizedBox(height: 16),

                      _buildInputLabel("운행 목적"),
                      DropdownButtonFormField<String>(
                        value: selectedPurpose,
                        hint: const Text("운행 목적 선택"),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: slate600,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: tossGrey,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: purposeOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setSheetState(() {
                            selectedPurpose = newValue;
                            if (newValue != '직접 입력') {
                              purposeCtrl.clear();
                            }
                          });
                        },
                      ),
                      if (selectedPurpose == '직접 입력') ...[
                        const SizedBox(height: 8),
                        _buildTextField(purposeCtrl, "예: A동 자재 수급"),
                      ],
                      const SizedBox(height: 20),

                      if (!isNow) ...[
                        _buildInputLabel("사용 시작 예약 시간"),
                        InkWell(
                          onTap: () => pickTime(true),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: tossGrey,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formatDateTime(selectedStartTime),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: slate900,
                                  ),
                                ),
                                const Icon(
                                  LucideIcons.calendarClock,
                                  color: slate600,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      _buildInputLabel(isLongTerm ? "예상 복 복귀 시간" : "예상 반납 시간"),
                      InkWell(
                        onTap: () => pickTime(false),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: tossBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: tossBlue.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                formatDateTime(selectedReturnTime),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: tossBlue,
                                ),
                              ),
                              const Icon(
                                LucideIcons.clock,
                                color: tossBlue,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();

                      String finalPurpose = selectedPurpose == '직접 입력'
                          ? purposeCtrl.text.trim()
                          : (selectedPurpose ?? '');

                      if (destinationCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("목적지를 입력해주세요."),
                            backgroundColor: warningRed,
                          ),
                        );
                        return;
                      }
                      if (finalPurpose.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("운행 목적을 선택하거나 입력해주세요."),
                            backgroundColor: warningRed,
                          ),
                        );
                        return;
                      }
                      if (!isNow &&
                          selectedStartTime.isBefore(
                            DateTime.now().subtract(const Duration(minutes: 5)),
                          )) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("과거 시간을 예약할 수 없습니다."),
                            backgroundColor: warningRed,
                          ),
                        );
                        return;
                      }
                      if (selectedReturnTime.isBefore(selectedStartTime)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("반납 시간은 시작 시간보다 빠를 수 없습니다."),
                            backgroundColor: warningRed,
                          ),
                        );
                        return;
                      }

                      String targetStatus = isNow ? '운행 중' : '예약 중';

                      await FirebaseFirestore.instance
                          .collection('vehicles')
                          .doc(vehicle['id'])
                          .update({
                            'status': targetStatus,
                            'currentUser': currentUser,
                            'destination': destinationCtrl.text.trim(),
                            'useType': isLongTerm ? "장기 출장" : "단기/일반",
                            'startTimeStamp': Timestamp.fromDate(
                              isNow ? DateTime.now() : selectedStartTime,
                            ),
                            'returnTimeStamp': Timestamp.fromDate(
                              selectedReturnTime,
                            ),
                            'returnTime': formatDateTime(selectedReturnTime),
                          });

                      await FirebaseFirestore.instance
                          .collection('vehicle_logs')
                          .add({
                            'userId': currentUser,
                            'type': vehicle['type'],
                            'number': vehicle['number'],
                            'date':
                                "${DateTime.now().year}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().day.toString().padLeft(2, '0')}",
                            'time': isNow
                                ? "출발 ~ ${formatDateTime(selectedReturnTime)}"
                                : "예약: ${formatDateTime(selectedStartTime)}",
                            'destination': destinationCtrl.text.trim(),
                            'purpose': finalPurpose,
                            'status': targetStatus,
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                      if (context.mounted) {
                        Navigator.pop(context);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isNow
                                  ? "배차가 완료되었습니다. 안전 운행하세요!"
                                  : "차량 예약이 완료되었습니다.",
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
                      isNow ? "운행 시작하기" : "예약 완료하기",
                      style: const TextStyle(
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
          );
        },
      ),
    );
  }

  Widget _buildChoiceBtn({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? tossBlue : pureWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? tossBlue : Colors.black12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? pureWhite : slate600,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
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
    String? imageUrl = vehicle['imageUrl'];
    String fuelType = vehicle['fuelType'] ?? '가솔린';

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
          Center(
            child: Container(
              width: double.infinity,
              height: 180,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: slate100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              ),
              clipBehavior: Clip.hardEdge,
              child: (imageUrl != null && imageUrl.isNotEmpty)
                  ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.car, size: 64, color: slate600),
                      ],
                    ),
            ),
          ),
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
          Row(
            children: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: fuelType == '전기'
                      ? tossBlue.withValues(alpha: 0.1)
                      : slate100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  fuelType,
                  style: TextStyle(
                    fontSize: 11,
                    color: fuelType == '전기' ? tossBlue : slate600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                "차량 번호: ${vehicle['number'] ?? "-"}",
                style: const TextStyle(
                  color: slate600,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCard() {
    String fuelType = vehicle['fuelType'] ?? '가솔린';
    int currentKm = int.tryParse(vehicle['currentMileage'].toString()) ?? 0;
    int nextKm = int.tryParse(vehicle['nextMaintenanceKm'].toString()) ?? 0;
    int remainKm = nextKm - currentKm;
    bool isWarning = (currentKm != 0 && nextKm != 0) && (remainKm <= 1000);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isWarning
                      ? warningRed.withValues(alpha: 0.1)
                      : slate100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.wrench,
                  color: isWarning ? warningRed : slate600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fuelType == '전기' ? "정기 점검" : "엔진 오일 교체",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: slate900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (currentKm == 0 || nextKm == 0)
                      const Text(
                        "주행거리 데이터 없음",
                        style: TextStyle(fontSize: 13, color: slate600),
                      )
                    else if (remainKm < 0)
                      Text(
                        "⚠️ 교체 시기 지남!",
                        style: const TextStyle(
                          fontSize: 13,
                          color: warningRed,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      Text(
                        "여유: $remainKm km 남음",
                        style: const TextStyle(
                          fontSize: 13,
                          color: tossBlue,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildInsuranceCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
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
                Text(
                  vehicle['insurance'] ?? "-",
                  style: const TextStyle(
                    fontSize: 16,
                    color: tossBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleLogs() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vehicle_logs')
          .where('number', isEqualTo: vehicle['number'])
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(color: tossBlue),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: const Text(
              "최근 운행 기록이 없습니다.",
              style: TextStyle(color: slate600, fontWeight: FontWeight.bold),
            ),
          );
        }

        var logs = snapshot.data!.docs;

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: logs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            var log = logs[index].data() as Map<String, dynamic>;
            return _buildLogCard(log);
          },
        );
      },
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    bool isReturned = log['status'] == '반납';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                log['date'] ?? '-',
                style: const TextStyle(
                  color: slate600,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isReturned
                      ? slate100
                      : tossBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  log['status'] ?? '-',
                  style: TextStyle(
                    color: isReturned ? slate600 : tossBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(LucideIcons.user, size: 16, color: slate900),
              const SizedBox(width: 8),
              Text(
                log['userId'] ?? '알 수 없음',
                style: const TextStyle(
                  color: slate900,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (log['destination'] != null)
            Row(
              children: [
                const Icon(LucideIcons.mapPin, size: 16, color: slate600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "목적지: ${log['destination']}",
                    style: const TextStyle(color: slate600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          if (isReturned && log['parking'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.parkingSquare,
                    size: 16,
                    color: tossBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "반납 위치: ${log['parking']}",
                      style: const TextStyle(
                        color: tossBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
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
