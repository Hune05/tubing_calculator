import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

// 🎨 색상 팔레트
const Color slate900 = Color(0xFF191F28);
const Color slate800 = Color(0xFF333D4B);
const Color slate600 = Color(0xFF8B95A1);
const Color slate300 = Color(0xFFD1D6DB);
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color blue500 = Color(0xFF3182F6);
const Color red500 = Color(0xFFF04452); // 🔥 에러용 빨간색 추가

class MobileProfileEditPage extends StatefulWidget {
  final String initialName;

  const MobileProfileEditPage({super.key, required this.initialName});

  @override
  State<MobileProfileEditPage> createState() => _MobileProfileEditPageState();
}

class _MobileProfileEditPageState extends State<MobileProfileEditPage> {
  late TextEditingController _nameController;
  late TextEditingController _teamController;
  late TextEditingController _roleController;
  late TextEditingController _phoneController;

  bool _isLoading = true;
  String? _photoUrl;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _teamController = TextEditingController();
    _roleController = TextEditingController();
    _phoneController = TextEditingController();

    _loadUserProfile();
  }

  // 🚀 Firestore에서 로그인한 유저의 정보 가져오기 (이름 기준)
  Future<void> _loadUserProfile() async {
    // uid 대신 widget.initialName (이름)으로 문서를 찾습니다!
    if (widget.initialName.isNotEmpty && widget.initialName != "로그인 필요") {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.initialName)
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          setState(() {
            _nameController.text = data['name'] ?? widget.initialName;
            _teamController.text = data['team'] ?? "";
            _roleController.text = data['role'] ?? "";
            _phoneController.text = data['phoneNumber'] ?? ""; // 🔥 키값 통일
            _photoUrl = data['photoUrl'];
          });
        }
      } catch (e) {
        debugPrint("프로필 불러오기 실패: $e");
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teamController.dispose();
    _roleController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pureWhite,
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          "프로필 수정",
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
                          const SizedBox(height: 40),

                          _buildInputField(
                            label: "이름",
                            controller: _nameController,
                          ),
                          const SizedBox(height: 24),

                          Row(
                            children: [
                              Expanded(
                                child: _buildInputField(
                                  label: "소속 팀",
                                  controller: _teamController,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildInputField(
                                  label: "직급",
                                  controller: _roleController,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // 🔥 연락처 필드 (필수)
                          _buildInputField(
                            label: "연락처 (필수)",
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 24),

                          // 💡 사원번호는 파이어베이스 UID의 앞 8자리로 예쁘게 잘라서 보여줍니다
                          _buildReadOnlyField(
                            label: "사원 번호 (ID)",
                            value:
                                FirebaseAuth.instance.currentUser?.uid
                                    .substring(0, 8)
                                    .toUpperCase() ??
                                "알 수 없음",
                          ),
                          const SizedBox(height: 40),
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

  // 🚀 [프로필 고도화] "사진 변경은 다음 버전에 업데이트됩니다"라는 미구현
  // 스텁이었던 걸 실제 갤러리 선택 → 정사각형 자르기 → Firebase Storage
  // 업로드 → users/{이름} 문서에 photoUrl 저장까지 실제로 동작하게
  // 만들었다. 다른 화면(채팅 이미지 전송)이 이미 쓰던 것과 같은
  // ImagePicker → FirebaseStorage 패턴을 그대로 따랐다.
  Future<void> _pickAndUploadPhoto() async {
    final userKey = widget.initialName;
    if (userKey.isEmpty || userKey == "로그인 필요") {
      _showErrorSnackBar('먼저 로그인한 뒤 사진을 등록해 주십시오.');
      return;
    }

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (picked == null) return;
    if (!mounted) return;

    final CroppedFile? cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '프로필 사진 편집',
          toolbarColor: blue500,
          toolbarWidgetColor: pureWhite,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: '프로필 사진 편집', aspectRatioLockEnabled: true),
      ],
    );
    if (cropped == null) return;
    if (!mounted) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('$userKey.jpg');
      await ref.putFile(File(cropped.path));
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(userKey).set({
        'photoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _photoUrl = url;
        _isUploadingPhoto = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('프로필 사진을 변경했습니다.')));
    } catch (e) {
      debugPrint('프로필 사진 업로드 실패: $e');
      if (mounted) setState(() => _isUploadingPhoto = false);
      _showErrorSnackBar('사진 업로드에 실패했습니다.');
    }
  }

  Widget _buildProfileImage() {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: slate100,
            shape: BoxShape.circle,
            border: Border.all(color: slate300, width: 1),
            image: (_photoUrl != null && _photoUrl!.isNotEmpty)
                ? DecorationImage(
                    image: NetworkImage(_photoUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: (_photoUrl == null || _photoUrl!.isEmpty)
              ? const Icon(LucideIcons.user, size: 50, color: slate600)
              : null,
        ),
        if (_isUploadingPhoto)
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
            onTap: _isUploadingPhoto
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    _pickAndUploadPhoto();
                  },
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

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
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
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(
              color: slate900,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
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
            color: slate100.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: slate600,
              fontSize: 18,
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
        onTap: () async {
          HapticFeedback.mediumImpact();

          final String userName = _nameController.text.trim();
          final String phoneNumber = _phoneController.text.trim();

          // 🔥 1. 무조건 번호(또는 이름)를 넣게 강제!
          if (userName.isEmpty) {
            _showErrorSnackBar('이름을 입력해 주십시오.');
            return;
          }
          if (phoneNumber.isEmpty) {
            _showErrorSnackBar('연락처는 필수 입력 항목입니다.');
            return;
          }

          // 🔥 2. Firestore 'users' 컬렉션에 프로필 저장 (이름을 ID로 사용!)
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userName)
              .set({
                'name': userName,
                'team': _teamController.text.trim(),
                'role': _roleController.text.trim(),
                'phoneNumber': phoneNumber, // 🔥 채팅방이랑 키값 일치시킴
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

          // 🔥 3. 기기 로컬 저장소(오프라인 대응용) 이름 갱신
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_real_name', userName);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('프로필이 성공적으로 업데이트 되었습니다.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.pop(context);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: blue500,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: const Text(
            "저장하기",
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

  // 에러 스낵바 헬퍼 함수
  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: red500,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
