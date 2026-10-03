// GD402 가이드 추가 탭(10-02): 설치·배선·배관(2장), 밀도계 설정·교정(5·8장), 열량계 설정·교정(6·9장).
// 수소 순도 탭과 같은 방식(설명 + 화면 따라하기). 근거는 IM 11T03E01-01E, 화면 글자·코드·범위는 설명서 그대로.
part of 'gd402_guide_page.dart';

// ── 밀도·열량 모드 화면 ──
const int _opSemi = 10, _opValve = 12;

GdStep _measD(String say, {GdKey? press, GdGas? gas, String data = '1.2504', String msg = 'KG/M3'}) => GdStep(say: say, press: press, data: data, msg: msg, opPtr: kOpMeasure, gas: gas);

/// 밀도·열량 모드: 측정 모드 → * → 설정 레벨 메뉴(target)까지.
List<GdStep> _toSettingD(int target, String what, {String data = '1.2504', String msg = 'KG/M3'}) => [
  _measD('측정 모드. * 스위치를 누름 ($what 메뉴는 설정 레벨에 있음)', press: GdKey.star, data: data, msg: msg),
  for (var i = 0; i <= target; i++)
    _set(
      i == 0
          ? '설정 레벨 *RANGE (비밀번호를 걸었으면 먼저 XXX *PASSW → [ENT]). ${target == 0 ? '[YES]' : '[NO]로 다음 메뉴'}'
          : (i == target ? '${['', '*CAL.DT', '*ALARM', '*SERVC'][i]}에서 [YES]' : '[NO]로 다음 메뉴'),
      ['*RANGE', '*CAL.DT', '*ALARM', '*SERVC'][i],
      i,
      press: i == target ? GdKey.yes : GdKey.no,
    ),
];

/// 밀도·열량 모드: 측정 모드 → [MODE] → 운전 레벨 DISP → … target(9 DISP, 10 SEM.CAL, 11 MAN.CAL, 12 VALVE).
List<GdStep> _toOpD(int target, {String data = '1.2504', String msg = 'KG/M3', GdGas? gas}) {
  const names = {kOpDisplay: 'DISP', _opSemi: 'SEM.CAL', kOpManCal: 'MAN.CAL', _opValve: 'VALVE'};
  return [
    _measD('측정 모드에서 [MODE] (비밀번호를 걸었으면 XXX *PASSW → [ENT])', press: GdKey.mode, data: data, msg: msg, gas: gas),
    for (var p = kOpDisplay; p <= target; p++)
      GdStep(
        say: p == target ? '${names[p]}에서 [YES]' : '${names[p]}. [NO]로 다음 (운전 레벨은 DISP → SEM.CAL → MAN.CAL → VALVE 순서로 돎)',
        press: p == target ? GdKey.yes : GdKey.no,
        msg: names[p]!,
        opPtr: p,
        keyOp: const {GdKey.yes, GdKey.no},
        gas: gas,
      ),
  ];
}

const _svcCommon = '01·02·04·05·10·11·12·20·21·23·31·40~45·50·82는 수소 순도 모드와 같음 ("수소 설정" 탭 표). 03(*H_HLD)은 수소 모드에만 있음';

Widget _codeTableDC() => refTable(
  headers: const ['코드', '화면', '내용·범위'],
  flex: const [2, 3, 7],
  rows: const [
    ['13', '*AUTO.C', '자동 교정: 0 안 함 / 1 씀 (1이면 CODE 15도 설정)'],
    ['14', '*REMOT', '원격 반자동 교정: 0 안 함 / 1 씀. 접점 입력(단자 1·2) 배선과 CODE 15 필요'],
    ['15', '*CAL.P', '교정 항목: 0 제로·스팬 / 1 제로만 / 2 스팬만'],
    ['', '*CAL.T', '교정 시간 00~59분'],
    ['', '*STAB.T', '안정 시간 00~59분'],
    ['', '*Y_M_D·*H_M', '자동 교정 시작 날짜 00.01.01~99.12.31, 시간 00.00~23.59'],
    ['', '*CYCL.U·*CYCL.T', '주기 단위 0 시간 / 1 일, 주기 시간 00~23 · 일 000~255'],
    ['22', '*CAL.U', '열량 단위: 0 MJ/m3 / 1 kBTU/ft3'],
    ['30', '*Y_M_D·*H_M', '날짜·시간 (윤년 2월 29일 됨)'],
  ],
  footer: '※ $_svcCommon',
);

Widget _contactTableDC() => refTable(
  headers: const ['값', 'ZERO', 'SPAN', 'MAINT', 'ALM'],
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
  footer: '※ 밀도·열량 모드 CODE 05. ZERO = 단자 22·23, SPAN = 단자 20·21 (교정가스 전자 밸브 구동). FAIL은 NC 고정',
);

List<GdStep> _valveSteps({String data = '1.2504', String msg = 'KG/M3'}) => [
  ..._toOpD(_opValve, data: data, msg: msg, gas: GdGas.gMeasuring),
  GdStep(say: 'V_ZERO (제로가스 밸브). 윗줄은 지금 측정값. [YES]로 제로가스 밸브를 엶', press: GdKey.yes, data: data, msg: 'V_ZERO', opPtr: _opValve, keyOp: const {GdKey.yes, GdKey.no}, gas: GdGas.gMeasuring),
  GdStep(say: 'Z_OPEN: 제로가스가 흐르는 중. 값이 제로가스 밀도 쪽으로 가는지 확인 → [NO]로 시료가스로 되돌림', press: GdKey.no, data: '1.2481', msg: 'Z_OPEN', opPtr: _opValve, keyOp: const {GdKey.yes, GdKey.no}, gas: GdGas.gZeroFlow),
  GdStep(say: 'V_ZERO로 돌아옴. [NO]로 V_SPAN', press: GdKey.no, data: data, msg: 'V_ZERO', opPtr: _opValve, keyOp: const {GdKey.yes, GdKey.no}, gas: GdGas.gMeasuring),
  GdStep(say: 'V_SPAN (스팬가스 밸브). [YES]로 엶', press: GdKey.yes, data: data, msg: 'V_SPAN', opPtr: _opValve, keyOp: const {GdKey.yes, GdKey.no}, gas: GdGas.gMeasuring),
  GdStep(say: 'S_OPEN: 스팬가스가 흐르는 중. 확인 → [NO]로 시료가스로 되돌림', press: GdKey.no, data: '1.9702', msg: 'S_OPEN', opPtr: _opValve, keyOp: const {GdKey.yes, GdKey.no}, gas: GdGas.gSpanFlow),
  GdStep(say: 'V_SPAN에서 [NO] → END. [YES]로 마침 ([NO]면 다시 V_ZERO)', press: GdKey.yes, msg: 'END', opPtr: _opValve, keyOp: const {GdKey.yes, GdKey.no}, gas: GdGas.gMeasuring),
  GdStep(say: 'WAIT (안정 시간). [YES]면 안정 시간이 지난 뒤, [NO]면 바로 측정 모드. 밸브를 하나도 안 열었으면 WAIT는 건너뜀', press: GdKey.no, data: data, msg: 'WAIT', opPtr: _opValve, keyOp: const {GdKey.yes, GdKey.no}, hold: true, gas: GdGas.gMeasuring),
  _measD('측정 모드', data: data, msg: msg, gas: GdGas.gMeasuring),
];

List<GdStep> _semiSteps({String data = '1.2504', String msg = 'KG/M3'}) => [
  ..._toOpD(_opSemi, data: data, msg: msg, gas: GdGas.gMeasuring),
  const GdStep(say: 'START에서 [YES]로 시작 ([NO]면 DISP). 그 뒤는 키를 안 눌러도 저절로 진행', press: GdKey.yes, msg: 'START', opPtr: _opSemi, keyOp: {GdKey.yes, GdKey.no}, gas: GdGas.gMeasuring),
  const GdStep(say: 'ZERO: 제로가스를 흘리며 보상 밀도 표시. CODE 15 교정 시간(*CAL.T)이 되면 교정값을 읽음', data: '1.2485', msg: 'ZERO', opPtr: _opSemi, hold: true, lamps: {'CAL/SEL'}, gas: GdGas.gZeroFlow),
  const GdStep(say: 'SPAN: 스팬가스로 같은 방식', data: '1.9738', msg: 'SPAN', opPtr: _opSemi, hold: true, lamps: {'CAL/SEL'}, gas: GdGas.gSpanFlow),
  const GdStep(say: 'WAIT: 시료가스로 돌아와 안정 시간(*STAB.T) 동안 기다림', data: '1.2502', msg: 'WAIT', opPtr: _opSemi, hold: true, gas: GdGas.gMeasuring),
  _measD('측정 모드로 돌아옴. 실패하면 WAIT와 ALM.10이 번갈아 뜨고, 측정 모드에서도 남음 (다시 교정이 정상으로 끝나야 지워짐)', data: data, msg: msg, gas: GdGas.gMeasuring),
];

// ───────── 설치·배선·배관 ─────────

class _Install extends StatelessWidget {
  const _Install();

  @override
  Widget build(BuildContext context) => _page('install', [
    refIntroBadge('검출기 GD40과 변환기 GD402를 처음 설치할 때입니다 (설명서 2장). 단자표는 "개요" 탭.'),
    _title('놓을 자리 (검출기·변환기 공통)'),
    ..._rows(const [
      ('검출기', '시료 채취점에 되도록 가깝게, 정비하기 쉬운 곳'),
      ('변환기', '키가 작업자 정면에 오게. 검출기 가까우면 교정이 편함. 뒤쪽 400 mm 이상 비움 (뒤 덮개 열고 배선)'),
      ('피할 곳', '부식성 가스, 큰 진동 (배선 풀림), 직사광선·고온 설비 복사열, 물이 튀는 곳'),
      ('습도', '5~95 %RH (권장 25~85 %RH)'),
      ('고도', '2,000 m 미만'),
      ('직사광선', '변환기 안 온도가 한계를 넘을 것 같으면 후드(옵션)'),
      ('방폭 지역', '방폭형 검출기 GD40T·V·R, 변환기 GD402T·V·R. 개조·부품 교체는 인증 무효'),
    ]),
    _title('설치'),
    ..._rows(const [
      ('검출기', '50 A(외경 60.5 mm) 파이프에 세로로. 배선 구멍 G1/2(R)·1/2 NPT, 시료 입출구 Rc1/4(R)·1/4 NPT'),
      ('GD402G 파이프', 'φ60.5 mm 파이프에 U볼트·브래킷'),
      ('GD402G 벽', '부착 구멍 3곳, M8 볼트 (따로 준비)'),
      ('GD402G 판넬', '판넬 구멍 139 (+2/0) mm 정사각, 브래킷 달기 전에 변환기부터 넣음'),
      ('GD402T·V·R', '약 15 kg, 50 A 파이프, 접지 단자 M5, 배선 구멍 G3/4(R)·1/2 NPT 6개'),
    ]),
    _title('방폭형 조건'),
    refTable(
      headers: const ['기종', '주위 온도', '실링'],
      rows: const [
        ['GD40T (FM)', '-10~60 ℃, T5', '475 mm 이내'],
        ['GD40V (CSA)', '-10~60 ℃, T5', '500 mm 이내'],
        ['GD402T (FM)', '-10~55 ℃, T6', '475 mm 이내'],
        ['GD402V (CSA)', '-10~55 ℃, T6', '500 mm 이내'],
      ],
      footer: '※ 위험 지역에서 기계적 불꽃이 나지 않게. 덮개 열기 전 회로 차단',
    ),
    _title('배관'),
    gdGasFigure(GdGas.gMeasuring),
    const SizedBox(height: 10),
    ..._steps(const [
      '배관 계통 네 가지: 시료 공급, 배출(회수 또는 대기 방출), 제로 교정가스, 스팬 교정가스',
      '스테인리스 관, 외경 6 mm(내경 4 mm) ~ 15 A. 새지 않게 단단히',
      '시료 → 차단 밸브 → 필터 → 절환 밸브(제로·스팬 가스 합류) → 유량계 → 검출기 → 압력 전송기 분기 → 회수',
      '검출기 입구 압력 0.5 MPa 이하. 높으면 감압 밸브, 낮으면 펌프',
      '회수할 때 입구와 회수점 차압 0.5 kPa 이상, 회수 배관은 굵게',
      '채취점(회수점)에 반드시 차단 밸브',
      '유량 0.1~1 L/min. 먼지·미스트·수분은 필터·미스트 분리기·제습기로 제거',
      '교정가스 용기 압력은 감압기로 입구 압력까지 낮춤',
      '압력 전송기 도압관은 검출기에서 0.5 m 이내',
    ]),
    const SizedBox(height: 8),
    refTipBox('자동·반자동 교정을 쓰려면 제로·스팬 가스 절환에 전자 밸브가 필요함 (방폭 지역이면 방폭형). 수소 순도계 배관은 "개요" 탭'),
    _title('배선 순서'),
    ..._steps(const [
      '외부 차단기로 전원 차단 (안에 고전압)',
      '검출기·변환기 일련번호 짝 확인 (다르면 CODE 82로 검출기 상수 입력)',
      'GD402G: 앞 덮개 네 모서리 나사 → 단자 덮개 떼고 배선. 글랜드 A·B = 압력 전송기·출력·접점 입력, C = 검출기, D·E = 접점 출력, F = 전원',
      'GD402T·V·R: 육각 고정나사를 먼저 풀고 뒤 덮개를 반시계 방향으로 엶 (그냥 돌리면 나사산 상함). 글랜드 A = 전원, B·C = 접점 출력, D = 검출기, E·F = 압력 전송기·출력·접점 입력. 케이블은 75 ℃ 이상',
      '피복 6 mm 벗겨 단자에 조임 (0.5 N·m), 극성 확인',
      '남은 케이블을 함 안에 밀어 넣지 말 것. 덮개·글랜드 단단히',
    ]),
    _title('케이블'),
    refTable(
      headers: const ['용도', '케이블', '주의'],
      flex: const [3, 5, 5],
      rows: const [
        ['전원', 'AC 3심 1.25~2.5 mm², DC 2심, 외경 8~16 mm', '외부 차단기 5 A (IEC 947-1·3)'],
        ['출력 1·2', '차폐 0.75~2.5 mm², 외경 8~16 mm', '차폐 한쪽만 접지, 부하 600 Ω (BRAIN 250~550 Ω)'],
        ['검출기', '차폐, 외경 10~13.5 mm, M4 압착단자', '차폐는 단자 13. 노이즈 심하면 이중 차폐(GDW-L)'],
        ['압력 전송기', '차폐, 총 저항 50 Ω 이하', '7·9 연결, 8 → 전송기 −, 10 → 전송기 +'],
        ['교정 접점', '1.25 mm² 이상', '전자 밸브 구동 (전원은 따로, 스위치·퓨즈)'],
        ['기타 접점', '0.13~1.25 mm²', '무전압 접점, 경보등 전원은 따로'],
        ['접점 입력', '무전압 신호', '외부 전압 걸지 말 것'],
      ],
    ),
    _title('접지'),
    ..._rows(const [
      ('변환기', 'D종 접지. 단자 26 또는 외함 접지 단자 (0.5 N·m)'),
      ('검출기 (방폭)', 'A종 접지, 10 Ω 이하, 2 mm² 이상'),
      ('외함 접지', '외함 → 접지선 압착단자 → 록 와셔 → 접지 단자'),
    ]),
    const SizedBox(height: 8),
    refDataRow('설명서 차이', '검출기 접지 단자가 그림에는 "3 mm screw", 본문에는 M4 압착단자로 적힘. 본문의 그림 번호(2.12·2.17 등)도 실제 그림과 다름'),
  ]);
}

// ───────── 밀도계 설정 ─────────

class _DensSetup extends StatelessWidget {
  const _DensSetup();

  @override
  Widget build(BuildContext context) => _page('dens_setup', [
    refIntroBadge('밀도계로 쓸 때 (서비스 CODE 50 = 0). 밀도·보상 밀도·비중·열량·분자량·농도를 측정해 출력합니다 (설명서 5장).'),
    _title('운전 레벨'),
    ..._rows(const [
      ('DISP', '측정 모드에 보일 항목'),
      ('SEM.CAL', '반자동 교정 (원터치)'),
      ('MAN.CAL', '수동 교정'),
      ('VALVE', '제로·스팬 가스 밸브 확인'),
    ]),
    _title('따라하기: 측정 모드에 보일 항목 (DISP)'),
    Gd402Walkthrough(id: 'd_disp', steps: [
      ..._toOpD(kOpDisplay),
      const GdStep(say: '1) 물리 밀도. [NO]를 누르면 다음 항목', press: GdKey.no, data: '1.3842', msg: 'KG/M3', opPtr: kOpDisplay, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '2) 보상 밀도 (0 ℃·1 atm 기준). [NO]', press: GdKey.no, data: '1.2504', msg: 'KG/M3', opPtr: kOpDisplay, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '3) 비중 (공기 = 1). 이걸 보이려면 [YES]', press: GdKey.yes, data: '0.9672', msg: 'SP GR', opPtr: kOpDisplay, keyOp: {GdKey.yes, GdKey.no}),
      _measD('측정 모드에 비중이 표시됨. 4) 열량 5) 분자량 6) 농도도 같은 방법, 7) 온도 8) 압력 9)·10) 출력 %는 보기만', data: '0.9672', msg: 'SP GR'),
    ]),
    const SizedBox(height: 10),
    refTable(
      headers: const ['DISP 항목', '표시', '측정 모드 표시'],
      flex: const [4, 5, 3],
      rows: const [
        ['물리 밀도', 'XX.XXXX KG/M3', '가능'],
        ['보상 밀도', 'X.XXXX KG/M3', '가능'],
        ['비중', 'X.XXXX SP GR', '가능'],
        ['열량', 'XXX.XXX MJ/M3', '가능'],
        ['분자량', 'XXX.XX MOL', '가능'],
        ['농도', 'XXX.X VOL%', '가능'],
        ['온도', 'XXX.X ℃', '보기만'],
        ['압력', 'XXX.XX KPA', '보기만'],
        ['출력 1·2', 'XXX.X MA1% / MA2%', '보기만'],
      ],
    ),
    _title('계산식'),
    ..._rows(const [
      ('보상 밀도', 'do = d × (273.15 + t) ÷ 273.15 × 101.33 ÷ P (0 ℃, 101.33 kPa 기준)'),
      ('비중', 'S = do ÷ 1.2928 (공기 밀도)'),
      ('분자량', 'M = 22.414 × do'),
      ('열량·농도', '밀도와 직선 관계로 계산: 두 점(제로·스팬)을 넣음'),
    ]),
    _title('따라하기: 출력 = 열량 (밀도 0.5~0.7 → 35~46.6 MJ/m3)'),
    Gd402Walkthrough(id: 'd_range', steps: [
      ..._toSettingD(0, '출력'),
      const GdStep(say: '*OUT1에서 [YES] (*OUT2는 [NO]로)', press: GdKey.yes, msg: '*OUT1', setPtr: 0, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '항목 목록 (직전에 고른 것부터 보임). [NO]로 넘기며 *CALRY에서 [YES]. 순서: *DENS → *C_DNS → *SP_GR → *CALRY → *MOL → *CONCT → *TEMP → *PRESS', press: GdKey.yes, msg: '*CALRY', setPtr: 0, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '4 mA 열량값 35.000 → [ENT]', press: GdKey.ent, data: '035.000', msg: '*Z_CAL', setPtr: 0, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: '20 mA 열량값 46.600 → [ENT]', press: GdKey.ent, data: '046.600', msg: '*S_CAL', setPtr: 0, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: '35.000일 때의 밀도 0.5000 → [ENT]', press: GdKey.ent, data: '0.5000', msg: '*Z_CL.D', setPtr: 0, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: '46.600일 때의 밀도 0.7000 → [ENT]. *RANGE로 돌아옴', press: GdKey.ent, data: '0.7000', msg: '*S_CL.D', setPtr: 0, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
    ]),
    const SizedBox(height: 10),
    refTipBox('설명서 예: 열량 = 58 × 밀도 + 6 (MJ/m3). 밀도 0.5 → 35, 0.7 → 46.6. 밀도와 열량 관계는 가스 열량계로 정확히 구해 넣을 것'),
    _title('출력 항목과 범위'),
    refTable(
      headers: const ['항목', '0%·100% 화면', '범위'],
      flex: const [3, 4, 6],
      rows: const [
        ['*DENS 물리 밀도', '*Z_DNS·*S_DNS', '0~60.0000 kg/m3'],
        ['*C_DNS 보상 밀도', '*Z_CP.D·*S_CP.D', '0~6.0000 kg/m3'],
        ['*SP_GR 비중', '*Z_SPC·*S_SPC', '0~5.0000'],
        ['*CALRY 열량', '*Z_CAL·*S_CAL + *Z_CL.D·*S_CL.D', '0~133.000 MJ/m3'],
        ['*MOL 분자량', '*Z_MOL·*S_MOL', '0~140.00'],
        ['*CONCT 농도', '*Z_CON·*S_CON + *Z_CN.D·*S_CN.D', '0~100.0 vol%'],
        ['*TEMP·*PRESS', '설정 없음', ''],
      ],
      footer: '※ 통신(BRAIN)은 출력 1만. *Z_CL.D 등 밀도 보조값 범위는 설명서에 없음',
    ),
    const SizedBox(height: 10),
    refDataRow('농도 예 (H2 in N2)', 'H2 0.0899, N2 1.2504 kg/m3 → *Z_CON 0, *S_CON 100, *Z_CN.D 1.2504, *S_CN.D 0.0899'),
    _title('따라하기: 알람 (물리 밀도 상하한)'),
    Gd402Walkthrough(id: 'd_alarm', steps: [
      ..._toSettingD(2, '알람'),
      const GdStep(say: '항목 고르기 (*DENS → *C_DNS → *SP_GR → *CALRY → *MOL → *CONCT). *DENS에서 [YES]', press: GdKey.yes, msg: '*DENS', setPtr: 2, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '하한 → [ENT]', press: GdKey.ent, data: '01.1000', msg: '*L_DNS', setPtr: 2, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: '상한 → [ENT]. *ALARM으로 돌아옴', press: GdKey.ent, data: '01.4000', msg: '*H_DNS', setPtr: 2, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
    ]),
    const SizedBox(height: 10),
    refTable(
      headers: const ['항목', '하한·상한', '알람'],
      rows: const [
        ['*DENS', '*L_DNS·*H_DNS', 'ALM.01'],
        ['*C_DNS', '*L_CP.D·*H_CP.D', 'ALM.02'],
        ['*SP_GR', '*L_SPC·*H_SPC', 'ALM.03'],
        ['*CALRY', '*L_CAL·*H_CAL', 'ALM.04'],
        ['*MOL', '*L_MOL·*H_MOL', 'ALM.05'],
        ['*CONCT', '*L_CON·*H_CON', 'ALM.06'],
      ],
      footer: '※ 값 이하·이상이면 알람. 히스테리시스·지연은 설명서에 없음',
    ),
    _title('서비스 코드 (밀도·열량 모드에 더 있는 것)'),
    _codeTableDC(),
    _title('따라하기: 자동·반자동 교정 시간 (CODE 15)'),
    const Gd402Walkthrough(id: 'd_code15', steps: [
      GdStep(say: '*SERVC에서 [YES] → 15 *CODE → [ENT]', press: GdKey.ent, data: '15', msg: '*CODE', setPtr: 3, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      GdStep(say: '교정 항목: 0 제로·스팬 / 1 제로만 / 2 스팬만 → [ENT]', press: GdKey.ent, data: '0', msg: '*CAL.P', setPtr: 3, keyOp: {GdKey.up, GdKey.ent}),
      GdStep(say: '교정 시간 (분). 가스를 흘리고 이 시간이 되면 값을 읽음 → [ENT]', press: GdKey.ent, data: '05', msg: '*CAL.T', setPtr: 3, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      GdStep(say: '안정 시간 (분). 교정 뒤 시료가스로 돌아와 기다리는 시간 → [ENT]', press: GdKey.ent, data: '03', msg: '*STAB.T', setPtr: 3, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      GdStep(say: '자동 교정 시작 날짜 (년.월.일) → [ENT]', press: GdKey.ent, data: '26.10.05', msg: '*Y_M_D', setPtr: 3, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      GdStep(say: '시작 시간 (시.분) → [ENT]', press: GdKey.ent, data: '09.00', msg: '*H_M', setPtr: 3, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      GdStep(say: '주기 단위: 0 시간 / 1 일 → [ENT]', press: GdKey.ent, data: '1', msg: '*CYCL.U', setPtr: 3, keyOp: {GdKey.up, GdKey.ent}),
      GdStep(say: '주기 (일이면 000~255, 시간이면 00~23) → [ENT]. *SERVC로 돌아옴', press: GdKey.ent, data: '007', msg: '*CYCL.T', setPtr: 3, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
    ]),
    const SizedBox(height: 10),
    refTipBox('자동 교정은 CODE 13 = 1, 원격 반자동(접점 입력으로 시작)은 CODE 14 = 1. 날짜·시간(CODE 30)이 맞아야 자동 교정이 제때 돎. 예시 숫자는 그림용'),
    _title('따라하기: 날짜·시간 (CODE 30)'),
    const Gd402Walkthrough(id: 'd_code30', steps: [
      GdStep(say: '*SERVC에서 [YES] → 30 *CODE → [ENT]', press: GdKey.ent, data: '30', msg: '*CODE', setPtr: 3, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      GdStep(say: '오늘 날짜 (년.월.일) → [ENT]', press: GdKey.ent, data: '26.10.02', msg: '*Y_M_D', setPtr: 3, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      GdStep(say: '현재 시간 (시.분) → [ENT]. *SERVC로 돌아옴', press: GdKey.ent, data: '10.30', msg: '*H_M', setPtr: 3, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
    ]),
    _title('표시 설정 (서비스 레벨)'),
    ..._rows(const [
      ('CODE 20·21·22·23', '압력·밀도·열량·온도 단위'),
      ('CODE 31', '음수 측정값 0 보임 / 1 숨김 (따라하기는 "수소 표시" 탭, 순서는 같음)'),
      ('CODE 43', '0 보통 / 1 고분해능'),
      ('설명서에 없음', '100%·상한에서 값을 막는 설정, 백라이트'),
    ]),
    _title('접점 NO/NC (CODE 05, 밀도·열량 모드)'),
    _contactTableDC(),
  ]);
}

// ───────── 밀도계 교정 ─────────

class _DensCal extends StatelessWidget {
  const _DensCal();

  @override
  Widget build(BuildContext context) => _page('dens_cal', [
    refIntroBadge('밀도계는 반자동·수동·자동 세 가지로 교정합니다. 제로·스팬 표준가스 밀도를 직접 넣습니다 (설명서 8장).'),
    _title('순서'),
    ..._steps(const [
      '교정값: 설정 레벨 *CAL.DT (제로·스팬 가스 밀도, 교정 중 출력 유지)',
      '반자동·자동이면 서비스 CODE 13·14·15',
      '밸브 확인 (VALVE)',
      '교정: 반자동 SEM.CAL / 수동 MAN.CAL / 자동 (정해진 때 저절로)',
    ]),
    _title('따라하기 1: 교정값 (*CAL.DT)'),
    Gd402Walkthrough(id: 'd_caldt', steps: [
      ..._toSettingD(1, '교정값'),
      const GdStep(say: '제로가스 밀도 (0 ℃·1 atm). 예: 질소 1.2504 → [ENT]', press: GdKey.ent, data: '1.2504', msg: '*Z_DNS', setPtr: 1, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: '스팬가스 밀도. 예: CO2 1.9771 → [ENT]', press: GdKey.ent, data: '1.9771', msg: '*S_DNS', setPtr: 1, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: '교정 중 출력: 0 유지 안 함 / 1 직전값 / 2 지정값 → [ENT]', press: GdKey.ent, data: '1', msg: '*C_HLD', setPtr: 1, keyOp: {GdKey.up, GdKey.ent}),
      const GdStep(say: '2일 때만 지정값 % (-10.0~110.0) → [ENT]. *RANGE로 돌아옴', press: GdKey.ent, data: '050.0', msg: '*PR.SET', setPtr: 1, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
    ]),
    const SizedBox(height: 10),
    refTable(
      headers: const ['가스', '밀도 kg/m3 (0 ℃, 1 atm)'],
      rows: const [
        ['수소 H2', '0.08988'],
        ['헬륨 He', '0.179 (TI 시험값)'],
        ['메탄 CH4', '0.7175'],
        ['질소 N2', '1.2504'],
        ['공기', '1.2928'],
        ['산소 O2', '1.4289'],
        ['이산화탄소 CO2', '1.9771'],
        ['프로판 C3H8', '2.0102'],
      ],
      footer: '※ 요꼬가와 TI 11T03E01-01E 부록 (JIS K2301). 실제는 표준가스 성적서 값을 넣을 것',
    ),
    _title('따라하기 2: 밸브 확인 (VALVE)'),
    Gd402Walkthrough(id: 'd_valve', steps: _valveSteps()),
    _title('준비: 반자동·자동 교정'),
    ..._rows(const [
      ('전자 밸브', '제로·스팬 가스를 바꿔 주는 전자 밸브 필요. 방폭 지역이면 방폭형. 용기는 검출기 가까이'),
      ('구동 접점', 'ZERO = 단자 22·23, SPAN = 단자 20·21. 250 V AC 3 A / 30 V DC 3 A. 전원은 따로 대고 스위치·퓨즈'),
      ('원격 시작', 'CODE 14 = 1이면 접점 입력(단자 1·2)에 무전압 신호로 반자동 교정 시작'),
    ]),
    const SizedBox(height: 8),
    refDataRow('설명서에 없음', '어느 단계에서 어느 접점이 움직이는지는 적혀 있지 않음 (ZERO 단계 = ZERO 접점으로 보임). CODE 15 = 제로만·스팬만일 때 화면이 어떻게 건너뛰는지도 없음'),
    _title('따라하기 3: 반자동 교정 (SEM.CAL)'),
    Gd402Walkthrough(id: 'd_semi', steps: _semiSteps()),
    const SizedBox(height: 10),
    refTipBox('ZERO·SPAN 중 [MODE] → WAIT → [MODE] 한 번 더 → 측정 모드 (교정 취소)'),
    _title('따라하기 4: 수동 교정 (MAN.CAL)'),
    Gd402Walkthrough(id: 'd_man', steps: [
      ..._toOpD(kOpManCal, gas: GdGas.gMeasuring),
      const GdStep(say: 'ZERO. [YES] (제로를 건너뛰려면 [NO] → SPAN)', press: GdKey.yes, msg: 'ZERO', opPtr: kOpManCal, keyOp: {GdKey.yes, GdKey.no}, gas: GdGas.gMeasuring),
      const GdStep(say: '제로가스 밀도를 [>][∧]로 넣고 [ENT]', press: GdKey.ent, data: '1.2504', msg: 'Z_DNS', opPtr: kOpManCal, keyOp: {GdKey.right, GdKey.up, GdKey.ent}, gas: GdGas.gAllClosed),
      const GdStep(say: '제로가스를 흘림 (수동 밸브나 전자 밸브). 지시가 안정되면 [ENT]. 이 화면은 [>][∧]를 안 받음', press: GdKey.ent, data: '1.2511', msg: 'CAL.SET', opPtr: kOpManCal, keyOp: {GdKey.ent}, hold: true, gas: GdGas.gZeroFlow),
      const GdStep(say: 'SPAN. [YES] (제로를 마치고 [NO]면 WAIT, 제로를 건너뛰고 [NO]면 MAN.CAL)', press: GdKey.yes, msg: 'SPAN', opPtr: kOpManCal, keyOp: {GdKey.yes, GdKey.no}, gas: GdGas.gAllClosed),
      const GdStep(say: '스팬가스 밀도 → [ENT]', press: GdKey.ent, data: '1.9771', msg: 'S_DNS', opPtr: kOpManCal, keyOp: {GdKey.right, GdKey.up, GdKey.ent}, gas: GdGas.gAllClosed),
      const GdStep(say: '스팬가스를 흘리고 안정되면 [ENT] (교정값 이상이면 ALM.10 → [YES]·[NO]로 MAN.CAL)', press: GdKey.ent, data: '1.9752', msg: 'CAL.SET', opPtr: kOpManCal, keyOp: {GdKey.ent}, hold: true, gas: GdGas.gSpanFlow),
      const GdStep(say: '시료가스로 돌림. WAIT: [YES]면 안정 시간 뒤, [NO]면 바로 측정 모드', press: GdKey.no, data: '1.2502', msg: 'WAIT', opPtr: kOpManCal, keyOp: {GdKey.yes, GdKey.no}, hold: true, gas: GdGas.gMeasuring),
      _measD('측정 모드', gas: GdGas.gMeasuring),
    ]),
    _title('자동 교정'),
    ..._steps(const [
      'CODE 13 *AUTO.C = 1, CODE 15에 항목·교정 시간·안정 시간·시작 날짜·시간·주기',
      '정한 때가 되면 측정 모드 → ZERO → SPAN → WAIT → 측정 모드로 저절로 돎 (화면은 반자동과 같음)',
      '중단: ZERO·SPAN 중 [MODE] → WAIT → [MODE]',
      '자동 교정 중에도 반자동·수동으로 끼어들 수 있음. 반자동 중에 자동 교정 시간이 되면 그 회는 건너뜀',
      '교정 중 출력은 *CAL.DT의 *C_HLD를 따름',
    ]),
  ]);
}

// ───────── 열량계 설정 ─────────

class _CalSetup extends StatelessWidget {
  const _CalSetup();

  @override
  Widget build(BuildContext context) => _page('calo_setup', [
    refIntroBadge('열량계로 쓸 때 (서비스 CODE 50 = 1). 밀도·보상 밀도·열량만 측정하고, 열량은 밀도에서 계산합니다 (설명서 6장).'),
    _title('밀도계와 다른 점'),
    ..._rows(const [
      ('측정 항목', '물리 밀도, 보상 밀도, 열량 (비중·분자량·농도 없음)'),
      ('출력·알람 항목', '*DENS, *C_DNS, *CALRY (+ 출력은 *TEMP·*PRESS). 열량 출력은 *Z_CAL·*S_CAL만 넣음'),
      ('교정값', '제로·스팬마다 열량과 밀도를 짝으로: *Z_CAL·*Z_DNS·*S_CAL·*S_DNS'),
      ('환산 계수', 'MAN.CAL 안에 밀도/열량 환산 계수(ADJUST) 설정이 있음. 열량을 측정하려면 꼭 해야 함 (설명서)'),
      ('단위', 'CODE 22: MJ/m3 / kBTU/ft3 (1 kBTU/ft3 = 37.259 MJ/m3)'),
      ('알람', '열량 상하한 *L_CAL·*H_CAL → ALM.04'),
    ]),
    _title('따라하기: 측정 모드에 열량 보이기 (DISP)'),
    Gd402Walkthrough(id: 'c_disp', steps: [
      ..._toOpD(kOpDisplay, data: '1.2504', msg: 'KG/M3'),
      const GdStep(say: '1) 물리 밀도. [NO]', press: GdKey.no, data: '0.8421', msg: 'KG/M3', opPtr: kOpDisplay, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '2) 보상 밀도. [NO]', press: GdKey.no, data: '0.7766', msg: 'KG/M3', opPtr: kOpDisplay, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '3) 열량. [YES]', press: GdKey.yes, data: '051.040', msg: 'MJ/M3', opPtr: kOpDisplay, keyOp: {GdKey.yes, GdKey.no}),
      _measD('측정 모드에 열량. 4) 온도 5) 압력 6)·7) 출력 %는 보기만', data: '051.040', msg: 'MJ/M3'),
    ]),
    _title('따라하기: 출력 = 열량'),
    Gd402Walkthrough(id: 'c_range', steps: [
      ..._toSettingD(0, '출력', data: '051.040', msg: 'MJ/M3'),
      const GdStep(say: '*OUT1에서 [YES]', press: GdKey.yes, msg: '*OUT1', setPtr: 0, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '*DENS → *C_DNS → *CALRY 순서. *CALRY에서 [YES]', press: GdKey.yes, msg: '*CALRY', setPtr: 0, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '4 mA 열량 → [ENT] (0~133.000 MJ/m3)', press: GdKey.ent, data: '035.000', msg: '*Z_CAL', setPtr: 0, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: '20 mA 열량 → [ENT]. *RANGE로 돌아옴', press: GdKey.ent, data: '060.000', msg: '*S_CAL', setPtr: 0, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
    ]),
    _title('따라하기: 열량 알람'),
    Gd402Walkthrough(id: 'c_alarm', steps: [
      ..._toSettingD(2, '알람', data: '051.040', msg: 'MJ/M3'),
      const GdStep(say: '*CALRY에서 [YES]', press: GdKey.yes, msg: '*CALRY', setPtr: 2, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '하한 → [ENT]', press: GdKey.ent, data: '045.000', msg: '*L_CAL', setPtr: 2, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: '상한 → [ENT]', press: GdKey.ent, data: '055.000', msg: '*H_CAL', setPtr: 2, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
    ]),
    _title('따라하기: 밀도/열량 환산 계수 (ADJUST)'),
    Gd402Walkthrough(id: 'c_adjust', steps: [
      ..._toOpD(kOpManCal, data: '051.040', msg: 'MJ/M3'),
      const GdStep(say: 'ZERO에서 [NO]', press: GdKey.no, msg: 'ZERO', opPtr: kOpManCal, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: 'SPAN에서 [NO]', press: GdKey.no, msg: 'SPAN', opPtr: kOpManCal, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: 'ADJUST에서 [YES]', press: GdKey.yes, msg: 'ADJUST', opPtr: kOpManCal, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: 'AT_ADJ (자동 제로 조정). 하려면 [YES], 계수만 넣으려면 [NO] → SET_K', press: GdKey.yes, msg: 'AT_ADJ', opPtr: kOpManCal, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: '값을 넣고 [ENT] (0~133.000, 화면 글자는 설명서대로 VALVE)', press: GdKey.ent, data: '051.040', msg: 'VALVE', opPtr: kOpManCal, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: '지시값이 안정되면 [ENT]. 결과는 K0_ADJ에도 들어감. AT_ADJ로 돌아옴 → [NO]', press: GdKey.ent, data: '051.040', msg: 'CAL.SET', opPtr: kOpManCal, keyOp: {GdKey.ent}),
      const GdStep(say: 'SET_K (계수 넣기)에서 [YES]', press: GdKey.yes, msg: 'SET_K', opPtr: kOpManCal, keyOp: {GdKey.yes, GdKey.no}),
      const GdStep(say: 'K0_ADJ (제로) -99999~99999 → [ENT]. [>]를 누를 때마다 숫자 → 소수점 → 부호 칸으로 옮겨 감 (소수점 위치를 옮길 수 있는 건 여기만)', press: GdKey.ent, data: '0.0000', msg: 'K0_ADJ', opPtr: kOpManCal, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: 'K0 → [ENT]', press: GdKey.ent, data: '6.0000', msg: 'K0', opPtr: kOpManCal, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: 'K1 (0~99999) → [ENT]. SET_K로 돌아옴 → [NO]', press: GdKey.ent, data: '58.000', msg: 'K1', opPtr: kOpManCal, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: 'END에서 [YES] → 측정 모드 ([NO]면 다시 AT_ADJ)', press: GdKey.yes, msg: 'END', opPtr: kOpManCal, keyOp: {GdKey.yes, GdKey.no}),
    ]),
    const SizedBox(height: 10),
    refWarnBox('K0·K1이 들어가는 식의 꼴(예: 열량 = K0 + K1 × 밀도인지)은 설명서에 적혀 있지 않음. AT_ADJ 화면 글자 "VALVE"가 무엇인지도 설명이 없음. 계수는 요꼬가와나 공급사 자료대로 넣을 것. 예시 숫자(6, 58)는 그림용'),
    _title('서비스 코드'),
    _codeTableDC(),
  ]);
}

// ───────── 열량계 교정 ─────────

class _CalCal extends StatelessWidget {
  const _CalCal();

  @override
  Widget build(BuildContext context) => _page('calo_cal', [
    refIntroBadge('열량계 교정은 밀도계와 같은 세 방식(반자동·수동·자동)이고, 제로·스팬마다 열량과 밀도를 짝으로 넣는 것만 다릅니다 (설명서 9장).'),
    _title('순서'),
    ..._steps(const [
      '교정값 *CAL.DT (제로·스팬 열량과 밀도, 출력 유지)',
      '밀도/열량 환산 계수 (ADJUST, "열량계 설정" 탭)',
      '반자동·자동이면 CODE 13·14·15 ("밀도계 설정" 탭과 같음)',
      '밸브 확인 → 반자동 SEM.CAL / 수동 MAN.CAL / 자동',
    ]),
    _title('따라하기 1: 교정값 (*CAL.DT)'),
    Gd402Walkthrough(id: 'c_caldt', steps: [
      ..._toSettingD(1, '교정값', data: '051.040', msg: 'MJ/M3'),
      const GdStep(say: '제로가스 열량 (0~133.000 MJ/m3) → [ENT]', press: GdKey.ent, data: '039.940', msg: '*Z_CAL', setPtr: 1, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: '제로가스 밀도 → [ENT]', press: GdKey.ent, data: '0.7175', msg: '*Z_DNS', setPtr: 1, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: '스팬가스 열량 → [ENT]', press: GdKey.ent, data: '101.400', msg: '*S_CAL', setPtr: 1, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: '스팬가스 밀도 → [ENT]', press: GdKey.ent, data: '2.0102', msg: '*S_DNS', setPtr: 1, keyOp: {GdKey.right, GdKey.up, GdKey.ent}),
      const GdStep(say: '교정 중 출력 0/1/2 → [ENT] (2면 *PR.SET). *RANGE로 돌아옴', press: GdKey.ent, data: '1', msg: '*C_HLD', setPtr: 1, keyOp: {GdKey.up, GdKey.ent}),
    ]),
    const SizedBox(height: 10),
    refTipBox('예시는 TI 부록 값: 메탄 39.94 MJ/m3·0.7175 kg/m3, 프로판 101.4 MJ/m3·2.0102 kg/m3 (총발열량, 0 ℃·1 atm). 실제는 표준가스 성적서 값'),
    _title('따라하기 2: 수동 교정 (MAN.CAL)'),
    Gd402Walkthrough(id: 'c_man', steps: [
      ..._toOpD(kOpManCal, data: '051.040', msg: 'MJ/M3', gas: GdGas.gMeasuring),
      const GdStep(say: 'ZERO. [YES] ([NO]면 SPAN)', press: GdKey.yes, msg: 'ZERO', opPtr: kOpManCal, keyOp: {GdKey.yes, GdKey.no}, gas: GdGas.gMeasuring),
      const GdStep(say: '제로 열량 → [ENT]', press: GdKey.ent, data: '039.940', msg: 'Z_CAL', opPtr: kOpManCal, keyOp: {GdKey.right, GdKey.up, GdKey.ent}, gas: GdGas.gAllClosed),
      const GdStep(say: '제로 밀도 → [ENT]', press: GdKey.ent, data: '0.7175', msg: 'Z_DNS', opPtr: kOpManCal, keyOp: {GdKey.right, GdKey.up, GdKey.ent}, gas: GdGas.gAllClosed),
      const GdStep(say: '제로가스를 흘리고 안정되면 [ENT]', press: GdKey.ent, data: '0.7181', msg: 'CAL.SET', opPtr: kOpManCal, keyOp: {GdKey.ent}, hold: true, gas: GdGas.gZeroFlow),
      const GdStep(say: 'SPAN. [YES]', press: GdKey.yes, msg: 'SPAN', opPtr: kOpManCal, keyOp: {GdKey.yes, GdKey.no}, gas: GdGas.gAllClosed),
      const GdStep(say: '스팬 열량 → [ENT]', press: GdKey.ent, data: '101.400', msg: 'S_CAL', opPtr: kOpManCal, keyOp: {GdKey.right, GdKey.up, GdKey.ent}, gas: GdGas.gAllClosed),
      const GdStep(say: '스팬 밀도 → [ENT]', press: GdKey.ent, data: '2.0102', msg: 'S_DNS', opPtr: kOpManCal, keyOp: {GdKey.right, GdKey.up, GdKey.ent}, gas: GdGas.gAllClosed),
      const GdStep(say: '스팬가스를 흘리고 안정되면 [ENT] (이상이면 ALM.10)', press: GdKey.ent, data: '2.0087', msg: 'CAL.SET', opPtr: kOpManCal, keyOp: {GdKey.ent}, hold: true, gas: GdGas.gSpanFlow),
      const GdStep(say: '시료가스로 돌림. WAIT → [YES] 안정 뒤 / [NO] 바로 측정 모드', press: GdKey.no, data: '0.7766', msg: 'WAIT', opPtr: kOpManCal, keyOp: {GdKey.yes, GdKey.no}, hold: true, gas: GdGas.gMeasuring),
      _measD('측정 모드', data: '051.040', msg: 'MJ/M3', gas: GdGas.gMeasuring),
    ]),
    _title('따라하기 3: 반자동 교정 (SEM.CAL)'),
    Gd402Walkthrough(id: 'c_semi', steps: _semiSteps(data: '051.040', msg: 'MJ/M3')),
    const SizedBox(height: 10),
    refTipBox('반자동 화면은 열량계도 밀도(XX.XXXX)를 보여 줌. 밸브 확인·자동 교정은 "밀도계 교정" 탭과 같음'),
    _title('따라하기 4: 밸브 확인 (VALVE)'),
    Gd402Walkthrough(id: 'c_valve', steps: _valveSteps(data: '051.040', msg: 'MJ/M3')),
  ]);
}
