// 튜브 가공: 튜브를 자르는 두 가지 화면의 입구.
//  - 라인 컷팅: 지점마다 부속을 골라 부속 공제를 빼고 구간별 절단 길이를 구한다(작업·기록·재고 차감).
//  - 단관 컷팅: 부속 없이 같은 길이를 여러 개 자를 때 원자재 본수와 자르는 눈금을 본다.
import 'package:flutter/material.dart';

import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';

import '../cutting_theme.dart';
import 'mobile_cutting_project_list_page.dart';
import 'short_pipe_cutting_page.dart';

class TubeWorkHubPage extends StatelessWidget {
  const TubeWorkHubPage({super.key});

  Widget _card({
    required Key key,
    required IconData icon,
    required String title,
    required String line1,
    required String line2,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: CuttingColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CuttingColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: CuttingColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: CuttingColors.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: CuttingColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      line1,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: CuttingColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line2,
                      style: const TextStyle(
                        fontSize: 12,
                        color: CuttingColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(AppIcons.forward, color: CuttingColors.textSecondary),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return CuttingTheme(
      child: Scaffold(
        backgroundColor: CuttingColors.background,
        appBar: AppBar(
          backgroundColor: CuttingColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          title: const Text(
            '튜브 가공',
            style: TextStyle(
              color: CuttingColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
          iconTheme: const IconThemeData(color: CuttingColors.textPrimary),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(
              key: const Key('hub_line_cutting'),
              icon: Icons.account_tree_outlined,
              title: '라인 컷팅',
              line1: '부속을 골라 절단 길이 구하기',
              line2: '부속 공제 · 배치 · 지시서 · 재고',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MobileCuttingProjectListPage(),
                ),
              ),
            ),
            _card(
              key: const Key('hub_short_pipe'),
              icon: Icons.content_cut_rounded,
              title: '단관 컷팅',
              line1: '같은 길이를 여러 개 자를 때',
              line2: '원자재 본수 · 자르는 눈금 · 잔재',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ShortPipeCuttingPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
