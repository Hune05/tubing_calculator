import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tubing_calculator/src/core/utils/settings_cloud.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔥 추가됨
import 'package:firebase_messaging/firebase_messaging.dart'; // 🔥 추가됨
import 'package:tubing_calculator/src/presentation/menu/page/home_menu_router.dart';

class MobileLoadingScreen extends StatefulWidget {
  const MobileLoadingScreen({super.key});

  @override
  State<MobileLoadingScreen> createState() => _MobileLoadingScreenState();
}

class _MobileLoadingScreenState extends State<MobileLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  // 설치된 앱 버전(pubspec). 예전엔 "v2.0"이라 글자로 박혀 있어 실제 버전과 달랐다.
  String _version = '';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    PackageInfo.fromPlatform()
        .then((p) {
          if (mounted) setState(() => _version = p.version);
        })
        .catchError((_) {});

    // 🔥 앱 켜지자마자 바로 로그인 상태 체크 시작
    _checkLoginStatusAndRoute();

    // 🚀 [통신 없는 현장] 발전소처럼 통신이 안 되는 곳에서는 토큰 저장·구글 로그인이
    // 응답 없이 오래 걸려서 이 화면에 갇혔다. 어떤 이유로든 8초 안에 못 넘어가면
    // 저장된 이름(없으면 게스트)으로 그냥 들어간다.
    Future.delayed(const Duration(seconds: 8), () => _goOnce(_fallbackName));

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
      String? token = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
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

  // 이 화면을 떠나는 길은 하나뿐이게 한다(안전망과 겹쳐 두 번 넘어가지 않게).
  bool _routed = false;
  String _fallbackName = "로그인 필요";

  void _goOnce(String name) {
    if (_routed || !mounted) return;
    _routed = true;
    _navigateToMainMenu(name);
  }

  Future<void> _checkLoginStatusAndRoute() async {
    try {
      // 1. 스플래시 화면(로고)을 최소 1.5초간 보여주기 위함
      await Future.delayed(const Duration(milliseconds: 1500));

      // 2. 기기에 저장된 오프라인 이름이 있는지 최우선 확인
      final prefs = await SharedPreferences.getInstance();
      String? savedName = prefs.getString('user_real_name');

      if (savedName != null && savedName.isNotEmpty) {
        _fallbackName = savedName;
        // 🚀 토큰 저장은 통신이 필요하다. 기다리면 통신 없는 현장에서 앱이 안 열리므로
        // 화면을 먼저 넘기고 토큰은 뒤에서 올린다(통신되면 알아서 올라간다).
        _goOnce(savedName);
        _saveUserToken(savedName);
        return;
      }

      // 3. 저장된 이름이 없다면 구글 '자동 로그인(Silent)'만 시도
      await _googleSignIn.initialize(
        serverClientId:
            '289974993415-lhibiid49ncmb5hev53hnasj7vhkvki3.apps.googleusercontent.com',
      );

      // 통신이 없으면 응답이 오지 않으므로 오래 기다리지 않는다.
      final GoogleSignInAccount? account = await (_googleSignIn
          .attemptLightweightAuthentication()
          ?.timeout(const Duration(seconds: 5), onTimeout: () => null));

      if (account != null) {
        final GoogleSignInAuthentication googleAuth = account.authentication;

        final OAuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);

        // 새로 깔아서 폰에 설정이 없으면 서버에 올려 둔 설정을 받는다
        // (통신이 없으면 5초만 기다리고 넘어간다).
        await SettingsCloudSync.instance.restore();

        String name = account.displayName ?? "작업자";
        await prefs.setString('user_real_name', name);

        await _saveUserToken(name); // 🔥 구글 자동 로그인 성공 시 토큰 갱신

        _goOnce(name);
      } else {
        // 4. 정보가 아무것도 없으면? => 가두지 않고 '게스트'로 메인화면 통과!
        _goOnce(_fallbackName);
      }
    } catch (e) {
      debugPrint("🚨 자동 로그인 체크 에러: $e");
      // 에러가 나더라도 무한 로딩에 빠지지 않도록 저장된 이름(없으면 게스트)으로 넘깁니다.
      _goOnce(_fallbackName);
    }
  }

  // 🚀 메인 메뉴(껍데기 화면)로 이동하는 함수
  void _navigateToMainMenu(String userName) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        // 🚀 [수정] 폴더블 대응: 화면 크기를 실시간으로 반영하는
        // HomeMenuRouter를 거치도록 해서, 접힌 채로 앱을 켰다가 펼쳐도
        // (혹은 그 반대도) 그 순간의 화면에 맞는 홈 화면으로 즉시 전환된다.
        pageBuilder: (context, animation, secondaryAnimation) => HomeMenuRouter(
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
            Text(
              _version.isEmpty ? "모바일 현장 지원 시스템" : "모바일 현장 지원 시스템 v$_version",
              style: const TextStyle(color: Colors.grey, fontSize: 16),
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
