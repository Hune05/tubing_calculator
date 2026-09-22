// 전선관 탭: KS 규격·벤더 제원(앱 자료 그대로)·스프링백·커플링 여유·곤질레다.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/engine/bend_geometry.dart';
import '../../../data/conduit_spec_sets.dart';
import '../../../data/models/bender_spec_data.dart';
import '../../my_work_logs/models/skid_presets.dart'
    show kThickConduitOd, kConduletSize, kCouplingSize, kUnionSize;
import 'reference_widgets.dart';

/// 박강 전선관(KS C 8422) 호칭과 바깥지름(mm). 앱은 박강도 후강 호칭(16~54)으로 고르므로 참고용.
const Map<int, double> _thinConduitOd = {
  19: 19.1,
  25: 25.4,
  31: 31.8,
  39: 38.1,
  51: 50.8,
  63: 63.5,
  75: 76.2,
};

const List<double> _angles = [30, 45, 60, 90];

String _typeLabel(String t) => switch (t.toLowerCase()) {
  'emt' => '박강(EMT)',
  'rigid' => '후강(Rigid)',
  'pvc' => 'PVC',
  _ => t,
};

String _num(dynamic v) => v is num ? refNum(v.toDouble()) : '—';

class RefConduitTab extends StatelessWidget {
  const RefConduitTab({super.key});

  Widget _specTables(
    String benderType,
    List<String> fields,
    List<String> headers,
  ) {
    final byMaker = benderSpecData[benderType] ?? const {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in byMaker.entries)
          for (final t in m.value.entries) ...[
            refSectionTitle("${m.key} · ${_typeLabel(t.key)}"),
            refTable(
              headers: ["규격", ...headers],
              rows: [
                for (final s in t.value.entries)
                  [s.key, for (final f in fields) _num(s.value[f])],
              ],
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hand = benderSpecData['hand']?['Greenlee']?['Rigid'] ?? const {};
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        refIntroBadge(
          "벤더 제원 표는 전선관 벤딩 마킹 계산기 설정에서 제조사·재질·규격을 고르면 들어가는 기본값 그대로입니다. "
          "설정에서 고쳐 저장한 값은 그 규격에 따로 남고, 이 표는 바뀌지 않습니다.",
        ),
        const SizedBox(height: 16),

        refCard(
          title: "1. 전선관 규격 · 바깥지름",
          subtitle: "후강은 KS C 8401(JIS G관과 같음). 배치도의 전선관 폭도 이 값입니다.",
          icon: LucideIcons.ruler,
          iconColor: Colors.blueGrey,
          children: [
            refSectionTitle("후강 전선관 (앱 규격 16~54)"),
            refTable(
              headers: ["호칭", "바깥지름\n(mm)", "곤질레다\n몸통 길이(mm)", "커플링\n길이(mm)"],
              rows: [
                for (final e in kThickConduitOd.entries)
                  [
                    "${e.key}",
                    refNum(e.value),
                    _num(kConduletSize[e.key]?[0]),
                    _num(kCouplingSize[e.key]?[0]),
                  ],
              ],
            ),
            const SizedBox(height: 16),
            refSectionTitle("박강 전선관 (KS C 8422, 참고)"),
            refTable(
              headers: ["호칭", "바깥지름 (mm)"],
              rows: [
                for (final e in _thinConduitOd.entries)
                  ["${e.key}", refNum(e.value)],
              ],
              footer:
                  "※ 계산기에서 박강(EMT)을 고를 때도 규격은 후강 호칭(16~54)으로 고릅니다. 제원표가 그 호칭으로 되어 있어서입니다.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        refExpandCard(
          title: "2. 수동 벤더 제원 (앱 값)",
          subtitle: "90° 테이크업 · 게인 · 슈 중심선 반경(CLR)",
          icon: Icons.handyman_outlined,
          iconColor: Colors.brown,
          initiallyExpanded: true,
          children: [
            refDataRow("테이크업", "꺾이는 점까지의 거리에서 이만큼 빼고 화살표를 맞춘다(벤드마다)."),
            refDataRow("게인", "90°로 꺾으며 줄어드는 길이. 총 절단 길이에서 벤드마다 뺀다."),
            refDataRow("CLR", "슈가 그리는 곡선의 중심선 반지름. 45° 같은 각도의 테이크업 환산에 쓴다."),
            const SizedBox(height: 8),
            _specTables(
              'hand',
              const ['takeUp', 'gain', 'clr'],
              const ["테이크업\n90° (mm)", "게인\n90° (mm)", "CLR\n(mm)"],
            ),
          ],
        ),
        const SizedBox(height: 16),

        refExpandCard(
          title: "3. 유압식 벤더 제원 (앱 값)",
          subtitle: "90° 램 이동 거리 · 셋백 · CLR",
          icon: Icons.precision_manufacturing,
          iconColor: Colors.indigo,
          children: [
            refDataRow("램 이동", "90°로 꺾을 때 램이 나가는 거리. 다른 각도는 이 값에서 셈해 보여 준다."),
            refDataRow("셋백", "꺾이는 점에서 슈 가운데 표시까지 빼는 거리."),
            const SizedBox(height: 8),
            _specTables(
              'ram',
              const ['ramTravel', 'setback', 'clr'],
              const ["램 이동\n(mm)", "셋백\n(mm)", "CLR\n(mm)"],
            ),
          ],
        ),
        const SizedBox(height: 16),

        refExpandCard(
          title: "4. 시카고식 벤더 제원 (앱 값)",
          subtitle: "노치당 각도 · 노치 간격 · 롤러 · 테이크업",
          icon: LucideIcons.cog,
          iconColor: Colors.deepOrange,
          children: [
            refDataRow("노치당 각도", "기어(노치) 한 칸 넘길 때 꺾이는 각. 90 ÷ 칸 수로 잰다."),
            refDataRow("테이크업", "수동 벤더와 같은 슈 구조라 같은 값을 쓴다(어림값)."),
            const SizedBox(height: 8),
            _specTables(
              'chicago',
              const ['degPerNotch', 'notchSpacing', 'rollerSize', 'takeUp'],
              const ["노치당\n각도(°)", "노치 간격\n(mm)", "롤러\n(mm)", "테이크업\n(mm)"],
            ),
          ],
        ),
        const SizedBox(height: 16),

        refCard(
          title: "5. 각도별 테이크업 환산 (계산기 식)",
          subtitle: "보기: Greenlee 후강 수동 벤더. 테이크업 = 반경 몫 × tan(각/2) + 슈 고정분.",
          icon: LucideIcons.calculator,
          iconColor: refTeal,
          children: [
            refTable(
              headers: ["규격", for (final a in _angles) "${refNum(a)}°"],
              rows: [
                for (final e in hand.entries)
                  [
                    e.key,
                    for (final a in _angles)
                      refNum(
                        scaleTakeUp(
                          (e.value['takeUp'] as num).toDouble(),
                          (e.value['clr'] as num).toDouble(),
                          a,
                        ),
                      ),
                  ],
              ],
              footer:
                  "※ 예전 계산은 45°에도 90° 테이크업을 그대로 빼서 첫 마킹이 앞으로 밀렸습니다. 지금은 위 식으로 줄입니다.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        refCard(
          title: "6. 스프링백 · 커플링 끝 여유 기본값",
          subtitle: "처음 고르는 규격에 계산기가 넣는 어림값. 한 번 저장하면 그 규격은 저장한 값을 씁니다.",
          icon: LucideIcons.refreshCcw,
          iconColor: Colors.pinkAccent,
          children: [
            refDataRow("스프링백", "굵고 두꺼울수록 더 펴진다(박강 < 후강). PVC는 열로 굽혀 0."),
            refDataRow(
              "커플링 끝 여유",
              "마킹에서 '체결'을 고르면 줄자 0점을 커플링 끝에 대고 마킹. 나사 물림 길이만큼 여유.",
            ),
            const SizedBox(height: 12),
            refTable(
              headers: ["규격", "박강\n스프링백", "후강\n스프링백", "커플링\n여유(mm)"],
              rows: [
                for (final size in kThickConduitOd.keys)
                  [
                    "$size",
                    "${refNum(conduitCorrectionDefaults(conduitType: 'EMT', conduitSize: '${size}mm')['springback']!)}°",
                    "${refNum(conduitCorrectionDefaults(conduitType: 'Rigid', conduitSize: '${size}mm')['springback']!)}°",
                    refNum(
                      conduitCorrectionDefaults(
                        conduitType: 'Rigid',
                        conduitSize: '${size}mm',
                      )['couplingAllowance']!,
                    ),
                  ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        refCard(
          title: "7. 오프셋·새들 계수 (전선관도 같음)",
          subtitle: "단차 H에 곱한다. 빗변 = H ÷ sin, 수축 = H × tan(각/2).",
          icon: Icons.call_made,
          iconColor: Colors.orange,
          children: [
            refTable(
              headers: ["각도", "빗변 × H", "수축 × H", "쓰는 곳"],
              rows: const [
                ["10°", "× 5.76", "× 0.087", "긴 완만한 단차"],
                ["22.5°", "× 2.61", "× 0.199", "낮은 단차, 좁은 곳"],
                ["30°", "× 2.00", "× 0.268", "제일 흔한 오프셋"],
                ["45°", "× 1.41", "× 0.414", "새들·짧은 단차"],
                ["60°", "× 1.15", "× 0.577", "급한 단차"],
              ],
              footer:
                  "※ 3벤드 새들: 가운데 45°, 양옆 22.5°. 4벤드 새들: 양쪽 오프셋 둘. 계산기 특수 벤딩 툴이 마킹까지 찍어 줍니다.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        refExpandCard(
          title: "8. 곤질레다·커플링 (삼화기전 F-7)",
          subtitle: "배치도 부속 크기. 카탈로그에 몸통 치수가 없어 대략값 — 실제를 재서 편집 칸에서 고칩니다.",
          icon: LucideIcons.box,
          iconColor: Colors.teal,
          children: [
            refSectionTitle("종류(허브 방향)"),
            refDataRow("LB", "뒤로 빠짐. 벽 관통·직각 꺾임에 제일 흔함"),
            refDataRow("LL / LR", "왼쪽 / 오른쪽으로 빠짐(뚜껑을 보고)"),
            refDataRow("LT", "T자. 양옆 + 한쪽 끝"),
            refDataRow("LC", "일자(C). 양 끝 통과, 뚜껑으로 선 넣기"),
            refDataRow("LX", "십자. 네 방향"),
            const SizedBox(height: 12),
            refSectionTitle("곤질레다 몸통 (mm, 대략)"),
            refTable(
              headers: ["규격", "길이", "폭", "높이", "허브 돌출"],
              rows: [
                for (final e in kConduletSize.entries)
                  ["${e.key}", for (final v in e.value) refNum(v)],
              ],
            ),
            const SizedBox(height: 12),
            refSectionTitle("커플링 · 유니온 커플링(EUF) (mm, 대략)"),
            refTable(
              headers: ["규격", "커플링\n길이", "커플링\n외경", "유니온\n길이", "유니온\n너트 외경"],
              rows: [
                for (final e in kCouplingSize.entries)
                  [
                    "${e.key}",
                    refNum(e.value[0]),
                    refNum(e.value[1]),
                    _num(kUnionSize[e.key]?[0]),
                    _num(kUnionSize[e.key]?[1]),
                  ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        refCard(
          title: "9. 전선관 현장에서 지키는 것",
          subtitle: "전선관은 튜브보다 굵어 실수 하나가 크다",
          icon: LucideIcons.alertTriangle,
          iconColor: Colors.redAccent,
          children: [
            refDataRow(
              "한 관에 360° 이내",
              "박스와 박스 사이 꺾임 각도 합이 360°(90° 넷)를 넘지 않게. 넘으면 선 못 넣는다.",
            ),
            refGap(),
            refDataRow(
              "테이크업 빼기",
              "꺾이는 점 치수에서 테이크업을 빼고 화살표를 맞춘다. 계산기 마킹은 이미 뺀 값.",
            ),
            refGap(),
            refDataRow("나사 절단면", "자른 뒤 안쪽 버를 반드시 깎는다(리머). 남으면 선 피복이 찢어진다."),
            refGap(),
            refDataRow(
              "커플링 체결",
              "커플링 끝 여유만큼 관을 더 둔다. 마킹에서 '체결'을 고르면 계산기가 넣는다.",
            ),
            refGap(),
            refDataRow(
              "스프링백",
              "한 번 꺾어 각도기로 재고 설정에 넣는다. 90°를 92~93°까지 꺾는 게 보통.",
            ),
            refGap(),
            refDataRow(
              "개 도그 방지",
              "새들·오프셋은 두 벤드가 한 평면에 있어야 한다. 관에 그은 선을 벤더 슈 가운데에 맞춰 비틀림을 잡는다.",
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
