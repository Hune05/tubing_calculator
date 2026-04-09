import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);

class MobileVehicleReturnPage extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  final String currentUser;

  const MobileVehicleReturnPage({
    super.key,
    required this.vehicle,
    required this.currentUser,
  });

  @override
  State<MobileVehicleReturnPage> createState() =>
      _MobileVehicleReturnPageState();
}

class _MobileVehicleReturnPageState extends State<MobileVehicleReturnPage> {
  final TextEditingController _mileageCtrl = TextEditingController();
  final TextEditingController _parkingCtrl = TextEditingController(); // 직접 입력용
  final TextEditingController _keyCtrl = TextEditingController(); // 직접 입력용
  final TextEditingController _remarksCtrl = TextEditingController();

  bool _isSubmitting = false;

  // 🚀 드롭다운 상태 관리 변수
  String? _selectedParking;
  String? _selectedKey;

  // 🚀 드롭다운 선택지
  final List<String> _parkingOptions = ['S-1 공장동', 'H-1 공장동', '직접 입력'];
  final List<String> _keyOptions = ['차량내', 'H-1 키걸이', '직접 입력'];

  @override
  void dispose() {
    _mileageCtrl.dispose();
    _parkingCtrl.dispose();
    _keyCtrl.dispose();
    _remarksCtrl.dispose();
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
          "운행 종료 및 반납",
          style: TextStyle(
            color: slate900,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 차량 정보 요약
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: pureWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tossBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.car, color: tossBlue),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.vehicle['number'] ?? '-',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: tossBlue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.vehicle['type'] ?? '-',
                            style: const TextStyle(
                              fontSize: 14,
                              color: slate900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 2. 주행거리 입력
              const Text(
                "누적 주행거리 입력",
                style: TextStyle(
                  color: slate900,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _mileageCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: "예: 80500",
                  hintStyle: const TextStyle(color: Colors.black26),
                  suffixText: "km",
                  suffixStyle: const TextStyle(
                    fontSize: 20,
                    color: slate900,
                    fontWeight: FontWeight.bold,
                  ),
                  filled: true,
                  fillColor: pureWhite,
                  contentPadding: const EdgeInsets.all(20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 🚀 3. 다음 사람을 위한 위치 공유 (핵심 UX 포인트)
              const Text(
                "차량 및 차키 보관 위치",
                style: TextStyle(
                  color: slate900,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "다음 사용자가 차를 쉽게 찾을 수 있도록 정확히 적어주세요.",
                style: TextStyle(
                  color: tossBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // 주차 위치 드롭다운
              const Text(
                "주차 위치",
                style: TextStyle(
                  color: slate600,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedParking,
                hint: const Text("주차 위치 선택"),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: slate600,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: pureWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _parkingOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedParking = newValue;
                    if (newValue != '직접 입력') {
                      _parkingCtrl.clear(); // 다른 옵션 선택시 직접 입력 텍스트 초기화
                    }
                  });
                },
              ),
              // 주차 위치 직접 입력 필드 (조건부 렌더링)
              if (_selectedParking == '직접 입력') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _parkingCtrl,
                  decoration: InputDecoration(
                    hintText: "예: B동 1층 자재창고 앞",
                    filled: true,
                    fillColor: pureWhite,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // 차키 보관 장소 드롭다운
              const Text(
                "차키 보관 장소",
                style: TextStyle(
                  color: slate600,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedKey,
                hint: const Text("차키 보관 장소 선택"),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: slate600,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: pureWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _keyOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedKey = newValue;
                    if (newValue != '직접 입력') {
                      _keyCtrl.clear();
                    }
                  });
                },
              ),
              // 차키 위치 직접 입력 필드 (조건부 렌더링)
              if (_selectedKey == '직접 입력') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _keyCtrl,
                  decoration: InputDecoration(
                    hintText: "예: 운전석 햇빛가리개 위, 현장사무실 키박스",
                    filled: true,
                    fillColor: pureWhite,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // 4. 특이사항
              const Text(
                "기타 특이사항 (선택)",
                style: TextStyle(
                  color: slate900,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _remarksCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "주유 필요, 스크래치 발생, 워셔액 부족 등\n다음 사용자와 관리자를 위해 남겨주세요.",
                  hintStyle: const TextStyle(
                    color: Colors.black26,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: pureWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
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
            onPressed: _isSubmitting ? null : _submitReturn,
            style: ElevatedButton.styleFrom(
              backgroundColor: slate900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: pureWhite,
                      strokeWidth: 3,
                    ),
                  )
                : const Text(
                    "반납 완료하기",
                    style: TextStyle(
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

  Future<void> _submitReturn() async {
    HapticFeedback.mediumImpact();

    // 🚀 최종 주차 위치/차키 위치 결정 로직 ('직접 입력'일 경우 TextField 값 사용)
    String finalParking = _selectedParking == '직접 입력'
        ? _parkingCtrl.text.trim()
        : (_selectedParking ?? '');
    String finalKey = _selectedKey == '직접 입력'
        ? _keyCtrl.text.trim()
        : (_selectedKey ?? '');

    // 🚀 유효성 검사 수정 (드롭다운과 텍스트 필드 값 모두 체크)
    if (_mileageCtrl.text.trim().isEmpty ||
        finalParking.isEmpty ||
        finalKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("주행거리, 주차 위치, 차키 위치를 모두 입력해 주세요."),
          backgroundColor: warningRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      int finalMileage = int.parse(_mileageCtrl.text.trim());

      // 🚀 Firestore 업데이트
      await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(widget.vehicle['id'])
          .update({
            'status': '사용 가능',
            'currentUser': null,
            'destination': null,
            'returnTime': null,
            'useType': "단기/일반",
            'currentMileage': finalMileage,
            'parkingLocation': finalParking,
            'keyLocation': finalKey,
          });

      await FirebaseFirestore.instance.collection('vehicle_logs').add({
        'userId': widget.currentUser,
        'type': widget.vehicle['type'],
        'number': widget.vehicle['number'],
        'date':
            "${DateTime.now().year}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().day.toString().padLeft(2, '0')}",
        'time': "반납 완료",
        'finalMileage': finalMileage,
        'parking': finalParking, // 결정된 최종 위치 사용
        'remarks': _remarksCtrl.text.trim(),
        'status': '반납',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("차량 반납이 완료되었습니다. 고생하셨습니다!"),
            backgroundColor: tossBlue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("오류가 발생했습니다. 다시 시도해 주세요.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
