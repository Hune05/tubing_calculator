// 라인 컷팅 "재고에서 빼기"를 읽는 사이 한 번 더 누르면 같은 사용량을 두 번 뺐다(8차, 10-09).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_firestore_helper.dart';

void main() {
  testWidgets('같은 작업의 재고 빼기가 진행 중이면 두 번째는 시작하지 않고 알린다', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    deductingCuttingProjects.add('p1');
    addTearDown(() => deductingCuttingProjects.remove('p1'));
    // 진행 중 표시가 있으면 서버를 읽지 않고 바로 돌아온다(서버가 없는 시험에서도 오류 없이).
    await deductCuttingProjectInventory(
      context: ctx,
      projectId: 'p1',
      projectName: '루마',
      worker: '시험',
    );
    await tester.pump();
    expect(find.text('재고에서 빼는 중입니다. 끝난 뒤 다시 확인하십시오.'), findsOneWidget);
    expect(deductingCuttingProjects, {'p1'});
  });
}
