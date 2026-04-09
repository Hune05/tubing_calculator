import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class TubeReferencePage extends StatelessWidget {
  // 🚀 클래스 이름을 원래대로 복구!
  const TubeReferencePage({super.key}); // 🚀 생성자 이름도 복구!

  // 토스 스타일 & 마키타 테마 컬러
  static const Color makitaTeal = Color(0xFF007580);
  static const Color bgColor = Color(0xFFF2F4F6); // 토스 특유의 부드러운 회색 배경
  static const Color cardColor = Colors.white;
  static const Color textMain = Color(0xFF191F28);
  static const Color textSub = Color(0xFF8B95A1);
  static const Color highlightBg = Color(0xFFE8F3F4);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // 탭 개수
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const Text(
            "벤딩 실무 마스터",
            style: TextStyle(
              color: textMain,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          backgroundColor: cardColor, // 탭바와 자연스럽게 이어지도록 흰색 배경
          elevation: 0,
          centerTitle: false,
          iconTheme: const IconThemeData(color: textMain),
          // 🚀 토스 스타일의 깔끔한 탭바 적용
          bottom: const TabBar(
            indicatorColor: textMain,
            indicatorWeight: 3.0,
            labelColor: textMain,
            unselectedLabelColor: textSub,
            labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            dividerColor: Colors.transparent, // 기본 밑줄 제거 (깔끔함 유지)
            tabs: [
              Tab(text: "행동 지침서 (가이드)"),
              Tab(text: "실전 도표 (데이터)"),
            ],
          ),
        ),
        // 🚀 탭을 누르면 화면이 부드럽게 전환됨
        body: TabBarView(
          children: [
            _buildGuideTab(), // 첫 번째 탭: 30선 가이드
            _buildChartTab(), // 두 번째 탭: 10선 도표
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 1️⃣ 첫 번째 탭: 벤딩 마스터 가이드 (Top 30)
  // ==========================================
  Widget _buildGuideTab() {
    final List<Map<String, dynamic>> expertGuide = [
      {
        "category": "1. 튜브 제원 & 물리적 특성",
        "icon": LucideIcons.ruler,
        "color": Colors.blueGrey,
        "tips": [
          {"title": "1/4\" 튜브 반경", "desc": "외경 6.35mm / 벤딩 반경(R) 14.3mm"},
          {
            "title": "3/8\" 튜브 반경",
            "desc": "외경 9.52mm / 벤딩 반경(R) 23.8mm (가장 많이 씀)",
          },
          {"title": "1/2\" 튜브 반경", "desc": "외경 12.70mm / 벤딩 반경(R) 38.1mm"},
          {
            "title": "스프링백",
            "desc": "원하는 각도보다 1~3도 더 꺾어야 정확한 각이 나옴 (재질, 두께별 상이)",
          },
          {
            "title": "오벌리티",
            "desc": "급하게 꺾으면 배관이 타원형으로 눌림. 벤딩은 일정한 속도로 지그시 당길 것.",
          },
        ],
      },
      {
        "category": "2. 새들 (Saddle) 완벽 마스터",
        "icon": LucideIcons.rainbow,
        "color": makitaTeal,
        "tips": [
          {"title": "30도 마킹", "desc": "장애물 높이(H) × 2 (제일 계산하기 편함)"},
          {"title": "45도 마킹", "desc": "장애물 높이(H) × 1.414"},
          {
            "title": "수축량 보상",
            "desc": "가운데 평면(W) 마킹 시, 30도는 H×0.27 / 45도는 H×0.41 만큼 빼줄 것.",
          },
          {
            "title": "외경 실측",
            "desc": "도면 센터합계 + 반지름 (3/8\" 기준 약 +5mm) ➔ 줄자로 등 쟀을 때 나와야 함.",
          },
          {
            "title": "내경 실측",
            "desc": "도면 센터합계 - 반지름 ➔ 장애물이 타이트할 때 배가 닿지 않는지 확인.",
          },
        ],
      },
      {
        "category": "3. 오프셋 (Offset) & 롤링",
        "icon": Icons.call_made,
        "color": Colors.orange,
        "tips": [
          {"title": "오프셋 검수법", "desc": "바깥선 잴 필요 없음! 바닥에서 띄워진 '단차 높이'만 자로 확인."},
          {
            "title": "기장 손실 보상",
            "desc": "위로 뜬 만큼 파이프가 짧아지므로, 전체 기장 자를 때 수축량(Shrink)을 반드시 더할 것.",
          },
          {
            "title": "롤링 오프셋 진높이",
            "desc": "√(수평단차² + 수직단차²) ➔ 대각선 실제 도달 거리를 피타고라스로 계산.",
          },
          {
            "title": "병렬 오프셋",
            "desc": "배관 2개가 나란히 갈 때, 바깥쪽 배관의 마킹 시작점을 더 길게 잡아야 충돌 안 함.",
          },
          {
            "title": "롤 각도(Roll)",
            "desc": "벤더에 물린 파이프를 수평 기준 몇 도 비틀어 꺾을지 사전 계산 필수.",
          },
        ],
      },
      {
        "category": "4. 벤더기 조작 필수 기준",
        "icon": LucideIcons.wrench,
        "color": Colors.brown,
        "tips": [
          {
            "title": "'0' 눈금",
            "desc": "모든 굽힘의 시작점. 내 마킹선은 무조건 벤더의 '0'과 일치해야 함.",
          },
          {
            "title": "'R' 마크 활용",
            "desc": "90도 벤딩 시, 배관 끝단에서부터 길이를 재어왔을 때(정방향) 맞추는 눈금.",
          },
          {"title": "'L' 마크 활용", "desc": "반대로 파이프 시작점부터 치수를 쟀을 때 맞추는 눈금."},
          {
            "title": "롤러 핀 고정",
            "desc": "파이프를 물린 후 롤러가 들뜨지 않게 핀을 끝까지 확실히 밀어 넣을 것.",
          },
          {
            "title": "역방향 주의",
            "desc": "마킹을 뒤집어 물리면 각도와 길이가 완전히 박살 남. 항상 화살표 방향 확인.",
          },
        ],
      },
      {
        "category": "5. 초보자 치명적 실수 TOP 5",
        "icon": LucideIcons.alertTriangle,
        "color": Colors.redAccent,
        "tips": [
          {
            "title": "❌ 먼저 자르기",
            "desc": "[절대 금지] 도면 합계대로 미리 자르면 100% 짧아짐. 다 꺾고 마지막에 커팅할 것.",
          },
          {
            "title": "❌ 마킹선 먹기",
            "desc": "네임펜 두께(1~1.5mm)를 무시하면 4번 꺾을 때 6mm 오차 발생. 선의 중앙을 꺾을지 정할 것.",
          },
          {
            "title": "❌ 허공 꺾기",
            "desc": "3D 벤딩 시 반대로 꺾어 버리는 경우가 허다함. 꺾기 전 허공에 대고 손으로 시뮬레이션 필수.",
          },
          {
            "title": "❌ 짧은 직선구간",
            "desc": "마지막 피팅에 물릴 끝단은 '튜브 외경의 2.5배' 이상 직선을 유지해야 누설이 없음.",
          },
          {
            "title": "❌ 튜브 삽입 불량",
            "desc": "피팅 체결 시 튜브가 끝(턱)까지 닿지 않은 채로 조이면 고압 라인에서 1순위로 터짐.",
          },
        ],
      },
      {
        "category": "6. 고수로 가는 현장 꿀팁",
        "icon": LucideIcons.lightbulb,
        "color": Colors.deepPurple,
        "tips": [
          {
            "title": "💡 옷걸이 철사",
            "desc": "복잡한 3D 라인은 머리로 계산하지 말고, 얇은 철사를 가져가 미리 접어본 뒤 똑같이 꺾기.",
          },
          {
            "title": "💡 나만의 연신율",
            "desc":
                "같은 3/8\"라도 SUS, 동관 마다 늘어나는 값이 다름. 오늘 꺾은 파이프의 실측 차이를 메모할 것.",
          },
          {
            "title": "💡 마킹 지우기",
            "desc": "검은색 네임펜 자국은 아세톤이나 알콜스왑으로 깔끔하게 지워야 A급 마감 소리 들음.",
          },
          {
            "title": "💡 자투리 파이프",
            "desc": "버려지는 30cm 파이프에 100mm 마킹하고 90도 꺾어서 실제로 몇 mm 늘어나는지 직접 재보기.",
          },
          {
            "title": "💡 눈보다 줄자",
            "desc": "눈대중으로 '이쯤' 꺾는 버릇을 버릴 것. 모든 치수는 밀리미터(mm) 단위로 떨어져야 함.",
          },
        ],
      },
    ];

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: expertGuide.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final section = expertGuide[index];
        return _buildTossCard(
          title: section['category'],
          icon: section['icon'],
          iconColor: section['color'],
          children: section['tips'].map<Widget>((tip) {
            final isLast = tip == section['tips'].last;
            return Column(
              children: [
                _buildDataRow(tip['title'], tip['desc']),
                if (!isLast) _buildDivider(),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  // ==========================================
  // 2️⃣ 두 번째 탭: 실전 참고 도표 (데이터 10선)
  // ==========================================
  Widget _buildChartTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        _buildIntroBadge(),
        const SizedBox(height: 16),

        _buildTossCard(
          title: "1. 나만의 연신율 (Gain) 보정표",
          subtitle: "90도 벤딩 기준, 파이프가 늘어나는 양 (실측 데이터)",
          icon: LucideIcons.trendingUp,
          iconColor: makitaTeal,
          children: [
            _buildTossTable(
              headers: ["규격", "SUS 316L", "동관 (Copper)"],
              rows: [
                ["1/4\"", "+ 1.5 mm", "+ 1.8 mm"],
                ["3/8\"", "+ 2.5 mm", "+ 3.0 mm"],
                ["1/2\"", "+ 3.5 mm", "+ 4.2 mm"],
              ],
              footer: "※ 현장 벤더기 상태에 따라 ±0.5mm 오차 발생. 직접 꺾어보고 본인 값으로 수정하세요.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildTossCard(
          title: "2. 180도 U벤딩 (Return Bend)",
          subtitle: "파이프를 완전히 뒤집어 U턴 시킬 때",
          icon: LucideIcons.cornerUpLeft,
          iconColor: Colors.deepPurple,
          children: [
            _buildInfoRow(
              "강제 C-to-C 간격",
              "R × 2",
              "3/8\" 벤더(R=23.8) 사용 시 두 배관 사이는 무조건 47.6mm가 됨.",
            ),
            const Divider(height: 24, color: bgColor),
            _buildInfoRow(
              "소요 기장 계산",
              "(R × 3.14) + 직선",
              "U턴 곡선 구간 자체가 먹는 튜브 길이 = 약 75mm (3/8\" 기준)",
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildTossCard(
          title: "3. 각도별 오프셋 곱하기 계수",
          subtitle: "빗변(Travel)과 수축량(Shrink)을 구하는 마법의 숫자",
          icon: LucideIcons.calculator,
          iconColor: Colors.orange,
          children: [
            _buildTossTable(
              headers: ["벤딩 각도", "빗변 (Travel)", "수축량 (Shrink)"],
              rows: [
                ["22.5 도", "높이 × 2.61", "높이 × 0.20"],
                ["30 도", "높이 × 2.00", "높이 × 0.27"],
                ["45 도", "높이 × 1.41", "높이 × 0.41"],
                ["60 도", "높이 × 1.15", "높이 × 0.58"],
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildTossCard(
          title: "4. 90도 벤딩 셋백 (Set-back)",
          subtitle: "벽에서부터 얼마나 띄워서 마킹할 것인가",
          icon: LucideIcons.cornerRightDown,
          iconColor: Colors.blueGrey,
          children: [
            _buildTossTable(
              headers: ["규격", "벤딩 반경(R)", "셋백 (Set-back)"],
              rows: [
                ["1/4\"", "14.3 mm", "14.3 mm (R과 동일)"],
                ["3/8\"", "23.8 mm", "23.8 mm (R과 동일)"],
                ["1/2\"", "38.1 mm", "38.1 mm (R과 동일)"],
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildTossCard(
          title: "5. 새들 높이별 수축량 (30도 기준)",
          subtitle: "너비(W)에서 이 수치를 빼야 정확히 떨어짐",
          icon: LucideIcons.rainbow,
          iconColor: makitaTeal,
          children: [
            _buildTossTable(
              headers: ["장애물 높이 (H)", "수축량 (- 빼기)", "비고"],
              rows: [
                ["20 mm", "5.4 mm", "20 × 0.27"],
                ["30 mm", "8.1 mm", "30 × 0.27"],
                ["40 mm", "10.8 mm", "40 × 0.27"],
                ["50 mm", "13.5 mm", "50 × 0.27"],
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildTossCard(
          title: "6. 재질별 스프링백 (추가 꺾임각)",
          subtitle: "튕겨 오르는 성질을 고려해 벤더를 더 밀어줘야 하는 양",
          icon: LucideIcons.rotateCcw,
          iconColor: Colors.redAccent,
          children: [
            _buildTossTable(
              headers: ["재질", "두께 (T)", "추가 꺾임각"],
              rows: [
                ["동관 (Copper)", "0.8 ~ 1.0", "거의 없음 (0~1도)"],
                ["SUS 304", "1.0", "약 +2도 ~ +3도"],
                ["SUS 316L", "1.2 이상", "약 +3도 ~ +4도"],
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildTossCard(
          title: "7. 피팅 최소 직선 구간",
          subtitle: "파이프 끝에서 벤딩 시작점까지의 여유 (짧으면 누설)",
          icon: LucideIcons.pipette,
          iconColor: Colors.indigo,
          children: [
            _buildTossTable(
              headers: ["튜브 외경", "Swagelok 권장", "현장 마지노선"],
              rows: [
                ["1/4\"", "21 mm", "15 mm"],
                ["3/8\"", "24 mm", "18 mm"],
                ["1/2\"", "30 mm", "22 mm"],
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildTossCard(
          title: "8. 피팅 체결 (Make-up) 턴 수",
          subtitle: "손으로 꽉 조인 후 렌치로 돌리는 규정 바퀴 수",
          icon: LucideIcons.settings,
          iconColor: Colors.brown,
          children: [
            _buildTossTable(
              headers: ["튜브 사이즈", "최초 체결 시", "재체결 시"],
              rows: [
                ["~ 3/16\"", "3/4 바퀴 (9시➔6시)", "꽉 물린 느낌 후 약간만"],
                ["1/4\" ~ 1\"", "1과 1/4 바퀴 (9시➔12시)", "꽉 물린 느낌 후 약간만"],
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildTossCard(
          title: "9. 두께별 허용 사용 압력 (참고용)",
          subtitle: "SUS 316L 기준 허용 압력 (단위: bar)",
          icon: LucideIcons.gauge,
          iconColor: Colors.teal,
          children: [
            _buildTossTable(
              headers: ["외경", "0.89T", "1.24T", "1.65T"],
              rows: [
                ["1/4\"", "340 bar", "510 bar", "720 bar"],
                ["3/8\"", "220 bar", "330 bar", "460 bar"],
                ["1/2\"", "-", "240 bar", "330 bar"],
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildTossCard(
          title: "10. 네임펜 마킹선 1.5mm 보정법",
          subtitle: "선의 두께 때문에 4번 꺾으면 6mm가 틀어집니다.",
          icon: LucideIcons.edit2,
          iconColor: Colors.deepOrange,
          children: [
            _buildInfoRow(
              "왼쪽으로 배관이 갈 때",
              "마킹선의 우측 타격",
              "벤더의 0점이 마킹선의 우측 끝에 닿게",
            ),
            const Divider(height: 24, color: bgColor),
            _buildInfoRow(
              "오른쪽으로 배관이 갈 때",
              "마킹선의 좌측 타격",
              "벤더의 0점이 마킹선의 좌측 끝에 닿게",
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ==========================================
  // 🛠️ 공통 UI 컴포넌트 (토스 스타일)
  // ==========================================

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
              "이 도표들은 이론값이 아닌 '현장 실무' 기준입니다. 본인의 벤더기 상태나 파이프 재질에 따라 미세한 오차가 있을 수 있으니, 항상 테스트 후 본인만의 데이터를 완성하세요.",
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
    String? subtitle,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
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
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textSub,
              ),
            ),
          ],
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  // 좌측 타이틀, 우측 내용 (가이드용)
  Widget _buildDataRow(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textMain,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              desc,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textSub,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 타이틀 + 내용 나열용 (도표용)
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

  // 토스 스타일 테이블
  Widget _buildTossTable({
    required List<String> headers,
    required List<List<String>> rows,
    String? footer,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

  // 구분선
  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(color: bgColor, height: 1, thickness: 1),
    );
  }
}
