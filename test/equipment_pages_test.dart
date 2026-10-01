// 장비 관리 대장 화면: 등록, 목록 요약·걸러 보기, 상세의 교정·반출·반납, QR로 찾기, 내보내기 글.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/record_sync.dart';
import 'package:tubing_calculator/src/presentation/equipment/equipment_model.dart';
import 'package:tubing_calculator/src/presentation/equipment/equipment_pages.dart';
import 'package:tubing_calculator/src/presentation/equipment/equipment_store.dart';

final _now = DateTime(2026, 9, 30, 10);
DateTime _clock() => _now;

Equipment _e(
  String id, {
  String name = '게이지',
  String assetNo = '',
  DateTime? last,
  int interval = 12,
  String holder = '',
}) => Equipment(
  id: id,
  name: name,
  assetNo: assetNo,
  intervalMonths: interval,
  lastDone: last,
  holder: holder,
  createdAt: _now,
);

String? _shared;
String? _scanResult;

Future<void> _open(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(700, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

Widget _ledger({LedgerView view = LedgerView.all}) => EquipmentLedgerPage(
  initialView: view,
  now: _clock,
  share: (t) async => _shared = t,
  scan: (_) async => _scanResult,
);

Future<void> _seed(List<Equipment> list) async {
  SharedPreferences.setMockInitialValues({});
  recordRemote = () => null;
  for (final e in list) {
    await EquipmentStore.put(e);
  }
}

void main() {
  setUp(() {
    _shared = null;
    _scanResult = null;
    SharedPreferences.setMockInitialValues({});
    recordRemote = () => null;
  });

  group('목록', () {
    testWidgets('비어 있으면 예시가 뜨고, 예시를 누르면 이름·주기가 채워진 등록 화면이 열린다', (tester) async {
      await _open(tester, _ledger());
      expect(find.text('등록한 장비가 없습니다'), findsOneWidget);
      await tester.tap(find.byKey(const Key('equip_preset_압력 게이지')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '압력 게이지'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('equip_interval_12'))).selected, true);
    });

    testWidgets('REMS 예시를 고르면 제조사·모델·제원이 채워진다', (tester) async {
      await _open(tester, _ledger());
      await tester.ensureVisible(find.byKey(const Key('equip_preset_REMS 아미고 2 (전동 나사 절삭기)')));
      await tester.tap(find.byKey(const Key('equip_preset_REMS 아미고 2 (전동 나사 절삭기)')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'REMS'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Amigo 2'), findsOneWidget);
      // 제원은 메모가 아니라 제원 줄에 들어간다
      expect(tester.widget<TextField>(find.byKey(const Key('equip_spec_name_0'))).controller!.text, '전동기');
      expect(tester.widget<TextField>(find.byKey(const Key('equip_spec_value_0'))).controller!.text, '1700 W');
      expect(tester.widget<TextField>(find.byKey(const Key('equip_note'))).controller!.text, '');
      await tester.ensureVisible(find.byKey(const Key('equip_save')));
      await tester.tap(find.byKey(const Key('equip_save')));
      await tester.pumpAndSettle();
      final saved = (await EquipmentStore.load()).single;
      expect(saved.specs.first, ('전동기', '1700 W'));
      expect(saved.specs.length, 7);
      expect(Equipment.fromJson(saved.toJson()).specs.last, ('고정', '받침대(서포트 브래킷), 바이스 없이'));
    });

    testWidgets('요약 숫자와 걸러 보기·검색', (tester) async {
      await _seed([
        _e('1', name: '만료 게이지', assetNo: 'PG-1', last: DateTime(2025, 1, 1)),
        _e('2', name: '임박 멀티미터', last: DateTime(2025, 10, 15)),
        _e('3', name: '정상 렌치', last: DateTime(2026, 9, 1)),
        _e('4', name: '반출 벤더', interval: 0, holder: '홍길동'),
      ]);
      await _open(tester, _ledger());
      expect(find.text('만료 게이지'), findsNothing); // 관리번호가 앞에 붙어 "PG-1  만료 게이지"
      expect(find.text('PG-1  만료 게이지'), findsOneWidget);
      // 요약: 전체 4, 기한(만료+임박) 2, 반출 1
      Finder stat(String key) => find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(Text),
      );
      expect(tester.widget<Text>(stat('equip_stat_all').first).data, '4');
      expect(tester.widget<Text>(stat('equip_stat_due').first).data, '2');
      expect(tester.widget<Text>(stat('equip_stat_out').first).data, '1');

      await tester.tap(find.byKey(const Key('equip_stat_due')));
      await tester.pumpAndSettle();
      expect(find.text('정상 렌치'), findsNothing);
      expect(find.text('임박 멀티미터'), findsOneWidget);

      await tester.tap(find.byKey(const Key('equip_stat_out')));
      await tester.pumpAndSettle();
      expect(find.text('반출 벤더'), findsOneWidget);
      expect(find.text('임박 멀티미터'), findsNothing);
      expect(find.textContaining('홍길동 반출 중'), findsOneWidget);

      await tester.tap(find.byKey(const Key('equip_stat_all')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('equip_search')), 'pg-1');
      await tester.pumpAndSettle();
      expect(find.text('PG-1  만료 게이지'), findsOneWidget);
      expect(find.text('정상 렌치'), findsNothing);
    });

    testWidgets('만료 장비가 위에 오고 지난 날이 보인다', (tester) async {
      await _seed([
        _e('1', name: '정상 렌치', last: DateTime(2026, 9, 1)),
        _e('2', name: '만료 게이지', last: DateTime(2025, 1, 1)),
      ]);
      await _open(tester, _ledger());
      final first = tester.getTopLeft(find.text('만료 게이지')).dy;
      final second = tester.getTopLeft(find.text('정상 렌치')).dy;
      expect(first, lessThan(second));
      expect(find.textContaining('일 지남'), findsOneWidget);
    });

    testWidgets('QR로 찾으면 그 장비 상세가 열리고, 없는 QR은 안내한다', (tester) async {
      await _seed([_e('1', name: '내 게이지', assetNo: 'PG-1', last: DateTime(2026, 9, 1))]);
      await _open(tester, _ledger());
      _scanResult = 'FH-EQ:PG-1';
      await tester.tap(find.byKey(const Key('equip_scan')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('equip_due_card')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      _scanResult = 'FH-EQ:없음';
      await tester.tap(find.byKey(const Key('equip_scan')));
      await tester.pumpAndSettle();
      expect(find.text('이 QR·바코드와 맞는 장비가 없습니다'), findsOneWidget);
    });

    testWidgets('기한 지난·임박 장비를 카톡 글로 보낸다', (tester) async {
      await _seed([_e('1', name: '만료 게이지', assetNo: 'PG-1', last: DateTime(2025, 1, 1))]);
      await _open(tester, _ledger());
      await tester.tap(find.byKey(const Key('equip_more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('기한 지난·임박 장비 (카톡)'));
      await tester.pumpAndSettle();
      expect(_shared, contains('⚠ PG-1 만료 게이지'));
    });
  });

  group('등록·수정', () {
    testWidgets('이름이 없으면 막고, 저장하면 목록에 생긴다. 다음 기한 미리보기', (tester) async {
      await _open(tester, EquipmentEditPage(now: _clock));
      await tester.tap(find.byKey(const Key('equip_save')));
      await tester.pumpAndSettle();
      expect(find.text('장비 이름을 적어 주십시오'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('equip_name')), '토크 렌치');
      await tester.enterText(find.byKey(const Key('equip_assetno')), 'TW-1');
      await tester.tap(find.byKey(const Key('equip_cat_tool')));
      await tester.tap(find.byKey(const Key('equip_interval_6')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('equip_save')));
      await tester.pumpAndSettle();
      final all = await EquipmentStore.load();
      expect(all.single.name, '토크 렌치');
      expect(all.single.category, EquipCategory.tool);
      expect(all.single.intervalMonths, 6);
    });

    testWidgets('같은 관리번호는 막는다', (tester) async {
      await _seed([_e('1', name: '먼저', assetNo: 'PG-1')]);
      await _open(tester, EquipmentEditPage(now: _clock));
      await tester.enterText(find.byKey(const Key('equip_name')), '나중');
      await tester.enterText(find.byKey(const Key('equip_assetno')), 'pg-1');
      await tester.tap(find.byKey(const Key('equip_save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('같은 관리번호'), findsOneWidget);
      expect((await EquipmentStore.load()).length, 1);
    });

    testWidgets('고칠 때는 자기 관리번호를 그대로 둬도 된다', (tester) async {
      final e = _e('1', name: '먼저', assetNo: 'PG-1');
      await _seed([e]);
      await _open(tester, EquipmentEditPage(existing: e, now: _clock));
      await tester.enterText(find.byKey(const Key('equip_name')), '이름 고침');
      await tester.tap(find.byKey(const Key('equip_save')));
      await tester.pumpAndSettle();
      expect((await EquipmentStore.load()).single.name, '이름 고침');
    });
  });

  group('상세', () {
    testWidgets('교정을 기록하면 기한이 새로 잡히고 이력이 쌓인다', (tester) async {
      await _seed([_e('1', name: '만료 게이지', last: DateTime(2025, 1, 1))]);
      await _open(tester, EquipmentDetailPage(id: '1', now: _clock, share: (t) async => _shared = t));
      expect(find.textContaining('일 지남'), findsOneWidget);

      await tester.tap(find.byKey(const Key('equip_inspect')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('inspect_by')), '한국교정');
      await tester.enterText(find.byKey(const Key('inspect_cert')), 'C-100');
      await tester.tap(find.byKey(const Key('inspect_save')));
      await tester.pumpAndSettle();

      final e = (await EquipmentStore.load()).single;
      expect(e.lastDone, DateTime(2026, 9, 30));
      expect(e.nextDue, DateTime(2027, 9, 30));
      expect(e.events.single.certNo, 'C-100');
      expect(find.textContaining('일 지남'), findsNothing);
      expect(find.textContaining('성적서 C-100'), findsOneWidget);
    });

    testWidgets('불합격이면 수리·점검 중이 되고 반출 단추가 막힌다', (tester) async {
      await _seed([_e('1', last: DateTime(2026, 9, 1))]);
      await _open(tester, EquipmentDetailPage(id: '1', now: _clock));
      await tester.tap(find.byKey(const Key('equip_inspect')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('inspect_result_$kResultFail')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('inspect_save')));
      await tester.pumpAndSettle();
      expect((await EquipmentStore.load()).single.status, EquipStatus.repair);
      final out = tester.widget<OutlinedButton>(find.byKey(const Key('equip_checkout')));
      expect(out.onPressed, isNull);
    });

    testWidgets('반출하면 사용자가 붙고 반납하면 비워진다', (tester) async {
      await _seed([_e('1', name: '벤더', interval: 0)]);
      await _open(tester, EquipmentDetailPage(id: '1', now: _clock));
      await tester.tap(find.byKey(const Key('equip_checkout')));
      await tester.pumpAndSettle();
      // 이름이 없으면 막는다.
      await tester.tap(find.byKey(const Key('checkout_save')));
      await tester.pump();
      expect(find.text('가져가는 사람을 적어 주십시오'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('checkout_who')), '홍길동');
      await tester.enterText(find.byKey(const Key('checkout_project')), '루마');
      await tester.tap(find.byKey(const Key('checkout_save')));
      await tester.pumpAndSettle();
      var e = (await EquipmentStore.load()).single;
      expect(e.holder, '홍길동');
      expect(e.holderProject, '루마');
      expect(find.byKey(const Key('equip_checkin')), findsOneWidget);

      await tester.tap(find.byKey(const Key('equip_checkin')));
      await tester.pumpAndSettle();
      e = (await EquipmentStore.load()).single;
      expect(e.isOut, false);
      expect(find.byKey(const Key('equip_checkout')), findsOneWidget);
    });

    testWidgets('폐기하면 이력은 남고 기한을 따지지 않는다', (tester) async {
      await _seed([_e('1', last: DateTime(2020, 1, 1))]);
      await _open(tester, EquipmentDetailPage(id: '1', now: _clock));
      await tester.tap(find.byKey(const Key('equip_detail_more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('폐기 처리'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('equip_confirm_yes')));
      await tester.pumpAndSettle();
      final e = (await EquipmentStore.load()).single;
      expect(e.isRetired, true);
      expect(e.dueState(_now), DueState.none);
      expect(find.text('폐기한 장비'), findsOneWidget);
    });

    testWidgets('지우면 대장에서 사라진다', (tester) async {
      await _seed([_e('1')]);
      await _open(tester, EquipmentDetailPage(id: '1', now: _clock));
      await tester.tap(find.byKey(const Key('equip_detail_more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('대장에서 지우기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('equip_confirm_yes')));
      await tester.pumpAndSettle();
      expect(await EquipmentStore.load(), isEmpty);
    });

    testWidgets('QR 라벨 화면에 QR과 글이 나온다', (tester) async {
      await _seed([_e('1', name: '게이지', assetNo: 'PG-1')]);
      await _open(tester, EquipmentDetailPage(id: '1', now: _clock));
      await tester.tap(find.byKey(const Key('equip_qr')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('equip_qr_view')), findsOneWidget);
      expect(find.text('FH-EQ:PG-1'), findsOneWidget);
    });

    testWidgets('없는 장비 번호면 안내한다', (tester) async {
      await _open(tester, EquipmentDetailPage(id: 'none', now: _clock));
      expect(find.text('장비를 찾을 수 없습니다'), findsOneWidget);
    });
  });
}
