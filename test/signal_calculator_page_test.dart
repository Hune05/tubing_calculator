// 4-20mA 계산기 화면 — 환산, 교정 점검 판정, 루프 전압, 좁은 폰.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/instrument/cal_record.dart';
import 'package:tubing_calculator/src/presentation/instrument/cal_records_page.dart';
import 'package:tubing_calculator/src/presentation/instrument/signal_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/screens/steel_pdf_preview_page.dart';

Future<void> pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: SignalCalculatorPage()));
  await tester.pumpAndSettle();
}

String textIn(WidgetTester tester, Key key) => tester
    .widgetList<Text>(
      find.descendant(of: find.byKey(key), matching: find.byType(Text)),
    )
    .map((t) => t.data ?? '')
    .join('\n');

Future<void> openTab(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  // 입력 보관(draft)이 시험 사이에 넘어가지 않게 매번 비운다.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('환산: 0~10bar에서 12mA → 5 bar, 50%, 5점 표', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byKey(const Key('sg_value')), '12');
    await tester.pump();
    final r = textIn(tester, const Key('sg_conv_result'));
    expect(r, startsWith('측정값\n5 bar'));
    expect(r, contains('측정 범위의 50%'));
    expect(r, contains('3 V (250Ω)'));
    expect(r, contains('정상 구간'));
    final t = textIn(tester, const Key('sg_table'));
    expect(t, contains('7.5 bar'));
    expect(t, contains('16'));
  });

  testWidgets('환산: 측정값 7.5 → 16mA, 3.5mA는 고장 신호 알림', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('sg_in_pv')));
    await tester.enterText(find.byKey(const Key('sg_value')), '7.5');
    await tester.pump();
    expect(textIn(tester, const Key('sg_conv_result')), contains('16 mA'));
    await tester.tap(find.byKey(const Key('sg_in_ma')));
    await tester.enterText(find.byKey(const Key('sg_value')), '3.5');
    await tester.pump();
    expect(textIn(tester, const Key('sg_conv_result')), contains('고장 신호(하한)'));
  });

  testWidgets('교정 점검: ±0.5%, 50% 점 12.1mA → 불합격, 나머지 합격', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'sg_tab_cal');
    await tester.tap(find.byKey(const Key('sc_tol_0.5')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('sc_read_0')), '4.02');
    await tester.enterText(find.byKey(const Key('sc_read_2')), '12.1');
    await tester.enterText(find.byKey(const Key('sc_read_4')), '19.96');
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('sc_err_0'))).data,
      contains('+0.13% · +0.02 mA'),
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('sc_err_2'))).data,
      startsWith('불합격 · 오차 +0.63%'),
    );
    final r = textIn(tester, const Key('sg_cal_result'));
    expect(r, contains('+0.63%'));
    expect(r, contains('조정 전 불합격: 1점 허용오차 초과'));
    expect(r, contains('불합격 점: 50%'));
    // 고치고 나면 합격
    await tester.enterText(find.byKey(const Key('sc_read_2')), '12.03');
    await tester.pump();
    expect(
      textIn(tester, const Key('sg_cal_result')),
      contains('합격: 3점 모두 ±0.5% 이내'),
    );
  });

  testWidgets('교정 점검: 범위를 환산 탭에서 바꾸면 같이 바뀌고, 지시값으로도 셈', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byKey(const Key('sg_urv')), '200');
    await tester.enterText(find.byKey(const Key('sg_unit')), 'C');
    await openTab(tester, 'sg_tab_cal');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('sc_urv')))
          .controller!
          .text,
      '200',
    );
    await tester.tap(find.byKey(const Key('sc_kind_pv')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('sc_read_2')), '99.2');
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('sc_err_2'))).data,
      '오차 -0.4% · -0.064 mA · -0.8 C',
    );
  });

  testWidgets('루프 전압: 24V·250Ω·1.5sq 500m → 23mA에서 17.97V 충분', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'sg_tab_loop');
    await tester.enterText(find.byKey(const Key('sl_len')), '500');
    await tester.pump();
    final r = textIn(tester, const Key('sl_result'));
    // 1.5sq 20°C 12.1Ω/km × 1km = 12.1Ω, 합 262.1Ω → 24 − 0.023 × 262.1 = 17.97
    expect(r, contains('17.97 V'));
    expect(r, contains('23mA 때 계기 단자 전압: 충분'));
    expect(r, contains('루프 총저항 262.1Ω'));
    await tester.enterText(find.byKey(const Key('sl_hart')), '700');
    await tester.pump();
    expect(textIn(tester, const Key('sl_result')), contains('20mA도 낼 수 없습니다'));
  });

  testWidgets('좁은 폰(344)·큰 글씨에서 세 탭이 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(344, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: const SignalCalculatorPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sg_value')), '12');
    await tester.pump();
    expect(tester.takeException(), isNull);
    for (final t in ['sg_tab_cal', 'sg_tab_loop', 'sg_tab_conv']) {
      await tester.tap(find.byKey(Key(t)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: t);
    }
    await tester.tap(find.byKey(const Key('sg_tab_cal')));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('sc_read_0')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.enterText(find.byKey(const Key('sc_read_0')), '4.02');
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.dragUntilVisible(
      find.byKey(const Key('sc_save')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('지시값으로 넣으면 점마다 환산 mA(역산), 환산 탭도 역산 제목', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('sg_in_pv')));
    await tester.enterText(find.byKey(const Key('sg_value')), '5');
    await tester.pump();
    expect(
      textIn(tester, const Key('sg_conv_result')),
      startsWith('출력 전류(역산)\n12 mA'),
    );
    await openTab(tester, 'sg_tab_cal');
    await tester.tap(find.byKey(const Key('sc_kind_pv')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('sc_read_2')), '5.1');
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('sc_flow_2'))).data,
      '환산 mA 12.16 (지시값 역산)',
    );
  });

  testWidgets('조정 전·후를 따로 넣고 요약에 다른 쪽 결과가 한 줄로', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'sg_tab_cal');
    await tester.tap(find.byKey(const Key('sc_tol_0.5')));
    await tester.enterText(find.byKey(const Key('sc_read_2')), '12.1');
    await tester.pump();
    expect(textIn(tester, const Key('sg_cal_result')), contains('조정 전 불합격'));
    await tester.tap(find.byKey(const Key('sc_phase_left')));
    await tester.pump();
    // 조정 후 칸은 비어 있다
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('sc_read_2')))
          .controller!
          .text,
      '',
    );
    await tester.enterText(find.byKey(const Key('sc_read_2')), '12.01');
    await tester.pump();
    final r = textIn(tester, const Key('sg_cal_result'));
    expect(r, contains('조정 후 합격: 1점 모두 ±0.5% 이내'));
    expect(r, contains('조정 전: 최대 오차 +0.63% · 불합격'));
  });

  testWidgets('기록 저장 → 저장한 기록 목록 → 불러오기', (tester) async {
    SharedPreferences.setMockInitialValues({'user_real_name': '차재훈'});
    await pumpPage(tester);
    await openTab(tester, 'sg_tab_cal');
    // 값 없이 저장하면 안내만
    await tester.tap(find.byKey(const Key('sc_save')));
    await tester.pumpAndSettle();
    expect(find.text('측정값을 한 점 이상 넣으십시오.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sc_tol_0.5')));
    await tester.enterText(find.byKey(const Key('sc_read_0')), '4.02');
    await tester.enterText(find.byKey(const Key('sc_read_2')), '12.1');
    await tester.tap(find.byKey(const Key('sc_phase_left')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('sc_read_2')), '12.01');
    await tester.pump();
    await tester.tap(find.byKey(const Key('sc_save')));
    await tester.pumpAndSettle();
    // 작업자는 앱 사용자 이름으로 채워져 있다
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('cs_worker')))
          .controller!
          .text,
      '차재훈',
    );
    // 태그 없이 저장하면 막는다
    await tester.tap(find.byKey(const Key('cs_save')));
    await tester.pumpAndSettle();
    expect(find.text('태그 번호를 넣으십시오'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('cs_tag')), 'PT-101');
    await tester.tap(find.byKey(const Key('cs_save')));
    await tester.pumpAndSettle();
    expect(find.text('PT-101 기록을 저장했습니다.'), findsOneWidget);
    expect(find.byKey(const Key('sc_editing')), findsOneWidget);
    final saved = await CalRecordStore.load();
    expect(saved.single.tag, 'PT-101');
    expect(saved.single.foundSummary.pass, isFalse);
    expect(saved.single.finalPass, isTrue);

    // 새 점검으로 비우고, 목록에서 불러오기
    await tester.tap(find.byKey(const Key('sc_new')));
    await tester.pumpAndSettle();
    expect(find.text('새로 시작'), findsWidgets); // 확인 창
    await tester.tap(find.byKey(const Key('sc_confirm_ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sc_editing')), findsNothing);
    await tester.tap(find.byKey(const Key('sc_records')));
    await tester.pumpAndSettle();
    expect(find.text('PT-101'), findsOneWidget);
    expect(find.text('합격'), findsOneWidget);
    await tester.tap(find.byKey(Key('cr_item_${saved.single.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cr_act_load')));
    await tester.pumpAndSettle();
    expect(find.text('PT-101 기록을 불러왔습니다.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('sc_read_2')))
          .controller!
          .text,
      '12.1',
    );
  });

  testWidgets('저장한 기록 지우기는 확인을 받는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await CalRecordStore.put(
      CalRecord(
        id: 'z',
        date: DateTime(2026, 9, 26),
        tag: 'LT-9',
        lrv: 0,
        urv: 1,
        found: const [CalEntry(reading: 4)],
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: CalRecordsPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cr_item_z')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cr_act_delete')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('LT-9 2026-09-26 00:00 기록을 지우겠습니까?'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('cr_delete_ok')));
    await tester.pumpAndSettle();
    expect(await CalRecordStore.load(), isEmpty);
    expect(find.textContaining('저장한 기록이 없습니다'), findsOneWidget);
  });

  testWidgets('성적서 보기는 미리보기로 열린다(공유는 단추를 눌러야만)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await CalRecordStore.put(
      CalRecord(
        id: 'q',
        date: DateTime(2026, 9, 26),
        tag: 'LT-9',
        lrv: 0,
        urv: 1,
        found: const [CalEntry(reading: 4)],
      ),
    );
    pdfPreviewBuilder = (bytes, name) =>
        Text('미리보기 $name ${bytes.length > 1000}');
    await tester.pumpWidget(const MaterialApp(home: CalRecordsPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cr_item_q')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('cr_act_pdf')));
      for (
        var i = 0;
        i < 40 && find.textContaining('미리보기 cal_').evaluate().isEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('미리보기 cal_LT-9_20260926.pdf true'), findsOneWidget);
    expect(find.text('교정 성적서 미리보기'), findsOneWidget);
  });
  testWidgets('전송기 제곱근 출력: 차압 25%(범위 0~100 kPa) → 12mA, 유량 50%', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.enterText(find.byKey(const Key('sg_urv')), '100');
    await tester.enterText(find.byKey(const Key('sg_unit')), 'kPa');
    await tester.tap(find.byKey(const Key('sg_tf_sqrtOut')));
    await tester.tap(find.byKey(const Key('sg_in_pv')));
    await tester.enterText(find.byKey(const Key('sg_value')), '25');
    await tester.pump();
    final r = textIn(tester, const Key('sg_conv_result'));
    expect(r, startsWith('출력 전류(역산)\n12 mA'));
    expect(r, contains('유량 50% (mA는 유량에 비례)'));
  });

  testWidgets('mA 입력 → 지시값: 50% 점은 12mA 입력, 이론값 5 bar, 5.05 읽으면 +0.5%', (
    tester,
  ) async {
    await pumpPage(tester);
    await openTab(tester, 'sg_tab_cal');
    await tester.tap(find.byKey(const Key('sc_kind_maIn')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('sc_expected_2'))).data,
      '이론값 5 bar',
    );
    await tester.enterText(find.byKey(const Key('sc_read_2')), '5.05');
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('sc_err_2'))).data,
      '오차 +0.5% · +0.08 mA · +0.05 bar',
    );
    expect(find.byKey(const Key('sc_flow_2')), findsOneWidget);
  });

  testWidgets('값이 있을 때 측정 방법을 바꾸면 묻고, 취소하면 그대로', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'sg_tab_cal');
    await tester.enterText(find.byKey(const Key('sc_read_2')), '12.1');
    await tester.pump();
    await tester.tap(find.byKey(const Key('sc_kind_pv')));
    await tester.pumpAndSettle();
    expect(find.text('측정 방법 바꾸기'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sc_flow_2')), findsNothing); // 아직 mA 방법
    await tester.tap(find.byKey(const Key('sc_kind_pv')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sc_kind_ok')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('sc_read_2')))
          .controller!
          .text,
      '',
    );
    expect(textIn(tester, const Key('sc_settings')), contains('루프 지시값'));
  });

  testWidgets('합격이지만 허용오차의 50%를 넘으면 조정 권장, 설정은 한 줄로 접힌다', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'sg_tab_cal');
    await tester.tap(find.byKey(const Key('sc_tol_0.5')));
    await tester.enterText(find.byKey(const Key('sc_read_2')), '12.05');
    await tester.pump();
    final r = textIn(tester, const Key('sg_cal_result'));
    expect(r, contains('조정 전 합격'));
    expect(r, contains('조정 권장: 50% 점'));
    expect(
      tester.widget<Text>(find.byKey(const Key('sc_mini'))).data,
      '조정 전 · 최대 오차 +0.31% · 합격',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('sc_settings_line'))).data,
      '0 bar ~ 10 bar · 선형 · 전송기 출력(mA) · ±0.5%',
    );
    await tester.tap(find.byKey(const Key('sc_settings_toggle')));
    await tester.pump();
    expect(find.byKey(const Key('sc_tol')), findsNothing);
    expect(find.byKey(const Key('sc_read_2')), findsOneWidget);
  });

  testWidgets('이 표 지우기는 확인을 받고 지금 구분만 지운다', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'sg_tab_cal');
    await tester.enterText(find.byKey(const Key('sc_read_2')), '12.1');
    await tester.tap(find.byKey(const Key('sc_phase_left')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('sc_read_2')), '12.0');
    await tester.pump();
    await tester.tap(find.byKey(const Key('sc_clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sc_confirm_ok')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('sc_read_2')))
          .controller!
          .text,
      '',
    );
    await tester.tap(find.byKey(const Key('sc_phase_found')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('sc_read_2')))
          .controller!
          .text,
      '12.1',
    );
  });

  testWidgets('루프 전압: 확인 전류 21mA를 고르면 18.5V, 지시계 전압 강하 2V를 빼면 16.5V', (
    tester,
  ) async {
    await pumpPage(tester);
    await openTab(tester, 'sg_tab_loop');
    await tester.enterText(find.byKey(const Key('sl_len')), '500');
    await tester.tap(find.byKey(const Key('sl_cm_21')));
    await tester.pump();
    expect(textIn(tester, const Key('sl_result')), contains('18.5 V'));
    await tester.enterText(find.byKey(const Key('sl_extra')), '2');
    await tester.pump();
    final r = textIn(tester, const Key('sl_result'));
    expect(r, contains('16.5 V'));
    expect(r, contains('최대 루프 저항 548Ω (21mA 기준)'));
  });

  testWidgets('저장 창: 차기 교정일 1년, 주위 조건, 표준기 저장. 태그를 바꾸면 새로 저장이 기본', (
    tester,
  ) async {
    await pumpPage(tester);
    await openTab(tester, 'sg_tab_cal');
    await tester.enterText(find.byKey(const Key('sc_read_2')), '12.0');
    await tester.pump();
    await tester.tap(find.byKey(const Key('sc_save')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('cs_tag')), 'PT-7');
    await tester.enterText(find.byKey(const Key('cs_ref')), 'Fluke 754 #1');
    await tester.enterText(find.byKey(const Key('cs_ambient')), '23°C, 45%RH');
    await tester.tap(find.byKey(const Key('cs_due_12')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cs_save')));
    await tester.pumpAndSettle();
    var saved = await CalRecordStore.load();
    expect(saved.single.ambient, '23°C, 45%RH');
    expect(saved.single.refStd, 'Fluke 754 #1');
    expect(
      saved.single.nextDue!.year * 12 + saved.single.nextDue!.month,
      saved.single.date.year * 12 + saved.single.date.month + 12,
    );
    // 다시 저장 창: 같은 태그면 "고쳐 저장"이 기본, 태그를 바꾸면 "새로 저장"이 기본
    await tester.tap(find.byKey(const Key('sc_save')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ElevatedButton, '고쳐 저장'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('cs_tag')), 'PT-8');
    await tester.pump();
    expect(find.widgetWithText(ElevatedButton, '새로 저장'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cs_save')));
    await tester.pumpAndSettle();
    saved = await CalRecordStore.load();
    expect(saved.map((e) => e.tag).toSet(), {'PT-7', 'PT-8'});
    expect(find.text('성적서 보기'), findsOneWidget); // 저장 알림의 버튼
  });

  testWidgets('화면을 나갔다 다시 열어도 입력한 값이 남는다', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'sg_tab_cal');
    await tester.tap(find.byKey(const Key('sc_tol_0.5')));
    await tester.enterText(find.byKey(const Key('sc_read_2')), '12.1');
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MaterialApp(home: SignalCalculatorPage()));
    await tester.pumpAndSettle();
    await openTab(tester, 'sg_tab_cal');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('sc_read_2')))
          .controller!
          .text,
      '12.1',
    );
    expect(textIn(tester, const Key('sg_cal_result')), contains('조정 전 불합격'));
  });

  testWidgets('저장한 기록 목록: 조정 전 판정도 보이고 CSV 내보내기 버튼이 있다', (tester) async {
    await CalRecordStore.put(
      CalRecord(
        id: 'm',
        date: DateTime(2026, 9, 26),
        tag: 'PT-9',
        lrv: 0,
        urv: 10,
        tolPct: 0.5,
        found: const [CalEntry(), CalEntry(), CalEntry(reading: 12.1)],
        left: const [CalEntry(), CalEntry(), CalEntry(reading: 12.0)],
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: CalRecordsPage()));
    await tester.pumpAndSettle();
    expect(find.text('조정 전 불합격 → 조정 후 합격'), findsOneWidget);
    expect(find.text('합격'), findsOneWidget);
    expect(find.byKey(const Key('cr_csv')), findsOneWidget);
  });
}
