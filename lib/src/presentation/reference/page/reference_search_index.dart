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
  '단위 환산',
  '발전 설비',
  '전기 기준(KEC)',
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
  RefSearchEntry(0, '각도별 계산 (계산기 공식 그대로)', ['셋백', '게인', '호 길이']),
  RefSearchEntry(0, '오프셋 계수 (빗변·수축·직진)'),
  RefSearchEntry(0, '180° U벤드가 차지하는 자리'),
  RefSearchEntry(0, '스프링백 참고값', ['동관', 'sus316l']),
  RefSearchEntry(0, '라인 컷팅 부속 공제값 (앱 자료)'),
  RefSearchEntry(0, '튜브 두께별 최대 허용 압력', ['sus 316l', 'psi', 'bar']),
  RefSearchEntry(0, 'NPT 나사 규격'),
  RefSearchEntry(0, '튜브 작업, 현장에서 지키는 것'),

  // 전선관(1)
  RefSearchEntry(1, '전선관 규격 · 외경', ['ks c 8401', '후강', '박강', '바깥지름']),
  RefSearchEntry(1, '수동 벤더 제원 (앱 값)', ['테이크업', '게인', 'clr']),
  RefSearchEntry(1, '유압식 벤더 제원 (앱 값)', ['램', '셋백', 'clr']),
  RefSearchEntry(1, '시카고식 벤더 제원 (앱 값)', ['노치', '롤러']),
  RefSearchEntry(1, '각도별 테이크업 환산 (계산기 식)'),
  RefSearchEntry(1, '스프링백 · 커플링 끝 여유 기본값'),
  RefSearchEntry(1, '오프셋·새들 계수 (튜브 탭 4번과 같은 식)'),
  RefSearchEntry(1, '곤질레다·커플링 (삼화기전 F-7)', [
    'lb',
    'll',
    'lr',
    'lt',
    'lc',
    'lx',
  ]),
  RefSearchEntry(1, '전선관·후렉시블 관통 구멍(홀쏘) 최소 지름', [
    '홀쏘',
    '홀커터',
    '홀가공',
  ]),
  RefSearchEntry(1, '유볼트(U밴드) 고르는 법', ['유볼트', 'u밴드', 'u볼트']),
  RefSearchEntry(1, '탭 사이즈별 홀가공 지름(탭 드릴)', [
    '탭드릴',
    '탭 드릴',
    'm6',
    'm8',
    'm10',
    'm12',
  ]),
  RefSearchEntry(1, '볼트 머리·렌치(스패너) 사이즈', ['렌치', '스패너', '육각소켓', '유볼트']),
  RefSearchEntry(1, '전선관·후렉시블 부속 이름 정리', [
    '로크너트',
    '부싱',
    '후렉시블 커넥터',
    '새들',
    '스트랩',
    '니플',
  ]),
  RefSearchEntry(1, '전선관 작업, 현장에서 지키는 것'),

  // 형강(2)
  RefSearchEntry(2, '재단 계획 계산 방법'),
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

  // 단위 환산(3)
  RefSearchEntry(3, '단위 환산: 길이·인치 분수·피트', ['mm', 'inch', '인치', '분수', 'ft', '피트']),
  RefSearchEntry(3, '단위 환산: 압력', ['bar', 'psi', 'mpa', 'kgf/cm2', '수주', 'mmhg']),
  RefSearchEntry(3, '단위 환산: 토크', ['nm', 'lb-ft', 'kgf·m', 'kgm', '토크']),
  RefSearchEntry(3, '단위 환산: 중량·힘', ['kg', 'lb', 'kgf', '톤', 'lbf', '무게']),
  RefSearchEntry(3, '단위 환산: 온도·온도차·유량·면적·부피', ['°c', '°f', 'gpm', 'l/min', '갤런', '온도차']),
  RefSearchEntry(3, '단위 환산: 각도·구배·동력·에너지', ['구배', '%', 'mm/m', 'kw', '마력', 'kwh', 'kcal', '냉동톤']),
  RefSearchEntry(3, '단위 환산: 전선 굵기 (SQ ↔ AWG)', ['awg', 'sq', '스퀘어', '전선']),
  RefSearchEntry(3, '단위 환산: 배관 호칭 (A·B·DN·외경)', ['15a', 'dn', 'nps', '호칭', '외경', '바깥지름']),

  // 발전 설비(4) — 10-09 전문 자료로 다시 씀(카드 제목과 같아야 찾아간다)
  RefSearchEntry(4, '왜 대형 발전기는 수소(H₂)로 냉각하나', ['h2', '수소냉각', '풍손', 'windage', '수소압']),
  RefSearchEntry(4, '수소 가스 계통: 판넬·드라이어·분석기', [
    '가스 판넬',
    'gas panel',
    '가스 드라이어',
    '순도',
    '노점',
    'dew point',
    '분석기',
    'katharometer',
  ]),
  RefSearchEntry(4, 'CO₂ 퍼지: 수소 충전·배출 순서', ['co2 퍼지', '가스 치환', 'purge', '이산화탄소']),
  RefSearchEntry(4, '씰 오일 계통: 수소가 축을 따라 안 새는 이유', [
    'seal oil',
    '씰오일탱크',
    '차압',
    '진공탱크',
    'vacuum tank',
    'dpr',
    'detraining',
    'float trap',
    'liquid detector',
  ]),
  RefSearchEntry(4, '윤활유 계통(LOT)과 베어링 보호', [
    'lot',
    'lube oil tank',
    '오일쿨러',
    '비상오일펌프',
    'jacking oil',
    '잭킹오일',
    'turning gear',
    '터닝기어',
    '베어링 온도',
    'oil whirl',
  ]),
  RefSearchEntry(4, '냉각수 계통(워터 쿨링): 열을 밖으로 빼내는 3단', [
    '워터쿨링',
    '밀폐냉각수',
    'ccw',
    'service water',
  ]),
  RefSearchEntry(4, '고정자 냉각수(SCW): 수질·압력·감시', [
    '고정자냉각수',
    'scw',
    'stator cooling',
    '전도도',
    '용존산소',
    'runback',
  ]),
  RefSearchEntry(4, '복수기 진공: 배압·공기 유입', [
    '복수기',
    '진공계통',
    '배압',
    'sjae',
    'lrvp',
    '공기 유입',
  ]),
  RefSearchEntry(4, '여자 계통·AVR·조속기(EHC)', [
    '여자계통',
    'excitation',
    'avr',
    '64f',
    '계자 지락',
    '조속기',
    'governor',
    'droop',
  ]),
  RefSearchEntry(4, '밸브 스테이션: 밸브를 왜 한 곳에 모아두나', ['valve station']),
  RefSearchEntry(4, '전체 흐름 한눈에 보기', ['원자로', '보일러', '터빈']),

  // 전기 기준(KEC)(5)
  RefSearchEntry(5, '최신 원문을 확인하는 방법', [
    'kec',
    '한국전기설비규정',
    '전기설비기술기준',
    'law.go.kr',
  ]),
  RefSearchEntry(5, '접지·과전류 보호: 감전·화재와 직결', [
    '접지',
    '계통접지',
    '과전류보호',
    '차단기',
  ]),
  RefSearchEntry(5, '절연저항·이격거리: 측정값 기준', ['절연저항', '이격거리', '메거']),
  RefSearchEntry(5, '최근 몇 년 사이 개정이 잦았던 분야', [
    'ev충전',
    '신재생',
    'ess',
  ]),
];
