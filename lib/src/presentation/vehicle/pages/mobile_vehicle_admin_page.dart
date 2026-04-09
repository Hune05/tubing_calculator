import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);
const Color makitaTeal = Color(0xFF007580);

class MobileVehicleAdminPage extends StatefulWidget {
  const MobileVehicleAdminPage({super.key});

  @override
  State<MobileVehicleAdminPage> createState() => _MobileVehicleAdminPageState();
}

class _MobileVehicleAdminPageState extends State<MobileVehicleAdminPage> {
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tossGrey,
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slate900),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "차량 통합 세팅",
              style: TextStyle(
                color: slate900,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              "관리자 전용 (마스터 권한)",
              style: TextStyle(
                color: warningRed,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vehicles').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: tossBlue),
            );
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("등록된 차량이 없습니다.", style: TextStyle(color: slate600)),
            );
          }

          final vehicles = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final vehicleData =
                  vehicles[index].data() as Map<String, dynamic>;
              vehicleData['id'] = vehicles[index].id;

              bool inUse = vehicleData['status'] == "운행 중";
              String? imageUrl = vehicleData['imageUrl'];
              String fuelType = vehicleData['fuelType'] ?? '가솔린'; // 🔥 연료 타입 추가

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: pureWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: slate100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: (imageUrl != null && imageUrl.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: tossBlue,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(
                                        LucideIcons.car,
                                        color: slate600,
                                      ),
                                )
                              : const Icon(
                                  LucideIcons.car,
                                  color: slate600,
                                  size: 24,
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    vehicleData['number'] ?? '번호 없음',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: tossBlue,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: inUse
                                          ? warningRed.withValues(alpha: 0.1)
                                          : tossBlue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      inUse ? "운행 중" : "차고지 대기",
                                      style: TextStyle(
                                        color: inUse ? warningRed : tossBlue,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  // 🔥 연료 타입 뱃지
                                  Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: fuelType == '전기'
                                          ? tossBlue.withValues(alpha: 0.1)
                                          : slate100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      fuelType,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: fuelType == '전기'
                                            ? tossBlue
                                            : slate600,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    vehicleData['type'] ?? '-',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: slate900,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tossGrey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "배정 현황",
                                style: TextStyle(color: slate600, fontSize: 13),
                              ),
                              Text(
                                vehicleData['fixedTeam'] ?? "없음 (공용)",
                                style: const TextStyle(
                                  color: slate900,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (inUse) ...[
                            const Divider(height: 16, color: Colors.black12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "현재 사용자",
                                  style: TextStyle(
                                    color: slate600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  "${vehicleData['currentUser']}",
                                  style: const TextStyle(
                                    color: warningRed,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _showEditBottomSheet(vehicleData);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: slate900,
                              side: const BorderSide(color: Colors.black12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text("정보/정비/사진 수정"),
                          ),
                        ),
                        if (inUse) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                HapticFeedback.heavyImpact();
                                await FirebaseFirestore.instance
                                    .collection('vehicles')
                                    .doc(vehicleData['id'])
                                    .update({
                                      'status': '사용 가능',
                                      'currentUser': null,
                                      'destination': null,
                                      'returnTime': null,
                                    });

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("관리자 권한으로 강제 반납 처리되었습니다."),
                                      backgroundColor: slate900,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: warningRed,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                "강제 회수",
                                style: TextStyle(
                                  color: pureWhite,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          _showEditBottomSheet(null);
        },
        backgroundColor: slate900,
        icon: const Icon(Icons.add, color: pureWhite),
        label: const Text(
          "신규 차량 등록",
          style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showEditBottomSheet(Map<String, dynamic>? vehicle) {
    bool isNew = vehicle == null;

    final numCtrl = TextEditingController(text: isNew ? '' : vehicle['number']);
    final typeCtrl = TextEditingController(text: isNew ? '' : vehicle['type']);
    final teamCtrl = TextEditingController(
      text: isNew ? '' : vehicle['fixedTeam'],
    );
    final insCtrl = TextEditingController(
      text: isNew ? '' : vehicle['insurance'],
    );
    final insPhoneCtrl = TextEditingController(
      text: isNew ? '' : vehicle['insurancePhone'],
    );
    final maintenanceCtrl = TextEditingController(
      text: isNew ? '' : vehicle['nextMaintenanceKm'],
    );

    String? currentImageUrl = isNew ? null : vehicle['imageUrl'];
    File? selectedLocalImage;
    bool isUploading = false;

    // 🔥 연료 타입 상태 (기본값 전기)
    String selectedFuel = vehicle?['fuelType'] ?? '전기';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isNew ? "신규 차량 등록" : "차량 정보 수정",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: slate900,
                  ),
                ),
                const SizedBox(height: 24),

                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildInputLabel("차량 대표 사진 (선택)"),
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          try {
                            final XFile? image = await _picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1080,
                              maxHeight: 1080,
                              imageQuality: 50,
                            );
                            if (image != null) {
                              setModalState(() {
                                selectedLocalImage = File(image.path);
                              });
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('사진을 가져오는 중 오류가 발생했습니다.'),
                              ),
                            );
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 160,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: tossGrey,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black12),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: selectedLocalImage != null
                              ? Image.file(
                                  selectedLocalImage!,
                                  fit: BoxFit.cover,
                                )
                              : (currentImageUrl != null &&
                                    currentImageUrl.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: currentImageUrl,
                                  fit: BoxFit.cover,
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.camera,
                                      size: 40,
                                      color: slate600,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      "터치하여 갤러리에서 사진 등록",
                                      style: TextStyle(
                                        color: slate600,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      // 🔥 연료 타입 선택 UI (탭 형태)
                      _buildInputLabel("연료 타입"),
                      Row(
                        children: ['전기', '가솔린', '디젤', '하이브리드']
                            .asMap()
                            .entries
                            .map((entry) {
                              int idx = entry.key;
                              String fuel = entry.value;
                              bool isSelected = selectedFuel == fuel;

                              return Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setModalState(() => selectedFuel = fuel);
                                  },
                                  child: Container(
                                    margin: EdgeInsets.only(
                                      right: idx == 3 ? 0 : 8,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected ? slate900 : pureWhite,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? slate900
                                            : Colors.black12,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      fuel,
                                      style: TextStyle(
                                        color: isSelected
                                            ? pureWhite
                                            : slate600,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            })
                            .toList(),
                      ),
                      const SizedBox(height: 16),

                      _buildInputLabel("차량 번호"),
                      _buildTextField(
                        numCtrl,
                        isNew ? "예: 12가 3456" : "차량 번호 입력",
                      ),
                      const SizedBox(height: 16),

                      _buildInputLabel("차종 및 설명"),
                      _buildTextField(
                        typeCtrl,
                        isNew ? "예: EV6 (롱레인지)" : "차종 입력",
                      ),
                      const SizedBox(height: 16),

                      _buildInputLabel("고정 팀 배정 (선택)"),
                      _buildTextField(
                        teamCtrl,
                        isNew ? "예: 현장팀 전용 (비워두면 공용)" : "팀 배정 입력",
                      ),
                      const SizedBox(height: 16),

                      const Divider(height: 32, color: tossGrey),

                      _buildInputLabel("보험사 명"),
                      _buildTextField(
                        insCtrl,
                        isNew ? "예: 삼성화재 다이렉트" : "보험사 정보 입력",
                      ),
                      const SizedBox(height: 16),

                      _buildInputLabel("보험사 긴급출동 연락처 (숫자만, 또는 하이픈 포함)"),
                      _buildTextField(
                        insPhoneCtrl,
                        isNew ? "예: 1588-5114" : "연락처 입력",
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),

                      // 🔥 연료 타입에 따라 라벨과 힌트가 스마트하게 변경됨
                      _buildInputLabel(
                        selectedFuel == '전기'
                            ? "다음 정기 점검 기준 (목표 주행거리)"
                            : "엔진오일 교체 주기 (목표 주행거리)",
                      ),
                      _buildTextField(
                        maintenanceCtrl,
                        isNew
                            ? (selectedFuel == '전기'
                                  ? "예: 80,000km (감속기 오일 등)"
                                  : "예: 10,000km")
                            : "주행거리 입력",
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isUploading
                        ? null
                        : () async {
                            HapticFeedback.mediumImpact();

                            if (numCtrl.text.trim().isEmpty ||
                                typeCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('차량 번호와 차종은 필수 입력입니다.'),
                                  backgroundColor: warningRed,
                                ),
                              );
                              return;
                            }

                            setModalState(() => isUploading = true);

                            String finalImageUrl = currentImageUrl ?? "";

                            if (selectedLocalImage != null) {
                              try {
                                String fileName =
                                    "vehicle_${DateTime.now().millisecondsSinceEpoch}.jpg";
                                Reference ref = FirebaseStorage.instance
                                    .ref()
                                    .child('vehicle_images')
                                    .child(fileName);
                                await ref.putFile(selectedLocalImage!);
                                finalImageUrl = await ref.getDownloadURL();
                              } catch (e) {
                                setModalState(() => isUploading = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('사진 업로드에 실패했습니다.'),
                                    ),
                                  );
                                }
                                return;
                              }
                            }

                            // 🔥 저장 데이터에 연료 타입 포함
                            final saveInfo = {
                              'number': numCtrl.text.trim(),
                              'type': typeCtrl.text.trim(),
                              'fuelType': selectedFuel, // 👈 DB에 추가됨
                              'fixedTeam': teamCtrl.text.trim().isEmpty
                                  ? null
                                  : teamCtrl.text.trim(),
                              'insurance': insCtrl.text.trim(),
                              'insurancePhone': insPhoneCtrl.text.trim(),
                              'nextMaintenanceKm': maintenanceCtrl.text.trim(),
                              'imageUrl': finalImageUrl,
                            };

                            if (isNew) {
                              saveInfo['status'] = "사용 가능";
                              saveInfo['currentUser'] = null;
                              saveInfo['destination'] = null;
                              saveInfo['returnTime'] = null;
                              saveInfo['useType'] = "단기/일반";
                              saveInfo['tireNext'] = "점검 요망";

                              await FirebaseFirestore.instance
                                  .collection('vehicles')
                                  .add(saveInfo);
                            } else {
                              await FirebaseFirestore.instance
                                  .collection('vehicles')
                                  .doc(vehicle['id'])
                                  .update(saveInfo);
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isNew
                                        ? "새 차량이 등록되었습니다."
                                        : "차량 정보가 수정되었습니다.",
                                  ),
                                  backgroundColor: tossBlue,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tossBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isUploading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: pureWhite,
                              strokeWidth: 3,
                            ),
                          )
                        : Text(
                            isNew ? "차량 등록하기" : "수정 사항 저장",
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: pureWhite,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: slate600,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black26),
        filled: true,
        fillColor: tossGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
