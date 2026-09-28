// GD402 가스 밀도계(요꼬가와 EXA GD402 + GD40) 사용설명서 번역본.
//
// 원문: Yokogawa "User's Manual Model GD402 Gas Density Meter" IM 11T03E01-01E
// (13th Edition, 2023.08). 한글 정식 매뉴얼이 없어(요꼬가와 코리아도 영문만
// 올려 둠) 실무에 쓰는 장(설치·배선·배관, 운전, 세 가지 계기별 보정 절차,
// 점검·경보표)을 원문 그대로 옮겼다. 다만 아래 둘은 표/그림이라 글로 옮길 수
// 없어 뺐다 — 1.3 치수도(순수 도면)와 4~7장의 CODE별 설정값 전체 표(레벨마다
// 수백 항목, 3개 계기 종류×4단계가 반복되는 부록 성격이라 필요할 때 원문
// PDF에서 CODE 번호로 찾는 게 낫다).
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/field_view.dart';
import 'reference_widgets.dart';

class Gd402ManualPage extends StatelessWidget {
  const Gd402ManualPage({super.key});

  @override
  Widget build(BuildContext context) =>
      FieldViewTheme(child: Builder(builder: _buildPage));

  Widget _buildPage(BuildContext context) {
    return Scaffold(
      backgroundColor: refBg,
      appBar: AppBar(
        title: Text(
          "GD402 가스 밀도계 매뉴얼",
          style: TextStyle(
            color: refTextMain,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: refWhite,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: refTextMain),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          refIntroBadge(
            "요꼬가와 원문 IM 11T03E01-01E(13th Ed., 2023.08)를 옮긴 것이다. "
            "한글 정식 매뉴얼은 없다(요꼬가와 코리아 홈페이지도 영문만 올려 둠). "
            "번역이 원문과 다르게 읽히면 원문이 맞다 — 보정·조작 전 헷갈리면 "
            "원문 PDF나 담당자 확인을 같이 보십시오.",
          ),
          const SizedBox(height: 8),
          refWarnBox(
            "치수도(1.3, 순수 도면)와 4~7장의 CODE별 설정값 전체 표(3개 계기 "
            "종류 × 4단계, 수백 항목)는 글로 옮기지 않았다. 초기 시운전 때 "
            "CODE 번호로 세부 설정을 하나하나 맞춰야 하면 원문 PDF를 같이 보십시오.",
          ),
          const SizedBox(height: 8),
          refWarnBox(
            "이 페이지는 조작판 버튼 순서·경보표 중심의 대략적인 사용법이다. 실제 밸브 위치, "
            "가스 새는지 확인, 안전 조치는 현장·담당자 확인이 필요하다 — 처음 보정하는 사람은 "
            "혼자 판단하지 말고 경험자와 같이 한다.",
          ),
          const SizedBox(height: 16),

          refExpandCard(
            title: "1. 사양",
            subtitle: "검출기·컨버터 형식, 측정 범위·정확도, 전기 사양",
            icon: LucideIcons.clipboardList,
            iconColor: Colors.blueGrey,
            children: [
              refSectionTitle("검출기(GD40) 종류"),
              refTable(
                headers: ["형식", "용도", "전기 연결"],
                rows: const [
                  ["GD40G", "일반형(비방폭)", "1/2 NPT female"],
                  ["GD40T", "FM 방폭 + 본질안전 (Class I Div.1 B,C,D)", "1/2 NPT female"],
                  ["GD40V", "CSA 방폭 + 본질안전 (Class I Div.1 B,C,D)", "1/2 NPT female"],
                  ["GD40R", "TIIS 방폭 (Exd [ia] IIB+H2T5)", "G1/2 female"],
                ],
                footer: "공통: 배관 연결 1/4 NPT(GD40R은 Rc1/4). 재질 SUS316. 무게 약 7kg(배관 브래킷 포함). "
                    "주변온도 -10~60℃, 습도 5~95%RH, 빗물 등급 IP65/NEMA4X 상당.",
              ),
              const SizedBox(height: 12),
              refSectionTitle("컨버터(GD402) 종류"),
              refTable(
                headers: ["형식", "용도", "무게"],
                rows: const [
                  ["GD402G", "일반형(비방폭)", "약 3kg"],
                  ["GD402T", "FM 방폭 (Class I Div.1 B,C,D)", "약 15kg"],
                  ["GD402V", "CSA 방폭 (Class I Div.1 B,C,D)", "약 15kg"],
                  ["GD402R", "TIIS 방폭", "약 15kg"],
                ],
                footer: "공통: 전기 연결 1/2 NPT female(GD402R은 G3/4). 주변온도 -10~55℃, 습도 5~95%RH, "
                    "IP65/NEMA4X 상당. 표시는 6자리, 분해능 0.0001kg/m³.",
              ),
              const SizedBox(height: 12),
              refWarnBox(
                "검출기·컨버터는 출하할 때 한 쌍으로 조정되어 나온다. 설치할 때 두 기기 시리얼 번호가 짝이 "
                "맞는지 확인한다. 따로 받았다면 GD40 뚜껑 안쪽에 적힌 디텍터 상수를 컨버터에 입력해야 한다.",
              ),
              const SizedBox(height: 12),
              refSectionTitle("측정 성능(밀도 기준 항목)"),
              refTable(
                headers: ["항목", "밀도 kg/m³", "비중", "분자량", "농도 vol%"],
                flex: const [3, 3, 3, 3, 3],
                rows: const [
                  ["범위", "0~6(보정) / 0~60(물리)", "0~5", "0~140", "0~100"],
                  ["최소 범위(스팬)", "0.1", "0.1", "4", "100kg/m³ 상당"],
                  ["응답시간(90%)", "약 5초", "약 5초", "약 5초", "약 5초"],
                  ["직선성", "±1%FS", "±0.001 또는 ±0.5%FS*", "±0.02 또는 ±0.5%FS*", "±0.5% 상당"],
                  ["반복성", "±0.001 또는 ±0.5%FS*", "±0.003/월", "±0.07/월", "±0.003kg/m³/월 상당"],
                ],
                footer: "* 둘 중 큰 쪽 적용. 밀도가 기본 측정값이고 나머지는 밀도에서 환산한다. "
                    "GD402는 표가 아니라 수식 하나로 전부 계산한다.",
              ),
              const SizedBox(height: 12),
              refSectionTitle("수소순도 관련 항목(치환계 포함)"),
              refTable(
                headers: ["항목", "H2 in Air vol%", "H2 in CO2 vol%", "Air in CO2 vol%"],
                rows: const [
                  ["범위", "85~100", "0~100", "0~100"],
                  ["응답시간(90%)", "약 5초", "약 5초", "약 5초"],
                  ["직선성", "±1", "±1", "±1"],
                  ["반복성", "±0.5", "±0.5", "±0.5"],
                  ["드리프트", "±0.5/월", "±0.5/월", "±0.5/월"],
                ],
              ),
              const SizedBox(height: 12),
              refSectionTitle("전기 사양"),
              refTable(
                headers: ["항목", "값"],
                rows: const [
                  ["출력 신호", "4-20mA DC × 2계통(절연, 부하저항 최대 600Ω. BRAIN 통신은 출력1만 유효)"],
                  ["전원", "AC 100~240V(47~63Hz) 또는 DC 24V(허용 21.6~26.4V)"],
                  ["소비전력", "약 12W"],
                  ["퓨즈", "250V 1A 타임래그형(AC형) / 250V 2A 타임래그형(DC24V형), VDE/SEMKO 인증"],
                  ["접점 출력", "MAINTENANCE·FAIL·상하한 경보 신호(무전압 접점)"],
                  ["접점 입력", "보정 개시 신호. 용량 250V AC 3A 또는 30V DC 3A"],
                  ["통신", "BRAIN 프로토콜. 농도·온도·압력·경보 설정값 등을 핸드헬드 단말로 주고받음"],
                  ["시료가스 조건", "온도 -10~60℃, 압력 최대 588.5kPa(abs), 유량 0.1~1L/min"],
                  ["설치 고도", "2000m 이하"],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          refExpandCard(
            title: "2. 설치·배선·배관",
            subtitle: "장소 고르기, 방폭 실링, 배관 구성, 단자별 배선",
            icon: LucideIcons.plug,
            iconColor: Colors.brown,
            children: [
              refSectionTitle("설치 장소 고르는 기준(검출기·컨버터 공통)"),
              refDataRow("부식성 가스 없음", "전자 부품이 상할 수 있다."),
              refGap(),
              refDataRow("진동 적은 곳", "내진동이지만, 진동이 심하면 외부 배선 접속이 풀릴 수 있다."),
              refGap(),
              refDataRow(
                "직사광선 피하기",
                "내부 온도가 비정상적으로 올라간다. 주변 고온 설비의 복사열도 마찬가지다. "
                "컨버터가 직사광선을 받을 수밖에 없다면 후드(옵션)를 단다.",
              ),
              refGap(),
              refDataRow("습도 5~95%RH", "되도록 25~85%RH 범위에서 쓴다."),
              refGap(),
              refDataRow("빗물 직접 안 맞게", "방수형이지만, 점검 때 뚜껑을 열어야 하므로 물이 안 튀는 자리가 낫다."),
              refGap(),
              refDataRow("고도 2000m 이하", ""),
              refGap(),
              refDataRow(
                "컨버터는 조작 편한 자리",
                "화면·버튼을 보기 쉽고, 검출기와 가까울수록 보정·점검이 편하다. 뒤판을 열어 배선하므로 "
                "컨버터 뒤에 400mm 이상 빈 공간이 필요하다.",
              ),
              const SizedBox(height: 12),
              refWarnBox(
                "방폭 지역에 설치할 때는(GD40T/V/R, GD402T/V/R) 그 지역이 해당 방폭 코드에 맞는지 먼저 "
                "확인한다. FM형(T)은 실링 피팅을 인클로저에서 475mm 이내, CSA형(V)은 500mm 이내에 "
                "설치해야 한다(각 지역 전기 코드 준수). 커버는 회로를 끊은 뒤에만 연다.",
              ),
              const SizedBox(height: 14),
              refSectionTitle("배관 — 시료가스·보정가스 라인"),
              refStep(1, "검출기 입구 압력은 0.5MPa 이하로 맞춘다. 높으면 감압밸브, 낮으면 펌프로 승압한다."),
              refStep(2, "가스에 먼지·미스트·수분이 섞여 있으면 필터·미스트 분리기·제습기로 걸러낸다."),
              refStep(
                3,
                "측정 후 내보내는 가스는 검출기 입구와 배출점 압력차가 최소 0.5kPa 이상이어야 한다. 배출관은 "
                "압력손실이 적게 굵은 관을 쓴다.",
              ),
              refStep(4, "가스를 뽑거나 되돌리는 자리에는 반드시 차단밸브를 둔다."),
              refStep(
                5,
                "압력보정용 압력전송기는 검출기 압력을 재는 것이므로, 검출기에서 되도록 가깝게(0.5m 이내) "
                "압력 인출 배관을 낸다.",
              ),
              refGap(),
              refDataRow(
                "재질·치수",
                "스테인리스, 바깥지름 6mm·안지름 4mm부터 JIS 15A(바깥지름 21.7mm)까지 권장.",
              ),
              refGap(),
              refDataRow(
                "수소순도계 구성(치환계 포함)",
                "표준가스는 CO2·H2 두 병. 유량계(0.1~1L/min)를 지나 검출기로 들어가고, 검출기 출구는 "
                "대기압에 가깝게 벤트로 뺀다. 입구압력(P1) 최대 0.5885MPa(abs), 입·출구 압력차(P1-P2) "
                "0.5kPa 이상.",
              ),
              refGap(),
              refWarnBox(
                "치환계(H2 in CO2, Air in CO2)는 검출기에 걸리는 압력이 흔들리면 출력도 흔들린다. "
                "유량계를 검출기보다 위쪽(하류)에 두어, 검출기에 걸리는 압력이 대기압에 가깝게 되도록 한다.",
              ),
              const SizedBox(height: 14),
              refSectionTitle("배선 — 전원"),
              refDataRow(
                "케이블",
                "AC형은 굵기 1.25~2.5mm² 3심, DC24V형은 2심. 바깥지름 8~16mm. 끝단 피복을 6mm 벗겨 "
                "L·N·G(AC) 또는 +·-·G(DC) 단자에 물린다(조임 토크 0.5Nm).",
              ),
              refGap(),
              refDataRow(
                "CE 마크 지역",
                "외부 차단기(IEC947-1/947-3, 정격 5A)를 컨버터와 같은 방에, 조작자가 접근 가능한 자리에 "
                "달고 '컨버터 전원 스위치'라고 표시한다(DC24V형은 불필요).",
              ),
              refGap(),
              refWarnBox(
                "방폭형(GD402R/T/V)은 내장 전원 스위치가 있지만 방폭 지역에서는 조작할 수 없다 — 항상 ON에 "
                "둔 채 전원을 껐다 켤 때는 반드시 외부 차단기를 쓴다.",
              ),
              const SizedBox(height: 14),
              refSectionTitle("배선 — 단자표"),
              refTable(
                headers: ["배선", "단자", "비고"],
                rows: const [
                  ["출력 1 (4-20mA)", "3, 4번", "BRAIN 통신은 이 단자만 유효. 극성 주의"],
                  ["출력 2 (4-20mA)", "5, 6번", "절연, 부하저항 최대 600Ω"],
                  ["압력전송기(EJX310A)", "7~10번", "SUP./+·-/AL/CHK. 단자 나사 M4"],
                  ["검출기(GD40) 케이블", "11~13번", "실드선은 13번(컨버터 쪽만 접지)"],
                  ["경보·FAIL·보정개시 등 접점", "16~19번 등", "무전압 접점, 구동 전원은 별도"],
                ],
                footer: "출력·접점 케이블은 완성외경 8~16mm 실드케이블. 출력용 0.75mm² 이상, 접점용 "
                    "0.13~1.25mm²(보정용 접점은 1.25mm² 이상). 단자 조임 토크 0.5Nm.",
              ),
              refGap(),
              refDataRow(
                "검출기 케이블",
                "완성외경 10~13.5mm 실드케이블. M4 크림프 단자로 마감, 실드는 컨버터 13번 단자에만 "
                "접지(반대쪽은 접지하지 않는다). 노이즈로 오작동하면 요꼬가와 GDW-L(2심 이중 실드) "
                "케이블을 쓰고, 바깥 실드는 컨버터 13번·검출기 접지단자에, 안쪽 실드는 컨버터 접지단자에 "
                "연결한다.",
              ),
              refGap(),
              refDataRow(
                "접지",
                "GD40R(방폭)은 2mm² 이상 도체로 A종 접지. GD402(컨버터)는 D종 접지. GD40T는 미국 "
                "NEC(ANSI/NFPA 70), GD40V는 캐나다 전기코드를 따른다.",
              ),
            ],
          ),
          const SizedBox(height: 16),

          refExpandCard(
            title: "3. 운전",
            subtitle: "처음 켤 때 확인할 것, 조작판, 버튼, 정지·재시작",
            icon: LucideIcons.power,
            iconColor: Colors.teal,
            children: [
              refSectionTitle("운전 준비"),
              refStep(1, "설치·배관·배선이 도면대로 됐는지 확인한다."),
              refStep(2, "전원을 넣는다."),
              refStep(3, "조작판·버튼을 확인한다(아래)."),
              refStep(4, "설정 파라미터가 실제 운전 조건과 맞는지 확인한다 — 출하 시 기본값 그대로다."),
              refStep(5, "표준가스로 보정한다(8·9·10장)."),
              refStep(6, "계기 성능을 확인한 뒤 정상 운전에 들어간다."),
              const SizedBox(height: 12),
              refWarnBox(
                "출하 시 기본값 그대로 쓰기 전에, 그 값이 지금 현장 조건과 맞는지 꼭 확인한다. 매뉴얼 "
                "뒤쪽 '설정값 기록표'에 적어 두면 나중에 누가 바꿨는지 추적하기 쉽다.",
              ),
              const SizedBox(height: 14),
              refSectionTitle("조작판"),
              refDataRow("버튼 7개", "YES · NO · MODE · ◀▶(자리 이동) · ▲▼(값 바꾸기) · ENT."),
              refGap(),
              refDataRow(
                "MODE",
                "평소(측정) 화면에서 누르면 조작·설정 메뉴로 들어간다. 다른 메뉴 어디서든 다시 누르면 "
                "바로 측정 화면으로 나온다.",
              ),
              refGap(),
              refDataRow(
                "YES / NO",
                "메시지 칸에 뜬 코드가 깜빡일 때 YES는 그 항목 선택, NO는 다음 후보로 넘기기.",
              ),
              refGap(),
              refDataRow("◀▶ / ▲▼ / ENT", "숫자 입력. ◀▶로 자리를 옮기고 ▲▼로 숫자를 바꾼 뒤 ENT로 확정."),
              refGap(),
              refDataRow(
                "비밀번호",
                "메뉴에 걸려 있을 수 있다. <*PASSW> 프롬프트가 뜨면 정해진 비밀번호(XXX)를 입력하고 "
                "ENT. 틀리면 그 레벨에 못 들어간다.",
              ),
              refGap(),
              refDataRow(
                "레벨 구조",
                "측정 레벨(평소 화면) → 조작 레벨(MODE로 진입, 보정 방식·밸브 점검) → 설정 레벨(측정 "
                "화면에서 * 키로 진입, 보정 데이터·출력) → 서비스 레벨(CODE 번호로 접근하는 상위 설정).",
              ),
              const SizedBox(height: 14),
              refSectionTitle("표시 항목"),
              refDataRow("측정값", "항상 표시된다."),
              refGap(),
              refDataRow("경보 표시", "농도 이상, 입력 압력 이상, 보정값 이상 등."),
              refGap(),
              refDataRow("보정 관련", "보정 시각, 안정화 시간, 보정 시작 시각, 보정 주기."),
              refGap(),
              refDataRow(
                "자기진단",
                "센서 발진 정지, 발진 주파수 이상, 센서 온도 감지 실패, A/D 변환 이상, 메모리 이상.",
              ),
              const SizedBox(height: 14),
              refSectionTitle("정지·재시작"),
              refDataRow("정지할 때", "외부 차단기로 전원을 끈다. 배관에 남은 표준가스가 있으면 밸브를 잠근다."),
              refGap(),
              refDataRow("재시작할 때", "전원을 넣고 설정값이 그대로인지 확인한 뒤, 표준가스로 한 번 더 확인 보정하는 것을 권장한다."),
            ],
          ),
          const SizedBox(height: 16),

          refExpandCard(
            title: "8. 밀도계 보정 절차",
            subtitle: "GD402를 '밀도계'로 쓸 때 (반자동·수동·자동 세 가지)",
            icon: Icons.speed,
            iconColor: Colors.indigo,
            children: [
              refDataRow(
                "이 장을 보는 경우",
                "GD402를 순수 밀도계로 쓸 때. 열량계는 9장, 수소순도계(치환계 포함)는 10장을 본다.",
              ),
              const SizedBox(height: 10),
              refSectionTitle("준비"),
              refStep(1, "조작 레벨에서 반자동/수동 보정 파라미터를 설정한다."),
              refStep(2, "설정 레벨에서 보정 데이터(제로점·스팬점 밀도값, 보정 중 출력 유지 방식)를 넣는다."),
              refStep(3, "서비스 레벨 CODE 13(자동보정)·CODE 14(원격 반자동)를 사용/미사용으로 정한다."),
              refStep(4, "서비스 레벨 CODE 15에서 보정 항목·보정 시각·안정화 시간 등을 정한다."),
              refStep(5, "밸브 점검 순서(조작 레벨)로 제로가스·스팬가스 밸브가 제대로 열리는지 확인한다."),
              refGap(),
              refTable(
                headers: ["보정 데이터", "키", "입력 범위"],
                rows: const [
                  ["제로점 밀도", "*Z_DNS", "0.0000~6.0000 kg/m³"],
                  ["스팬점 밀도", "*S_DNS", "0.0000~6.0000 kg/m³"],
                  ["보정 중 출력", "*C_HLD", "0=미유지 1=직전값 유지 2=설정값 유지"],
                  ["유지 설정값", "*PR.SET", "-10.0~110.0 (C_HLD=2일 때만)"],
                ],
              ),
              const SizedBox(height: 12),
              refSectionTitle("반자동 보정"),
              refButtonGuide(
                btnName: "SEM.CAL 고르기",
                purpose: "반자동 보정 모드로 들어가기",
                action: "측정 화면에서 MODE(비밀번호 있으면 입력) → 후보를 NO로 넘기다 SEM.CAL에서 YES.",
              ),
              refGap(),
              refButtonGuide(
                btnName: "START",
                purpose: "보정 시작",
                action: "START에서 YES → 제로가스 밸브가 자동으로 열리고 ZERO 값이 뜬다.",
              ),
              refGap(),
              refButtonGuide(
                btnName: "SPAN",
                purpose: "위쪽 기준점",
                action: "이어서 스팬가스로 자동 전환, SPAN 값이 뜬다.",
              ),
              refGap(),
              refButtonGuide(
                btnName: "WAIT → 측정 모드",
                purpose: "마무리",
                action: "안정화 시간 뒤 자동으로, 또는 YES로 바로 측정 모드에 돌아간다.",
              ),
              const SizedBox(height: 12),
              refSectionTitle("수동 보정"),
              refButtonGuide(
                btnName: "MAN.CAL 고르기",
                purpose: "수동 보정 모드로 들어가기",
                action: "측정 화면에서 MODE → 후보를 NO로 넘기다 MAN.CAL에서 YES.",
              ),
              refGap(),
              refButtonGuide(
                btnName: "ZERO",
                purpose: "영점 잡기",
                action: "ZERO에서 YES → 제로가스 밸브를 사람이 연다 → 값이 안정되면 ENT로 확정. "
                    "건너뛰려면 YES 대신 NO.",
              ),
              refGap(),
              refButtonGuide(
                btnName: "SPAN",
                purpose: "기울기 잡기",
                action: "같은 방식으로 스팬가스를 흘리고 안정되면 ENT.",
              ),
              const SizedBox(height: 12),
              refSectionTitle("자동 보정"),
              refDataRow(
                "설정",
                "서비스 레벨 CODE 13(*AUTO.C)을 1로 하면 켜진다. 정해진 주기마다 제로 → 스팬 → 대기 → "
                "측정모드 순서로 스스로 돈다. 이 도중에도 반자동·수동으로 끼어들 수 있다(끼어들면 그 회차는 "
                "건너뜀).",
              ),
            ],
          ),
          const SizedBox(height: 16),

          refExpandCard(
            title: "9. 열량계 보정 절차",
            subtitle: "GD402를 '열량계'로 쓸 때 — 8장과 흐름은 같고 열량값이 추가된다",
            icon: LucideIcons.flame,
            iconColor: Colors.deepOrange,
            children: [
              refDataRow(
                "8장과 다른 점",
                "보정 데이터에 밀도값 말고 열량값도 같이 넣는다. 순서(반자동·수동·자동)와 버튼 조작은 "
                "8장과 완전히 같다.",
              ),
              refGap(),
              refTable(
                headers: ["보정 데이터", "키", "입력 범위"],
                rows: const [
                  ["제로점 열량", "*Z_CAL", "0.000~133.000 MJ/m³"],
                  ["제로점 밀도", "*Z_DNS", "0.0000~6.0000 kg/m³"],
                  ["스팬점 열량", "*S_CAL", "0.000~133.000 MJ/m³"],
                  ["스팬점 밀도", "*S_DNS", "0.0000~6.0000 kg/m³"],
                  ["보정 중 출력", "*C_HLD", "0=미유지 1=직전값 유지 2=설정값 유지"],
                ],
              ),
              refGap(),
              refTipBox("보정 순서(반자동·수동·자동)는 8장 '밀도계 보정 절차'를 그대로 따라 하면 된다."),
            ],
          ),
          const SizedBox(height: 16),

          refExpandCard(
            title: "10. 수소순도계 보정 절차",
            subtitle: "GD402를 '수소순도계·치환계'로 쓸 때 — 여기가 실제로 쓰는 장",
            icon: LucideIcons.wind,
            iconColor: Colors.blue,
            initiallyExpanded: true,
            children: [
              refWarnBox(
                "수소순도계는 반자동·자동 보정이 없다 — 오직 수동 보정만 있다. 8·9장과 순서가 다르니 "
                "그대로 따라 하면 안 된다.",
              ),
              const SizedBox(height: 10),
              refDataRow("제로가스", "수소(H2) 100%"),
              refGap(),
              refDataRow("스팬가스", "이산화탄소(CO2) 100%"),
              const SizedBox(height: 10),
              refWarnBox(
                "수소는 공기 중 4~75%에서 폭발성이다. 제로가스 밸브를 열고 닫는 작업 중 배관·연결부에서 "
                "새는 곳이 없는지 먼저 확인하고, 환기가 되는 곳에서 작업한다. 이 페이지는 조작판 버튼 순서만 "
                "정리한 것이라, 실제 제로·시료·스팬 밸브가 현장에 어느 것인지는 배관도(그림 2.10, 이 페이지엔 "
                "없음)나 담당자 확인이 필요하다 — 처음 하는 사람은 혼자 밸브를 짐작해서 돌리지 말 것.",
              ),
              const SizedBox(height: 12),
              refSectionTitle("준비"),
              refDataRow(
                "조작 레벨에서 설정",
                "보정 중 출력 유지 방식(*C_HLD: 0=미유지 1=직전값 유지 2=설정값 유지)과, 2일 때만 쓰는 "
                "유지 설정값(*PR.SET, -10.0~110.0)을 정한다. 제로·스팬 밀도값은 따로 입력하지 않는다 — "
                "계기가 읽은 값을 그대로 쓴다.",
              ),
              const SizedBox(height: 12),
              refSectionTitle("보정 순서(수동뿐)"),
              refButtonGuide(
                btnName: "MAN.CAL 고르기",
                purpose: "보정 모드로 들어가기",
                action: "측정 화면에서 MODE → 후보를 NO로 넘기다 MAN.CAL에서 YES.",
              ),
              refGap(),
              refButtonGuide(
                btnName: "ZERO (닫기 → 열기)",
                purpose: "H2로 영점 잡기",
                action:
                    "ZERO에서 YES → 먼저 시료가스 밸브를 닫는다 → 제로가스(H2) 밸브를 연다 → 화면에 "
                    "밀도값이 뜬다(예: 0.0899 근처, H2 자체 밀도). 값이 안정되면 CAL.SET에서 ENT로 확정 "
                    "→ 제로가스 밸브를 닫는다.",
              ),
              refGap(),
              refButtonGuide(
                btnName: "SPAN",
                purpose: "CO2로 기울기 잡기",
                action:
                    "이어서 스팬가스(CO2) 밸브를 연다 → 화면에 밀도값이 뜬다(예: 1.9771 근처, CO2 자체 "
                    "밀도). 안정되면 CAL.SET에서 ENT로 확정 → 스팬가스 밸브를 닫는다 → 시료가스 밸브를 "
                    "다시 연다.",
              ),
              const SizedBox(height: 12),
              refWarnBox(
                "보정값이 범위를 벗어나면 ALM.10(보정 오류)이 뜬다. YES나 NO를 누르면 MAN.CAL로 되돌아간다 "
                "— 가스가 정말 100%인지, 배관에 공기가 안 섞였는지부터 의심한다.",
              ),
              refGap(),
              refTipBox(
                "화면에 뜨는 예시값 0.0899(H2)·1.9771(CO2)은 표준상태(0℃, 101.325kPa)에서 두 가스 "
                "자체의 밀도다 — 실제로 뜨는 숫자가 이 언저리인지 눈으로도 가늠할 수 있다.",
              ),
            ],
          ),
          const SizedBox(height: 16),

          refExpandCard(
            title: "11. 점검·유지보수, 경보·고장 전체 표",
            subtitle: "정기 점검 주기, ALM 10개·Err 5개 전부",
            icon: LucideIcons.wrench,
            iconColor: Colors.amber.shade800,
            children: [
              refSectionTitle("정기 점검"),
              refDataRow(
                "표준가스 점검",
                "2~3개월마다(운전 조건에 따라 주기 조정) 표준가스로 출력을 확인하고, 오차가 있으면 "
                "제로·스팬 보정.",
              ),
              refGap(),
              refDataRow("시료가스 유량", "600mL/min ±10% 유지. 배관 누설도 같이 확인."),
              refGap(),
              refDataRow("검출기 O-링", "재질 NBR. 2~3년 주기로 교체 권장(요꼬가와 문의)."),
              refGap(),
              refDataRow(
                "퓨즈 교체",
                "외부 차단기로 전원을 먼저 끈다 → 퓨즈 홀더 캡을 반시계로 90° 돌려 분리 → 규격 맞는 새 "
                "퓨즈로 교체 → 시계로 90° 돌려 고정. 새 퓨즈가 금방 또 나가면 회로 이상일 수 있으니 "
                "서비스 문의.",
              ),
              refGap(),
              refDataRow("청소", "부드러운 천. 비방폭형 투명창은 중성세제 가능(유기용제 금지)."),
              const SizedBox(height: 14),
              refSectionTitle("경보(ALM) — 접점 16·17번, 측정은 계속됨"),
              refTable(
                headers: ["번호", "무슨 뜻", "조치"],
                flex: const [2, 5, 5],
                rows: const [
                  ["ALM.01", "물리 밀도 상하한 벗어남", "상하한 설정값 확인"],
                  ["ALM.02", "보정 밀도 상하한 벗어남", "상하한 설정값 확인"],
                  ["ALM.03", "비중 상하한 벗어남", "상하한 설정값 확인"],
                  ["ALM.04", "열량 상하한 벗어남", "상하한 설정값 확인"],
                  ["ALM.05", "분자량 상하한 벗어남", "상하한 설정값 확인"],
                  ["ALM.06", "농도 상하한 벗어남", "상하한 설정값 확인"],
                  ["ALM.07", "제로·스팬가스 압력 이상", "가스 압력·유량 재확인"],
                  ["ALM.08", "시료가스 온도 이상(-25~80℃ 밖)", "허용 온도 안으로"],
                  ["ALM.09", "배터리 이상(접점 신호 없음)", "제조사 서비스 문의"],
                  ["ALM.10", "보정값(제로·스팬) 오류", "재보정, 가스 순도부터 의심"],
                ],
              ),
              const SizedBox(height: 12),
              refSectionTitle("고장(FAIL) — 접점 18·19번이 열림(open)으로 바뀜"),
              refTable(
                headers: ["번호", "무슨 뜻", "조치"],
                flex: const [2, 5, 5],
                rows: const [
                  ["Err.01", "센서 발진 정지(발진 주파수 감지 실패)", "전원 재투입, 안 되면 서비스 문의"],
                  [
                    "Err.02",
                    "발진 주파수 이상(F2: 1000~10000Hz, F4: 4000~10000Hz 밖)",
                    "전원 재투입, 안 되면 서비스 문의",
                  ],
                  ["Err.03", "센서 온도 감지 이상", "서비스 문의"],
                  ["Err.04", "A/D 변환 이상", "서비스 문의"],
                  ["Err.05", "메모리 이상(EEPROM/EPROM/RAM)", "서비스 문의"],
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
