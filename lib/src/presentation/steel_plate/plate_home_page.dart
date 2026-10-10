// 철판 가공 첫 화면(10-10): 레이저 절단 / 절단 + 절곡 / 손그림 읽어 만들기 중에서 고른다.
// 셋 다 구멍 배치 편집·DXF·가공 지시서 PDF를 같이 쓴다. 메뉴·빠른 실행·자료 검색이 이 화면을 연다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_icon_set.dart';
import '../../core/theme/field_view.dart';
import '../common/app_icons.dart';
import 'plate_page.dart';
import 'plate_sketch_page.dart';

class PlateHomePage extends StatelessWidget {
  const PlateHomePage({super.key});

  @override
  Widget build(BuildContext context) => FieldViewTheme(
    child: Builder(
      builder: (context) {
        Widget row(
          String key,
          AppGlyph glyph,
          String title,
          String sub,
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
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.push(context, MaterialPageRoute(builder: page));
            },
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
                      ],
                    ),
                  ),
                  Icon(AppIcons.forward, color: fc.textFaint),
                ],
              ),
            ),
          ),
        );

        return Scaffold(
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
              row(
                'ph_cut',
                AppGlyph.plateCut,
                '레이저 절단',
                '평판·삼각 리브·자유 모양을 자르기만 합니다. 네 귀 R·C·따내기, 구멍·장공.',
                (_) => const PlatePage(),
              ),
              const SizedBox(height: 10),
              row(
                'ph_bend',
                AppGlyph.plateBend,
                '절단 + 절곡',
                'ㄱ·ㄷ·Z·모자로 꺾습니다. 전개도·꺾기선·공제값.',
                (_) => const PlatePage(bend: true),
              ),
              const SizedBox(height: 10),
              row(
                'ph_sketch',
                AppGlyph.plateSketch,
                '손그림 읽어 만들기',
                '종이에 그린 그림 사진을 AI가 읽습니다. 안 되면 사진 위에 직접 찍고 치수를 넣습니다.',
                (_) => const PlateSketchPage(),
              ),
              const SizedBox(height: 16),
              Text(
                '셋 다 구멍 배치 편집, 레이저 업체에 보낼 DXF, 가공 지시서 PDF를 같이 씁니다. 입력은 화면마다 따로 남습니다.',
                style: TextStyle(fontSize: 14, color: fc.textSub, height: 1.4),
              ),
            ],
          ),
        );
      },
    ),
  );
}
