import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:tubing_calculator/src/core/database/database_helper.dart';

// 💡 [경로 확인] 본인 프로젝트에 맞는 경로 활성화
import '../../fabrication/screens/fabrication_detail_screen.dart';

// 💡 실무용 컬러 팔레트 (눈이 편안한 슬레이트 톤 추가)
const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color slate50 = Color(0xFFF8FAFC);
const Color pureWhite = Color(0xFFFFFFFF);

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // 프로젝트 이름을 키(Key)로, 해당 프로젝트의 도면 리스트를 값(Value)으로 가지는 Map
  Map<String, List<Map<String, dynamic>>> _groupedHistory = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshHistory();
  }

  Future<void> _refreshHistory() async {
    setState(() => _isLoading = true);

    // 🔥 에러 수정 완료: readAllHistory() -> getHistory() 로 변경!
    final data = await DatabaseHelper.instance.getHistory();

    // 🚀 [디테일 1] 비동기 작업(await) 후 화면이 닫혔으면 멈춤 (앱 튕김 방지)
    if (!mounted) return;

    // 데이터를 프로젝트(폴더)별로 그룹화
    Map<String, List<Map<String, dynamic>>> tempGrouped = {};
    for (var item in data) {
      String rawPtoP = item['p_to_p'] ?? '{}';
      String project = "미지정 프로젝트";
      try {
        var pData = jsonDecode(rawPtoP);
        // 저장 시 입력한 프로젝트명이 빈 칸이 아니면 사용
        if (pData['project'] != null &&
            pData['project'].toString().trim().isNotEmpty) {
          project = pData['project'];
        }
      } catch (_) {}

      if (!tempGrouped.containsKey(project)) {
        tempGrouped[project] = [];
      }
      tempGrouped[project]!.add(item);
    }

    // 🚀 [디테일 2] 폴더 안의 도면들을 '최신순(ID 내림차순)'으로 정렬
    tempGrouped.forEach((key, list) {
      list.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
    });

    setState(() {
      _groupedHistory = tempGrouped;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slate50, // 💡 전체 배경을 눈이 편안한 오프화이트로
      appBar: AppBar(
        title: const Text(
          '제작 보관함',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        backgroundColor: makitaTeal,
        foregroundColor: pureWhite,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: makitaTeal))
          : _groupedHistory.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    '저장된 도면이 없습니다.',
                    style: TextStyle(
                      color: slate600,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _groupedHistory.keys.length,
              itemBuilder: (context, index) {
                String folderName = _groupedHistory.keys.elementAt(index);
                List<Map<String, dynamic>> folderItems =
                    _groupedHistory[folderName]!;

                // 아코디언 형태의 폴더 디자인 (화이트 테마)
                return Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: pureWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: index == 0,
                      iconColor: makitaTeal,
                      collapsedIconColor: slate600,
                      leading: const Icon(
                        Icons.folder,
                        color: makitaTeal,
                        size: 28,
                      ),
                      title: Text(
                        "$folderName (${folderItems.length})",
                        style: const TextStyle(
                          color: slate900,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      children: folderItems.map((item) {
                        String rawPtoP = item['p_to_p'] ?? '{}';
                        String fromTo = "경로 미상";
                        try {
                          var pData = jsonDecode(rawPtoP);
                          fromTo = "${pData['from']} ➔ ${pData['to']}";
                        } catch (_) {}

                        // 총 컷팅 길이 반올림 처리
                        double cutRaw =
                            double.tryParse(item['total_length'].toString()) ??
                            0.0;
                        int cutDisplay = cutRaw.round();

                        return Container(
                          margin: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 12,
                          ),
                          decoration: BoxDecoration(
                            color: slate100, // 💡 폴더 안의 파일은 살짝 회색으로 구분감 부여
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            onTap: () async {
                              // 상세 화면으로 이동
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      FabricationDetailScreen(itemData: item),
                                ),
                              );
                              // 🚀 [디테일 3] 뒤로가기 눌러서 돌아왔을 때 안전하게 새로고침
                              if (!mounted) return;
                              _refreshHistory();
                            },
                            title: Text(
                              fromTo,
                              style: const TextStyle(
                                color: makitaTeal,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.straighten,
                                        size: 14,
                                        color: slate600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Total Cut: $cutDisplay mm",
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        "Size: ${item['pipe_size']}",
                                        style: const TextStyle(
                                          color: slate600,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "날짜: ${item['date']?.toString().substring(0, 10) ?? ''}",
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.red.shade400,
                              ),
                              onPressed: () async {
                                // 💡 삭제 확인 팝업
                                bool? confirm = await showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: pureWhite,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    title: const Text(
                                      "삭제 확인",
                                      style: TextStyle(
                                        color: slate900,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    content: const Text(
                                      "이 도면을 보관함에서 영구 삭제하시겠습니까?",
                                      style: TextStyle(color: slate600),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text(
                                          "취소",
                                          style: TextStyle(
                                            color: slate600,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: Text(
                                          "삭제",
                                          style: TextStyle(
                                            color: Colors.red.shade600,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await DatabaseHelper.instance.deleteHistory(
                                    item['id'],
                                  );
                                  // 🚀 [디테일 4] 삭제 완료 후 팝업 닫힌 뒤 안전하게 새로고침
                                  if (!mounted) return;
                                  _refreshHistory();
                                }
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
