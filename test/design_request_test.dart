// 설계팀에 보내기(10-12, 사용자 "외부 업체에 보내는 것보다 내부 설계팀한테 던져주는 식으로"):
// 같이 쓰는 설정·화면마다 요청 내용 저장, 업체 지시서 → 설계 요청서 바꾸기(요청 표·요청 사항·사진·참고 그림),
// 카톡 요약 글, 형강 브라켓·철판 가공 보내기 탭의 "업체에 / 설계팀에".
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_page.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_pdf.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/design_request.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_page.dart';

// 1×1 흰 PNG
final _png = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  ),
);

BracketPdfInput _vendor() => BracketPdfInput(
  title: '2호기 배관 서포트',
  summary: const [('모양', 'ㄱ자'), ('가공비 기준', '절단 1m'), ('원판 배치', '1장')],
  drawingPng: _png,
  sections: const [
    BracketPdfSection('자를 것·판', ['a']),
    BracketPdfSection('원자재', ['b']),
    BracketPdfSection('일반 노트', ['c']),
    BracketPdfSection('구멍', ['d']),
  ],
  notes: const ['가로대 구멍이 기둥 바로 위'],
  titleBlock: const [('도면 번호', 'BR-01')],
  author: '작성자',
);

void main() {
  group('설정·요청 저장', () {
    test('설정·요청 내용은 JSON으로 그대로 돌아온다, 받는 곳 비우면 설계팀', () {
      const s = DesignSendSettings(
        requester: '홍길동',
        team: '기계설계팀',
        designFirst: true,
      );
      final back = DesignSendSettings.fromJson(
        jsonDecode(jsonEncode(s.toJson())),
      );
      expect(back.requester, '홍길동');
      expect(back.teamName, '기계설계팀');
      expect(back.designFirst, isTrue);
      expect(const DesignSendSettings(team: ' ').teamName, '설계팀');
      const r = DesignRequest(
        loc: '3층 EL+12000',
        due: '2026-10-20',
        note: '보온 50',
        photos: ['/a.jpg'],
      );
      final rb = DesignRequest.fromJson(jsonDecode(jsonEncode(r.toJson())));
      expect(rb.loc, '3층 EL+12000');
      expect(rb.photos, ['/a.jpg']);
      expect(DesignRequest.empty.isEmpty, isTrue);
      expect(rb.isEmpty, isFalse);
    });
  });

  group('설계 요청서', () {
    test('요청 표·요청 사항을 앞에, 업체 몫(원자재·일반 노트·가공비)·서명 칸은 뺌', () {
      final d = designPdfFrom(
        _vendor(),
        docTitle: '형강 브라켓 설계 요청서',
        settings: const DesignSendSettings(team: '설계팀'),
        request: const DesignRequest(
          loc: '3층',
          due: '2026-10-20',
          note: '배관 2줄\n보온 50 포함',
        ),
        requester: '홍길동',
        qty: '4개',
        photos: [('사진 1', _png)],
        today: DateTime(2026, 10, 12),
        dropSummary: const {'가공비 기준', '원판 배치'},
      );
      expect(d.docTitle, '형강 브라켓 설계 요청서');
      expect(d.titleBlock, [
        ('받는 곳', '설계팀'),
        ('요청자', '홍길동'),
        ('요청일', '2026-10-12'),
        ('필요일', '2026-10-20'),
        ('현장 위치', '3층'),
        ('수량', '4개'),
      ]);
      expect(d.summary.map((x) => x.$1), ['모양']);
      // 요청 사항은 요청 표 바로 아래(그림 앞), 업체 몫 구역은 뺌
      expect(d.leadSections.single.title, '요청 사항');
      expect(d.leadSections.single.lines, ['배관 2줄', '보온 50 포함']);
      expect(d.sections.map((x) => x.title), ['자를 것·판', '구멍']);
      expect(d.drawingCaption, startsWith('현장에서 정한 모양(참고)'));
      expect(d.signs, isEmpty); // 사내라 서명 칸 없음
      expect(d.author, '홍길동');
      expect(d.notes, ['가로대 구멍이 기둥 바로 위']);
      expect(d.photos.length, 1);
    });

    test('사진이 든 요청서 PDF가 만들어진다', () async {
      final d = designPdfFrom(
        _vendor(),
        docTitle: '철판 가공 설계 요청서',
        settings: DesignSendSettings.defaults,
        request: DesignRequest.empty,
        requester: '',
        qty: '1장',
        photos: [('사진 1', _png), ('사진 2', _png), ('사진 3', _png)],
      );
      expect(d.titleBlock.firstWhere((x) => x.$1 == '요청자').$2, '-');
      expect(d.leadSections.single.lines, ['-']);
      final bytes = await buildBracketPdf(d, date: DateTime(2026, 10, 12));
      expect(bytes.length, greaterThan(1000));
    });

    test('카톡 요약 글: 어디·무엇·언제까지·요청 사항', () {
      final t = designShareText(
        what: '형강 브라켓',
        job: '배관 서포트',
        settings: const DesignSendSettings(team: '설계팀'),
        request: const DesignRequest(
          loc: '3층',
          due: '2026-10-20',
          note: '보온 50',
          photos: ['/a.jpg', '/b.jpg'],
        ),
        requester: '홍길동',
        body: const ['ㄱ자 · L-50×50×5 · 4개'],
        today: DateTime(2026, 10, 12),
      );
      expect(
        t,
        '[설계 요청] 형강 브라켓 · 배관 서포트\n'
        '받는 곳 설계팀 · 요청 홍길동 · 2026-10-12\n'
        '현장 위치: 3층\n'
        '필요일: 2026-10-20\n'
        'ㄱ자 · L-50×50×5 · 4개\n'
        '요청 사항: 보온 50\n'
        '그림·치수·현장 사진 2장은 설계 요청서 PDF로 보냅니다.',
      );
    });
  });

  group('화면', () {
    Future<void> tap(WidgetTester tester, String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    testWidgets('형강 브라켓: 설계팀에 → 요청 칸, 카톡 글, 요청 내용은 따로 남고 지도에는 안 섞임', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        kDesignSendSettingsKey: jsonEncode(
          const DesignSendSettings(requester: '홍길동').toJson(),
        ),
      });
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: BracketPage(share: (t) async => sent = t, openPlate: (_, _) {}),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'br_tab_send');
      // 처음은 업체에(설정 기본)
      expect(find.byKey(const Key('br_pdf')), findsOneWidget);
      await tap(tester, 'br_to_design');
      expect(find.byKey(const Key('br_pdf')), findsNothing);
      expect(find.byKey(const Key('br_rq_pdf')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('br_rq_loc')), '3층 EL+12000');
      await tester.enterText(find.byKey(const Key('br_rq_note')), '보온 50 포함');
      await tester.pumpAndSettle();
      await tap(tester, 'br_rq_share');
      expect(sent, startsWith('[설계 요청] 형강 브라켓'));
      expect(sent, contains('요청 홍길동'));
      expect(sent, contains('현장 위치: 3층 EL+12000'));
      expect(sent, contains('요청 사항: 보온 50 포함'));
      final p = await SharedPreferences.getInstance();
      final rq = DesignRequest.fromJson(
        jsonDecode(p.getString('steel_bracket_design_request_v1')!),
      );
      expect(rq.loc, '3층 EL+12000');
      await tester.pump(const Duration(seconds: 1));
      final draft = p.getString(BracketPage.draftKey) ?? '';
      expect(draft, isNot(contains('EL+12000')));
      // 비우기(되돌리기 알림)
      await tap(tester, 'br_rq_clear');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('br_rq_loc')))
            .controller!
            .text,
        '',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('철판 가공: 설정이 "설계팀에"면 보내기 탭이 설계팀 쪽으로 열리고 카톡 글', (tester) async {
      SharedPreferences.setMockInitialValues({
        kDesignSendSettingsKey: jsonEncode(
          const DesignSendSettings(team: '기계설계팀', designFirst: true).toJson(),
        ),
      });
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? sent;
      await tester.pumpWidget(
        MaterialApp(home: PlatePage(bend: true, share: (t) async => sent = t)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pl_tab_send')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pl_send_dxf')), findsNothing);
      expect(find.text('기계설계팀에 보내기'), findsOneWidget);
      await tap(tester, 'pl_send_rq_kakao');
      expect(sent, startsWith('[설계 요청] 철판 가공'));
      expect(sent, contains('받는 곳 기계설계팀'));
      await tap(tester, 'pl_to_vendor');
      expect(find.byKey(const Key('pl_send_dxf')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
