// 전선관 보관함 한 건이 깨져도 나머지는 읽는다(10-08).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/conduit_drawings.dart';

void main() {
  test('형이 어긋난 한 건(totalCut이 글자)은 건너뛰고 나머지 도면은 남는다', () async {
    SharedPreferences.setMockInitialValues({
      kConduitDrawingsPrefsKey: jsonEncode([
        {'id': '1', 'folderName': 'A', 'title': '좋은 도면', 'totalCut': 600, 'bends': []},
        {'id': '2', 'folderName': 'A', 'title': '깨진 도면', 'totalCut': '육백', 'bends': []},
      ]),
    });
    final list = await loadConduitDrawings();
    expect(list.map((d) => d.title), ['좋은 도면']);
  });
}
