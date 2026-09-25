// 현장 자료 화면 통합 검색용 카드 색인(현장자료 보충제안 2번). 탭 안 내용을
// 코드로 구조화하지 않고, 카드 제목만 따로 추려 어느 탭에 있는지 찾아 준다.
// 탭 자체는 그대로 두고(위험한 재구조화 없음), 검색어가 있을 때만 이 목록에서
// 걸러 보여 주고, 고르면 그 탭으로 넘어간다.
library;

class RefSearchEntry {
  final int tab;
  final String title;
  final List<String> keywords;
  const RefSearchEntry(this.tab, this.title, [this.keywords = const []]);

  bool matches(String query) {
    final q = query.toLowerCase();
    if (title.toLowerCase().contains(q)) return true;
    return keywords.any((k) => k.toLowerCase().contains(q));
  }
}

const List<String> refTabNames = [
  '튜브',
  '전선관',
  '형강',
  '장비 사용법',
  '앱 사용법',
  '단위 환산',
];

const List<RefSearchEntry> refSearchIndex = [
  // 튜브(0)
  RefSearchEntry(0, '튜브 규격표 · 계산기 기본 제원', [
    'OD',
    '반경',
    'takeup',
    '테이크업',
    '게인',
    'inch',
    'mm',
  ]),
  RefSearchEntry(0, '피팅 삽입 깊이 · 최소 직선'),
  RefSearchEntry(0, '각도별 셈 (계산기 공식 그대로)', ['셋백', '게인', '호 길이']),
  RefSearchEntry(0, '오프셋 계수 (빗변·수축·직진)'),
  RefSearchEntry(0, '180° U벤드가 차지하는 자리'),
  RefSearchEntry(0, '스프링백 참고값', ['동관', 'sus316l']),
  RefSearchEntry(0, '튜브 컷팅 부속 공제값 (앱 자료)'),
  RefSearchEntry(0, '튜브 두께별 최대 허용 압력', ['sus 316l', 'psi', 'bar']),
  RefSearchEntry(0, 'NPT 나사 규격'),
  RefSearchEntry(0, '튜브 작업, 현장에서 지키는 것'),

  // 전선관(1)
  RefSearchEntry(1, '전선관 규격 · 바깥지름', ['ks c 8401', '후강', '박강']),
  RefSearchEntry(1, '수동 벤더 제원 (앱 값)', ['테이크업', '게인', 'clr']),
  RefSearchEntry(1, '유압식 벤더 제원 (앱 값)', ['램', '셋백', 'clr']),
  RefSearchEntry(1, '시카고식 벤더 제원 (앱 값)', ['노치', '롤러']),
  RefSearchEntry(1, '각도별 테이크업 환산 (계산기 식)'),
  RefSearchEntry(1, '스프링백 · 커플링 끝 여유 기본값'),
  RefSearchEntry(1, '오프셋·새들 계수 (전선관도 같음)'),
  RefSearchEntry(1, '곤질레다·커플링 (삼화기전 F-7)', [
    'lb',
    'll',
    'lr',
    'lt',
    'lc',
    'lx',
  ]),
  RefSearchEntry(1, '전선관 작업, 현장에서 지키는 것'),

  // 형강(2)
  RefSearchEntry(2, '재단 계획이 세는 법'),
  RefSearchEntry(2, '앵글 이론 중량표', ['kg/m']),
  RefSearchEntry(2, '찬넬 이론 중량표', ['kg/m']),
  RefSearchEntry(2, '스트럿 이론 중량표', ['kg/m']),
  RefSearchEntry(2, '평철 이론 중량표', ['kg/m']),
  RefSearchEntry(2, '각파이프 이론 중량표', ['kg/m']),
  RefSearchEntry(2, '강관 이론 중량표', ['kg/m']),
  RefSearchEntry(2, '환봉 이론 중량표', ['kg/m']),
  RefSearchEntry(2, '전산볼트 이론 중량표', ['kg/m']),
  RefSearchEntry(2, '부등변앵글 이론 중량표', ['kg/m']),
  RefSearchEntry(2, '립C형강 이론 중량표', ['kg/m']),
  RefSearchEntry(2, 'H형강 이론 중량표', ['kg/m']),
  RefSearchEntry(2, '절단 현장에서 지키는 것', ['고속절단기', '밴드쏘']),

  // 장비 사용법(3)
  RefSearchEntry(3, '튜브 수동 벤더 (Swagelok·Ridgid형)'),
  RefSearchEntry(3, 'Swagelok 전동 벤더 (MS-BTB)'),
  RefSearchEntry(3, 'TRACTO-TECHNIK TB20D (NC 벤더)'),
  RefSearchEntry(3, '전선관 수동 벤더 (Greenlee·Ideal형)'),
  RefSearchEntry(3, '유압식 벤더 (Greenlee·Current Tools형)'),
  RefSearchEntry(3, '시카고식 벤더 (기어·크랭크)'),
  RefSearchEntry(3, '내 장비 실측 캘리브레이션 (한 번만)', [
    '테이크업',
    '게인',
    '램이동',
    '노치각도',
    '스프링백',
  ]),
  RefSearchEntry(3, '튜브 커터 · 디버링'),
  RefSearchEntry(3, '고속절단기 · 밴드쏘 · 전선관 나사'),
  RefSearchEntry(3, '안전(장비 사용)', ['보호구', '안전수칙']),

  // 앱 사용법(4)
  RefSearchEntry(4, '벤딩 마킹 계산기 (튜브)'),
  RefSearchEntry(4, '전선관 벤딩 마킹 계산기'),
  RefSearchEntry(4, '튜브 컷팅 계산기'),
  RefSearchEntry(4, '형강 컷팅 (찬넬/앵글)'),
  RefSearchEntry(4, '작업 배치도'),
  RefSearchEntry(4, '내 프로젝트 · 작업 일지 · 주간 보고'),
  RefSearchEntry(4, '내 일정 관리'),
  RefSearchEntry(4, '자재 현황 · 자재 통합 관리'),
  RefSearchEntry(4, '현장 도면 스캔 (QR) · 통신 없는 곳'),

  // 단위 환산(5)
  RefSearchEntry(5, '길이 (mm ↔ inch)', ['mm', 'inch']),
  RefSearchEntry(5, '무게 (kg ↔ lb)', ['kg', 'lb']),
  RefSearchEntry(5, '압력 (bar ↔ psi)', ['bar', 'psi']),
  RefSearchEntry(5, '토크 (Nm ↔ lb-ft)', ['nm', 'lb-ft', '토크']),
];
