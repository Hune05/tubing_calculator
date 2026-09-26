// 장비 사용법 탭: 튜브 벤더(수동·전동·NC), 전선관 벤더(수동·유압·시카고),
// 실측 캘리브레이션, 톱·절단기, 안전.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'reference_widgets.dart';

class RefMachineTab extends StatelessWidget {
  const RefMachineTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        refIntroBadge(
          "현장에 있는 장비의 조작 순서입니다. 제원(테이크업·게인·반경)은 장비마다 달라서, 처음 쓰는 장비는 '실측 캘리브레이션'을 한 번 하고 설정에 넣어 두십시오.",
        ),
        const SizedBox(height: 16),

        // ── 튜브 ──
        refCard(
          title: "1. 튜브 수동 벤더 (Swagelok·Ridgid형)",
          subtitle: "튜브 벤딩의 기본. 슈(다이)·롤러·핸들",
          icon: Icons.handyman_outlined,
          iconColor: Colors.brown,
          children: [
            refButtonGuide(
              btnName: "0 마크",
              purpose: "모든 벤딩의 시작 기준",
              action:
                  "튜브에 그은 마킹선을 슈의 '0' 눈금에 정확히 맞춘다. 계산기 마킹은 이 자리를 기준으로 찍혀 있다.",
            ),
            refGap(),
            refButtonGuide(
              btnName: "R 마크 / L 마크",
              purpose: "어느 쪽에서 치수를 쟀는지",
              action:
                  "튜브 끝에서 벤드까지 잰 치수(정방향)면 R, 시작점부터 잰 치수면 L에 마킹선을 맞춘다. 계산기 '마킹 위치(줄자 0점 기준)'는 R 방식이다.",
            ),
            refGap(),
            refButtonGuide(
              btnName: "롤러 핀·클램프",
              purpose: "튜브가 슈에서 뜨지 않게",
              action:
                  "튜브를 넣고 롤러(링크)를 내린 뒤 핀을 끝까지 밀어 넣는다. 핀이 덜 들어가면 각도가 모자라고 관이 눌린다.",
            ),
            refGap(),
            refButtonGuide(
              btnName: "각도 눈금",
              purpose: "목표 각도 + 스프링백",
              action:
                  "롤러의 0 눈금이 슈의 목표 각도(예 90)를 지나 스프링백만큼(2~3°) 더 가도록 지그시 한 번에 당긴다. 멈췄다 다시 당기면 자국이 남는다.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2026-09-26 바로잡음: 매뉴얼(MS-13-145)·제조사 자료와 맞지 않던 조작 설명과 TB20D 금형 표를 뺐다.
        refCard(
          title: "2. Swagelok 전동 벤더 (MS-BTB)",
          subtitle: "벤치탑 전동. 숫자 바퀴로 각도, 토글 스위치로 굽힘 (1/4\"~1-1/4\", 6~30mm)",
          icon: Icons.precision_manufacturing,
          iconColor: Colors.orange.shade800,
          children: [
            refButtonGuide(
              btnName: "벤드 슈 기준선",
              purpose: "마킹 맞추기",
              action:
                  "관이 휘기 시작하는 자리(계산기 마킹)를 벤드 슈의 기준선(reference mark)에 맞춘다. 관 끝이 클램프 암 오른쪽 끝을 지나야 한다.",
            ),
            refGap(),
            refButtonGuide(
              btnName: "숫자 바퀴 (thumb wheel)",
              purpose: "각도 넣기",
              action:
                  "넣을 각도(설계각 + 스프링백)를 맞춘다. 스프링백은 한 번 꺾어 재서 차이를 더한다(예: 90을 넣어 86이 나오면 94).",
            ),
            refGap(),
            refButtonGuide(
              btnName: "토글 스위치",
              purpose: "꺾기·풀기",
              action: "스위치로 꺾고, 끝나면 반대로 돌려 관을 뺀다. 풋 페달은 옵션이다.",
            ),
            const SizedBox(height: 12),
            refWarnBox(
              "슈 반경: 1/4\"·3/8\" R36, 1/2\" R36 또는 R56, 5/8\" R46, 3/4\" R56, 7/8\" R67, 1\" R82, 1-1/4\" R112 (MS-13-145 3쪽). 마킹·넣을 각도는 '전동 벤딩 계산기'에서 장비를 골라 구하십시오.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        refCard(
          title: "3. TRACTO-TECHNIK TUBOBEND TB20D",
          subtitle: "굽힘 각도만 자동, 이송·회전은 손으로 (강관 Ø20×2mm, 최대 R50)",
          icon: LucideIcons.monitorSmartphone,
          iconColor: Colors.indigo,
          children: [
            refButtonGuide(
              btnName: "각도 미리 넣기",
              purpose: "벤딩 순서",
              action:
                  "각도 8개까지 미리 넣고 차례로 꺾을 수 있다(제조사 자료). '전동 벤딩 계산기'의 넣을 각도를 벤드 순서대로 넣는다.",
            ),
            refGap(),
            refButtonGuide(
              btnName: "이송·회전 (손)",
              purpose: "관 자리 잡기",
              action:
                  "계산기의 '손 이송' 줄대로 관을 밀어 넣고(밀기) 돌린 뒤(돌리기) 클램프를 물린다. 길이·회전 스토퍼는 옵션이다.",
            ),
            refGap(),
            refButtonGuide(
              btnName: "클램프·풋 스위치",
              purpose: "물리고 꺾기",
              action: "유압 클램프로 물리고 꺾는다. 굽힘·클램프 풋 스위치는 옵션이다.",
            ),
            const SizedBox(height: 12),
            refWarnBox(
              "화면의 지금 순서 번호를 늘 확인하십시오. 순서가 꼬이면 90° 자리에 45°가 들어가 관을 버립니다. 금형별 반경·게인은 공개 자료에 없어, 금형 각인 R과 시험 굽힘 값으로 계산기에 넣으십시오.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── 전선관 ──
        refCard(
          title: "4. 전선관 수동 벤더 (Greenlee·Ideal형)",
          subtitle: "발로 밟아 꺾는 히키 벤더. 슈에 화살표·별·림 표시가 있다",
          icon: LucideIcons.wrench,
          iconColor: Colors.brown,
          children: [
            refButtonGuide(
              btnName: "화살표 (Arrow)",
              purpose: "90°·오프셋 마킹을 맞추는 표시",
              action: "관에 찍은 마킹선을 화살표에 맞춘다. 계산기 마킹은 테이크업을 이미 뺀 '화살표 자리'다.",
            ),
            refGap(),
            refButtonGuide(
              btnName: "별 (Star)",
              purpose: "뒤로 꺾을 때(백투백) 기준",
              action: "두 번째 90°를 관 끝 쪽에서 재서 꺾을 때 마킹선을 별에 맞춘다.",
            ),
            refGap(),
            refButtonGuide(
              btnName: "림 표시 (Rim notch)",
              purpose: "새들 가운데 벤드",
              action: "3벤드 새들의 가운데 마킹(45°)을 림 홈에 맞춘다. 양옆 22.5°는 화살표.",
            ),
            refGap(),
            refButtonGuide(
              btnName: "발판·핸들",
              purpose: "꺾기",
              action:
                  "발판을 밟으며 핸들을 당긴다. 슈 눈금이 목표 각도 + 스프링백(후강 3~5°)까지. 바닥에 관이 뜨면 각이 모자란 것.",
            ),
            refGap(),
            refButtonGuide(
              btnName: "순서 (오프셋)",
              purpose: "두 벤드가 같은 평면에",
              action:
                  "첫 벤드 뒤 관을 뒤집지 말고 슈 안에서 180° 돌려 두 번째 마킹을 화살표에 맞춘다. 관에 그은 세로 선이 슈 가운데와 나란한지 본다(개 다리 방지).",
            ),
          ],
        ),
        const SizedBox(height: 16),

        refCard(
          title: "5. 유압식 벤더 (Greenlee·Current Tools형)",
          subtitle: "슈를 규격에 맞게 갈아 끼우고 램으로 민다",
          icon: Icons.precision_manufacturing,
          iconColor: Colors.indigo,
          children: [
            refButtonGuide(
              btnName: "슈·받침(다이) 고르기",
              purpose: "규격에 맞는 곡선",
              action:
                  "관 호칭과 같은 슈를 램에 끼우고, 받침 롤러(다이)는 프레임의 그 호칭 구멍에 핀으로 꽂는다. 핀이 끝까지 안 들어가면 절대 밀지 않는다.",
            ),
            refGap(),
            refButtonGuide(
              btnName: "셋백 마크 맞추기",
              purpose: "꺾이는 점 자리",
              action: "계산기 마킹(셋백을 뺀 자리)을 슈 가운데 표시에 맞춘다. 관은 받침 롤러 양쪽에 고르게 걸친다.",
            ),
            refGap(),
            refButtonGuide(
              btnName: "펌프·램",
              purpose: "꺾기",
              action:
                  "펌프 밸브를 잠그고 펌프질(전동은 스위치). 램 눈금이 설정의 '램 이동 거리'(90°)·각도별 환산값까지 나오면 멈춘다. 각도기로 재고 부족하면 조금 더.",
            ),
            refGap(),
            refButtonGuide(
              btnName: "되돌리기",
              purpose: "관 빼기",
              action: "릴리스 밸브를 천천히 열어 램을 넣는다. 갑자기 열면 슈가 튄다. 관을 빼고 다음 마킹.",
            ),
            const SizedBox(height: 12),
            refWarnBox(
              "램이 나갈 때 손·발을 슈와 받침 사이에 두지 않는다. 핀이 반쯤 꽂힌 채 밀면 핀이 총알처럼 튄다.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        refCard(
          title: "6. 시카고식 벤더 (기어·크랭크)",
          subtitle: "슈를 기어로 돌려 꺾는다. 굵은 후강에 쓴다",
          icon: LucideIcons.cog,
          iconColor: Colors.deepOrange,
          children: [
            refButtonGuide(
              btnName: "롤러·슈 맞추기",
              purpose: "규격에 맞는 홈",
              action:
                  "관 호칭에 맞는 롤러 규격(설정의 '롤러 규격')과 슈 홈에 관을 넣는다. 훅(고리)이 관을 꽉 눌러야 한다.",
            ),
            refGap(),
            refButtonGuide(
              btnName: "0점·마킹",
              purpose: "시작 자리",
              action: "노치 휠을 0에 두고 마킹선(테이크업 뺀 자리)을 슈 표시에 맞춘다.",
            ),
            refGap(),
            refButtonGuide(
              btnName: "크랭크·노치",
              purpose: "각도만큼 돌리기",
              action:
                  "크랭크를 돌리며 넘어가는 노치 칸을 센다. 칸 수 = 목표 각도 ÷ 노치당 각도(설정값). 스프링백만큼 한두 칸 더.",
            ),
            refGap(),
            refButtonGuide(
              btnName: "되돌리기 레버",
              purpose: "관 빼기",
              action: "래칫을 풀고 크랭크를 되돌린다. 관을 빼기 전에 훅을 먼저 푼다.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── 실측 ──
        refCard(
          title: "7. 내 장비 실측 캘리브레이션 (한 번만)",
          subtitle: "제원표는 기계마다 달라 못 믿습니다. 한 번 재서 설정에 넣으면 그 뒤로는 자동입니다",
          icon: Icons.straighten_rounded,
          iconColor: Colors.deepPurple,
          children: [
            refButtonGuide(
              btnName: "① 테이크업 / 셋백 (수동·시카고·유압 공통)",
              purpose: "첫 벤딩점에서 빼야 할 값",
              action:
                  "곧은 관 끝에서 300~500mm 자리에 선을 긋고, 그 선을 벤더 0점(화살표·별)에 맞춰 90°로 꺾는다.\n"
                  "꺾은 뒤 관 끝에서 바깥면(등)까지 잰다.\n"
                  "테이크업 = 잰 길이 − 처음 그은 선까지의 길이. 전선관 계산기 설정의 '실측 보정' 창에 두 값을 넣으면 앱이 셈해 준다.",
            ),
            refGap(),
            refButtonGuide(
              btnName: "② 게인 (전 기종 공통)",
              purpose: "90°에서 줄어드는 길이",
              action:
                  "관 하나를 정확한 길이(예 500mm)로 잘라 한가운데를 90°로 꺾는다.\n"
                  "꺾인 점(교차점)에서 양쪽 끝까지 잰다(A, B).\n"
                  "게인 = A + B − 500. 튜브 계산기 설정의 게인 칸, 전선관 계산기의 '벤딩 게인' 칸에 넣는다.",
            ),
            refGap(),
            refButtonGuide(
              btnName: "③ 유압식 — 램 이동 거리",
              purpose: "각도별 램 눈금",
              action:
                  "①과 같이 90°로 꺾으면서 램에 붙은 눈금 값을 적는다. 45°도 한 번 더 재 두면 사이 각도를 더 정확히 셈한다.",
            ),
            refGap(),
            refButtonGuide(
              btnName: "④ 시카고식 — 노치당 각도",
              purpose: "기어 한 칸이 몇 도인지",
              action:
                  "0점에서 90°가 될 때까지 넘어간 노치 칸 수를 센다. 노치당 각도 = 90 ÷ 칸 수. 노치 간격은 이웃 노치 사이를 자로 잰다.",
            ),
            refGap(),
            refButtonGuide(
              btnName: "⑤ 스프링백",
              purpose: "더 꺾어야 하는 각",
              action:
                  "90° 눈금까지 꺾고 풀어 각도기로 잰다. 90 − 잰 각 = 스프링백. 설정의 '스프링백 [°]'에 넣는다.",
            ),
            const SizedBox(height: 12),
            refTipBox(
              "잰 값은 튜브 계산기 '설정' 탭(수동/유압식/시카고식 제원 칸), 전선관 계산기 '설정'(제조사·재질·규격별)에 넣습니다. 규격마다 따로 저장되니 한 번만 하면 됩니다.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── 절단 ──
        refCard(
          title: "8. 튜브 커터 · 디버링",
          subtitle: "튜브는 톱이 아니라 커터로 자른다",
          icon: LucideIcons.scissors,
          iconColor: Colors.teal,
          children: [
            refStep(1, "마킹선에 커터 날을 맞추고 가볍게 조인 뒤 한 바퀴 돌린다."),
            refStep(2, "돌릴 때마다 손잡이를 1/4바퀴씩만 조인다. 한 번에 세게 조이면 관 끝이 안으로 말린다."),
            refStep(
              3,
              "잘린 면의 안팎 버를 디버링 툴로 깎는다. 안쪽 버는 유량을 막고, 바깥 버는 페룰 자리를 긁는다.",
            ),
            refStep(4, "끝면이 관 축과 직각인지 본다. 비스듬하면 피팅 턱에 닿지 않아 샌다."),
            refStep(5, "자르기 전 계산기의 '총 절단 길이'와 마킹지(PDF)를 한 번 더 대조한다."),
          ],
        ),
        const SizedBox(height: 16),

        refCard(
          title: "9. 고속절단기 · 밴드쏘 · 전선관 나사",
          subtitle: "형강·전선관 절단",
          icon: LucideIcons.zap,
          iconColor: Colors.redAccent,
          children: [
            refStep(
              1,
              "톱날 두께를 재서 형강 컷팅·튜브 컷팅 화면의 '톱날 손실'에 넣는다(고속절단기 2.5~3mm, 밴드쏘 1.3~1.6mm).",
            ),
            refStep(2, "재단 계획 순서대로 긴 조각부터 자른다. 자재를 바이스에 꽉 물린다."),
            refStep(3, "절단기는 날을 자재에 댄 채 시동하지 않는다. 회전이 다 오른 뒤 천천히 내린다."),
            refStep(4, "밴드쏘는 자재를 밀지 않는다. 날 무게로 내려가게 두고 후강·H형강은 속도를 낮춘다."),
            refStep(
              5,
              "전선관 나사는 다이스에 절삭유를 치고 1/4바퀴 되돌리며 낸다. 나사 길이 = 커플링 길이의 절반 + 1~2산.",
            ),
            refStep(6, "자른 뒤 리머로 안쪽 버를 깎는다. 남은 잔재는 규격을 적어 잔재 목록에 올린다."),
          ],
        ),
        const SizedBox(height: 16),

        refCard(
          title: "10. 안전",
          subtitle: "매일 지키는 것",
          icon: LucideIcons.hardHat,
          iconColor: Colors.amber.shade800,
          children: [
            refDataRow(
              "보호구",
              "보안경(절단·연마 필수), 귀마개, 절단 장갑. 회전 장비 앞에서 면장갑은 말려 들어간다.",
            ),
            refGap(),
            refDataRow("유압", "호스·커플러 누유 확인. 램·슈 사이에 손 금지. 핀은 끝까지."),
            refGap(),
            refDataRow("전동 벤더", "비상 정지 자리를 먼저 확인. 암이 도는 반경 안에 사람·자재 없게."),
            refGap(),
            refDataRow(
              "무게",
              "6m 후강 54는 본당 약 36kg, H형강은 더 무겁다. 형강 탭의 무게로 미리 인원을 정한다.",
            ),
            refGap(),
            refDataRow("불꽃", "절단기 불꽃 방향에 배관·케이블·유류 없게. 소화기 위치 확인."),
            refGap(),
            refDataRow(
              "통신 없는 현장",
              "발전소 안에서는 앱이 폰에 저장했다가 통신되면 올린다. 저장 안 됐다고 다시 누르지 말고 나와서 확인.",
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
