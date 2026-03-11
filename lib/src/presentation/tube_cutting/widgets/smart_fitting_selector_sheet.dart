import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/fitting_item.dart';

// 화이트 & 마키타 테마
const Color whiteCard = Colors.white;
const Color makitaTeal = Color(0xFF007580);
const Color textPrimary = Colors.black87;
const Color textSecondary = Colors.black54;

class SmartFittingSelectorSheet extends StatelessWidget {
  final String tubeSize; // 메인 화면에서 받아올 배관 규격

  const SmartFittingSelectorSheet({super.key, required this.tubeSize});

  // 바텀 시트를 띄우는 static 함수 (tubeSize 파라미터 추가됨)
  static Future<FittingItem?> show(BuildContext context, String tubeSize) {
    return showModalBottomSheet<FittingItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // 둥근 모서리 적용을 위해 투명하게
      builder: (context) => SmartFittingSelectorSheet(tubeSize: tubeSize),
    );
  }

  // 🌟 중요: 파이어베이스의 문자열을 Flutter의 IconData로 변환해주는 헬퍼 함수
  IconData _getIconFromString(String iconString) {
    // DB에 올리신 iconString 값에 맞춰서 원하는 아이콘으로 매핑해 주세요!
    switch (iconString) {
      case 'elbow_90':
        return Icons.turn_right;
      case 'elbow_45':
        return Icons.turn_slight_right;
      case 'tee':
        return Icons.call_split;
      case 'coupling':
        return Icons.horizontal_rule;
      // 기본값
      default:
        return Icons.build_circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7, // 화면의 70% 높이 차지
      decoration: const BoxDecoration(
        color: whiteCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 상단 손잡이(핸들) 영역
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          // 타이틀 영역
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                const Icon(
                  Icons.settings_input_component,
                  color: makitaTeal,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  "$tubeSize 규격 부속 선택",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.black12),

          // 파이어베이스 데이터 리스트 영역
          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              // 🚀 핵심 쿼리: fittings 컬렉션에서 사이즈가 일치하는 것만 가져옵니다.
              future: FirebaseFirestore.instance
                  .collection('fittings')
                  .where('size', isEqualTo: tubeSize)
                  .get(
                    const GetOptions(source: Source.serverAndCache),
                  ), // 캐시 우선, 없으면 서버
              builder: (context, snapshot) {
                // 1. 로딩 중일 때
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: makitaTeal),
                  );
                }

                // 2. 에러가 났을 때
                if (snapshot.hasError) {
                  return const Center(child: Text("데이터를 불러오는 중 오류가 발생했습니다."));
                }

                // 3. 데이터가 비어있을 때
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      "$tubeSize 규격에 등록된 부속이 없습니다.",
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                // 4. 데이터가 정상적으로 들어왔을 때 리스트 렌더링
                var docs = snapshot.data!.docs;

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;

                    // 💡 수정된 부분: FittingItem 모델의 최신 파라미터에 맞게 매핑
                    FittingItem item = FittingItem(
                      id: data['id'] ?? 'unknown',
                      // size 대신 tubeOD로 할당 (DB 필드가 size인 것을 감안해 호환성 유지)
                      tubeOD: data['tubeOD'] ?? data['size'] ?? '',
                      // type 대신 category로 할당
                      category: data['category'] ?? data['type'] ?? '',
                      name: data['name'] ?? '이름 없음',
                      maker: data['maker'] ?? '',
                      deduction: (data['deduction'] as num?)?.toDouble() ?? 0.0,
                      icon: _getIconFromString(data['iconString'] ?? ''),
                    );

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: makitaTeal.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item.icon, color: makitaTeal),
                      ),
                      title: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        item.maker,
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Text(
                        "- ${item.deduction} mm",
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      onTap: () {
                        // 클릭 시 선택된 아이템을 메인 화면으로 돌려보냄
                        Navigator.pop(context, item);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
