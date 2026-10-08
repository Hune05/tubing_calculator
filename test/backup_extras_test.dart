import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/conduit_drawings.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/backup_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/layout_board_models.dart' show LayoutOwner;

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

  group('배치도 복원은 내 것만, 서버에 있는 것은 덮지 않는다(10-09 사용자 결정)', () {
    const me = LayoutOwner(uid: 'u-me', name: '나');
    final raw = [
      {'id': 'mine-gone', 'data': {'ownerUid': 'u-me', 'name': '지운 내 배치도'}},
      {'id': 'mine-there', 'data': {'ownerUid': 'u-me', 'name': '서버에 있는 내 배치도'}},
      {'id': 'old-shared', 'data': {'name': '주인 칸 없는 예전 배치도'}},
      {'id': 'other', 'data': {'ownerUid': 'u-other', 'name': '남의 배치도'}},
      {'id': 'other-name', 'data': {'ownerName': '김동료', 'name': '이름만 있는 남의 배치도'}},
      'broken',
    ];

    test('서버에 없는 내 것·예전 것만 쓰고, 있는 것과 남의 것은 건드리지 않는다', () {
      final plan = planLayoutRestore(raw, {'mine-there', 'other'}, me);
      expect(plan.write.map((w) => w.id), ['mine-gone', 'old-shared']);
      expect(plan.kept, 1);
      expect(plan.others, 2);
    });

    test('백업에 담는 배치도도 같은 규칙(남의 것 빼기)', () {
      expect(layoutBelongsInBackup({'ownerUid': 'u-me'}, me), isTrue);
      expect(layoutBelongsInBackup({}, me), isTrue);
      expect(layoutBelongsInBackup({'ownerUid': 'u-other'}, me), isFalse);
      expect(layoutBelongsInBackup({'ownerName': '김동료'}, me), isFalse);
    });

    test('복원 알림에 그대로 둔 것·뺀 것·통신 없음이 나온다', () {
      final t = restoreResultText(
        const RestoreResult(2, 1, 0, layoutsKept: 3, layoutsOthers: 1),
      );
      expect(t, contains('배치도 1개'));
      expect(t, contains('서버에 있는 배치도 3개는 그대로'));
      expect(t, contains('다른 사람 배치도 1개는 뺐습니다'));
      final off = restoreResultText(const RestoreResult(2, 0, 0, layoutsUnchecked: true));
      expect(off, contains('통신이 없어 배치도는 되돌리지 않았습니다'));
    });
  });

  test('이름 없는 사람의 클라우드 백업은 맨 위 공용 폴더가 아닌 자기 폴더로(10-09)', () {
    expect(cloudBackupFolderName('김현장', 'u1'), '김현장');
    expect(cloudBackupFolderName('a/b#c', null), 'a_b_c');
    expect(cloudBackupFolderName(null, 'u1'), 'uid_u1');
    expect(cloudBackupFolderName('  ', 'u1'), 'uid_u1');
    expect(cloudBackupFolderName('로그인 필요', null), '_no_name');
    expect(cloudBackupFolderName('', ''), '_no_name');
  });
}
