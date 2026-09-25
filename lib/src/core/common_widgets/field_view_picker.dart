// 현장 보기 고르기(보통·햇빛·야간, UI 디자인 제안 D-D). 누르면 바로 바뀌고 폰에 기억한다.
// 튜브 설정 탭 "앱 설정"과 전선관 설정에 같은 모양으로 둔다. 현장 탭의 햇빛 단추도 같은 값이다.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/field_view.dart';

class FieldViewModePicker extends StatelessWidget {
  const FieldViewModePicker({super.key});

  static IconData _icon(FieldViewMode m) => switch (m) {
    FieldViewMode.normal => Icons.brightness_medium_rounded,
    FieldViewMode.sunlight => Icons.wb_sunny_rounded,
    FieldViewMode.night => Icons.nightlight_round,
  };

  @override
  Widget build(BuildContext context) {
    final p = FieldPalette.ofContext(context);
    return ValueListenableBuilder<FieldViewMode>(
      valueListenable: FieldColors.mode,
      builder: (context, cur, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '현장 보기',
            style: AppText.body.copyWith(
              color: p.text,
              fontWeight: AppText.medium,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            '계산기·현장 탭·수평계·각도기·리모컨 화면의 색입니다.',
            style: AppText.sub.copyWith(color: p.textSub),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              for (final m in FieldViewMode.values) ...[
                if (m != FieldViewMode.values.first)
                  const SizedBox(width: AppSpace.sm),
                Expanded(child: _choice(p, m, m == cur)),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            cur.description,
            key: const Key('field_view_desc'),
            style: AppText.sub.copyWith(color: p.textSub),
          ),
        ],
      ),
    );
  }

  Widget _choice(FieldPalette p, FieldViewMode m, bool selected) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? p.brand : p.fill,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: InkWell(
          key: Key('field_view_${m.name}'),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          onTap: () => FieldColors.set(m),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpace.sm,
                horizontal: AppSpace.xs,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _icon(m),
                    size: 20,
                    color: selected ? p.onBrand : p.textSub,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m.label,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: kAppFontFamily,
                      fontSize: 14,
                      fontWeight: AppText.bold,
                      color: selected ? p.onBrand : p.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
