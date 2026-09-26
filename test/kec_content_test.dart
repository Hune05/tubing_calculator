// 전기 기준(KEC) 요약을 서버에 두기(B)와 새 개정 공고 알림(A) — 앱 쪽.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/reference/kec_content.dart';
import 'package:tubing_calculator/src/presentation/reference/page/ref_kec_tab.dart';
import 'package:tubing_calculator/src/presentation/reference/page/tube_reference_page.dart';

KecContent bundled() => KecContent.tryParse(
  jsonDecode(File('assets/reference/kec_content.json').readAsStringSync()),
)!;

Map<String, dynamic> serverContent(int version, String warn) => {
  'version': version,
  'basis': {'serial': 'S2', 'noticeNo': '2026-10', 'issued': '2026-10-01'},
  'warn': warn,
  'sections': [
    {
      'type': 'steps',
      'title': '새 요약 카드',
      'items': ['한 줄'],
    },
  ],
};

Future<void> pumpTab(WidgetTester tester, KecState state) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: RefKecTab(load: () async => state)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('앱에 든 요약과 서버 함수의 요약 파일이 같다', () {
    final app = File('assets/reference/kec_content.json').readAsStringSync();
    final fn = File('functions/kec_content.json').readAsStringSync();
    expect(jsonDecode(app), jsonDecode(fn));
  });

  test('앱에 든 요약을 읽는다(판 번호·기준 공고·카드)', () {
    final c = bundled();
    expect(c.version, greaterThanOrEqualTo(1));
    expect(c.basis.serial, '2100000270772');
    expect(c.basis.noticeNo, '2025-227');
    expect(c.sections.first.type, 'steps');
    expect(c.sections.first.steps, hasLength(3));
    expect(c.sections[1].rows.first.label, '계통접지');
  });

  group('요약 고르기', () {
    test('서버 판이 더 높으면 서버 요약', () {
      final s = mergeKecState(bundled(), {'content': serverContent(99, '서버 글')});
      expect(s.content.warn, '서버 글');
    });
    test('서버 판이 같거나 낮으면 앱에 든 요약', () {
      final b = bundled();
      final s = mergeKecState(b, {
        'content': serverContent(b.version, '서버 글'),
      });
      expect(s.content.warn, b.warn);
    });
    test('서버 요약이 깨졌거나 문서가 없으면 앱에 든 요약', () {
      final b = bundled();
      expect(
        mergeKecState(b, {
          'content': {'version': 'x'},
        }).content.warn,
        b.warn,
      );
      expect(mergeKecState(b, null).content.warn, b.warn);
    });
  });

  group('새 공고 판단(서버 함수 kec.js와 같은 규칙)', () {
    const basis = KecBasis(serial: 'S1', issued: '2026-01-05');
    test('같은 공고면 아님', () {
      expect(
        isNewerKecNotice(
          const KecLatest(serial: 'S1', issued: '2026-01-05'),
          basis,
        ),
        isFalse,
      );
    });
    test('일련번호가 다르고 발령일이 늦으면 새 공고', () {
      expect(
        isNewerKecNotice(
          const KecLatest(serial: 'S2', issued: '2026-10-01'),
          basis,
        ),
        isTrue,
      );
    });
    test('옛 공고(발령일이 이르면)는 아님', () {
      expect(
        isNewerKecNotice(
          const KecLatest(serial: 'S0', issued: '2025-12-30'),
          basis,
        ),
        isFalse,
      );
    });
    test('확인 기록이 없으면 아님', () {
      expect(isNewerKecNotice(null, basis), isFalse);
    });
  });

  group('KEC 탭 화면', () {
    testWidgets('새 공고가 났으면 맨 위에 알리고 원문 보기 단추가 있다', (tester) async {
      final s = mergeKecState(bundled(), {
        'latest': {
          'serial': '2100000280000',
          'noticeNo': '2026-15',
          'revision': '일부개정',
          'issued': '2026-10-01',
          'effective': '2026-10-01',
          'url': 'https://www.law.go.kr/LSW/admRulInfoP.do?admRulSeq=2100000280000',
        },
        'check': {'ok': true, 'at': '2026-10-02T06:00:00+09:00'},
      });
      await pumpTab(tester, s);
      expect(find.byKey(const Key('kec_new_notice')), findsOneWidget);
      expect(find.textContaining('새 개정 공고가 났습니다 — 공고 제2026-15호'), findsOneWidget);
      expect(find.textContaining('(제2025-227호) 기준'), findsOneWidget);
      expect(find.text('원문 보기'), findsOneWidget);
    });

    testWidgets('새 공고가 없으면 알림 상자 없이 확인한 때와 출처만', (tester) async {
      final s = mergeKecState(bundled(), {
        'latest': {'serial': '2100000270772', 'issued': '2026-01-05'},
        'check': {'ok': true, 'at': '2026-09-27T06:00:00+09:00'},
      });
      await pumpTab(tester, s);
      expect(find.byKey(const Key('kec_new_notice')), findsNothing);
      final lines = tester
          .widget<Text>(find.byKey(const Key('kec_basis_lines')))
          .data!;
      expect(lines, contains('요약 기준: 공고 제2025-227호(2026-01-05 발령)'));
      expect(lines, contains('새 공고 없음'));
      expect(lines, contains('출처: 법제처 국가법령정보센터'));
    });

    testWidgets('확인을 못 했으면 그 이유를 보인다', (tester) async {
      final s = mergeKecState(bundled(), {
        'check': {'ok': false, 'message': '법제처 API 인증값이 아직 없습니다'},
      });
      await pumpTab(tester, s);
      final lines = tester
          .widget<Text>(find.byKey(const Key('kec_basis_lines')))
          .data!;
      expect(lines, contains('개정 확인을 못 했습니다: 법제처 API 인증값이 아직 없습니다'));
    });

    testWidgets('서버 요약(더 높은 판)이 있으면 그 카드를 그린다', (tester) async {
      final s = mergeKecState(bundled(), {
        'content': serverContent(99, '서버에서 고친 안내'),
      });
      await pumpTab(tester, s);
      expect(find.text('서버에서 고친 안내'), findsOneWidget);
      expect(find.text('새 요약 카드'), findsOneWidget);
    });
  });

  testWidgets('현장 자료를 전기 기준 탭으로 바로 열 수 있다(알림에서)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: TubeReferencePage(initialTab: kRefKecTabIndex)),
    );
    await tester.pumpAndSettle();
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, kRefKecTabIndex);
    // Firebase가 없으면(시험) 앱에 든 요약을 그린다.
    expect(find.textContaining('조문 번호·수치가 없습니다'), findsOneWidget);
  });
}
