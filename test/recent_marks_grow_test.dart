// 10-09: 최근 마킹 기록이 입력하는 도중의 목록마다 쌓여 20개 한도를 금방 채웠다 → 방금 기록에 줄을
// 이어 붙인 것이면 바꿔 끼운다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/common_widgets/recent_calc_history.dart';

void main() {
  testWidgets('줄을 이어 넣는 동안은 한 기록을 바꿔 끼우고, 앞 줄을 고치면 새로 쌓는다', (tester) async {
    final log = RecentCalcLog();
    RecentCalcLog.now = () => DateTime(2026, 10, 9, 9);
    addTearDown(() => RecentCalcLog.now = DateTime.now);
    Future<void> wait() => tester.pump(const Duration(seconds: 1));

    log.log('마킹 계산', '1줄', dedupeKey: 'a', growKey: '300_90_0;');
    await wait();
    log.log('마킹 계산', '2줄', dedupeKey: 'b', growKey: '300_90_0;200_0_0;');
    await wait();
    expect(log.entries.length, 1);
    expect(log.entries.first.subtitle, '2줄');
    // 앞 줄 길이를 고친 목록은 이어 붙인 것이 아니다.
    log.log('마킹 계산', '고침', dedupeKey: 'c', growKey: '350_90_0;200_0_0;');
    await wait();
    expect(log.entries.length, 2);
    // 제목(규격)이 다르면 따로.
    log.log('마킹 계산 · 튜브 3/8"', '다른 규격', dedupeKey: 'd', growKey: '350_90_0;200_0_0;400_0_0;');
    await wait();
    expect(log.entries.length, 3);
  });
}
