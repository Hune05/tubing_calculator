import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔥 파이어베이스 연동

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileProjectCreatePage extends StatefulWidget {
  const MobileProjectCreatePage({super.key});

  @override
  State<MobileProjectCreatePage> createState() =>
      _MobileProjectCreatePageState();
}

class _MobileProjectCreatePageState extends State<MobileProjectCreatePage> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _designerCtrl = TextEditingController();
  final _qcCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _designerCtrl.dispose();
    _qcCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pureWhite,
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
          "새 프로젝트 생성",
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "프로젝트의 기본 정보와\n주요 담당자를 지정해주세요.",
              style: TextStyle(
                color: slate900,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            _buildInputLabel("프로젝트명 (현장명)"),
            _buildTextField(
              controller: _nameCtrl,
              hint: "예: A동 3층 메인 배관 공사",
              icon: LucideIcons.hardHat,
            ),
            const SizedBox(height: 20),
            _buildInputLabel("프로젝트 코드"),
            _buildTextField(
              controller: _codeCtrl,
              hint: "예: P24-001 (자동채움 가능)",
              icon: LucideIcons.hash,
            ),
            const SizedBox(height: 32),
            const Divider(height: 1, color: tossGrey),
            const SizedBox(height: 32),
            const Row(
              children: [
                Icon(LucideIcons.users, color: tossBlue, size: 20),
                SizedBox(width: 8),
                Text(
                  "핵심 담당자 배정",
                  style: TextStyle(
                    color: slate900,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInputLabel("담당 설계 (엔지니어링)"),
            _buildTextField(
              controller: _designerCtrl,
              hint: "이름 또는 부서 입력",
              icon: LucideIcons.penTool,
            ),
            const SizedBox(height: 8),
            const Text(
              "  * 도면 변경 및 간섭 발생 시 즉시 소통할 담당자입니다.",
              style: TextStyle(color: slate600, fontSize: 12),
            ),
            const SizedBox(height: 20),
            _buildInputLabel("QC / 품질 검사관"),
            _buildTextField(
              controller: _qcCtrl,
              hint: "이름 또는 소속 입력",
              icon: LucideIcons.clipboardCheck,
            ),
            const SizedBox(height: 8),
            const Text(
              "  * 자재 검사 및 최종 펀치(Punch)를 승인할 담당자입니다.",
              style: TextStyle(color: slate600, fontSize: 12),
            ),
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
            onPressed: () async {
              HapticFeedback.mediumImpact();

              if (_nameCtrl.text.isEmpty || _codeCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("프로젝트명과 코드를 입력해주세요.")),
                );
                return;
              }

              // 🔥 파이어베이스에 프로젝트 정보 저장
              await FirebaseFirestore.instance.collection('projects').add({
                'name': _nameCtrl.text.trim(),
                'code': _codeCtrl.text.trim(),
                'stage': '자재 발주', // 초기 상태
                'designer': _designerCtrl.text.trim(),
                'qc': _qcCtrl.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
              });

              if (context.mounted) {
                Navigator.pop(context); // 목록으로 돌아가기
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("신규 프로젝트가 생성되었습니다."),
                    backgroundColor: slate900,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: tossBlue,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              "프로젝트 개설하기",
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

  Widget _buildInputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: slate900,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: slate600, size: 20),
        hintText: hint,
        hintStyle: const TextStyle(
          color: Colors.black26,
          fontWeight: FontWeight.normal,
        ),
        filled: true,
        fillColor: tossGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
