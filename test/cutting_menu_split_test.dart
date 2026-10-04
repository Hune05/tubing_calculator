// 라인 컷팅과 단관 컷팅은 홈 메뉴·빠른 실행에서 각각 따로 들어간다("튜브 가공" 입구 화면은 없다).
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/common/quick_tool_bar.dart';
import 'package:tubing_calculator/src/presentation/menu/page/mobile_menu_page.dart';

void main() {
  group('빠른 실행 목록', () {
    QuickToolDef? byId(String id) {
      for (final t in kQuickTools) {
        if (t.id == id) return t;
      }
      return null;
    }

    test('라인 컷팅과 단관 컷팅이 따로 있고 같은 묶음(배관·튜브)에 있다', () {
      final line = byId('cut');
      final pipe = byId('shortpipe');
      expect(line?.label, '라인 컷팅');
      expect(pipe?.label, '단관 컷팅');
      expect(line?.group, '배관·튜브');
      expect(pipe?.group, '배관·튜브');
    });

    test('"튜브 가공"이라는 항목은 더 이상 없다', () {
      expect(kQuickTools.any((t) => t.label == '튜브 가공'), false);
    });

    test('빠른 실행 항목의 이름과 id는 겹치지 않는다', () {
      expect(kQuickTools.map((t) => t.id).toSet().length, kQuickTools.length);
      expect(kQuickTools.map((t) => t.label).toSet().length, kQuickTools.length);
    });
  });

  group('예전 이름으로 저장한 빠른 실행', () {
    test('"튜브 컷팅"·"튜브 가공"은 "라인 컷팅"으로 읽힌다', () {
      expect(renameQuickLaunchTitles(['튜브 컷팅', '압력시험']), ['라인 컷팅', '압력시험']);
      expect(renameQuickLaunchTitles(['튜브 가공']), ['라인 컷팅']);
    });

    test('둘 다 저장돼 있으면 하나만 남는다', () {
      expect(renameQuickLaunchTitles(['튜브 가공', '튜브 컷팅', '라인 컷팅']), ['라인 컷팅']);
    });

    test('단관 컷팅은 그대로', () {
      expect(renameQuickLaunchTitles(['단관 컷팅']), ['단관 컷팅']);
    });
  });
}
