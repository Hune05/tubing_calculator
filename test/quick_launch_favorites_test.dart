// 홈 화면 "빠른 실행" 즐겨찾기 켜고 끄기(순수 함수만 — MobileMenuPage 자체는
// Firebase·위치 등 실제 기기 의존이 많아 화면째 시험하지 않는다, weather_refresh_test.dart와 같은 방침).
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

  group('quickLaunchRelativeTime', () {
    final now = DateTime(2026, 9, 27, 12, 0);

    test('한 번도 안 썼으면 안내 글', () {
      expect(quickLaunchRelativeTime(null, now), '아직 사용한 기록이 없습니다');
    });

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

    test('2개월 전', () {
      expect(
        quickLaunchRelativeTime(now.subtract(const Duration(days: 61)), now),
        '2개월 전',
      );
    });

    test('1년 전', () {
      expect(
        quickLaunchRelativeTime(now.subtract(const Duration(days: 400)), now),
        '1년 전',
      );
    });
  });

  group('quickLaunchClampFrontIndex', () {
    test('범위 안이면 그대로', () {
      expect(quickLaunchClampFrontIndex(1, 3), 1);
    });

    test('실제 버그: 3장 중 3번째(2)를 보다가 1장을 빼서 2장이 되면 마지막(1)으로', () {
      expect(quickLaunchClampFrontIndex(2, 2), 1);
    });

    test('전부 빠지면(0장) 0', () {
      expect(quickLaunchClampFrontIndex(2, 0), 0);
    });

    test('한 장만 남으면 0', () {
      expect(quickLaunchClampFrontIndex(2, 1), 0);
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
