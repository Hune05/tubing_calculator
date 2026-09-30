// 축 정렬 계산기 화면: 값을 넣으면 결과, 검산·오류 안내, 두 방식, 기록 저장과 장비 대장 연결, 지난 기록.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/record_sync.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_math.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_page.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_record.dart';
import 'package:tubing_calculator/src/presentation/equipment/equipment_model.dart';
import 'package:tubing_calculator/src/presentation/equipment/equipment_store.dart';

final _now = DateTime(2026, 9, 30, 10);
String? _shared;
int _tick = 0;

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(700, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: AlignmentPage(
        share: (t) async => _shared = t,
        now: () => _now.add(Duration(seconds: _tick++)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String v) async {
  await tester.enterText(find.byKey(Key('align_$key')), v);
  await tester.pump();
}

/// 손으로 푼 예제(위아래만 어긋남): A −0.20, B +0.10, 거리 200/100/150/450
Future<void> _fillReverse(WidgetTester tester) async {
  await _type(tester, 'a90', '-0.10');
  await _type(tester, 'a180', '-0.20');
  await _type(tester, 'a270', '-0.10');
  await _type(tester, 'b90', '0.05');
  await _type(tester, 'b180', '0.10');
  await _type(tester, 'b270', '0.05');
  await _type(tester, 'between', '200');
  await _type(tester, 'coupB', '100');
  await _type(tester, 'front', '150');
  await _type(tester, 'rear', '450');
}

String _text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    recordRemote = () => null;
    _shared = null;
    _tick = 0;
  });

  testWidgets('처음에는 안내만 나오고, 값을 다 넣으면 결과가 나온다', (tester) async {
    await _open(tester);
    expect(find.byKey(const Key('align_hint')), findsOneWidget);
    await _type(tester, 'rpm', '1800');
    await _fillReverse(tester);
    expect(find.byKey(const Key('align_hint')), findsNothing);
    expect(_text(tester, 'align_shim_front'), '심 빼기 0.14 mm');
    expect(_text(tester, 'align_shim_rear'), '심 빼기 0.21 mm');
    expect(_text(tester, 'align_move_front'), '옆 그대로');
    expect(_text(tester, 'align_offsets'), contains('0.075 mm'));
    expect(find.byKey(const Key('align_diagram_v')), findsOneWidget);
    expect(find.byKey(const Key('align_plan')), findsOneWidget);
  });

  testWidgets('시계 그림과 측정 그림이 나오고, 입력칸에 그림과 같은 번호가 붙는다', (tester) async {
    await _open(tester);
    expect(find.byKey(const Key('align_clock')), findsOneWidget);
    expect(find.byKey(const Key('align_setup_diagram')), findsOneWidget);
    expect(find.text('① A·B 두 접촉면 사이'), findsOneWidget);
    expect(find.text('④ A면에서 모터 뒷발까지'), findsOneWidget);
    await tester.tap(find.text('림·페이스'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('align_setup_diagram')), findsOneWidget);
    expect(find.text('① 림면에서 커플링 중심까지'), findsOneWidget);
    expect(find.text('④ 페이스가 닿는 반지름'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('허용 범위 밖이면 초과, 허용값을 고치면 판정이 바뀐다', (tester) async {
    await _open(tester);
    await _type(tester, 'rpm', '1800'); // 참고 허용 0.08
    await _fillReverse(tester);
    // 평행 0.075는 허용(0.08) 안이지만 각도 0.025도 안 → 허용 안
    expect(find.text('허용 범위 안입니다'), findsOneWidget);
    await _type(tester, 'rpm', '3600'); // 허용 0.05 → 평행 초과
    expect(find.text('평행 어긋남 초과'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('align_tol_offset')), '0.10');
    await tester.pump();
    expect(find.text('허용 범위 안입니다'), findsOneWidget);
  });

  testWidgets('읽음값이 서로 안 맞으면 검산 경고가 뜬다', (tester) async {
    await _open(tester);
    await _fillReverse(tester);
    await _type(tester, 'a270', '0.30'); // 3시 −0.10 + 9시 0.30 ≠ 6시 −0.20
    expect(find.byKey(const Key('align_closure')), findsOneWidget);
  });

  testWidgets('거리가 이상하면 오류 안내(뒷발이 앞발보다 가까움)', (tester) async {
    await _open(tester);
    await _fillReverse(tester);
    await _type(tester, 'rear', '100');
    expect(find.text('뒷발이 앞발보다 더 멀어야 합니다'), findsOneWidget);
    expect(find.byKey(const Key('align_shim_front')), findsNothing);
  });

  testWidgets('림·페이스로 바꾸면 그 입력칸이 나오고 결과가 나온다', (tester) async {
    await _open(tester);
    await tester.tap(find.text('림·페이스'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('align_r180')), findsOneWidget);
    expect(find.byKey(const Key('align_a180')), findsNothing);
    // 위아래로 0.30 평행 어긋남만(기울기 0): 림 6시 = −0.60, 3시·9시 = −0.30, 페이스는 전부 0
    await _type(tester, 'r90', '-0.30');
    await _type(tester, 'r180', '-0.60');
    await _type(tester, 'r270', '-0.30');
    for (final k in ['f90', 'f180', 'f270']) {
      await _type(tester, k, '0');
    }
    await _type(tester, 'faceR', '90');
    await _type(tester, 'coupR', '40');
    await _type(tester, 'front', '120');
    await _type(tester, 'rear', '420');
    expect(_text(tester, 'align_shim_front'), '심 빼기 0.30 mm');
    expect(_text(tester, 'align_shim_rear'), '심 빼기 0.30 mm');
  });

  testWidgets('열팽창 목표를 넣으면 심이 그만큼 달라진다', (tester) async {
    await _open(tester);
    for (final k in ['a90', 'a180', 'a270', 'b90', 'b180', 'b270']) {
      await _type(tester, k, '0');
    }
    await _type(tester, 'between', '200');
    await _type(tester, 'coupB', '100');
    await _type(tester, 'front', '150');
    await _type(tester, 'rear', '450');
    expect(_text(tester, 'align_shim_front'), '심 그대로');
    await tester.tap(find.byKey(const Key('align_target_toggle')));
    await tester.pumpAndSettle();
    await _type(tester, 'targetY', '-0.20');
    expect(_text(tester, 'align_shim_front'), '심 빼기 0.20 mm');
  });

  testWidgets('기록 남기기: 저장되고 장비 대장 이력에 축 정렬이 붙는다(교정 기한은 그대로)', (tester) async {
    final e = Equipment(
      id: 'eq1',
      name: '급수펌프 모터',
      assetNo: 'M-1',
      intervalMonths: 12,
      lastDone: DateTime(2026, 6, 1),
      createdAt: _now,
    );
    await EquipmentStore.put(e);
    await _open(tester);
    await _type(tester, 'rpm', '1800');
    await _fillReverse(tester);
    await tester.tap(find.byKey(const Key('align_save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('align_stage_after')));
    await tester.enterText(find.byKey(const Key('align_machine')), '1호기 급수펌프');
    await tester.tap(find.byKey(const Key('align_equipment')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('M-1  급수펌프 모터').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('align_save_ok')));
    await tester.pumpAndSettle();

    final saved = await AlignStore.load();
    expect(saved.single.machine, '1호기 급수펌프');
    expect(saved.single.stage, AlignStage.after);
    expect(saved.single.offset, closeTo(0.075, 1e-9));
    expect(saved.single.inputs['between'], '200');

    final eq = (await EquipmentStore.load()).single;
    expect(eq.events.first.type, EventType.align);
    expect(eq.events.first.note, contains('정렬 후'));
    expect(eq.lastDone, DateTime(2026, 6, 1)); // 교정일은 안 바뀐다
    expect(eq.status, EquipStatus.ok);
  });

  testWidgets('지난 기록에서 보고 다시 보내고 지운다', (tester) async {
    await AlignStore.put(
      AlignRecord(
        id: '9',
        at: _now,
        machine: '2호기 팬',
        method: AlignMethod.reverse,
        stage: AlignStage.before,
        rpm: 1800,
        offset: 0.2,
        angle100: 0.05,
        shimFront: -0.1,
        shimRear: 0.2,
        moveFront: 0.05,
        moveRear: 0,
        verdict: AlignVerdict.offsetOut,
      ),
    );
    await _open(tester);
    await tester.tap(find.byKey(const Key('align_history')));
    await tester.pumpAndSettle();
    expect(find.textContaining('2호기 팬'), findsWidgets);
    await tester.tap(find.byKey(const Key('align_record_9')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('align_history_send')));
    await tester.pumpAndSettle();
    expect(_shared, contains('[축 정렬 정렬 전]'));
    expect(_shared, contains('앞발 심 빼기 0.10 mm'));
    expect(_shared, contains('옆 오른쪽 0.05 mm'));

    await tester.tap(find.byKey(const Key('align_record_9')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('align_history_delete')));
    await tester.pumpAndSettle();
    expect(find.text('저장한 정렬 기록이 없습니다'), findsOneWidget);
  });

  test('정렬 후 기록은 같은 기계의 정렬 전과 비교한다', () {
    AlignRecord r(String id, AlignStage s, DateTime at, double off, {String m = '펌프'}) => AlignRecord(
      id: id, at: at, machine: m, method: AlignMethod.reverse, stage: s, rpm: 1800,
      offset: off, angle100: off / 2, shimFront: 0, shimRear: 0, moveFront: 0, moveRear: 0, verdict: AlignVerdict.ok,
    );
    final before = r('1', AlignStage.before, DateTime(2026, 9, 30, 9), 0.30);
    final other = r('2', AlignStage.before, DateTime(2026, 9, 30, 9, 30), 0.90, m: '다른 기계');
    final after = r('3', AlignStage.after, DateTime(2026, 9, 30, 11), 0.04);
    final text = compareText(after, [after, other, before])!;
    expect(text, contains('0.300 → 0.040'));
    expect(compareText(before, [before, after]), isNull); // 정렬 전에는 비교 없음
    expect(compareText(after, [after]), isNull); // 전 기록이 없으면 null
  });
}
