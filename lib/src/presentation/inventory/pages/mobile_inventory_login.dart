import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'mobile_inventory_page.dart'; // 메인 페이지 임포트

class MobileInventoryLoginScreen extends StatefulWidget {
  const MobileInventoryLoginScreen({super.key});

  @override
  State<MobileInventoryLoginScreen> createState() =>
      _MobileInventoryLoginScreenState();
}

class _MobileInventoryLoginScreenState
    extends State<MobileInventoryLoginScreen> {
  // 🚀 작업자 명단 및 고유 PIN 번호 세팅 (나중에 실제 인원으로 수정)
  final List<Map<String, String>> _workers = [
    {"name": "차재훈 과장", "pin": "0526"},
    {"name": "이대리", "pin": "1111"},
    {"name": "박주임", "pin": "2222"},
    {"name": "관리자", "pin": "0000"},
  ];

  String? _selectedWorker;
  String _enteredPin = "";

  void _onKeyPress(String value) {
    if (_selectedWorker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("먼저 작업자 이름을 선택해주세요."),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    if (_enteredPin.length < 4) {
      setState(() => _enteredPin += value);
    }

    // 4자리가 다 입력되었을 때 자동 검사
    if (_enteredPin.length == 4) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    if (_enteredPin.isNotEmpty) {
      setState(
        () => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1),
      );
    }
  }

  void _verifyPin() {
    var worker = _workers.firstWhere((w) => w['name'] == _selectedWorker);
    if (worker['pin'] == _enteredPin) {
      // 🚀 PIN 일치: 메인 페이지로 이동하면서 이름(workerName)을 넘겨줌
      HapticFeedback.heavyImpact();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              MobileInventoryPage(workerName: _selectedWorker!),
        ),
      );
    } else {
      // PIN 불일치: 초기화 및 에러 메시지
      HapticFeedback.vibrate();
      setState(() => _enteredPin = "");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "비밀번호가 틀렸습니다. 다시 입력해주세요.",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.lock_person, size: 60, color: Color(0xFF007580)),
            const SizedBox(height: 16),
            const Text(
              "현장 자재 관리 시스템",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const Text(
              "작업자 본인 인증",
              style: TextStyle(fontSize: 16, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 30),

            // 🚀 작업자 선택 버튼들
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: _workers.map((w) {
                bool isSelected = _selectedWorker == w['name'];
                return ChoiceChip(
                  label: Text(
                    w['name']!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF007580),
                  backgroundColor: Colors.white,
                  onSelected: (selected) {
                    setState(() {
                      _selectedWorker = w['name'];
                      _enteredPin = ""; // 사람 바꾸면 PIN 초기화
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 40),

            // 🚀 PIN 번호 입력 표시창 (● ● ● ●)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: index < _enteredPin.length
                        ? const Color(0xFF007580)
                        : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
            const Spacer(),

            // 🚀 숫자 키패드
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 15,
                crossAxisSpacing: 15,
                childAspectRatio: 1.5,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (int i = 1; i <= 9; i++) _buildKey(i.toString()),
                  const SizedBox.shrink(), // 빈칸
                  _buildKey("0"),
                  InkWell(
                    onTap: _onBackspace,
                    child: const Center(
                      child: Icon(
                        Icons.backspace,
                        size: 28,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String value) {
    return InkWell(
      onTap: () => _onKeyPress(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }
}
