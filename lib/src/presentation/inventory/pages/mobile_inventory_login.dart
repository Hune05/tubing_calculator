import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../approval/member_approval.dart' show kAdminEmail;
import '../../profile/google_link.dart' show ensureGoogleSignInReady;
// 🚀 사용자님의 모바일 자재 관리 페이지를 임포트합니다!
import 'mobile_inventory_page.dart';

class MobileInventoryLoginScreen extends StatefulWidget {
  const MobileInventoryLoginScreen({super.key});

  @override
  State<MobileInventoryLoginScreen> createState() =>
      _MobileInventoryLoginScreenState();
}

// 한 번 본인 계정으로 확인된 폰이라는 표시. 발전소처럼 통신이 없는 곳에서는
// 구글에 물어볼 수 없으므로, 전에 확인된 폰이면 그대로 들여보낸다.
const String kInventoryAdminOkPrefsKey = 'inventory_admin_ok_v1';
// 확인된 구글 계정 이름(통신 없을 때 자재 기록에 적을 이름).
const String kInventoryAdminNamePrefsKey = 'inventory_admin_name_v1';

/// 본인 계정으로 확인된 폰이라고 적어 둔다.
/// 10-09: 예전에는 앱 전체가 쓰는 사용자 이름(user_real_name)을 구글 표시 이름으로 덮어써서,
/// 프로필에서 이름을 바꾼 사람이 자재 관리를 한 번 열면 다음에 켤 때 옛 이름으로 돌아가
/// 일정·프로필이 안 보였다. 이제 자재 관리용 칸에만 적는다.
Future<void> rememberInventoryAdmin(SharedPreferences prefs, String? displayName) async {
  await prefs.setBool(kInventoryAdminOkPrefsKey, true);
  await prefs.setString(kInventoryAdminNamePrefsKey, displayName ?? "관리자");
}

/// 통신이 없을 때 자재 기록에 적을 이름.
String inventoryAdminOfflineName(SharedPreferences? prefs) =>
    prefs?.getString(kInventoryAdminNamePrefsKey) ??
    prefs?.getString('user_real_name') ??
    "관리자";

class _MobileInventoryLoginScreenState
    extends State<MobileInventoryLoginScreen> {
  @override
  void initState() {
    super.initState();
    _verifyGoogleAdmin();
  }

  Future<void> _verifyGoogleAdmin() async {
    await Future.delayed(const Duration(milliseconds: 400));

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      await ensureGoogleSignInReady();

      // 통신이 없으면 응답이 오지 않는다. 오래 기다리지 않고 넘어간다.
      // (예전에는 여기서 "관리자 권한 확인 중…" 화면에 갇혀 있었다.)
      final GoogleSignInAccount? user = await (googleSignIn
          .attemptLightweightAuthentication()
          ?.timeout(const Duration(seconds: 5), onTimeout: () => null));

      if (!mounted) return;

      if (user == null) {
        _enterWithoutCheck(prefs, "통신이 없어 계정을 확인하지 못했습니다.");
        return;
      }

      // 🚀 [정리] 여러 사람이 쓰는 걸 상정해서 Firestore 'admins' 목록에
      // 등록된 다른 이메일도 통과시키던 로직을 제거했다. 개인용으로는
      // 본인 계정 하나만 통과하면 되고, 다른 이메일을 관리자로 추가하는
      // 화면(mobile_admin_management_page.dart)도 함께 삭제했다.
      if (user.email == kAdminEmail) {
        // 다음번에 통신이 없어도 들어올 수 있게, 확인된 폰이라고 적어 둔다.
        try {
          if (prefs != null) await rememberInventoryAdmin(prefs, user.displayName);
        } catch (_) {}
        if (!mounted) return;
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
        _showErrorAndPop("본인 계정으로 로그인하십시오.");
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint("자재 관리 권한 확인 실패: $e");
      _enterWithoutCheck(prefs, "계정을 확인하지 못했습니다.");
    }
  }

  // 구글에 물어보지 못했을 때. 전에 본인 계정으로 확인된 폰이면 그대로 들여보내고,
  // 처음 쓰는 폰이면 통신이 될 때 다시 들어오라고 알려 준다.
  void _enterWithoutCheck(SharedPreferences? prefs, String why) {
    final ok = prefs?.getBool(kInventoryAdminOkPrefsKey) == true;
    if (!ok) {
      _showErrorAndPop("$why 통신되는 곳에서 한 번 여십시오.");
      return;
    }
    final name = inventoryAdminOfflineName(prefs);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MobileInventoryPage(workerName: name),
      ),
    );
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
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.admin_panel_settings,
              size: 80,
              color: AppColors.brand,
            ),
            const SizedBox(height: 24),
            const Text(
              "관리자 권한 확인 중...",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: AppColors.brand),
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
