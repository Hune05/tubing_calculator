// 철판 가공 첫 화면(10-10): 레이저 절단 / 절단 + 절곡 / 손그림 읽어 만들기 중에서 고른다.
// 셋 다 구멍 배치 편집·DXF·가공 지시서 PDF를 같이 쓴다. 메뉴·빠른 실행·자료 검색이 이 화면을 연다.
// 줄마다 마지막에 하던 것("이어서: …")을 보이고, 들어갔다 나오면 다시 읽는다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_icon_set.dart';
import '../../core/theme/field_view.dart';
import '../common/app_icons.dart';
import 'plate_page.dart';
import 'plate_sketch_model.dart';
import 'plate_sketch_page.dart';

String _f(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s;
}

/// 손그림 남은 것 한 줄(없거나 비었으면 null).
String? plateSketchLabel(PlateSketch? s) {
  if (s == null || (s.n == 0 && s.holes.isEmpty)) return null;
  final b = s.bounds;
  if (s.scaled && b != null && s.n >= 3) {
    return '${_f(b.width)} × ${_f(b.height)} · 꼭짓점 ${s.n}개${s.holes.isEmpty ? '' : ' · 홀 ${s.holes.length}개'}';
  }
  return '꼭짓점 ${s.n}개 · 치수 넣기 전';
}

class PlateHomePage extends StatefulWidget {
  const PlateHomePage({super.key});

  @override
  State<PlateHomePage> createState() => _PlateHomePageState();
}

class _PlateHomePageState extends State<PlateHomePage> {
  String? _cut, _bend, _sketch;

  @override
  void initState() {
    super.initState();
    _readLast();
  }

  Future<void> _readLast() async {
    String? lbl(String? raw) {
      if (raw == null) return null;
      try {
        final m = jsonDecode(raw);
        final l = m is Map ? m['lbl'] : null;
        return l is String && l.isNotEmpty ? l : null;
      } catch (_) {
        return null;
      }
    }

    try {
      final p = await SharedPreferences.getInstance();
      final sk = p.getString(PlateSketchPage.draftKey);
      PlateSketch? s;
      try {
        s = sk == null ? null : PlateSketch.fromJson(jsonDecode(sk));
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _cut = lbl(p.getString(PlatePage.draftKeyOf(false)));
        _bend = lbl(p.getString(PlatePage.draftKeyOf(true)));
        _sketch = plateSketchLabel(s);
      });
    } catch (_) {}
  }

  Future<void> _open(WidgetBuilder page) async {
    HapticFeedback.selectionClick();
    await Navigator.push(context, MaterialPageRoute(builder: page));
    if (mounted) _readLast();
  }

  Widget _row(
    String key,
    AppGlyph glyph,
    String title,
    String sub,
    String? last,
    WidgetBuilder page,
  ) => Material(
    color: fc.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: fc.line),
    ),
    child: InkWell(
      key: Key(key),
      borderRadius: BorderRadius.circular(16),
      onTap: () => _open(page),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: fc.brand.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: AppIcon(glyph, size: 28, color: fc.brand),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: fc.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 14,
                      color: fc.textSub,
                      height: 1.35,
                    ),
                  ),
                  if (last != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '이어서: $last',
                      key: Key('${key}_last'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: fc.brand,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(AppIcons.forward, color: fc.textFaint),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => FieldViewTheme(
    child: Builder(
      builder: (context) => Scaffold(
        backgroundColor: fc.background,
        appBar: AppBar(
          backgroundColor: fc.surface,
          foregroundColor: fc.text,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            '철판 가공',
            style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _row(
              'ph_cut',
              AppGlyph.plateCut,
              '레이저 절단',
              '평판·삼각 리브·좌표 입력을 자르기만 합니다. 네 코너 R·C·따내기, 홀·장공.',
              _cut,
              (_) => const PlatePage(),
            ),
            const SizedBox(height: 10),
            _row(
              'ph_bend',
              AppGlyph.plateBend,
              '절단 + 절곡',
              'ㄱ·ㄷ·Z·모자로 절곡합니다. 전개도·절곡선·공제값.',
              _bend,
              (_) => const PlatePage(bend: true),
            ),
            const SizedBox(height: 10),
            _row(
              'ph_sketch',
              AppGlyph.plateSketch,
              '스케치로 만들기',
              '종이 스케치 사진을 AI가 읽거나, 화면에 손가락으로 직접 그립니다. 치수를 넣어 레이저 절단으로 보냅니다.',
              _sketch,
              (_) => const PlateSketchPage(),
            ),
            const SizedBox(height: 16),
            Text(
              '셋 다 홀 넣기·고치기, 레이저 업체에 보낼 DXF, 가공 도면 PDF를 같이 씁니다. 입력은 화면마다 따로 남습니다.',
              style: TextStyle(fontSize: 14, color: fc.textSub, height: 1.4),
            ),
          ],
        ),
      ),
    ),
  );
}
