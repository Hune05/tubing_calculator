/// 오프셋·굴림 오프셋·새들 시트의 방향 칸이 같이 쓰는 규칙.
///
/// 관이 이미 어느 축으로 가고 있으면 그 축(같은 쪽·반대쪽)으로는 꺾을 평면이 없어 못 꺾는다.
/// 입력 탭이 그 판단 함수([BendRule])를 시트에 넘겨 주면, 못 꺾는 방향 칸은 흐리게 하고
/// 누르면 이유만 알린다(선택은 안 된다). 함수를 안 넘기면(전선관 등) 예전처럼 모두 고를 수 있다.
library;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/common_widgets/app_components.dart';
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/app_dialog.dart';

/// 방향값(0 위·90 우·180 아래·270 좌·360 앞·450 뒤)으로 지금 꺾을 수 있는지.
typedef BendRule = bool Function(double rot);

/// 못 꺾는 방향을 눌렀을 때의 안내 창. (바닥 시트 위에서는 알림이 가려져서 창으로 띄운다.)
void showCannotBendNotice(BuildContext context, String label) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AppConfirmDialog(
      title: '그 방향으로는 못 꺾습니다',
      icon: const Icon(AppIcons.warning),
      cancelText: null,
      okText: '확인',
      onOk: () => Navigator.pop(ctx),
      content: AppDialog.message(
        "관이 이미 '$label' 쪽이나 그 반대쪽으로 가고 있습니다.\n"
        '다른 축(위·아래·앞·뒤 등)에서 고르십시오.',
      ),
    ),
  );
}

/// 방향 칸 하나를 규칙에 맞게 감싼다. [chip]은 눌림 처리를 받아 칸을 그린다.
Widget gateSheetDirection({
  required BuildContext context,
  required BendRule? rule,
  required double rot,
  required String label,
  required VoidCallback onPick,
  required Widget Function(VoidCallback onTap) chip,
}) {
  final allowed = rule == null || rule(rot);
  return Opacity(
    key: ValueKey('sheet_dir_$rot'),
    opacity: allowed ? 1.0 : 0.38,
    child: chip(allowed ? onPick : () => showCannotBendNotice(context, label)),
  );
}
