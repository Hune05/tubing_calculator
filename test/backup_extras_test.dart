import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/conduit_drawings.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/backup_tools.dart';

// 백업 파일에 배치도·내 일정이 함께 담기는 것과, 옛 백업과의 호환.
String backupText({List? layouts, List? schedules}) => jsonEncode({
  'app': 'tubing_calculator',
  'version': 1,
  'exportedAt': DateTime(2026, 9, 19, 20).toIso8601String(),
  'projects': [
    {'id': '1', 'name': 'A'},
    {'id': '2', 'name': 'B'},
  ],
  'templates': [
    {'id': 't1'},
  ],
  'favMaterials': [],
  'layouts': ?layouts,
  'personalSchedules': ?schedules,
});

void main() {
  test('배치도·내 일정 개수를 읽는다', () {
    final p = parseBackup(
      backupText(
        layouts: [
          {'id': 'l1', 'data': {}},
          {'id': 'l2', 'data': {}},
        ],
        schedules: [
          {'id': 's1', 'data': {}},
        ],
      ),
    );
    expect(p.projects, 2);
    expect(p.templates, 1);
    expect(p.layouts, 2);
    expect(p.schedules, 1);
  });

  test('옛 백업(배치도·내 일정 없음)은 0으로 읽고 그대로 복원할 수 있다', () {
    final p = parseBackup(backupText());
    expect(p.layouts, 0);
    expect(p.schedules, 0);
    expect(p.projects, 2);
  });

  test('한 줄 요약: 있는 것만 붙인다', () {
    expect(backupContentsLine(parseBackup(backupText())), '프로젝트 2건, 템플릿 1개');
    expect(
      backupContentsLine(
        parseBackup(
          backupText(
            layouts: [
              {'id': 'l1'},
            ],
          ),
        ),
      ),
      '프로젝트 2건, 템플릿 1개, 배치도 1개',
    );
    expect(
      backupContentsLine(
        parseBackup(
          backupText(
            layouts: [
              {'id': 'l1'},
            ],
            schedules: [
              {'id': 's1'},
              {'id': 's2'},
            ],
          ),
        ),
      ),
      '프로젝트 2건, 템플릿 1개, 배치도 1개, 내 일정 2건',
    );
  });

  test('프로젝트 복원 미리 보기는 그대로 동작한다', () {
    final p = parseBackup(backupText());
    final plan = planRestore(p, [
      {'id': '1', 'name': 'A현재'},
      {'id': '9', 'name': '없는것'},
    ]);
    expect(plan.overwritten, ['A']);
    expect(plan.added, ['B']);
    expect(plan.untouched, 1);
  });

  test('이 앱의 백업이 아니면 알려 준다', () {
    expect(() => parseBackup('{"app":"x"}'), throwsFormatException);
  });

  group('도면 보관함도 백업에 들어간다(점검 23번)', () {
    final tubeDb = <Map<String, dynamic>>[];
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tubeDb.clear();
      tubeDrawingsReader = () async => [
        for (var i = 0; i < tubeDb.length; i++) {'id': i + 1, ...tubeDb[i]},
      ];
      tubeDrawingWriter = (row) async => tubeDb.add(row);
    });

    Map<String, dynamic> raw() => {
      'tubeDrawings': [
        {
          'date': '2026-09-20 10:00',
          'bend_data': '[{"length":300,"angle":90}]',
          'p_to_p': '{"project":"A"}',
          'pipe_size': '1/2"',
          'total_length': '612.0',
        },
      ],
      'conduitDrawings': [
        {
          'id': 'c1',
          'folderName': 'EPS실',
          'title': '벤드 1개',
          'savedAt': '2026-09-20 11:00',
          'totalCut': 618.0,
          'bends': [
            {'length': 300.0, 'angle': 90.0, 'rotation': 0.0},
          ],
          'settings': <String, dynamic>{},
        },
      ],
    };

    test('되돌리면 튜브·전선관 도면이 보관함에 들어가고, 두 번 해도 한 벌', () async {
      var r = await restoreDrawings(raw());
      expect(r.tube, 1);
      expect(r.conduit, 1);
      r = await restoreDrawings(raw());
      expect(r.tube, 0);
      expect(r.conduit, 0);
      expect(tubeDb.length, 1);
      expect(tubeDb.single['pipe_size'], '1/2"');
      final c = await loadConduitDrawings();
      expect(c.single.folderName, 'EPS실');
    });

    test('한 줄 요약에 도면 개수가 붙는다', () {
      final j = jsonDecode(backupText()) as Map<String, dynamic>;
      j.addAll(raw());
      expect(
        backupContentsLine(parseBackup(jsonEncode(j))),
        '프로젝트 2건, 템플릿 1개, 튜브 도면 1개, 전선관 도면 1개',
      );
    });
  });
}
