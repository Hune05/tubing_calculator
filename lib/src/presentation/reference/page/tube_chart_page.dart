import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class TubeChartPage extends StatelessWidget {
  const TubeChartPage({super.key});

  static const Color makitaTeal = Color(0xFF007580);
  static const Color bgColor = Color(0xFFF2F4F6); // 토스 배경
  static const Color cardColor = Colors.white;
  static const Color textMain = Color(0xFF191F28);
  static const Color textSub = Color(0xFF8B95A1);
  static const Color highlightBg = Color(0xFFE8F3F4);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "벤딩 실전 참고 도표",
          style: TextStyle(
            color: textMain,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: textMain),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          _buildIntroBadge(),
          const SizedBox(height: 16),

          // 1. 나만의 연신율 (Gain) 데이터표
          _buildTossCard(
            title: "1. 나만의 연신율 (Gain) 보정표",
            subtitle: "90도 벤딩 기준, 재질별 파이프가 늘어나는 양 (실측 데이터)",
            icon: LucideIcons.trendingUp,
            iconColor: makitaTeal,
            child: _buildTossTable(
              headers: ["규격", "SUS 316L", "동관 (Copper)", "알루미늄"],
              rows: [
                ["1/4\"", "+ 1.5 mm", "+ 1.8 mm", "+ 2.0 mm"],
                ["3/8\"", "+ 2.5 mm", "+ 3.0 mm", "+ 3.2 mm"],
                ["1/2\"", "+ 3.5 mm", "+ 4.2 mm", "+ 4.5 mm"],
              ],
              footer: "※ 현장 벤더기 상태에 따라 ±0.5mm 오차 발생 가능 (테스트 후 본인만의 값으로 수정하세요)",
            ),
          ),
          const SizedBox(height: 16),

          // 2. 180도 U벤딩 (Return Bend)
          _buildTossCard(
            title: "2. 180도 U벤딩 (Return Bend)",
            subtitle: "파이프를 완전히 뒤집어 U턴 시킬 때의 치수",
            icon: LucideIcons.cornerUpLeft,
            iconColor: Colors.deepPurple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  "강제 C-to-C 간격",
                  "벤더 반지름(R) × 2",
                  "3/8\" 벤더(R=23.8) 사용 시 두 배관 사이는 무조건 47.6mm가 됨.",
                ),
                const Divider(height: 24, color: bgColor),
                _buildInfoRow(
                  "총 소요 기장 계산",
                  "(R × 3.14) + 직선 구간",
                  "U턴 구간 자체가 먹는 튜브 길이 = 약 75mm (3/8\" 기준)",
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. 각도별 오프셋 계수표 (Multiplier)
          _buildTossCard(
            title: "3. 각도별 오프셋 곱하기 계수",
            subtitle: "빗변(Travel)과 수축량(Shrink)을 구하는 마법의 숫자",
            icon: LucideIcons.calculator,
            iconColor: Colors.orange,
            child: _buildTossTable(
              headers: ["벤딩 각도", "빗변 (Travel)", "수축량 (Shrink)"],
              rows: [
                ["15 도", "높이 × 3.86", "높이 × 0.13"],
                ["22.5 도", "높이 × 2.61", "높이 × 0.20"],
                ["30 도", "높이 × 2.00", "높이 × 0.27"],
                ["45 도", "높이 × 1.41", "높이 × 0.41"],
                ["60 도", "높이 × 1.15", "높이 × 0.58"],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. 90도 벤딩 셋백 (Set-back) 표
          _buildTossCard(
            title: "4. 90도 벤딩 셋백 (Set-back)",
            subtitle: "벽에서부터 얼마나 띄워서 마킹할 것인가",
            icon: LucideIcons.cornerRightDown,
            iconColor: Colors.blueGrey,
            child: _buildTossTable(
              headers: ["규격", "벤딩 반경 (R)", "셋백 (Set-back)"],
              rows: [
                ["1/4\"", "14.3 mm", "14.3 mm (R과 동일)"],
                ["3/8\"", "23.8 mm", "23.8 mm (R과 동일)"],
                ["1/2\"", "38.1 mm", "38.1 mm (R과 동일)"],
              ],
              footer: "※ 90도는 R값 자체가 셋백입니다. 벽 끝선에서 R값만큼 뒤로 물러나서 마킹하세요.",
            ),
          ),
          const SizedBox(height: 16),

          // 5. 새들 높이별 수축량 (Shrink) 요약표
          _buildTossCard(
            title: "5. 새들(Saddle) 높이별 수축량 (30도 기준)",
            subtitle: "W(너비)에서 이 수치를 빼야 첫 번째 마킹이 정확히 떨어짐",
            icon: LucideIcons.rainbow,
            iconColor: makitaTeal,
            child: _buildTossTable(
              headers: ["장애물 높이 (H)", "수축량 (- 빼기)", "비고"],
              rows: [
                ["20 mm", "5.4 mm", "20 × 0.27"],
                ["30 mm", "8.1 mm", "30 × 0.27"],
                ["40 mm", "10.8 mm", "40 × 0.27"],
                ["50 mm", "13.5 mm", "50 × 0.27"],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 6. 재질별 스프링백 (Spring-back) 보정
          _buildTossCard(
            title: "6. 재질별 스프링백 (더 꺾어야 하는 각도)",
            subtitle: "원하는 각도를 얻기 위해 벤더를 더 밀어줘야 하는 양",
            icon: LucideIcons.rotateCcw,
            iconColor: Colors.redAccent,
            child: _buildTossTable(
              headers: ["재질", "두께 (T)", "추가 꺾임각 (예상)"],
              rows: [
                ["동관 (Copper)", "0.8 ~ 1.0", "거의 없음 (0~1도)"],
                ["SUS 304", "1.0", "약 +2도 ~ +3도"],
                ["SUS 316L", "1.2 이상", "약 +3도 ~ +4도"],
              ],
              footer: "※ SUS는 강성이 높아 튕겨 오릅니다. 90도 벤딩 시 눈금상 93도 언저리까지 당겨야 합니다.",
            ),
          ),
          const SizedBox(height: 16),

          // 7. 피팅(Fitting) 최소 직선 구간
          _buildTossCard(
            title: "7. 피팅 물림 최소 직선 구간",
            subtitle: "파이프 끝에서 벤딩 시작점까지 남겨둬야 할 최소 여유 (짧으면 누설 됨)",
            icon: LucideIcons.pipette,
            iconColor: Colors.indigo,
            child: _buildTossTable(
              headers: ["튜브 외경", "Swagelok 권장", "현장 최소 마지노선"],
              rows: [
                ["1/4\"", "21 mm", "15 mm"],
                ["3/8\"", "24 mm", "18 mm"],
                ["1/2\"", "30 mm", "22 mm"],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 8. 체결 (Make-up) 규정 턴(Turn) 수
          _buildTossCard(
            title: "8. 튜브 피팅 체결 (Make-up) 규정",
            subtitle: "렌치로 돌리는 바퀴 수 (손으로 꽉 조인 후 기준)",
            icon: LucideIcons.settings,
            iconColor: Colors.brown,
            child: _buildTossTable(
              headers: ["튜브 사이즈", "최초 체결 시", "재체결 시 (Re-make)"],
              rows: [
                ["1/16\" ~ 3/16\"", "3/4 바퀴 (9시 ➔ 6시)", "너트가 조여진 느낌 후 약간만"],
                ["1/4\" ~ 1\"", "1과 1/4 바퀴 (9시 ➔ 12시)", "너트가 꽉 물린 느낌 후 약간만"],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 9. 안전 사용 압력 참고 (SUS 316 기준)
          _buildTossCard(
            title: "9. 두께별 허용 사용 압력 (참고용)",
            subtitle: "두께(T)가 얇은데 고압 라인에 쓰면 터집니다 (단위: bar)",
            icon: LucideIcons.gauge,
            iconColor: Colors.teal,
            child: _buildTossTable(
              headers: ["외경", "0.89T", "1.24T", "1.65T"],
              rows: [
                ["1/4\"", "340 bar", "510 bar", "720 bar"],
                ["3/8\"", "220 bar", "330 bar", "460 bar"],
                ["1/2\"", "-", "240 bar", "330 bar"],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 10. 마킹선(Marker) 오차 보정 요령
          _buildTossCard(
            title: "10. 네임펜 마킹선 오차 보정 요령",
            subtitle: "마킹펜 두께 1.5mm 때문에 발생하는 기장 틀어짐 방지법",
            icon: LucideIcons.edit2,
            iconColor: Colors.deepOrange,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  "왼쪽으로 갈 때",
                  "마킹선의 우측을 타격",
                  "벤더의 0점이 마킹선의 오른쪽 끝에 닿게 세팅",
                ),
                const Divider(height: 24, color: bgColor),
                _buildInfoRow(
                  "오른쪽으로 갈 때",
                  "마킹선의 좌측을 타격",
                  "벤더의 0점이 마킹선의 왼쪽 끝에 닿게 세팅",
                ),
                const SizedBox(height: 12),
                Text(
                  "※ 4포인트 벤딩 시 선의 중앙을 꺾으면 1.5mm × 4번 = 6mm의 치수 오차가 발생합니다. 항상 선의 어느 면을 벤딩 0점에 맞출지 통일하세요.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.deepOrange.shade400,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // 상단 안내 뱃지
  Widget _buildIntroBadge() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: makitaTeal.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.info, color: makitaTeal, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "이 도표들은 이론값이 아닌 '현장 실무'를 기준으로 작성되었습니다. 본인의 벤더기 상태나 파이프 재질에 따라 미세한 오차가 있을 수 있으니, 첫 작업 시 여유분을 두고 테스트하여 본인만의 데이터를 완성하세요.",
              style: TextStyle(
                color: textMain.withOpacity(0.8),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 토스 스타일 카드
  Widget _buildTossCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textMain,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textSub,
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  // 🚀 토스 스타일의 깔끔한 데이터 테이블 (표) 생성기
  Widget _buildTossTable({
    required List<String> headers,
    required List<List<String>> rows,
    String? footer,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: headers
                .map(
                  (h) => Expanded(
                    child: Text(
                      h,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textSub,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        // 로우 데이터
        ...rows.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: row
                  .map(
                    (cell) => Expanded(
                      child: Text(
                        cell,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textMain,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                  .toList(),
            ),
          );
        }),
        // 푸터 (주의사항 등)
        if (footer != null) ...[
          const SizedBox(height: 12),
          Text(
            footer,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.redAccent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  // 타이틀 + 내용 나열용 (표 형태가 아닐 때)
  Widget _buildInfoRow(String title, String value, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textSub,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textMain,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          desc,
          style: const TextStyle(fontSize: 13, color: textSub, height: 1.4),
        ),
      ],
    );
  }
}
