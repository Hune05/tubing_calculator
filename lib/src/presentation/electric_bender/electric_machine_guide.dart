// 설정 화면(폰·PC) "전동 장비" 안내. 2026-09-26 바로잡음: 예전 표(MS-BTB R38.1·76.2·101.6·127, TB20D 25mm R75,
// "권장 연신율")는 매뉴얼·제조사 자료와 맞지 않았다. 반경은 장비 목록(electric_machines.dart)에서 읽고,
// 출처 없는 값은 싣지 않는다. 근거는 docs/전동벤더_근거.md.
import 'package:flutter/material.dart';

import 'electric_machines.dart';

class ElectricMachineGuide extends StatelessWidget {
  const ElectricMachineGuide({super.key, required this.swagelok});

  /// true면 Swagelok MS-BTB, false면 TUBOBEND TB20D.
  final bool swagelok;

  @override
  Widget build(BuildContext context) {
    final m = machineById(swagelok ? MachineId.msBtb : MachineId.tb20d);
    final text = Theme.of(context).colorScheme.onSurface;
    final sub = text.withValues(alpha: 0.7);
    Widget row(String a, String b) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(a, style: TextStyle(fontSize: 13, color: sub)),
          ),
          Expanded(
            child: Text(
              b,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: text,
              ),
            ),
          ),
        ],
      ),
    );
    Widget step(String a, String b) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '$a  $b',
        style: TextStyle(fontSize: 13, color: text, height: 1.45),
      ),
    );
    return Container(
      key: const Key('electric_machine_guide'),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${m.shortName} 안내',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Colors.orange.shade900,
            ),
          ),
          const SizedBox(height: 12),
          if (swagelok) ...[
            row('모델', 'MS-BTB-1 (110V) / MS-BTB-2 (230V) 벤치탑 전동'),
            row('관경', '1/4"~1-1/4", 6~30mm'),
            row('굽힘 각', '1~180°'),
            row('조작', '각도는 숫자 바퀴(thumb wheel)로 넣고 토글 스위치로 꺾음. 풋 페달은 옵션'),
            const SizedBox(height: 12),
            step('1.', '관경에 맞는 벤드 슈를 끼웁니다. 두꺼운 관·1-1/4"·28·30mm는 강철 슈를 씁니다.'),
            step('2.', '관 끝이 클램프 암 오른쪽 끝을 지나도록 넣습니다.'),
            step('3.', '마킹(관이 휘기 시작하는 자리)을 벤드 슈의 기준선(reference mark)에 맞춥니다.'),
            step('4.', '숫자 바퀴에 넣을 각도를 맞추고 토글 스위치로 꺾습니다.'),
            step(
              '5.',
              '스프링백: 한 번 꺾어 각도를 재고 차이를 더합니다. 예: 90을 넣어 86이 나오면 94를 넣습니다.',
            ),
            const SizedBox(height: 6),
            Text(
              '벤드 슈 반경',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: text,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in m.tooling.where(
                  (t) => !t.id.startsWith('btb_m'),
                ))
                  Chip(
                    label: Text(t.label, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'mm 관: 6·10·12mm R36, 14·15·16mm R46, 18mm R56, 20·22mm R67, 25mm R82, 28·30mm R112.\n'
              '출처: Swagelok MS-13-145 3쪽, MS-01-179 3쪽. 게인·스프링백은 "전동 벤딩 계산기"의 시험 굽힘으로 채우십시오.',
              style: TextStyle(fontSize: 12, color: sub, height: 1.45),
            ),
          ] else ...[
            row('모델', 'TUBOBEND TB20D'),
            row('제조사', 'TRACTO-TECHNIK GmbH & Co.KG (독일)'),
            row('일련번호', '286'),
            row('제작 연도', '2020년'),
            row(
              '능력(제조사 자료)',
              '강관 Ø20×2mm, 최대 반경 50mm (2021 데이터시트는 Ø16×2mm, 45mm)',
            ),
            const SizedBox(height: 12),
            step('1.', '굽힘 각도만 장비가 하고, 관 밀어 넣기(이송)와 돌리기(회전)는 손으로 합니다.'),
            step('2.', '각도 8개를 미리 넣어 두고 차례로 꺾을 수 있습니다(제조사 자료).'),
            step('3.', '유압 클램프로 관을 물리고 꺾습니다. 굽힘·클램프 풋 스위치는 옵션입니다.'),
            const SizedBox(height: 6),
            Text(
              '금형별 반경·클램프 길이·게인은 공개 자료에 없습니다. 금형에 새겨진 반경(R)을 "전동 벤딩 계산기"의 '
              '"금형 더하기"에 넣고, 시험 굽힘으로 게인·스프링백을 채우십시오.',
              style: TextStyle(fontSize: 12, color: sub, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}
