// 현장 사진 도장(필드 헬퍼 3번): 찍을 줄 고르기, 설정 켜고 끄기·저장.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/photo_stamp.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_style.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/report_style_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/work_theme.dart';

import 'helpers_text.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('photoStampLines', () {
    final now = DateTime(2026, 9, 25, 14, 32);

    test('현장 이름·시각·위치 세 줄', () {
      expect(
        photoStampLines(
          siteName: '현대 스마트팩토리 3동',
          now: now,
          location: '부산 해운대구',
        ),
        ['현대 스마트팩토리 3동', '2026-09-25 14:32', '부산 해운대구'],
      );
    });

    test('위치를 못 가져오면 그 줄만 뺀다', () {
      expect(
        photoStampLines(siteName: '현대 스마트팩토리 3동', now: now, location: null),
        ['현대 스마트팩토리 3동', '2026-09-25 14:32'],
      );
    });

    test('현장 이름이 없으면 시각만', () {
      expect(photoStampLines(siteName: '', now: now, location: null), [
        '2026-09-25 14:32',
      ]);
    });
  });

  group('ReportStyle.photoStamp', () {
    test('기본은 켬', () {
      expect(ReportStyle().photoStamp, isTrue);
    });

    test('저장한 값(끔)을 그대로 읽는다', () async {
      final s = ReportStyle()..photoStamp = false;
      await saveReportStyle(s);
      ReportStyle.current = ReportStyle(); // 메모리 값 지우고
      final loaded = await loadReportStyle();
      expect(loaded.photoStamp, isFalse);
    });

    test('예전에 저장해 둔 값(이 칸이 아예 없음)은 켬으로 본다', () async {
      final old = ReportStyle()..company = '삼화기전';
      // photoStamp 칸이 생기기 전 저장 형식을 흉내: toJson에서 그 칸만 뺀다.
      final j = old.toJson()..remove('photoStamp');
      final restored = ReportStyle.fromJson(j);
      expect(restored.photoStamp, isTrue);
      expect(restored.company, '삼화기전');
    });
  });

  group('보고서 양식 화면', () {
    setUp(() => ReportStyle.current = ReportStyle());

    testWidgets('사진 도장 스위치: 기본 켬, 끄고 저장하면 남는다', (tester) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: workThemeData(), home: const ReportStylePage()),
      );
      await tester.pumpAndSettle();
      // 제목 글은 keepWords()가 글자 사이 U+2060(단어 잇기)을 끼워 넣어 그냥
      // find.text로는 못 찾는다(findText가 지워 주고 견준다).
      final finder = find.ancestor(
        of: findText("사진에 현장 이름·날짜·위치 찍기"),
        matching: find.byType(SwitchListTile),
      );
      expect(finder, findsOneWidget);
      expect(tester.widget<SwitchListTile>(finder).value, isTrue);

      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(finder).value, isFalse);

      await tester.tap(find.text("저장"));
      await tester.pumpAndSettle();
      final reloaded = await loadReportStyle();
      expect(reloaded.photoStamp, isFalse);
    });
  });
}
