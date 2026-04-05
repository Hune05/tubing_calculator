import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _checkLoginStatus();
  }

  Future<void> _saveUserData(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_real_name', name);
  }

  Future<String?> _getSavedName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_real_name');
  }

  Future<void> _checkLoginStatus() async {
    try {
      await _googleSignIn.initialize(
        serverClientId:
            '289974993415-lhibiid49ncmb5hev53hnasj7vhkvki3.apps.googleusercontent.com',
      );

      final GoogleSignInAccount? account = await _googleSignIn
          .attemptLightweightAuthentication();
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;

      if (account != null) {
        final GoogleSignInAuthentication googleAuth =
            await account.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);

        String? savedName = await _getSavedName();
        if (savedName != null) {
          _navigateToMainMenu(savedName);
        } else {
          await _showNameConfirmDialog(account);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("🚨 자동 로그인 에러: $e");
      if (!mounted) return;

      String? savedName = await _getSavedName();
      if (savedName != null) {
        _showOfflineLoginSnackBar();
        _navigateToMainMenu(savedName);
      } else {
        // 🔥 [해결] 에러 나도 막지 않고 로딩 풀어서 수동 버튼 누를 수 있게 함
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleManualSignIn() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.authenticate();

      if (account != null) {
        final GoogleSignInAuthentication googleAuth =
            await account.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);

        if (!mounted) return;
        await _showNameConfirmDialog(account);
      }
    } catch (error) {
      print("🚨 수동 로그인 에러: $error");
      if (!mounted) return;

      String? savedName = await _getSavedName();
      if (savedName != null) {
        _showOfflineLoginSnackBar();
        _navigateToMainMenu(savedName);
      } else {
        // 🔥 [해결] 로그인 실패하고 저장된 이름도 없을 때, 튕겨내지 않고 억지로 이름 입력창을 띄움!!!
        _showErrorSnackBar("구글 로그인 실패: 오프라인 모드로 강제 진입합니다.");
        await _showNameConfirmDialog(null); // account 없이 다이얼로그 호출
      }
    }
  }

  void _showOfflineLoginSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "📡 오프라인 모드로 접속했습니다.",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade600),
    );
  }

  // 🚀 [해결] account가 null(로그인 실패)이어도 무조건 창이 뜨도록 수정
  Future<void> _showNameConfirmDialog(GoogleSignInAccount? account) async {
    TextEditingController nameController = TextEditingController(
      text: account?.displayName ?? "",
    );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "작업자 실명 입력 (오프라인 가능)",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "현장에서 사용할 정확한 본인 실명을 입력해주세요.",
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF007580), width: 2),
                  ),
                  labelText: "이름",
                  labelStyle: TextStyle(color: Color(0xFF007580)),
                  hintText: "예: 홍길동",
                  prefixIcon: Icon(Icons.person, color: Color(0xFF007580)),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (value) async {
                  String realName = value.trim();
                  if (realName.isNotEmpty) {
                    await _saveUserData(realName);
                    if (context.mounted) {
                      Navigator.pop(context);
                      _navigateToMainMenu(realName);
                    }
                  }
                },
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007580),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onPressed: () async {
                String realName = nameController.text.trim();
                if (realName.isNotEmpty) {
                  await _saveUserData(realName);
                  if (context.mounted) {
                    Navigator.pop(context);
                    _navigateToMainMenu(realName);
                  }
                } else {
                  _showErrorSnackBar("이름을 입력해주세요.");
                }
              },
              child: const Text(
                "확인 및 시작",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToMainMenu(String userName) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MobileMenuPage(currentWorker: userName),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
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
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_isLoading) {
            _handleManualSignIn();
          }
        },
        child: Center(
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

              if (_isLoading)
                const CircularProgressIndicator(color: Color(0xFF007580))
              else
                FadeTransition(
                  opacity: _animController,
                  child: const Text(
                    "- TAP TO START -",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF007580),
                      letterSpacing: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
