// 형강 탭: 규격별 이론 중량(형강 컷팅이 쓰는 함수 그대로), 재단 계획 기준.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../data/models/steel_shape_db.dart';
import '../../steel_cutting/steel_weight.dart';
import '../../tube_cutting/cutting_optimizer.dart' show kMinLeftoverMm;
import 'reference_widgets.dart';

class RefSteelTab extends StatelessWidget {
  const RefSteelTab({super.key});

  static const Map<String, IconData> _icons = {
    'ANGLE': LucideIcons.cornerDownRight,
    'CHANNEL': LucideIcons.brackets,
    'STRUT': LucideIcons.alignJustify,
    'FLAT': LucideIcons.minus,
    'SQUARE': LucideIcons.square,
    'ROUND': LucideIcons.circle,
    'BAR': LucideIcons.disc,
    'ROD': LucideIcons.moreVertical,
    'UNEQUAL': LucideIcons.cornerRightDown,
    'LIPC': LucideIcons.brackets,
    'BEAM': LucideIcons.columns,
  };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        refIntroBadge(
          "형강 컷팅이 무게를 셀 때 쓰는 이론 중량(kg/m)입니다. 규격 이름만으로 셈한 참고값이라 실제 저울과 ±3% 안팎 다를 수 있습니다. "
          "발주·운송 무게는 자재 규격서로 확인하십시오. 6m 1본 무게는 kg/m × 6.",
        ),
        const SizedBox(height: 16),

        refCard(
          title: "재단 계획이 세는 법",
          subtitle: "형강·튜브 컷팅의 '재단 계획' 시트와 결과 탭 본수는 같은 식으로 셉니다.",
          icon: LucideIcons.calculator,
          iconColor: refTeal,
          children: [
            refStep(1, "잔재부터 채운다. 같은 규격의 잔재에 들어가는 조각을 먼저 넣는다."),
            refStep(
              2,
              "나머지는 새 원자재에 긴 것부터 넣는 방법과 꼭 맞는 곳에 넣는 방법 중 본수가 적은 쪽을 고른다.",
            ),
            refStep(3, "조각이 많지 않으면(24개 이하) 더 촘촘한 배치를 직접 찾아본다."),
            refStep(4, "톱날 손실은 조각마다 한 번씩 뺀다(마지막 조각도 뺀다 — 모자란 것보다 여유가 낫다)."),
            refStep(
              5,
              "자르고 남은 것이 ${refNum(kMinLeftoverMm)}mm 이상이면 잔재로 남긴다. 그보다 짧으면 버린다.",
            ),
            refStep(
              6,
              "길이 섞어 쓰기를 켜면 가장 긴 원자재로 배치한 뒤 본마다 들어갈 수 있는 가장 짧은 길이로 바꿔, 원자재 총 길이가 적은 쪽을 고른다.",
            ),
            const SizedBox(height: 8),
            refTipBox(
              "톱날 손실은 형강 컷팅 화면 위 '톱날 손실' 칸에 톱 두께(고속절단기 2.5~3mm, 밴드쏘 1.3~1.6mm)를 넣어 둡니다. 0이면 모자라게 잘립니다.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        for (final c in SteelShapeDB.categories) ...[
          refExpandCard(
            title: c.label,
            subtitle: _hint(c.id),
            icon: _icons[c.id] ?? LucideIcons.box,
            iconColor: Colors.blueGrey,
            children: [
              refTable(
                headers: const ["규격", "kg/m", "6m 1본 (kg)"],
                flex: const [4, 2, 3],
                rows: [
                  for (final it in SteelShapeDB.byCategory(c.id))
                    [
                      it.label.replaceFirst('${c.label} ', ''),
                      _kg(steelKgPerM(it.label), 1),
                      _kg(steelKgPerM(it.label), 6),
                    ],
                ],
                footer:
                    SteelShapeDB.byCategory(
                      c.id,
                    ).any((i) => steelKgPerM(i.label) == null)
                    ? "※ '—'는 이름만으로 무게를 못 구하는 규격입니다(형강 컷팅도 무게 합계에서 뺍니다)."
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        refCard(
          title: "절단 현장에서 지키는 것",
          subtitle: "고속절단기·밴드쏘",
          icon: LucideIcons.alertTriangle,
          iconColor: Colors.redAccent,
          children: [
            refDataRow(
              "톱날 두께",
              "실제 톱날을 재서 설정에 넣는다. 지시서 길이는 이미 손실을 넣은 값이니 마킹선 위를 자른다.",
            ),
            refGap(),
            refDataRow("마킹 자리", "긴 조각부터 자른다(재단 계획 순서). 잔재는 규격을 적어 잔재 목록에 올린다."),
            refGap(),
            refDataRow("버 제거", "자른 면의 버를 그라인더로 깎는다. 앵글·찬넬은 안쪽 모서리도."),
            refGap(),
            refDataRow("클램프", "바이스로 꽉 물고 자른다. 손으로 잡고 자르면 톱날이 물려 튄다."),
            refGap(),
            refDataRow("보호구", "보안경·귀마개·장갑. 절단기는 불꽃 방향에 사람·자재가 없게."),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  static String _kg(double? kgPerM, double meters) =>
      kgPerM == null ? "—" : fmtKg(kgPerM * meters);

  static String? _hint(String id) => switch (id) {
    'ANGLE' => "등변 앵글 변×변×두께 (KS 열간압연 표값)",
    'UNEQUAL' => "부등변 앵글 긴변×짧은변×두께",
    'CHANNEL' => "ㄷ형강 춤×폭×웨브 (립 없음)",
    'LIPC' => "립C형강 높이×폭×립×두께 (KS D 3530 식)",
    'STRUT' => "스트럿 찬넬 폭×높이×두께",
    'FLAT' => "평철 폭×두께",
    'SQUARE' => "각파이프 변×변×두께",
    'ROUND' => "배관용 탄소강관(SGP) 호칭",
    'BAR' => "환봉 지름",
    'ROD' => "전산볼트 M 호칭",
    'BEAM' => "H형강 춤×폭×웨브×플랜지",
    _ => null,
  };
}
