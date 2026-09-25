// 공용 부품(UI 디자인 제안 D-C): 단추·창·알림·빈 화면·불러오는 중·숫자 표시.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/common_widgets/app_components.dart';
import 'package:tubing_calculator/src/core/theme/app_theme.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/app_dialog.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_theme.dart';

Widget _app(Widget home) => MaterialApp(
  theme: buildAppTheme(),
  home: Scaffold(body: home),
);

void main() {
  group('AppButton', () {
    testWidgets('네 가지 색이 색의 뜻을 따른다', (tester) async {
      expect(AppButton.colorsOf(AppButtonKind.primary).$1, AppColors.brand);
      expect(AppButton.colorsOf(AppButtonKind.secondary).$2, AppColors.brand);
      expect(AppButton.colorsOf(AppButtonKind.danger).$1, AppColors.danger);
      expect(AppButton.colorsOf(AppButtonKind.quiet).$2, AppColors.textSub);
    });

    testWidgets('높이는 48 이상, 꽉 채우기면 가로 전체', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              AppButton(key: const Key('p'), label: '저장', onPressed: () {}),
              AppButton.secondary(
                key: const Key('s'),
                label: '특수 벤딩 툴 (오프셋/새들 등)',
                icon: Icons.build_circle_outlined,
                expand: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('p'))).height,
        greaterThanOrEqualTo(48),
      );
      final s = tester.getSize(find.byKey(const Key('s')));
      expect(s.height, greaterThanOrEqualTo(48));
      expect(s.width, 320);
      // 보조 단추는 청록 테두리(예전 특수 벤딩 툴: 진한 회색 테두리·검정 글씨).
      final ob = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(ob.style?.side?.resolve({})?.color, AppColors.brand);
      expect(tester.takeException(), isNull);
    });
  });

  group('창', () {
    testWidgets('묻는 창: 확인이면 true, 취소면 false, 지우기는 빨강', (tester) async {
      final results = <bool>[];
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await showAppConfirm(
                  context,
                  title: '지울까요',
                  message: '되돌릴 수 없습니다.',
                  okText: '삭제',
                  destructive: true,
                  okKey: const Key('ok'),
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      final ok = tester.widget<ElevatedButton>(find.byKey(const Key('ok')));
      expect(ok.style?.backgroundColor?.resolve({}), AppColors.danger);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ok')));
      await tester.pumpAndSettle();
      expect(results, [false, true]);
    });

    testWidgets('컷팅 확인 창·지우기 확인·AppDialog가 같은 공용 창으로 그려진다', (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => showCuttingConfirmDialog(
                    context,
                    title: '컷팅',
                    message: '저장할까',
                  ),
                  child: const Text('a'),
                ),
                TextButton(
                  onPressed: () => confirmDeleteDialog(context, message: '지울까'),
                  child: const Text('b'),
                ),
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => AppDialog(
                      title: '보관',
                      content: const Text('x'),
                      onCancel: () {},
                      onOk: () {},
                    ),
                  ),
                  child: const Text('c'),
                ),
              ],
            ),
          ),
        ),
      );
      for (final k in ['a', 'b', 'c']) {
        await tester.tap(find.text(k));
        await tester.pumpAndSettle();
        expect(find.byType(AppConfirmDialog), findsOneWidget, reason: k);
        final dlg = tester.widget<AlertDialog>(find.byType(AlertDialog));
        expect(
          (dlg.shape as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(AppRadius.large),
          reason: k,
        );
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
      }
    });
  });

  group('알림', () {
    testWidgets('되돌리기 알림은 누를 수 있고, 시간이 지나면 사라진다', (tester) async {
      var undone = 0;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showCuttingUndoSnack(
                context,
                '구간을 지웠습니다',
                onUndo: () => undone++,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('실행 취소'), findsOneWidget);
      // 예전: 단추 달린 알림이 기본으로 계속 떠 있어(persist) 화면을 가렸다.
      await tester.pump(kAppUndoSnackDuration);
      await tester.pumpAndSettle();
      expect(find.text('구간을 지웠습니다'), findsNothing);

      await tester.tap(find.text('열기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('실행 취소'));
      expect(undone, 1);
    });

    testWidgets('실패 알림은 빨강, 잘 됨은 진한 청록', (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () =>
                      showCuttingSnack(context, '안 됨', isError: true),
                  child: const Text('e'),
                ),
                TextButton(
                  onPressed: () => showAppSnack(context, '됨'),
                  child: const Text('s'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('e'));
      await tester.pump();
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
        AppColors.danger,
      );
      ScaffoldMessenger.of(
        tester.element(find.text('e')),
      ).removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('s'));
      await tester.pump();
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
        kAppSnackSuccess,
      );
    });
  });

  group('빈 화면·불러오는 중·숫자', () {
    testWidgets('빈 화면: 제목·설명·할 일 단추', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _app(
          EmptyState(
            icon: Icons.add_road_rounded,
            title: '설계된 배관이 없습니다',
            message: '아래에서 넣으십시오.',
            actionLabel: '새로 만들기',
            onAction: () => tapped = true,
          ),
        ),
      );
      expect(find.text('설계된 배관이 없습니다'), findsOneWidget);
      await tester.tap(find.text('새로 만들기'));
      expect(tapped, isTrue);
    });

    testWidgets('빈 화면: 자리가 좁으면 아이콘을 빼고 글이 보인다', (tester) async {
      Future<void> pumpAt(double h) => tester.pumpWidget(
        _app(
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: h,
              child: const EmptyState(
                icon: Icons.add_road_rounded,
                title: '설계된 배관이 없습니다',
                message: '아래에서 넣으십시오.',
              ),
            ),
          ),
        ),
      );
      await pumpAt(120);
      expect(find.byIcon(Icons.add_road_rounded), findsNothing);
      final r = tester.getRect(find.text('설계된 배관이 없습니다'));
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.bottom, lessThanOrEqualTo(120));
      await pumpAt(400);
      expect(find.byIcon(Icons.add_road_rounded), findsOneWidget);
    });

    testWidgets('불러오는 중 목록은 320 폭 글씨 1.3에서도 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const Scaffold(body: LoadingList()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('숫자 표시: 좁아도 한 줄, 자리 맞춤 숫자', (tester) async {
      await tester.pumpWidget(
        _app(
          const Center(
            child: SizedBox(
              width: 90,
              child: NumberDisplay(
                value: '12,345.6',
                unit: 'mm',
                label: '총 길이',
                large: true,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final rich = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(NumberDisplay),
              matching: find.byType(Text),
            ),
          )
          .firstWhere((t) => t.textSpan != null);
      final numSpan = (rich.textSpan as TextSpan).children!.first as TextSpan;
      expect(
        numSpan.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(numSpan.style?.fontSize, AppText.numberLarge.fontSize);
    });
  });
}
