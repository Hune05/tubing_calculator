// 라인 진행 보드(10-10): 라인마다 단계 체크, 두 기기 합치기(단계마다 나중 체크), 압력시험·교정 기록 자동 체크,
// 화면에서 라인 넣기·체크·단계 이름 바꾸기.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/repositories/work_project_repository.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/line_auto_check.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/line_progress.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_merge.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/line_board_page.dart';

Map<String, dynamic> _line(String id, String name) => {
  'id': id,
  'name': name,
  'done': <String, dynamic>{},
};

class _FakeRepo extends WorkProjectRepository {
  final List<Map<String, dynamic>> projects;
  Map<String, dynamic>? saved;
  _FakeRepo(this.projects);

  @override
  Future<List<Map<String, dynamic>>> fetchCachedProjects() async => [
    for (final p in projects) Map<String, dynamic>.from(p),
  ];

  @override
  Future<List<Map<String, dynamic>>> fetchAllProjects() async =>
      fetchCachedProjects();

  @override
  Future<void> upsertProject(
    Map<String, dynamic> project, {
    bool merge = true,
    void Function()? onWritten,
  }) async {
    saved = project;
    onWritten?.call();
  }
}

void main() {
  group('자료', () {
    test('기본 단계, 체크·풀기, 다 마침', () {
      final log = <String, dynamic>{};
      expect(lineStagesOf(log), kDefaultLineStages);
      final l = _line('1', '1F-PT-101');
      final stages = lineStagesOf(log);
      for (final s in stages) {
        setLineStage(l, s, true, who: '홍길동', now: DateTime(2026, 10, 10));
      }
      expect(lineComplete(l, stages), isTrue);
      expect(lineStageMark(l, '설치')!.by, '홍길동');
      setLineStage(l, '설치', false);
      expect(lineStageDone(l, '설치'), isFalse);
      expect(lineComplete(l, stages), isFalse);
    });

    test('라인 찾기: 띄어쓰기·대소문자 무시, 태그는 조각이 이어서 든 라인 하나일 때만', () {
      final log = {
        kLineItemsKey: [
          _line('1', '1F-PT-101'),
          _line('2', '1F-PT-1011'),
          _line('3', '2F-FT-201'),
          _line('4', '3F-FT-201'),
        ],
      };
      expect(findLine(log, ' 1f-pt-101 ')!['id'], '1');
      expect(findLineForTag(log, 'PT-101')!['id'], '1'); // 1011은 다른 조각
      expect(findLineForTag(log, 'FT-201'), isNull); // 두 라인에 들어 있음
      expect(findLineForTag(log, 'TT-9'), isNull);
    });

    test('기록 종류 → 단계: 압력시험은 "압력", 교정은 "교정" 없으면 "루프"', () {
      expect(stageForRecord(kDefaultLineStages, pressure: true), '압력시험');
      expect(stageForRecord(kDefaultLineStages, pressure: false), '루프 체크');
      expect(
        stageForRecord(['설치', '기밀시험', '교정', '루프'], pressure: false),
        '교정',
      );
      expect(stageForRecord(['설치', '기밀시험'], pressure: true), '기밀시험');
      expect(stageForRecord(['설치'], pressure: true), isNull);
    });

    test('붙여넣기: 엑셀 열·탭·빈 줄·같은 이름', () {
      expect(parseLineNames('1F-PT-101\r\n\r\n1F-PT-102\t1f-pt-101\n  2F-FT-201 '), [
        '1F-PT-101',
        '1F-PT-102',
        '2F-FT-201',
      ]);
    });

    test('진행 수와 엑셀', () {
      final a = _line('1', 'A');
      final b = _line('2', 'B "x"');
      for (final s in kDefaultLineStages) {
        setLineStage(a, s, true, now: DateTime(2026, 10, 9));
      }
      setLineStage(b, '설치', true, now: DateTime(2026, 10, 10));
      final log = {kLineItemsKey: [a, b]};
      final p = lineProgress(log);
      expect(p.total, 2);
      expect(p.complete, 1);
      expect(p.perStage['설치'], 2);
      expect(p.perStage['압력시험'], 1);
      final csv = buildLineCsv(log).split('\n');
      expect(csv.first, contains('"라인","컷팅·벤딩","설치","서포트","압력시험","루프 체크","메모"'));
      expect(csv[2], startsWith('"B ""x""","","2026-10-10",""'));
    });

    test('두 기기가 같은 라인의 다른 단계를 체크하면 둘 다 남고, 나중에 푼 것은 풀린 채', () {
      Map<String, dynamic> doc(Map<String, dynamic> line) => {
        'id': 'p',
        kLineItemsKey: [line],
      };
      final phone = _line('L1', '1F-PT-101');
      final tab = _line('L1', '1F-PT-101');
      setLineStage(phone, '설치', true, now: DateTime(2026, 10, 10, 9));
      setLineStage(tab, '서포트', true, now: DateTime(2026, 10, 10, 9, 5));
      setLineStage(tab, '압력시험', true, now: DateTime(2026, 10, 10, 9, 6));
      setLineStage(phone, '압력시험', false, now: DateTime(2026, 10, 10, 9, 7));
      final merged = mergeProjectDocs(local: doc(phone), server: doc(tab));
      final l = (merged[kLineItemsKey] as List).single as Map;
      expect(lineStageDone(l, '설치'), isTrue);
      expect(lineStageDone(l, '서포트'), isTrue);
      expect(lineStageDone(l, '압력시험'), isFalse); // 9:07에 푼 것이 이긴다
    });
  });

  group('자동 체크', () {
    late _FakeRepo repo;
    setUp(() {
      repo = _FakeRepo([
        {
          'id': 'p1',
          'name': '루마',
          kLineItemsKey: [_line('L1', '1F-PT-101'), _line('L2', '1F-PT-102')],
        },
      ]);
      lineCheckRepo = () => repo;
    });
    tearDown(() => lineCheckRepo = WorkProjectRepository.new);

    test('압력시험 합격 기록: 라인 이름이 맞으면 압력시험 체크', () async {
      final note = await autoCheckLineStage(
        projectId: 'p1',
        name: '1F-PT-101',
        pressure: true,
        who: '김시험',
      );
      expect(note, '라인 진행에 표시: 1F-PT-101 압력시험');
      final l = (repo.saved![kLineItemsKey] as List).first as Map;
      expect(lineStageDone(l, '압력시험'), isTrue);
      expect(lineStageMark(l, '압력시험')!.by, '김시험');
    });

    test('교정 기록: 태그 PT-102 → 라인 1F-PT-102 루프 체크', () async {
      final note = await autoCheckLineStage(
        projectId: 'p1',
        name: 'PT-102',
        pressure: false,
      );
      expect(note, '라인 진행에 표시: 1F-PT-102 루프 체크');
    });

    test('프로젝트·라인이 없거나 이미 체크했으면 아무것도 안 한다', () async {
      expect(
        await autoCheckLineStage(projectId: '', name: 'X', pressure: true),
        isNull,
      );
      expect(
        await autoCheckLineStage(projectId: 'p1', name: '없는 라인', pressure: true),
        isNull,
      );
      expect(repo.saved, isNull);
    });
  });

  group('화면', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('라인 넣기 → 동그라미로 체크 → 요약, 단계 이름을 바꾸면 체크가 따라간다', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      final log = <String, dynamic>{'id': 'p', 'name': 'TEST'};
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: LineBoardPage(log: log, onChanged: () => saves++),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('line_add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('line_add_field')),
        '1F-PT-101\n1F-PT-102\n1F-PT-101',
      );
      await tester.tap(find.byKey(const Key('line_add_ok')));
      await tester.pumpAndSettle();
      expect(lineItemsOf(log).length, 2);
      expect(find.text('다 마친 라인 0 / 2'), findsOneWidget);

      for (final s in kDefaultLineStages) {
        await tester.tap(find.byKey(Key('line_dot_1F-PT-101_$s')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('다 마친 라인 1 / 2'), findsOneWidget);
      expect(saves, greaterThanOrEqualTo(6));

      // 단계 이름: "서포트" → "서포트 설치"(같은 자리) — 체크가 따라간다.
      await tester.tap(find.byKey(const Key('line_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('단계 이름 고치기'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('line_stage_field')),
        '컷팅·벤딩\n설치\n서포트 설치\n압력시험\n루프 체크',
      );
      await tester.tap(find.byKey(const Key('line_stage_ok')));
      await tester.pumpAndSettle();
      final l = lineItemsOf(log).firstWhere((e) => e['name'] == '1F-PT-101');
      expect(lineStageDone(l, '서포트 설치'), isTrue);
      expect(find.text('다 마친 라인 1 / 2'), findsOneWidget);
    });
  });

  test('단계 줄임 이름', () {
    expect(lineStageShort('컷팅·벤딩'), '컷벤');
    expect(lineStageShort('루프 체크'), '루프');
    expect(lineStageShort('설치'), '설치');
  });
}
