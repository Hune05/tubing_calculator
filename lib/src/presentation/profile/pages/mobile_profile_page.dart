// 내 프로필: 이름·사진·팀·직급·연락처, 계산기 설정 서버 보관, 빠른 이동, 로그아웃.
//
// 사용자 문서는 users/{이름}이라 이름 바꾸기는 [ProfileStore.renameUser] 한 갈래로만 한다.
// 바꾼 뒤에는 홈을 새 이름으로 다시 연다(예전엔 앱을 껐다 켜기 전까지 홈이 옛 이름이었다).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tubing_calculator/src/core/utils/settings_cloud.dart';
import 'package:tubing_calculator/src/data/repositories/work_project_repository.dart';
import 'package:tubing_calculator/src/presentation/menu/page/mobile_loading_screen.dart';
import 'package:tubing_calculator/src/presentation/menu/page/mobile_menu_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/notification_check_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/storage_management_page.dart';
import 'package:tubing_calculator/src/presentation/profile/profile_tools.dart';
import 'package:tubing_calculator/src/presentation/profile/widgets/profile_photo.dart';
import 'package:tubing_calculator/src/presentation/profile/widgets/settings_cloud_card.dart';
import 'package:tubing_calculator/src/presentation/reference/page/tube_reference_page.dart';

import 'mobile_profile_edit_page.dart';

const Color tossBlue = Color(0xFF3182F6);
const Color slate900 = Color(0xFF191F28);
const Color slate800 = Color(0xFF333D4B);
const Color slate600 = Color(0xFF5F6B78);
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color red500 = Color(0xFFF04452);

const String _kGoogleServerClientId =
    '289974993415-lhibiid49ncmb5hev53hnasj7vhkvki3.apps.googleusercontent.com';

class MobileProfilePage extends StatefulWidget {
  final String currentWorker;

  const MobileProfilePage({super.key, required this.currentWorker});

  @override
  State<MobileProfilePage> createState() => _MobileProfilePageState();
}

class _MobileProfilePageState extends State<MobileProfilePage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final ProfileStore _store = ProfileStore.instance;
  bool _isLoggingIn = false;
  bool _photoBusy = false;
  String _version = '';

  late String _displayName;

  @override
  void initState() {
    super.initState();
    _displayName = widget.currentWorker;
    PackageInfo.fromPlatform()
        .then((p) {
          if (mounted) setState(() => _version = p.version);
        })
        .catchError((_) {});
  }

  bool get _isGuest => ProfileStore.isGuest(_displayName);

  // ───────────────── 로그인 ─────────────────

  /// 이름만 넣고 쓰던 사람이 이름은 그대로 두고 구글 계정만 잇는다(계산기 설정을 계정에 보관하려고).
  Future<bool> _linkGoogleAccount() async {
    try {
      await _googleSignIn.initialize(serverClientId: _kGoogleServerClientId);
      final GoogleSignInAccount account = await _googleSignIn.authenticate();
      final credential = GoogleAuthProvider.credential(
        idToken: account.authentication.idToken,
      );
      // 익명 계정이면 그 계정에 구글을 이어 uid를 그대로 둔다("내 것"을 잃지 않게).
      await signInOrLinkGoogle(credential);
      final got = await restoreCalculatorSettings();
      if (got == 0) await SettingsCloudSync.instance.backup();
      if (mounted) setState(() {});
      return true;
    } catch (e) {
      debugPrint("구글 계정 연결 실패: $e");
      if (mounted) {
        _showSnackBar("구글 계정을 연결하지 못했습니다. 통신을 확인하십시오.", isError: true);
      }
      return false;
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoggingIn = true);
    try {
      await _googleSignIn.initialize(serverClientId: _kGoogleServerClientId);
      // authenticate()는 취소·실패면 예외를 던지고 null을 주지 않는다.
      final GoogleSignInAccount account = await _googleSignIn.authenticate();
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: account.authentication.idToken,
      );
      await signInOrLinkGoogle(credential);

      // 폰에 없는 설정 칸은 서버 것으로 채우고, 받을 것이 없으면 폰 설정을 올려 둔다.
      final got = await restoreCalculatorSettings();
      if (got == 0) SettingsCloudSync.instance.backup();

      if (!mounted) return;
      await _showNameConfirmDialog(account.displayName ?? "");
    } catch (error) {
      debugPrint("구글 로그인 실패: $error");
      if (mounted) {
        _showSnackBar("로그인하지 못했습니다. 통신이 없으면 '이름만 넣기'로 쓰십시오.", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  /// 처음 이름 넣기(이름만 넣기·구글 로그인 뒤 공통). 넣으면 앱을 처음부터 다시 연다.
  Future<void> _showNameConfirmDialog([String initialName = ""]) async {
    final nameCtrl = TextEditingController(text: initialName);
    final error = ValueNotifier<String?>(null);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: pureWhite,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "작업자 이름 넣기",
            style: TextStyle(fontWeight: FontWeight.bold, color: slate900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "현장에서 부르는 이름(또는 직급)을 넣으십시오. 일지·일정·자재 기록에 이 이름이 남습니다.",
                style: TextStyle(fontSize: 14, color: slate600, height: 1.4),
              ),
              const SizedBox(height: 16),
              _nameField(nameCtrl, error, hint: "예: 홍길동 (또는 김반장)"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소", style: TextStyle(color: slate600)),
            ),
            ElevatedButton(
              style: _blueButton,
              onPressed: () async {
                final realName = nameCtrl.text.trim();
                final problem = userNameProblem(realName);
                if (problem != null) {
                  error.value = problem;
                  return;
                }
                // 로그인 안 했으면 익명으로라도 uid를 받고, 남이 쓰는 이름인지 본다.
                final taken = await _store.claimName(realName);
                if (taken != null) {
                  error.value = taken;
                  return;
                }
                await _store.saveName(realName);
                await _store.saveToken(realName);
                if (!context.mounted) return;
                Navigator.pop(context);
                _showSnackBar("$realName님, 시작합니다.");
                // 이름이 정해졌으니 로딩 화면부터 다시(홈·알림·설정이 이 이름으로 읽힌다).
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MobileLoadingScreen(),
                  ),
                  (route) => false,
                );
              },
              child: const Text(
                "시작",
                style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // ───────────────── 이름 바꾸기 ─────────────────

  Future<void> _showRenameDialog() async {
    final idCtrl = TextEditingController(text: _displayName);
    final error = ValueNotifier<String?>(null);
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: pureWhite,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "이름 바꾸기",
            style: TextStyle(fontWeight: FontWeight.bold, color: slate900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _nameField(idCtrl, error, hint: "새 이름", autofocus: true),
              const SizedBox(height: 12),
              const Text(
                "사진·팀·연락처는 새 이름으로 같이 옮깁니다. 예전 이름으로 적어 둔 일정·일지·자재 기록은 예전 이름 그대로 남습니다.",
                style: TextStyle(fontSize: 13, color: slate600, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소", style: TextStyle(color: slate600)),
            ),
            ElevatedButton(
              style: _blueButton,
              onPressed: () {
                final v = idCtrl.text.trim();
                final problem = userNameProblem(v);
                if (problem != null) {
                  error.value = problem;
                  return;
                }
                if (v == _displayName) {
                  error.value = "지금 이름과 같습니다.";
                  return;
                }
                Navigator.pop(context, v);
              },
              child: const Text(
                "바꾸기",
                style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
    if (newName == null || !mounted) return;
    await _applyRename(newName);
  }

  Future<void> _applyRename(String newName) async {
    final old = _displayName;
    final taken = await _store.claimName(newName);
    if (taken != null) {
      _showSnackBar(taken, isError: true);
      return;
    }
    await _store.renameUser(old, newName);
    if (!mounted) return;
    setState(() => _displayName = newName);
    _showSnackBar("이름을 '$newName'(으)로 바꿨습니다.");
    // 홈·다른 화면이 옛 이름을 들고 있으니 홈을 새 이름으로 다시 연다.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => MobileMenuPage(currentWorker: newName),
      ),
      (route) => false,
    );
  }

  Widget _nameField(
    TextEditingController ctrl,
    ValueNotifier<String?> error, {
    required String hint,
    bool autofocus = false,
  }) {
    return ValueListenableBuilder<String?>(
      valueListenable: error,
      builder: (_, err, _) => TextField(
        controller: ctrl,
        cursorColor: tossBlue,
        autofocus: autofocus,
        maxLength: 20,
        onChanged: (_) => error.value = null,
        decoration: InputDecoration(
          filled: true,
          fillColor: slate100,
          counterText: "",
          errorText: err,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: tossBlue, width: 2),
          ),
          hintText: hint,
          prefixIcon: const Icon(LucideIcons.user, color: tossBlue),
        ),
      ),
    );
  }

  ButtonStyle get _blueButton => ElevatedButton.styleFrom(
    backgroundColor: tossBlue,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isError ? red500 : slate900,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ───────────────── 연락처 ─────────────────

  Future<void> _phoneActions(String phone) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                phone,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: slate900,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(LucideIcons.phoneCall, color: tossBlue),
              title: const Text(
                "전화 걸기",
                style: TextStyle(fontWeight: FontWeight.w700, color: slate900),
              ),
              onTap: () => Navigator.pop(ctx, 'call'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.copy, color: tossBlue),
              title: const Text(
                "복사",
                style: TextStyle(fontWeight: FontWeight.w700, color: slate900),
              ),
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: phone));
      _showSnackBar('연락처를 복사했습니다.');
      return;
    }
    final uri = Uri(
      scheme: 'tel',
      path: phone.replaceAll(RegExp(r'[^0-9+]'), ''),
    );
    try {
      final ok = await launchUrl(uri);
      if (!ok) _showSnackBar('전화 앱을 열지 못했습니다.', isError: true);
    } catch (_) {
      _showSnackBar('전화 앱을 열지 못했습니다.', isError: true);
    }
  }

  // ───────────────── 빠른 이동 ─────────────────

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

  void _openEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MobileProfileEditPage(initialName: _displayName),
      ),
    );
  }

  // ───────────────── 화면 ─────────────────

  @override
  Widget build(BuildContext context) {
    final bool isGuest = _isGuest;

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
                    if (isGuest)
                      _buildGuestIdentity()
                    else
                      _buildUserIdentity(),
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
                              "구글 계정으로 시작",
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
                              _showNameConfirmDialog();
                            },
                            icon: const Icon(
                              LucideIcons.wifiOff,
                              color: slate600,
                              size: 20,
                            ),
                            label: const Text(
                              "이름만 넣고 시작 (통신 없을 때)",
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

              if (!isGuest) SettingsCloudCard(onLinkGoogle: _linkGoogleAccount),

              if (!isGuest) ...[
                _buildMenuCard([
                  _menuItem(
                    title: "상세 프로필 (팀·직급·연락처)",
                    icon: LucideIcons.settings,
                    onTap: _openEdit,
                  ),
                  _menuItem(
                    title: "알림 확인",
                    subtitle: "일지·주간 보고 알림이 잡혀 있는지",
                    icon: LucideIcons.bell,
                    onTap: _openNotifications,
                  ),
                  _menuItem(
                    title: "백업 · 저장 공간",
                    subtitle: "일지 백업 파일, 클라우드 백업, 임시 파일 정리",
                    icon: LucideIcons.hardDrive,
                    onTap: _openStorage,
                  ),
                  _menuItem(
                    title: "현장 자료 · 장비 사용법",
                    icon: LucideIcons.bookOpen,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TubeReferencePage(),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                _buildMenuCard([
                  _menuItem(
                    title: "로그아웃",
                    icon: LucideIcons.logOut,
                    titleColor: red500,
                    iconColor: red500,
                    onTap: () => _showLogoutDialog(context),
                  ),
                ]),
              ],
              const SizedBox(height: 16),
              Text(
                _version.isEmpty ? "현장 도우미" : "현장 도우미 v$_version",
                key: const Key('profile_version'),
                style: const TextStyle(color: slate600, fontSize: 12),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(List<Widget> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                color: slate100,
                indent: 24,
                endIndent: 24,
              ),
            items[i],
          ],
        ],
      ),
    );
  }

  Widget _buildGuestIdentity() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: slate100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            LucideIcons.userX,
            size: 40,
            color: slate600.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "이름이 없습니다",
          style: TextStyle(
            color: slate600,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "이름을 넣거나 구글로 로그인하면 일지·일정·자재 기록에 이름이 남습니다.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: slate600,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  /// users/{이름} 문서를 구독해 사진·직급·팀·연락처를 보여 준다. 상세 프로필에서 고치면 바로 반영.
  Widget _buildUserIdentity() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_displayName)
          .snapshots(),
      builder: (context, snapshot) {
        final p = UserProfile.fromMap(_displayName, snapshot.data?.data());
        final String? photoUrl = p.photoUrl;
        final bool hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
        final user = FirebaseAuth.instance.currentUser;
        final bool isVerified = user != null;

        return Column(
          children: [
            Stack(
              children: [
                InkWell(
                  onTap: _photoBusy
                      ? null
                      : () => changeProfilePhoto(
                          context,
                          userName: _displayName,
                          hasPhoto: hasPhoto,
                          onBusy: (b) {
                            if (mounted) setState(() => _photoBusy = b);
                          },
                        ),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: slate100,
                      shape: BoxShape.circle,
                      image: hasPhoto
                          ? DecorationImage(
                              image: NetworkImage(photoUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _photoBusy
                        ? const Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: tossBlue,
                              ),
                            ),
                          )
                        : hasPhoto
                        ? null
                        : const Icon(
                            LucideIcons.user,
                            size: 40,
                            color: tossBlue,
                          ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: pureWhite,
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: slate100, width: 2),
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.camera,
                      size: 14,
                      color: slate800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _displayName,
                    style: const TextStyle(
                      color: slate900,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  key: const Key('profile_rename'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showRenameDialog();
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
            ),
            const SizedBox(height: 4),
            Text(
              p.role.isNotEmpty ? p.role : "현장 작업자",
              style: const TextStyle(
                color: slate600,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isVerified ? LucideIcons.badgeCheck : LucideIcons.smartphone,
                  size: 14,
                  color: isVerified ? tossBlue : slate600,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    loginMethodLabel(
                      googleLinked: isVerified,
                      email: user?.email,
                    ),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: slate600, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildInfoChip(
                  icon: LucideIcons.users,
                  label: p.team.isNotEmpty ? p.team : "팀 넣기",
                  muted: p.team.isEmpty,
                  onTap: _openEdit,
                ),
                _buildInfoChip(
                  icon: LucideIcons.phone,
                  label: p.phone.isNotEmpty ? p.phone : "연락처 넣기",
                  muted: p.phone.isEmpty,
                  onTap: p.phone.isNotEmpty
                      ? () => _phoneActions(p.phone)
                      : _openEdit,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool muted = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: slate100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: slate600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: muted ? slate600 : slate800,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem({
    required String title,
    String? subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color titleColor = slate800,
    Color iconColor = slate600,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Row(
          children: [
            Icon(icon, size: 24, color: iconColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: slate600, fontSize: 13),
                    ),
                  ],
                ],
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

  /// 로그아웃. 이 폰에서 알림 토큰·구글 연결·이름을 지우고 처음 화면으로 간다.
  Future<void> _logout(BuildContext context) async {
    HapticFeedback.mediumImpact();
    // 같이 쓰는 폰에서 남의 알림이 오지 않게 토큰부터 지운다.
    await _store.clearToken(_displayName);
    try {
      // 통신이 없으면 끝나지 않을 수 있어 오래 기다리지 않는다.
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

  // 🚀 [고침] 구글 계정을 잇지 않은 사람에게 "되찾을 수 없다"고 경고하면서도 빨간
  // "로그아웃"이 가장 눈에 띄었고, 창 안에서 바로 이을 수도 없었다. 그때는 "구글 계정
  // 잇기"를 큰 단추로, 로그아웃은 글자 단추로 둔다. 통신이 없을 때 몇 초 반응이
  // 없던 것은 누른 뒤 도는 표시로 알린다.
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
              backgroundColor: anonymous ? Colors.transparent : red500,
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
                      color: anonymous ? red500 : pureWhite,
                    ),
                  )
                : Text(
                    anonymous ? "그래도 로그아웃" : "로그아웃",
                    style: TextStyle(
                      color: anonymous ? red500 : pureWhite,
                      fontSize: anonymous ? 15 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          );
          final cancelBtn = TextButton(
            onPressed: busy ? null : () => Navigator.pop(dialogCtx),
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
          );
          return AlertDialog(
            backgroundColor: pureWhite,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              "로그아웃하시겠습니까?",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: slate900,
                letterSpacing: -0.5,
              ),
            ),
            content: Text(
              anonymous
                  ? "이 폰에서 이름과 알림을 지웁니다. 폰에 저장된 일지·설정은 그대로 남습니다.\n\n"
                        "구글 계정을 잇지 않았으므로, 로그아웃하면 '내 것'으로 넣은 재고·배치도를 "
                        "다시 찾을 수 없습니다. 먼저 구글 계정을 이으십시오."
                  : "이 폰에서 이름과 알림을 지웁니다. 폰에 저장된 일지·설정은 그대로 남습니다.",
              style: const TextStyle(
                fontSize: 15,
                color: slate600,
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
                              _showSnackBar("구글 계정을 이었습니다.");
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007580),
                      foregroundColor: pureWhite,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "구글 계정 잇기",
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
}
