// 보관함 "도면 보기": 정보를 고치거나 시작 방향을 돌려도 저장 때 값(장비 값·메모)이 지워지지 않는다,
// 저장 창 메모와 특이사항은 같은 글, 3D 그림은 저장 때 장비 값으로 그린다, QR 날짜는 도면 저장 날짜.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/history_card_info.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_pipe_visualizer.dart';
import 'package:tubing_calculator/src/presentation/fabrication/fab_qr.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/mobile_fabrication_detail_screen.dart';

const _specs = {
  'radius': 44.0,
  'gain90': 13.5,
  'springback': 2.0,
  'benderOffset': 0.0,
  'fittingDepth': 21.0,
};

final _bends = [
  {'length': 150.0, 'angle': 0.0, 'rotation': 0.0},
  {'length': 80.0, 'angle': 90.0, 'rotation': 0.0},
  {'length': 200.0, 'angle': 0.0, 'rotation': 0.0},
];

Map<String, dynamic> _item({
  Map<String, dynamic> extra = const {},
  Map<String, double>? specs = _specs,
}) => {
  'id': 7,
  'date': '2026-09-21 10:05',
  'pipe_size': '1/2"',
  'total_length': 700.0,
  'p_to_p': jsonEncode({
    'project': 'A동',
    'from': '1',
    'to': '2',
    'start_fit': true,
    'end_fit': false,
    'tail': 25.0,
    'start_dir': 'RIGHT',
    'specs': ?specs,
    ...extra,
  }),
  'bend_data': jsonEncode(_bends),
};

void main() {
  late List<(int, Map<String, dynamic>)> updates;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MachineSpecs().resetForTest();
    updates = [];
    TubeHistoryDb.update = (id, row) async => updates.add((id, row));
  });

  Future<void> open(WidgetTester tester, Map<String, dynamic> item) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: MobileFabricationDetailScreen(itemData: item)),
    );
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> lastPToP() =>
      jsonDecode(updates.last.$2['p_to_p'] as String) as Map<String, dynamic>;

  testWidgets('도면 정보를 고쳐도 저장 때 장비 값과 시작 방향이 그대로 남는다', (tester) async {
    await open(tester, _item(extra: {'note': '현장 메모'}));
    await tester.tap(find.byTooltip('도면 정보 수정'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'A동'), 'B동');
    await tester.pump();
    await tester.tap(find.text('수정 완료'));
    await tester.pumpAndSettle();

    expect(updates.single.$1, 7);
    final p = lastPToP();
    expect(p['project'], 'B동');
    expect(p['specs'], _specs); // 저장 때 장비 값
    expect(p['start_dir'], 'RIGHT');
    expect(p['tail'], 25.0);
    expect(p['start_fit'], true);
    expect(p['note'], '현장 메모'); // 저장 창에서 적은 메모
    expect(p['memo'], '현장 메모'); // 도면 보기의 특이사항과 같은 글
  });

  testWidgets('3D에서 시작 방향을 돌려도 장비 값과 메모가 남는다', (tester) async {
    await open(tester, _item(extra: {'note': '현장 메모'}));
    final viz = tester.widget<MobilePipeVisualizer>(
      find.byType(MobilePipeVisualizer),
    );
    viz.onStartDirChanged!('LEFT');
    await tester.pumpAndSettle();

    final p = lastPToP();
    expect(p['start_dir'], 'LEFT');
    expect(p['specs'], _specs);
    expect(p['note'], '현장 메모');
    expect(p['project'], 'A동');

    // 방향을 돌린 뒤 정보를 고쳐도 방향이 옛 값으로 돌아가지 않는다.
    await tester.tap(find.byTooltip('도면 정보 수정'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'A동'), 'C동');
    await tester.pump();
    await tester.tap(find.text('수정 완료'));
    await tester.pumpAndSettle();
    expect(lastPToP()['start_dir'], 'LEFT');
    expect(lastPToP()['specs'], _specs);
  });

  testWidgets('저장 창 메모와 특이사항이 다르면 이어 붙여 보여 준다', (tester) async {
    await open(tester, _item(extra: {'note': '배관 교체', 'memo': '용접 금지'}));
    await tester.tap(find.byTooltip('도면 정보 수정'));
    await tester.pumpAndSettle();
    expect(find.text('배관 교체\n용접 금지'), findsOneWidget);
  });

  testWidgets('3D 그림은 저장 때 장비 값으로 그리고, 값이 없는 옛 도면은 지금 설정으로', (tester) async {
    await open(tester, _item());
    var viz = tester.widget<MobilePipeVisualizer>(
      find.byType(MobilePipeVisualizer),
    );
    expect(viz.bendRadius, 44.0);
    expect(viz.fittingDepth, 21.0);

    MachineSpecs().update(radius: 55.0, fittingDepth: 30.0);
    await tester.pumpWidget(const SizedBox());
    await open(tester, _item(specs: null));
    viz = tester.widget<MobilePipeVisualizer>(
      find.byType(MobilePipeVisualizer),
    );
    expect(viz.bendRadius, 55.0);
    expect(viz.fittingDepth, 30.0);
  });

  group('순수 함수', () {
    test('바꾼 칸만 얹고 나머지는 그대로', () {
      final out = historyPToPWith(
        {
          'project': 'A',
          'specs': {'radius': 1},
          'note': 'n',
        },
        {'project': 'B'},
      );
      expect(out, {
        'project': 'B',
        'specs': {'radius': 1},
        'note': 'n',
      });
    });

    test('메모 합치기', () {
      expect(mergeDrawingMemo('', ''), '');
      expect(mergeDrawingMemo(' A ', ''), 'A');
      expect(mergeDrawingMemo('', 'B'), 'B');
      expect(mergeDrawingMemo('A', 'A'), 'A');
      expect(mergeDrawingMemo('A', 'B'), 'A\nB');
    });

    test('보관함 카드의 메모도 특이사항을 같이 본다', () {
      final i = HistoryCardInfo.of({
        'p_to_p': jsonEncode({'memo': '특이사항만'}),
        'bend_data': '[]',
        'total_length': 100,
      });
      expect(i.note, '특이사항만');
    });

    test('QR 날짜는 도면에 저장된 날짜: 같은 도면은 늘 같은 QR', () {
      expect(
        FabQr.savedDateOf('2026-09-21 10:05'),
        DateTime(2026, 9, 21, 10, 5),
      );
      expect(FabQr.savedDateOf('2026-09-21'), DateTime(2026, 9, 21));
      expect(FabQr.savedDateOf(''), isNull);
      expect(FabQr.savedDateOf(null), isNull);
      expect(FabQr.savedDateOf('abc'), isNull);
      FabQrLink make(DateTime? now) => FabQr.build(
        project: 'A',
        pipeSize: '1/2"',
        bends: [
          {'length': 100.0, 'angle': 90.0, 'rotation': 0.0},
        ],
        startFit: true,
        endFit: false,
        tail: 0,
        startDir: 'RIGHT',
        totalCut: 100,
        now: now,
      );
      final saved = FabQr.savedDateOf('2026-09-21 10:05');
      final a = make(saved);
      final b = make(saved);
      expect(a.url, b.url);
      expect(a.code, b.code);
      expect(a.savedText, '2026-09-21 10:05');
    });
  });
}
