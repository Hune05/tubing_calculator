// 발전 설비 탭: 대형 터빈-발전기 보조계통(수소 가스·씰 오일·윤활유·고정자 냉각수·복수기 진공·
// 여자·조속기)의 구성, 운전 기준 예시값, 계장 점검, 고장 조치(현상/원인/조치).
//
// 2026-10-09 사용자 요청 "전문적인 자료로 채워줘"로 다시 씀(예전 글은 교과서 수준 원리 설명이었고,
// 씰 오일 진공 탱크 용도·씰 오일 유지 시점·순도와 노점을 섞어 쓴 곳이 틀렸다).
// 숫자는 공개 자료에서 출처를 확인한 것만 넣고 카드마다 출처를 적는다. 제작사·호기마다 값이
// 다르므로 "예시"로만 쓰고, 근거를 못 찾은 값(CO₂ 치환 종료 농도, 과속 트립, 저진공 트립 등)은
// 숫자 대신 "해당 호기 값"으로 둔다. 조사 기록: docs/발전설비_자료_출처_1009.md
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'reference_widgets.dart';

/// 카드 끝의 출처 한 줄.
Widget _src(String text) => Padding(
  padding: const EdgeInsets.only(top: 10),
  child: Text(
    '출처: $text',
    style: TextStyle(fontSize: 11, color: refTextSub, height: 1.4),
  ),
);

/// 고장 조치 표(현상 / 원인 / 조치).
Widget _trouble(List<List<String>> rows) => refTable(
  headers: const ['현상', '원인', '조치'],
  rows: rows,
  flex: const [3, 4, 4],
);

class RefPlantTab extends StatelessWidget {
  const RefPlantTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        refIntroBadge(
          "대형 터빈-발전기 보조계통의 구성·운전 기준·점검·고장 조치. 숫자는 공개된 제작사 "
          "자료·표준·기술 지침에서 확인한 예시값이며 기종·호기마다 다릅니다. 설정값·조작 순서는 "
          "반드시 해당 호기 제작사 매뉴얼과 발전소 절차서(SOP)를 따르십시오.",
          icon: LucideIcons.factory,
        ),
        const SizedBox(height: 16),

        // ───────────── 수소 냉각 ─────────────
        refCard(
          title: "왜 대형 발전기는 수소(H₂)로 냉각하나",
          subtitle: "열전도율 약 7배 · 밀도 약 1/14 → 냉각 향상, 풍손(windage) 감소",
          icon: LucideIcons.wind,
          iconColor: Colors.lightBlue,
          children: [
            refTable(
              headers: const ['항목', '내용'],
              flex: const [2, 5],
              rows: const [
                ['열전도율', '공기의 약 7배'],
                ['밀도', '공기의 약 1/14 → 풍손 감소'],
                ['정격 수소압', '30·45·60·75 psig 등급(약 2.1·3.1·4.1·5.2 barg), 기종마다 다름'],
                ['cold gas', '최대 46 °C, 보통 30~40 °C 운전 (hot-cold 차 15~25 °C)'],
              ],
            ),
            const SizedBox(height: 12),
            refSectionTitle("순도가 떨어지면"),
            refTable(
              headers: const ['순도 변화', '영향'],
              flex: const [2, 4],
              rows: const [
                ['공기 1% 섞임', '가스 밀도 약 14% 증가'],
                ['97% → 95%', 'windage 손실 약 32% 증가'],
                ['99% 대비 90%', '가스 밀도 약 134% 높음'],
              ],
            ),
            const SizedBox(height: 12),
            refWarnBox(
              "수소는 공기 중 4~75 vol%에서 연소, 최소 점화 에너지 0.017 mJ(정전기 불꽃으로도 착화). "
              "케이싱 개방·출입 전 수소 없음 확인(출입 직전 재측정), 방폭·본질안전 공구 사용, "
              "밀폐공간 작업 허가 필수.",
            ),
            _src(
              "ANSI C50.13, Klempner·Kerszenbaum 「Operation and Maintenance of Large "
              "Turbo-Generators」 4장, Panametrics·Proton 응용 자료, OSHA SHIB 01-22-2016, DOE Safetygram",
            ),
          ],
        ),
        const SizedBox(height: 16),

        refExpandCard(
          title: "수소 가스 계통: 판넬·드라이어·분석기",
          subtitle: "H2 Gas Panel · Gas Dryer · Purity Analyzer · Dew Point",
          icon: LucideIcons.gauge,
          iconColor: Colors.teal,
          children: [
            refSectionTitle("가스 판넬(H2 Gas Panel)"),
            refDataRow(
              "구성",
              "수소·CO₂ 공급 매니폴드, 압력 조정기, 보충(make-up)·배출(vent) 밸브, 순도 분석기, "
              "노점계, 압력 지시·경보. 순도(H₂ %)와 노점(수분)은 서로 다른 계기로 따로 감시.",
            ),
            const SizedBox(height: 8),
            refSectionTitle("운전 기준 예시"),
            refTable(
              headers: const ['항목', '예시 값', '근거'],
              flex: const [2, 4, 3],
              rows: const [
                ['순도', '98% 이상 유지, 95%에서 경보', '보험사 지침(AXA XL)'],
                ['순도 하한', '운전 중 95% 이상', 'Westinghouse OMM 38'],
                ['노점', '7.2 °C(45 °F) 이하', 'Westinghouse OMM 38'],
                ['노점', '대부분 상한 0 °C, 보통 −26~0 °C', '미국 발전소 다수(AEP)'],
                ['노점', 'H2 쿨러 입구 냉각수 온도 이하', 'EPRI TR-102949'],
                ['노점 측정', '연속 노점계, 없으면 주 1회 이상', 'EPRI TR-102949'],
              ],
              footer: "노점은 측정 압력 기준 확인: 대기압 −11 °C인 가스가 70 psi에서는 약 +14 °C.",
            ),
            const SizedBox(height: 12),
            refSectionTitle("가스 드라이어(Gas Dryer)"),
            refDataRow(
              "흡착식",
              "twin-tower 활성 알루미나. 한 탑 흡착 중 다른 탑 가열 재생 후 자동 전환. 자체 blower형은 "
              "정지·터닝 기어 중에도 건조 가능(구형 단탑은 정격 속도에서만 동작).",
            ),
            refDataRow(
              "냉동식(freeze-out)",
              "증발기 코일에서 수분 동결 → 주기적 defrost → 수위 경보 시 배수.",
            ),
            const SizedBox(height: 8),
            refSectionTitle("순도 분석기"),
            refTable(
              headers: const ['측정 범위', '용도'],
              flex: const [3, 3],
              rows: const [
                ['H₂ in air 85(80)~100%', '운전 중 순도'],
                ['H₂ in CO₂ 0~100%', '수소 충전·배출'],
                ['air in CO₂ 0~100%', 'CO₂ 치환'],
              ],
              footer: "열전도식(katharometer) 예: ABB, E/One GGA(drift < 0.2%/월). 6개월마다 점검 권고(EPRI).",
            ),
            const SizedBox(height: 12),
            refTipBox(
              "원인 가르기: fan 차압 상승 + 순도 저하 → 공기 유입. fan 차압 상승 + 순도 변화 적음 → "
              "수분 유입. 휴대용 분석기로 교차 확인.",
            ),
            const SizedBox(height: 12),
            refSectionTitle("고장 조치"),
            _trouble(const [
              [
                '순도 저하',
                'seal oil에서 공기 방출, 드라이어 이상, 분석기 오차',
                'scavenging(빼고 보충), 드라이어 점검, 휴대용 분석기·fan 차압 교차 확인',
              ],
              [
                '노점 상승',
                'seal oil 수분, H2·SCW·윤활유 쿨러 누설, gland steam 과다, 드라이어 포화·히터 고장',
                '드라이어 재생 확인, 건조 수소 퍼지, liquid detector·seal oil 수분 확인',
              ],
              [
                '소비량 증가',
                'seal·bushing·이음부 누설, SCW로 유입',
                '보충량 추세, SCW vent 유량 확인, 휴대용 검지기로 누설 위치 찾기',
              ],
              [
                '압력 저하',
                '누설, seal oil 압력 상실',
                '출력 제한 곡선 적용. 가스압이 SCW 압력 아래로 내려가면 차압 보호 상실',
              ],
              [
                '분석기 drift',
                '기준 가스·교정 주기, 시료 라인 오일 유입',
                '교정, coalescing filter, 감압기를 시료 탭 가까이',
              ],
            ]),
            const SizedBox(height: 8),
            refDataRow(
              "누설 잦은 곳",
              "HV bushing, collector 단자, end shield 이음부, access cover, seal 하우징, seal oil drain. "
              "정지 중 수소가 bore conductor를 타고 brush rigging 쪽에 고일 수 있음.",
            ),
            _src(
              "EPRI TR-102949(Westinghouse OMM 38·46·68, GE TIL 1098, PECO·ComEd 절차 수록), "
              "AXA XL PRC.17.12.1, ABB AG/HPPGM, E/One GGA, Machinery Lubrication(AEP)",
            ),
          ],
        ),
        const SizedBox(height: 16),

        refExpandCard(
          title: "CO₂ 퍼지: 수소 충전·배출 순서",
          subtitle: "공기 → CO₂ → H₂ (배출은 반대) · CO₂ 하부 주입",
          icon: LucideIcons.arrowLeftRight,
          iconColor: Colors.blueGrey,
          children: [
            refStep(1, "공기와 수소를 직접 바꾸지 않음. 충전: 공기 → CO₂ → H₂. 배출: H₂ → CO₂ → 공기."),
            refStep(
              2,
              "CO₂는 무거우므로 하부 매니폴드로 주입·상부로 배출. 수소는 상부로 주입. 수소는 위에 "
              "고이므로 확인 측정은 상부에서.",
            ),
            refStep(3, "정지 또는 turning gear에서 천천히. CO₂는 vaporizer로 기화(얼지 않게)."),
            refStep(
              4,
              "치환 종료 판정 농도(CO₂ 중 공기 %, CO₂ 중 H₂ %)는 해당 호기 제작사 값. 분석기 "
              "모드(H₂ in CO₂ / air in CO₂)를 맞춰 측정.",
            ),
            refStep(5, "씰 오일은 치환 전부터 가동, 케이싱에 수소가 있는 동안 계속 유지."),
            const SizedBox(height: 8),
            refDataRow(
              "N₂ 대신 CO₂",
              "공기에 수소 3%가 섞인 가스는 binary 분석기에서 순수 N₂와 같게 읽혀 구분 불가. CO₂는 "
              "액화 상태로 한 병에 많이 담김.",
            ),
            const SizedBox(height: 8),
            refWarnBox(
              "OSHA 사망 사례: 절차상 CO₂ 12병이 필요했는데 6병만 쓰고, 3일 전 측정값으로 출입 → "
              "화재. 정해진 양 전부 사용, 출입 직전 재측정.",
            ),
            _src("OSHA SHIB 01-22-2016, SRS BGA244 Tech Note, ABB AG/HPPGM"),
          ],
        ),
        const SizedBox(height: 16),

        // ───────────── 씰 오일 ─────────────
        refExpandCard(
          title: "씰 오일 계통: 수소가 축을 따라 안 새는 이유",
          subtitle: "Seal Oil System · single/dual/triple-flow · DPR · Vacuum Tank",
          icon: LucideIcons.droplet,
          iconColor: Colors.amber,
          children: [
            refStep(
              1,
              "축이 케이싱을 뚫는 양끝을 seal ring과 오일 막으로 밀봉. 씰 오일 압력을 수소압보다 "
              "항상 일정 차압 높게 유지(DPR: differential pressure regulator).",
            ),
            refStep(
              2,
              "케이싱에 수소가 있는 동안은 정지·turning gear 중에도 씰 오일 유지. 기동은 윤활유 → 씰 오일 "
              "→ 가스 치환 순서.",
            ),
            const SizedBox(height: 8),
            refSectionTitle("형식"),
            refTable(
              headers: const ['형식', '순도 지키는 방법', '예'],
              flex: const [2, 5, 2],
              rows: const [
                [
                  'single-flow (진공 처리)',
                  '링 가운데 급유 → 양쪽으로 흐름. 급유 전 vacuum tank에서 공기·수분 제거',
                  'GE, 도시바',
                ],
                [
                  'dual-flow',
                  '공기측·수소측 오일을 따로 공급, pressure equalizing valve로 같은 압력 유지',
                  'Westinghouse, 미쓰비시전기',
                ],
                ['triple-flow', '공기측·진공 처리 오일·수소측 세 홈', 'Alstom(특허)'],
              ],
              footer: "형식은 제작사 이름이 아니라 해당 호기 P&ID로 확인.",
            ),
            const SizedBox(height: 12),
            refSectionTitle("주요 구성"),
            refDataRow("vacuum tank", "씰로 보낼 오일에서 녹은 공기·수분 제거(수소 순도 유지). 진공 펌프 동반."),
            refDataRow(
              "detraining tank",
              "수소측 배유의 거품·수소 분리 → loop seal·float trap 거쳐 배유.",
            ),
            refDataRow("liquid detector", "발전기 하부 오일·물 고임 검출(고수위 경보)."),
            refDataRow(
              "펌프·백업",
              "AC 주펌프(MSOP), DC 비상펌프(ESOP), 베어링 윤활유 헤더 백업 공급.",
            ),
            const SizedBox(height: 8),
            refSectionTitle("차압(씰 오일압 − 수소압) 예시"),
            refTable(
              headers: const ['출처', '정상', '저차압 동작'],
              flex: const [3, 3, 4],
              rows: const [
                ['GE 특허', '약 8 psid (0.55 bar)', '—'],
                ['Westinghouse dual-flow', '12 psi (0.83 bar)', '8 psi 백업 공급, 5 psi 백업 펌프 기동'],
                ['Westinghouse 501F', '공기측 약 6 psi', '4 psi 경보 + 트립·벤트·퍼지'],
                ['도시바', '0.5 kgf/cm² 이상', '—'],
              ],
            ),
            const SizedBox(height: 8),
            refDataRow(
              "온도",
              "공기측·수소측 오일 온도 차가 커지면 seal ring 변형 → 축 마찰·진동. 예: 정상 약 57 °C, "
              "양측 차 2.2 °C(4 °F) 이내(Westinghouse 특허).",
            ),
            const SizedBox(height: 12),
            refSectionTitle("계장"),
            refDataRow(
              "차압",
              "DP 스위치(트립용) + DP 전송기 2대 백업 예. 수소 신호는 디포밍실, 오일 신호는 공기측 헤더에서 "
              "취출, impulse line은 오일 충전. 양끝 차압 편차 감시.",
            ),
            refDataRow(
              "그 밖에",
              "detraining tank·float trap 레벨 스위치, vacuum tank 레벨·진공계, 수소측 유량계, "
              "공기측·수소측 오일 온도 열전대, 필터 차압.",
            ),
            const SizedBox(height: 12),
            refSectionTitle("고장 조치"),
            _trouble(const [
              [
                '발전기 내 오일 유입 (liquid detector 고수위)',
                'float trap 닫힌 채 고착, 저압 시 넘침',
                'bypass로 sight glass 유면 중간 유지, bypass 열어 둔 채 방치 금지, 유량 이력 비교',
              ],
              [
                '수소 순도 저하',
                'dual-flow 균압 불량, seal ring 마모, ESOP 운전(진공 처리 빠짐), 오일 수분',
                '차압·균압 점검, feed & bleed, 오일 수분 분석',
              ],
              [
                '수소 소비 증가',
                'float trap 열린 채 고착, seal ring 손상',
                'bypass로 유면 수동 유지, 능력 곡선 따라 감발, 유량·온도 상승폭 추세',
              ],
              [
                'DPR 헌팅·설정 이탈',
                '밸브 지연·고착, 설정값 낮음',
                'DP 전송기·impulse line 먼저 확인, 고장 시 bypass·격리로 차압 맞춤',
              ],
              [
                'vacuum tank 고수위·진공 저하',
                'float 열린 채 고착, ESOP 운전',
                '진공 펌프 정지 → 탱크 입구 닫기 → ESOP 기동',
              ],
              [
                'seal ring 마찰·고온·진동',
                '공기측·수소측 온도 차, 오일 온도 낮음',
                '양측 온도 제어 점검, 발전기 가까운 측정점으로 제어',
              ],
            ]),
            const SizedBox(height: 8),
            refWarnBox("씰 오일 완전 상실 = 수소 누설·화재 위험. 터빈 트립, 수소 배출(CO₂) 절차."),
            _src(
              "GE·Westinghouse·도시바·미쓰비시전기·Alstom 특허(US5474304, US4792911, US4969796, "
              "US5186277, JPS60190144 등), CCJ(Athens), NRC LER, 교육 자료",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ───────────── 윤활유 ─────────────
        refExpandCard(
          title: "윤활유 계통(LOT)과 베어링 보호",
          subtitle: "MOP · AC Aux · DC Emergency · Jacking Oil · Turning Gear",
          icon: LucideIcons.cog,
          iconColor: Colors.orange,
          children: [
            refSectionTitle("구성"),
            refTable(
              headers: const ['설비', '역할'],
              flex: const [2, 5],
              rows: const [
                ['MOP', '축 구동 주 오일펌프. 정격 속도 근처에서만 충분한 압력'],
                ['AC 보조펌프', '기동·정지(coast-down) 구간 공급'],
                ['DC 비상펌프', '전원 상실 시. 쿨러·필터 우회해 헤더 직결인 경우 많음'],
                ['jacking oil', '저속에서 축을 고압 오일로 띄움(축 들림 약 0.05~0.13 mm, GE 예)'],
                ['turning gear', '정지 중 축 휨 방지 회전. 일반 3~5 rpm, GE·Westinghouse 예 1.5 rpm'],
                ['vapor extractor', '탱크·베어링 하우징 약한 진공 → 오일 미스트 누출 방지'],
                ['쿨러·필터', '2×100% duplex, transfer valve로 전환'],
              ],
            ),
            const SizedBox(height: 8),
            refWarnBox(
              "3-way transfer valve 핸들이 stop을 넘어가면 공급이 끊김(대형 사고 사례). 전환 시 "
              "밸브 위치·stop 확인.",
            ),
            const SizedBox(height: 12),
            refSectionTitle("저유압 자동기동 순서 예"),
            refTable(
              headers: const ['동작', 'Westinghouse 예', 'GE 예'],
              flex: const [3, 3, 3],
              rows: const [
                ['정상 헤더', '0.97~1.24 bar', '1.72 bar(25 psig)'],
                ['AC 보조 기동', '0.76~0.83 bar', '헤더 15 psig 미만'],
                ['DC 비상 기동', '0.69~0.76 bar', 'TG 펌프 토출 10 psig 미만 등'],
                ['터빈 트립', '0.34~0.48 bar', 'OEM 값'],
              ],
              footer: "NRC 교재(원전 1,800 rpm 터빈) 예시. 순서는 AC 보조 → DC 비상 → 트립, 설정값은 호기 값.",
            ),
            const SizedBox(height: 12),
            refSectionTitle("베어링 금속 온도"),
            refDataRow(
              "범위",
              "정상 운전 74~107 °C. OEM 값이 없으면 대형기 경보 85 °C·트립 96 °C로 보수적 설정 권고. "
              "새 베어링은 길들기 전 약 8 °C 높게 나옴.",
            ),
            const SizedBox(height: 12),
            refSectionTitle("오일 상태 관리 (ASTM D4378)"),
            refTable(
              headers: const ['항목', '기준'],
              flex: const [2, 5],
              rows: const [
                ['점도', '새 오일 대비 ±5%'],
                ['TAN', '0.1~0.2 증가 주의, 0.3~0.4 증가 경고'],
                ['RPVOT', '새 오일의 25% + TAN 상승 → 교체 계획'],
                ['수분', '1,000 ppm(0.1%), 일부 OEM 500 ppm'],
                ['MPC(varnish)', 'ΔE 30 경고(D4378-20)'],
                ['청정도 ISO 4406', '18/15/13 이하, OEM 권고 16/13~14/11'],
              ],
              footer: "주기 예: 매일 육안, 매월 TAN·수분·입자, 분기 RPVOT. Karl Fischer는 free water 못 잡음 → 육안 병행.",
            ),
            const SizedBox(height: 12),
            refSectionTitle("계장·정기 시험"),
            refStep(
              1,
              "pressure drop test(주 1회 예): 운전 중 PS·PT 감지 라인 drain → 압력이 다 빠지기 전 펌프 "
              "기동·토출 압력 확인. 설비에 따라 시험 중 트립 위험.",
            ),
            refStep(
              2,
              "cascade test(연 1회·대정비 후): 정지·터닝 기어 정지 상태에서 AC 주 → AC 예비 → DC 순서 "
              "전환 확인, 전환 시 최저 압력 기록.",
            ),
            refStep(3, "PS는 fail-safe(단선 시 펌프 기동), 2oo3 구성. DCS 단독은 단일 고장점."),
            const SizedBox(height: 12),
            refSectionTitle("고장 조치"),
            _trouble(const [
              [
                '헤더 압력 낮음',
                '펌프 고장, 필터 막힘, transfer valve 오조작, 체크밸브 누설, 탱크 레벨 낮음',
                'AC·DC 펌프 기동 확인, 밸브 위치·stop 확인',
              ],
              [
                '베어링 온도 높음',
                '공급 오일 온도 높음(쿨러·냉각수), 점도 저하, wiping',
                '온도·진동 추세 함께, strainer 금속 조각 확인(wiping은 오일 분석에 안 잡힘)',
              ],
              [
                '진동(oil whirl)',
                '0.42~0.48× 성분(정확히 0.5×면 rub·헐거움 의심)',
                '오일 온도 조정은 임시, 근본 대책은 베어링 개조(OEM 협의)',
              ],
              [
                '거품',
                '공기 혼입, 오염, 수분',
                '수분 먼저 확인, D892·D3427 구분 시험, 실리콘 소포제 사용 금지',
              ],
              [
                '수분 혼입',
                'gland seal 누설, 쿨러 누설, 결로, vapor extractor 고장',
                'KF 시험, 정유기(진공 탈수기는 용존수 80~90% 제거)',
              ],
              ['서보밸브 고착', 'varnish', 'MPC 추세 관리'],
              [
                'DC 펌프 시험 실패',
                '배터리, 열동계전기 트립, DCS 재시작 시 초기값',
                '열동계전기 경보 전용 전환, 차단기 기동전류 150% 설정 권고',
              ],
            ]),
            _src(
              "NRC HRTD 교재 7.3·7.4·11.3, EPRI Lube Notes(2020.12), Mobil Turbine Oil Condition "
              "Monitoring(ASTM D4378), Munich Re 「Lube oil protection systems」, Machinery Lubrication",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ───────────── 냉각수 ─────────────
        refExpandCard(
          title: "냉각수 계통(워터 쿨링): 열을 밖으로 빼내는 3단",
          subtitle: "Stator Cooling → Closed Cooling(CCW) → Service Water",
          icon: LucideIcons.waves,
          iconColor: Colors.blue,
          children: [
            refTable(
              headers: const ['단계', '역할'],
              flex: const [2, 5],
              rows: const [
                ['SCW', '고정자 바 hollow strand에 순수 직접 통수(수냉 고정자)'],
                ['CCW', '탈염수 + 부식억제제 폐회로. 수소 쿨러·윤활유 쿨러·SCW 쿨러·펌프 베어링 냉각'],
                ['Service Water', '해수·하천수·냉각탑 개방 회로로 최종 방열'],
              ],
              footer: "안쪽(SCW·CCW)을 깨끗한 폐회로로 두어 바깥 물이 정밀 설비로 못 들어오게 격리.",
            ),
            const SizedBox(height: 12),
            refSectionTitle("고장 조치"),
            _trouble(const [
              [
                '수소·오일 온도 상승',
                '쿨러 fouling, 냉각수 유량 부족, 온도 조절 밸브 고장',
                '입출구 온도차·차압 추세, 예비 쿨러 전환 후 세정',
              ],
              ['CCW 부식', '보충수·팽창 탱크로 산소 유입, 억제제 부족', '억제제 농도·pH 정기 분석, side-stream 여과'],
            ]),
            _src("POWER 「Monitoring and treatment of closed-loop cooling water systems」, NRC LER(Nine Mile Point 2)"),
          ],
        ),
        const SizedBox(height: 16),

        refExpandCard(
          title: "고정자 냉각수(SCW): 수질·압력·감시",
          subtitle: "Conductivity · Dissolved O₂ · H₂ in SCW · Runback",
          icon: LucideIcons.flaskConical,
          iconColor: Colors.cyan,
          children: [
            refSectionTitle("수질 기준 (25 °C 환산)"),
            refTable(
              headers: const ['항목', '기준', '근거'],
              flex: const [2, 4, 2],
              rows: const [
                ['전도도 정상', '중성 처리 ≤ 0.2 µS/cm, 목표 < 0.15', 'IAPWS'],
                ['전도도 조치 기준', '0.5 µS/cm 넘겨 잡지 않음', 'IAPWS'],
                ['전도도 최대(정지)', 'OEM 6~20 µS/cm, 10 널리 사용', 'IAPWS'],
                ['DO 저산소', '목표 < 10 µg/kg, 한계 20 µg/kg', 'IAPWS'],
                ['DO 고산소', '공기 포화 수준, 2,000 µg/kg 이상', 'IAPWS'],
              ],
              footer: "DO 중간 영역 금지: 산화구리 막이 불안정 → 입자가 strand·strainer 막음(구리 방출 100~500 ppb에서 최대, CIGRE).",
            ),
            const SizedBox(height: 12),
            refSectionTitle("압력·수소 유입"),
            refDataRow(
              "압력 관계",
              "가스(H₂) 압력을 항상 물보다 높게 → 새면 수소가 물로 들어가고 물이 발전기로 안 나옴. "
              "예: SCW를 가스압보다 약 3 psi 낮게(PECO, GE 발전기).",
            ),
            refTable(
              headers: const ['SCW로 들어온 수소(vent)', '기준'],
              flex: const [3, 4],
              rows: const [
                ['기밀 좋은 계통', '약 20 L/day (IAPWS)'],
                ['대부분 OEM 장기 허용', '500 L/day까지 (IAPWS)'],
                ['GE TIL 1098', '0.28 m³/day 이상 → 다음 정지 때 점검, 5.7 m³/day 이상 → 즉시 정지'],
              ],
            ),
            const SizedBox(height: 12),
            refSectionTitle("설비·감시"),
            refDataRow(
              "구성",
              "순환 펌프, 쿨러, full-flow 필터(흔히 1~20 µm 감은 PP, 2×100%), side-stream mixed bed, 팽창 탱크.",
            ),
            refDataRow(
              "막힘 감시",
              "권선 유량·차압을 기준 유량으로 환산해 추세 관리(10% 변화면 의미 있음). 바 온도 편차. "
              "입구 온도를 낮춰 막힘을 가리지 말 것(출구만 내려가고 hot spot 그대로).",
            ),
            refDataRow(
              "runback",
              "SCW 상실 시 자체 냉각으로 버틸 출력까지 빠르게 감발, 정해진 시간 안에 못 내리면 트립. "
              "목표 출력·시간은 OEM 값.",
            ),
            const SizedBox(height: 12),
            refSectionTitle("고장 조치"),
            _trouble(const [
              [
                '전도도 상승',
                '수지 고갈, CO₂ 유입(공기·수소 불순물), 보충수',
                'mixed bed 확인·수지 교체, 한계 초과 시 절차대로 감발·정지',
              ],
              [
                'DO 중간 영역',
                '저산소: 플랜지·밸브·펌프 실 공기 유입. 고산소: 수소 유입, 공기 주입 부족',
                '누설점 점검, 보충수 줄임, 고산소 계통은 탱크 수소 농도 확인',
              ],
              ['권선 차압 상승·바 온도 편차', '산화구리 strand 막힘', '추세 관리, 수화학 원인 교정(세정은 임시)'],
              ['vent 가스량 증가', '바·호스 gas-to-water 누설', '수소 소모량과 비교, OEM 허용치 초과 시 정지 검토'],
            ]),
            _src(
              "IAPWS TGD10-19(2019), CIGRE WG A1.15 「Guide on Stator Water Chemistry Management」(2010), "
              "GE GER-3751A·TIL 1098, EPRI TR-102949, POWER 「Forgotten water」",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ───────────── 복수기 ─────────────
        refExpandCard(
          title: "복수기 진공: 배압·공기 유입",
          subtitle: "Condenser Back Pressure · SJAE · LRVP · Air In-leakage",
          icon: LucideIcons.thermometerSnowflake,
          iconColor: Colors.indigo,
          children: [
            refDataRow(
              "배압과 출력",
              "배압(절대압)이 오르면 LP 터빈 출력 감소·heat rate 악화. 설계 예: 500 MW, 2.5 inHgA(8.5 kPa abs), "
              "냉각수 32 °C. 저진공 트립값은 호기 값(절대압·게이지압 구분).",
            ),
            refDataRow(
              "공기 제거",
              "SJAE(구동 증기 압력이 설계보다 낮으면 성능 저하), LRVP(액봉식, 봉수 온도 높으면 흡입 한계·"
              "cavitation). 기동 hogging, 운전 holding.",
            ),
            refDataRow(
              "공기 유입처",
              "LP gland seal, 팽창 이음, 진공 파괴 밸브, rupture disk, 드레인·계기 배관(EPRI 목록).",
            ),
            const SizedBox(height: 12),
            refSectionTitle("고장 조치"),
            _trouble(const [
              ['배압 서서히 상승 + 냉각수 차압·온도 변화', '튜브 오염·이물', '깨끗할 때 기준값과 비교 후 튜브 세정'],
              ['같은 부하·냉각수에서 배압 계단 상승', '공기 유입', '공기 유량 확인, 누설 탐지(위 유입처)'],
              ['진공펌프 성능 저하', '봉수 유량 부족(오리피스·노즐 막힘), 봉수 온도 높음', '봉수 유량·압력·온도 확인'],
              ['hotwell 수위 높음', '튜브 잠김 → 전열 면적 감소', '복수펌프·수위 조절 확인'],
            ]),
            _src("EPRI TR-112819 「Condenser In-Leakage Guideline」, POWER(2012), Graham, Nash"),
          ],
        ),
        const SizedBox(height: 16),

        // ───────────── 여자·조속기 ─────────────
        refExpandCard(
          title: "여자 계통·AVR·조속기(EHC)",
          subtitle: "Brushless/Static Excitation · OEL/UEL · 64F · Droop",
          icon: LucideIcons.zap,
          iconColor: Colors.deepPurple,
          children: [
            refTable(
              headers: const ['방식', '내용'],
              flex: const [2, 5],
              rows: const [
                ['Brushless', '교류 여자기 + 축의 회전 다이오드 정류, brush·slip ring 없음'],
                ['Static', '변압기 → thyristor 정류 → slip ring으로 계자 공급'],
              ],
            ),
            const SizedBox(height: 8),
            refDataRow(
              "AVR",
              "Auto(전압 설정, PSS 사용 가능) / Manual(계자 전류·전압 설정, PSS 꺼짐). 제한기: OEL(계자 과전류), "
              "UEL(부족여자 → 단부 철심 과열·안정도), V/Hz(철심 과열).",
            ),
            refDataRow(
              "계자 지락(64F)",
              "첫 지락은 전류가 거의 없어 경보. 두 번째 지락 → 계자 일부 단락·자속 불균형 → 진동·회전자 손상. "
              "brushless는 측정용 brush·ring 별도 필요.",
            ),
            refDataRow(
              "조속기(EHC)",
              "병입 전 속도 제어(정격 속도·동기), 병입 후 부하 제어. 계통 주파수 변화에 droop으로 출력 응답.",
            ),
            const SizedBox(height: 8),
            refTable(
              headers: const ['발전기 종류', 'droop 기준'],
              flex: const [3, 3],
              rows: const [
                ['수력·내연', '3.0~4.0%'],
                ['가스터빈', '4.0~5.0%'],
                ['기력', '5.0~6.0%'],
                ['IGCC', '4.0% 이내'],
              ],
              footer: "국내 전력시장운영규칙 별표3. 불감대: 신규 발전기 0.06% 이내. 5% droop = 속도 5%(3 Hz) 변화에 출력 0→100%.",
            ),
            const SizedBox(height: 12),
            refSectionTitle("고장 조치"),
            _trouble(const [
              [
                '계자 지락 경보',
                '절연 저하, 측정 brush 접촉 불량',
                '절연저항 추세, 진동 감시 강화(두 번째 지락 대비), 정지 정비 계획',
              ],
              [
                '여자 상실(40)',
                'field breaker 트립, 계자 개방·단락, AVR 고장, 여자 전원 상실',
                '무효전력 흡수로 고정자 전류 2 pu 넘을 수 있음. 트립 확인 후 원인 조사',
              ],
              [
                '부하 차단 시 과속',
                '조속기가 밸브를 못 닫음',
                '주증기·조절·재열 정지·intercept 밸브 전부 닫힘 확인. 과속 트립 설정은 OEM 값',
              ],
            ]),
            _src("IEEE 421.5 분류(TAMU ECEN667), Basler BE1-64F, ABB 40 relay, KPX 전력시장운영규칙 별표3, KNS DEHC 논문"),
          ],
        ),
        const SizedBox(height: 16),

        refCard(
          title: "밸브 스테이션: 밸브를 왜 한 곳에 모아두나",
          icon: LucideIcons.layoutGrid,
          iconColor: Colors.green,
          children: [
            refStep(1, "주요 차단·조절 밸브와 계기를 접근 쉬운 한 자리(스키드·판넬)에 모음. 예: 주증기, 씰 스팀, H2 gas panel."),
            refStep(2, "순찰·정비 시 한 곳 확인, 비상 시 여러 밸브 빠르게 조작."),
            refStep(3, "밸브 태그·흐름 방향·정상 위치(NO/NC) 표시 확인, 잠금(LOTO) 지점 표시."),
          ],
        ),
        const SizedBox(height: 16),

        refExpandCard(
          title: "전체 흐름 한눈에 보기",
          subtitle: "보일러/원자로 → 증기 → 터빈 → 발전기 → 복수기",
          icon: LucideIcons.workflow,
          iconColor: Colors.blueGrey,
          children: [
            refStep(1, "보일러(화력)·원자로(원자력) 증기 → 터빈 → 발전기 로터 회전."),
            refStep(2, "발전기 내부: 수소 냉각(가스 판넬·드라이어·CO₂ 퍼지), 축 관통부는 씰 오일로 밀봉."),
            refStep(3, "베어링: 윤활유 계통(MOP·AC·DC·jacking oil), 정지 중 turning gear."),
            refStep(4, "열: 수소·윤활유·씰 오일·SCW → CCW → service water로 방열."),
            refStep(5, "터빈 배기 → 복수기 진공에서 응축 → 급수 계통으로 순환. 여자 계통이 전압, 조속기가 출력 제어."),
            refGap(),
            Text(
              "가스·오일·물 계통이 서로 열을 주고받으므로 한 계통 이상이 다른 계통 경보로 먼저 보이기도 "
              "함(예: 수소 쿨러 냉각수 부족 → cold gas 온도 상승 → 출력 제한).",
              style: TextStyle(fontSize: 13, color: refTextSub, height: 1.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 16),

        refWarnBox(
          "위 숫자는 공개된 제작사 특허·교재·기술 지침·표준에서 확인한 예시값입니다. 실제 설정값·정상 범위·"
          "조작 순서는 해당 호기 제작사 매뉴얼과 발전소 절차서(SOP)가 우선입니다.",
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
