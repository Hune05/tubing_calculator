// 10-14 작업 전 안전 점검(TBM) 참석자 명단과 손가락 서명: 서명 글 적기·읽기, 기록 저장, 카톡 글,
// PDF 서명부, 화면에서 "저장하고 다음 사람"으로 여러 명 받기.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/safety/safety_check_model.dart';
import 'package:tubing_calculator/src/presentation/safety/safety_check_page.dart';
import 'package:tubing_calculator/src/presentation/safety/safety_check_pdf.dart';

final _at = DateTime(2026, 10, 14, 7, 50);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('서명 글', () {
    test('칸 크기에 맞춰 0~1000·0~400으로 적고, 가까운 점은 건너뛰고, 그대로 읽힌다', () {
      final sig = encodeSignature(
        [
          [(0, 0), (0.2, 0), (50, 20), (100, 40)],
          [(25, 10)],
        ],
        100,
        40,
      );
      // (0.2,0)은 2칸이라 (0,0)에서 4칸 안이어서 빠진다. 마지막 점은 늘 남는다.
      expect(sig, 'v1:0,0 500,200 1000,400;250,100');
      final back = decodeSignature(sig);
      expect(back.length, 2);
      expect(back.first.last, (1000.0, 400.0));
      expect(decodeSignature('깨짐'), isEmpty);
      expect(encodeSignature(const [], 100, 40), '');
    });

    test('참석자는 기록에 저장했다 그대로 읽히고, 카톡 글에 명수와 서명 수가 붙는다', () {
      final r = SafetyRecord(
        id: '1',
        at: _at,
        people: '대성 홍길동, 김철수',
        lines: const [],
        attendees: const [
          SafetyAttendee('홍길동', company: '대성', sig: 'v1:0,0 10,10'),
          SafetyAttendee('김철수'),
        ],
      );
      final back = SafetyRecord.fromJson(r.toJson())!;
      expect(back.attendees.length, 2);
      expect(back.attendees.first.company, '대성');
      expect(back.attendees.first.signed, isTrue);
      expect(back.signedCount, 1);
      expect(
        buildSafetyCheckText(back),
        endsWith('참석 2명: 대성 홍길동, 김철수 (서명 1명)'),
      );
    });

    test('지난 참석자: 최근 기록 먼저, 같은 이름은 한 번, 예전 글 기록도 읽는다', () {
      final old = SafetyRecord(
        id: 'a',
        at: _at.subtract(const Duration(days: 1)),
        people: '김철수, 이영희',
        lines: const [],
      );
      final now = SafetyRecord(
        id: 'b',
        at: _at,
        lines: const [],
        attendees: const [SafetyAttendee('김철수', company: '한빛', sig: 'v1:1,1')],
      );
      final list = recentAttendees([old, now]);
      expect(list.map((a) => a.name), ['김철수', '이영희']);
      expect(list.first.company, '한빛');
      expect(list.first.sig, '', reason: '칩에는 서명을 옮기지 않는다');
    });
  });

  group('PDF 서명부', () {
    test('서명 받은 기록·예전 글 기록·빈 기록 모두 PDF가 만들어진다', () async {
      for (final r in [
        SafetyRecord(
          id: '1',
          at: _at,
          site: '1층',
          work: '배관',
          lines: const [SafetyLine('작업허가서 확인', SafetyAnswer.yes)],
          attendees: const [
            SafetyAttendee(
              '홍길동',
              company: '대성',
              sig: 'v1:0,0 500,200 1000,400;300,300',
            ),
            SafetyAttendee('김철수'),
          ],
        ),
        SafetyRecord(id: '2', at: _at, people: '홍길동', lines: const []),
        SafetyRecord(id: '3', at: _at, lines: const []),
      ]) {
        final bytes = await buildSafetyCheckPdf(r);
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      }
      expect(
        safetyPdfFileName(
          SafetyRecord(id: '1', at: _at, site: '1층 A', lines: const []),
        ),
        'tbm_1층_A_20261014_0750.pdf',
      );
    });
  });

  testWidgets('화면: 서명 받고 다음 사람, 이름만 적은 사람, 저장하면 기록에 남는다', (tester) async {
    SharedPreferences.setMockInitialValues({
      kSafetyItemsKey: ['가'],
    });
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SafetyCheckPage(share: (_) async {}, now: () => _at),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('safety_att_add')));
    await tester.tap(find.byKey(const Key('safety_att_add')));
    await tester.pumpAndSettle();
    // 이름 없이 저장하면 막는다.
    await tester.tap(find.byKey(const Key('safety_att_save')));
    await tester.pump();
    expect(find.text('이름을 적어야 저장됩니다'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('safety_att_name')), '홍길동');
    await tester.enterText(find.byKey(const Key('safety_att_company')), '대성');
    final pad = find.byKey(const Key('safety_sig_pad'));
    final c = tester.getCenter(pad);
    await tester.timedDragFrom(
      c - const Offset(80, 0),
      const Offset(160, 30),
      const Duration(milliseconds: 300),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('safety_att_next')));
    await tester.pumpAndSettle();

    // 다음 사람 창이 바로 열린다.
    expect(find.byKey(const Key('safety_att_name')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('safety_att_name')), '김철수');
    await tester.tap(find.byKey(const Key('safety_att_save')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('safety_att_count'))).data,
      '2명 · 서명 1명',
    );

    await tester.tap(find.byKey(const Key('safety_yes_가')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('safety_save')));
    await tester.pumpAndSettle();

    final saved = await loadSafetyRecords();
    expect(saved.length, 1);
    final r = saved.single;
    expect(r.attendees.map((a) => a.name), ['홍길동', '김철수']);
    expect(r.attendees.first.company, '대성');
    expect(r.attendees.first.signed, isTrue);
    // 빈 칸에 처음 긋는 획도 점 하나가 아니라 선으로 남는다(안내 글이 사라질 때 끊기던 것).
    expect(
      decodeSignature(r.attendees.first.sig).first.length,
      greaterThan(2),
    );
    expect(r.attendees.last.signed, isFalse);
    expect(r.people, '대성 홍길동, 김철수');
    // 저장하면 참석자 목록은 비고, 다음 점검에서 이름 칩으로 나온다.
    expect(find.byKey(const Key('safety_att_count')), findsNothing);
    await tester.tap(find.byKey(const Key('safety_att_add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety_att_chip_홍길동')), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety_att_chip_홍길동')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('safety_att_company')))
          .controller!
          .text,
      '대성',
    );
  });
}
