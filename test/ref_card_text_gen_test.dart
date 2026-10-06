// 현장 자료 카드 본문 색인(자료 검색용)을 만들고, 화면과 어긋나지 않았는지 확인한다(10-07).
// 현장 자료 탭(튜브·전선관·형강·발전 설비·KEC)을 실제로 그려 카드마다 보이는 글을 모은다.
//
// 화면 글을 바꿔 이 시험이 실패하면 아래 명령으로 색인 파일을 다시 만든다(PowerShell):
//   $env:GEN_REF_INDEX='1'; flutter test test/ref_card_text_gen_test.dart; Remove-Item Env:GEN_REF_INDEX
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/reference/page/ref_card_text.g.dart';
import 'package:tubing_calculator/src/presentation/reference/page/ref_conduit_tab.dart';
import 'package:tubing_calculator/src/presentation/reference/page/ref_kec_tab.dart';
import 'package:tubing_calculator/src/presentation/reference/page/ref_plant_tab.dart';
import 'package:tubing_calculator/src/presentation/reference/page/ref_steel_tab.dart';
import 'package:tubing_calculator/src/presentation/reference/page/ref_tube_tab.dart';
import 'package:tubing_calculator/src/presentation/reference/page/reference_widgets.dart';

const _out = 'lib/src/presentation/reference/page/ref_card_text.g.dart';

/// 탭 번호(현장 자료 화면 순서)와 그 탭 위젯.
final _tabs = <(int, Widget)>[
  (0, const RefTubeTab()),
  (1, const RefConduitTab()),
  (2, const RefSteelTab()),
  (4, const RefPlantTab()),
  (5, const RefKecTab()),
];

/// 짧은 조각(표 칸)은 한 줄로 이어 붙이고, 같은 줄이 이어지면 하나만 둔다.
List<String> _tidy(List<String> parts) {
  final out = <String>[];
  var buf = '';
  void flush() {
    if (buf.isNotEmpty) out.add(buf);
    buf = '';
  }

  for (final raw in parts) {
    // 아이콘 글꼴 글자(사용자 정의 영역)는 뺀다.
    final p = raw
        .replaceAll(RegExp(r'[-]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (p.isEmpty) continue;
    if (out.isNotEmpty && out.last == p) continue;
    if (p.length <= 14) {
      buf = buf.isEmpty ? p : (buf.length + p.length > 90 ? (() { flush(); return p; })() : '$buf · $p');
    } else {
      flush();
      out.add(p);
    }
  }
  flush();
  return out;
}

String _lit(String s) =>
    "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$')}'";

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('현장 자료 카드 본문 색인이 화면과 같다', (t) async {
    t.view.physicalSize = const Size(800, 60000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    kRefExpandAll = true;
    addTearDown(() => kRefExpandAll = false);
    final cards = <(int, String, List<String>)>[];
    for (final (tab, w) in _tabs) {
      await t.pumpWidget(MaterialApp(home: Scaffold(body: w)));
      await t.pumpAndSettle();
      final keyed = find.byWidgetPredicate(
        (x) => x.key is ValueKey<String> && (x.key! as ValueKey<String>).value.startsWith('refcard:'),
      );
      for (final el in keyed.evaluate()) {
        final title = ((el.widget.key! as ValueKey<String>).value).substring(8);
        final texts = [
          for (final r in t.widgetList<RichText>(
            find.descendant(of: find.byWidget(el.widget), matching: find.byType(RichText)),
          ))
            r.text.toPlainText(),
        ].where((s) => s.trim() != title.trim()).toList();
        cards.add((tab, title, _tidy(texts)));
      }
    }
    expect(cards.length, greaterThan(20));
    final b = StringBuffer()
      ..writeln('// 생성 파일: test/ref_card_text_gen_test.dart가 현장 자료 탭을 그려 카드마다 보이는 글을 모았다.')
      ..writeln('// 직접 고치지 말 것. 화면 글을 바꾸면 그 시험 머리글의 명령으로 다시 만든다.')
      ..writeln('library;')
      ..writeln()
      ..writeln('/// (탭 번호, 카드 제목, 본문 줄). 자료 검색이 현장 자료 카드 내용을 찾는 데 쓴다.')
      ..writeln('const List<(int, String, List<String>)> kRefCardText = [');
    for (final (tab, title, lines) in cards) {
      b.writeln('  ($tab, ${_lit(title)}, [');
      for (final l in lines) {
        b.writeln('    ${_lit(l)},');
      }
      b.writeln('  ]),');
    }
    b.writeln('];');
    final text = b.toString();
    if (Platform.environment['GEN_REF_INDEX'] == '1') {
      File(_out).writeAsStringSync(text);
      return;
    }
    expect(
      File(_out).readAsStringSync().replaceAll('\r\n', '\n'),
      text,
      reason: '현장 자료 화면 글이 바뀌었습니다. 이 파일 머리글의 명령으로 색인을 다시 만드십시오.',
    );
    // 생성 파일을 실제로 읽어 쓰는지(상수가 비지 않았는지)
    expect(kRefCardText.length, cards.length);
  });
}
