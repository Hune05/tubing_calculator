import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class TubeReferencePage extends StatelessWidget {
  const TubeReferencePage({super.key});

  // 토스 스타일 & 마키타 테마 컬러
  static const Color makitaTeal = Color(0xFF007580);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color bgColor = Color(0xFFF2F4F6);
  static const Color cardColor = Colors.white;
  static const Color textMain = Color(0xFF191F28);
  static const Color textSub = Color(0xFF8B95A1);
  static const Color highlightBg = Color(0xFFE8F3F4);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
          backgroundColor: cardColor,
          elevation: 0,
          centerTitle: false,
          iconTheme: const IconThemeData(color: textMain),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: textMain,
            indicatorWeight: 3.0,
            labelColor: textMain,
            unselectedLabelColor: textSub,
            labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: "행동 지침서"),
              Tab(text: "실전 도표"),
              Tab(text: "장비 사용법"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildGuideTab(), // 1. 30선 가이드
            _buildChartTab(), // 2. 10선 도표
            _buildMachineGuideTab(), // 3. 장비 사용법 (NC 벤더 반영)
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 1️⃣ 첫 번째 탭: 벤딩 마스터 가이드
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
  // 2️⃣ 두 번째 탭: 실전 참고 도표 (업그레이드 버전)
  // ==========================================
  Widget _buildChartTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        _buildIntroBadge(
          "이 도표들은 이론값이 아닌 '현장 실무' 기준입니다. 특히 U벤딩 시 공간 간섭을 피하기 위해 도면상의 '센터'보다 실제 파이프가 차지하는 '외경 폭'을 우선적으로 확인하세요.",
        ),
        const SizedBox(height: 16),

        // 📈 1. 연신율 보정표 (1/4" ~ 1" 확장 / 외경+센터 기준)
        _buildTossCard(
          title: "1. 90도 연신율 (Gain) 보정표",
          subtitle: "마킹 위치에 따른 파이프 늘어남 보상값 (SUS 316L 기준)",
          icon: LucideIcons.trendingUp,
          iconColor: makitaTeal,
          children: [
            _buildDataRow("외경 기준 (O.D)", "줄자로 파이프 바깥쪽(등)을 쟀을 때의 마킹 기준 (현장 추천)"),
            _buildDataRow("센터 기준 (C.L)", "파이프 중심선 기준 (도면 치수 확인용)"),
            const SizedBox(height: 16),
            _buildTossTable(
              headers: [
                "규격\n(OD)",
                "표준 벤딩\n반경(R)",
                "외경 기준\n(추천)",
                "센터 기준\n(참고)",
              ],
              rows: [
                ["1/4\"", "14.3", "+ 3.5 mm", "+ 1.5 mm"],
                ["3/8\"", "23.8", "+ 5.5 mm", "+ 2.5 mm"],
                ["1/2\"", "38.1", "+ 8.0 mm", "+ 3.5 mm"],
                ["3/4\"", "57.2", "+ 12.0 mm", "+ 5.5 mm"],
                ["1\"", "76.2", "+ 16.0 mm", "+ 7.5 mm"],
              ],
              footer: "※ 표준 수동/NC 벤더(R값) 기준입니다. 현장 장비에 따라 ±1mm 오차가 발생할 수 있습니다.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 🔄 2. 180도 U벤딩 표 (1/4" ~ 1" 확장 / 외경 폭 우선)
        _buildTossCard(
          title: "2. 180도 U벤딩 (Return Bend)",
          subtitle: "배관을 완전히 뒤집을 때 차지하는 공간 및 소요 기장",
          icon: LucideIcons.cornerUpLeft,
          iconColor: Colors.deepPurple,
          children: [
            _buildDataRow("외경 폭 (O-to-O)", "두 배관의 바깥쪽 끝단 넓이 (장애물/벽면 간섭 확인용)"),
            _buildDataRow("센터 간격 (C-to-C)", "두 배관의 중심선 사이 거리 (2 × R)"),
            const SizedBox(height: 16),
            _buildTossTable(
              headers: [
                "규격\n(OD)",
                "외경 전체 폭\n(O-to-O)",
                "센터 간격\n(C-to-C)",
                "곡선부 소요\n기장(R×π)",
              ],
              rows: [
                ["1/4\"", "35.0 mm", "28.6 mm", "45 mm"],
                ["3/8\"", "57.1 mm", "47.6 mm", "75 mm"],
                ["1/2\"", "88.9 mm", "76.2 mm", "120 mm"],
                ["3/4\"", "133.5 mm", "114.4 mm", "180 mm"],
                ["1\"", "177.8 mm", "152.4 mm", "239 mm"],
              ],
              footer: "※ 곡선부 소요 기장: U턴 라운드 구간 자체를 만드는 데 순수하게 소모되는 튜브 길이입니다.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 📐 3. 오프셋 계산표
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
        const SizedBox(height: 40),

        // 🔩 4. 피팅 체결 치수표 (매우 중요)
        _buildTossCard(
          title: "4. 피팅 삽입 깊이 & 최소 직선 구간",
          subtitle: "최종 컷팅 기장 계산 및 너트 체결 공간 확보용 (Swagelok 기준)",
          icon: Icons.compress,
          iconColor: Colors.blueAccent,
          children: [
            _buildDataRow("삽입 깊이 (A)", "피팅 내부로 파이프가 밀려 들어가는 실제 깊이 (기장 더하기)"),
            _buildDataRow("최소 직선 (B)", "벤딩 끝단에서 튜브 끝까지 확보해야 너트와 페룰이 들어가는 길이"),
            const SizedBox(height: 16),
            _buildTossTable(
              headers: [
                "규격\n(OD)",
                "피팅 삽입 깊이\n(Insertion)",
                "최소 직선 구간\n(Min. Straight)",
              ],
              rows: [
                ["1/4\"", "15.0 mm", "21.0 mm"],
                ["3/8\"", "17.0 mm", "24.0 mm"],
                ["1/2\"", "23.0 mm", "30.0 mm"],
                ["3/4\"", "24.0 mm", "38.0 mm"],
                ["1\"", "31.0 mm", "48.0 mm"],
              ],
              footer: "※ 현장에서는 계산 편의상 소수점을 반올림하여 사용합니다.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 🌉 5. 새들 (Saddle) 보정표
        _buildTossCard(
          title: "5. 장애물 통과 (Saddle) 보정표",
          subtitle: "배관이 장애물을 타고 넘을 때 (45도 기준)",
          icon: LucideIcons.rainbow,
          iconColor: Colors.teal,
          children: [
            _buildDataRow("마킹 간격", "장애물 높이 × 1.41 (가운데 기준점에서 양옆으로 띄우는 거리)"),
            _buildDataRow("수축 보상", "장애물을 넘느라 파이프가 당겨지는 양 (전체 기장 자를 때 추가)"),
            const SizedBox(height: 16),
            _buildTossTable(
              headers: ["장애물 높이\n(H)", "마킹 간격\n(거리)", "전체 수축량\n(Shrink)"],
              rows: [
                ["50 mm", "71 mm", "20 mm"],
                ["100 mm", "141 mm", "41 mm"],
                ["150 mm", "212 mm", "62 mm"],
                ["200 mm", "283 mm", "82 mm"],
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 🔙 6. 스프링백 참고표
        _buildTossCard(
          title: "6. 재질별 스프링백 (Springback)",
          subtitle: "목표 각도를 얻기 위해 기계에 추가로 꺾어야 하는 값",
          icon: LucideIcons.refreshCcw,
          iconColor: Colors.pinkAccent,
          children: [
            _buildTossTable(
              headers: [
                "규격\n(OD)",
                "동관\n(Copper)",
                "SUS 316L\n(0.035~0.049T)",
                "SUS 316L\n(0.065T 이상)",
              ],
              rows: [
                ["1/4\"", "+ 0.5° ~ 1°", "+ 1.5° ~ 2°", "+ 2° ~ 3°"],
                ["3/8\"", "+ 1°", "+ 2° ~ 2.5°", "+ 3° ~ 4°"],
                ["1/2\"", "+ 1° ~ 1.5°", "+ 2.5° ~ 3°", "+ 3.5° ~ 5°"],
              ],
              footer: "※ 두께(T)가 두꺼울수록, 파이프 직경이 클수록 스프링백 값이 커집니다.",
            ),
          ],
        ),
        const SizedBox(height: 40),

        // 📏 7. 연속 벤딩 최소 간격
        _buildTossCard(
          title: "7. 연속 벤딩 최소 물림 간격",
          subtitle: "두 개의 벤딩이 연속될 때 벤더기 충돌을 막는 최소 직선",
          icon: LucideIcons.moveHorizontal,
          iconColor: Colors.deepOrange,
          children: [
            _buildDataRow("L 최소값", "첫 번째 벤딩 끝나는 점 ~ 두 번째 마킹 선까지의 거리"),
            const SizedBox(height: 16),
            _buildTossTable(
              headers: ["규격\n(OD)", "벤더기 롤러 폭\n(참고치)", "권장 최소 직선\n(안전 확보)"],
              rows: [
                ["1/4\"", "15 mm", "25.0 mm 이상"],
                ["3/8\"", "24 mm", "35.0 mm 이상"],
                ["1/2\"", "32 mm", "45.0 mm 이상"],
                ["3/4\"", "45 mm", "60.0 mm 이상"],
              ],
              footer: "※ 수동 벤더기 기준이며, NC 벤더기의 경우 클램프 길이에 따라 더 길어질 수 있습니다.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 💥 8. 허용 압력표
        _buildTossCard(
          title: "8. 튜브 두께별 최대 허용 압력",
          subtitle: "SUS 316L 심리스(Seamless) 튜브 기준 (상온)",
          icon: LucideIcons.gauge,
          iconColor: Colors.redAccent,
          children: [
            _buildDataRow("0.035T (0.89mm)", "가장 흔히 쓰는 일반 저/중압용 두께"),
            _buildDataRow("0.049T (1.24mm) 이상", "수소, 고압 가스 등 특수 라인용 두께"),
            const SizedBox(height: 16),
            _buildTossTable(
              headers: [
                "규격\n(OD)",
                "0.035T\n(0.89mm)",
                "0.049T\n(1.24mm)",
                "0.065T\n(1.65mm)",
              ],
              rows: [
                [
                  "1/4\"",
                  "5,100 psig\n(350 bar)",
                  "7,500 psig\n(510 bar)",
                  "10,200 psig\n(700 bar)",
                ],
                [
                  "3/8\"",
                  "3,300 psig\n(220 bar)",
                  "4,800 psig\n(330 bar)",
                  "6,500 psig\n(440 bar)",
                ],
                [
                  "1/2\"",
                  "2,600 psig\n(170 bar)",
                  "3,700 psig\n(250 bar)",
                  "5,100 psig\n(350 bar)",
                ],
              ],
              footer: "※ 배관 외경이 커질수록 견디는 압력은 오히려 낮아집니다. (두께가 같을 경우)",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 🔩 9. NPT 나사산 규격
        _buildTossCard(
          title: "9. 장비 체결용 NPT 나사산 규격",
          subtitle: "배관 규격과 테이퍼 나사(NPT/PT) 외경의 실제 차이",
          icon: LucideIcons.settings,
          iconColor: Colors.blueGrey,
          children: [
            _buildIntroBadge(
              "초보자 실수 1순위: '1/2인치 밸브'의 나사산 외경은 1/2인치(12.7mm)가 아닙니다! 약 21.3mm의 훨씬 굵은 크기를 가집니다.",
            ),
            const SizedBox(height: 16),
            _buildTossTable(
              headers: [
                "호칭 치수\n(NPT)",
                "실제 나사 외경\n(mm)",
                "1인치당\n나사산 수(TPI)",
                "테프론 감는 횟수\n(참고치)",
              ],
              rows: [
                ["1/4\"", "13.7 mm", "18 개", "3 ~ 4 바퀴"],
                ["3/8\"", "17.1 mm", "18 개", "3 ~ 4 바퀴"],
                ["1/2\"", "21.3 mm", "14 개", "4 ~ 5 바퀴"],
                ["3/4\"", "26.7 mm", "14 개", "5 ~ 6 바퀴"],
              ],
              footer: "※ 테프론 테이프는 나사산의 끝에서 두 번째 산부터 시작하여 시계 방향으로 감습니다.",
            ),
          ],
        ),
        const SizedBox(height: 16), // 마지막 띄어쓰기 유지용
      ],
    );
  }

  // ==========================================
  // 3️⃣ 세 번째 탭: 장비 사용법 (🚀 NC 벤더 특화)
  // ==========================================
  Widget _buildMachineGuideTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        _buildIntroBadge(
          "수동 벤더기 및 현장에 배치된 NC(Numerical Control) 전동 벤더기의 핵심 조작법입니다. 기계와 파이프의 충돌을 막기 위해 작업 전 반드시 숙지하세요.",
        ),
        const SizedBox(height: 16),

        // 🛠️ 1. 수동 벤더기 조작법
        _buildTossCard(
          title: "1. 수동 벤더기 (Hand Bender)",
          subtitle: "가장 기본이 되는 현장 공용 툴 (Swagelok, Ridgid 등)",
          icon: Icons.handyman_outlined,
          iconColor: Colors.brown,
          children: [
            _buildButtonGuide(
              btnName: "0 마크 (Zero Mark)",
              purpose: "모든 벤딩의 시작 기준점",
              action: "내 파이프에 그은 마킹선(샤피/네임펜)을 벤더 슈의 '0' 눈금에 정확히 일치시킵니다.",
            ),
            const Divider(height: 24, color: bgColor),
            _buildButtonGuide(
              btnName: "R 마크 (Right Mark)",
              purpose: "오른쪽(정방향) 90도 벤딩",
              action:
                  "파이프의 끝단에서부터 길이를 재어왔을 때 사용합니다. 0눈금에 마킹선을 맞춘 후, 롤러의 '0' 눈금이 다이의 '90' 눈금에 도달할 때까지 당깁니다.",
            ),
            const Divider(height: 24, color: bgColor),
            _buildButtonGuide(
              btnName: "L 마크 (Left Mark)",
              purpose: "왼쪽(역방향) 90도 벤딩",
              action: "파이프의 시작점부터 길이를 쟀을 때 사용합니다. 마킹선을 'L'에 맞추고 90도까지 당깁니다.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ⚡ 2. Swagelok 전동 벤더기 조작법
        _buildTossCard(
          title: "2. Swagelok 전동기 (MS-BTB)",
          subtitle: "전자식 펜던트 제어 방식 (단일 벤딩용)",
          icon: Icons.precision_manufacturing,
          iconColor: Colors.orange.shade800,
          children: [
            _buildButtonGuide(
              btnName: "[ANGLE] / [SPRINGBACK]",
              purpose: "벤딩 각도 및 탄성 보상",
              action: "목표 각도(예: 90)와 스프링백(예: 2.5)을 펜던트에 입력합니다.",
            ),
            const Divider(height: 24, color: bgColor),
            _buildButtonGuide(
              btnName: "[BEND] 스위치",
              purpose: "모터 구동 및 실제 벤딩 실행",
              action: "안전을 위해 벤딩이 끝날 때까지 꾹 누르고 있어야 합니다. (손을 떼면 비상 정지)",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 🖥️ 3. TRACTO-TECHNIK (TB20D) - NC 벤더 조작법 🚀 (완전 개편)
        _buildTossCard(
          title: "3. TRACTO-TECHNIK (TB20D) - NC",
          subtitle: "NC(Numerical Control) 제어반 프로그램 방식",
          icon: LucideIcons.monitorSmartphone,
          iconColor: Colors.indigo,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDataRow("구동 방식", "NC 제어반 (각도 C축 자동 제어)"),
                  _buildDataRow(
                    "작업 특징",
                    "프로그램에 벤딩 순서(Step 1,2..)를 입력해두고 풋 페달로 연속 작업",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "🔧 NC 제어반 실무 조작 순서",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: textMain,
              ),
            ),
            const SizedBox(height: 12),
            _buildButtonGuide(
              btnName: "1. 기계 원점 복귀 (Reference/Home)",
              purpose: "NC 컨트롤러 영점 셋팅 (가장 중요!)",
              action:
                  "장비 전원을 켠 후, 화면에서 [HOME] 또는 [REF] 버튼을 눌러 벤딩 암을 0° 원점으로 세팅합니다. (이 과정을 건너뛰면 기계가 오작동하여 충돌할 수 있습니다.)",
            ),
            const Divider(height: 24, color: bgColor),
            _buildButtonGuide(
              btnName: "2. NC 프로그램 (PROG) 스텝 입력",
              purpose: "도면의 벤딩 순서대로 데이터 저장",
              action:
                  "새 프로그램 번호를 엽니다. \n• Step 1: 첫 번째 벤딩 각도와 스프링백(Korr) 입력 후 ENTER.\n• Step 2: 두 번째 벤딩 각도 입력 후 ENTER.\n이런 식으로 파이프 하나에 들어갈 모든 벤딩 각도를 순서대로 짜놓습니다.",
            ),
            const Divider(height: 24, color: bgColor),
            _buildButtonGuide(
              btnName: "3. 길이/회전 세팅 및 클램핑",
              purpose: "스토퍼(캐리지)를 이용한 파이프 세팅",
              action:
                  "파이프를 넣고 기계 뒷단의 수동 스토퍼(길이, 회전 방향)에 파이프를 밀착시킵니다. 그 후 [CLAMP] 버튼이나 풋 페달 1단을 밟아 파이프를 꽉 물립니다.",
            ),
            const Divider(height: 24, color: bgColor),
            _buildButtonGuide(
              btnName: "4. 사이클 스타트 (풋 페달 작동)",
              purpose: "입력된 NC 프로그램 자동 실행",
              action:
                  "모드를 [AUTO]로 두고 풋 페달을 끝까지 밟습니다. 기계가 Step 1에 입력된 각도까지 정확히 꺾고 멈춥니다.\n\n➔ 파이프를 풀고 다음 스토퍼까지 밀어 넣은 뒤, 다시 페달을 밟으면 자동으로 Step 2 각도가 실행됩니다.",
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "NC 벤더 주의: 스텝(Step) 순서가 꼬이지 않게 주의하세요. 기계는 현재 몇 번째 스텝인지 화면에 표시합니다. 잘못 밟으면 90도 꺾을 타이밍에 45도를 꺾어 파이프를 버리게 됩니다.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "📊 TB20D 권장 연신율 표 (SUS 기준)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            _buildTossTable(
              headers: ["규격(OD)", "표준 금형(CLR)", "권장 연신율"],
              rows: [
                ["1/4\" (6.35)", "R15.0", "7.0 ~ 8.0"],
                ["3/8\" (9.52)", "R22.5", "11.0 ~ 12.5"],
                ["1/2\" (12.7)", "R35.0", "18.0 ~ 20.0"],
                ["3/4\" (19.05)", "R50.0", "26.0 ~ 28.0"],
              ],
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
  Widget _buildIntroBadge(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: makitaTeal.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.info, color: makitaTeal, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textMain.withValues(alpha: 0.8),
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
            color: Colors.black.withValues(alpha: 0.02),
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
                  color: iconColor.withValues(alpha: 0.1),
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

  // 🚀 장비 버튼 설명 전용 위젯
  Widget _buildButtonGuide({
    required String btnName,
    required String purpose,
    required String action,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: textMain,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              btnName,
              style: const TextStyle(
                color: pureWhite,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "• 목적: ",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: textMain,
                ),
              ),
              Expanded(
                child: Text(
                  purpose,
                  style: const TextStyle(fontSize: 13, color: textSub),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "• 조작: ",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: makitaTeal,
                ),
              ),
              Expanded(
                child: Text(
                  action,
                  style: const TextStyle(
                    fontSize: 13,
                    color: textMain,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 좌측 타이틀, 우측 내용
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

  // 타이틀 + 내용 나열용
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
