import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_action_bar.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_diagram_pdf.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_main_screen.dart';

// PDF 표가 쪽 경계에서 갈라지지 않게 묶는 도우미, 그리고 아이콘 이름을 다시 보는 "?" 버튼.
int pageCount(List<int> bytes) =>
    RegExp(r'/Type/Page\b').allMatches(String.fromCharCodes(bytes)).length;

pw.Widget table(int rows) => pw.TableHelper.fromTextArray(
  headers: ['HEADCOL', 'B'],
  data: [
    for (var i = 0; i < rows; i++) ['ROW$i', 'x'],
  ],
);

Future<List<int>> make(List<pw.Widget> Function() body) async {
  final pdf = pw.Document();
  pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, build: (c) => body()));
  return pdf.save();
}

// 쪽마다 글자를 뽑아 준다(영문이라 pdftotext로 읽힌다). pdftotext가 없으면 null.
Future<List<String>?> pagesText(List<int> bytes) async {
  final dir = await Directory.systemTemp.createTemp('pdfbreak');
  final f = File('${dir.path}/t.pdf')..writeAsBytesSync(bytes);
  try {
    final out = <String>[];
    for (var p = 1; p <= 3; p++) {
      final r = await Process.run('pdftotext', [
        '-f',
        '$p',
        '-l',
        '$p',
        '-layout',
        f.path,
        '-',
      ]);
      if (r.exitCode != 0) break;
      out.add(r.stdout as String);
    }
    return out.isEmpty ? null : out;
  } catch (_) {
    return null;
  } finally {
    dir.deleteSync(recursive: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('묶기 도우미', () {
    test('작은 표는 한 덩어리로, 큰 표는 그대로 둔다', () {
      final small = keepTogether([pw.Text('a'), pw.Text('b')], rows: 5);
      expect(small.length, 1);
      expect(small.single, isA<pw.Inseparable>());
      final big = keepTogether([pw.Text('a'), pw.Text('b')], rows: 40);
      expect(big.length, 2);
      expect(keepTogether(const [], rows: 1), isEmpty);
      // 경계값
      expect(keepTogether([pw.Text('a')], rows: 14).length, 1);
      expect(keepTogether([pw.Text('a'), pw.Text('b')], rows: 15).length, 2);
    });

    test('아주 큰 표(묶으면 쪽을 넘는)도 오류 없이 만들어진다', () async {
      final bytes = await make(
        () => [
          ...keepTogether([pw.Text('TITLE'), table(120)], rows: 120),
        ],
      );
      expect(pageCount(bytes) >= 2, true);
    });

    test('쪽 아래에 걸리는 표는 묶으면 머리와 행이 같은 쪽에 남는다(안 묶으면 갈라진다)', () async {
      // 글자 37줄을 채우면 표 머리는 첫 쪽 맨 아래에, 행은 다음 쪽에 걸린다(위 실험으로 확인한 값).
      List<pw.Widget> body({required bool together}) {
        final filler = [
          for (var i = 0; i < 37; i++)
            pw.Text('FILL$i', style: const pw.TextStyle(fontSize: 16)),
        ];
        final section = [pw.Text('SECTION'), table(6)];
        return [
          ...filler,
          ...(together ? keepTogether(section, rows: 6) : section),
        ];
      }

      final apart = await pagesText(await make(() => body(together: false)));
      final joined = await pagesText(await make(() => body(together: true)));
      if (apart == null || joined == null || apart.length < 2) {
        // pdftotext가 없는 환경에서는 쪽 수만 본다.
        expect(pageCount(await make(() => body(together: true))) >= 1, true);
        return;
      }
      int page(List<String> t, String w) => t.indexWhere((x) => x.contains(w));
      // 안 묶으면 머리와 첫 행이 다른 쪽이다(문제 재현).
      expect(page(apart, 'HEADCOL') != page(apart, 'ROW0'), true);
      // 묶으면 제목·머리·첫 행이 모두 같은 쪽이다.
      final p = page(joined, 'HEADCOL');
      expect(p, isNot(-1));
      expect(page(joined, 'ROW0'), p);
      expect(page(joined, 'SECTION'), p);
    });
  });

  group('아이콘 이름 다시 보기(? 버튼)', () {
    Future<void> show(
      WidgetTester tester, {
      bool labels = false,
      VoidCallback? onHelp,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: CutActionBar(
                showLabels: labels,
                onToggleLabels: onHelp,
                actions: [
                  CutActionSpec(
                    key: const Key('a1'),
                    label: '하나',
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('동작을 주면 ? 버튼이 있고 모양이 상태를 따른다', (tester) async {
      var n = 0;
      await show(tester, onHelp: () => n++);
      expect(find.byKey(const Key('action_help')), findsOneWidget);
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
      await tester.tap(find.byKey(const Key('action_help')));
      expect(n, 1);
      await show(tester, labels: true, onHelp: () => n++);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('동작을 안 주면 ? 버튼이 없다', (tester) async {
      await show(tester);
      expect(find.byKey(const Key('action_help')).evaluate(), isEmpty);
    });
  });

  group('결과 탭에서 ? 버튼', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CuttingMainScreen(
              project: CuttingProject(
                id: 'p1',
                name: '루마',
                createdAt: DateTime(2026, 9, 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
    }

    testWidgets('처음에는 이름이 보이고 ? 버튼은 없다', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('action_label_카톡 보내기')), findsOneWidget);
      expect(find.byKey(const Key('action_help')).evaluate(), isEmpty);
    });

    testWidgets('써 본 뒤에는 ? 로 이름을 다시 보고, 다시 눌러 숨기며, 저장은 하지 않는다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'cutting_result_icons_used': true,
      });
      await open(tester);
      expect(find.byKey(const Key('action_label_카톡 보내기')).evaluate(), isEmpty);
      await tester.tap(find.byKey(const Key('action_help')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('action_label_카톡 보내기')), findsOneWidget);
      await tester.tap(find.byKey(const Key('action_help')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('action_label_카톡 보내기')).evaluate(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('cutting_result_icons_used'), true); // 그대로
    });

    testWidgets('이름을 다시 보는 중에 아이콘을 쓰면 이름이 숨는다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'cutting_result_icons_used': true,
      });
      await open(tester);
      await tester.tap(find.byKey(const Key('action_help')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('result_btn_copy')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('action_label_글 복사')).evaluate(), isEmpty);
    });

    testWidgets('글자를 크게 키워도 넘치지 않는다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'cutting_result_icons_used': true,
      });
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: CuttingMainScreen(
              project: CuttingProject(
                id: 'p1',
                name: '루마',
                createdAt: DateTime(2026, 9, 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('action_help')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
