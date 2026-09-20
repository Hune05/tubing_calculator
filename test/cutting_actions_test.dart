import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_action_bar.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_main_screen.dart';

// 결과 탭 제목줄의 아이콘 버튼 줄(재단 최적화·PDF·카톡·복사)과 카카오톡 바로 보내기.
void main() {
  group('아이콘 버튼 줄', () {
    Future<void> show(
      WidgetTester tester, {
      bool labels = false,
      List<String>? pressed,
      double scale = 1.0,
      double width = 360,
    }) async {
      tester.view.physicalSize = Size(width * 3, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('컷팅 지시서', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  CutActionBar(
                    showLabels: labels,
                    actions: [
                      for (final n in ['재단 최적화', 'PDF 공유', '카톡 보내기', '글 복사'])
                        CutActionSpec(
                          key: Key('btn_$n'),
                          label: n,
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () => pressed?.add(n),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('각 아이콘을 누르면 자기 동작이 불린다', (tester) async {
      final pressed = <String>[];
      await show(tester, pressed: pressed);
      for (final n in ['재단 최적화', 'PDF 공유', '카톡 보내기', '글 복사']) {
        await tester.tap(find.byKey(Key('btn_$n')));
      }
      expect(pressed, ['재단 최적화', 'PDF 공유', '카톡 보내기', '글 복사']);
    });

    testWidgets('누르는 영역이 44dp 이상이고 서로 간격이 있다', (tester) async {
      await show(tester);
      final a = tester.getRect(find.byKey(const Key('btn_재단 최적화')));
      final b = tester.getRect(find.byKey(const Key('btn_PDF 공유')));
      expect(a.width >= 44 && a.height >= 44, true);
      expect(b.left - a.right >= 4 - 0.01, true);
    });

    testWidgets('길게 누르면 이름이 뜬다', (tester) async {
      await show(tester);
      await tester.longPress(find.byKey(const Key('btn_카톡 보내기')));
      await tester.pumpAndSettle();
      expect(find.text('카톡 보내기'), findsOneWidget);
    });

    testWidgets('처음 쓰는 동안에는 이름이 아래에 보이고, 아니면 숨는다', (tester) async {
      await show(tester, labels: true);
      expect(find.byKey(const Key('action_label_재단 최적화')), findsOneWidget);
      expect(find.byKey(const Key('action_label_카톡 보내기')), findsOneWidget);
      await show(tester, labels: false);
      expect(find.byKey(const Key('action_label_재단 최적화')).evaluate(), isEmpty);
    });

    testWidgets('좁은 화면·큰 글씨에서도 제목과 함께 한 줄에 넘치지 않는다', (tester) async {
      await show(tester, labels: true, scale: 1.6, width: 320);
      expect(tester.takeException(), isNull);
      await show(tester, labels: false, scale: 1.0, width: 360);
      expect(tester.takeException(), isNull);
    });
  });

  group('재단 최적화 아이콘', () {
    testWidgets('그려지고 크기를 따른다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: CutBarIcon(size: 40))),
        ),
      );
      expect(tester.getSize(find.byType(CutBarIcon)), const Size(40, 40));
      expect(tester.takeException(), isNull);
    });
  });

  group('카카오톡 보내기(결과 탭)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    late KakaoSender oldKakao;
    late TextSharer oldShare;
    setUp(() {
      oldKakao = kakaoSender;
      oldShare = textSharer;
    });
    tearDown(() {
      kakaoSender = oldKakao;
      textSharer = oldShare;
    });

    Finder lengthField(int i) => find
        .byWidgetPredicate(
          (w) =>
              w is TextField &&
              (w.decoration?.labelText ?? '').startsWith('전체 길이'),
        )
        .at(i);

    Future<void> open(WidgetTester tester, {bool typed = true}) async {
      tester.view.physicalSize = const Size(1080, 6000);
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
      if (typed) {
        await tester.enterText(lengthField(0), '600');
        await tester.pump();
      }
      await tester.tap(find.text('결과'));
      await tester.pumpAndSettle();
    }

    testWidgets('제목줄에 아이콘 네 개가 있고 예전 큰 버튼 줄은 없다', (tester) async {
      await open(tester);
      for (final k in [
        'result_btn_optimize',
        'result_btn_export',
        'result_btn_kakao',
        'result_btn_copy',
      ]) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: k);
      }
      expect(find.text('컷팅 지시서'), findsOneWidget);
      // 예전 세로 버튼의 글자("PDF 공유" 등)는 처음 쓰는 동안 아이콘 아래 작은 이름으로만 나온다.
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('카톡 버튼은 지시서 글을 카카오톡 보내기에 넘긴다', (tester) async {
      String? sent;
      kakaoSender = (t) async {
        sent = t;
        return true;
      };
      var shared = false;
      textSharer = (t) async => shared = true;
      await open(tester);
      await tester.tap(find.byKey(const Key('result_btn_kakao')));
      await tester.pumpAndSettle();
      expect(sent, isNotNull);
      expect(sent!.startsWith('[컷팅 지시서] 루마'), true);
      expect(sent!.contains('600.0mm × 1개'), true);
      expect(shared, false); // 카카오톡이 열렸으니 공유창은 쓰지 않는다
    });

    testWidgets('카카오톡이 없으면 공유창으로 대신 보내고 알려 준다', (tester) async {
      kakaoSender = (t) async => false;
      String? shared;
      textSharer = (t) async => shared = t;
      await open(tester);
      await tester.tap(find.byKey(const Key('result_btn_kakao')));
      await tester.pumpAndSettle();
      expect(shared, isNotNull);
      expect(shared!.contains('합계 600.0mm'), true);
      expect(find.textContaining('카카오톡을 찾지 못해'), findsOneWidget);
    });

    testWidgets('공유마저 실패하면 오류를 알려 준다', (tester) async {
      kakaoSender = (t) async => false;
      textSharer = (t) async => throw StateError('없음');
      await open(tester);
      await tester.tap(find.byKey(const Key('result_btn_kakao')));
      await tester.pumpAndSettle();
      expect(find.textContaining('보내기 실패'), findsOneWidget);
    });

    testWidgets('치수가 없으면 보내지 않고 안내한다', (tester) async {
      var called = false;
      kakaoSender = (t) async {
        called = true;
        return true;
      };
      await open(tester, typed: false);
      await tester.tap(find.byKey(const Key('result_btn_kakao')));
      await tester.pump();
      expect(called, false);
      expect(find.textContaining('보낼 치수가 없습니다'), findsOneWidget);
    });

    testWidgets('아이콘을 한 번 쓰면 이름 표시가 사라지고 기억된다', (tester) async {
      kakaoSender = (t) async => true;
      await open(tester);
      expect(find.byKey(const Key('action_label_카톡 보내기')), findsOneWidget);
      await tester.tap(find.byKey(const Key('result_btn_kakao')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('action_label_카톡 보내기')).evaluate(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('cutting_result_icons_used'), true);
    });

    testWidgets('이미 써 본 사람은 처음부터 이름이 없다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'cutting_result_icons_used': true,
      });
      await open(tester);
      expect(find.byKey(const Key('action_label_카톡 보내기')).evaluate(), isEmpty);
    });

    testWidgets('글자를 크게 키워도 결과 탭이 넘치지 않는다', (tester) async {
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
      expect(tester.takeException(), isNull);
    });
  });
}
