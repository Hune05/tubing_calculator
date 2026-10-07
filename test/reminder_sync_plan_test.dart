// 다른 기기에서 만든·고친·지운 일정의 알림 맞추기(10-07). 알림 예약은 기기마다 따로라,
// 예전에는 태블릿에서 만든 일정의 알림이 폰에서 울리지 않고 지운 일정의 알림은 계속 울렸다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_reminders.dart';

Map<String, dynamic> _doc(String title, {String at = '2026-10-20T09:00:00', List<int> rem = const [30]}) => {
  'title': title,
  'dateTime': at,
  'hasTime': true,
  'recurrence': 'none',
  'reminders': rem,
};

void main() {
  test('이 기기가 잡은 그대로면 건너뛰고, 다른 기기에서 만든·고친 것은 다시 잡고, 지운 것은 취소', () {
    final same = _doc('점검');
    final docs = [
      (id: 'a', data: same),
      (id: 'b', data: _doc('새 일정')), // 태블릿에서 만듦(이 기기는 모름)
      (id: 'c', data: _doc('시각 바꿈', at: '2026-10-21T10:00:00')),
    ];
    final sigs = {
      'a': personalReminderSig(same),
      'c': personalReminderSig(_doc('시각 바꿈')),
      'gone': personalReminderSig(_doc('지운 일정')),
    };
    final plan = planPersonalReminderSync(docs: docs, sigs: sigs, canCancel: true);
    expect(plan.toSchedule, ['b', 'c']);
    expect(plan.toCancel, ['gone']);
  });

  test('폰 사본이 비어 무엇이 지워졌는지 모르면 취소하지 않는다', () {
    final plan = planPersonalReminderSync(
      docs: const [],
      sigs: {'x': 'sig'},
      canCancel: false,
    );
    expect(plan.toCancel, isEmpty);
  });

  test('알림 시각에 쓰이는 칸이 바뀌면 모양도 바뀐다(제목·알림 분·뺀 회차)', () {
    final base = personalReminderSig(_doc('점검'));
    expect(personalReminderSig(_doc('점검 2')), isNot(base));
    expect(personalReminderSig(_doc('점검', rem: [10])), isNot(base));
    expect(personalReminderSig({..._doc('점검'), 'memo': '메모만 바꿈'}), base);
  });
}
