// 화면 머리 한 모양·아이콘 한 벌(UI 디자인 제안 D-E).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:tubing_calculator/src/core/theme/app_theme.dart';

/// lib 아래 dart 파일의 AppBar(...) 덩어리들.
Iterable<(String, String)> appBars() sync* {
  for (final f in Directory(
    'lib',
  ).listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    final s = f.readAsStringSync();
    for (final m in RegExp(r'\bAppBar\(').allMatches(s)) {
      var depth = 0;
      var end = s.length;
      for (var k = m.end - 1; k < s.length; k++) {
        if (s[k] == '(') depth++;
        if (s[k] == ')' && --depth == 0) {
          end = k + 1;
          break;
        }
      }
      yield (f.path, s.substring(m.start, end));
    }
  }
}

void main() {
  test('색으로 채운 머리가 없다(카메라·사진 편집의 검은 머리만 예외)', () {
    final colored = RegExp(
      r'^\s{0,12}backgroundColor:\s*(makitaTeal|Colors\.orange\.shade\d+|'
      r'CuttingColors\.primary|AppColors\.brand|slate900|tossBlue)\b',
      multiLine: true,
    );
    final bad = <String>[];
    for (final (path, bar) in appBars()) {
      // 머리 자체의 바탕만 본다(안의 단추 바탕은 뺀다): actions 앞부분.
      final head = bar.split('actions:').first;
      if (colored.hasMatch(head) &&
          !path.contains('mobile_inventory_dialogs.dart')) {
        bad.add(path);
      }
    }
    expect(bad, isEmpty, reason: '청록·주황으로 채운 머리: $bad');
  });

  test('뒤로·목록 화살표는 한 벌(AppIcons)만 쓴다', () {
    final old = RegExp(
      r'Icons\.(arrow_back\w*|chevron_right\w*|chevron_left\w*|'
      r'arrow_forward_ios\w*|keyboard_arrow_right\w*)\b',
    );
    final bad = <String>[];
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (old.hasMatch(lines[i])) bad.add('${f.path}:${i + 1}');
      }
    }
    expect(bad, isEmpty, reason: '$bad');
  });

  testWidgets('기본 뒤로 단추도 앱 아이콘', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        theme: buildAppTheme(),
        home: const Scaffold(body: Text('처음')),
      ),
    );
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(appBar: AppBar(title: const Text('다음'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.back), findsOneWidget);
  });
}
