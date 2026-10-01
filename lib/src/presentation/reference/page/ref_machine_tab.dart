// 장비 사용법: 장비마다 접힌 줄 하나. 펴면 제원·작업 순서·안전 수칙·점검·고장 조치·정리정돈을 칸으로 골라 본다.
// 글은 안전 교육·장비 교육 자료처럼 개조식으로 쓴다(~확인, ~금지, ~사용). 안전 수칙 머리말은 재해 유형(끼임·베임·맞음·감전·화재),
// 고장 조치는 현상·원인·조치 세 줄. 장비별 세부(정비 주기·부품·경보 코드)는 제조사 설명서가 먼저다.
// 전동 공구에 다 해당하는 것(전원·릴선·카본 브러시·A/S)은 "전동 공구 공통 수칙"에 한 번만 적는다.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../equipment/equipment_manual.dart';
import 'gd402_manual_page.dart';
import 'reference_widgets.dart';

enum _Group {
  all('전체'),
  tube('튜브'),
  conduit('전선관'),
  cut('절단·나사 가공'),
  meter('계측'),
  base('실측'),
  common('공통');

  final String label;
  const _Group(this.label);
}

const _spec = '제원';
const _order = '작업 순서';
const _safety = '안전 수칙';
const _check = '점검·정비';
const _trouble = '고장 조치';
const _tidy = '정리정돈';

/// 한 칸. [rows]는 (머리말, 내용 — 줄바꿈마다 한 항목), [steps]는 번호 순서, [trouble]은 (현상, 원인, 조치).
class _Part {
  final String name;
  final List<(String, String)> rows;
  final List<String> steps;
  final List<(String, String, String)> trouble;
  final String? warn;
  final String? tip;
  final Widget Function(BuildContext context)? extra;
  const _Part(
    this.name, {
    this.rows = const [],
    this.steps = const [],
    this.trouble = const [],
    this.warn,
    this.tip,
    this.extra,
  });
}

class _Guide {
  final String id;
  final _Group group;
  final String title;
  final String sub;
  final IconData icon;
  final Color color;
  final List<_Part> parts;
  final Widget Function(BuildContext context)? footer; // 설명서 단추 등
  const _Guide({
    required this.id,
    required this.group,
    required this.title,
    required this.sub,
    required this.icon,
    required this.color,
    required this.parts,
    this.footer,
  });
}

Widget _manualButton({required Key key, required String label, required VoidCallback onTap, required Color color}) {
  return SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      key: key,
      onPressed: onTap,
      icon: const Icon(LucideIcons.bookOpen, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}

Widget _vendorManual(BuildContext context, String key, String title) => _manualButton(
  key: Key('vendor_manual_$key'),
  label: '제조사 설명서 (원본 PDF)',
  color: Colors.red.shade700,
  onTap: () => openEquipManual(context, key: key, title: title),
);

final List<_Guide> _guides = [
  // ───────── 튜브 ─────────
  _Guide(
    id: 'tube_hand',
    group: _Group.tube,
    title: '튜브 수동 벤더',
    sub: 'Swagelok·Ridgid 핸드 벤더',
    icon: Icons.handyman_outlined,
    color: Colors.brown,
    parts: [
      _Part(_order, steps: [
        '튜브 외경에 맞는 벤더 준비 (1/4", 3/8", 1/2")',
        '마킹선을 벤딩 슈 0 눈금에 맞춤',
        '치수를 튜브 끝에서 쟀으면 R, 시작점에서 쟀으면 L 눈금 사용 (앱 마킹값은 R 기준)',
        '튜브 클램프 체결 후 롤러를 튜브에 밀착',
        '목표 각도 + 스프링백(2~3°)까지 한 번에 벤딩. 중간에 멈추면 튜브에 자국 남음',
      ]),
      _Part(_safety, rows: [
        ('끼임', '롤러와 슈 사이 손가락 주의\n핸들 끝을 잡고 작업'),
        ('베임', '절단면 버 제거 후 작업'),
        ('맞음', '직관부가 짧으면 클램프에서 튜브가 빠져 튐\n클램프 물림 길이 확보'),
        ('장비 손상', '규격 외 튜브 사용 금지 (3/8" 벤더에 10 mm 튜브 등)\n핸들에 파이프 끼워 연장 사용 금지'),
      ]),
      _Part(_check, rows: [
        ('작업 전', '슈·롤러 홈 이물질, 찍힘 확인\n핸들·피벗 유격 확인'),
        ('작업 후', '홈 쇳가루 청소\n피벗부만 소량 주유 (홈에는 주유 금지)'),
        ('정기', '시험 벤딩으로 각도·게인 확인 ("벤더 실측 캘리브레이션" 참고)'),
      ]),
      _Part(_trouble, trouble: [
        ('튜브 찌그러짐·주름', '벤더 규격 불일치, 클램프 체결 불량, 두께 부족', '규격 확인 후 재체결'),
        ('각도 부족', '스프링백 미반영', '스프링백만큼 추가 벤딩'),
        ('튜브 표면 긁힘', '슈·롤러 홈 이물질 또는 찍힘', '홈 청소, 찍힘 심하면 슈 교체'),
        ('치수 틀어짐', 'R·L 눈금 혼동, 게인 설정값 불일치', '눈금 기준 재확인, 벤더 실측 다시'),
      ]),
      _Part(_tidy, steps: [
        '슈·롤러 홈 청소',
        '핸들·클램프 원위치',
        '규격별 전용 케이스에 보관 (떨어뜨리면 슈 틀어짐)',
      ]),
    ],
  ),
  _Guide(
    id: 'tube_msbtb',
    group: _Group.tube,
    title: 'Swagelok 전동 벤더 (MS-BTB)',
    sub: '펜던트로 각도 입력, 단일 벤딩용',
    icon: Icons.precision_manufacturing,
    color: Colors.orange.shade800,
    parts: [
      _Part(_order, steps: [
        '[ANGLE]에 목표 각도, [SPRINGBACK]에 스프링백 입력 (앱 설정값과 같게)',
        '마킹선을 0점에 맞추고 토글 클램프 끝까지 체결',
        '[BEND] 누르고 있기. 손 떼면 정지',
        '완료 후 [RETURN]으로 암 복귀, 그다음 클램프 해제',
      ]),
      _Part(_safety, rows: [
        ('끼임', '암 회전 반경 안에 손·몸 금지'),
        ('맞음', '긴 튜브는 뒤쪽이 크게 돎. 주변 인원·자재 정리'),
        ('비상정지', '작업 전 비상정지 버튼 위치 확인'),
        ('감전', '펜던트 케이블 밟힘·꺾임 금지'),
      ]),
      _Part(_check, rows: [
        ('작업 전', '다이·롤러·클램프 블록 홈 청소\n클램프 블록 마모 확인 (닳으면 튜브 밀림)'),
        ('정기', '시험 벤딩 후 각도기로 90° 확인, 틀리면 스프링백 값 수정'),
      ]),
      _Part(_trouble, trouble: [
        ('작동 안 됨', '전원, 비상정지 눌림, 암 원위치 아님', '전원 확인, 비상정지 해제, [RETURN] 먼저'),
        ('각도 편차', '클램프 체결 불량, 스프링백 값 틀림, 튜브 재질·두께 바뀜', '재체결, 시험 벤딩으로 값 재설정'),
        ('튜브 밀림', '클램프 블록 마모, 기름 묻음', '청소 또는 블록 교체'),
      ]),
      _Part(_tidy, steps: [
        '[RETURN]으로 암 원위치',
        '전원 OFF, 플러그 분리',
        '다이 분리·청소 후 규격별 보관, 펜던트 케이블은 느슨하게 감기',
      ]),
    ],
  ),
  _Guide(
    id: 'tube_tb20d',
    group: _Group.tube,
    title: 'TRACTO-TECHNIK TB20D (NC 벤더)',
    sub: '제어반 프로그램 입력, 풋 페달 연속 작업',
    icon: LucideIcons.monitorSmartphone,
    color: Colors.indigo,
    parts: [
      _Part(_order, steps: [
        '전원 ON 후 원점 복귀 [HOME]·[REF] 먼저. 생략하면 엉뚱한 각도로 벤딩되어 충돌',
        '[PROG]에서 새 번호 열고 Step 1부터 각도·스프링백(Korr) 입력 (앱 마킹 가이드 벤딩 순서와 같게)',
        '튜브를 후방 스토퍼에 붙이고 [CLAMP] 또는 페달 1단으로 고정',
        '[AUTO] 상태에서 페달 끝까지. 해당 Step 각도까지 벤딩 후 정지',
        '클램프 풀고 다음 마킹까지 이송 후 반복',
      ], warn: '작업 중 화면 Step 번호 계속 확인. 순서 꼬이면 90° 자리에 45°가 들어가서 튜브 버림'),
      _Part('금형·연신율', extra: (_) => refTable(
        headers: const ['규격', '표준 금형 CLR', '권장 연신율'],
        rows: const [
          ['1/4" (6.35)', 'R15.0', '7.0~8.0'],
          ['3/8" (9.52)', 'R22.5', '11.0~12.5'],
          ['1/2" (12.7)', 'R35.0', '18.0~20.0'],
          ['3/4" (19.05)', 'R50.0', '26.0~28.0'],
        ],
        footer: '※ SUS 기준. 금형 CLR이 수동 벤더(R14.3/23.8/38.1)와 다름. 앱 설정의 반경을 이 장비 값으로 바꾸고 마킹',
      )),
      _Part(_safety, rows: [
        ('맞음', '긴 튜브는 벤딩 때 뒤쪽이 크게 돎\n회전 반경 안 출입 금지'),
        ('끼임', '금형·클램프 사이 손 금지\n금형 교체는 전원 OFF 후'),
        ('오조작', '페달은 한 번 밟고 발 뗄 것. 두 번 밟으면 다음 Step 바로 동작'),
      ]),
      _Part(_check, rows: [
        ('작업 전', '금형·클램프 다이 홈 청소\n원점 복귀 정상 동작 확인'),
        ('정기', '시험 벤딩으로 각도·길이 확인, 틀리면 Korr·연신율 수정'),
        ('경보', '경보 코드 기록. 같은 경보 반복되면 A/S 의뢰'),
      ]),
      _Part(_trouble, trouble: [
        ('원점 복귀 안 됨', '이물질 걸림, 센서 이상', '걸린 것 제거 후 재시도, 계속되면 A/S'),
        ('각도 틀어짐', 'Korr 값, 튜브 재질 바뀜, 클램프 체결 불량', 'Korr 재설정, 재체결'),
        ('길이 틀어짐', '연신율 값이 금형·튜브와 안 맞음', '"금형·연신율" 표 기준으로 재설정'),
        ('화면 경보', '', '코드 기록 후 제조사 설명서 경보표 확인'),
      ]),
      _Part(_tidy, steps: [
        '원점 복귀 후 전원 OFF',
        '금형 분리·청소',
        '사용한 프로그램 번호 작업 일지에 기록',
      ]),
    ],
  ),
  _Guide(
    id: 'tube_cutter',
    group: _Group.tube,
    title: '튜브 커터 · 디버링',
    sub: '튜브 절단은 쇠톱 말고 커터로',
    icon: LucideIcons.scissors,
    color: Colors.teal,
    parts: [
      _Part(_order, steps: [
        '마킹선에 커터 날 맞추고 가볍게 조여 한 바퀴',
        '한 바퀴마다 손잡이 1/4바퀴씩만 조임. 한 번에 세게 조이면 끝이 안으로 말림',
        '절단면 안팎 버 제거. 안쪽 버는 유로를 막고, 바깥 버는 페룰 자리를 상하게 함',
        '절단면 직각 확인. 비스듬하면 피팅 안쪽 턱에 안 닿아서 누설',
      ]),
      _Part(_safety, rows: [
        ('베임', '커터 날, 디버링 날, SUS 버에 손 베임 주의'),
      ]),
      _Part(_check, rows: [
        ('작업 전', '날 이 빠짐 확인, 여분 날 준비\n롤러 회전 상태 확인'),
      ]),
      _Part(_trouble, trouble: [
        ('끝단 말림', '한 번에 과하게 조임', '조금씩 조이면서 절단'),
        ('나선 자국', '첫 바퀴 과다 조임, 날·롤러 마모', '첫 바퀴는 가볍게, 마모 시 교체'),
        ('버 과다', '날 무뎌짐', '날 교체'),
      ]),
      _Part(_tidy, steps: [
        '쇳가루 털고 날 보호해서 공구함 보관',
      ]),
    ],
  ),

  // ───────── 전선관 ─────────
  _Guide(
    id: 'conduit_hand',
    group: _Group.conduit,
    title: '전선관 수동 벤더 (히키)',
    sub: 'Greenlee·Ideal 핸드 벤더. 슈에 화살표·별·림 표시',
    icon: LucideIcons.wrench,
    color: Colors.brown,
    parts: [
      _Part(_order, steps: [
        '마킹선을 화살표에 맞춤 (앱 마킹은 테이크업 뺀 화살표 기준)',
        '백투백(두 번째 90°를 관 끝에서 잴 때)은 별 표시에 맞춤',
        '3벤드 새들은 가운데 45°를 림 홈에, 양쪽 22.5°는 화살표에',
        '발판 확실히 밟고 핸들 당겨서 벤딩. 목표 각도 + 스프링백(후강 3~5°)',
        '오프셋은 첫 벤딩 후 관을 180° 돌려서 두 번째 마킹 맞춤. 관에 그은 세로선이 슈 중심과 일직선인지 확인',
      ]),
      _Part(_safety, rows: [
        ('맞음', '발판에서 발 빠지면 관이 튀어 얼굴 타격\n발판 확실히 밟을 것'),
        ('넘어짐', '미끄럽거나 기운 바닥에서 작업 금지'),
        ('근골격계', '굵은 관은 무리하지 말고 유압식 사용\n핸들에 파이프 끼워 연장 금지'),
      ]),
      _Part(_check, rows: [
        ('작업 전', '슈 홈 흙·쇳가루 제거'),
        ('정기', '화살표·별·림 표시가 지워졌으면 다시 새김'),
      ]),
      _Part(_trouble, trouble: [
        ('개다리 (도그렉)', '두 번째 벤딩 때 관이 돌아감', '세로선 맞추고 다시 벤딩'),
        ('각도 부족', '스프링백 미반영', '스프링백만큼 추가 벤딩'),
        ('관 찌그러짐', '슈 규격 불일치 (EMT용 슈에 후강 등)', '관 종류·호칭에 맞는 슈 사용'),
        ('치수 틀어짐', '화살표·별 혼동, 테이크업 값 불일치', '기준 표시 확인, 벤더 실측 다시'),
      ]),
      _Part(_tidy, steps: [
        '홈 청소, 바깥면만 방청유 얇게',
        '핸들 분리해서 호칭별로 같이 보관',
      ]),
    ],
  ),
  _Guide(
    id: 'conduit_hyd',
    group: _Group.conduit,
    title: '유압식 벤더',
    sub: 'Greenlee·Current Tools 유압 벤더. 슈 교체식',
    icon: Icons.precision_manufacturing,
    color: Colors.indigo,
    parts: [
      _Part(_order, steps: [
        '관 호칭에 맞는 슈를 램에, 받침 롤러는 같은 호칭 구멍에 핀으로 체결. 핀이 끝까지 안 들어가면 작업 금지',
        '앱 마킹(셋백 뺀 위치)을 슈 중심 표시에 맞춤',
        '릴리즈 밸브 잠그고 펌핑. 램 눈금이 설정한 램 이동 거리에 오면 멈추고 각도기로 확인',
        '릴리즈 밸브 천천히 열어 복귀. 한 번에 열면 슈가 튐',
      ]),
      _Part(_safety, rows: [
        ('끼임', '램 앞, 슈와 받침 롤러 사이 손·발 금지'),
        ('맞음', '핀 덜 꽂힌 상태로 가압하면 핀이 튀어 나감'),
        ('유압', '호스 꺾임·누유, 커플러 손상 시 사용 금지\n가압 상태에서 커플러 분리 금지\n펌프 정격 압력 초과 금지'),
      ]),
      _Part(_check, rows: [
        ('작업 전', '호스·커플러·램 누유 확인\n오일 레벨 확인 (보충은 지정 오일로)'),
        ('작업 후', '램 표면 청소'),
        ('정기', '램 동작이 출렁이거나 느리면 에어 빼기 (설명서 순서대로)'),
      ]),
      _Part(_trouble, trouble: [
        ('램 전진 안 됨', '릴리즈 밸브 열림, 오일 부족, 커플러 체결 불량', '밸브 잠금, 오일 보충, 커플러 재체결'),
        ('램이 저절로 후진', '릴리즈 밸브 덜 잠김, 패킹 누유', '밸브 확인, 누유면 패킹 교체 의뢰'),
        ('동작 느림·떨림', '오일 부족, 에어 참', '오일 보충, 에어 빼기'),
        ('관 찌그러짐', '슈·받침 롤러 규격 또는 구멍 위치 틀림', '호칭 맞춰 다시 세팅'),
        ('오일 누유', '패킹·호스 손상', '사용 중지, 수리 의뢰. 장비 대장 "수리·점검 중"으로 변경'),
      ]),
      _Part(_tidy, steps: [
        '램 끝까지 복귀시켜 압력 해제',
        '커플러에 먼지 캡, 호스는 크게 감아서 보관',
        '슈·받침·핀 청소 후 호칭별 보관, 흘린 오일 닦기',
      ]),
    ],
  ),
  _Guide(
    id: 'conduit_chicago',
    group: _Group.conduit,
    title: '시카고 벤더',
    sub: '기어·크랭크식. 후강 큰 호칭용',
    icon: LucideIcons.cog,
    color: Colors.deepOrange,
    parts: [
      _Part(_order, steps: [
        '관 호칭에 맞는 롤러(앱 설정 롤러 규격)와 슈 홈에 관 넣고 훅으로 고정',
        '노치 휠 0에 두고 마킹(테이크업 뺀 위치)을 슈 표시에 맞춤',
        '크랭크 돌리면서 노치 칸 수 셈. 칸 수 = 목표 각도 ÷ 노치당 각도(설정값), 스프링백만큼 한두 칸 추가',
        '래칫 풀고 크랭크 복귀. 관 빼기 전에 훅 먼저 해제',
      ]),
      _Part(_safety, rows: [
        ('맞음', '래칫 풀 때 크랭크 역회전\n손잡이 잡고 해제'),
        ('끼임', '기어·노치 휠 회전부에 손가락 금지'),
        ('넘어짐', '프레임 전도 방지 고정\n긴 관은 끝단 받침'),
      ]),
      _Part(_check, rows: [
        ('작업 전', '기어·래칫 쇳가루 제거\n훅 고정력, 롤러 홈 마모 확인'),
        ('정기', '기어·축 그리스 주입 (홈에는 금지)'),
      ]),
      _Part(_trouble, trouble: [
        ('래칫 헛돎', '이물질 끼임, 스프링 약해짐', '청소, 스프링 교체'),
        ('각도 틀어짐', '노치당 각도 설정값 불일치, 스프링백', '벤더 실측으로 값 재설정'),
        ('관 미끄러짐', '훅 고정 불량', '훅 다시 조임'),
        ('크랭크 뻑뻑함', '그리스 부족', '그리스 주입'),
      ]),
      _Part(_tidy, steps: [
        '훅 풀고 크랭크 0 위치',
        '쇳가루 청소, 크랭크 분리해서 같이 보관',
      ]),
    ],
  ),

  // ───────── 절단·나사 가공 ─────────
  _Guide(
    id: 'cut_chop',
    group: _Group.cut,
    title: '고속절단기',
    sub: '절단석으로 형강·전선관 절단',
    icon: LucideIcons.zap,
    color: Colors.redAccent,
    parts: [
      _Part(_order, steps: [
        '절단석 두께(2.5~3 mm)를 형강·튜브 컷팅 화면 "톱날 손실"에 입력',
        '재단 계획 순서대로 긴 것부터 절단, 자재는 바이스에 확실히 고정',
        '절단석이 자재에 닿은 상태로 기동 금지. 회전 다 오른 뒤 천천히 내림',
      ]),
      _Part(_safety, rows: [
        ('파열·비산', '금 가거나 이 빠진 절단석 사용 금지\n절단석 최고 사용 회전수가 기계 회전수보다 높은지 확인\n덮개 제거 금지, 절단석 측면 사용 금지\n작업 전 1분, 절단석 교체 후 3분 이상 시운전'),
        ('화재', '불티 튀는 방향에 배관·케이블·가연물 제거\n소화기 비치'),
        ('베임', '짧은 자재 손으로 잡고 절단 금지, 바이스 고정'),
        ('보호구', '보안경 또는 보안면, 귀마개 착용'),
      ]),
      _Part(_check, rows: [
        ('작업 전', '절단석 균열·마모 확인\n덮개·바이스 고정 상태 확인'),
        ('보관', '절단석은 습기 없는 곳에 보관'),
      ]),
      _Part(_trouble, trouble: [
        ('절단면 기울어짐', '바이스 각도 틀어짐', '바이스 각도 재조정'),
        ('절단석 떨림', '고정 너트 풀림, 절단석 균열', '즉시 정지. 너트 확인, 균열이면 폐기'),
      ]),
      _Part(_tidy, steps: [
        '플러그 분리',
        '쇳가루·불티 찌꺼기 청소 (불씨 남았는지 확인)',
        '잔재는 규격 적어서 잔재 목록에 등록',
      ]),
    ],
  ),
  _Guide(
    id: 'cut_band',
    group: _Group.cut,
    title: '밴드쏘',
    sub: '띠톱으로 형강·파이프 절단',
    icon: LucideIcons.zap,
    color: Colors.redAccent,
    parts: [
      _Part(_order, steps: [
        '톱날 두께(1.3~1.6 mm)를 "톱날 손실"에 입력',
        '자재 바이스 고정, 톱날 장력·가이드 세팅 후 기동',
        '자재 밀어 넣지 말고 톱날 자중으로 내려가게. 후강·H형강은 속도 낮춤',
      ]),
      _Part(_safety, rows: [
        ('베임', '톱날 회전 중 자재를 손으로 밀거나 잡기 금지'),
        ('정비 중', '톱날 교체는 플러그 분리 후, 장갑 착용'),
      ]),
      _Part(_check, rows: [
        ('작업 전', '톱날 장력·가이드·이 빠짐 확인\n절삭유 양 확인'),
      ]),
      _Part(_trouble, trouble: [
        ('절단면 기울어짐', '톱날 가이드·장력 불량', '가이드·장력 재조정'),
        ('톱날 자주 끊어짐', '장력 과다, 이송 과다, 날 이 수가 재질과 안 맞음', '장력 조정, 천천히 이송, 톱날 교체'),
      ]),
      _Part(_tidy, steps: [
        '쇳가루 청소',
        '장기 보관 시 톱날 장력 풀어 둠',
      ]),
    ],
  ),
  _Guide(
    id: 'cut_thread',
    group: _Group.cut,
    title: '수동 나사 절삭 (오스타)',
    sub: '래칫 핸들·다이스로 전선관 나사 가공',
    icon: LucideIcons.wrench,
    color: Colors.blueGrey,
    parts: [
      _Part(_order, steps: [
        '관 끝 직각 절단, 버 제거',
        '절삭유 충분히 주면서 진행, 1/4바퀴씩 되돌려 칩 끊기',
        '나사 길이는 커플링 길이 절반 + 1~2산',
      ]),
      _Part(_safety, rows: [
        ('베임', '나사 칩 날카로움. 맨손 금지, 솔로 제거'),
      ]),
      _Part(_check, rows: [
        ('작업 전', '다이스 날 이 빠짐, 칩 끼임 확인'),
      ]),
      _Part(_trouble, trouble: [
        ('나사산 뜯김', '절삭유 부족, 날 무뎌짐', '절삭유 보충, 다이스 교체'),
      ]),
      _Part(_tidy, steps: [
        '칩·기름 닦고 방청유 얇게',
      ]),
    ],
  ),
  _Guide(
    id: 'rems_amigo',
    group: _Group.cut,
    title: 'REMS 아미고',
    sub: '전동 나사 절삭기 (아미고 1). 지지대로 파이프에 물리고 손에 들고 가공',
    icon: LucideIcons.wrench,
    color: Colors.red.shade700,
    parts: [
      _Part(_spec, rows: [
        ('전동기', '1200 W'),
        ('전원', '230 V 6 A (차단기 10 A)\n110 V 12 A (차단기 20 A)'),
        ('사용률', 'S3 20% (10분 중 2분 가동)'),
        ('회전수', '35~27 rpm (자동 무단 변속)'),
        ('관용 나사', '1/8~1 1/4" (16~40 mm)'),
        ('볼트 나사', '6~30 mm (1/4~1")'),
        ('나사 종류', 'R·NPT 테이퍼, 전선관 M×1.5 (EN 60423)\n평행 나사(G·Pg)·볼트 나사는 버튼 다이 헤드로'),
        ('중량', '본체 3.5 kg, 지지대 1.3 kg, 다이헤드 0.6~0.8 kg'),
        ('크기', '440 × 85 × 195 mm'),
        ('과부하 보호', '있음. 작동하면 몇 초 뒤 버튼 누름'),
        ('아미고 2', '1700 W, 30~18 rpm, 2"까지\n1 1/2"·2" 다이헤드는 리테이닝 링으로 고정, 과부하 버튼 없음'),
      ]),
      _Part(_order, steps: [
        '파이프 직각 절단, 버 제거',
        '다이헤드를 본체 앞쪽 8각 자리에 끼움 (딸깍 걸림). 1 1/4"까지 같은 방식',
        '지지대를 파이프 끝에서 약 10 cm 자리에 아래쪽에서 댐. V죠와 이송 나사 가운데 오게 하고 레버로 꽉 조임',
        '나사 낼 자리에 절삭유 분사',
        '모터가 지지대 두 갈래 사이에 걸리게 본체를 파이프에 씌움',
        '방향 레버: 오른나사는 R, 왼나사는 L',
        '모터 손잡이 잡고 스위치 누르면서 기어 손잡이로 파이프 쪽으로 밀기. 1~2산 물리면 그다음부터 저절로 들어감',
        '가공 중 절삭유 여러 번 보충',
        '테이퍼 나사 표준 길이: 파이프 끝이 다이(날) 윗면과 맞을 때 (커버 윗면 아님)',
        '스위치 놓고 완전히 멈춘 뒤 방향 레버 반대로. 스위치 다시 눌러서 다이헤드 빼냄',
      ], warn: '방향 레버는 완전히 멈춘 뒤에만 바꿀 것',
          tip: '사용률 S3 20%: 10분 중 2분 가동 기준. 나사를 연달아 많이 낼 때는 중간에 쉬어 줄 것'),
      _Part(_safety, rows: [
        ('맞음', '지지대 없이 사용 금지. 토크 걸리면 본체가 손에서 빠져 돎\n이 기계에 맞는 지지대만 사용\n연장 바(522051)와 S형 다이헤드 같이 사용 금지 (지지대 안 맞음)'),
        ('끼임·말림', '가동 중 모터·지지대 쪽에 손 넣기 금지, 모터 손잡이만 잡을 것\n헐렁한 옷·장신구 금지, 회전부에 장갑 닿지 않게'),
        ('감전', '명판 전압 확인\n누전차단기(30 mA) 거친 전원 사용, 비·물기 주의\n릴선 10 m까지 1.5 mm², 10~30 m는 2.5 mm²'),
        ('화재', '스프레이 절삭유는 부탄가스 들어 있음\n햇빛·50 ℃ 넘는 곳 보관 금지, 억지로 따지 말 것'),
        ('피부', '절삭유 피부 장시간 접촉 피함, 보호 크림 또는 장갑'),
        ('자리 비움', '오래 쉴 때 전원 끄고 플러그 분리\n교육받은 사람만 사용'),
        ('짧은 파이프', '짧은 토막은 REMS 니플 고정구(Nippelspanner)로만 물림'),
      ]),
      _Part(_check, rows: [
        ('작업 전', '전원선·릴선 손상 확인, 손상 시 교체 의뢰\n다이 날 상태 확인'),
        ('작업 후', '본체·다이헤드 자리 청소, 칩 제거\n때가 심한 다이헤드는 테레빈유로 닦음'),
        ('세척 주의', '본체 플라스틱은 비눗물 적신 걸레로만, 휘발유·시너 금지\n본체 안에 물·기름 들어가지 않게, 담그기 금지'),
        ('주유', '기어는 그리스 영구 봉입이라 주유 불필요'),
        ('카본 브러시', '소모품. 점검·교체는 REMS 지정 A/S'),
        ('정기', '1년에 1번 이상 A/S 점검 권장'),
      ]),
      _Part('날 교체', steps: [
        '플러그 분리, 다이헤드 8각 쪽을 바이스에 물림',
        '접시머리 나사 풀고 커버 분리',
        '헌 날을 가운데 쪽으로 쳐서 빼냄',
        '새 날은 절삭 시작 쪽(테이퍼 쪽)이 아래로 가게, 번호 맞춰 끼움 (1번 날은 1번 홈 ~ 4번 날은 4번 홈). 몸통 바깥으로 안 나오게',
        '커버 덮고 나사 살짝 조임',
        '구리·황동·단단한 나무 막대로 날을 바깥쪽으로 쳐서 커버 턱에 닿게',
        '나사 꽉 조임',
      ], warn: '날은 한 세트로 교체. 번호 틀리게 끼우면 나사산 뜯김'),
      _Part('절삭유', rows: [
        ('REMS Spezial', '광유계. 강관·SUS·비철·플라스틱 다 됨\n음용수 배관에는 사용 금지'),
        ('REMS Sanitol', '광유 없는 합성유. 음용수 배관용\n빨간색이라 씻겼는지 확인 가능'),
        ('공통', '원액으로만 사용, 희석 금지\n하수구·땅에 버리기 금지, 폐유로 처리'),
      ]),
      _Part(_trouble, trouble: [
        ('힘 없음·과부하 보호 작동', '정품 아닌 다이헤드, 날 마모, 절삭유 부적합, 카본 브러시 마모, 전원선 불량', '정품 다이헤드 사용, 날 교체, REMS 절삭유 사용. 카본·전원선은 A/S'),
        ('나사산 뜯김·나사 안 나옴', '날 마모, 날 번호 틀리게 끼움, 절삭유 부족·희석, 나사 가공 안 되는 파이프 재질', '날 교체, 번호 맞춰 다시 끼움, 절삭유 원액 충분히, 규격 파이프 사용'),
        ('나사 틀어짐', '파이프 직각 절단 안 됨', '직각으로 다시 절단'),
        ('지지대에서 파이프 밀림', '조임 부족, V죠 오염, V죠 이 마모', '더 조임, 와이어 브러시로 청소, 지지대 교체'),
        ('본체가 지지대에 닿음', '지지대를 파이프 끝에 너무 가깝게 물림, 긴 나사를 다시 안 물리고 계속 가공', '파이프 끝에서 약 10 cm에 물림, 지지대 가까워지면 정지 후 다시 물림'),
        ('기동 안 됨', '방향 레버 덜 걸림, 과부하 보호 작동, 카본 브러시 마모, 전원선 불량', '레버 끝까지 걸기, 몇 초 뒤 과부하 버튼 누름. 카본·전원선은 A/S'),
      ]),
      _Part(_tidy, steps: [
        '플러그 분리',
        '다이헤드 빼기 (뒤로 튀어나온 테두리를 평평한 면에 톡 쳐서)',
        '칩·기름 닦고 방청유 얇게',
        '다이헤드는 호칭별 자리에, 지지대와 같이 철제 케이스 보관',
        '바닥 칩·절삭유 청소, 절삭유 통 마개 닫기',
      ]),
    ],
    footer: (c) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _vendorManual(c, 'REMS|Amigo', 'REMS 아미고'),
        const SizedBox(height: 6),
        Text(
          '제조사 설명서는 아미고·아미고 E·아미고 2·컴팩트 묶음이고 여러 나라 말이 들어 있음. 영문 아미고 설명은 66~70쪽',
          style: TextStyle(fontSize: 12.5, height: 1.4, color: refTextSub),
        ),
      ],
    ),
  ),
  _Guide(
    id: 'rems_tiger',
    group: _Group.cut,
    title: 'REMS 타이거 SR (컷쏘)',
    sub: '파이프용 컷쏘. 가이드 홀더 물리면 바이스 없이 직각 절단',
    icon: LucideIcons.scissors,
    color: Colors.red.shade700,
    parts: [
      _Part(_spec, rows: [
        ('전동기', '1400 W'),
        ('전원', '230 V 6.4 A / 110 V 12.8 A'),
        ('중량', '3.0 kg'),
        ('스트로크 속도', '전자식 조절 (SR). 기본형 타이거는 고정'),
        ('가이드 홀더', '2" 홀더 1/8~2", 4" 홀더 2 1/2~4", 6" 홀더 5~6"'),
      ]),
      _Part(_order, steps: [
        '재질 맞는 톱날 선택 (강관·SUS는 고운 날), 끝까지 끼우고 당겨서 체결 확인',
        '호칭 맞는 가이드 홀더 장착, 절단선에 맞춰 파이프에 물림',
        '톱날이 파이프에 안 닿은 상태에서 기동. 천천히 시작해서 날이 먹으면 속도 올림',
        '세게 누르지 말 것. 홀더가 받쳐 줌',
        '톱날 정지 후 빼고 절단면 버 제거',
      ]),
      _Part(_safety, rows: [
        ('폭발·누출', '절단 전 배관 내 잔압·가스·물 확인\n격리·배수·퍼지 끝난 배관만 절단'),
        ('관통', '톱날 끝이 뒤쪽 배관·케이블·벽에 닿지 않게 날 길이 선택'),
        ('맞음', '잘려 나가는 쪽 파이프 받침 또는 결속\n무게로 날이 끼이면 본체가 튐'),
        ('화상·베임', '톱날 교체는 플러그 분리 후\n막 쓴 날은 뜨거움'),
      ]),
      _Part(_check, rows: [
        ('작업 후', '톱날 고정부 쇳가루 제거\n휘거나 이 빠진 날 폐기'),
        ('가이드 홀더', '볼트 풀림, 파이프 접촉면 손상 확인'),
      ]),
      _Part(_trouble, trouble: [
        ('톱날 빠짐', '고정부 쇳가루, 날 삽입 불량', '청소 후 끝까지 다시 삽입'),
        ('톱날 휨·파손', '과도하게 누름, 날 종류 부적합, 홀더 없이 비스듬히 절단', '누르지 말고 홀더 사용, 재질 맞는 날 사용'),
        ('절단면 직각 불량', '홀더 밀착 안 됨, 날 휨', '홀더 밀착, 날 교체'),
        ('절단 속도 느림', '날 마모, 날 이 수 부적합, 스트로크 속도 부적합', '날 교체, 속도 조절'),
        ('진동 심함', '날 고정부·홀더 볼트 풀림', '체결 확인'),
      ]),
      _Part(_tidy, steps: [
        '플러그 분리',
        '톱날 빼서 따로 보관 (끼운 채 케이스에 넣지 않음)',
        '쇳가루 털고 홀더와 같이 케이스 보관',
      ]),
    ],
    footer: (c) => _vendorManual(c, 'REMS|Tiger SR', 'REMS 타이거 SR'),
  ),

  // ───────── 계측 ─────────
  _Guide(
    id: 'meter_loop',
    group: _Group.meter,
    title: '루프 점검 (멀티미터·HART)',
    sub: '4-20 mA 루프 전류 측정, 트랜스미터 확인',
    icon: Icons.electrical_services,
    color: Colors.deepOrange.shade600,
    parts: [
      _Part(_order, steps: [
        '멀티미터 DC mA 레인지, 루프 (+)선 한 곳 풀고 그 사이에 직렬 연결. 병렬로 대면 전압이 측정됨',
        '테스트 단자가 있으면 선 풀지 않고 클립만 연결',
        'HART 커뮤니케이터는 선 안 풀고 mA·PV 바로 확인',
        '시험 압력 올리면서 mA가 레인지대로 따라오는지 확인 (예: 0~10 bar → 4~20 mA)',
      ], tip: '루프 전원·저항 계산은 "계기 교정 → 루프 전압", 포인트별 기록은 "계기 교정 → 교정 점검"'),
      _Part(_safety, rows: [
        ('운전 중 루프', '선 풀면 신호 튀고 경보·인터록 동작 가능\n제어실 통보, 바이패스 승인 후 작업'),
        ('계측기 손상', 'mA 단자에 꽂은 채 전압 측정 금지 (퓨즈 단선)'),
        ('방폭', '방폭 지역은 방폭형 계측기만 사용'),
      ]),
      _Part(_check, rows: [
        ('작업 전', '배터리·mA 퓨즈 확인 (퓨즈 나가면 0 표시)\n테스트 리드 피복·끝단 확인'),
        ('정기', '교정 유효기한 관리 (장비 관리 대장)'),
      ]),
      _Part(_trouble, trouble: [
        ('0 mA 표시', 'mA 퓨즈 단선, 단자 잘못 꽂음, 루프 단선', '퓨즈·단자 확인, 루프 점검'),
        ('값 흔들림', '클립 접촉 불량', '클립 다시 물림'),
        ('(-) 값 표시', '극성 반대', '리드 바꿔 연결'),
        ('HART 통신 안 됨', '루프 저항 부족 (250 Ω 정도 필요), 전원·주소', '저항 확인, 전원·폴링 주소 확인'),
      ]),
      _Part(_tidy, steps: [
        '테스트 리드 전압 단자로 원위치 후 전원 OFF',
        '푼 선 원상 복구, 단자 조임 확인',
        '제어실 통보 후 바이패스 해제, 측정값은 계기 교정 화면에 기록',
      ]),
    ],
  ),
  _Guide(
    id: 'meter_gd402',
    group: _Group.meter,
    title: 'GD402 가스 밀도계 (요꼬가와)',
    sub: '수소 순도 감시. 코드 화면에서 YES·NO로 선택',
    icon: Icons.speed,
    color: Colors.indigo,
    parts: [
      _Part('보정 가스', rows: [
        ('제로 가스', '수소(H2) 100%'),
        ('스팬 가스', '이산화탄소(CO2) 100%'),
      ], warn: '수소 순도계는 수동 보정만 됨. 밀도계·열량계와 순서 다름. 전체 매뉴얼 10장 참고'),
      _Part(_safety, rows: [
        ('폭발', '수소 폭발 범위 4~75% (공기 중)\n화기 엄금, 정전기 주의'),
        ('가스 용기', '용기 전도 방지 체인 고정\n벤트는 안전한 곳으로'),
        ('운전 영향', '샘플 밸브 조작 전 운전원과 협의'),
      ]),
      _Part(_check, rows: [
        ('정기', '정해진 주기로 보정, 결과 기록'),
        ('샘플 라인', '필터 막힘·유량 확인 (전체 매뉴얼 11장)'),
      ]),
      _Part(_trouble, trouble: [
        ('ALM·Err 표시', '', '코드 기록 후 전체 매뉴얼 11장 경보표 확인'),
        ('보정값 안 맞음', '가스 종류·유량 틀림, 보정 방식 혼동', '가스·유량 확인, 수동 보정 순서대로 다시'),
      ]),
      _Part(_tidy, steps: [
        '밸브 운전 위치로 복구',
        '보정 가스 용기 밸브 잠금',
        '보정값·날짜 기록',
      ]),
    ],
    footer: (c) => _manualButton(
      key: const Key('gd402_manual'),
      label: '전체 매뉴얼 보기(설치·배선·보정 세 가지·경보표 전부)',
      color: Colors.indigo,
      onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const Gd402ManualPage())),
    ),
  ),

  // ───────── 실측 ─────────
  _Guide(
    id: 'base_calib',
    group: _Group.base,
    title: '벤더 실측 캘리브레이션',
    sub: '같은 모델도 장비마다 값이 다름. 한 번 실측해서 설정에 입력',
    icon: Icons.straighten_rounded,
    color: Colors.deepPurple,
    parts: [
      _Part('측정 방법', rows: [
        ('테이크업·셋백', '관 끝에서 300~500 mm에 선 긋고 그 선을 0점에 맞춰 90° 벤딩\n관 끝에서 바깥면(등)까지 측정\n테이크업 = 측정 길이 - 선까지 길이'),
        ('게인', '정확한 길이(예: 500 mm) 관 가운데를 90° 벤딩\n교차점에서 양 끝 A, B 측정\n게인 = A + B - 500'),
        ('유압식 램 이동', '90° 벤딩하면서 램 눈금 기록\n45°도 재 두면 중간 각도가 정확해짐'),
        ('시카고 노치', '90°까지 넘어간 노치 칸 수 세기\n노치당 각도 = 90 ÷ 칸 수'),
        ('스프링백', '90° 눈금까지 벤딩 후 풀고 측정\n스프링백 = 90 - 측정 각도'),
      ], tip: '튜브 계산기 "설정"(수동·유압·시카고 제원), 전선관 계산기 "설정"(제조사·재질·규격별)에 입력. 규격마다 따로 저장됨'),
      _Part('측정 시 주의', rows: [
        ('조건', '같은 장비·슈·관 재질·두께로 측정'),
        ('측정', '줄자 0점, 관 끝 직각 확인\n스프링백은 풀고 측정'),
        ('반복', '2~3회 측정해서 편차 확인'),
      ]),
      _Part('재측정 시기', rows: [
        ('슈 교체', '슈·다이 교체 또는 신규 구입 시'),
        ('수리 후', '수리 또는 낙하 후'),
        ('편차 지속', '벤딩 실측 기록에서 한쪽으로 계속 틀어질 때'),
      ]),
      _Part('값 이상 시', trouble: [
        ('테이크업 이상', '화살표·별 기준 혼동, 등 대신 안쪽 면 측정', '기준 표시 확인, 바깥면 기준 재측정'),
        ('게인 이상', '교차점 잘못 잡음', '두 직선 연장선이 만나는 점 기준'),
        ('측정값 편차 큼', '관 밀림, 재질 섞임', '클램프 확인, 같은 자재로 재측정'),
      ]),
    ],
  ),

  // ───────── 공통 ─────────
  _Guide(
    id: 'common_power',
    group: _Group.common,
    title: '전동 공구 공통 수칙',
    sub: '전동 벤더·절단기·아미고·타이거 공통',
    icon: LucideIcons.plug,
    color: Colors.blueGrey,
    parts: [
      _Part(_safety, rows: [
        ('감전', '명판 전압 확인\n접지형 콘센트, 누전차단기 거친 전원 사용\n물기 있는 곳 주의'),
        ('화재', '릴선은 다 풀어서 사용 (감긴 채 쓰면 과열)\n가늘고 긴 릴선은 전압 강하로 힘 빠짐'),
        ('말림', '회전부 앞에서 면장갑 금지, 소매 단속'),
        ('보호구', '보안경, 귀마개'),
      ]),
      _Part(_check, rows: [
        ('작업 전', '전원선 피복 손상, 플러그 핀 휨 확인'),
        ('정기', '통풍구 먼지 에어로 불기 (막히면 과열)\n카본 브러시: 스파크 심하거나 힘 빠지면 마모, 직접 분해 말고 A/S'),
        ('기록', '점검·수리 내역은 장비 관리 대장에 기록'),
      ]),
      _Part(_trouble, trouble: [
        ('기동 안 됨', '콘센트·차단기·릴선, 플러그·스위치 불량', '전원 쪽부터 차례로 확인, 이상 없으면 A/S'),
        ('본체 과열', '장시간 연속 사용, 통풍구 막힘', '쉬면서 냉각, 통풍구 청소'),
        ('탄 냄새·스파크 심함', '모터·카본 이상', '즉시 정지, 플러그 분리. 사용 중지하고 장비 대장 "수리·점검 중"으로 변경'),
      ]),
      _Part(_tidy, steps: [
        '플러그 분리, 전원선 꺾이지 않게 감기',
        '쇳가루·기름 닦고 케이스 보관',
        '장비 대장에 반납 처리, 이상 있으면 기록',
      ]),
    ],
  ),
  _Guide(
    id: 'common_safety',
    group: _Group.common,
    title: '공통 안전 수칙',
    sub: '작업 전 TBM 때 확인',
    icon: LucideIcons.hardHat,
    color: Colors.amber.shade800,
    parts: [
      _Part('매일 확인', rows: [
        ('보호구', '보안경 (절단·연마 필수), 귀마개, 베임 방지 장갑\n회전체 작업 시 면장갑 착용 금지'),
        ('유압', '호스·커플러 누유 확인\n램·슈 사이 손 금지, 핀 끝까지 체결'),
        ('전동 벤더', '비상정지 버튼 위치 확인\n암 회전 반경 안 출입 금지'),
        ('중량물', '긴 자재·중량물은 2인 1조 운반\n형강 탭에서 중량 확인 후 인원 배치'),
        ('화기', '불티 방향 가연물 제거, 소화기 비치'),
        ('통신 불가 구역', '앱은 폰에 먼저 저장되고 통신되면 서버로 올라감\n저장 안 된 것 같아도 다시 누르지 말고 통신되는 곳에서 확인'),
      ]),
    ],
  ),
];

class RefMachineTab extends StatefulWidget {
  const RefMachineTab({super.key});

  @override
  State<RefMachineTab> createState() => _RefMachineTabState();
}

class _RefMachineTabState extends State<RefMachineTab> {
  _Group _group = _Group.all;

  @override
  Widget build(BuildContext context) {
    final list = [for (final g in _guides) if (_group == _Group.all || g.group == _group) g];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        refIntroBadge('장비를 누르면 펼쳐집니다. 제원·작업 순서·안전 수칙·점검·고장 조치·정리정돈을 골라 보십시오. 정비 주기·부품은 제조사 설명서를 따릅니다.'),
        const SizedBox(height: 12),
        refChips(
          items: [for (final g in _Group.values) g.label],
          selected: _group.label,
          onSelected: (v) => setState(() => _group = _Group.values.firstWhere((g) => g.label == v)),
        ),
        const SizedBox(height: 12),
        for (final g in list) ...[
          _GuideTile(key: Key('guide_${g.id}'), guide: g),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _GuideTile extends StatefulWidget {
  final _Guide guide;
  const _GuideTile({super.key, required this.guide});

  @override
  State<_GuideTile> createState() => _GuideTileState();
}

class _GuideTileState extends State<_GuideTile> {
  bool _open = false;
  int _part = 0;

  static final _headStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: refTextMain, height: 1.4);
  static final _bodyStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: refTextSub, height: 1.5);

  @override
  Widget build(BuildContext context) {
    final g = widget.guide;
    final part = g.parts[_part.clamp(0, g.parts.length - 1)];
    return Container(
      decoration: BoxDecoration(color: refWhite, borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('guide_head_${g.id}'),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: g.color.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(g.icon, color: g.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: refTextMain)),
                        const SizedBox(height: 2),
                        Text(g.sub, style: TextStyle(fontSize: 12.5, height: 1.35, color: refTextSub)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(LucideIcons.chevronDown, size: 20, color: refTextSub),
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (g.parts.length > 1)
                    refChips(
                      items: [for (final p in g.parts) p.name],
                      selected: part.name,
                      onSelected: (v) => setState(() => _part = g.parts.indexWhere((p) => p.name == v)),
                    ),
                  const SizedBox(height: 12),
                  ..._partBody(context, part),
                  if (g.footer != null) ...[
                    const SizedBox(height: 14),
                    g.footer!(context),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 줄바꿈으로 나눈 여러 항목은 "· " 머리를 붙인다(한 항목이면 그대로).
  static String _bullets(String body) {
    final lines = body.split('\n');
    return lines.length == 1 ? body : lines.map((l) => '· $l').join('\n');
  }

  List<Widget> _partBody(BuildContext context, _Part p) {
    final out = <Widget>[];
    for (var i = 0; i < p.steps.length; i++) {
      out.add(refStep(i + 1, p.steps[i]));
    }
    // 머리말이 긴 칸은 머리말 위·내용 아래. 옆에 두면 머리말이 두세 줄로 꺾인다.
    final stacked = p.rows.any((r) => r.$1.length > 7);
    for (var i = 0; i < p.rows.length; i++) {
      if (i > 0) out.add(refGap());
      final (head, body) = p.rows[i];
      out.add(stacked ? _stackedRow(head, _bullets(body)) : refDataRow(head, _bullets(body)));
    }
    for (var i = 0; i < p.trouble.length; i++) {
      if (i > 0) out.add(refGap());
      out.add(_troubleRow(p.trouble[i]));
    }
    if (p.extra != null) out.add(p.extra!(context));
    if (p.warn != null) out.addAll([const SizedBox(height: 10), refWarnBox(p.warn!)]);
    if (p.tip != null) out.addAll([const SizedBox(height: 10), refTipBox(p.tip!)]);
    return out;
  }

  Widget _stackedRow(String head, String body) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(head, style: _headStyle),
          const SizedBox(height: 2),
          Text(body, style: _bodyStyle),
        ],
      ),
    );
  }

  /// 고장 조치 한 건: 현상(굵게) 아래 원인·조치.
  Widget _troubleRow((String, String, String) t) {
    final (symptom, cause, fix) = t;
    Widget line(String label, String text) => Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 40, child: Text(label, style: _bodyStyle.copyWith(color: refTeal, fontWeight: FontWeight.w700))),
          Expanded(child: Text(text, style: _bodyStyle)),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(symptom, style: _headStyle),
          if (cause.isNotEmpty) line('원인', cause),
          line('조치', fix),
        ],
      ),
    );
  }
}
