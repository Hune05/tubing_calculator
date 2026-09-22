// 상세 프로필: 사진·이름·팀·직급·연락처. 이름을 바꾸면 프로필 화면과 같은 갈래
// ([ProfileStore.renameUser])로 옮기고 홈을 새 이름으로 다시 연다.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:tubing_calculator/src/presentation/menu/page/mobile_menu_page.dart';
import 'package:tubing_calculator/src/presentation/profile/profile_tools.dart';
import 'package:tubing_calculator/src/presentation/profile/widgets/profile_photo.dart';

const Color slate900 = Color(0xFF191F28);
const Color slate800 = Color(0xFF333D4B);
const Color slate600 = Color(0xFF8B95A1);
const Color slate300 = Color(0xFFD1D6DB);
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color blue500 = Color(0xFF3182F6);
const Color red500 = Color(0xFFF04452);

class MobileProfileEditPage extends StatefulWidget {
  final String initialName;

  const MobileProfileEditPage({super.key, required this.initialName});

  @override
  State<MobileProfileEditPage> createState() => _MobileProfileEditPageState();
}

class _MobileProfileEditPageState extends State<MobileProfileEditPage> {
  final ProfileStore _store = ProfileStore.instance;
  late final TextEditingController _nameController;
  late final TextEditingController _teamController;
  late final TextEditingController _roleController;
  late final TextEditingController _phoneController;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _photoUrl;
  bool _photoBusy = false;
  String? _nameError;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _teamController = TextEditingController();
    _roleController = TextEditingController();
    _phoneController = TextEditingController();
    _load();
  }

  /// 서버가 5초 안에 답이 없으면 폰에 남은 것으로(예전엔 통신 없으면 영영 돌았다).
  Future<void> _load() async {
    final p = await _store.load(widget.initialName);
    if (!mounted) return;
    setState(() {
      _nameController.text = p.name;
      _teamController.text = p.team;
      _roleController.text = p.role;
      _phoneController.text = p.phone;
      _photoUrl = p.photoUrl;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teamController.dispose();
    _roleController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    final String newName = _nameController.text.trim();
    final String phoneRaw = _phoneController.text.trim();

    final nameProblem = userNameProblem(newName);
    final phoneProblem = phoneRaw.isEmpty
        ? '연락처를 넣으십시오.'
        : (isPhoneLike(phoneRaw) ? null : '연락처는 숫자 9~11자리로 넣으십시오.');
    setState(() {
      _nameError = nameProblem;
      _phoneError = phoneProblem;
    });
    if (nameProblem != null || phoneProblem != null) return;

    final String phone = normalizePhone(phoneRaw);
    final bool renamed =
        newName != widget.initialName &&
        !ProfileStore.isGuest(widget.initialName);
    if (renamed) {
      final ok = await _confirmRename(newName);
      if (ok != true) return;
    }

    setState(() => _isSaving = true);
    if (renamed) {
      await _store.renameUser(widget.initialName, newName);
    } else {
      await _store.saveName(newName);
    }
    await _store.saveFields(
      newName,
      team: _teamController.text.trim(),
      role: _roleController.text.trim(),
      phone: phone,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(renamed ? '이름을 바꾸고 프로필을 저장했습니다.' : '프로필을 저장했습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (renamed) {
      // 홈·프로필이 옛 이름을 들고 있으니 새 이름으로 다시 연다.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => MobileMenuPage(currentWorker: newName),
        ),
        (route) => false,
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<bool?> _confirmRename(String newName) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: pureWhite,
      surfaceTintColor: Colors.transparent,
      title: const Text(
        "이름을 바꿉니다",
        style: TextStyle(fontWeight: FontWeight.bold, color: slate900),
      ),
      content: Text(
        "'${widget.initialName}' → '$newName'\n\n사진·팀·연락처는 새 이름으로 같이 옮깁니다. 예전 이름으로 적어 둔 일정·일지·자재 기록은 예전 이름 그대로 남습니다.",
        style: const TextStyle(color: slate600, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text("취소", style: TextStyle(color: slate600)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            "바꾸기",
            style: TextStyle(color: blue500, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: pureWhite,
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          "상세 프로필",
          style: TextStyle(
            color: slate900,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slate900),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: blue500))
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildProfileImage(),
                          const SizedBox(height: 32),
                          _buildInputField(
                            label: "이름",
                            controller: _nameController,
                            errorText: _nameError,
                            hint: "현장에서 부르는 이름",
                            maxLength: 20,
                            onChanged: (_) {
                              if (_nameError != null) {
                                setState(() => _nameError = null);
                              }
                            },
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildInputField(
                                  label: "소속 팀",
                                  controller: _teamController,
                                  hint: "예: 계장 2팀",
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildInputField(
                                  label: "직급",
                                  controller: _roleController,
                                  hint: "예: 반장",
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildInputField(
                            label: "연락처",
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            errorText: _phoneError,
                            hint: "010-0000-0000",
                            onChanged: (_) {
                              if (_phoneError != null) {
                                setState(() => _phoneError = null);
                              }
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildReadOnlyField(
                            label: "로그인",
                            value: loginMethodLabel(
                              googleLinked: user != null,
                              email: user?.email,
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileImage() {
    final bool hasPhoto = _photoUrl != null && _photoUrl!.isNotEmpty;
    return Stack(
      children: [
        InkWell(
          onTap: _photoBusy ? null : _changePhoto,
          customBorder: const CircleBorder(),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: slate100,
              shape: BoxShape.circle,
              border: Border.all(color: slate300, width: 1),
              image: hasPhoto
                  ? DecorationImage(
                      image: NetworkImage(_photoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: hasPhoto
                ? null
                : const Icon(LucideIcons.user, size: 50, color: slate600),
          ),
        ),
        if (_photoBusy)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: pureWhite,
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 0,
          right: 0,
          child: InkWell(
            onTap: _photoBusy ? null : _changePhoto,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: pureWhite,
                shape: BoxShape.circle,
                border: Border.all(color: slate300, width: 1),
              ),
              child: const Icon(LucideIcons.camera, size: 18, color: slate800),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _changePhoto() async {
    HapticFeedback.lightImpact();
    final r = await changeProfilePhoto(
      context,
      userName: widget.initialName,
      hasPhoto: _photoUrl != null && _photoUrl!.isNotEmpty,
      onBusy: (b) {
        if (mounted) setState(() => _photoBusy = b);
      },
    );
    if (r == null || !mounted) return;
    setState(() => _photoUrl = r.removed ? null : r.url);
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? errorText,
    String? hint,
    int? maxLength,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: slate600,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: slate100,
            borderRadius: BorderRadius.circular(16),
            border: errorText == null
                ? null
                : Border.all(color: red500, width: 1.5),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLength: maxLength,
            onChanged: onChanged,
            style: const TextStyle(
              color: slate900,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: InputBorder.none,
              isDense: true,
              counterText: "",
              hintText: hint,
              hintStyle: const TextStyle(
                color: slate300,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText,
            style: const TextStyle(
              color: red500,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReadOnlyField({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: slate600,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: slate100.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: slate600,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: const BoxDecoration(
        color: pureWhite,
        border: Border(top: BorderSide(color: slate100, width: 1)),
      ),
      child: InkWell(
        onTap: _isSaving ? null : _save,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: _isSaving ? slate300 : blue500,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: _isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: pureWhite,
                    strokeWidth: 2.5,
                  ),
                )
              : const Text(
                  "저장",
                  style: TextStyle(
                    color: pureWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
