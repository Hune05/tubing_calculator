// 10-09 남은 것 2묶음: 앞에 줄이 있으면 첫 줄 길이는 앞 꺾이는 점에서 재므로, 시트 칸 이름과
// "1번 마킹이 N mm 자리" 알림이 관 끝 기준으로 말하지 않게 한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_sheet_specs.dart';

void main() {
  final s = {'benderType': 'hand', 'takeUp': 152.4, 'gain': 81.2, 'clr': 114.3, 'applyShrink': true};

  test('목록이 비었으면 관 끝 기준으로 줄자 자리를 말한다', () {
    final specs = BendSheetSpecs.conduit(s);
    expect(specs.listEmpty, isTrue);
    expect(specs.startRef, '관 끝');
    expect(specs.firstMarkNotice(247.6), '1번 마킹이 248mm 자리에 찍힙니다.');
  });

  test('앞 줄이 있으면 "앞 꺾이는 점"이라 하고 줄자 자리는 마킹 탭을 보라고 한다', () {
    final specs = BendSheetSpecs.conduit(s, listEmpty: false);
    expect(specs.startRef, '앞 꺾이는 점');
    expect(specs.firstMarkNotice(247.6), contains('마킹 탭에서 확인'));
    expect(specs.firstMarkNotice(247.6), isNot(contains('248mm')));
  });
}
