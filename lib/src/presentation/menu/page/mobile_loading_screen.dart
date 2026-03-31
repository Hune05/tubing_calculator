import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🚀 오프라인 저장을 위한 패키지
import 'package:tubing_calculator/src/presentation/menu/page/mobile_menu_page.dart';

class MobileLoadingScreen extends StatefulWidget {
  const MobileLoadingScreen({super.key});

  @override
  State<MobileLoadingScreen> createState() => _MobileLoadingScreenState();
}

class _MobileLoadingScreenState extends State<MobileLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  // 🚀 구글 로그인 인스턴스 (v7.0)
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

  // 💾 기기에 실명 정보 저장
  Future<void> _saveUserData(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_real_name', name);
  }

  // 💾 기기에서 실명 정보 불러오기
  Future<String?> _getSavedName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_real_name');
  }

  // 🚀 앱 시작 시 로그인 상태 확인 (오프라인/온라인 모두 대응)
  Future<void> _checkLoginStatus() async {
    try {
      await _googleSignIn.initialize(
        serverClientId:
            '289974993415-lhibiid49ncmb5hev53hnasj7vhkvki3.apps.googleusercontent.com',
      );

      // 1. 구글 서버에 자동 로그인 시도
      final GoogleSignInAccount? account = await _googleSignIn
          .attemptLightweightAuthentication();
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;

      if (account != null) {
        // ✨ [온라인 상태] 구글 로그인 성공
        String? savedName = await _getSavedName();
        if (savedName != null) {
          // 기기에 저장된 이름이 있으면 팝업 없이 패스
          _navigateToMainMenu(savedName);
        } else {
          // 저장된 이름이 없으면 최초 1회 실명 팝업 호출
          await _showNameConfirmDialog(account);
        }
      } else {
        // 구글 로그인 정보가 아예 없음 (로그아웃 상태)
        setState(() => _isLoading = false);
      }
    } catch (e) {
      // 🚨 [오프라인 상태 / 통신 에러 발생 시] 🚨
      if (!mounted) return;

      String? savedName = await _getSavedName();
      if (savedName != null) {
        // 인터넷은 끊겼지만, 기기에 저장된 이름이 있다면 지하(오프라인)로 간주하고 통과!
        _showOfflineLoginSnackBar();
        _navigateToMainMenu(savedName);
      } else {
        // 인터넷도 안 되고 로그인 기록도 없으면 수동 로그인 창으로
        setState(() => _isLoading = false);
        _showErrorSnackBar("네트워크 연결을 확인해주세요. (최초 1회 로그인은 인터넷 연결 필요)");
      }
    }
  }

  // 🚀 사용자가 탭해서 수동 로그인 시도
  Future<void> _handleManualSignIn() async {
    try {
      final GoogleSignInAccount account = await _googleSignIn.authenticate();

      if (!mounted) return;
      await _showNameConfirmDialog(account);
    } catch (error) {
      // 🚨 지하에서 버튼을 눌렀을 때의 대비책
      if (!mounted) return;
      String? savedName = await _getSavedName();
      if (savedName != null) {
        _showOfflineLoginSnackBar();
        _navigateToMainMenu(savedName);
      } else {
        _showErrorSnackBar("인터넷 연결이 필요합니다.");
      }
    }
  }

  // 알림창 기능들
  void _showOfflineLoginSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "📡 오프라인 모드로 접속했습니다. (기존 정보 사용)",
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

  // 🚀 예쁜 실명 확인 팝업창 (UI 복구)
  Future<void> _showNameConfirmDialog(GoogleSignInAccount account) async {
    TextEditingController nameController = TextEditingController(
      text: account.displayName ?? "",
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
            "작업자 실명 확인",
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
                    await _saveUserData(realName); // 기기에 저장
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
                  await _saveUserData(realName); // 🚀 기기에 저장!
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
                    "- TAP TO LOGIN WITH GOOGLE -",
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
