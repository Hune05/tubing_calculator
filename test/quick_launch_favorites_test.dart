// 홈 화면 "빠른 실행" 즐겨찾기 켜고 끄기(순수 함수만 — MobileMenuPage 자체는
// Firebase·위치 등 실제 기기 의존이 많아 화면째 시험하지 않는다, weather_refresh_test.dart와 같은 방침).
//
// 2026-09-28: "빠른 실행"을 실물 카드·카드 지갑 흉내 대신 전체 메뉴와 같은
// 목록 줄로 바꾸면서, 그 카드 전용이었던 상세 화면·부가 기능 화면·사용
// 히스토리·앞 카드 자리 관련 순수 함수들(quickLaunchRelativeTime,
// quickLaunchClampFrontIndex, quickLaunchAppendHistory,
// quickLaunchDecodeHistory/EncodeHistory)은 다 같이 지워서 이 파일의 시험도
// 정리했다.
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
}
