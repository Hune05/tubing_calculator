// GD402 가이드(10-01, 10-02 넓힘): 수소 순도계 설정~교정에 더해 설치·배선, 밀도계·열량계 설정·교정까지 탭 16장.
// 키 조작은 "화면 따라하기"(gd402_panel.dart)로 단계마다 누를 키와 표시창 모습을 보여 준다.
// 근거: 사용자가 준 요꼬가와 설명서 IM 11T03E01-01E(13판), IM 11T03E01-51E(GD402G /M1 단자대형, 7판).
// 화면 글자·코드·범위는 설명서 그대로, 숫자 표시의 측정값은 그림용 예시. 설명서끼리 다른 곳은 화면에 밝힌다.
import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../reference/page/reference_widgets.dart';
import 'gd40_principle.dart';
import 'gd402_panel.dart';

part 'gd402_guide_more.dart';

class Gd402GuidePage extends StatelessWidget {
  final int initialTab;
  const Gd402GuidePage({super.key, this.initialTab = 0});

  static const tabs = ['개요', '원리·구조 (GD40)', '키·화면', '설치·배선', '수소 설정', '수소 출력', '수소 알람', '수소 표시', '수소 교정', '운전·정지', '알람·고장 코드', '점검', '밀도계 설정', '밀도계 교정', '열량계 설정', '열량계 교정'];

  /// 탭 번호(다른 화면에서 바로 열 때).
  static const tabH2Cal = 8;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      initialIndex: initialTab,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('GD402 가스 밀도계 가이드'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (var i = 0; i < tabs.length; i++) Tab(key: Key('gdg_tab_$i'), text: tabs[i])],
          ),
        ),
        body: const TabBarView(
          children: [_Overview(), _Principle(), _Keys(), _Install(), _FirstSetup(), _Output(), _Alarm(), _Display(), _Calibration(), _Operation(), _Codes(), _Maintenance(), _DensSetup(), _DensCal(), _CalSetup(), _CalCal()],
        ),
      ),
    );
  }
}

Widget _page(String id, List<Widget> children) => ListView(key: Key('gdg_list_$id'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: children);

Widget _title(String t) => Padding(
  padding: const EdgeInsets.only(top: 18, bottom: 8),
  child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
);

List<Widget> _rows(List<(String, String)> rows) => [
  for (var i = 0; i < rows.length; i++) ...[if (i > 0) refGap(), refDataRow(rows[i].$1, rows[i].$2)],
];

List<Widget> _steps(List<String> s) => [for (var i = 0; i < s.length; i++) refStep(i + 1, s[i])];

// ── 자주 쓰는 화면 ──
const _measure = GdStep(say: '', data: '98.2', msg: 'H2_AIR', opPtr: kOpMeasure);

GdStep _meas(String say, {GdKey? press, GdGas? gas}) => GdStep(say: say, press: press, data: _measure.data, msg: _measure.msg, opPtr: kOpMeasure, gas: gas);

GdStep _set(String say, String msg, int ptr, {GdKey? press}) => GdStep(say: say, press: press, msg: msg, setPtr: ptr, keyOp: const {GdKey.yes, GdKey.no});

/// 측정 모드에서 * → *RANGE → … 원하는 설정 레벨 메뉴까지.
List<GdStep> _toSetting(int target, String what) => [
  _meas('측정 모드. 덮개 안 오른쪽 * 스위치를 누름 ($what은 설정 레벨)', press: GdKey.star),
  for (var i = 0; i <= target; i++)
    _set(
      i == 0
          ? '설정 레벨로 들어옴(비밀번호를 걸어 두었으면 먼저 XXX *PASSW를 넣고 [ENT]). 메뉴는 [NO]로 넘기고 [YES]로 들어감. ${target == 0 ? '*RANGE에서 [YES]' : '[NO]로 다음 메뉴'}'
          : (i == target ? '${['', '*CAL.DT', '*ALARM', '*SERVC'][i]}에서 [YES]' : '[NO]로 다음 메뉴'),
      ['*RANGE', '*CAL.DT', '*ALARM', '*SERVC'][i],
      i,
      press: i == target ? GdKey.yes : GdKey.no,
    ),
];

// ───────── 1. 개요 ─────────

class _Overview extends StatelessWidget {
  const _Overview();

  @override
  Widget build(BuildContext context) => _page('overview', [
    refIntroBadge('요꼬가와 GD402 가스 밀도계를 수소 순도계(발전기 수소 냉각)로 쓸 때의 설정·교정 순서입니다. 화면 글자와 코드는 설명서 그대로이고, 표시창의 측정값 숫자는 그림용 예시입니다.'),
    _title('계통'),
    gdGasFigure(GdGas.measuring, key: const Key('gdg_overview_gas')),
    const SizedBox(height: 10),
    ..._rows(const [
      ('검출기', 'GD40 (가스 밀도를 재는 센서)'),
      ('변환기', 'GD402 (표시·설정·출력). 수소 순도는 밀도에서 계산'),
      ('압력 전송기', 'EJX310A 절대압 (옵션). 수소 순도계로 쓰려면 압력 보상용으로 필요'),
      ('교정 가스', '제로 = 수소(H2) 100%, 스팬 = 이산화탄소(CO2) 100%. 공기는 교정에 안 씀'),
    ]),
    _title('측정 범위 (vol%)'),
    refTable(
      headers: const ['항목', 'H2 in Air', 'H2 in CO2', 'Air in CO2'],
      rows: const [
        ['범위', '85~100', '0~100', '0~100'],
        ['응답(90%)', '약 5초', '약 5초', '약 5초'],
        ['직선성', '±1', '±1', '±1'],
        ['반복성', '±0.5', '±0.5', '±0.5'],
        ['드리프트', '±0.5/월', '±0.5/월', '±0.5/월'],
      ],
      footer: '※ H2 in Air = 수소 순도(운전 중), H2 in CO2·Air in CO2 = 치환(가스 바꿀 때) 농도',
    ),
    _title('시료가스 조건'),
    ..._rows(const [
      ('온도', '-10~60 ℃ (결로 없이)'),
      ('압력', '최대 588.5 kPa abs. 검출기 입구 0.5 MPa 이하 (높으면 감압 밸브)'),
      ('유량', '0.1~1 L/min (점검 기준 600 mL/min ±10%)'),
      ('차압', '입구와 회수점 차이 0.5 kPa 이상'),
      ('가스', '부식성 가스·아세틸렌 제외'),
    ]),
    _title('배관 주의'),
    ..._steps(const [
      '유량계는 검출기 앞(상류)에. H2 in CO2·Air in CO2 범위에서 검출기 압력을 대기압 가깝게 해야 출력이 안 흔들림',
      '시료 회수점에 반드시 차단 밸브(stop valve)',
      '압력 전송기 도압관은 검출기에서 0.5 m 안쪽으로',
      '교정 때 출구 압력은 대기압',
    ]),
    _title('전원·출력·접점'),
    ..._rows(const [
      ('전원', '100~240 V AC 또는 24 V DC, 약 12 W\n외부 차단기 5 A'),
      ('퓨즈', 'AC형 250 V 1 A time lag (A1109EF)\nDC형 250 V 2 A time lag (A1111EF)'),
      ('출력 1', '4-20 mA, 단자 3·4, BRAIN 통신 가능, 부하 600 Ω 이하 (통신 시 250~550 Ω)'),
      ('출력 2', '4-20 mA, 단자 5·6, 부하 600 Ω 이하'),
      ('접점 출력', '250 V AC 3 A / 30 V DC 3 A, 무전압 릴레이\nMAINT·ALM·FUNC·SEL GAS는 NO/NC 선택, FAIL은 NC 고정'),
      ('접점 입력', '단자 1·2, 무전압 신호만. 치환계 범위 선택 (열림 = Air in CO2, 닫힘 = H2 in CO2)'),
    ]),
    _title('단자 (일반형 GD402G)'),
    refTable(
      headers: const ['단자', '표시', '용도'],
      rows: const [
        ['1+ / 2−', 'CONT INP', '접점 입력'],
        ['3+ / 4−', 'ANLG OUT1', '4-20 mA + BRAIN'],
        ['5+ / 6−', 'ANLG OUT2', '4-20 mA'],
        ['7+ / 8−', 'SNSR PWR', '압력 전송기 전원'],
        ['9+ / 10−', 'SNSR INP', '압력 전송기 입력'],
        ['11+ / 12−', 'DET INP', 'GD40 검출기'],
        ['13', 'SHIELD', '검출기 케이블 차폐'],
        ['14 / 15', 'MAINT', '유지보수 접점'],
        ['16 / 17', 'ALM', '알람 접점'],
        ['18 / 19', 'FAIL', '고장 접점 (고장 시 열림)'],
        ['20 / 21', 'SPAN/FUNC', 'FUNCTION 접점'],
        ['22 / 23', 'ZERO/SEL GAS', 'SELECT GAS 접점'],
        ['24 / 25 / 26', 'L(+) / N(−) / G', '전원 / 접지'],
      ],
      footer: '※ 압력 전송기: 7과 9 연결, 8 → 전송기 −, 10 → 전송기 + (설명서 그림 2.11·2.17)',
    ),
    _title('단자 (단자대형 GD402G /M1)'),
    refTable(
      headers: const ['단자', '표시', '용도'],
      rows: const [
        ['1+ / 2−', 'CONT', '접점 입력'],
        ['3+ / 4−', 'OUT1', '4-20 mA + BRAIN'],
        ['5+ / 6−', 'OUT2', '4-20 mA'],
        ['7+ / 8−', 'SNSR', '압력 전송기'],
        ['9+ / 10−', 'DET', 'GD40 검출기'],
        ['11', 'SHIELD', '검출기 차폐'],
        ['12', 'G', '접지'],
        ['13 / 14', 'MAINT', '유지보수 접점'],
        ['15 / 16', 'ALM', '알람 접점'],
        ['17 / 18', 'FAIL', '고장 접점'],
        ['19 / 20', 'FUNC', 'FUNCTION 접점'],
        ['21 / 22', 'SEL', 'SELECT GAS 접점'],
        ['23 / 24', 'L / N', '전원'],
      ],
    ),
    const SizedBox(height: 8),
    refWarnBox('/M1 설명서(51E) 본문에는 일반형 단자 번호(13, 16·17, 18·19, 24·25·26 등)가 그대로 남아 있어 그림과 다름. 배선은 위 표(설명서 그림 2.11)대로. 압력 전송기 극성도 그림상 이상해 보이니 현장 확인'),
  ]);
}

// ───────── 1-2. GD40 원리·구조 ─────────

class _Principle extends StatelessWidget {
  const _Principle();

  @override
  Widget build(BuildContext context) => _page('principle', [
    refIntroBadge('검사관이 "순도를 어떻게 재느냐"고 물을 때: 수소 순도를 직접 재는 게 아니라 가스의 무게(밀도)를 재서 계산합니다. 근거는 요꼬가와 기술 자료 TI 11T03E01-01E와 사용자 설명서입니다.'),
    _title('한 줄로'),
    refTipBox('얇은 쇠 원통을 가스 속에서 떨게 하면, 둘레 가스도 같이 흔들려 원통이 무거워진 것처럼 진동수가 내려감. 가스가 무거울수록(밀도가 클수록) 진동수가 더 내려감. 수소는 공기보다 약 14배 가벼워서, 공기가 조금만 섞여도 밀도가 크게 달라짐 → 밀도로 순도를 계산'),
    _title('검출기 GD40 단면'),
    gd40StructureFigure(),
    const SizedBox(height: 6),
    const Text('※ 원리를 보이려고 단순화한 그림 (부품 배치는 TI 그림 1 기준)', style: TextStyle(fontSize: 12, color: AppColors.textSub)),
    const SizedBox(height: 10),
    ..._rows(const [
      ('원통 공진자', '얇은 벽 스테인리스 원통. 가스 속에서 떨리는 "저울" 역할. 녹 안 나게 스테인리스'),
      ('압전 소자', '원통 네 곳에 두 쌍. 한 쌍은 원통을 떨게 하고(구동), 한 쌍은 떨림을 읽음(검출). 전기 ↔ 떨림을 바꿔 주는 부품'),
      ('가스 챔버', '원통 둘레의 가스 공간. 시료가스가 입구로 들어와 원통 바깥을 감싸고 지나 출구로 나감. 원통 둘레를 시료로 채워야 그 가스의 밀도가 진동수에 실림 (가스는 원통 바깥을 지나감, TI 4장)'),
      ('백금 온도 센서', '가스 온도를 잼. 같은 가스도 온도가 오르면 밀도가 내려가므로 0 ℃ 기준 밀도로 바꾸는 데 씀'),
      ('O-링', 'NBR. 챔버를 막아 가스가 새지 않게 하고 진동을 잡아 줌. 굳으면 누설·진동에 약해져 오차 → 2~3년마다 교체 권장'),
      ('몸체', '원통과 챔버를 감싸는 함체. 외부 진동에 강하게 만들어짐 (TI). 방폭형(GD40R)은 Exd [ia] IIB+H2T5'),
      ('변환기 GD402', '두 진동수를 받아 밀도·순도 계산, 표시, 4-20 mA 출력, 알람'),
    ]),
    _title('왜 진동수로 밀도를 아나'),
    const Gd40ModesFigure(),
    const SizedBox(height: 6),
    ..._steps(const [
      '압전 소자가 원통을 원래 떨리기 좋은 진동수(고유 진동수)로 계속 떨게 함 (자려 발진, 회로가 스스로 맞춰 줌)',
      '원통이 떨면 겉면에 닿은 가스도 같이 밀리고 당겨짐 → 원통에 가스 무게가 얹힌 꼴 (관성 부하)',
      '무게가 늘면 진동수가 내려감 (그네에 사람이 타면 느려지는 것과 같은 이치)',
      '그래서 진동수를 재면 둘레 가스의 밀도를 알 수 있음',
    ]),
    _title('왜 두 모드(F2·F4)를 동시에 쓰나'),
    ..._rows(const [
      ('문제', '진동수는 가스 말고도 원통 자체 때문에 바뀜: 온도에 따른 쇠의 탄성 변화, 오래 쓰며 생기는 변화, 겉면에 앉은 먼지·오일 미스트·수분'),
      ('해결', '원통을 2차 원주 모드(F2 약 2 kHz)와 4차 원주 모드(F4 약 6 kHz)로 동시에 울림. 원통 자체 때문인 변화는 두 모드에 같은 비율로 걸려서, F2 ÷ F4 비율을 쓰면 서로 지워짐. 가스 무게는 두 모드에 다르게 걸려서 비율에 남음'),
      ('효과', '먼지(MgO 0.4 mg/cm²)가 앉았을 때 오차가 한 모드만 쓸 때의 약 1/10 (TI 5.5). 드리프트가 거의 없어 손볼 일이 적음'),
      ('확인', '서비스 CODE 41에서 F2·F4·F2/F4를 볼 수 있음. F2 1000~10000 Hz, F4 4000~10000 Hz를 벗어나면 Err.02'),
    ]),
    _title('밀도에서 순도까지 계산 순서'),
    ..._steps(const [
      'F2·F4 → 실제 밀도 d (그 자리 온도·압력에서의 밀도)',
      '표준 상태로 바꿈: do = d × (273.15 + t) ÷ 273.15 × 101.33 ÷ P  (t: 가스 온도 ℃, P: 가스 압력 kPa abs)',
      '두 가스 섞임을 직선으로: 순도 = (공기 밀도 − do) ÷ (공기 밀도 − 수소 밀도) × 100',
      '교정은 이 직선의 두 끝을 맞추는 일: 제로 = 수소 100% (0.0899), 스팬 = CO2 100% (1.9771)',
    ]),
    const SizedBox(height: 8),
    refDataRow('설명서 계산식', '농도 C = (do − dz) ÷ (ds − dz) × (Cs − Cz) + Cz  (dz·ds: 제로·스팬 밀도, Cz·Cs: 제로·스팬 농도). GD402는 표가 아니라 이 식 하나로 계산 (TI 9장)'),
    _title('직접 보기: 순도에 따른 밀도'),
    const Gd40PurityFigure(),
    _title('왜 압력 전송기를 다나'),
    ..._rows(const [
      ('이유', '검출기가 재는 건 그 자리의 실제 밀도. 같은 가스도 압력이 2배면 밀도가 2배 → 압력이 흔들리면 순도가 흔들린 것처럼 보임'),
      ('하는 일', 'EJX310A 절대압 전송기가 검출기 가스 압력을 재서 변환기가 101.33 kPa 기준으로 바꿈 (서비스 CODE 10·12)'),
      ('필수', '설명서: 수소 순도계로 쓸 때는 압력 보상용 압력 전송기가 필요'),
      ('없으면', '보상을 끄면 101.33 kPa abs로 보고 계산 → 실제 압력이 다르면 그만큼 틀림'),
      ('설치', '도압관은 검출기에서 0.5 m 안쪽 (검출기 압력과 같게 재려고)'),
    ]),
    _title('왜 유량을 일정하게 하나'),
    refTable(
      headers: const ['유량 (mL/min)', '지시 (kg/Nm³)', '600 기준 차이'],
      rows: const [
        ['300', '1.2502', '-0.0002'],
        ['600 (정격)', '1.2504', '0'],
        ['1000', '1.2515', '+0.0011'],
      ],
      footer: '※ TI 5.3 시험값(수소). 많이 흘릴수록 지시가 올라감 → 600 mL/min 안팎으로 일정하게',
    ),
    _title('검사관이 자주 묻는 것'),
    ..._rows(const [
      ('공기 말고 다른 게 섞이면?', '두 가스(수소·공기) 섞임으로 계산하므로, 다른 가스(수분 등)가 섞이면 그만큼 밀도가 바뀌어 순도 오차가 됨 (원리상). 그래서 시료는 필터·제습을 거침'),
      ('수소가 왜 냉각에 쓰이나?', '고속으로 도는 발전기 냉각에 수소를 씀. 공기와 섞이면 위험해서 운전 중 순도를 늘 봄 (TI 8.1)'),
      ('왜 CO2를 거치나?', '정비 때 수소를 바로 공기로 바꾸면 위험한 혼합이 생김. 수소 → CO2 → 공기 순서로 바꾸고, 다시 운전할 때는 공기 → CO2 → 수소. 이때 H2 in CO2, Air in CO2 범위로 치환 정도를 봄 (TI 8.1)'),
      ('정확도는?', 'H2 in Air 85~100%: 직선성 ±1, 반복성 ±0.5, 드리프트 ±0.5/월 (vol%), 응답 90% 약 5초'),
      ('온도가 갑자기 바뀌면?', '10 ℃ 급변에도 1 g/m³ 안 (TI 2장)'),
      ('얼마나 자주 교정하나?', '설명서: 2~3개월마다 표준가스로 확인, 틀리면 교정. TI 예: 3개월에 한 번 정도 점검'),
    ]),
  ]);
}

// ───────── 2. 키·화면 ─────────

class _Keys extends StatelessWidget {
  const _Keys();

  @override
  Widget build(BuildContext context) => _page('keys', [
    gdPanelFigure(const GdStep(say: '', data: '98.2', msg: 'H2_AIR', opPtr: kOpMeasure), key: const Key('gdg_keys_panel')),
    _title('키 7개'),
    ..._rows(const [
      ('YES', '키 조작 표시에 YES가 켜졌을 때 "예"'),
      ('NO', '키 조작 표시에 NO가 켜졌을 때 "아니오" (다음 메뉴로)'),
      ('MODE', '측정 모드 → 운전 레벨. 다른 데서 누르면 측정 모드로 돌아감 (언제든 취소)'),
      ('>', '바꿀 자리 옮기기'),
      ('∧', '숫자 올리기 (내리는 키는 없음, 9 다음은 0)'),
      ('ENT', '값 확정'),
      ('*', '설정·서비스 레벨로. 덮개 연 안쪽 오른편 스위치 (방폭형은 키패드 오른쪽 끝)'),
    ]),
    _title('표시창'),
    ..._rows(const [
      ('상태 표시', 'HOLD (출력 유지 중), FAIL (고장), TEMP.MAN'),
      ('숫자 표시', '측정값·설정값 6자리'),
      ('메시지 표시', '단위·메뉴 이름. 앞에 * 가 붙으면 설정·서비스 레벨'),
      ('키 조작 표시', 'YES NO ▶ ▲ ENT 중 깜박이는 것이 지금 누를 수 있는 키'),
      ('▶ 포인터', '오른쪽 목록에서 지금 있는 모드'),
      ('접점 램프', 'MAINT, ALARM, CAL/SEL, FAIL'),
    ]),
    _title('레벨 4개'),
    refTable(
      headers: const ['레벨', '하는 일', '들어가는 법'],
      flex: const [3, 5, 5],
      rows: const [
        ['측정', '측정값 보기', '전원 켜면 바로'],
        ['운전', '표시 항목, 측정 범위, 교정', '측정 모드에서 [MODE]'],
        ['설정', '출력, 교정 데이터, 알람', '측정 모드에서 [*]'],
        ['서비스', '기능 선택 (코드 번호)', '*SERVC에서 [YES] → 코드'],
      ],
    ),
    _title('숫자 넣기 따라하기'),
    const Gd402Walkthrough(id: 'digits', steps: [
      GdStep(say: '값을 바꾸는 화면 (예: 수소 순도 하한 알람 85.0). 키 조작 표시에 ▶ ▲ ENT가 켜져 있으면 숫자를 바꿀 수 있음', press: GdKey.right, data: '085.0', msg: '*L_H_A', keyOp: {GdKey.right, GdKey.up, GdKey.ent}, setPtr: 2),
      GdStep(say: '[>]를 누를 때마다 바꿀 자리가 옮겨가며 깜박임. 둘째 자리로', press: GdKey.up, data: '085.0', msg: '*L_H_A', keyOp: {GdKey.right, GdKey.up, GdKey.ent}, setPtr: 2, cursor: 1),
      GdStep(say: '[∧]로 8 → 9', press: GdKey.right, data: '095.0', msg: '*L_H_A', keyOp: {GdKey.right, GdKey.up, GdKey.ent}, setPtr: 2, cursor: 1),
      GdStep(say: '[>]로 셋째 자리 → [∧]를 다섯 번 (5→6→7→8→9→0)', press: GdKey.up, data: '090.0', msg: '*L_H_A', keyOp: {GdKey.right, GdKey.up, GdKey.ent}, setPtr: 2, cursor: 2),
      GdStep(say: '[ENT]로 확정. 범위를 넘는 값이면 *OVER가 뜸 → [YES]나 [NO]를 누르고 다시 넣음', press: GdKey.ent, data: '090.0', msg: '*L_H_A', keyOp: {GdKey.right, GdKey.up, GdKey.ent}, setPtr: 2),
      GdStep(say: '저장됨. 입력값은 전원을 꺼도 남음. [MODE]로 측정 모드', press: GdKey.mode, msg: '*ALARM', setPtr: 2, keyOp: {GdKey.yes, GdKey.no}),
    ]),
    const SizedBox(height: 10),
    refTipBox('0/1/2처럼 고르는 항목은 [∧]와 [ENT]만 씀'),
    _title('비밀번호 (서비스 CODE 44)'),
    ..._rows(const [
      ('형식', 'X.X.X: 첫째 = 운전 레벨, 둘째 = 설정 레벨, 셋째 = 서비스 레벨. 처음에는 없음'),
      ('묻는 때', '운전: [MODE] 누를 때, 설정: [*] 누를 때, 서비스: *SERVC에서 [YES] 누를 때'),
    ]),
    const SizedBox(height: 8),
    refTable(
      headers: const ['설정값', '비밀번호'],
      rows: const [
        ['0', '없음'],
        ['1', '111'],
        ['2', '333'],
        ['3', '777'],
        ['4', '888'],
        ['5', '123'],
        ['6', '957'],
        ['7', '331'],
        ['8', '546'],
        ['9', '847'],
      ],
      footer: '※ 틀리면 못 들어감. CODE 82(검출기 상수)는 따로 020 *PASSW',
    ),
  ]);
}

// ───────── 3. 처음 설정 ─────────

class _FirstSetup extends StatelessWidget {
  const _FirstSetup();

  @override
  Widget build(BuildContext context) => _page('setup', [
    refIntroBadge('처음 설치했거나 변환기를 바꿨을 때 서비스 레벨에서 이 순서로 맞춥니다. 출력·알람·교정 설정은 다음 탭.'),
    _title('순서'),
    ..._steps(const [
      'CODE 50: 계기 종류 = 2 (수소 순도·치환계)',
      'CODE 10: 압력 보상, CODE 12: 압력 전송기 범위',
      'CODE 20·21·23: 압력·밀도·온도 단위',
      'CODE 01·02·03: 유지보수·고장·수소 순도 범위 출력 유지',
      'CODE 04: 출력 평활, CODE 05: 접점 NO/NC',
      'CODE 44: 비밀번호 (맨 마지막에)',
    ]),
    _title('따라하기: 계기 종류를 수소 순도로 (CODE 50)'),
    Gd402Walkthrough(id: 'code50', steps: [
      ..._toSetting(3, '서비스'),
      const GdStep(say: '코드 번호 화면 "00 *CODE". [>]로 자리를 고르고 [∧]로 50을 만듦', press: GdKey.up, data: '00', msg: '*CODE', setPtr: 3, cursor: 0, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: '50이 되면 [ENT]', press: GdKey.ent, data: '50', msg: '*CODE', setPtr: 3, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: '0 = 밀도계, 1 = 열량계, 2 = 수소 순도·치환계. [∧]로 2를 만들고 [ENT]', press: GdKey.ent, data: '2', msg: '*MODEL', setPtr: 3, keyOp: {GdKey.up, GdKey.ent}),
      const GdStep(say: '*SERVC로 돌아옴. 다른 코드도 같은 방법([YES] → 코드 → [ENT] → 값 → [ENT]). 끝나면 [MODE]', press: GdKey.mode, msg: '*SERVC', setPtr: 3, keyOp: {GdKey.yes, GdKey.no}),
      _meas('측정 모드. 수소 순도(H2_AIR)가 표시됨'),
    ]),
    _title('따라하기: 압력 보상 (CODE 10·12)'),
    const Gd402Walkthrough(id: 'code10', steps: [
      GdStep(say: '*SERVC에서 [YES] → 10 *CODE → [ENT]', press: GdKey.ent, data: '10', msg: '*CODE', setPtr: 3, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      GdStep(say: '0 = 보상 안 함, 1 = 압력 전송기 값으로 보상, 2 = 고정값(*P.FIX). 압력 전송기가 있으면 1 → [ENT]', press: GdKey.ent, data: '1', msg: '*P.COMP', setPtr: 3, keyOp: {GdKey.up, GdKey.ent}),
      GdStep(say: '다시 [YES] → 12 *CODE → [ENT]: 압력 전송기 범위를 넣음', press: GdKey.ent, data: '12', msg: '*CODE', setPtr: 3, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      GdStep(say: '0점 (예: 0.00 kPa). 압력 전송기 4 mA 값과 같게 → [ENT]', press: GdKey.ent, data: '000.00', msg: '*Z_PRS', setPtr: 3, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      GdStep(say: '스팬 (예: 500.00 kPa). 압력 전송기 20 mA 값과 같게 → [ENT]. 끝나면 [MODE]', press: GdKey.ent, data: '500.00', msg: '*S_PRS', setPtr: 3, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
    ]),
    const SizedBox(height: 10),
    refWarnBox('압력 보상을 안 하면 101.33 kPa abs 기준 밀도로 계산함. 압력 전송기로 보상하려면 전송기를 연결하고 CODE 12 범위를 반드시 넣을 것. 예시 숫자는 그림용, 실제는 압력 전송기 레인지대로'),
    _title('서비스 코드 (수소 순도 모드)'),
    refTable(
      headers: const ['코드', '화면', '내용·범위'],
      flex: const [2, 3, 7],
      rows: const [
        ['01', '*M_HLD', '유지보수 중 출력 유지: 0 안 함 / 1 직전값 / 2 지정값(*PR.SET -10.0~110.0%)'],
        ['02', '*E_HLD', '고장(에러) 때 출력 유지: 0/1/2, *PR.SET'],
        ['03', '*H_HLD', '수소 순도 범위 출력 유지: 0/1/2, *PR.SET'],
        ['04', '*SMOTH', '출력 평활 00~60초 (댐핑은 이것 하나)'],
        ['05', '*CNTCT', '접점 NO/NC 조합 00~15 (아래 표)'],
        ['10', '*P.COMP', '압력 보상: 0 안 함 / 1 측정값 / 2 고정값(*P.FIX)'],
        ['11', '*C.D.TMP·*C.D.PRS', '보상 밀도 기준 온도(-20.0~80.0 ℃)·압력'],
        ['12', '*Z_PRS·*S_PRS', '압력 전송기 0점·스팬'],
        ['14', '*REMOT', '접점 입력으로 치환계 범위 선택: 0 안 함 / 1 씀'],
        ['20', '*PRES.U', '압력 단위: 0 kPa / 1 MPa / 2 psi'],
        ['21', '*DENS.U', '밀도 단위: 0 kg/m3 / 1 lb/ft3'],
        ['23', '*TEMP.U', '온도 단위: 0 ℃ / 1 ℉'],
        ['31', '*MINUS', '마이너스 표시: 0 보임 / 1 숨김'],
        ['40', '*C_K_Z·*C_K_S', '교정 계수 (읽기만)'],
        ['41', '*F2.KHZ 등', '발진 주파수 (읽기만)'],
        ['42', '*REV', '소프트웨어 판 (읽기만)'],
        ['43', '*S_CYC', '0 보통 / 1 고분해능'],
        ['44', '*PASS', '비밀번호 0.0.0~9.9.9'],
        ['45', '*BAT', '0 배터리 검출 안 함 / 1 검출'],
        ['50', '*MODEL', '0 밀도계 / 1 열량계 / 2 수소 순도·치환계'],
        ['82', '*K_A_H 등', '검출기 상수 (020 *PASSW). 출하 짝 그대로면 손대지 말 것'],
      ],
      footer: '※ 표에 없는 코드는 넣지 말 것. 잘못 넣었으면 [MODE]로 빠져나옴. CODE 10의 1은 설명서 표에 "측정값", 본문에 "직전값"으로 서로 다르게 적힘',
    ),
    _title('출력 유지 우선순위 (CODE 03)'),
    refTable(
      headers: const ['순위', '상태', '수소 순도 범위를 출력에 고른 경우', '안 고른 경우'],
      flex: const [2, 4, 5, 5],
      rows: const [
        ['1', '고장', 'CODE 03', 'CODE 02'],
        ['2', '교정', 'CODE 03', '*CAL.DT의 *C_HLD'],
        ['3', '유지보수', 'CODE 03', 'CODE 01'],
        ['4', '치환계로 바꿈', 'CODE 03', '정상 출력'],
      ],
    ),
    _title('접점 NO/NC (CODE 05)'),
    refTable(
      headers: const ['값', 'SEL GAS', 'FUNC', 'MAINT', 'ALM'],
      rows: const [
        ['0', 'NO', 'NO', 'NO', 'NO'],
        ['1', 'NO', 'NO', 'NO', 'NC'],
        ['2', 'NO', 'NO', 'NC', 'NO'],
        ['3', 'NO', 'NO', 'NC', 'NC'],
        ['4', 'NO', 'NC', 'NO', 'NO'],
        ['5', 'NO', 'NC', 'NO', 'NC'],
        ['6', 'NO', 'NC', 'NC', 'NO'],
        ['7', 'NO', 'NC', 'NC', 'NC'],
        ['8', 'NC', 'NO', 'NO', 'NO'],
        ['9', 'NC', 'NO', 'NO', 'NC'],
        ['10', 'NC', 'NO', 'NC', 'NO'],
        ['11', 'NC', 'NO', 'NC', 'NC'],
        ['12', 'NC', 'NC', 'NO', 'NO'],
        ['13', 'NC', 'NC', 'NO', 'NC'],
        ['14', 'NC', 'NC', 'NC', 'NO'],
        ['15', 'NC', 'NC', 'NC', 'NC'],
      ],
      footer: '※ NO = 평상시 열림, NC = 평상시 닫힘. FAIL은 이 설정과 상관없이 고장 때 열림',
    ),
  ]);
}

// ───────── 4. 출력 4-20 mA ─────────

class _Output extends StatelessWidget {
  const _Output();

  @override
  Widget build(BuildContext context) => _page('output', [
    refIntroBadge('설정 레벨 *RANGE에서 출력 1·2에 무엇을 내보낼지와 4 mA·20 mA 값을 정합니다.'),
    _title('따라하기: 출력 1 = 수소 순도 85.0~100.0%'),
    Gd402Walkthrough(id: 'range', steps: [
      ..._toSetting(0, '출력'),
      const GdStep(say: '*OUT1 (단자 3·4, BRAIN 통신 가능). 출력 2는 [NO]로 *OUT2', press: GdKey.yes, msg: '*OUT1', setPtr: 0, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '내보낼 항목 고르기. *DENS(밀도)는 [NO]로 넘김', press: GdKey.no, msg: '*DENS', setPtr: 0, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '*C_DNS(보상 밀도)도 [NO]', press: GdKey.no, msg: '*C_DNS', setPtr: 0, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '*H_A = 수소 순도. [YES] (치환계 모드에서는 안 보이고 대신 *H_C_A)', press: GdKey.yes, msg: '*H_A', setPtr: 0, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '4 mA(0%) 값. 예: 85.0 → [ENT]', press: GdKey.ent, data: '085.0', msg: '*Z_H_A', setPtr: 0, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: '20 mA(100%) 값. 예: 100.0 → [ENT]', press: GdKey.ent, data: '100.0', msg: '*S_H_A', setPtr: 0, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: '*RANGE로 돌아옴. [MODE]로 측정 모드', press: GdKey.mode, msg: '*RANGE', setPtr: 0, keyOp: {GdKey.yes, GdKey.no}),
    ]),
    const SizedBox(height: 10),
    refWarnBox('출력 1·2에 같은 항목을 고르면 나중에 넣은 0%·100% 값이 양쪽에 다 적용됨. 출력을 바꾸면 알람값·접점·출력 유지 값도 같이 확인 (설명서 4.1.3)'),
    const SizedBox(height: 10),
    _title('출력 항목'),
    ..._rows(const [
      ('*DENS', '물리 밀도 (0~60.0000 kg/m3)'),
      ('*C_DNS', '보상 밀도 (0~6.0000 kg/m3)'),
      ('*H_A', '수소 순도 (0.0~100.0%)'),
      ('*H_C_A', '치환 농도 (0.0~100.0%)'),
      ('*TEMP / *PRESS', '가스 온도·압력 (0%·100% 설정 없음)'),
    ]),
    const SizedBox(height: 10),
    refTipBox('mA ↔ % 계산은 계기 교정 → 4-20mA 탭에서 (0% 값 85, 100% 값 100으로 넣으면 됨). 4 mA = 85.0%, 12 mA = 92.5%, 20 mA = 100.0%'),
    const SizedBox(height: 8),
    refDataRow('설명서 차이', '*Z_H_A·*S_H_A 범위가 설명서 7-3쪽 표에는 "0.00000~0.40000", 7-11쪽 본문에는 "0.0~100.0"으로 다르게 적힘. 화면 형식이 XXX.X라 본문 값으로 봄'),
  ]);
}

// ───────── 5. 알람 ─────────

class _Alarm extends StatelessWidget {
  const _Alarm();

  @override
  Widget build(BuildContext context) => _page('alarm', [
    refIntroBadge('수소 순도 알람은 하한(*L_H_A) 하나입니다. 순도가 이 값 이하로 떨어지면 ALARM 접점(16·17)이 동작하고 ALARM 램프가 켜집니다.'),
    _title('따라하기: 수소 순도 하한 90.0%'),
    Gd402Walkthrough(id: 'alarm', steps: [
      ..._toSetting(2, '알람'),
      const GdStep(say: '항목 고르기. *DENS는 [NO]', press: GdKey.no, msg: '*DENS', setPtr: 2, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '*C_DNS도 [NO]', press: GdKey.no, msg: '*C_DNS', setPtr: 2, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '*H_A(수소 순도)에서 [YES] (치환계를 고른 상태면 이 단계는 건너뜀)', press: GdKey.yes, msg: '*H_A', setPtr: 2, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '하한값. 예: 90.0 ([>] 자리, [∧] 숫자) → [ENT]', press: GdKey.ent, data: '090.0', msg: '*L_H_A', setPtr: 2, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: '*ALARM으로 돌아옴. [MODE]로 측정 모드', press: GdKey.mode, msg: '*ALARM', setPtr: 2, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '알람이 걸린 모습: 메시지에 알람 번호, ALARM 램프 켜짐, ALM 접점 동작', data: '88.7', msg: 'ALM.06', opPtr: kOpMeasure, lamps: {'ALARM'}),
    ]),
    const SizedBox(height: 10),
    ..._rows(const [
      ('범위', '0.0~100.0%'),
      ('상한', '수소 순도는 상한 알람 없음 (밀도·보상 밀도는 상하한)'),
      ('히스테리시스·지연', '설명서에 없음'),
      ('알람 번호', '농도 상하한은 ALM.06 (수소 순도 하한이 이 번호로 뜨는 것으로 보임, 설명서에 따로 적혀 있지 않음)'),
      ('접점', 'ALARM 공통 1개 (16·17). NO/NC는 CODE 05'),
      ('ALM.09', '배터리 이상은 접점이 안 나감'),
    ]),
    const SizedBox(height: 10),
    refTipBox('알람값을 바꾸면 알람 동작과 출력 설정도 같이 확인 (설명서 4.1.3)'),
  ]);
}

// ───────── 6. 표시 ─────────

class _Display extends StatelessWidget {
  const _Display();

  @override
  Widget build(BuildContext context) => _page('display', [
    _title('따라하기: 측정 모드에 보일 항목 (DISP)'),
    Gd402Walkthrough(id: 'disp', steps: [
      _meas('측정 모드에서 [MODE] (비밀번호를 걸었으면 XXX *PASSW → [ENT])', press: GdKey.mode),
      const GdStep(say: '운전 레벨 첫 화면 S_GAS. [NO]로 다음', press: GdKey.no, msg: 'S_GAS', opPtr: kOpSelGas, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: 'DISP에서 [YES]', press: GdKey.yes, msg: 'DISP', opPtr: kOpDisplay, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '1) 물리 밀도. [NO]를 누르면 다음 항목', press: GdKey.no, data: '0.1342', msg: 'KG/M3', opPtr: kOpDisplay, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '2) 보상 밀도. [NO]', press: GdKey.no, data: '0.1189', msg: 'KG/M3', opPtr: kOpDisplay, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '3) 농도(수소 순도). 측정 모드에 이걸 보이려면 [YES]', press: GdKey.yes, data: '98.2', msg: 'H2_AIR', opPtr: kOpDisplay, keyOp: {GdKey.yes, GdKey.no}),
      _meas('측정 모드에 수소 순도가 표시됨. 4) 온도 5) 압력 6) 출력1 7) 출력2(MA%)는 DISP에서 [NO]로 넘기며 보기만 가능'),
    ]),
    const SizedBox(height: 10),
    refTable(
      headers: const ['DISP 항목', '표시 형식', '측정 모드 표시'],
      flex: const [4, 5, 3],
      rows: const [
        ['물리 밀도', 'XX.XXXX KG/M3', '가능'],
        ['보상 밀도', 'X.XXXX KG/M3', '가능'],
        ['농도', 'XXX.X (H2_AIR 등)', '가능'],
        ['온도', 'XXX.X ℃', '보기만'],
        ['압력', 'XXX.XX KPA 등', '보기만'],
        ['출력 1 전류', 'XXX.X MA1%', '보기만'],
        ['출력 2 전류', 'XXX.X MA2%', '보기만'],
      ],
    ),
    _title('따라하기: 측정 범위 고르기 (S_GAS)'),
    Gd402Walkthrough(id: 'sgas', steps: [
      _meas('측정 모드에서 [MODE]', press: GdKey.mode),
      const GdStep(say: 'S_GAS에서 [YES]', press: GdKey.yes, msg: 'S_GAS', opPtr: kOpSelGas, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: 'H2_AIR = 수소 순도 (평상 운전). [NO]를 누르면 다음 범위', press: GdKey.no, data: '98.2', msg: 'H2_AIR', opPtr: kOpSelGas, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: 'H2_CO2 = 치환계, CO2 속 수소 농도 (CO2 → H2로 바꿀 때)', press: GdKey.no, data: '12.4', msg: 'H2_CO2', opPtr: kOpSelGas, keyOp: {GdKey.yes, GdKey.no}, lamps: {'CAL/SEL'}),
      const GdStep(say: 'A_CO2 = 치환계, CO2 속 공기 농도 (공기 ↔ CO2로 바꿀 때). [NO]를 또 누르면 H2_AIR로', press: GdKey.no, data: '87.6', msg: 'A_CO2', opPtr: kOpSelGas, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '쓰려는 범위에서 [YES] → 그 범위로 측정 모드에 표시', press: GdKey.yes, data: '98.2', msg: 'H2_AIR', opPtr: kOpSelGas, keyOp: {GdKey.yes, GdKey.no}),
      _meas('측정 모드 (H2_AIR)'),
    ]),
    const SizedBox(height: 10),
    refTipBox('치환계 범위는 접점 입력으로도 바꿀 수 있음: CODE 14 = 1이면 단자 1·2 열림 = Air in CO2, 닫힘 = H2 in CO2'),
    _title('따라하기: 음수 값 숨기기 (CODE 31)'),
    Gd402Walkthrough(id: 'code31', steps: [
      const GdStep(say: '제로 근처에서 지시가 음수로 내려간 모습 (예: 치환계 A_CO2 -0.4)', data: '-0.4', msg: 'A_CO2', opPtr: kOpMeasure),
      ..._toSetting(3, '서비스'),
      const GdStep(say: '31을 만들고 [ENT]', press: GdKey.ent, data: '31', msg: '*CODE', setPtr: 3, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: '0 = 음수 보임, 1 = 음수 숨김. [∧]로 1 → [ENT]. *SERVC로 돌아옴 → [MODE]', press: GdKey.ent, data: '1', msg: '*MINUS', setPtr: 3, keyOp: {GdKey.up, GdKey.ent}),
    ]),
    const SizedBox(height: 10),
    ..._rows(const [
      ('설명서 내용', '"음수 측정값(-)을 보일지 숨길지 정함. 보임 0 / 숨김 1" 이 한 줄뿐'),
      ('실물 확인', '숨겼을 때 화면에 0이 뜨는지 빈칸인지, 4-20 mA 출력(4 mA 아래)도 같이 막히는지는 설명서에 없음. 바꾼 뒤 DISP의 MA1%·MA2%와 DCS 값을 보고 확인'),
      ('100% 넘을 때', '100%로 막는 설정은 설명서에 없음. 순도가 100.3%처럼 나오면 그대로 보임 → 제로·스팬 교정으로 바로잡을 일'),
    ]),
    const SizedBox(height: 8),
    refWarnBox('음수를 숨기면 화면은 깔끔해도 실제 값은 음수 그대로. 제로가 틀어졌다는 신호가 안 보이게 되니, 숨기기 전에 제로 교정부터 확인할 것'),
    _title('단위·표시 설정 (서비스 레벨)'),
    ..._rows(const [
      ('CODE 20', '압력 단위: kPa (XXX.XX) / MPa (X.XXXX) / psi (XX.XXX)'),
      ('CODE 21', '밀도 단위: kg/m3 / lb/ft3'),
      ('CODE 23', '온도 단위: ℃ / ℉'),
      ('CODE 31', '마이너스 값: 0 보임 / 1 숨김'),
      ('CODE 43', '0 보통 / 1 고분해능'),
      ('백라이트', '설명서에 없음'),
    ]),
  ]);
}

// ───────── 7. 교정 ─────────

class _Calibration extends StatelessWidget {
  const _Calibration();

  @override
  Widget build(BuildContext context) => _page('cal', [
    refIntroBadge('수소 순도계는 수동 교정만 됩니다. 제로 = 수소 100% (기준 밀도 0.0899), 스팬 = 이산화탄소 100% (기준 밀도 1.9771). 지시가 안정된 것을 눈으로 보고 [ENT]로 확정합니다.'),
    _title('교정 전에'),
    ..._steps(const [
      '제어실(MCR)에 알림. 출력이 DCS 경보·인터록에 물려 있으면 바이패스 승인',
      '교정 가스 확인: H2 100% (수소 용기 주황), CO2 100% (탄산가스 용기 청색), 압력·잔량 (계기 교정 → 교정 가스 탭)',
      '용기 압력을 감압 밸브로 낮추고 유량 0.1~1 L/min (점검 기준 600 mL/min ±10%)',
      '출구는 대기압 (교정 조건)',
      '교정 중 출력 유지(*C_HLD) 확인 (아래 따라하기)',
    ]),
    _title('따라하기 1: 교정 중 출력 유지 (*C_HLD)'),
    Gd402Walkthrough(id: 'chld', steps: [
      ..._toSetting(1, '교정 데이터'),
      const GdStep(say: '0 = 유지 안 함, 1 = 교정 직전 값 유지, 2 = 지정값 유지. DCS 경보를 막으려면 1이나 2 → [ENT]', press: GdKey.ent, data: '1', msg: '*C_HLD', setPtr: 1, keyOp: {GdKey.up, GdKey.ent}),
      const GdStep(say: '2를 골랐을 때만: 유지할 출력 %(-10.0~110.0) → [ENT]', press: GdKey.ent, data: '050.0', msg: '*PR.SET', setPtr: 1, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: '*RANGE로 돌아옴. [MODE]로 측정 모드', press: GdKey.mode, msg: '*RANGE', setPtr: 0, keyOp: {GdKey.yes, GdKey.no}),
    ]),
    const SizedBox(height: 10),
    refTipBox('출력에 수소 순도(*H_A)를 골랐으면 교정 중 출력은 *C_HLD가 아니라 서비스 CODE 03을 따름'),
    _title('따라하기 2: 제로·스팬 교정'),
    Gd402Walkthrough(id: 'mancal', steps: [
      _meas('측정 모드. 시료가스가 흐르는 중. [MODE]', press: GdKey.mode, gas: GdGas.measuring),
      const GdStep(say: 'S_GAS. [NO]', press: GdKey.no, msg: 'S_GAS', opPtr: kOpSelGas, keyOp: {GdKey.yes, GdKey.no}, gas: GdGas.measuring),
      const GdStep(say: 'DISP. [NO]', press: GdKey.no, msg: 'DISP', opPtr: kOpDisplay, keyOp: {GdKey.yes, GdKey.no}, gas: GdGas.measuring),
      const GdStep(say: 'MAN.CAL에서 [YES]', press: GdKey.yes, msg: 'MAN.CAL', opPtr: kOpManCal, keyOp: {GdKey.yes, GdKey.no}, gas: GdGas.measuring),
      const GdStep(say: 'ZERO 표시. 시료가스 밸브를 닫고 [YES] (제로를 건너뛰려면 [NO] → SPAN)', press: GdKey.yes, msg: 'ZERO', opPtr: kOpManCal, keyOp: {GdKey.yes, GdKey.no}, gas: GdGas.allClosed),
      const GdStep(say: '제로 기준 밀도(H2) 0.0899 표시. 고정값이라 못 바꿈. [ENT]', press: GdKey.ent, data: '0.0899', msg: 'H2', opPtr: kOpManCal, keyOp: {GdKey.ent}, gas: GdGas.allClosed),
      GdStep(say: '제로가스(H2) 밸브를 엶. 지시(보정 밀도)가 내려가 안정되면 [ENT] → 제로가스 밸브를 닫음', press: GdKey.ent, data: '0.0903', msg: 'CAL.SET', opPtr: kOpManCal, keyOp: const {GdKey.ent}, gas: GdGas.zeroFlow, warn: '이 화면은 [>][∧]를 안 받음. 값이 계속 움직이면 안정될 때까지 기다림'),
      const GdStep(say: 'SPAN 표시. [YES]', press: GdKey.yes, msg: 'SPAN', opPtr: kOpManCal, keyOp: {GdKey.yes, GdKey.no}, gas: GdGas.allClosed),
      const GdStep(say: '스팬 기준 밀도(CO2) 1.9771 표시. 고정값. [ENT]', press: GdKey.ent, data: '1.9771', msg: 'CO2', opPtr: kOpManCal, keyOp: {GdKey.ent}, gas: GdGas.allClosed),
      const GdStep(say: '스팬가스(CO2) 밸브를 엶. 지시가 올라가 안정되면 [ENT] → 스팬가스 밸브를 닫고 시료가스 밸브를 엶', press: GdKey.ent, data: '1.9758', msg: 'CAL.SET', opPtr: kOpManCal, keyOp: {GdKey.ent}, gas: GdGas.spanFlow),
      _meas('측정 모드로 돌아옴. 시료가스로 수소 순도가 다시 안정되는지 확인', gas: GdGas.measuring),
    ]),
    _title('교정이 안 맞을 때 (ALM.10)'),
    const Gd402Walkthrough(id: 'alm10', steps: [
      GdStep(say: '마지막 [ENT] 뒤 ALM.10이 뜨면 교정 데이터 이상. [YES]나 [NO]', press: GdKey.yes, msg: 'ALM.10', opPtr: kOpManCal, keyOp: {GdKey.yes, GdKey.no}, lamps: {'ALARM'}),
      GdStep(say: 'MAN.CAL로 돌아옴. 가스 종류·농도, 유량, 출구 대기압, 누설을 확인하고 다시 교정', press: GdKey.yes, msg: 'MAN.CAL', opPtr: kOpManCal, keyOp: {GdKey.yes, GdKey.no}),
    ]),
    const SizedBox(height: 10),
    ..._rows(const [
      ('ALM.10 조건', '제로 교정값 -0.3000~0.3000, 스팬 교정값 0.50000~1.5000 (설명서 표 그대로, 벗어나면 알람으로 보임)'),
      ('교정 결과', '서비스 CODE 40에서 *C_K_Z(제로)·*C_K_S(스팬) 계수 확인 (읽기만)'),
      ('건너뛰기', 'ZERO·SPAN 둘 다 [NO]면 MAN.CAL로 돌아감'),
    ]),
    _title('교정 뒤에'),
    ..._steps(const [
      '교정 가스 용기 밸브 잠금, 시료가스 유량 확인',
      'DCS 값이 정상인지 확인하고 제어실에 알림, 바이패스 해제',
      '교정 날짜·가스·결과 기록 (계기 교정 → 교정 점검 탭)',
      '다음 확인: 2~3개월마다 표준가스로 지시 확인 (운전 조건에 따라)',
    ]),
  ]);
}

// ───────── 8. 운전·정지 ─────────

class _Operation extends StatelessWidget {
  const _Operation();

  @override
  Widget build(BuildContext context) => _page('op', [
    _title('전원 넣기 전'),
    ..._steps(const [
      '설치 상태 확인',
      '시료가스 라인 누설 점검',
      '배선 확인 뒤 단자함 덮개를 확실히 닫음',
      '방폭형(GD402T/V/R)은 내장 전원 스위치를 ON',
      '출력 때문에 연결된 제어 기기가 움직이지 않게 해 둠',
    ]),
    const SizedBox(height: 8),
    refWarnBox('점검 중에는 전원을 넣지 말 것. 방폭 지역에서는 전원이 켜진 채 단자함을 열지 말 것. 고온 환경이면 금속부가 뜨거움'),
    _title('운전 시작'),
    ..._steps(const [
      '외부 전원 스위치 ON → 측정 모드로 시작 (예열 시간은 설명서에 없음)',
      '서비스 CODE 50 = 2(수소 순도) 확인, 필요한 파라미터 설정 ("처음 설정" 탭)',
      '제로·스팬 교정 ("교정" 탭)',
      '측정 모드로 돌아와 측정 루프 기기를 다 켜고 한동안 이상 없는지 본 뒤 정상 운전',
    ]),
    _title('접점 상태'),
    ..._rows(const [
      ('전원 OFF', 'FAIL 열림, SEL·FUNC·MAINT·ALM 닫힘'),
      ('전원 ON', 'FAIL은 정상 닫힘 / 고장 열림. 나머지는 CODE 05대로'),
    ]),
    const SizedBox(height: 8),
    refTable(
      headers: const ['범위', 'FUNC', 'SEL GAS', 'LED'],
      rows: const [
        ['H2 in AIR (수소 순도)', '보통', '보통', '꺼짐'],
        ['H2 in CO2 (치환)', '동작', '동작', '켜짐'],
        ['AIR in CO2 (치환)', '동작', '보통', '꺼짐'],
      ],
      footer: '※ 수소 순도·치환계 모드(설명서 3-7쪽). FUNC = 수소 순도계·치환계 구분, SEL GAS = 치환 범위 구분',
    ),
    _title('고장 났을 때'),
    ..._rows(const [
      ('FAIL', 'FAIL 접점(18·19) 열림, FAIL 램프, 에러 번호 표시'),
      ('출력', '직전값 또는 설정값으로 유지 (CODE 02, 수소 순도 출력이면 CODE 03)'),
      ('Err.01·02', '전원을 껐다 켜 보고, 그래도면 요꼬가와 서비스'),
      ('Err.03~05', '요꼬가와 서비스'),
    ]),
    _title('정지·재시작'),
    ..._steps(const [
      '설정값은 전원을 꺼도 남음. 오래 세울 때는 전원 OFF',
      '센서를 계기용 공기(instrument air)로 충분히 퍼지. 세정이 필요하면 요꼬가와와 상담',
      '오래 세웠다 다시 쓸 때는 모든 기기를 눈으로 보고 배선·배관 체결을 다시 확인',
    ]),
  ]);
}

// ───────── 9. 알람·고장 코드 ─────────

class _Codes extends StatelessWidget {
  const _Codes();

  @override
  Widget build(BuildContext context) => _page('codes', [
    refIntroBadge('알람(ALM)은 ALARM 접점(16·17)과 ALARM 램프, 고장(Err)은 FAIL 접점(18·19)이 열리고 FAIL 램프가 켜집니다.'),
    _title('알람'),
    refTable(
      headers: const ['표시', '내용', '조치'],
      flex: const [3, 6, 5],
      rows: const [
        ['ALM.01', '물리 밀도 상하한', '상하한값 확인·변경'],
        ['ALM.02', '보상 밀도 상하한', '상하한값 확인·변경'],
        ['ALM.03', '비중 상하한', '상하한값 확인·변경'],
        ['ALM.04', '열량 상하한', '상하한값 확인·변경'],
        ['ALM.05', '분자량 상하한', '상하한값 확인·변경'],
        ['ALM.06', '농도 상하한 (수소 순도 하한으로 보임)', '알람값·실제 순도 확인'],
        ['ALM.07', '압력 입력 범위 이상: 0점 -3% 이하, 스팬 +5% 이상, 0.1 kPa 이하', '시료가스 압력·압력 범위(CODE 12) 확인'],
        ['ALM.08', '시료가스 온도 이상 (-25~80 ℃ 밖)', '허용 범위 안에서 사용'],
        ['ALM.09', '배터리 이상 (접점 안 나감)', '요꼬가와 서비스'],
        ['ALM.10', '교정 이상 (제로·스팬)', '다시 교정 ("교정" 탭)'],
      ],
    ),
    _title('고장 (FAIL)'),
    refTable(
      headers: const ['표시', '내용', '조치'],
      flex: const [3, 6, 5],
      rows: const [
        ['Err.01', '센서 발진 정지', '전원 껐다 켬 → 서비스'],
        ['Err.02', '발진 주파수 이상 (F2 1000~10000 Hz, F4 4000~10000 Hz 밖)', '전원 껐다 켬 → 서비스'],
        ['Err.03', '센서 온도 검출 이상', '서비스'],
        ['Err.04', 'A/D 변환기 이상', '서비스'],
        ['Err.05', '메모리 이상', '서비스'],
      ],
      footer: '※ 발진 주파수는 서비스 CODE 41에서 볼 수 있음',
    ),
  ]);
}

// ───────── 10. 점검 ─────────

class _Maintenance extends StatelessWidget {
  const _Maintenance();

  @override
  Widget build(BuildContext context) => _page('maint', [
    ..._rows(const [
      ('지시 확인', '2~3개월마다 표준가스로 확인 (운전 조건에 따라). 틀리면 제로·스팬 교정'),
      ('유량', '600 mL/min ±10% 유지 확인. 이때 배관 이상·교정 가스 누설도 확인'),
      ('O-링', '검출기 NBR O-링: 2~3년마다 교체 권장 (요꼬가와와 상담). 열화되면 누설·진동 약해짐·지시 오차'),
      ('청소', '깨끗하고 부드러운 천. 투명창은 심하게 더러우면 중성세제, 유기용제 금지'),
    ]),
    _title('퓨즈 교체'),
    ..._steps(const [
      '외부 차단기로 전원 차단',
      '일자 드라이버로 퓨즈 홀더 캡을 반시계 90° 돌려 캡째 뽑음',
      '정격 확인한 새 퓨즈를 캡에 넣고, 누르면서 시계 90°',
      '새 퓨즈가 곧 끊어지면 회로 이상, 요꼬가와에 연락',
    ]),
    const SizedBox(height: 8),
    refDataRow('퓨즈', 'AC형 1 A (A1109EF), DC형 2 A (A1111EF), 둘 다 250 V time lag'),
    const SizedBox(height: 12),
    refTipBox('원리상 드리프트가 거의 없어 기본적으로 손볼 곳은 적지만 주기 점검은 권장 (설명서 3.2.3)'),
  ]);
}
