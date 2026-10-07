// 홈 검색의 "기록에서 찾기": 프로젝트·일지·이슈·자재를 찾고, 검색 창에서 기능 결과 아래에 덧붙는다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/common/feature_search.dart';
import 'package:tubing_calculator/src/presentation/common/record_search.dart';
import 'package:tubing_calculator/src/presentation/inventory/material_catalog.dart';

final _logs = <Map<String, dynamic>>[
  {
    'id': 'p1',
    'name': '루마 계장 배관',
    'daily_reports': [
      {
        'date': '2026-09-29',
        'note': '센서 3개소 결선 완료, 튜브 라인 연결',
        'work_type': ['결선/트레이싱'],
      },
      {'date': '2026-09-28', 'note': '지지대 설치'},
    ],
    'punch_lists': [
      {'content': '튜브 끝단 누설 확인 필요', 'location': 'B동 3층'},
    ],
  },
  {'id': 'p2', 'name': 'H2 캐비넷', 'daily_reports': [], 'punch_lists': []},
];

const _cat = [
  CatalogItem(
    id: 'a',
    name: '후강 전선관 22mm',
    category: 'CONDUIT',
    unit: '본',
    spec: '22mm',
  ),
  CatalogItem(id: 'b', name: '엘보 90도', category: 'ACC', unit: 'EA'),
];

void main() {
  group('searchRecords', () {
    test('빈 검색어는 아무것도 안 찾는다', () {
      expect(searchRecords('  ', _logs, _cat), isEmpty);
    });

    test('프로젝트 이름은 띄어쓰기·대소문자와 상관없이 찾는다', () {
      final r = searchRecords('h2', _logs, _cat);
      expect(r.single.kind, '프로젝트');
      expect(r.single.projectId, 'p2');
      expect(r.single.tab, 0);
      expect(searchRecords('계장배관', _logs, _cat).first.title, '루마 계장 배관');
    });

    test('일지 내용은 일지 탭(3), 이슈 내용은 이슈 탭(2)으로 열린다', () {
      final r = searchRecords('튜브', _logs, _cat);
      final report = r.firstWhere((e) => e.kind == '작업 일지');
      final issue = r.firstWhere((e) => e.kind == '이슈');
      expect(report.projectId, 'p1');
      expect(report.tab, 3);
      expect(report.title, '루마 계장 배관 · 2026-09-29');
      expect(report.subtitle, contains('튜브 라인 연결'));
      expect(issue.tab, 2);
      expect(issue.title, contains('B동 3층'));
      expect(issue.subtitle, contains('누설'));
    });

    test('자재는 이름·규격으로 찾고 프로젝트 없이 나온다', () {
      final r = searchRecords('22mm', _logs, _cat);
      final m = r.firstWhere((e) => e.kind == '자재');
      expect(m.title, '후강 전선관 22mm');
      expect(m.projectId, isNull);
      expect(m.subtitle, '자재 · 22mm · 본');
    });

    test('없는 말은 빈 목록', () {
      expect(searchRecords('없는말xyz', _logs, _cat), isEmpty);
    });

    test('실제 자재 목록으로도 끝나고 개수 상한을 지킨다', () {
      final r = searchRecords('전선관', const [], allMaterialCatalog());
      expect(r.length, lessThanOrEqualTo(kRecordMaxMaterials));
      expect(r, isNotEmpty);
    });
  });

  group('검색 창', () {
    Widget host(Future<List<FeatureItem>> Function(String) more) => MaterialApp(
      home: Scaffold(
        body: FeatureSearchSheet(
          title: '메뉴 검색',
          items: [FeatureItem(title: '공학용 계산기', subtitle: '', onTap: () {})],
          moreResults: more,
        ),
      ),
    );

    testWidgets('두 글자 이상 넣으면 기능 아래에 기록 결과가 붙는다', (tester) async {
      final asked = <String>[];
      await tester.pumpWidget(
        host((q) async {
          asked.add(q);
          return [
            FeatureItem(title: '루마 · 2026-09-29', subtitle: '작업 일지', onTap: () {}),
          ];
        }),
      );
      await tester.enterText(find.byKey(const Key('feature_search_field')), '공');
      await tester.pump(const Duration(milliseconds: 400));
      expect(asked, isEmpty); // 한 글자는 안 찾는다
      expect(find.text('기록에서 찾기'), findsNothing);

      await tester.enterText(find.byKey(const Key('feature_search_field')), '공학');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(asked, ['공학']);
      expect(find.text('기록에서 찾기'), findsOneWidget);
      expect(find.text('루마 · 2026-09-29'), findsOneWidget);
      expect(find.text('공학용 계산기'), findsOneWidget);
    });

    testWidgets('검색어를 지우면 기록 결과도 사라지고, 찾기가 실패해도 창은 멀쩡하다', (tester) async {
      await tester.pumpWidget(
        host((q) async => q == '오류'
            ? throw Exception('없음')
            : [FeatureItem(title: '결과A', subtitle: '', onTap: () {})]),
      );
      await tester.enterText(find.byKey(const Key('feature_search_field')), '결과');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('결과A'), findsOneWidget);
      await tester.tap(find.byKey(const Key('feature_search_clear')));
      await tester.pump();
      expect(find.text('결과A'), findsNothing);

      await tester.enterText(find.byKey(const Key('feature_search_field')), '오류');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('기록에서 찾기'), findsNothing);
    });

    testWidgets('예전처럼 moreResults 없이도 그대로 동작한다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeatureSearchSheet(
              title: '메뉴 검색',
              items: [FeatureItem(title: '공학용 계산기', subtitle: '', onTap: () {})],
            ),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('feature_search_field')), '공학');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('공학용 계산기'), findsOneWidget);
      expect(find.text('기록에서 찾기'), findsNothing);
    });

    testWidgets('다른 검색 화면으로 잇는 줄은 두 글자부터, 기록 머리글 위에 붙는다(기록이 없어도)', (tester) async {
      Future<List<FeatureItem>> more(String q) async =>
          q == '공학' ? [FeatureItem(title: '루마 일지', subtitle: '작업 일지', onTap: () {})] : const [];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeatureSearchSheet(
              title: '메뉴 검색',
              items: [FeatureItem(title: '공학용 계산기', subtitle: '', onTap: () {})],
              moreResults: more,
              searchElsewhere: (q) => FeatureItem(title: "자료 검색에서 '$q' 찾기", subtitle: '', onTap: () {}),
            ),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('feature_search_field')), '공');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('자료 검색에서'), findsNothing);
      await tester.enterText(find.byKey(const Key('feature_search_field')), '공학');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      final link = tester.getTopLeft(find.text("자료 검색에서 '공학' 찾기")).dy;
      final head = tester.getTopLeft(find.text('기록에서 찾기')).dy;
      expect(link < head, isTrue);
      await tester.enterText(find.byKey(const Key('feature_search_field')), '없는말');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text("자료 검색에서 '없는말' 찾기"), findsOneWidget);
      expect(find.text('기록에서 찾기'), findsNothing);
    });
  });
}
