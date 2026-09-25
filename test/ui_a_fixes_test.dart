// UI·UX 점검 묶음 U-A(숫자·자료) 고침 확인.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/app_dialog.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_logs_page.dart';

void main() {
  test('X2 재고 실사 기록: 부호대로 −3/+2, 부호 없는 예전 기록만 =', () {
    // 예전: 10→7로 고쳐도 "=3"(3개로 맞춤)처럼 보였다.
    expect(auditQtyPrefix({'qty': 3, 'sign': '-'}), '−');
    expect(auditQtyPrefix({'qty': 2, 'sign': '+'}), '+');
    expect(auditQtyPrefix({'qty': 5}), '=');
  });

  group('X3 숫자판', () {
    Future<TextEditingController> open(WidgetTester tester) async {
      final c = TextEditingController(text: '38.1');
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    MakitaNumpad.show(context, controller: c, title: '반경'),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.tap(find.text('0'));
      await tester.pump();
      expect(c.text, '50'); // 누르는 동안은 바로 보인다
      return c;
    }

    testWidgets('X(닫기)는 열 때 값으로 되돌린다', (tester) async {
      final c = await open(tester);
      await tester.tap(find.byKey(const Key('numpad_close')));
      await tester.pumpAndSettle();
      // 예전: X도 "적용"이라 50이 남았다.
      expect(c.text, '38.1');
    });

    testWidgets('바깥을 눌러 닫아도 되돌린다', (tester) async {
      final c = await open(tester);
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
      expect(c.text, '38.1');
    });

    testWidgets('"적용"을 누르면 새 값이 남는다', (tester) async {
      final c = await open(tester);
      await tester.tap(find.text('적용'));
      await tester.pumpAndSettle();
      expect(c.text, '50');
    });
  });

  testWidgets('X8 지우기 확인 창은 확인 단추가 빨갛다', (tester) async {
    Color? okColor(bool destructive) {
      final b = tester.widget<ElevatedButton>(find.byKey(const Key('ok')));
      return b.style?.backgroundColor?.resolve({});
    }

    for (final d in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: AppDialog(
            title: '삭제 확인',
            okText: '삭제',
            okKey: const Key('ok'),
            destructive: d,
            onCancel: () {},
            onOk: () {},
            content: const SizedBox(),
          ),
        ),
      );
      expect(okColor(d), d ? const Color(0xFFDC2626) : const Color(0xFF007580));
    }
  });

  testWidgets('X9 지우기 전에 묻는다: 취소면 false, 삭제면 true', (tester) async {
    final results = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                results.add(await confirmDeleteDialog(context, message: '지울까')),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete_ok')));
    await tester.pumpAndSettle();
    expect(results, [false, true]);
  });
}
