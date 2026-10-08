// 사용 승인(10-08): 승인제가 켜져 있고 대기·거절이면 "승인 대기" 화면, 아니면 홈 그대로.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/approval/member_approval.dart';
import 'package:tubing_calculator/src/presentation/approval/member_approval_page.dart';
import 'package:tubing_calculator/src/presentation/approval/member_gate.dart';

void main() {
  test('막는 때: 승인제가 켜져 있고 대기·거절일 때만', () {
    for (final s in MemberStatus.values) {
      expect(memberBlocked(enforced: false, status: s), isFalse, reason: '$s 꺼짐');
    }
    expect(memberBlocked(enforced: true, status: MemberStatus.pending), isTrue);
    expect(memberBlocked(enforced: true, status: MemberStatus.rejected), isTrue);
    expect(memberBlocked(enforced: true, status: MemberStatus.approved), isFalse);
    // 한 번도 확인 못 했으면(통신 없는 현장) 막지 않는다.
    expect(memberBlocked(enforced: true, status: MemberStatus.unknown), isFalse);
  });

  test('상태 글 ↔ 값', () {
    for (final s in MemberStatus.values) {
      expect(memberStatusFromText(memberStatusText(s)), s);
    }
    expect(memberStatusFromText(null), MemberStatus.unknown);
    expect(memberStatusFromText('이상한 값'), MemberStatus.unknown);
  });

  test('목록 순서: 대기 → 승인됨 → 거절, 같은 상태는 최근 신청 먼저', () {
    Map<String, dynamic> r(String name, String status, int day) => {
      'name': name,
      'status': status,
      'requestedAt': Timestamp.fromDate(DateTime(2026, 10, day)),
    };
    final rows = [
      r('승인A', 'approved', 1),
      r('거절', 'rejected', 9),
      r('대기 옛', 'pending', 2),
      r('대기 새', 'pending', 8),
      r('승인B', 'approved', 5),
    ]..sort(memberRowOrder);
    expect(rows.map((e) => e['name']), ['대기 새', '대기 옛', '승인B', '승인A', '거절']);
  });

  Future<void> pumpGate(
    WidgetTester tester, {
    required MemberCheck cached,
    required Future<MemberCheck> Function(String) check,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberGate(
          name: '홍길동',
          cached: () async => cached,
          check: check,
          child: const Scaffold(body: Text('홈 화면')),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('승인제가 꺼져 있으면 대기 중이어도 홈이 그대로 열린다', (tester) async {
    await pumpGate(
      tester,
      cached: const MemberCheck(MemberStatus.unknown, false),
      check: (_) async => const MemberCheck(MemberStatus.pending, false),
    );
    expect(find.text('홈 화면'), findsOneWidget);
    expect(find.byKey(const Key('member_waiting')), findsNothing);
  });

  testWidgets('켜져 있고 대기면 "승인 대기", 승인 뒤 다시 확인하면 홈', (tester) async {
    var status = MemberStatus.pending;
    await pumpGate(
      tester,
      cached: const MemberCheck(MemberStatus.unknown, true),
      check: (_) async => MemberCheck(status, true),
    );
    expect(find.byKey(const Key('member_waiting')), findsOneWidget);
    expect(find.text('승인 대기 중입니다'), findsOneWidget);
    expect(find.text('이름: 홍길동'), findsOneWidget);
    expect(find.text('홈 화면'), findsNothing);

    status = MemberStatus.approved;
    await tester.tap(find.byKey(const Key('member_recheck')));
    await tester.pump();
    await tester.pump();
    expect(find.text('홈 화면'), findsOneWidget);
  });

  testWidgets('거절이면 거절 안내', (tester) async {
    await pumpGate(
      tester,
      cached: const MemberCheck(MemberStatus.rejected, true),
      check: (_) async => const MemberCheck(MemberStatus.rejected, true),
    );
    expect(find.text('사용이 거절되었습니다'), findsOneWidget);
  });

  testWidgets('통신이 없어 확인이 늦어도 폰에 적어 둔 승인 상태로 바로 홈이 열린다', (tester) async {
    await pumpGate(
      tester,
      cached: const MemberCheck(MemberStatus.approved, true),
      check: (_) => Future.delayed(
        const Duration(seconds: 30),
        () => const MemberCheck(MemberStatus.approved, true),
      ),
    );
    expect(find.text('홈 화면'), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets("대기 화면에서 구글 계정으로 로그인하면 다시 확인해 승인된 계정이면 홈(10-09)", (tester) async {
    var status = MemberStatus.pending;
    var logins = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MemberGate(
          name: "홍길동",
          cached: () async => const MemberCheck(MemberStatus.unknown, true),
          check: (_) async => MemberCheck(status, true),
          googleLogin: () async {
            logins++;
            status = MemberStatus.approved; // 이미 승인된 구글 계정으로 바뀜
          },
          child: const Scaffold(body: Text("홈 화면")),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key("member_google_login")), findsOneWidget);
    await tester.tap(find.byKey(const Key("member_google_login")));
    await tester.pump();
    await tester.pump();
    expect(logins, 1);
    expect(find.text("홈 화면"), findsOneWidget);
  });

  testWidgets("구글 로그인이 실패하면 알리고 대기 화면에 남는다", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberGate(
          name: "홍길동",
          cached: () async => const MemberCheck(MemberStatus.unknown, true),
          check: (_) async => const MemberCheck(MemberStatus.pending, true),
          googleLogin: () async => throw Exception("통신 없음"),
          child: const Scaffold(body: Text("홈 화면")),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key("member_google_login")));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining("구글 계정으로 로그인하지 못했습니다"), findsOneWidget);
    expect(find.byKey(const Key("member_waiting")), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}

