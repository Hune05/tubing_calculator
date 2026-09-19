import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
// 🚀 사용자님의 모바일 자재 관리 페이지를 임포트합니다!
import 'mobile_inventory_page.dart';

class MobileInventoryLoginScreen extends StatefulWidget {
  const MobileInventoryLoginScreen({super.key});

  @override
  State<MobileInventoryLoginScreen> createState() =>
      _MobileInventoryLoginScreenState();
}

class _MobileInventoryLoginScreenState
    extends State<MobileInventoryLoginScreen> {
  // 🚀 최고 관리자(마스터) 이메일 (DB 등록 여부와 상관없이 무조건 프리패스)
  final String _masterEmail = "a01020020271@gmail.com";

  @override
  void initState() {
    super.initState();
    _verifyGoogleAdmin();
  }

  Future<void> _verifyGoogleAdmin() async {
    await Future.delayed(const Duration(milliseconds: 1000));

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(
        serverClientId:
            '289974993415-lhibiid49ncmb5hev53hnasj7vhkvki3.apps.googleusercontent.com',
      );

      final GoogleSignInAccount? user = await googleSignIn
          .attemptLightweightAuthentication();

      if (!mounted) return;

      if (user != null) {
        // 🚀 [정리] 여러 사람이 쓰는 걸 상정해서 Firestore 'admins' 목록에
        // 등록된 다른 이메일도 통과시키던 로직을 제거했다. 개인용으로는
        // 본인 계정 하나만 통과하면 되고, 다른 이메일을 관리자로 추가하는
        // 화면(mobile_admin_management_page.dart)도 함께 삭제했다.
        if (user.email == _masterEmail) {
          // ✨ 권한 통과! 모바일 마스터 페이지로 이동하면서 닉네임을 넘겨줌
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  MobileInventoryPage(workerName: user.displayName ?? "관리자"),
            ),
          );
        } else {
          // ❌ 본인 계정이 아님! 접근 거부
          _showErrorAndPop("⚠️ 본인 계정으로 로그인해 주십시오.");
        }
      } else {
        _showErrorAndPop("로그인 정보를 찾을 수 없습니다.");
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorAndPop("인증 오류가 발생했습니다: $e");
    }
  }

  void _showErrorAndPop(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context); // 권한이 없으면 이전 메뉴로 튕겨냅니다.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.admin_panel_settings,
              size: 80,
              color: Color(0xFF007580),
            ),
            const SizedBox(height: 24),
            const Text(
              "관리자 권한 확인 중...",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: Color(0xFF007580)),
            const SizedBox(height: 24),
            Text(
              "본인 계정인지 확인하고 있습니다.",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
