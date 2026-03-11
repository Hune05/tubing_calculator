import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/fitting_item.dart';

const Color pureWhite = Colors.white;
const Color makitaTeal = Color(0xFF007580);
const Color textDark = Color(0xFF1A1A1A);
const Color lightBg = Color(0xFFF0F3F5);

class SmartFittingSelectorSheet extends StatefulWidget {
  final String maker;

  const SmartFittingSelectorSheet({super.key, required this.maker});

  static Future<FittingItem?> show(BuildContext context, String maker) {
    return showModalBottomSheet<FittingItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SmartFittingSelectorSheet(maker: maker),
    );
  }

  @override
  State<SmartFittingSelectorSheet> createState() =>
      _SmartFittingSelectorSheetState();
}

class _SmartFittingSelectorSheetState extends State<SmartFittingSelectorSheet> {
  String selectedSize = "1/2";
  String selectedGroup = "FITTING";
  String selectedSubCategory = "유니온류";

  final Map<String, List<String>> fittingSubCategories = {
    '유니온류': [
      'UNI',
      'BLK_UNI',
      'EL90',
      'EL45',
      'TEE',
      'CRS',
      'RED',
      'PORT_CONN',
      'ADAPTER',
    ],
    '커넥터류': [
      'M_CONN',
      'F_CONN',
      'M_EL90',
      'F_EL90',
      'M_RUN_TEE',
      'F_RUN_TEE',
      'M_BRN_TEE',
      'F_BRN_TEE',
    ],
    '어저스트류': ['ADJ_EL90', 'ADJ_RUN_TEE', 'ADJ_BRN_TEE'],
    '마감류(캡/플러그)': ['CAP', 'PLUG'],
  };

  final Map<String, List<String>> valveSubCategories = {
    '볼/니들': ['V_BALL', 'V_NEEDLE', 'V_MANI', 'V_BLEED'],
    '체크/릴리프': ['V_CHECK', 'V_RELIEF'],
  };

  final List<String> inchSizes = ["1/4", "3/8", "1/2", "3/4", "1"];
  final List<String> metricSizes = ["8mm", "10mm", "12mm"];

  void _onGroupChanged(String newGroup) {
    setState(() {
      selectedGroup = newGroup;
      if (newGroup == 'FITTING') {
        selectedSubCategory = '유니온류';
      } else if (newGroup == 'VALVE') {
        selectedSubCategory = '볼/니들';
      } else {
        selectedSubCategory = '전체';
      }
    });
  }

  Widget _buildCategoryBadge(String category) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: makitaTeal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: makitaTeal.withValues(alpha: 0.5)),
      ),
      child: Text(
        category.replaceAll('_', '\n'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: category.length > 4 ? 10 : 13,
          fontWeight: FontWeight.w900,
          color: makitaTeal,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildSizeButton(String size) {
    bool isSelected = selectedSize == size;
    return GestureDetector(
      onTap: () => setState(() => selectedSize = size),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? makitaTeal : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? makitaTeal : Colors.transparent,
          ),
        ),
        child: Text(
          size,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isSelected ? pureWhite : textDark,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90,
        decoration: const BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: makitaTeal,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.only(
                top: 12,
                bottom: 20,
                left: 24,
                right: 24,
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.account_tree,
                        color: pureWhite,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "${widget.maker} 부속 검색",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: pureWhite,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Padding(
              padding: EdgeInsets.only(left: 24, right: 24, bottom: 8),
              child: Text(
                "1. 튜브 규격",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: inchSizes
                          .map((s) => _buildSizeButton(s))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: metricSizes
                          .map((s) => _buildSizeButton(s))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Padding(
              padding: EdgeInsets.only(left: 24, right: 24, bottom: 8),
              child: Text(
                "2. 대분류",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: ["FITTING", "VALVE", "FLANGE", "SPECIAL"].map((
                  group,
                ) {
                  bool isSelected = selectedGroup == group;
                  String display = group == 'FITTING'
                      ? '피팅'
                      : group == 'VALVE'
                      ? '밸브'
                      : group == 'FLANGE'
                      ? '플랜지'
                      : '기타';
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onGroupChanged(group),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? makitaTeal : pureWhite,
                          border: Border.all(
                            color: isSelected
                                ? makitaTeal
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          display,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? pureWhite
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            if (selectedGroup == 'FITTING' || selectedGroup == 'VALVE') ...[
              const Padding(
                padding: EdgeInsets.only(left: 24, right: 24, bottom: 8),
                child: Text(
                  "3. 상세 종류 (Sub-Category)",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children:
                      (selectedGroup == 'FITTING'
                              ? fittingSubCategories.keys
                              : valveSubCategories.keys)
                          .map((subCat) {
                            bool isSelected = selectedSubCategory == subCat;
                            // 🚀 버그 수정: 상세 종류(Sub-Category)에서 ChoiceChip의 기본 다크 테마를 박살 내기 위해 GestureDetector로 완전 교체!
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => selectedSubCategory = subCat,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected ? makitaTeal : pureWhite,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? makitaTeal
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    subCat,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? pureWhite
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],

            const Divider(height: 1, thickness: 2, color: Color(0xFFEEEEEE)),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('fittings')
                    .where('maker', isEqualTo: widget.maker)
                    .where('tubeOD', isEqualTo: selectedSize)
                    .where('group', isEqualTo: selectedGroup)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(
                      child: CircularProgressIndicator(color: makitaTeal),
                    );
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        "데이터가 없습니다.",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }

                  var allDocs = snapshot.data!.docs;
                  var filteredDocs = allDocs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String cat = data['category'] ?? '';

                    if (selectedGroup == 'FITTING') {
                      return fittingSubCategories[selectedSubCategory]
                              ?.contains(cat) ??
                          false;
                    } else if (selectedGroup == 'VALVE') {
                      return valveSubCategories[selectedSubCategory]?.contains(
                            cat,
                          ) ??
                          false;
                    }
                    return true;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Text(
                        "선택한 분류에 해당하는 부속이 없습니다.",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filteredDocs.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      var data =
                          filteredDocs[index].data() as Map<String, dynamic>;

                      FittingItem item = FittingItem(
                        id: data['id'] ?? 'unknown',
                        tubeOD: data['tubeOD'] ?? '',
                        category: data['category'] ?? '',
                        name: data['displayName'] ?? data['name'] ?? '',
                        maker: data['maker'] ?? '',
                        deduction:
                            (data['deduction'] as num?)?.toDouble() ?? 0.0,
                        icon: Icons.settings,
                      );

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        leading: _buildCategoryBadge(item.category),
                        title: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                        subtitle: Text(
                          "${item.maker} | ${item.tubeOD}",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Text(
                          "- ${item.deduction} mm",
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).pop(item);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
