// 작업 일지 사진이 늦게 붙던 것(10-09): 고르자마자 사진 칸에 먼저 보이고(정리 중 표시), 도장·보관은
// 뒤에서 끝나면 그 자리를 바꾼다. 도장은 1600px, 위치 이름은 한 번만 묻는다, 작은 칸은 작게 펼친다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/image_picker_helper.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/photo_stamp.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/photo_store.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/daily_report_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/work_theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    ImagePickerHelper.debugPickRaw = null;
    ImagePickerHelper.debugFinish = null;
  });

  test('도장은 올릴 때 크기(1600px)로 찍는다', () {
    expect(kStampMaxSide, 1600);
  });

  test('위치 이름은 같은 때 두 번 물어도 한 번만 묻는다', () async {
    final a = quickSiteLocationLabel();
    final b = quickSiteLocationLabel();
    expect(identical(a, b), isTrue);
    expect(await a, isNull); // 시험에는 위치가 없다
  });

  testWidgets('작은 사진 칸은 그 크기(2배)로만 펼친다', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: PhotoImage('/no/such.jpg', width: 88, height: 88)),
    );
    final img = tester.widget<Image>(find.byType(Image));
    expect(img.image, isA<ResizeImage>());
    expect((img.image as ResizeImage).width, 88 * 3 * 2);
  });

  testWidgets('작업 일지: 고르자마자 사진이 보이고, 정리가 끝나면 그 자리가 바뀐다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final finish = Completer<String>();
    ImagePickerHelper.debugPickRaw = (max) async => [
      const PickedPhoto('/tmp/raw_1.jpg', fromCamera: true),
    ];
    ImagePickerHelper.debugFinish = (p) => finish.future;

    await tester.pumpWidget(
      const MaterialApp(home: WorkTheme(child: DailyReportPage())),
    );
    await tester.pumpAndSettle();
    final add = find.text('사진 추가');
    await tester.scrollUntilVisible(
      add,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pump();

    // 정리가 끝나기 전에 이미 사진 칸에 있다(정리 중 표시와 함께).
    expect(find.byKey(const Key('photo_busy_0')), findsOneWidget);
    expect(
      tester.widget<PhotoImage>(find.byType(PhotoImage)).path,
      '/tmp/raw_1.jpg',
    );
    // 정리 중에는 글·표시 넣기를 잠깐 막는다.
    await tester.tap(find.byKey(const Key('photo_annotate_0')));
    await tester.pump();
    expect(find.textContaining('사진을 정리하는 중입니다'), findsOneWidget);

    finish.complete('/docs/photos/final_1.jpg');
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('photo_busy_0')), findsNothing);
    expect(
      tester.widget<PhotoImage>(find.byType(PhotoImage)).path,
      '/docs/photos/final_1.jpg',
    );
  });
}
