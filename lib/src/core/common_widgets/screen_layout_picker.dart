// 화면 구성 고르기(자동·폰 화면·태블릿 화면). 누르면 바로 바뀌고 폰에 기억한다(기기마다 따로).
// 튜브 설정 탭 "앱 설정"과 전선관 설정에 현장 보기 밑에 같은 모양으로 둔다.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/field_view.dart';
import '../utils/screen_layout.dart';

class ScreenLayoutPicker extends StatelessWidget {
  const ScreenLayoutPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final p = FieldPalette.ofContext(context);
    return ValueListenableBuilder<ScreenLayoutMode>(
      valueListenable: ScreenLayout.mode,
      builder: (context, cur, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '화면 구성',
            style: AppText.body.copyWith(
              color: p.text,
              fontWeight: AppText.medium,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            '태블릿에서 두 칸 화면이 어색하면 폰 화면으로 바꾸십시오. 이 기기에만 적용됩니다.',
            style: AppText.sub.copyWith(color: p.textSub),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              for (final m in ScreenLayoutMode.values) ...[
                if (m != ScreenLayoutMode.values.first)
                  const SizedBox(width: AppSpace.sm),
                Expanded(child: _choice(p, m, m == cur)),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            cur.description,
            key: const Key('screen_layout_desc'),
            style: AppText.sub.copyWith(color: p.textSub),
          ),
        ],
      ),
    );
  }

  Widget _choice(FieldPalette p, ScreenLayoutMode m, bool selected) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? p.brand : p.fill,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: InkWell(
          key: Key('screen_layout_${m.name}'),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          onTap: () => ScreenLayout.set(m),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpace.sm,
                horizontal: AppSpace.xs,
              ),
              child: Center(
                child: Text(
                  m.label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kAppFontFamily,
                    fontSize: 14,
                    fontWeight: AppText.bold,
                    color: selected ? p.onBrand : p.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
