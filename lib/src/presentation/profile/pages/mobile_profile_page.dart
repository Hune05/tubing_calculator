import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'mobile_profile_edit_page.dart';
import 'package:tubing_calculator/src/presentation/menu/page/mobile_loading_screen.dart';
import 'package:tubing_calculator/src/presentation/menu/page/mobile_menu_page.dart'; // 🔥 메인 메뉴 화면 import 추가

const Color tossBlue = Color(0xFF3182F6);
const Color slate900 = Color(0xFF191F28);
const Color slate800 = Color(0xFF333D4B);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color red500 = Color(0xFFF04452);

class MobileProfilePage extends StatefulWidget {
  final String currentWorker;

  const MobileProfilePage({super.key, required this.currentWorker});

  @override
  State<MobileProfilePage> createState() => _MobileProfilePageState();
}

class _MobileProfilePageState extends State<MobileProfilePage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isLoggingIn = false;

  // 🚀 화면에서 즉시 변경된 이름을 보여주기 위한 로컬 상태 변수
  late String _displayName;

  @override
  void initState() {
    super.initState();
    // 초기에는 이전 화면에서 전달받은 이름을 세팅합니다.
    _displayName = widget.currentWorker;
  }

  // 🚀 로그인 완료 및 아이디 변경 시 기기에 이름 저장
  Future<void> _saveUserData(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_real_name', name);
  }

  // 🚀 공통 FCM 토큰 저장 함수 추가
  Future<void> _saveUserToken(String userName) async {
    if (userName.isEmpty || userName == "로그인 필요") return;
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(userName).set({
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("🚨 FCM 토큰 저장 에러: $e");
    }
  }

  // 🚀 구글 로그인 처리
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoggingIn = true);
    try {
      await _googleSignIn.initialize(
        serverClientId:
            '289974993415-lhibiid49ncmb5hev53hnasj7vhkvki3.apps.googleusercontent.com',
      );
      final GoogleSignInAccount? account = await _googleSignIn.authenticate();

      if (account != null) {
        final GoogleSignInAuthentication googleAuth =
            await account.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);

        if (!mounted) return;
        await _showNameConfirmDialog(account.displayName ?? "");
      }
    } catch (error) {
      debugPrint("🚨 구글 로그인 에러: $error");
      if (mounted) {
        _showSnackBar("로그인에 실패했습니다. 오프라인 모드를 사용해주세요.", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  // 🚀 실명 입력 다이얼로그 (오프라인 & 구글 로그인 공통 사용 - 초기 설정용)
  Future<void> _showNameConfirmDialog([String initialName = ""]) async {
    TextEditingController nameCtrl = TextEditingController(text: initialName);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "작업자 실명 입력",
            style: TextStyle(fontWeight: FontWeight.bold, color: slate900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "현장에서 사용할 정확한 본인 실명(또는 직급)을 입력해주세요.",
                style: TextStyle(fontSize: 14, color: slate600, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                cursorColor: tossBlue,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: slate100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: tossBlue, width: 2),
                  ),
                  hintText: "예: 홍길동 (또는 김반장)",
                  prefixIcon: const Icon(LucideIcons.user, color: tossBlue),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소", style: TextStyle(color: slate600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: tossBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                String realName = nameCtrl.text.trim();
                if (realName.isNotEmpty) {
                  await _saveUserData(realName);
                  await _saveUserToken(realName);

                  if (context.mounted) {
                    Navigator.pop(context); // 팝업 닫기
                    _showSnackBar("환영합니다, $realName님!");
                    // 로그인 완료 후 화면 새로고침을 위해 로딩스크린(또는 메인)으로 강제 이동
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MobileLoadingScreen(),
                      ),
                      (route) => false,
                    );
                  }
                } else {
                  _showSnackBar("이름을 입력해주세요.", isError: true);
                }
              },
              child: const Text(
                "확인 및 시작",
                style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // 🚀 프로필에서 즉시 아이디(이름)를 변경하는 다이얼로그
  Future<void> _showEditAppIdDialog() async {
    TextEditingController idCtrl = TextEditingController(text: _displayName);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "앱 아이디 변경",
            style: TextStyle(fontWeight: FontWeight.bold, color: slate900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "앱에서 사용할 새로운 아이디나 직급을 입력해주세요.",
                style: TextStyle(fontSize: 14, color: slate600, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: idCtrl,
                cursorColor: tossBlue,
                autofocus: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: slate100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: tossBlue, width: 2),
                  ),
                  hintText: "새로운 아이디 입력",
                  prefixIcon: const Icon(LucideIcons.edit2, color: tossBlue),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소", style: TextStyle(color: slate600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: tossBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                String newId = idCtrl.text.trim();
                if (newId.isNotEmpty) {
                  try {
                    // 1. Firebase Auth 서버에 새 이름 업데이트 🌟
                    if (FirebaseAuth.instance.currentUser != null) {
                      await FirebaseAuth.instance.currentUser!
                          .updateDisplayName(newId);
                    }

                    // 2. 스마트폰 로컬 저장소 업데이트
                    await _saveUserData(newId);

                    // 3. 이름이 바뀌었으니 토큰도 새 이름 문서에 저장
                    await _saveUserToken(newId);

                    // 4. 화면 즉시 업데이트
                    setState(() {
                      _displayName = newId;
                    });

                    if (context.mounted) {
                      Navigator.pop(context);
                      _showSnackBar("아이디가 '$newId'(으)로 변경되었습니다.");
                    }
                  } catch (e) {
                    debugPrint("Firebase 이름 업데이트 실패: $e");
                    if (context.mounted) {
                      _showSnackBar("서버 업데이트에 실패했습니다.", isError: true);
                    }
                  }
                } else {
                  _showSnackBar("아이디를 입력해주세요.", isError: true);
                }
              },
              child: const Text(
                "적용",
                style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isError ? red500 : slate900,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isGuest = _displayName.isEmpty || _displayName == "로그인 필요";

    return Scaffold(
      backgroundColor: slate100,
      appBar: AppBar(
        backgroundColor: slate100,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slate900),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // 🌟 내 정보 (또는 로그인 유도) 카드 영역
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: pureWhite,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: slate100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isGuest ? LucideIcons.userX : LucideIcons.user,
                        size: 40,
                        color: isGuest
                            ? slate600.withValues(alpha: 0.5)
                            : tossBlue,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 💡 아이디 표시 및 변경 버튼 영역
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            isGuest ? "로그인이 필요합니다" : _displayName,
                            style: TextStyle(
                              color: isGuest ? slate600 : slate900,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isGuest) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _showEditAppIdDialog();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                LucideIcons.pencil,
                                size: 20,
                                color: slate600.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),
                    Text(
                      isGuest ? "현장 관리 기능을 100% 활용해보세요" : "현장 작업자",
                      style: const TextStyle(
                        color: slate600,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    // 🚀 비로그인 상태일 때만 로그인 버튼들 표시
                    if (isGuest) ...[
                      const SizedBox(height: 24),
                      if (_isLoggingIn)
                        const CircularProgressIndicator(color: tossBlue)
                      else ...[
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _handleGoogleSignIn();
                            },
                            icon: const Icon(
                              LucideIcons.chrome,
                              color: pureWhite,
                              size: 20,
                            ),
                            label: const Text(
                              "Google 계정으로 시작",
                              style: TextStyle(
                                color: pureWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tossBlue,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _showNameConfirmDialog(); // 오프라인 실명 입력 모드
                            },
                            icon: const Icon(
                              LucideIcons.wifiOff,
                              color: slate600,
                              size: 20,
                            ),
                            label: const Text(
                              "오프라인 모드 (이름만 입력)",
                              style: TextStyle(
                                color: slate600,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.black12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // 🌟 메뉴 리스트 영역 (로그인 상태일 때만 표시)
              if (!isGuest)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: pureWhite,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      _buildProfileMenuItem(
                        title: "상세 프로필 설정",
                        icon: LucideIcons.settings,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MobileProfileEditPage(
                                initialName: _displayName,
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(
                        height: 1,
                        color: slate100,
                        indent: 24,
                        endIndent: 24,
                      ),
                      _buildProfileMenuItem(
                        title: "로그아웃",
                        icon: LucideIcons.logOut,
                        titleColor: red500,
                        iconColor: red500,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showLogoutDialog(context);
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileMenuItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color titleColor = slate800,
    Color iconColor = slate600,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
            Icon(icon, size: 24, color: iconColor),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: slate600.withValues(alpha: 0.5),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: pureWhite,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "로그아웃 하시겠습니까?",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: slate900,
              letterSpacing: -0.5,
            ),
          ),
          content: const Text(
            "안전한 작업을 위해\n작업이 끝났다면 로그아웃 해주세요.",
            style: TextStyle(fontSize: 15, color: slate600, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: slate100,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "취소",
                      style: TextStyle(
                        color: slate600,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();

                      // 🔥 1. 구글 완전 연결 해제 (자동 로그인 방지)
                      try {
                        await _googleSignIn.signOut();
                        await _googleSignIn.disconnect();
                      } catch (e) {
                        debugPrint("구글 연결 해제 패스: $e");
                      }

                      // 🔥 2. 파이어베이스 및 기기 저장소 초기화
                      await FirebaseAuth.instance.signOut();
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('user_real_name');

                      // 🔥 3. 로딩 화면이 아닌 메인 메뉴(게스트)로 직행
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const MobileMenuPage(currentWorker: "로그인 필요"),
                          ),
                          (route) => false,
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: red500,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "로그아웃",
                      style: TextStyle(
                        color: pureWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
