// 이슈 화면 사진도 작업 일지처럼(10-09): 고르자마자 사진 칸에 먼저 보이고(정리 중 표시), 도장·보관이
// 끝나면 그 자리가 바뀐다. 이슈 등록과 처리 후 사진 두 곳.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/background_photos.dart';
import 'package:tubing_calculator/src/core/utils/image_picker_helper.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/photo_store.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/punch_detail_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/punch_list_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/work_theme.dart';

Future<Completer<String>> _fakePick() async {
  final finish = Completer<String>();
  ImagePickerHelper.debugPickRaw = (max) async => [
    const PickedPhoto('/tmp/raw_issue.jpg', fromCamera: true),
  ];
  ImagePickerHelper.debugFinish = (p) => finish.future;
  return finish;
}

void _big(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

String _shownPath(WidgetTester tester) =>
    tester.widget<PhotoImage>(find.byType(PhotoImage).last).path;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    ImagePickerHelper.debugPickRaw = null;
    ImagePickerHelper.debugFinish = null;
  });

  testWidgets('이슈 등록: 고르자마자 보이고, 정리가 끝나면 바뀐다', (tester) async {
    _big(tester);
    final finish = await _fakePick();
    await tester.pumpWidget(
      const MaterialApp(
        home: WorkTheme(child: PunchListPage(projectName: 'TEST')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_a_photo_rounded));
    await tester.pump();
    expect(find.byKey(const Key('punch_photo_busy_0')), findsOneWidget);
    expect(_shownPath(tester), '/tmp/raw_issue.jpg');

    finish.complete('/docs/photos/issue_final.jpg');
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('punch_photo_busy_0')), findsNothing);
    expect(_shownPath(tester), '/docs/photos/issue_final.jpg');
  });

  testWidgets('이슈 처리 후 사진: 고르자마자 보이고, 정리가 끝나면 바뀐다', (tester) async {
    _big(tester);
    final finish = await _fakePick();
    await tester.pumpWidget(
      MaterialApp(
        home: WorkTheme(
          child: PunchDetailPage(
            punch: {
              'content': '볼트 풀림',
              'location': '2층',
              'is_completed': false,
              'created_at': DateTime(2026, 10, 9),
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final add = find.text('처리 후 사진').first;
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pump();
    expect(find.byKey(const Key('after_photo_busy_0')), findsOneWidget);
    expect(_shownPath(tester), '/tmp/raw_issue.jpg');

    finish.complete('/docs/photos/after_final.jpg');
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('after_photo_busy_0')), findsNothing);
    expect(_shownPath(tester), '/docs/photos/after_final.jpg');
  });

  test('정리 중 기다리기: 다 끝나야 돌아오고, 그사이 지운 사진은 목록에 다시 안 들어온다', () async {
    final finish = Completer<String>();
    ImagePickerHelper.debugFinish = (p) => finish.future;
    final jobs = BackgroundPhotos();
    final list = <String>['/a.jpg'];
    jobs.addAll(list, const [PickedPhoto('/tmp/x.jpg')], update: (fn) => fn());
    expect(list, ['/a.jpg', '/tmp/x.jpg']);
    expect(jobs.busy('/tmp/x.jpg'), isTrue);
    list.remove('/tmp/x.jpg'); // 정리 중에 지움
    var waited = false;
    final w = jobs.waitAll().then((_) => waited = true);
    await Future<void>.delayed(Duration.zero);
    expect(waited, isFalse);
    finish.complete('/tmp/x_kept.jpg');
    await w;
    expect(waited, isTrue);
    expect(list, ['/a.jpg']);
    expect(jobs.isIdle, isTrue);
  });
}
