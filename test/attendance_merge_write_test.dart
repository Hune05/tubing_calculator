// 근태 저장은 칸별로 쓴다(10-08): 이 폰이 모르는 칸(다른 기기에서 적은 메모·퇴근)은 건드리지 않는다.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/attendance.dart';

void main() {
  final day = DateTime(2026, 10, 8);

  test('출근만 찍으면 퇴근·메모·휴게 칸은 보내지 않는다(다른 기기 값이 남음)', () {
    final d = attendanceWriteData(AttendanceRecord(date: day, checkIn: '08:00'), null, 'u1');
    expect(d['checkIn'], '08:00');
    expect(d['type'], kAttendanceNormal);
    expect(d['uid'], 'u1');
    expect(d['date'], '2026-10-08');
    expect(d.containsKey('checkOut'), isFalse);
    expect(d.containsKey('memo'), isFalse);
    expect(d.containsKey('breakMin'), isFalse);
  });

  test('이 폰이 알던 메모를 비우면 지운다', () {
    final before = AttendanceRecord(date: day, checkIn: '08:00', checkOut: '17:00', memo: '태안');
    final d = attendanceWriteData(AttendanceRecord(date: day, checkIn: '08:00', checkOut: '17:00', memo: '  '), before, 'u1');
    expect(d['memo'], isA<FieldValue>());
    expect(d['checkOut'], '17:00');
    expect(d.containsKey('breakMin'), isFalse);
  });
}
