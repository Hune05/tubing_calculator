// 장비 사용법: 장비마다 접힌 줄 하나. 펴면 제원·쓰는 법·주의·정비·고장·정리를 칸으로 골라 본다.
// 내용은 현장에서 흔히 쓰는 요령을 정리한 것이고, 장비별 세부(정비 주기·부품·경보 코드)는 제조사 설명서가 먼저다.
// 전동 공구에 다 해당하는 것(전원·연장선·카본 브러시·서비스센터)은 "전동 공구 공통"에 한 번만 적는다.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../equipment/equipment_manual.dart';
import 'gd402_manual_page.dart';
import 'reference_widgets.dart';

enum _Group {
  all('전체'),
  tube('튜브'),
  conduit('전선관'),
  cut('절단·나사'),
  meter('계측'),
  base('기준 잡기'),
  common('공통');

  final String label;
  const _Group(this.label);
}

/// 한 칸(제원·쓰는 법·주의…). [rows]는 (머리말, 내용), [steps]는 번호 순서(머리말이 비면 내용만).
class _Part {
  final String name;
  final List<(String, String)> rows;
  final List<(String, String)> steps;
  final String? warn;
  final String? tip;
  final Widget Function(BuildContext context)? extra;
  const _Part(this.name, {this.rows = const [], this.steps = const [], this.warn, this.tip, this.extra});
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
    sub: 'Swagelok·Ridgid형. 슈(다이)·롤러·핸들로 꺾는 기본 벤더',
    icon: Icons.handyman_outlined,
    color: Colors.brown,
    parts: [
      _Part('쓰는 법', steps: [
        ('0 마크', '튜브에 그은 마킹선을 슈의 0 눈금에 맞춘다. 계산기 마킹은 이 자리를 기준으로 찍혀 있다.'),
        ('R·L 마크', '관 끝에서 잰 치수면 R, 시작점에서 잰 치수면 L에 맞춘다. 계산기 "마킹 위치(줄자 0점 기준)"는 R 방식이다.'),
        ('롤러 핀', '롤러를 내리고 핀을 끝까지 밀어 넣는다. 덜 들어가면 각도가 모자라고 관이 눌린다.'),
        ('각도', '롤러 0 눈금이 목표 각도를 지나 스프링백(2~3°)만큼 더 가도록 한 번에 지그시 당긴다. 멈췄다 당기면 자국이 남는다.'),
      ]),
      _Part('주의', rows: [
        ('끼임', '롤러와 슈 사이에 손가락을 두지 않는다. 핸들 끝을 잡고 당긴다.'),
        ('규격', '관 바깥지름에 맞는 벤더만 쓴다. 3/8" 벤더에 10 mm 관처럼 비슷한 크기를 넣으면 관이 눌린다.'),
        ('남는 길이', '클램프가 물 만큼 곧은 길이가 있어야 한다. 짧으면 관이 빠지며 손을 친다.'),
        ('힘', '핸들에 파이프를 끼워 늘려 당기지 않는다. 벤더가 휘면 각도가 영영 틀어진다.'),
      ]),
      _Part('정비', rows: [
        ('쓸 때마다', '슈·롤러 홈의 쇳가루·모래를 닦는다. 홈의 흠은 관에 그대로 찍힌다.'),
        ('피벗·핀', '피벗 유격, 롤러 핀 휨을 본다. 피벗에만 기름 한 방울, 홈에는 바르지 않는다.'),
      ]),
      _Part('고장', rows: [
        ('관이 납작하다·주름', '규격이 다른 슈, 롤러 핀 덜 들어감, 관 두께가 너무 얇음.'),
        ('각도가 모자라다', '스프링백만큼 더 당기지 않았다. 롤러 핀이 덜 들어갔다.'),
        ('긁힌 자국', '홈에 이물이나 흠. 닦고, 흠이면 슈를 바꾼다.'),
        ('길이가 어긋난다', '0·R·L 마크 혼동, 설정의 게인이 이 벤더 값이 아님("기준 잡기").'),
      ]),
      _Part('정리', steps: [
        ('', '홈의 쇳가루를 닦는다.'),
        ('', '롤러·핀을 제자리에 끼워 둔다.'),
        ('', '규격별로 케이스에 넣는다. 떨어뜨리면 슈가 틀어진다.'),
      ]),
    ],
  ),
  _Guide(
    id: 'tube_msbtb',
    group: _Group.tube,
    title: 'Swagelok 전동 벤더 (MS-BTB)',
    sub: '펜던트로 각도를 넣는 단일 벤딩용',
    icon: Icons.precision_manufacturing,
    color: Colors.orange.shade800,
    parts: [
      _Part('쓰는 법', steps: [
        ('[ANGLE]·[SPRINGBACK]', '목표 각도와 스프링백을 넣는다. 설정에 넣어 둔 스프링백 값과 같게.'),
        ('토글 클램프', '마킹선을 0점에 맞추고 레버를 끝까지 민다. 덜 물리면 관이 밀려 마킹이 어긋난다.'),
        ('[BEND]', '끝날 때까지 누르고 있는다. 손을 떼면 멈춘다. 끝나면 [RETURN]으로 암을 되돌린 뒤 클램프를 푼다.'),
      ]),
      _Part('주의', rows: [
        ('비상 정지', '켜기 전에 비상 정지 자리를 먼저 본다.'),
        ('도는 반경', '암이 도는 자리와 관 뒤쪽이 휘두르는 자리에 사람·자재가 없게.'),
        ('펜던트 선', '밟거나 꺾지 않는다.'),
      ]),
      _Part('정비', rows: [
        ('쓸 때마다', '다이·롤러·클램프 블록 홈을 닦는다. 클램프 블록이 닳으면 관이 미끄러진다.'),
        ('각도 확인', '가끔 시험 벤딩해 각도기로 90°를 잰다. 틀리면 스프링백 값을 고친다.'),
      ]),
      _Part('고장', rows: [
        ('안 움직인다', '전원 → 비상 정지 풀림 → 암이 원위치인지([RETURN] 먼저).'),
        ('각도가 매번 다르다', '클램프 덜 물림, 스프링백 값, 관 재질·두께가 바뀜.'),
        ('관이 미끄러진다', '클램프 블록 마모·기름. 닦거나 바꾼다.'),
      ]),
      _Part('정리', steps: [
        ('', '[RETURN]으로 암을 원위치에 둔다.'),
        ('', '전원을 끄고 플러그를 뽑는다.'),
        ('', '다이를 빼서 닦아 규격별로 넣는다. 펜던트 선은 느슨히 감는다.'),
      ]),
    ],
  ),
  _Guide(
    id: 'tube_tb20d',
    group: _Group.tube,
    title: 'TRACTO-TECHNIK TB20D (NC 벤더)',
    sub: '제어반에 순서를 넣고 풋 페달로 연속 작업',
    icon: LucideIcons.monitorSmartphone,
    color: Colors.indigo,
    parts: [
      _Part('쓰는 법', steps: [
        ('원점 복귀 [HOME]·[REF]', '전원을 켜면 먼저 암을 0°로. 건너뛰면 엉뚱한 각으로 꺾여 충돌한다.'),
        ('프로그램 [PROG]', '새 번호를 열고 Step 1부터 각도와 스프링백(Korr)을 차례로 넣는다. 계산기 "마킹 가이드"의 벤드 순서와 같게.'),
        ('스토퍼·클램프', '관을 뒤쪽 스토퍼(길이·회전)에 붙이고 [CLAMP]나 페달 1단으로 물린다.'),
        ('[AUTO] + 페달', '끝까지 밟으면 그 Step 각도까지 꺾고 멈춘다. 풀고 다음 마킹까지 밀고 다시 밟는다.'),
      ], warn: '화면의 지금 Step 번호를 늘 본다. 순서가 꼬이면 90° 자리에 45°가 들어가 관을 버린다.'),
      _Part('금형·연신율', extra: (_) => refTable(
        headers: const ['규격', '표준 금형 CLR', '권장 연신율'],
        rows: const [
          ['1/4" (6.35)', 'R15.0', '7.0~8.0'],
          ['3/8" (9.52)', 'R22.5', '11.0~12.5'],
          ['1/2" (12.7)', 'R35.0', '18.0~20.0'],
          ['3/4" (19.05)', 'R50.0', '26.0~28.0'],
        ],
        footer: '※ SUS 기준. 금형 CLR이 수동 벤더(R14.3/23.8/38.1)와 다르니 설정의 반경을 이 장비 값으로 바꾸고 마킹한다.',
      )),
      _Part('주의', rows: [
        ('휘두르는 관', '긴 관은 꺾일 때 뒤쪽이 크게 돈다. 그 반경 안에서 사람을 비킨다.'),
        ('페달', '한 번 끝까지 밟고 발을 뗀다. 두 번 밟으면 다음 Step이 바로 돈다.'),
        ('금형 바꾸기', '전원을 끄고 바꾼다.'),
      ]),
      _Part('정비', rows: [
        ('쓸 때마다', '금형·클램프 다이 홈을 닦는다.'),
        ('각도·길이 확인', '가끔 시험 벤딩으로 잰다. 틀리면 Korr·연신율 값을 고친다.'),
        ('화면 경보', '코드를 적어 둔다. 같은 경보가 되풀이되면 서비스센터.'),
      ]),
      _Part('고장', rows: [
        ('원점 복귀가 안 된다', '걸린 것을 치우고 다시. 그래도 안 되면 센서 문제.'),
        ('각도가 틀리다', 'Korr 값, 관 재질 바뀜, 클램프 덜 물림.'),
        ('길이가 틀리다', '연신율 값이 금형·관과 안 맞다("금형·연신율" 칸).'),
        ('화면에 경보', '코드를 적고 제조사 설명서의 경보표를 본다.'),
      ]),
      _Part('정리', steps: [
        ('', '원점 복귀 뒤 전원을 끈다.'),
        ('', '금형을 빼서 닦아 둔다.'),
        ('', '쓴 프로그램 번호를 일지에 적어 둔다.'),
      ]),
    ],
  ),
  _Guide(
    id: 'tube_cutter',
    group: _Group.tube,
    title: '튜브 커터 · 디버링',
    sub: '튜브는 톱이 아니라 커터로 자른다',
    icon: LucideIcons.scissors,
    color: Colors.teal,
    parts: [
      _Part('쓰는 법', steps: [
        ('', '마킹선에 날을 맞추고 가볍게 조여 한 바퀴 돌린다.'),
        ('', '돌릴 때마다 손잡이를 1/4바퀴씩만 조인다. 세게 조이면 관 끝이 안으로 말린다.'),
        ('', '잘린 면 안팎의 버를 깎는다. 안쪽 버는 유량을 막고, 바깥 버는 페룰 자리를 긁는다.'),
        ('', '끝면이 직각인지 본다. 비스듬하면 피팅 턱에 안 닿아 샌다.'),
      ]),
      _Part('주의', rows: [
        ('날', '커터·디버링 날과 스테인리스 버에 손이 베인다.'),
      ]),
      _Part('정비', rows: [
        ('날', '이가 빠진 날은 바꾼다. 여분 날을 같이 둔다.'),
        ('롤러', '롤러가 부드럽게 도는지 본다.'),
      ]),
      _Part('고장', rows: [
        ('관 끝이 안으로 말린다', '너무 세게 조였다.'),
        ('나선으로 돈다', '첫 바퀴를 세게 조였거나 날·롤러가 닳았다.'),
        ('버가 크다', '날이 무디다.'),
      ]),
      _Part('정리', steps: [
        ('', '쇳가루를 털고 날을 보호해 공구함에 넣는다.'),
      ]),
    ],
  ),

  // ───────── 전선관 ─────────
  _Guide(
    id: 'conduit_hand',
    group: _Group.conduit,
    title: '전선관 수동 벤더 (히키)',
    sub: 'Greenlee·Ideal형. 발로 밟아 꺾는다. 슈에 화살표·별·림 표시',
    icon: LucideIcons.wrench,
    color: Colors.brown,
    parts: [
      _Part('쓰는 법', steps: [
        ('화살표', '마킹선을 화살표에 맞춘다. 계산기 마킹은 테이크업을 이미 뺀 화살표 자리다.'),
        ('별', '두 번째 90°를 관 끝 쪽에서 재서 꺾을 때(백투백) 별에 맞춘다.'),
        ('림 표시', '3벤드 새들의 가운데(45°)를 림 홈에, 양옆 22.5°는 화살표에.'),
        ('꺾기', '발판을 밟으며 핸들을 당긴다. 목표 각도 + 스프링백(후강 3~5°)까지.'),
        ('오프셋', '첫 벤드 뒤 관을 슈 안에서 180° 돌려 두 번째 마킹을 맞춘다. 관에 그은 세로선이 슈 가운데와 나란한지 본다.'),
      ]),
      _Part('주의', rows: [
        ('발판', '확실히 밟는다. 발이 빠지면 관이 튀어 얼굴로 온다.'),
        ('바닥', '미끄럽거나 기운 곳에서 하지 않는다.'),
        ('무리', '굵은 관은 유압식으로. 핸들에 파이프를 끼워 늘리지 않는다.'),
      ]),
      _Part('정비', rows: [
        ('쓸 때마다', '슈 홈의 흙·쇳가루를 턴다.'),
        ('표시', '화살표·별·림 표시가 지워졌으면 다시 새긴다.'),
      ]),
      _Part('고장', rows: [
        ('개 다리', '두 번째 벤드 때 관이 돌았다. 세로선을 맞춘다.'),
        ('각도가 모자라다', '스프링백만큼 더 꺾지 않았다.'),
        ('관이 납작하다', '규격이 다른 슈, EMT용 슈에 후강.'),
        ('길이가 틀리다', '화살표·별 혼동, 테이크업이 이 벤더 값이 아님.'),
      ]),
      _Part('정리', steps: [
        ('', '홈을 털고, 녹 막이 기름은 바깥에만 얇게.'),
        ('', '손잡이를 빼서 크기별로 같이 둔다.'),
      ]),
    ],
  ),
  _Guide(
    id: 'conduit_hyd',
    group: _Group.conduit,
    title: '유압식 벤더',
    sub: 'Greenlee·Current Tools형. 슈를 갈아 끼우고 램으로 민다',
    icon: Icons.precision_manufacturing,
    color: Colors.indigo,
    parts: [
      _Part('쓰는 법', steps: [
        ('슈·받침', '관 호칭과 같은 슈를 램에, 받침 롤러는 그 호칭 구멍에 핀으로 꽂는다. 핀이 끝까지 안 들어가면 밀지 않는다.'),
        ('셋백 마크', '계산기 마킹(셋백 뺀 자리)을 슈 가운데 표시에 맞춘다.'),
        ('펌프·램', '밸브를 잠그고 펌프질. 램 눈금이 설정의 "램 이동 거리"까지 나오면 멈추고 각도기로 잰다.'),
        ('되돌리기', '릴리스 밸브를 천천히 연다. 갑자기 열면 슈가 튄다.'),
      ]),
      _Part('주의', rows: [
        ('서는 자리', '램 앞, 슈와 받침 사이에 손·발을 두지 않는다.'),
        ('핀', '반쯤 꽂힌 채 밀면 핀이 총알처럼 튄다.'),
        ('호스', '꺾이거나 새는 호스·커플러는 쓰지 않는다. 압력 걸린 채 커플러를 빼지 않는다.'),
        ('압력', '펌프 정격을 넘기지 않는다. 안 꺾이면 슈·관 규격부터 본다.'),
      ]),
      _Part('정비', rows: [
        ('쓸 때마다', '호스·커플러·램 씰의 기름 샘을 보고 램을 닦는다.'),
        ('오일', '오일량을 본다. 모자라면 설명서의 오일로.'),
        ('공기', '램이 출렁이거나 느리면 공기가 찼다. 설명서 순서로 뺀다.'),
      ]),
      _Part('고장', rows: [
        ('램이 안 나간다', '릴리스 밸브 열림, 오일 부족, 커플러 덜 꽂힘.'),
        ('램이 저절로 들어간다', '릴리스 밸브 덜 잠김, 씰 누유.'),
        ('느리다·출렁인다', '오일 부족, 공기.'),
        ('관이 찌그러진다', '슈·받침 규격이나 받침 구멍이 다르다.'),
        ('기름이 샌다', '쓰지 말고 씰 교체를 맡긴다. 장비 대장에서 "수리·점검 중".'),
      ]),
      _Part('정리', steps: [
        ('', '램을 끝까지 넣어 압력을 뺀다.'),
        ('', '커플러에 먼지 덮개, 호스는 크게 감는다.'),
        ('', '슈·받침·핀을 닦아 규격별로. 흘린 오일은 닦는다.'),
      ]),
    ],
  ),
  _Guide(
    id: 'conduit_chicago',
    group: _Group.conduit,
    title: '시카고식 벤더',
    sub: '기어·크랭크로 슈를 돌려 꺾는다. 굵은 후강용',
    icon: LucideIcons.cog,
    color: Colors.deepOrange,
    parts: [
      _Part('쓰는 법', steps: [
        ('롤러·슈', '관 호칭에 맞는 롤러(설정의 "롤러 규격")와 슈 홈에 관을 넣고 훅으로 꽉 누른다.'),
        ('0점', '노치 휠을 0에 두고 마킹선(테이크업 뺀 자리)을 슈 표시에 맞춘다.'),
        ('크랭크', '돌리며 노치 칸을 센다. 칸 수 = 목표 각도 ÷ 노치당 각도(설정값). 스프링백만큼 한두 칸 더.'),
        ('되돌리기', '래칫을 풀고 크랭크를 되돌린다. 관을 빼기 전에 훅을 먼저 푼다.'),
      ]),
      _Part('주의', rows: [
        ('반동', '래칫을 풀 때 크랭크가 되돌아 돈다. 손잡이를 잡고 푼다.'),
        ('기어', '도는 기어·노치 휠에 손가락을 두지 않는다.'),
        ('고정', '프레임이 넘어지지 않게 고정하거나 받친다. 무거운 관은 끝을 받친다.'),
      ]),
      _Part('정비', rows: [
        ('쓸 때마다', '기어·래칫의 쇳가루를 턴다.'),
        ('기름', '기어·축에 설명서의 그리스. 홈에는 바르지 않는다.'),
        ('훅·롤러', '훅이 꽉 누르는지, 홈이 닳지 않았는지.'),
      ]),
      _Part('고장', rows: [
        ('래칫이 헛돈다', '이물이 끼었거나 스프링이 약하다.'),
        ('각도가 틀리다', '노치당 각도 설정이 이 벤더 값이 아님, 스프링백.'),
        ('관이 미끄러진다', '훅이 덜 눌렀다.'),
        ('뻑뻑하다', '그리스가 말랐다.'),
      ]),
      _Part('정리', steps: [
        ('', '훅을 풀고 크랭크를 0으로.'),
        ('', '쇳가루를 털고 크랭크를 빼서 같이 둔다.'),
      ]),
    ],
  ),

  // ───────── 절단·나사 ─────────
  _Guide(
    id: 'cut_chop',
    group: _Group.cut,
    title: '고속절단기',
    sub: '숫돌로 형강·전선관을 자른다',
    icon: LucideIcons.zap,
    color: Colors.redAccent,
    parts: [
      _Part('쓰는 법', steps: [
        ('', '숫돌 두께(2.5~3 mm)를 형강·튜브 컷팅 화면의 "톱날 손실"에 넣는다.'),
        ('', '재단 계획 순서대로 긴 조각부터. 자재를 바이스에 꽉 물린다.'),
        ('', '숫돌을 자재에 댄 채 켜지 않는다. 회전이 다 오른 뒤 천천히 내린다.'),
      ]),
      _Part('주의', rows: [
        ('숫돌', '금·이 빠짐이 있으면 쓰지 않는다. 숫돌 최고 회전수가 기계보다 높은지 본다. 덮개를 떼지 않는다.'),
        ('불꽃', '불꽃 방향에 배관·케이블·유류가 없게. 소화기 위치를 본다.'),
        ('짧은 조각', '손으로 잡고 자르지 않는다. 바이스에 문다.'),
      ]),
      _Part('정비', rows: [
        ('숫돌', '닳아 작아지면 바꾼다. 습기 없는 곳에 둔다.'),
        ('바이스', '나사의 쇳가루를 턴다.'),
      ]),
      _Part('고장', rows: [
        ('비스듬히 잘린다', '바이스 각도가 틀어졌다.'),
        ('숫돌이 떨린다', '바로 멈춘다. 고정 너트·숫돌 금을 본다. 금이면 버린다.'),
      ]),
      _Part('정리', steps: [
        ('', '플러그를 뽑는다.'),
        ('', '쇳가루·불꽃 찌꺼기를 치운다(불씨가 남는다).'),
        ('', '남은 잔재는 규격을 적어 잔재 목록에 올린다.'),
      ]),
    ],
  ),
  _Guide(
    id: 'cut_band',
    group: _Group.cut,
    title: '밴드쏘',
    sub: '띠톱으로 형강·관을 자른다',
    icon: LucideIcons.zap,
    color: Colors.redAccent,
    parts: [
      _Part('쓰는 법', steps: [
        ('', '날 두께(1.3~1.6 mm)를 "톱날 손실"에 넣는다.'),
        ('', '자재를 바이스에 물리고 날 장력·가이드를 맞춘 뒤 켠다.'),
        ('', '자재를 밀지 않는다. 날 무게로 내려가게 두고 후강·H형강은 속도를 낮춘다.'),
      ]),
      _Part('주의', rows: [
        ('손', '날이 도는 동안 자재를 손으로 밀거나 잡지 않는다.'),
        ('날 바꾸기', '플러그를 뽑고, 장갑을 끼고 바꾼다.'),
      ]),
      _Part('정비', rows: [
        ('날', '장력·가이드·이 빠짐을 본다.'),
        ('절삭유', '양을 본다.'),
      ]),
      _Part('고장', rows: [
        ('비스듬히 잘린다', '날 가이드·장력.'),
        ('날이 자주 끊긴다', '장력 과다, 너무 빨리 내림, 날 이 수가 재질과 안 맞음.'),
      ]),
      _Part('정리', steps: [
        ('', '쇳가루를 치운다.'),
        ('', '오래 안 쓸 때는 날 장력을 풀어 둔다.'),
      ]),
    ],
  ),
  _Guide(
    id: 'cut_thread',
    group: _Group.cut,
    title: '전선관 나사 (수동 다이스)',
    sub: '손으로 돌려 나사를 낸다',
    icon: LucideIcons.wrench,
    color: Colors.blueGrey,
    parts: [
      _Part('쓰는 법', steps: [
        ('', '관 끝을 직각으로 자르고 버를 깎는다.'),
        ('', '절삭유를 치고 1/4바퀴씩 되돌리며 낸다.'),
        ('', '나사 길이 = 커플링 길이의 절반 + 1~2산.'),
      ]),
      _Part('주의', rows: [
        ('칩', '나사 칩은 날카롭다. 솔로 턴다.'),
      ]),
      _Part('정비', rows: [
        ('다이스 날', '이 빠짐을 보고 칩을 턴다.'),
      ]),
      _Part('고장', rows: [
        ('나사가 뜯긴다', '절삭유 부족, 날이 무디다.'),
      ]),
      _Part('정리', steps: [
        ('', '칩·기름을 닦고 녹 막이 기름을 얇게 바른다.'),
      ]),
    ],
  ),
  _Guide(
    id: 'rems_amigo',
    group: _Group.cut,
    title: 'REMS 아미고 2',
    sub: '전동 나사 절삭기. 바이스 없이 받침대로 관에 물려 나사를 낸다',
    icon: LucideIcons.wrench,
    color: Colors.red.shade700,
    parts: [
      _Part('제원', rows: [
        ('전동기', '1700 W'),
        ('회전수', '30~18 rpm (나사 낼 때)'),
        ('무게', '본체 6.5 kg (다이 헤드 빼고)'),
        ('나사 범위', '관용 1/8~2" (16~50 mm), 볼트 6~30 mm (1/4~1")'),
        ('큰 관', '4" 자동 다이 헤드로 2 1/2~4"'),
        ('구성', '본체, 크기별 다이 헤드, 받침대(서포트 브래킷), 공구함'),
      ]),
      _Part('쓰는 법', steps: [
        ('', '관 끝을 직각으로 자르고 안쪽 버를 깎는다.'),
        ('', '관 크기 다이 헤드를 본체에 끝까지 끼운다.'),
        ('', '받침대를 관에 물리고 다이 헤드를 관 끝에 직각으로 댄다.'),
        ('', '절삭유를 치며 나사를 낸다. 관 끝이 다이 헤드 앞면에 오면 멈춘다.'),
        ('', '멈춘 뒤 방향을 바꿔 다이 헤드를 빼낸다.'),
      ]),
      _Part('주의', rows: [
        ('받침대', '받침대 없이 손으로만 잡고 켜지 않는다. 본체가 돌며 손목을 친다.'),
        ('회전부', '도는 다이 헤드에 장갑·소매가 닿지 않게. 보안경.'),
        ('방향 바꾸기', '완전히 멈춘 뒤에 바꾼다.'),
        ('절삭유', '먹는 물 관은 먹는 물용. 바닥에 흘린 기름은 바로 닦는다.'),
      ]),
      _Part('정비', rows: [
        ('쓸 때마다', '다이 헤드 칩·기름때를 털고 날(체이서) 이를 본다.'),
        ('날 바꾸기', '한 세트를 같이 바꾼다. 하나만 바꾸면 나사가 비뚤어진다.'),
      ]),
      _Part('고장', rows: [
        ('나사가 뜯긴다', '절삭유 부족, 날이 무디다, 관 끝이 비스듬하다. 스테인리스는 전용 날.'),
        ('나사가 비뚤다', '처음 댈 때 직각이 아니었다. 받침대 자리를 다시 잡는다.'),
        ('힘이 약하다·멈춘다', '연장선이 가늘고 길다, 날이 무디다, 카본 브러시("전동 공구 공통").'),
        ('다이 헤드가 안 들어간다·안 빠진다', '자리에 칩이 끼었다. 플러그를 뽑고 청소.'),
      ]),
      _Part('정리', steps: [
        ('', '플러그를 뽑는다.'),
        ('', '다이 헤드를 빼서 닦고 녹 막이 기름을 얇게.'),
        ('', '다이 헤드는 크기별 자리에, 받침대와 같이 공구함에. 절삭유 통을 닫는다.'),
        ('', '바닥의 칩·기름을 치운다.'),
      ]),
    ],
    footer: (c) => _vendorManual(c, 'REMS|Amigo 2', 'REMS 아미고 2'),
  ),
  _Guide(
    id: 'rems_tiger',
    group: _Group.cut,
    title: 'REMS 타이거 SR (컷쏘)',
    sub: '파이프용 컷쏘. 가이드 홀더를 관에 대면 바이스 없이 직각으로 자른다',
    icon: LucideIcons.scissors,
    color: Colors.red.shade700,
    parts: [
      _Part('제원', rows: [
        ('전동기', '1400 W'),
        ('전원', '230 V 6.4 A / 110 V 12.8 A'),
        ('무게', '3.0 kg'),
        ('행정 속도', '전자식 조절(SR). 기본형 타이거는 고정'),
        ('가이드 홀더', '2" 홀더 1/8~2", 4" 홀더 2 1/2~4", 6" 홀더 5~6"'),
      ]),
      _Part('쓰는 법', steps: [
        ('', '관 재질에 맞는 날을 고른다(강관·스테인리스는 고운 날). 끝까지 끼우고 당겨 본다.'),
        ('', '관 크기 가이드 홀더를 달고 절단선에 맞춰 관에 댄다.'),
        ('', '날이 관에 닿지 않게 두고 켠다. 천천히 내리고, 들어가면 속도를 올린다.'),
        ('', '세게 누르지 않는다. 홀더가 힘을 받아 준다.'),
        ('', '날이 멈춘 뒤 빼고 버를 깎는다.'),
      ]),
      _Part('주의', rows: [
        ('자를 관', '안에 압력·가스·물이 남았는지 먼저. 격리·배수·퍼지가 끝난 관만.'),
        ('날 뒤쪽', '날 끝이 뒤의 배관·케이블·벽에 닿지 않게 날 길이를 고른다.'),
        ('잘린 쪽', '떨어지지 않게 받친다. 무게에 날이 끼면 튄다.'),
        ('날 바꾸기', '플러그를 뽑고. 막 쓴 날은 뜨겁다.'),
      ]),
      _Part('정비', rows: [
        ('쓸 때마다', '날 고정부의 쇳가루를 턴다. 휘거나 이 빠진 날은 버린다.'),
        ('가이드 홀더', '볼트 풀림, 관에 닿는 면을 본다.'),
      ]),
      _Part('고장', rows: [
        ('날이 자꾸 빠진다', '고정부에 쇳가루, 날을 끝까지 안 끼웠다.'),
        ('날이 휜다·부러진다', '세게 눌렀다, 날 종류가 안 맞다, 홀더 없이 비스듬히.'),
        ('잘린 면이 비뚤다', '홀더를 붙이지 않았거나 날이 휘었다.'),
        ('잘 안 잘린다', '날이 무디다, 이가 재질과 안 맞다, 속도가 안 맞다.'),
        ('떨림이 크다', '날·홀더 볼트가 풀렸다.'),
      ]),
      _Part('정리', steps: [
        ('', '플러그를 뽑는다.'),
        ('', '날을 빼서 따로 둔다(끼운 채 넣지 않는다).'),
        ('', '쇳가루를 털고 홀더와 같이 케이스에.'),
      ]),
    ],
    footer: (c) => _vendorManual(c, 'REMS|Tiger SR', 'REMS 타이거 SR'),
  ),

  // ───────── 계측 ─────────
  _Guide(
    id: 'meter_loop',
    group: _Group.meter,
    title: '멀티미터·HART로 4-20mA 루프 확인',
    sub: '전송기는 표시창에 압력, 루프 전류는 멀티미터로',
    icon: Icons.electrical_services,
    color: Colors.deepOrange.shade600,
    parts: [
      _Part('쓰는 법', steps: [
        ('', '멀티미터를 DC mA로 두고 루프 +선 한 곳을 끊어 그 사이에 직렬로 문다. 두 선에 나란히 대면 전압을 재게 된다.'),
        ('', '시험 단자대가 있으면 선을 끊지 않고 클립만 꽂는다.'),
        ('', 'HART 통신기가 있으면 끊지 않고 mA·압력을 바로 읽는다.'),
        ('', '시험 압력을 올리며 mA가 그 압력에 맞게(예: 0~10 bar → 4~20 mA) 따라오는지 본다.'),
      ], tip: '루프 전원·저항 계산은 "계기 교정 → 루프 전압", 점별 기록은 "계기 교정 → 교정 점검".'),
      _Part('주의', rows: [
        ('살아있는 루프', '끊는 순간 신호가 튀거나 경보가 뜬다. 제어실에 알리거나 bypass 해 두고 한다.'),
        ('단자', 'mA 단자에 꽂은 채 전압을 재지 않는다. 퓨즈가 나간다.'),
        ('방폭', '방폭 구역에서는 방폭 인증 계기만.'),
      ]),
      _Part('정비', rows: [
        ('배터리·퓨즈', 'mA 퓨즈가 나가면 0으로 나온다.'),
        ('리드선', '피복·끝이 헐거우면 바꾼다.'),
        ('교정 기한', '장비 관리 대장에 올려 둔다.'),
      ]),
      _Part('고장', rows: [
        ('mA가 0이다', '퓨즈, mA 단자 아님, 루프 끊김.'),
        ('값이 튄다', '클립 접촉 불량.'),
        ('마이너스다', '극성이 반대.'),
        ('HART 응답 없음', '루프에 250 Ω쯤 저항이 있어야 통신된다. 전원·저항·주소.'),
      ]),
      _Part('정리', steps: [
        ('', '리드선을 전압 단자로 돌려 꽂고 끈다.'),
        ('', '끊은 선을 원래대로 물리고 조임을 본다.'),
        ('', '제어실에 알리고 bypass를 푼다. 잰 값은 계기 교정 화면에 기록.'),
      ]),
    ],
  ),
  _Guide(
    id: 'meter_gd402',
    group: _Group.meter,
    title: 'GD402 가스 밀도계 (요꼬가와)',
    sub: '수소 순도 모니터. 화면 코드를 보고 YES·NO로 고른다',
    icon: Icons.speed,
    color: Colors.indigo,
    parts: [
      _Part('보정 가스', rows: [
        ('제로가스', '수소(H2) 100%'),
        ('스팬가스', '이산화탄소(CO2) 100%'),
      ], warn: '수소순도계는 수동 보정만 있다. 밀도계·열량계와 순서가 다르니 전체 매뉴얼 10장을 본다.'),
      _Part('주의', rows: [
        ('수소', '공기 중 4~75%에서 터진다. 화기 금지, 정전기 주의.'),
        ('가스 용기', '넘어지지 않게 묶고, 배기는 안전한 곳으로.'),
        ('밸브', '샘플 쪽 밸브를 바꾸기 전에 운전원과 맞춘다.'),
      ]),
      _Part('정비', rows: [
        ('정기 보정', '정한 주기로 보정하고 결과를 적는다.'),
        ('샘플 계통', '필터 막힘·유량. 자세한 건 전체 매뉴얼 11장.'),
      ]),
      _Part('고장', rows: [
        ('ALM·Err', '코드를 적고 전체 매뉴얼 11장 경보표를 본다.'),
        ('보정이 안 맞는다', '가스 종류·유량, 보정 방식(수동)을 다시 본다.'),
      ]),
      _Part('정리', steps: [
        ('', '밸브를 운전 위치로.'),
        ('', '보정 가스 용기 밸브를 잠근다.'),
        ('', '보정 값과 날짜를 기록한다.'),
      ]),
    ],
    footer: (c) => _manualButton(
      key: const Key('gd402_manual'),
      label: '전체 매뉴얼 보기(설치·배선·보정 세 가지·경보표 전부)',
      color: Colors.indigo,
      onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const Gd402ManualPage())),
    ),
  ),

  // ───────── 기준 잡기 ─────────
  _Guide(
    id: 'base_calib',
    group: _Group.base,
    title: '내 장비 실측 캘리브레이션',
    sub: '제원표는 기계마다 다르다. 한 번 재서 설정에 넣으면 그 뒤로는 자동',
    icon: Icons.straighten_rounded,
    color: Colors.deepPurple,
    parts: [
      _Part('재는 법', steps: [
        ('테이크업·셋백', '관 끝에서 300~500 mm 자리에 선을 긋고, 그 선을 0점에 맞춰 90°로 꺾는다. 관 끝에서 바깥면(등)까지 잰다. 테이크업 = 잰 길이 − 선까지 길이.'),
        ('게인', '정확한 길이(예 500 mm)의 관 가운데를 90°로 꺾고 교차점에서 양 끝(A, B)을 잰다. 게인 = A + B − 500.'),
        ('유압식 램 이동', '90°로 꺾으며 램 눈금을 적는다. 45°도 재 두면 사이 각도가 정확해진다.'),
        ('시카고식 노치', '90°까지 넘어간 노치 칸을 센다. 노치당 각도 = 90 ÷ 칸 수.'),
        ('스프링백', '90° 눈금까지 꺾고 풀어 잰다. 90 − 잰 각 = 스프링백.'),
      ], tip: '튜브 계산기 "설정"(수동·유압·시카고 제원), 전선관 계산기 "설정"(제조사·재질·규격별)에 넣는다. 규격마다 따로 저장된다.'),
      _Part('주의', rows: [
        ('같은 조건', '같은 장비·슈·관 재질·두께로 잰다.'),
        ('재는 법', '줄자 0점 확인, 관 끝 직각. 스프링백은 풀고 잰다.'),
        ('여러 번', '두세 번 재서 비슷한지 본다.'),
      ]),
      _Part('다시 잴 때', rows: [
        ('슈를 바꿨을 때', '슈·다이를 바꾸거나 새로 샀으면.'),
        ('수리 뒤', '고쳤거나 떨어뜨렸으면.'),
        ('차이가 계속 날 때', '벤딩 실측 기록에서 차이가 늘 한쪽으로 나면.'),
      ]),
      _Part('값이 이상할 때', rows: [
        ('테이크업이 이상하다', '0점(화살표·별) 혼동, 등이 아니라 안쪽 면을 쟀다.'),
        ('게인이 이상하다', '교차점을 잘못 잡았다. 두 직선을 연장해 만나는 점.'),
        ('잴 때마다 다르다', '관이 미끄러졌다, 재질이 섞였다.'),
      ]),
    ],
  ),

  // ───────── 공통 ─────────
  _Guide(
    id: 'common_power',
    group: _Group.common,
    title: '전동 공구 공통',
    sub: '전동 벤더·절단기·아미고·타이거에 다 해당하는 것',
    icon: LucideIcons.plug,
    color: Colors.blueGrey,
    parts: [
      _Part('주의', rows: [
        ('전원', '명판 전압 확인. 접지된 콘센트, 젖은 곳은 누전차단기 달린 전원.'),
        ('연장선', '굵은 것을 쓰고 감긴 채로 쓰지 않는다(뜨거워진다). 가늘고 길면 힘이 빠진다.'),
        ('보호구', '보안경·귀마개. 도는 부분 앞에서 면장갑·소매는 말려 들어간다.'),
      ]),
      _Part('정비', rows: [
        ('전원선·플러그', '피복 벗겨짐, 플러그 핀 휨을 본다.'),
        ('통풍구', '먼지를 바람으로 불어 낸다. 막히면 뜨거워진다.'),
        ('카본 브러시', '불꽃이 많거나 힘이 빠지면 닳은 것. 직접 열지 말고 서비스센터.'),
        ('기록', '점검·수리는 장비 관리 대장에 남긴다.'),
      ]),
      _Part('고장', rows: [
        ('안 켜진다', '콘센트·차단기·연장선 → 플러그·스위치 → 서비스센터.'),
        ('본체가 뜨겁다', '오래 연달아 썼거나 통풍구가 막혔다. 쉬어 식힌다.'),
        ('타는 냄새·큰 불꽃', '바로 끄고 플러그를 뽑는다. 다시 쓰지 말고 장비 대장에서 "수리·점검 중".'),
      ]),
      _Part('정리', steps: [
        ('', '플러그를 뽑고 전원선은 꺾이지 않게 느슨히 감는다.'),
        ('', '쇳가루·기름을 닦아 케이스에 넣는다.'),
        ('', '장비 대장에서 반납, 이상이 있었으면 적어 둔다.'),
      ]),
    ],
  ),
  _Guide(
    id: 'common_safety',
    group: _Group.common,
    title: '안전',
    sub: '매일 지키는 것',
    icon: LucideIcons.hardHat,
    color: Colors.amber.shade800,
    parts: [
      _Part('매일', rows: [
        ('보호구', '보안경(절단·연마 필수), 귀마개, 절단 장갑. 회전 장비 앞에서 면장갑 금지.'),
        ('유압', '호스·커플러 누유 확인. 램·슈 사이에 손 금지. 핀은 끝까지.'),
        ('전동 벤더', '비상 정지 자리 먼저. 암이 도는 반경 안에 사람·자재 없게.'),
        ('무게', '6 m 후강 54는 본당 약 36 kg. 형강 탭의 무게로 미리 인원을 정한다.'),
        ('불꽃', '불꽃 방향에 배관·케이블·유류 없게. 소화기 위치 확인.'),
        ('통신 없는 현장', '앱은 폰에 저장했다가 통신되면 올린다. 저장 안 됐다고 다시 누르지 말고 나와서 확인.'),
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
        refIntroBadge('장비를 누르면 펴집니다. 제원·쓰는 법·주의·정비·고장·정리를 골라 봅니다. 정비 주기·부품은 제조사 설명서가 먼저입니다.'),
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

  List<Widget> _partBody(BuildContext context, _Part p) {
    final out = <Widget>[];
    for (var i = 0; i < p.steps.length; i++) {
      final (head, body) = p.steps[i];
      out.add(refStep(i + 1, head.isEmpty ? body : '$head: $body'));
    }
    // 머리말이 긴 칸(고장 증상 등)은 머리말을 위에, 내용을 아래에 둔다. 옆에 두면 머리말이 두세 줄로 꺾인다.
    final stacked = p.rows.any((r) => r.$1.length > 7);
    for (var i = 0; i < p.rows.length; i++) {
      if (i > 0) out.add(refGap());
      final (head, body) = p.rows[i];
      out.add(stacked ? _stackedRow(head, body) : refDataRow(head, body));
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
          Text(head, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: refTextMain, height: 1.4)),
          const SizedBox(height: 2),
          Text(body, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: refTextSub, height: 1.5)),
        ],
      ),
    );
  }
}
