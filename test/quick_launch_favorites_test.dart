// 홈 화면 "빠른 실행" 즐겨찾기 켜고 끄기(순수 함수만 — MobileMenuPage 자체는
// Firebase·위치 등 실제 기기 의존이 많아 화면째 시험하지 않는다, weather_refresh_test.dart와 같은 방침).
//
// 2026-09-28: "빠른 실행"을 실물 카드·카드 지갑 흉내 대신 전체 메뉴와 같은
// 목록 줄로 바꿈. 이어서 헤더 점 세개에 "빠른 실행 편집"을 되돌리고, 줄을
// 길게 누르면 "작업 히스토리"(실제로 눌러 들어간 시각 목록)를 보여주도록
// 사용 기록 관련 순수 함수도 다시 넣었다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/menu/page/mobile_menu_page.dart';

void main() {
  test('없던 것을 넣으면 즐겨찾기에 들어간다', () {
    final r = toggleQuickLaunchFavorite({}, '내 프로젝트');
    expect(r, {'내 프로젝트'});
  });

  test('있던 것을 다시 누르면 빠진다', () {
    final r = toggleQuickLaunchFavorite({'내 프로젝트'}, '내 프로젝트');
    expect(r, isEmpty);
  });

  test('여러 개 중 하나만 골라 빼도 나머지는 그대로', () {
    final r = toggleQuickLaunchFavorite({'내 프로젝트', '내 일정 관리'}, '내 프로젝트');
    expect(r, {'내 일정 관리'});
  });

  test('원래 집합은 안 바뀐다(새 집합을 돌려준다)', () {
    final original = {'내 프로젝트'};
    final r = toggleQuickLaunchFavorite(original, '내 일정 관리');
    expect(original, {'내 프로젝트'}); // 그대로.
    expect(r, {'내 프로젝트', '내 일정 관리'});
  });

  test('이름을 바꾼 메뉴: 예전 이름으로 저장된 즐겨찾기를 새 이름으로 읽는다(겹치면 하나)', () {
    expect(renameQuickLaunchTitles(['내 프로젝트', '압력 시험']), ['내 프로젝트', '압력시험']);
    expect(renameQuickLaunchTitles(['압력시험', '압력 시험']), ['압력시험']);
  });

  group('빠른 실행 순서(끌어서 바꾸기)', () {
    test('저장된 순서가 있으면 그 순서대로, 없는 건 원래 순서로 뒤에', () {
      expect(orderQuickLaunch(['가', '나', '다', '라'], ['다', '가']), [
        '다',
        '가',
        '나',
        '라',
      ]);
    });

    test('순서에 있어도 즐겨찾기에서 빠진 제목은 버린다', () {
      expect(orderQuickLaunch(['가', '나'], ['라', '나', '가']), ['나', '가']);
    });

    test('순서가 비어 있으면 메뉴 순서 그대로', () {
      expect(orderQuickLaunch(['가', '나', '다'], []), ['가', '나', '다']);
    });

    test('아래로 옮기기: ReorderableListView의 newIndex는 뽑기 전 기준', () {
      // 0번(가)을 3번 자리(다 다음, 즉 index 3)로 → 나, 다, 가
      expect(moveQuickLaunch(['가', '나', '다'], 0, 3), ['나', '다', '가']);
      expect(moveQuickLaunch(['가', '나', '다'], 0, 2), ['나', '가', '다']);
    });

    test('위로 옮기기', () {
      expect(moveQuickLaunch(['가', '나', '다'], 2, 0), ['다', '가', '나']);
    });

    test('원본 목록은 안 바뀌고, 범위 밖 번호는 그대로 돌려준다', () {
      final src = ['가', '나'];
      moveQuickLaunch(src, 0, 2);
      expect(src, ['가', '나']);
      expect(moveQuickLaunch(src, 5, 0), ['가', '나']);
    });
  });

  group('quickLaunchRelativeTime', () {
    final now = DateTime(2026, 9, 28, 12, 0);

    test('30초 전은 방금 전', () {
      expect(
        quickLaunchRelativeTime(now.subtract(const Duration(seconds: 30)), now),
        '방금 전',
      );
    });

    test('45분 전', () {
      expect(
        quickLaunchRelativeTime(now.subtract(const Duration(minutes: 45)), now),
        '45분 전',
      );
    });

    test('5시간 전', () {
      expect(
        quickLaunchRelativeTime(now.subtract(const Duration(hours: 5)), now),
        '5시간 전',
      );
    });

    test('3일 전', () {
      expect(
        quickLaunchRelativeTime(now.subtract(const Duration(days: 3)), now),
        '3일 전',
      );
    });
  });

  group('quickLaunchAppendHistory', () {
    final t1 = DateTime(2026, 9, 28, 9);
    final t2 = DateTime(2026, 9, 28, 10);

    test('빈 목록에 하나 넣으면 그것만', () {
      expect(quickLaunchAppendHistory([], t1), [t1]);
    });

    test('새 기록이 맨 앞에 붙는다', () {
      expect(quickLaunchAppendHistory([t1], t2), [t2, t1]);
    });

    test('원래 목록은 안 바뀐다(새 목록을 돌려준다)', () {
      final original = [t1];
      final r = quickLaunchAppendHistory(original, t2);
      expect(original, [t1]);
      expect(r, [t2, t1]);
    });

    test('max를 넘으면 오래된 것부터 잘린다', () {
      final history = List.generate(5, (i) => t1.add(Duration(hours: i)));
      final r = quickLaunchAppendHistory(history, t2, max: 3);
      expect(r.length, 3);
      expect(r.first, t2);
    });
  });

  group('quickLaunchDecodeHistory/quickLaunchEncodeHistory', () {
    test('null이나 빈 글이면 빈 목록', () {
      expect(quickLaunchDecodeHistory(null), isEmpty);
      expect(quickLaunchDecodeHistory(''), isEmpty);
    });

    test('예전 형식(ISO8601 글 하나)도 읽는다', () {
      final t = DateTime(2026, 9, 20, 8, 30);
      expect(quickLaunchDecodeHistory(t.toIso8601String()), [t]);
    });

    test('인코드했다가 디코드하면 그대로', () {
      final history = [DateTime(2026, 9, 28, 10), DateTime(2026, 9, 27, 9)];
      final encoded = quickLaunchEncodeHistory(history);
      expect(quickLaunchDecodeHistory(encoded), history);
    });

    test('알아볼 수 없는 글이면 빈 목록', () {
      expect(quickLaunchDecodeHistory('이상한 글'), isEmpty);
    });
  });
}
