import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔥 추가됨
import 'package:firebase_messaging/firebase_messaging.dart'; // 🔥 추가됨
import 'package:tubing_calculator/src/presentation/menu/page/mobile_menu_page.dart';

class MobileLoadingScreen extends StatefulWidget {
  const MobileLoadingScreen({super.key});

  @override
  State<MobileLoadingScreen> createState() => _MobileLoadingScreenState();
}

class _MobileLoadingScreenState extends State<MobileLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    // 🔥 앱 켜지자마자 바로 로그인 상태 체크 시작
    _checkLoginStatusAndRoute();

    // 🔥 토큰이 앱 사용 중 자동으로 갱신될 때를 대비한 리스너
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final prefs = await SharedPreferences.getInstance();
      String? savedName = prefs.getString('user_real_name');
      if (savedName != null && savedName.isNotEmpty && savedName != "로그인 필요") {
        await FirebaseFirestore.instance.collection('users').doc(savedName).set(
          {'fcmToken': newToken, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      }
    });
  }

  // 🚀 공통 FCM 토큰 저장 함수 추가
  Future<void> _saveUserToken(String userName) async {
    if (userName == "로그인 필요") return;
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(userName).set({
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint("✅ FCM 토큰 업데이트 완료: $userName");
      }
    } catch (e) {
      debugPrint("🚨 FCM 토큰 저장 에러: $e");
    }
  }

  Future<void> _checkLoginStatusAndRoute() async {
    try {
      // 1. 스플래시 화면(로고)을 최소 1.5초간 보여주기 위함
      await Future.delayed(const Duration(milliseconds: 1500));

      // 2. 기기에 저장된 오프라인 이름이 있는지 최우선 확인
      final prefs = await SharedPreferences.getInstance();
      String? savedName = prefs.getString('user_real_name');

      if (savedName != null && savedName.isNotEmpty) {
        await _saveUserToken(savedName); // 🔥 자동 로그인 성공 시 토큰 갱신
        if (mounted) _navigateToMainMenu(savedName);
        return;
      }

      // 3. 저장된 이름이 없다면 구글 '자동 로그인(Silent)'만 시도
      await _googleSignIn.initialize(
        serverClientId:
            '289974993415-lhibiid49ncmb5hev53hnasj7vhkvki3.apps.googleusercontent.com',
      );

      final GoogleSignInAccount? account = await _googleSignIn
          .attemptLightweightAuthentication();

      if (account != null) {
        final GoogleSignInAuthentication googleAuth = account.authentication;

        final OAuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);

        String name = account.displayName ?? "작업자";
        await prefs.setString('user_real_name', name);

        await _saveUserToken(name); // 🔥 구글 자동 로그인 성공 시 토큰 갱신

        if (mounted) _navigateToMainMenu(name);
      } else {
        // 4. 정보가 아무것도 없으면? => 가두지 않고 '게스트'로 메인화면 통과!
        if (mounted) _navigateToMainMenu("로그인 필요");
      }
    } catch (e) {
      debugPrint("🚨 자동 로그인 체크 에러: $e");
      // 에러가 나더라도 무한 로딩에 빠지지 않도록 게스트로 넘깁니다.
      if (mounted) _navigateToMainMenu("로그인 필요");
    }
  }

  // 🚀 메인 메뉴(껍데기 화면)로 이동하는 함수
  void _navigateToMainMenu(String userName) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MobileMenuPage(
          currentWorker: userName,
        ), // 🔥 전달받은 이름 또는 "로그인 필요" 전달
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2124),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF007580).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.engineering,
                size: 80,
                color: Color(0xFF007580),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "FIELD HELPER",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "모바일 현장 지원 시스템 v2.0",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 100),

            // 깜빡거리는 로딩 텍스트
            FadeTransition(
              opacity: _animController,
              child: const Text(
                "SYSTEM LOADING...",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF007580),
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
