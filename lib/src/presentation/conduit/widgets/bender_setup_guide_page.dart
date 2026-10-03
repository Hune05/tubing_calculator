/// 전선관 설정 화면 헤더의 "장비 사용법" — 수동·유압식·시카고식 벤더를
/// 처음 만지는 사람도 순서대로 따라 할 수 있게, 실제 조작 절차(현장 자료 →
/// 장비 사용법 탭 4·5·6번과 같은 내용)를 단계별 글로 보여 준다.
/// (제원 칸을 내 장비에서 실제로 재는 방법은 그 탭의 "실측 캘리브레이션"에
/// 이미 있어서 여기서 다시 안 적는다 — 이 화면은 "어떻게 조작하는지"만.)
library;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';

const Color _slate900 = AppColors.text;
const Color _slate600 = AppColors.textSub;
const Color _pureWhite = Color(0xFFFFFFFF);
const Color _slate100 = AppColors.background;

enum _BenderKind { hand, ram, chicago }

class BenderSetupGuidePage extends StatelessWidget {
  const BenderSetupGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        key: const Key('bender_guide_page'),
        backgroundColor: _slate100,
        appBar: AppBar(
          title: const Text(
            '벤더 사용법',
            style: TextStyle(
              color: _slate900,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          backgroundColor: _pureWhite,
          elevation: 1,
          shadowColor: Colors.grey.shade200,
          centerTitle: false,
          iconTheme: const IconThemeData(color: _slate900),
          bottom: const TabBar(
            labelColor: AppColors.brand,
            unselectedLabelColor: _slate600,
            indicatorColor: AppColors.brand,
            tabs: [
              Tab(text: '수동 벤더'),
              Tab(text: '유압식 벤더'),
              Tab(text: '시카고식 벤더'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BenderGuideTab(kind: _BenderKind.hand),
            _BenderGuideTab(kind: _BenderKind.ram),
            _BenderGuideTab(kind: _BenderKind.chicago),
          ],
        ),
      ),
    );
  }
}

class _UsageStep {
  final IconData icon;
  final String title;
  final String detail;
  const _UsageStep(this.icon, this.title, this.detail);
}

List<_UsageStep> _stepsFor(_BenderKind kind) {
  switch (kind) {
    case _BenderKind.hand:
      return const [
        _UsageStep(
          Icons.center_focus_strong,
          '마킹선 화살표 맞추기',
          '관에 그은 마킹선을 슈의 화살표(Arrow)에 맞춰 끼울 것. 두 번째를 '
              '뒤로 꺾을 때는 별(Star) 표시에 맞출 것.',
        ),
        _UsageStep(
          Icons.pan_tool_alt,
          '발판 밟고 핸들 당기기',
          '발판을 밟은 채 핸들을 한 번에 지그시 당겨 꺾을 것. 멈췄다 다시 '
              '당기면 관에 자국이 남음.',
        ),
        _UsageStep(
          Icons.rule,
          '각도 + 스프링백 확인',
          '슈 눈금이 목표 각도보다 스프링백만큼(후강 3~5°) 더 간 곳에서 '
              '멈출 것. 바닥에서 관이 뜨면 각도 부족.',
        ),
      ];
    case _BenderKind.ram:
      return const [
        _UsageStep(
          Icons.build_circle_outlined,
          '슈·받침 고르기',
          '관 규격과 같은 슈를 램에 끼우고, 받침 롤러를 프레임의 그 규격 '
              '구멍에 핀으로 끝까지 꽂을 것. 핀이 덜 들어간 채로 밀기 금지.',
        ),
        _UsageStep(
          Icons.center_focus_strong,
          '셋백 마크 맞추기',
          '마킹선(셋백을 뺀 자리)을 슈 가운데 표시에 맞출 것. 관은 받침 '
              '롤러 양쪽에 고르게 걸칠 것.',
        ),
        _UsageStep(
          Icons.compress,
          '펌프질로 밀기',
          '펌프 밸브를 잠그고 펌프질(전동은 스위치). 램 눈금이 설정한 '
              "'램 이동 거리'까지 오면 멈추고 각도기로 확인.",
        ),
        _UsageStep(
          Icons.replay,
          '천천히 되돌리기',
          '릴리스 밸브를 천천히 열어 램을 넣을 것. 갑자기 열면 슈가 튐. '
              '관을 빼고 다음 마킹으로.',
        ),
      ];
    case _BenderKind.chicago:
      return const [
        _UsageStep(
          Icons.build_circle_outlined,
          '롤러·슈에 넣기',
          '관 규격에 맞는 롤러 규격과 슈 홈에 관을 넣을 것. 훅(고리)이 관을 '
              '꽉 누르는지 확인.',
        ),
        _UsageStep(
          Icons.center_focus_strong,
          '0점·마킹 맞추기',
          '노치 휠을 0점에 두고 마킹선(테이크업을 뺀 자리)을 슈 표시에 '
              '맞출 것.',
        ),
        _UsageStep(
          Icons.settings,
          '크랭크로 노치 세기',
          '크랭크를 돌리며 넘어가는 노치 칸 수 확인. 칸 수 = 목표 각도 ÷ '
              '노치당 각도(설정값). 스프링백만큼 한두 칸 더.',
        ),
        _UsageStep(
          Icons.replay,
          '래칫 풀고 되돌리기',
          '래칫을 풀고 크랭크를 되돌릴 것. 관을 빼기 전에 훅 먼저 풀 것.',
        ),
      ];
  }
}

/// 벤더 사용법 탭 — 그림 없이, 조작 순서를 번호가 매겨진 글 카드로만 보여
/// 준다.
class _BenderGuideTab extends StatelessWidget {
  final _BenderKind kind;
  const _BenderGuideTab({required this.kind});

  @override
  Widget build(BuildContext context) {
    final steps = _stepsFor(kind);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            _StepRow(index: i + 1, step: steps[i]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.brand),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '테이크업·게인을 내 장비에서 측정하는 방법은 장비 사용법의 '
                    '"벤더 실측 캘리브레이션"에 있습니다.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _slate900,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final _UsageStep step;
  const _StepRow({required this.index, required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(step.icon, size: 18, color: AppColors.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$index. ${step.title}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _slate900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  step.detail,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _slate600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
