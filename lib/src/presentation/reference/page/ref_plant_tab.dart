// 발전 설비 탭: 화력·원자력 대형 터빈-발전기의 보조계통(수소 냉각·씰 오일·
// 윤활유·냉각수·밸브 스테이션)을 원리 위주로 정리한다. 특정 발전소의 실제
// 도면(P&ID)이나 사내 절차서를 검증한 내용이 아니라 일반 교과서 수준의
// 설명이라, 실무 판단 근거로는 쓸 수 없다는 점을 맨 위 배지와 마지막 경고
// 상자에 명시한다(사용자 요청: 전기 기능사 실무 참고, 2026-09-25).
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'reference_widgets.dart';

class RefPlantTab extends StatelessWidget {
  const RefPlantTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        refIntroBadge(
          "화력·원자력 어느 쪽이든 대형 터빈-발전기 옆에 붙는 보조계통은 원리가 "
          "같습니다. 아래 내용은 일반 교육용 설명이라 특정 발전소의 실제 도면·"
          "절차서를 확인한 게 아닙니다 — 참고만 하시고, 조작·점검은 반드시 "
          "해당 발전소 절차서(SOP)를 따라야 합니다.",
          icon: LucideIcons.factory,
        ),
        const SizedBox(height: 16),
        refCard(
          title: "왜 대형 발전기는 수소(H₂)로 냉각하나",
          subtitle: "설치 사유 — 공기 냉각으로는 열을 못 뺀다",
          icon: LucideIcons.wind,
          iconColor: Colors.lightBlue,
          children: [
            refStep(
              1,
              "발전기 안 권선·철심에서 나는 열은 크기(출력)의 세제곱에 가깝게 "
              "늘어나는데, 식힐 표면적은 그만큼 못 늘어납니다. 100MW급을 "
              "넘어가면 공기 냉각만으로는 열을 다 못 뺍니다.",
            ),
            refStep(
              2,
              "수소는 같은 압력에서 열전도율이 공기보다 약 7배 높고, 밀도는 "
              "약 1/14로 가볍습니다. 밀도가 낮으면 로터가 도는 동안 기체를 "
              "밀어내는 손실(풍손, windage loss)도 같이 줄어듭니다.",
            ),
            refStep(
              3,
              "그래서 발전기 케이싱을 통째로 밀폐해 수소를 채우고 그 안에서 "
              "순환시킵니다 — 냉각도 더 잘 되고, 도는 데 드는 손실도 줄어서 "
              "효율이 올라갑니다(대형기일수록 이 차이가 큽니다).",
            ),
            refGap(),
            refWarnBox(
              "수소는 공기와 섞이면(대략 4~75%) 폭발성 혼합가스가 됩니다. 그래서 "
              "케이싱 안은 항상 순도·압력을 감시하고, 공기와 직접 맞바꾸지 "
              "않고 항상 CO₂로 한 번 밀어낸 다음 바꿉니다(아래 항목).",
            ),
          ],
        ),
        const SizedBox(height: 16),
        refExpandCard(
          title: "수소 가스 계통 — 판넬·드라이어·퍼지",
          subtitle: "H2 Gas Panel · Gas Dryer · CO₂ Purge",
          icon: LucideIcons.gauge,
          iconColor: Colors.teal,
          children: [
            refSectionTitle("가스 판넬(H2 Gas Panel)"),
            refDataRow(
              "하는 일",
              "발전기 케이싱 안 수소의 압력·순도(수분·불순물 비율)를 계기로 "
              "모아 보여주고, 보충(충전) 밸브·배출 밸브·순도 측정 라인을 "
              "한 판에 모아 둔 것입니다. 운전원이 여기서 압력·순도가 정상 "
              "범위인지 늘 확인합니다.",
            ),
            refGap(),
            refSectionTitle("가스 드라이어(Gas Dryer)"),
            refDataRow(
              "하는 일",
              "케이싱 안을 도는 수소에서 습기를 뽑아냅니다. 수소가 젖으면 "
              "권선 절연이 나빠지고 금속 부품이 부식되기 쉬워서, 실리카겔 "
              "같은 건조제 통을 두 개 두고 하나가 습기를 다 먹으면 자동으로 "
              "다른 쪽으로 바꿔 걸며(전환), 다 먹은 쪽은 가열해 말려 "
              "재생(regeneration)한 뒤 다시 씁니다.",
            ),
            refGap(),
            refSectionTitle("CO₂ 퍼지 — 왜 공기와 직접 안 바꾸나"),
            refDataRow(
              "충전할 때",
              "공기 → CO₂로 먼저 밀어내 케이싱을 채우고 → CO₂를 다시 수소로 "
              "밀어냅니다. 공기와 수소가 케이싱 안에서 직접 만나는 순간이 "
              "없게 만드는 순서입니다.",
            ),
            refDataRow(
              "배출할 때",
              "반대로 수소 → CO₂ → 공기 순서로 밀어내고 나서 정비를 "
              "시작합니다. CO₂는 수소·공기 양쪽과 안 반응하고 값도 싸서 "
              "이 중간 단계 기체로 씁니다.",
            ),
          ],
        ),
        const SizedBox(height: 16),
        refExpandCard(
          title: "씰 오일 계통 — 수소가 축을 따라 안 새는 이유",
          subtitle: "Seal Oil System",
          icon: LucideIcons.droplet,
          iconColor: Colors.orange,
          children: [
            refStep(
              1,
              "로터 축이 밀폐된 케이싱을 뚫고 밖으로 나가는 두 군데(양쪽 끝)는 "
              "기계적으로 완전히 막을 수 없습니다. 그 틈을 오일 막으로 "
              "메우는 게 씰 오일입니다.",
            ),
            refStep(
              2,
              "차압 조절기(differential pressure regulator)가 씰에 들어가는 "
              "오일 압력을 케이싱 안 수소 압력보다 항상 일정하게(보통 "
              "0.5~1 kgf/cm² 정도) 더 높게 유지합니다 — 압력이 높은 쪽에서 "
              "낮은 쪽으로만 흐르므로, 오일이 수소 쪽으로 아주 조금씩 "
              "새어 들어갈 뿐 수소가 밖으로 새지는 않습니다.",
            ),
            refStep(
              3,
              "그 오일 중 수소 쪽으로 들어간 만큼은 배출 라인을 타고 진공 "
              "탱크(vacuum tank/detraining tank)로 모여, 오일에 녹아든 "
              "수소를 진공으로 뽑아 분리한 뒤 오일만 씰 오일 탱크(Seal Oil "
              "Tank)로 돌려보냅니다.",
            ),
            refStep(
              4,
              "씰 오일 펌프는 정상 운전용(AC) 외에 정전 대비용 DC 펌프를 "
              "따로 둡니다 — 씰 오일이 끊기면 수소가 그대로 새므로, 발전기가 "
              "멈춘 뒤에도 한동안은 씰 오일 압력을 반드시 유지해야 합니다.",
            ),
          ],
        ),
        const SizedBox(height: 16),
        refExpandCard(
          title: "윤활유 계통(LOT)과 베어링 보호",
          subtitle: "Lube Oil Tank · Main/Aux/Emergency Pump",
          icon: LucideIcons.settings,
          iconColor: Colors.brown,
          children: [
            refDataRow(
              "메인 오일탱크",
              "터빈-발전기 축을 받치는 모든 베어링에 오일을 대 주는 "
              "저유조(LOT)입니다. 오일이 탱크에 머무는 동안 거품·수분·"
              "이물질이 가라앉거나 빠지도록 크기를 넉넉하게 잡습니다.",
            ),
            refDataRow(
              "펌프 3단",
              "① 메인 오일펌프(정상 운전 중, 축이나 전동기로 구동) "
              "② 보조 오일펌프(AC, 기동·정지 구간처럼 축 회전이 느려 메인 "
              "펌프압이 부족할 때) ③ 비상 오일펌프(DC, 완전 정전 시에도 "
              "베어링이 마르지 않게 최소압을 지킴) — 세 단이 겹쳐 있어 "
              "어떤 상황에서도 베어링에 오일이 끊기지 않게 합니다.",
            ),
            refDataRow(
              "오일 쿨러",
              "베어링을 돌고 뜨거워진 오일은 열교환기(오일 쿨러)를 지나며 "
              "식습니다 — 이 열을 받아가는 쪽이 아래 냉각수 계통입니다.",
            ),
            refDataRow(
              "오일 미스트",
              "베어링 하우징 안에서 생기는 오일 증기·미스트는 별도 팬으로 "
              "빨아내(vapor extractor) 압력을 살짝 낮게 유지합니다 — "
              "오일이 하우징 틈으로 새어 나오지 않게 하는 목적입니다.",
            ),
          ],
        ),
        const SizedBox(height: 16),
        refExpandCard(
          title: "냉각수 계통(워터 쿨링) — 열을 밖으로 빼내는 3단",
          subtitle: "Stator Cooling → Closed Cooling → Service Water",
          icon: LucideIcons.waves,
          iconColor: Colors.blueAccent,
          children: [
            refDataRow(
              "1단 · 고정자 냉각수",
              "대형 발전기는 고정자 권선 속을 순수(전기가 잘 안 통하는 "
              "물)가 직접 지나며 열을 뽑아갑니다. 이 물의 전기전도율을 "
              "계속 감시하는데, 값이 올라가면 절연이 나빠지고 있다는 "
              "신호라 중요한 경보로 취급합니다.",
            ),
            refDataRow(
              "2단 · 밀폐 냉각수",
              "고정자 냉각수·오일 쿨러·수소 쿨러 같은 여러 보조 열교환기를 "
              "식히는, 계통 안에서만 순환하는 깨끗한 물입니다(Closed/"
              "Component Cooling Water). 발전소 안 여러 설비가 이 한 "
              "계통을 같이 씁니다.",
            ),
            refDataRow(
              "3단 · 최종 방열",
              "2단이 받은 열을 냉각탑이나 해수·강물 같은 바깥 순환수(Service "
              "Water)로 넘겨 최종적으로 대기·강·바다로 버립니다. 1~2단이 "
              "깨끗한 물만 도는 이유는, 여기서 만약 새더라도 바깥 물이 "
              "안쪽 정밀 설비로 못 들어오게 격리하기 위해서입니다.",
            ),
          ],
        ),
        const SizedBox(height: 16),
        refCard(
          title: "밸브 스테이션 — 밸브를 왜 한 곳에 모아두나",
          icon: LucideIcons.workflow,
          iconColor: Colors.indigo,
          children: [
            refStep(
              1,
              "증기·오일·가스처럼 위험하거나 뜨거운 유체 라인일수록, 밸브를 "
              "설비 여기저기 흩어 두면 급할 때 찾아 잠그는 데 시간이 걸립니다.",
            ),
            refStep(
              2,
              "그래서 주요 차단·조절 밸브와 계측기를 사람이 안전하게 접근할 "
              "수 있는 한 자리(스킷/판넬)에 모아 놓은 것이 밸브 스테이션 "
              "입니다 — 예: 주증기 밸브 스테이션, 씰 스팀 밸브 스테이션.",
            ),
            refStep(
              3,
              "이렇게 모아 두면 순찰·정비 때 한 곳만 보면 되고, 비상 시에도 "
              "여러 밸브를 빠르게 같이 조작할 수 있습니다.",
            ),
          ],
        ),
        const SizedBox(height: 16),
        refExpandCard(
          title: "전체 흐름 한눈에 보기",
          subtitle: "연료(원자로/보일러) → 증기 → 터빈 → 발전기 → 복수기",
          icon: LucideIcons.network,
          iconColor: Colors.deepPurple,
          children: [
            refStep(
              1,
              "원자로(원자력) 또는 보일러(화력)에서 만든 증기가 터빈을 "
              "돌립니다. 터빈 축이 발전기 로터를 같이 돌립니다.",
            ),
            refStep(
              2,
              "발전기 케이싱 안은 수소로 채워 냉각하고(가스 판넬·드라이어· "
              "CO₂ 퍼지), 축이 케이싱을 뚫는 자리는 씰 오일로 막습니다.",
            ),
            refStep(
              3,
              "터빈·발전기를 받치는 베어링은 윤활유 계통(LOT, 3단 펌프)이 "
              "쉬지 않고 오일을 대 줍니다.",
            ),
            refStep(
              4,
              "씰 오일·윤활유·수소가 받아온 열, 그리고 고정자 냉각수가 뽑아온 "
              "열은 모두 냉각수 계통(밀폐 냉각수 → 최종 방열)으로 넘어가 "
              "밖으로 버려집니다.",
            ),
            refStep(
              5,
              "터빈을 돌리고 나온 증기는 복수기에서 물로 되돌아가고, "
              "급수펌프가 다시 원자로/보일러로 돌려보내 순환합니다.",
            ),
            refGap(),
            Text(
              "즉 발전기 하나를 돌리려면 가스·오일·물 세 계통이 서로 열을 "
              "주고받으며 같이 움직입니다 — 어느 한쪽이 멈추면 나머지도 "
              "정지 절차를 따라야 하는 이유입니다.",
              style: TextStyle(
                fontSize: 13,
                color: refTextSub,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        refExpandCard(
          title: "말씀하신 것 외에 같이 딸려 다니는 보조계통",
          subtitle: "여자 계통 · 조속기 · 복수기 진공",
          icon: LucideIcons.plusCircle,
          iconColor: Colors.grey,
          children: [
            refDataRow(
              "여자(Excitation) 계통",
              "발전기 로터에 직류 전류를 흘려 자석으로 만들어 주는 계통입니다 "
              "— 이 전류 크기를 조절해서 발전기가 내보내는 전압을 맞춥니다.",
            ),
            refDataRow(
              "조속기(Governor/EHC)",
              "터빈에 들어가는 증기량을 밸브로 조절해 회전수(주파수)를 "
              "일정하게 지킵니다. 요즘은 전자-유압식(EHC)이 많습니다.",
            ),
            refDataRow(
              "복수기 진공계통",
              "터빈을 나온 증기가 물로 되돌아가는 복수기 안을 진공에 "
              "가깝게 유지해야 터빈이 낼 수 있는 출력이 커집니다 — "
              "진공을 만들고 지키는 펌프·이젝터 계통입니다.",
            ),
          ],
        ),
        const SizedBox(height: 16),
        refWarnBox(
          "여기까지는 대형 터빈-발전기에 흔히 같이 붙는 보조계통의 일반 원리 "
          "설명입니다. 실제 설비의 정확한 사양·정상 범위·조작 순서는 발전소· "
          "제작사·기종마다 다르므로, 실무에서는 반드시 해당 발전소의 운전 "
          "절차서(SOP)·안전 기준을 따르셔야 합니다.",
        ),
      ],
    );
  }
}
