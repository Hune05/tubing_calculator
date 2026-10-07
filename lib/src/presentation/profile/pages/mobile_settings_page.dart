// 설정: 계산기 설정 서버 보관·구글 계정 연결, 알림 점검, 백업·저장 공간, 로그아웃, 버전.
//
// 예전엔 이게 다 "내 프로필" 화면에 섞여 있었다(신원과 앱 설정이 한 화면). 2026-09-28
// 헤더 점 3개를 "내 프로필 / 설정 / 빠른 실행 편집"으로 나누며 앱 설정만 이리로 옮겼다.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/app_icon_set.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/settings_cloud.dart';
import '../../../data/repositories/work_project_repository.dart';
import '../../menu/page/mobile_menu_page.dart';
import '../../my_work_logs/pages/notification_check_page.dart';
import '../../my_work_logs/pages/storage_management_page.dart';
import '../profile_tools.dart';
import '../widgets/profile_menu_widgets.dart';
import '../widgets/settings_cloud_card.dart';

const String _kGoogleServerClientId =
    '289974993415-lhibiid49ncmb5hev53hnasj7vhkvki3.apps.googleusercontent.com';

class MobileSettingsPage extends StatefulWidget {
  final String currentWorker;

  const MobileSettingsPage({super.key, required this.currentWorker});

  @override
  State<MobileSettingsPage> createState() => _MobileSettingsPageState();
}

class _MobileSettingsPageState extends State<MobileSettingsPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final ProfileStore _store = ProfileStore.instance;
  String _version = '';

  bool get _isGuest => ProfileStore.isGuest(widget.currentWorker);

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((p) {
          if (mounted) setState(() => _version = p.version);
        })
        .catchError((_) {});
  }

  Future<bool> _linkGoogleAccount() async {
    try {
      await _googleSignIn.initialize(serverClientId: _kGoogleServerClientId);
      final GoogleSignInAccount account = await _googleSignIn.authenticate();
      final credential = GoogleAuthProvider.credential(
        idToken: account.authentication.idToken,
      );
      await signInOrLinkGoogle(credential);
      final got = await restoreCalculatorSettings();
      if (got == 0 && SettingsCloudSync.instance.lastRestoreServerMissing) {
        await SettingsCloudSync.instance.backup();
      }
      if (mounted) setState(() {});
      return true;
    } catch (e) {
      debugPrint("구글 계정 연결 실패: $e");
      if (mounted) {
        showProfileSnack(context, "구글 계정을 연결하지 못했습니다. 통신을 확인하십시오.", isError: true);
      }
      return false;
    }
  }

  Future<void> _openStorage() async {
    final logs = await WorkProjectRepository().fetchAllProjects();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StorageManagementPage(logs: logs)),
    );
  }

  Future<void> _openNotifications() async {
    final logs = await WorkProjectRepository().fetchAllProjects();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NotificationCheckPage(logs: logs)),
    );
  }

  Future<void> _logout(BuildContext context) async {
    HapticFeedback.mediumImpact();
    await _store.clearToken(widget.currentWorker);
    try {
      await _googleSignIn.signOut().timeout(const Duration(seconds: 3));
      await _googleSignIn.disconnect().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint("구글 연결 해제 건너뜀: $e");
    }
    await FirebaseAuth.instance.signOut();
    await _store.clearName();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const MobileMenuPage(currentWorker: kGuestName),
        ),
        (route) => false,
      );
    }
  }

  void _showLogoutDialog(BuildContext context) {
    final anonymous = isAnonymousUser();
    bool busy = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setD) {
          final logoutBtn = TextButton(
            key: const Key('logout_confirm'),
            onPressed: busy
                ? null
                : () async {
                    setD(() => busy = true);
                    await _logout(context);
                  },
            style: TextButton.styleFrom(
              backgroundColor: anonymous ? Colors.transparent : profileRed500,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: busy
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: anonymous ? profileRed500 : profileWhite,
                    ),
                  )
                : Text(
                    anonymous ? "그래도 로그아웃" : "로그아웃",
                    style: TextStyle(
                      color: anonymous ? profileRed500 : profileWhite,
                      fontSize: anonymous ? 15 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          );
          final cancelBtn = TextButton(
            onPressed: busy ? null : () => Navigator.pop(dialogCtx),
            style: TextButton.styleFrom(
              backgroundColor: profileSlate100,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "취소",
              style: TextStyle(
                color: profileSlate600,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
          return AlertDialog(
            backgroundColor: profileWhite,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              "로그아웃하시겠습니까?",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: profileSlate900,
                letterSpacing: -0.5,
              ),
            ),
            content: Text(
              anonymous
                  ? "이 폰에서 이름과 알림을 지웁니다. 폰에 저장된 일지·설정은 그대로 남습니다.\n\n"
                        "구글 계정을 연결하지 않아 로그아웃하면 '내 것'으로 넣은 재고·배치도를 "
                        "다시 찾을 수 없습니다. 먼저 구글 계정을 연결하십시오."
                  : "이 폰에서 이름과 알림을 지웁니다. 폰에 저장된 일지·설정은 그대로 남습니다.",
              style: const TextStyle(
                fontSize: 15,
                color: profileSlate600,
                height: 1.4,
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              if (anonymous) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('logout_link_google'),
                    onPressed: busy
                        ? null
                        : () async {
                            final ok = await _linkGoogleAccount();
                            if (ok && dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                              showProfileSnack(context, "구글 계정을 연결했습니다.");
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: profileWhite,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "구글 계정 연결",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(child: cancelBtn),
                  const SizedBox(width: 8),
                  Expanded(child: logoutBtn),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: profileSlate100,
      appBar: AppBar(
        backgroundColor: profileSlate100,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          "설정",
          style: TextStyle(fontWeight: FontWeight.w800, color: profileSlate900),
        ),
        leading: IconButton(
          icon: const Icon(AppIcons.back, color: profileSlate900),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isGuest ? _buildGuestNotice() : _buildSettings(),
      ),
    );
  }

  Widget _buildGuestNotice() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          "이름을 넣거나 로그인하면 설정을 쓸 수 있습니다.",
          textAlign: TextAlign.center,
          style: TextStyle(color: profileSlate600, fontSize: 15, height: 1.4),
        ),
      ),
    );
  }

  Widget _buildSettings() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 8),
          SettingsCloudCard(onLinkGoogle: _linkGoogleAccount),
          const SizedBox(height: 8),
          buildProfileMenuCard([
            profileMenuItem(
              title: "알림 점검",
              subtitle: "일지·주간 보고 알림이 잡혀 있는지",
              icon: LucideIcons.bell,
              onTap: _openNotifications,
            ),
            profileMenuItem(
              title: "백업 · 저장 공간",
              subtitle: "일지 백업 파일, 클라우드 백업, 임시 파일 정리",
              icon: LucideIcons.hardDrive,
              onTap: _openStorage,
            ),
          ]),
          const SizedBox(height: 8),
          buildProfileMenuCard([
            profileMenuItem(
              title: "로그아웃",
              icon: LucideIcons.logOut,
              titleColor: profileRed500,
              iconColor: profileRed500,
              onTap: () => _showLogoutDialog(context),
            ),
          ]),
          const SizedBox(height: 16),
          Text(
            _version.isEmpty ? "Field Helper" : "Field Helper v$_version",
            key: const Key('settings_version'),
            style: const TextStyle(color: profileSlate600, fontSize: 12),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
