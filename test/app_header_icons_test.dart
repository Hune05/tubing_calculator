// 화면 머리 한 모양·아이콘 한 벌(UI 디자인 제안 D-E).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/common_widgets/app_header.dart';
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:tubing_calculator/src/core/theme/app_theme.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_remote_page.dart';

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

  testWidgets('흰 머리 + 모드 칩: 좁아도 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            appBar: appHeader(
              context,
              title: '아주 긴 제목이 들어가는 마킹 가이드 화면',
              mode: ModeChip(label: '전동', color: Colors.orange.shade800),
              actions: [
                IconButton(onPressed: () {}, icon: const Icon(AppIcons.search)),
                IconButton(onPressed: () {}, icon: const Icon(AppIcons.more)),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('전동'), findsOneWidget);
    final bar = tester.widget<AppBar>(find.byType(AppBar));
    expect(bar.backgroundColor, AppColors.surface);
  });

  testWidgets('리모컨 머리: 모드 색 띠 대신 흰 머리, 모드 이름은 진한 글씨', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const MobileRemotePage()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final header = tester.widget<Container>(
      find.byKey(const Key('remote_header')),
    );
    expect((header.decoration as BoxDecoration).color, AppColors.surface);
    final name = tester.widget<Text>(find.text('직관 (Straight)'));
    expect(name.style?.color, AppColors.text);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
