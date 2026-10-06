// 부하 합산(부하 계산서): 순수 계산(손계산 예제·경계값·오류 입력), 저장 모양, 화면, PDF.
// 손계산은 각 시험 위에 식을 적었다.
import 'dart:convert';
import 'formula_flat.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';
import 'package:tubing_calculator/src/data/record_sync.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_load_sum.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_load_sum_pdf.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_load_sum_tab.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/screens/steel_pdf_preview_page.dart';

/// 서버 대신 쓰는 가짜(모음 → 문서 이름 → 칸).
class _FakeRemote implements RecordRemote {
  final Map<String, Map<String, Map<String, dynamic>>> colls = {};
  int clock = 1000000;

  @override
  Future<void> write(String c, String id, Map<String, dynamic> fields) async {
    colls.putIfAbsent(c, () => {})[id] = {
      ...fields,
      'updatedAt': Timestamp.fromMillisecondsSinceEpoch(clock++),
    };
  }

  @override
  Future<RemoteFetch> fetch(String c, String owner) async => RemoteFetch([
    for (final e in (colls[c] ?? const {}).entries)
      if (e.value['owner'] == owner) recordFromServerDoc(e.key, e.value),
  ]);
}

LoadRowInput row(
  String kw, {
  String pf = '',
  String df = '',
  String name = '',
}) => LoadRowInput(name: name, kw: kw, pf: pf, df: df);

void main() {
  setUpAll(expandFormulaCards);
  TestWidgetsFlutterBinding.ensureInitialized();
  group('계산: 손계산 예제', () {
    test('예제 1: 100kW, 수용률 80%, 역률 90% 한 줄', () {
      // P = 100 × 0.8 = 80 kW. tanφ = tan(acos 0.9) = 0.484322. Q = 38.746 kvar.
      // S = 80 ÷ 0.9 = 88.889 kVA. 부등률 1, 여유 0이면 필요 88.889 kVA.
      // I = 88.889 × 1000 ÷ (√3 × 380) = 135.05 A.
      final r = computeLoadSum(
        LoadSumInput(
          rows: [row('100', pf: '90', df: '80')],
        ),
      );
      expect(r.ok, isTrue);
      expect(r.lines.single.p, closeTo(80, 1e-9));
      expect(r.lines.single.q, closeTo(38.7459, 1e-3));
      expect(r.demandKva, closeTo(88.8889, 1e-3));
      expect(r.pf, closeTo(0.9, 1e-9));
      expect(r.requiredKva, closeTo(88.8889, 1e-3));
      expect(r.ratedAmps, closeTo(135.055, 5e-3));
      expect(r.pass, isNull);
    });

    test('예제 2: 두 줄, 역률이 다름, 부등률 1.2, 여유 20%, 440V, 선정 150kVA', () {
      // 1번 100kW, 수용률 50%, 역률 80%: P=50, tanφ=0.75, Q=37.5, S=62.5.
      // 2번 40kW, 수용률 100%, 역률 100%: P=40, Q=0.
      // ΣP=90, ΣQ=37.5, S=√(8100+1406.25)=97.5 kVA, 종합 역률 90÷97.5=0.923077.
      // 필요 = 97.5 ÷ 1.2 × 1.2 = 97.5 kVA. I = 97500 ÷ (√3 × 440) = 127.94 A.
      // 부하율 = 97.5 ÷ 150 = 65%.
      final r = computeLoadSum(
        LoadSumInput(
          rows: [
            row('100', pf: '80', df: '50'),
            row('40', pf: '100', df: '100'),
          ],
          diversity: '1.2',
          margin: '20',
          volts: 440,
          selectedKva: '150',
        ),
      );
      expect(r.ok, isTrue);
      expect(r.totalKw, closeTo(140, 1e-9));
      expect(r.demandKw, closeTo(90, 1e-9));
      expect(r.demandKvar, closeTo(37.5, 1e-9));
      expect(r.demandKva, closeTo(97.5, 1e-9));
      expect(r.pf, closeTo(0.923077, 1e-6));
      expect(r.requiredKva, closeTo(97.5, 1e-9));
      expect(r.ratedAmps, closeTo(127.936, 5e-3));
      expect(r.loadPct, closeTo(65, 1e-9));
      expect(r.loadPctNoMargin, closeTo(54.1667, 1e-3));
      expect(r.pass, isTrue);
    });

    test('예제 3: 세 줄 기본 역률 100%, 부등률 1.3, 여유 10%, 380V', () {
      // P = 50×1.0 + 30×0.6 + 20×0.5 = 50 + 18 + 10 = 78 kW(역률 100%라 kVA도 78).
      // 필요 = 78 ÷ 1.3 × 1.1 = 66 kVA. I = 66000 ÷ (√3 × 380) = 100.28 A.
      final r = computeLoadSum(
        LoadSumInput(
          rows: [
            row('50', df: '100'),
            row('30', df: '60'),
            row('20', df: '50'),
          ],
          defaultPf: '100',
          diversity: '1.3',
          margin: '10',
        ),
      );
      expect(r.ok, isTrue);
      expect(r.demandKw, closeTo(78, 1e-9));
      expect(r.demandKvar, closeTo(0, 1e-9));
      expect(r.requiredKva, closeTo(66, 1e-9));
      expect(r.ratedAmps, closeTo(100.276, 5e-3));
    });

    test('기본 수용률·기본 역률은 빈 칸에만 쓰고, 줄에 적은 값이 우선', () {
      // 기본 수용률 60%, 기본 역률 80%. 1번은 기본값, 2번은 수용률 100%.
      // 1번 P=100×0.6=60, 2번 P=10. 합 P=70.
      final r = computeLoadSum(
        LoadSumInput(
          rows: [
            row('100'),
            row('10', df: '100'),
          ],
          defaultPf: '80',
          defaultDf: '60',
        ),
      );
      expect(r.ok, isTrue);
      expect(r.demandKw, closeTo(70, 1e-9));
      expect(r.lines.first.pfPct, 80);
      expect(r.lines.first.dfPct, 60);
      expect(r.lines.last.dfPct, 100);
    });
  });

  group('계산: 경계값', () {
    LoadSumResult one({
      String kw = '10',
      String pf = '90',
      String df = '50',
      String div = '1.0',
      String margin = '0',
      String sel = '',
    }) => computeLoadSum(
      LoadSumInput(
        rows: [row(kw, pf: pf, df: df)],
        diversity: div,
        margin: margin,
        selectedKva: sel,
      ),
    );

    test('수용률·역률 100%는 되고 100.01%와 0%는 입력 확인', () {
      expect(one(df: '100', pf: '100').ok, isTrue);
      expect(one(df: '100.01').errors.single, contains('수용률'));
      expect(one(df: '0').errors.single, contains('0 초과 100 이하'));
      expect(one(pf: '100.01').errors.single, contains('역률'));
      expect(one(pf: '0').errors.single, contains('0 초과 100 이하'));
      expect(one(df: '0.01').ok, isTrue);
    });

    test('부등률 1은 되고 1 미만은 입력 확인, 비우면 1', () {
      expect(one(div: '1').ok, isTrue);
      final low = one(div: '0.99');
      expect(low.ok, isFalse);
      expect(low.errors.single, contains('부등률'));
      expect(low.errors.single, contains('1 이상'));
      expect(one(div: '').diversity, 1);
      expect(one(div: '0').ok, isFalse);
    });

    test('여유: 0은 되고 음수는 입력 확인, 비우면 0', () {
      expect(one(margin: '0').ok, isTrue);
      expect(one(margin: '').marginPct, 0);
      expect(one(margin: '-1').errors.single, contains('여유'));
    });

    test('선정 용량 100%는 합격, 100% 초과는 불합격', () {
      // 부하 10kW × 0.5 = 5kW, 역률 90% → S = 5.5556 kVA.
      final s = one().requiredKva;
      expect(s, closeTo(5.5556, 1e-3));
      expect(one(sel: '$s').pass, isTrue);
      expect(one(sel: '$s').loadPct, closeTo(100, 1e-6));
      expect(one(sel: '5.5').pass, isFalse);
      expect(one(sel: '5.5').loadPct!, greaterThan(100));
      expect(one(sel: '6').pass, isTrue);
      expect(one(sel: '0').errors.single, contains('선정 변압기 용량'));
      expect(one(sel: '-50').ok, isFalse);
    });
  });

  group('계산: 잘못된 입력은 조용히 고치지 않고 입력 확인', () {
    test('음수·0 설비용량, 글자, 너무 큰 값', () {
      expect(
        computeLoadSum(
          LoadSumInput(
            rows: [row('-5', pf: '90', df: '50')],
          ),
        ).errors,
        isNotEmpty,
      );
      expect(
        computeLoadSum(
          LoadSumInput(
            rows: [row('0', pf: '90', df: '50')],
          ),
        ).ok,
        isFalse,
      );
      final abc = computeLoadSum(
        LoadSumInput(
          rows: [row('abc', pf: '90', df: '50')],
        ),
      );
      expect(abc.errors.single, contains('숫자가 아닙니다'));
      expect(
        computeLoadSum(
          LoadSumInput(
            rows: [row('NaN', pf: '90', df: '50')],
          ),
        ).ok,
        isFalse,
      );
      expect(
        computeLoadSum(
          LoadSumInput(
            rows: [row('Infinity', pf: '90', df: '50')],
          ),
        ).ok,
        isFalse,
      );
      expect(
        computeLoadSum(
          LoadSumInput(
            rows: [row('1000001', pf: '90', df: '50')],
          ),
        ).errors.single,
        contains('너무 큽니다'),
      );
    });

    test('오류 줄이 있으면 다른 줄이 맞아도 결과를 내지 않고 줄 번호를 알린다', () {
      final r = computeLoadSum(
        LoadSumInput(
          rows: [
            row('10', pf: '90', df: '50'),
            const LoadRowInput(),
            row('20', pf: '90', df: '150', name: '펌프'),
          ],
        ),
      );
      expect(r.ok, isFalse);
      expect(r.errors.single, startsWith('3번 줄(펌프)'));
      expect(r.requiredKva, 0);
    });

    test('역률·수용률이 비었고 기본값도 없으면 입력 확인', () {
      final r = computeLoadSum(LoadSumInput(rows: [row('10')]));
      expect(r.errors.length, 2);
      expect(r.errors.first, contains('기본 역률'));
      expect(r.errors.last, contains('기본 수용률'));
    });

    test('이름만 있고 kW가 없으면 입력 확인, 완전히 빈 줄은 건너뜀', () {
      final r = computeLoadSum(
        LoadSumInput(
          rows: [const LoadRowInput(name: '팬')],
          defaultPf: '90',
        ),
      );
      expect(r.errors.first, contains('설비용량(kW)'));
      final blank = computeLoadSum(
        const LoadSumInput(rows: [LoadRowInput(), LoadRowInput()]),
      );
      expect(blank.noLines, isTrue);
      expect(blank.ok, isFalse);
      expect(blank.errors, isEmpty);
    });

    test('기본값 칸이 범위 밖이면 입력 확인', () {
      final r = computeLoadSum(
        LoadSumInput(
          rows: [row('10', pf: '90', df: '50')],
          defaultPf: '120',
          defaultDf: 'x',
        ),
      );
      expect(r.errors.length, 2);
    });

    test('30줄까지, 31줄은 입력 확인', () {
      final ok = computeLoadSum(
        LoadSumInput(
          rows: [for (var i = 0; i < 30; i++) row('1', pf: '100', df: '100')],
        ),
      );
      expect(ok.ok, isTrue);
      expect(ok.totalKw, 30);
      final over = computeLoadSum(
        LoadSumInput(
          rows: [for (var i = 0; i < 31; i++) row('1', pf: '100', df: '100')],
        ),
      );
      expect(over.ok, isFalse);
      expect(over.errors.first, contains('30줄'));
    });

    test('쉼표가 든 큰 수는 읽는다', () {
      final r = computeLoadSum(
        LoadSumInput(
          rows: [row('1,500', pf: '100', df: '100')],
        ),
      );
      expect(r.totalKw, 1500);
    });
  });

  group('저장 모양', () {
    test('입력 JSON 왕복과 깨진 글', () {
      final i = LoadSumInput(
        rows: [row('12.5', pf: '85', df: '70', name: '팬')],
        defaultPf: '90',
        diversity: '1.1',
        margin: '15',
        volts: 480,
        selectedKva: '200',
        site: '1호기',
        memo: '메모',
      );
      final back = LoadSumInput.fromJson(jsonDecode(jsonEncode(i.toJson())));
      expect(back.rows.single.name, '팬');
      expect(back.rows.single.kw, '12.5');
      expect(back.volts, 480);
      expect(back.margin, '15');
      expect(back.site, '1호기');
      expect(LoadSumInput.fromJson('쓰레기').rows, isEmpty);
      expect(LoadSumInput.fromJson({'v': 123}).volts, 123, reason: '칩에 없는 전압도 직접 입력으로 받는다');
      expect(LoadSumInput.fromJson({'v': 0}).volts, 380);
      expect(decodeLoadSheets('{깨짐'), isEmpty);
      expect(decodeLoadSheets(null), isEmpty);
      expect(decodeLoadSheets('[1, {"name": "가"}]').single.name, '가');
    });

    test('저장한 계산서 목록은 폰 저장 칸에 들어가고 서버 없이 읽힌다', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await LoadSheetStore.load(), isEmpty);
      final s = LoadSheet(
        name: '1호기',
        savedAt: DateTime(2026, 9, 27),
        input: LoadSumInput(
          rows: [row('10', pf: '90', df: '50')],
        ),
      );
      expect(await LoadSheetStore.save([s]), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('elec_load_sheets_v1'), isNotNull);
      final back = await LoadSheetStore.load();
      expect(back.single.name, '1호기');
      expect(back.single.savedAt, DateTime(2026, 9, 27));
      expect(back.single.input.rows.single.kw, '10');
    });
  });

  group('폰↔태블릿 계산서 맞추기', () {
    test('예전에 저장한 계산서(이름표 없음)는 읽을 때 이름표가 붙어 저장된다', () async {
      SharedPreferences.setMockInitialValues({
        'elec_load_sheets_v1':
            '[{"name":"1호기","at":"2026-09-20T09:00:00.000","input":{}}]',
      });
      final a = await LoadSheetStore.load();
      expect(a.single.id, startsWith('ls_'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('elec_load_sheets_v1'), contains(a.single.id));
      // 다시 읽어도 같은 이름표.
      expect((await LoadSheetStore.load()).single.id, a.single.id);
    });

    test('새 것이 위로 온다', () async {
      SharedPreferences.setMockInitialValues({});
      final a = LoadSheet(
        name: '가',
        savedAt: DateTime(2026, 9, 1),
        input: LoadSumInput(rows: []),
      );
      final b = LoadSheet(
        name: '나',
        savedAt: DateTime(2026, 9, 5),
        input: LoadSumInput(rows: []),
      );
      await LoadSheetStore.save([a, b]);
      expect((await LoadSheetStore.load()).map((s) => s.name), ['나', '가']);
    });

    test('폰에서 저장한 계산서가 서버를 거쳐 태블릿에서 보이고, 지우면 사라진다', () async {
      final server = _FakeRemote();
      recordRemote = () => server;
      recordOwner = () async => const RecordOwner('작업자', 'uid-A');
      addTearDown(() {
        recordRemote = () => null;
      });

      // 폰에서 저장
      SharedPreferences.setMockInitialValues({});
      final s = LoadSheet(
        name: '1호기',
        savedAt: DateTime(2026, 9, 27),
        input: LoadSumInput(
          rows: [row('10', pf: '90', df: '50')],
        ),
      );
      await LoadSheetStore.save([s]);
      await LoadSheetStore.sync.saved(s.id);
      await RecordSync.idle();
      expect(server.colls['elec_load_sheets']![s.id]!['owner'], '작업자');
      final phone = <String, Object>{
        for (final k in (await SharedPreferences.getInstance()).getKeys())
          k: (await SharedPreferences.getInstance()).get(k)!,
      };

      // 태블릿(빈 저장)에서 열면 받는다
      SharedPreferences.setMockInitialValues({});
      await LoadSheetStore.sync.syncNow();
      final got = await LoadSheetStore.load();
      expect(got.single.name, '1호기');
      expect(got.single.input.rows.single.kw, '10');

      // 태블릿에서 지우면 폰에서도 사라진다
      await LoadSheetStore.save([]);
      await LoadSheetStore.sync.removed(s.id);
      await RecordSync.idle();
      SharedPreferences.setMockInitialValues(phone);
      await LoadSheetStore.sync.syncNow();
      expect(await LoadSheetStore.load(), isEmpty);
    });
  });

  group('화면', () {
    Future<void> pumpTab(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: FieldViewTheme(child: Scaffold(body: ElecLoadSumTab())),
        ),
      );
      await tester.pumpAndSettle();
    }

    // 화면 밖에 있는 칸은 목록을 밀어 그린 뒤 눈에 보이게 한다.
    Future<void> show(WidgetTester tester, String key) async {
      final f = find.byKey(Key(key));
      if (f.evaluate().isEmpty) {
        // 목록을 아래로 먼저 밀어 보고, 못 찾으면 위로 올려 다시 찾는다(화면이 길어지면 칸이 위쪽에 있을 수 있다).
        for (final dy in [300.0, -300.0]) {
          try {
            await tester.scrollUntilVisible(
              f,
              dy,
              scrollable: find.byType(Scrollable).first,
              maxScrolls: 60,
            );
            break;
          } catch (_) {
            if (dy < 0) rethrow;
          }
        }
      }
      await tester.ensureVisible(f);
      await tester.pump();
    }

    Future<void> type(WidgetTester tester, String key, String text) async {
      await show(tester, key);
      await tester.enterText(find.byKey(Key(key)), text);
      await tester.pump();
    }

    Future<void> tapKey(WidgetTester tester, String key) async {
      await show(tester, key);
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    // 화면이 길어도 첫 줄이 그려지도록 맨 위로 올린다.
    Future<void> toTop(WidgetTester tester) async {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 8000));
      await tester.pumpAndSettle();
    }

    // 불러오기 뒤에는 줄 번호표(키)가 새로 매겨지므로 첫 설비용량 칸을 화면 순서로 찾는다.
    String firstKwText(WidgetTester tester) => tester
        .widgetList<TextField>(
          find.byWidgetPredicate(
            (w) =>
                w is TextField &&
                w.key is ValueKey<String> &&
                (w.key as ValueKey<String>).value.startsWith('els_kw_'),
            // 결과 상자가 길어져 첫 줄이 화면 밖으로 밀려도 찾는다.
            skipOffstage: false,
          ),
        )
        .first
        .controller!
        .text;

    String sum(WidgetTester tester) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(const Key('els_sum')),
            matching: find.byType(Text),
          ),
        )
        .data!;

    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('처음에는 부하를 넣으라고 알리고 줄 3개가 있다', (tester) async {
      await pumpTab(tester);
      expect(sum(tester), '부하를 넣으십시오');
      expect(find.byKey(const Key('els_kw_0')), findsOneWidget);
      expect(find.byKey(const Key('els_kw_2')), findsOneWidget);
      expect(find.text('줄 추가 (3/30)'), findsOneWidget);
    });

    testWidgets('줄 추가·삭제와 계산(예제 1)', (tester) async {
      await pumpTab(tester);
      await type(tester, 'els_kw_0', '100');
      // 역률·수용률이 비었고 기본값도 없다: 입력 확인.
      expect(sum(tester), startsWith('입력 확인'));
      await type(tester, 'els_pf_0', '90');
      await type(tester, 'els_df_0', '80');
      expect(sum(tester), '최대수요 80 kW · 필요 88.9 kVA');
      expect(find.text('88.9 kVA'), findsOneWidget);
      expect(allFlat(tester), contains(flat('(√3 × 380 V) = 135.1 A (3상)')));

      await tester.tap(find.byKey(const Key('els_add')));
      await tester.pump();
      expect(find.byKey(const Key('els_kw_3')), findsOneWidget);
      expect(find.text('줄 추가 (4/30)'), findsOneWidget);

      // 4번 줄에 기본값을 쓰는 부하: 기본 역률·수용률 칸을 채운다.
      await type(tester, 'els_def_pf', '80');
      await type(tester, 'els_def_df', '50');
      await type(tester, 'els_kw_3', '40');
      // 추가 P = 20, S = 25. 합 P = 100, Q = 38.746 + 15 = 53.746, S = 113.5.
      expect(
        find.textContaining('최대수요 100 kW, 53.7 kvar, 113.5 kVA'),
        findsOneWidget,
      );

      // X 단추는 없고, 줄을 왼쪽으로 밀어 지운다.
      expect(find.byKey(const Key('els_del_3')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('els_name_3')));
      await tester.pumpAndSettle();
      // 글 칸은 글자 고르기로 밀기를 먹으므로 줄 번호를 잡고 민다.
      await tester.drag(find.text('4번').first, const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('els_kw_3')), findsNothing);
      expect(find.text('줄 추가 (3/30)'), findsOneWidget);
      expect(sum(tester), '최대수요 80 kW · 필요 88.9 kVA');
      // 되돌리기로 같은 값이 같은 자리에 다시 들어온다.
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(find.text('줄 추가 (4/30)'), findsOneWidget);
      expect(
        find.textContaining('최대수요 100 kW, 53.7 kvar, 113.5 kVA'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('30줄에서는 줄 추가가 막힌다', (tester) async {
      await pumpTab(tester);
      for (var i = 0; i < 27; i++) {
        await tester.ensureVisible(find.byKey(const Key('els_add')));
        await tester.tap(find.byKey(const Key('els_add')));
        await tester.pump();
      }
      expect(find.text('줄 추가 (30/30)'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('els_add')))
            .onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('부등률 1 미만은 입력 확인 경고, 고치면 결과가 나온다', (tester) async {
      await pumpTab(tester);
      await type(tester, 'els_kw_0', '100');
      await type(tester, 'els_pf_0', '90');
      await type(tester, 'els_df_0', '80');
      await type(tester, 'els_diversity', '0.8');
      expect(sum(tester), '입력 확인: 1건');
      expect(find.text('입력 확인'), findsOneWidget);
      expect(find.textContaining('부등률: 1 이상으로 넣으십시오'), findsOneWidget);
      // 입력 확인 중에는 계산서 PDF 단추가 꺼진다.
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('els_pdf'))).onPressed,
        isNull,
      );
      await type(tester, 'els_diversity', '1.25');
      // 88.889 ÷ 1.25 = 71.1 kVA.
      expect(sum(tester), '최대수요 80 kW · 필요 71.1 kVA');
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('수용률 100% 초과와 음수 설비용량은 입력 확인', (tester) async {
      await pumpTab(tester);
      await type(tester, 'els_kw_0', '-10');
      await type(tester, 'els_pf_0', '90');
      await type(tester, 'els_df_0', '120');
      expect(sum(tester), '입력 확인: 2건');
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('선정 용량: 부하율 합격, 100% 초과는 불합격', (tester) async {
      await pumpTab(tester);
      await type(tester, 'els_kw_0', '100');
      await type(tester, 'els_pf_0', '90');
      await type(tester, 'els_df_0', '80');
      await type(tester, 'els_selected', '100');
      expect(sum(tester), contains('부하율 88.9% 합격'));
      await type(tester, 'els_selected', '75');
      expect(sum(tester), contains('불합격'));
      expect(find.textContaining('선정 용량이 필요 용량보다 작습니다'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('els_v_440')));
      // 위쪽에 고정된 요약 줄에 가리지 않게 목록을 조금 내린다.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 200));
      await tester.pump();
      await tester.tap(find.byKey(const Key('els_v_440')));
      await tester.pump();
      expect(allFlat(tester), contains(flat('(√3 × 440 V)')));
      await tester.pump(const Duration(seconds: 1));
    });

    // 풀이 줄: 100 kW × 80% = 80 kW, Q = 80 × tan(acos 0.9) = 38.7 kvar, S = 88.9 kVA,
    // 필요 = 88.9 ÷ 1.25 × 1.1 = 78.2 kVA, 전류 = 78.2 × 1000 ÷ (√3 × 380) = 118.8 A, 부하율 = 78.2 ÷ 100 = 78.2%.
    testWidgets('결과 상자에 ①~⑤ 단계 풀이가 식과 숫자로 나온다', (tester) async {
      await pumpTab(tester);
      await type(tester, 'els_name_0', '모터');
      await type(tester, 'els_kw_0', '100');
      await type(tester, 'els_pf_0', '90');
      await type(tester, 'els_df_0', '80');
      await type(tester, 'els_diversity', '1.25');
      await type(tester, 'els_margin', '10');
      await type(tester, 'els_selected', '100');
      expect(allFlat(tester), contains(flat('1번 모터: P = 100 × 80% = 80 kW, Q = 80 × tan(acos 0.9) = 38.7 kvar')));
      expect(allFlat(tester), contains(flat('S = √(ΣP² + ΣQ²) = √(80² + 38.7²) = 88.9 kVA')));
      expect(allFlat(tester), contains(flat('종합 역률 = ΣP ÷ S = 80 ÷ 88.9 = 90%')));
      expect(allFlat(tester), contains(flat('③ 필요 용량 = S ÷ 부등률 × (1 + 여유) = 88.9 ÷ 1.25 × (1 + 10%) = 78.2 kVA')));
      expect(allFlat(tester), contains(flat('78.2 × 1000 ÷ (√3 × 380 V) = 118.8 A (3상)')));
      expect(allFlat(tester), contains(flat('⑤ 부하율 = 필요 용량 ÷ 선정 용량 × 100 = 78.2 ÷ 100 × 100 = 78.2%: 합격')));
      expect(allFlat(tester), contains(flat('여유를 뺀 부하율 = S ÷ 부등률 ÷ 선정 용량 × 100 = 88.9 ÷ 1.25 ÷ 100 × 100 = 71.1%')));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('부하 줄이 9개 이상이면 8줄까지만 풀고 나머지를 알린다', (tester) async {
      await pumpTab(tester);
      await type(tester, 'els_def_pf', '90');
      await type(tester, 'els_def_df', '80');
      for (var i = 0; i < 10; i++) {
        if (i >= 3) {
          await tester.ensureVisible(find.byKey(const Key('els_add')));
          await tester.tap(find.byKey(const Key('els_add')));
          await tester.pump();
        }
        await type(tester, 'els_kw_$i', '10');
      }
      expect(find.textContaining('나머지 2줄도 같은 식으로 합계에 들어갔습니다.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('입력값은 자동 저장되어 다시 열면 돌아온다', (tester) async {
      await pumpTab(tester);
      await type(tester, 'els_kw_0', '55');
      await type(tester, 'els_pf_0', '85');
      await type(tester, 'els_df_0', '70');
      await tester.tap(find.byKey(const Key('els_add')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('elec_load_sum_draft_v1'), contains('"kw":"55"'));

      await tester.pumpWidget(const SizedBox());
      await pumpTab(tester);
      await toTop(tester);
      expect(firstKwText(tester), '55');
      expect(find.text('줄 추가 (4/30)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('저장·불러오기·지우기는 묻는 창을 거친다', (tester) async {
      await pumpTab(tester);
      await type(tester, 'els_kw_0', '100');
      await type(tester, 'els_pf_0', '90');
      await type(tester, 'els_df_0', '80');
      // 이름 없이 저장하면 알림만.
      await tapKey(tester, 'els_save');
      expect(find.text('저장 이름을 넣으십시오.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));

      await type(tester, 'els_save_name', '1호기 배전반');
      await tapKey(tester, 'els_save');
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('els_open_0')), findsOneWidget);
      // 서버에 못 올리는 폰(로그인 없음)이면 그 사실을 계산서 목록 위에 적는다.
      expect(find.byKey(const Key('els_sync')), findsOneWidget);
      expect(find.textContaining('폰에만 저장됩니다'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('elec_load_sheets_v1'), contains('1호기 배전반'));

      // 값을 바꾸고 불러오기: 묻는 창에서 취소하면 그대로, 확인하면 돌아온다.
      await type(tester, 'els_kw_0', '999');
      await tapKey(tester, 'els_open_0');
      expect(find.textContaining('불러오시겠습니까?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('els_dialog_cancel')));
      await tester.pumpAndSettle();
      await toTop(tester);
      expect(firstKwText(tester), '999');
      await tapKey(tester, 'els_open_0');
      await tester.tap(find.byKey(const Key('els_dialog_ok')));
      await tester.pumpAndSettle();
      await toTop(tester);
      expect(firstKwText(tester), '100');

      // 같은 이름 저장은 덮어쓰기를 묻는다.
      await tapKey(tester, 'els_save');
      expect(find.textContaining('덮어쓰시겠습니까?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('els_dialog_ok')));
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('els_open_1')), findsNothing);

      // 지우기.
      await tapKey(tester, 'els_sheet_del_0');
      expect(find.textContaining('지우시겠습니까?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('els_dialog_ok')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('els_open_0')), findsNothing);
      expect(prefs.getString('elec_load_sheets_v1'), '[]');
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('계산서 PDF 단추는 미리보기 페이지를 연다(공유는 미리보기 단추)', (tester) async {
      final old = pdfPreviewBuilder;
      addTearDown(() => pdfPreviewBuilder = old);
      pdfPreviewBuilder = (bytes, name) =>
          Text('미리보기 $name ${bytes.length > 1000}');
      await pumpTab(tester);
      await type(tester, 'els_kw_0', '100');
      await type(tester, 'els_pf_0', '90');
      await type(tester, 'els_df_0', '80');
      await type(tester, 'els_save_name', '시험');
      await show(tester, 'els_pdf');
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('els_pdf')));
        for (
          var i = 0;
          i < 60 && find.textContaining('미리보기 load_sum_').evaluate().isEmpty;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('미리보기 load_sum_시험_'), findsOneWidget);
      expect(find.text('부하 계산서 미리보기'), findsOneWidget);
      expect(find.byKey(const Key('pdf_preview_share')), findsOneWidget);
    });
  });

  group('PDF', () {
    test('부하 계산서 PDF가 만들어지고 입력 오류 결과로는 만들지 않는다', () async {
      final input = LoadSumInput(
        rows: [
          for (var i = 0; i < 30; i++)
            row('${10 + i}', pf: '85', df: '60', name: '부하 ${i + 1}'),
        ],
        selectedKva: '2000',
        site: '1호기 보조 건물',
        memo: '시험',
      );
      final r = computeLoadSum(input);
      expect(r.ok, isTrue);
      final bytes = await buildLoadSumPdf(
        input,
        r,
        title: '1호기 배전반',
        date: DateTime(2026, 9, 27),
      );
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
      expect(bytes.length, greaterThan(10000));
      final bad = computeLoadSum(
        LoadSumInput(
          rows: [row('-1', pf: '90', df: '50')],
        ),
      );
      expect(() => buildLoadSumPdf(input, bad), throwsStateError);
      expect(
        loadSumFileName('1호기 배전반', DateTime(2026, 9, 7)),
        'load_sum_1호기_배전반_20260907.pdf',
      );
      expect(
        loadSumFileName('', DateTime(2026, 9, 7)),
        'load_sum_noname_20260907.pdf',
      );
    });
  });
}
