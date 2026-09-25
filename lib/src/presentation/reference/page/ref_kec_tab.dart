// 전기 기준(KEC) 탭: 전기설비기술기준·한국전기설비규정(KEC)은 해마다 조문이
// 바뀌는 법정 고시라, 이 환경(네트워크 정책)에서 law.go.kr·kec.kea.kr 접속이
// 막혀 최신 원문을 직접 확인할 방법이 없다(2026-09-25). 그래서 조문 번호·
// 수치를 지어내지 않고, "해마다 바뀔 수 있어 다시 확인해야 하는 항목"만
// 카테고리로 정리했다. 정확한 값은 공식 원문에서 확인해야 한다.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'reference_widgets.dart';

class RefKecTab extends StatelessWidget {
  const RefKecTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        refWarnBox(
          "여기엔 조문 번호나 수치를 넣지 않았습니다. 전기설비기술기준·한국전기설비규정"
          "(KEC)은 해마다 개정 고시가 나오는 법정 기준이라, 지금 이 화면이 만들어진 "
          "시점의 기억으로 숫자를 채우면 갱신 시점엔 틀린 값일 수 있습니다. 아래는 "
          "\"해마다 바뀔 수 있어 현장·자격 갱신 전에 다시 확인해야 하는 항목\"만 "
          "분류해 둔 목록입니다 — 정확한 조문·수치는 반드시 공식 원문으로 확인해야 합니다.",
        ),
        const SizedBox(height: 16),
        refCard(
          title: "최신 원문을 확인하는 방법",
          icon: LucideIcons.search,
          iconColor: Colors.blueGrey,
          children: [
            refStep(
              1,
              "국가법령정보센터(law.go.kr)에서 \"한국전기설비규정\"으로 검색하면 "
              "현재 시행 중인 전문과 개정 이력을 볼 수 있습니다.",
            ),
            refStep(
              2,
              "대한전기협회 KEC 홈페이지(kec.kea.kr)에서 장별 원문·개정 요약 자료를 "
              "내려받을 수 있습니다.",
            ),
            refStep(
              3,
              "소관 부처(산업통상자원부 계열)가 연말~연초에 개정 고시를 내는 경우가 "
              "많아, 자격 갱신·현장 적용 전에 그 해 고시가 났는지부터 확인하는 게 "
              "안전합니다.",
            ),
            refGap(),
            refTipBox(
              "최신 원문을 캡처해서 올려주시면, 그 내용 그대로 조문 번호·수치까지 "
              "채워 넣겠습니다.",
            ),
          ],
        ),
        const SizedBox(height: 16),
        refExpandCard(
          title: "접지·과전류 보호 — 감전·화재와 직결",
          subtitle: "계통접지 방식, 접지저항, 차단기 정격",
          icon: LucideIcons.zapOff,
          iconColor: Colors.redAccent,
          children: [
            refDataRow(
              "계통접지",
              "TN·TT·IT 같은 접지 방식 분류와 저압/고압 계통에서 어떤 방식을 "
              "쓰는지의 기준. 접지선 굵기·접지저항 허용값은 개정마다 세부 "
              "조정이 잦은 부분입니다.",
            ),
            refDataRow(
              "과전류 보호",
              "차단기·퓨즈의 정격, 설치 위치, 협조(선택차단) 기준. 설비 종류·"
              "부하 특성별로 표가 나뉘어 있어 매번 최신 표를 확인해야 합니다.",
            ),
          ],
        ),
        const SizedBox(height: 12),
        refExpandCard(
          title: "절연저항·이격거리 — 측정값 기준",
          subtitle: "저압/고압 절연저항 허용값, 안전거리",
          icon: LucideIcons.ruler,
          iconColor: Colors.deepOrange,
          children: [
            refDataRow(
              "절연저항",
              "전압 구분별로 최소 허용 절연저항값이 표로 정해져 있습니다. "
              "측정 전압(500V/1000V 메거)도 전압 구분에 따라 다릅니다.",
            ),
            refDataRow(
              "이격거리",
              "저압·고압·특고압 전선과 건조물·수목·다른 설비 사이에 둬야 하는 "
              "최소 거리. 옥내/옥외, 가선 방식에 따라 값이 세분화돼 있습니다.",
            ),
          ],
        ),
        const SizedBox(height: 12),
        refExpandCard(
          title: "최근 몇 년 사이 개정이 잦았던 분야",
          subtitle: "전기자동차 충전설비 · 신재생(태양광·ESS) · 분전반 구조",
          icon: LucideIcons.trendingUp,
          iconColor: Colors.green,
          children: [
            refDataRow(
              "EV 충전설비",
              "충전기 원격감시·제어, 화재 감시 관련 조항이 최근 개정에서 "
              "자주 손이 갔던 분야입니다(지하주차장 화재 대피·예방 포함).",
            ),
            refDataRow(
              "신재생에너지",
              "태양광·ESS(에너지저장장치) 설비의 배선·보호 기준은 보급이 "
              "늘면서 계속 세분화되고 있습니다.",
            ),
            refDataRow(
              "분전반 구조",
              "주택용 분전반처럼 \"앞면판이 탈락되지 않는 구조\" 식의 구조적 "
              "안전 요건이 개정으로 추가되는 경우가 있습니다.",
            ),
            refGap(),
            Text(
              "위 세 가지는 \"최근 개정이 몰렸던 분야\"라는 방향성 참고일 뿐, 이 "
              "화면이 그 해 실제 개정 내용을 확인한 것은 아닙니다.",
              style: TextStyle(
                fontSize: 12,
                color: refTextSub,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
