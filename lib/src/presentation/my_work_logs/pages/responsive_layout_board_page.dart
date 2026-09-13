import 'package:flutter/material.dart';

import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/tablet_layout_board_page.dart';

/// 🚀 [신규] 폴더블(Z Fold4 등) 대응 - 작업 배치도 화면을 여는 도중에도
/// 화면을 펴거나 접으면 그 순간의 화면 크기에 맞는 버전으로 실시간 전환한다.
///
/// 예전엔 메뉴 버튼을 누르는 "그 순간"의 화면 크기로 Mobile/Tablet 버전
/// 중 하나를 딱 한 번만 골라서 push했기 때문에, 배치도를 펴놓은 채로
/// 화면을 펼쳐도 좁은 모바일 버전에 계속 갇혀 있었다.
///
/// ⚠️ 참고: Mobile/Tablet 버전은 배치한 모듈·치수선 등을 각자 별도의
/// State로 들고 있는 서로 다른 화면이라, 전환되는 순간 그 세션에서
/// 작업 중이던 내용(아직 저장하지 않은 배치)은 초기화된다. 저장 버튼을
/// 눌러 확정한 배치는 영향 없다.
class ResponsiveLayoutBoardPage extends StatelessWidget {
  // 🚀 [추가] 프로젝트 목록에서 저장된 도면을 다시 열 때 사용.
  final String? projectId;

  const ResponsiveLayoutBoardPage({super.key, this.projectId});

  @override
  Widget build(BuildContext context) {
    final bool isTabletSize = MediaQuery.of(context).size.shortestSide >= 600;
    return isTabletSize
        ? TabletLayoutBoardPage(projectId: projectId)
        : MobileLayoutBoardPage(projectId: projectId);
  }
}
