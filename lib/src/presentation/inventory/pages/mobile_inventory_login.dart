import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
        bool hasPermission = false;

        // 1. 최고 관리자인지 확인 (프리패스)
        if (user.email == _masterEmail) {
          hasPermission = true;
        } else {
          // 2. Firebase DB 'admins' 컬렉션에 등록된 이메일인지 검사
          final doc = await FirebaseFirestore.instance
              .collection('admins')
              .doc(user.email)
              .get();

          if (doc.exists) {
            hasPermission = true;
          }
        }

        if (hasPermission) {
          // ✨ 권한 통과! 모바일 마스터 페이지로 이동하면서 닉네임을 넘겨줌
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  MobileInventoryPage(workerName: user.displayName ?? "관리자"),
            ),
          );
        } else {
          // ❌ 권한 없음! 접근 거부
          _showErrorAndPop("⚠️ 관리자 권한이 없습니다. 최고 관리자에게 승인을 요청하세요.");
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
              "DB에서 승인 여부를 조회하고 있습니다.",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
