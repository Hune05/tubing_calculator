// 근태 설정이 계산기 설정과 같이 서버로 올라가고, 다른 기기에서 그대로 읽히는지 시험.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/settings_cloud.dart';
import 'package:tubing_calculator/src/presentation/attendance/attendance_settings.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('근태 설정 칸이 서버에 올리는 칸에 들어 있고, 보기 방식은 빠져 있다', () {
    for (final k in [
      AttendanceSettings.hireKey,
      AttendanceSettings.breakKey,
      AttendanceSettings.saturdayKey,
      AttendanceSettings.overrideKey,
      AttendanceSettings.workStartKey,
      AttendanceSettings.workEndKey,
      AttendanceSettings.ruleNoteKey,
    ]) {
      expect(kCloudSettingKeys, contains(k), reason: k);
    }
    // 달력·목록 보기는 기기마다 다르게 둔다.
    expect(kCloudSettingKeys, isNot(contains(AttendanceSettings.viewKey)));
  });

  test('한 기기에서 저장한 설정이 다른 기기로 그대로 옮겨진다(휴게는 정수로)', () async {
    final a = AttendanceSettings(
      hireDate: DateTime(2021, 3, 15),
      defaultBreak: 60,
      saturdayIsHoliday: true,
      leaveOverrides: const {'2026-03-15': 17.0},
      workStart: '08:00',
      workEnd: '17:00',
      ruleNote: '제18조 연장은 17시부터',
    );
    await a.save();
    final up = collectLocalSettings(await SharedPreferences.getInstance());

    // 다른 기기: 빈 폰에 서버 값을 받는다. 서버는 정수를 소수로 돌려줄 수 있다.
    SharedPreferences.setMockInitialValues({});
    final p2 = await SharedPreferences.getInstance();
    final fromServer = {
      for (final e in up.entries)
        e.key: e.value is int ? (e.value as int).toDouble() : e.value,
    };
    await applyCloudSettings(p2, fromServer);

    final b = await AttendanceSettings.load();
    expect(b.hireDate, DateTime(2021, 3, 15));
    expect(b.defaultBreak, 60);
    expect(b.saturdayIsHoliday, isTrue);
    expect(b.leaveOverrides['2026-03-15'], 17.0);
    expect(b.workStart, '08:00');
    expect(b.workEnd, '17:00');
    expect(b.ruleNote, '제18조 연장은 17시부터');
  });

  test('비운 값(입사일·소정 시각)도 지우지 않고 빈 글자로 올라가 다른 기기에서도 비워진다', () async {
    await AttendanceSettings(
      hireDate: DateTime(2021, 3, 15),
      workStart: '08:00',
      workEnd: '17:00',
    ).save();
    // 비운 뒤 다시 저장
    await AttendanceSettings.load().then(
      (s) => s
          .copyWith(clearHire: true, clearWorkStart: true, clearWorkEnd: true)
          .save(),
    );
    final up = collectLocalSettings(await SharedPreferences.getInstance());
    expect(up[AttendanceSettings.hireKey], '');
    expect(up[AttendanceSettings.workStartKey], '');
    expect(up[AttendanceSettings.workEndKey], '');

    final s = await AttendanceSettings.load();
    expect(s.hireDate, isNull);
    expect(s.workStart, isNull);
    expect(s.workEnd, isNull);
  });
}
