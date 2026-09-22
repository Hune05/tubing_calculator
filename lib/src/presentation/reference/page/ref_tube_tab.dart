// 튜브 탭: 규격·벤더 제원·피팅 깊이·각도별 셈. 숫자는 계산기가 쓰는 자료
// (FittingData·SmartFittingDB·bend_geometry)에서 바로 읽어 설정과 늘 같다.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/engine/bend_geometry.dart';
import '../../../core/utils/fitting_data.dart';
import '../../../data/models/smart_fitting_db.dart';
import '../../calculator/segment_length_check.dart';
import 'reference_widgets.dart';

/// 규격 이름 · 자료 키 · 바깥지름(mm).
class _TubeSize {
  final String label;
  final String key;
  final double od;
  const _TubeSize(this.label, this.key, this.od);
}

const List<_TubeSize> _inchSizes = [
  _TubeSize('1/8"', '0.125', 3.18),
  _TubeSize('1/4"', '0.25', 6.35),
  _TubeSize('5/16"', '0.3125', 7.94),
  _TubeSize('3/8"', '0.375', 9.53),
  _TubeSize('1/2"', '0.5', 12.7),
  _TubeSize('5/8"', '0.625', 15.88),
  _TubeSize('3/4"', '0.75', 19.05),
  _TubeSize('7/8"', '0.875', 22.23),
  _TubeSize('1"', '1.0', 25.4),
];

const List<_TubeSize> _metricSizes = [
  _TubeSize('3 mm', '3.0', 3),
  _TubeSize('4 mm', '4.0', 4),
  _TubeSize('6 mm', '6.0', 6),
  _TubeSize('8 mm', '8.0', 8),
  _TubeSize('10 mm', '10.0', 10),
  _TubeSize('12 mm', '12.0', 12),
  _TubeSize('14 mm', '14.0', 14),
  _TubeSize('15 mm', '15.0', 15),
  _TubeSize('16 mm', '16.0', 16),
  _TubeSize('18 mm', '18.0', 18),
  _TubeSize('20 mm', '20.0', 20),
  _TubeSize('22 mm', '22.0', 22),
  _TubeSize('25 mm', '25.0', 25),
];

const List<double> _angles = [15, 22.5, 30, 45, 60, 90];

class RefTubeTab extends StatefulWidget {
  const RefTubeTab({super.key});

  @override
  State<RefTubeTab> createState() => _RefTubeTabState();
}

class _RefTubeTabState extends State<RefTubeTab> {
  String _sizeKey = '0.375';

  _TubeSize get _size =>
      [..._inchSizes, ..._metricSizes].firstWhere((s) => s.key == _sizeKey);

  List<List<String>> _specRows(List<_TubeSize> sizes) => [
    for (final s in sizes)
      if (FittingData.getBenderSpec('Swagelok', s.key) case final sp?)
        [
          s.label,
          refNum(s.od, 2),
          refNum(sp.bendRadius),
          refNum(sp.takeUp),
          refNum(sp.gain),
        ],
  ];

  List<List<String>> _fitRows(List<_TubeSize> sizes) => [
    for (final s in sizes)
      if (FittingData.getBenderSpec('Swagelok', s.key) case final sp?)
        [
          s.label,
          refNum(FittingData.getInsertionDepth('Swagelok', s.key)),
          refNum(minFittingStraightMm(s.od)),
          refNum(sp.minStraight),
        ],
  ];

  @override
  Widget build(BuildContext context) {
    final sp = FittingData.getBenderSpec('Swagelok', _size.key)!;
    final r = sp.bendRadius;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        refIntroBadge(
          "여기 숫자는 벤딩 마킹 계산기·튜브 컷팅 계산기가 쓰는 자료에서 그대로 읽습니다. "
          "설정에서 반경·테이크업·게인·삽입 깊이를 고치면 마킹은 그 값으로 셈하고, 이 표는 기본값을 보여 줍니다.",
        ),
        const SizedBox(height: 16),

        // 1. 규격표(인치·미터) — 계산기 기본 제원
        refCard(
          title: "1. 튜브 규격표 · 계산기 기본 제원",
          subtitle:
              "바깥지름(OD)과 수동 벤더(Swagelok형) 기본 반경 R·90° 테이크업·게인. 설정의 기본값이 이 값입니다.",
          icon: LucideIcons.ruler,
          iconColor: Colors.blueGrey,
          children: [
            refSectionTitle("인치 규격"),
            refTable(
              headers: [
                "규격",
                "외경\n(mm)",
                "반경 R\n(mm)",
                "테이크업\n90° (mm)",
                "게인\n90° (mm)",
              ],
              rows: _specRows(_inchSizes),
              flex: const [3, 3, 3, 3, 3],
            ),
            const SizedBox(height: 16),
            refSectionTitle("미터 규격"),
            refTable(
              headers: [
                "규격",
                "외경\n(mm)",
                "반경 R\n(mm)",
                "테이크업\n90° (mm)",
                "게인\n90° (mm)",
              ],
              rows: _specRows(_metricSizes),
              flex: const [3, 3, 3, 3, 3],
              footer:
                  "※ 테이크업 = 마킹선에서 벤더 0점을 맞출 때 꺾이는 점까지 빼는 값. 게인 = 90°로 꺾을 때 교차점 길이 합에서 줄어드는 길이(자를 때 뺀다).",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2. 피팅 삽입 깊이·최소 직선
        refCard(
          title: "2. 피팅 삽입 깊이 · 최소 직선",
          subtitle:
              "튜브 컷팅 계산기가 빼는 삽입 깊이(Swagelok·Hy-Lok·Parker 같은 값)와 계산기가 경고하는 최소 직선.",
          icon: Icons.compress,
          iconColor: Colors.blueAccent,
          children: [
            refDataRow("삽입 깊이", "튜브 끝이 피팅 안으로 들어가는 길이. 컷팅 계산기가 구간 길이에서 뺀다."),
            refDataRow(
              "피팅 최소 직선",
              "벤드 끝에서 튜브 끝까지 이만큼 곧아야 너트·페룰이 물린다(계산기 경고 기준).",
            ),
            refDataRow("벤더 최소 직선", "벤드와 벤드 사이 벤더 슈가 물릴 수 있는 최소 곧은 길이(설정 기본값)."),
            const SizedBox(height: 12),
            refSectionTitle("인치 규격"),
            refTable(
              headers: ["규격", "삽입 깊이\n(mm)", "피팅 최소\n직선(mm)", "벤더 최소\n직선(mm)"],
              rows: _fitRows(_inchSizes),
            ),
            const SizedBox(height: 16),
            refSectionTitle("미터 규격"),
            refTable(
              headers: ["규격", "삽입 깊이\n(mm)", "피팅 최소\n직선(mm)", "벤더 최소\n직선(mm)"],
              rows: _fitRows(_metricSizes),
              footer:
                  "※ 부속을 조일 때 튜브가 턱까지 닿았는지 꼭 확인. 덜 들어간 채 조이면 고압에서 제일 먼저 샌다.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. 각도별 셈 — 규격 고르기
        refCard(
          title: "3. 각도별 셈 (계산기 공식 그대로)",
          subtitle: "규격을 고르면 그 반경 R로 셋백·게인·호 길이를 계산기와 같은 식으로 셉니다.",
          icon: LucideIcons.calculator,
          iconColor: refTeal,
          children: [
            refChips(
              items: [for (final s in _inchSizes) s.label],
              selected: _size.label,
              onSelected: (v) => setState(
                () => _sizeKey = _inchSizes.firstWhere((s) => s.label == v).key,
              ),
            ),
            const SizedBox(height: 12),
            refDataRow("반경 R", "${refNum(r)} mm (설정 기본값)"),
            refDataRow("셋백", "R × tan(각/2) — 교차점에서 관이 휘기 시작하는 점까지"),
            refDataRow(
              "게인",
              "90° 게인 ${refNum(sp.gain)}mm를 각도 모양대로 환산(각도에 비례하지 않음)",
            ),
            refDataRow("호 길이", "π × R × 각 ÷ 180 — 휘는 구간의 중심선 길이"),
            const SizedBox(height: 12),
            refTable(
              headers: [
                "각도",
                "셋백\n(mm)",
                "게인\n(mm)",
                "호 길이\n(mm)",
                "테이크업\n(mm)",
              ],
              rows: [
                for (final a in _angles)
                  [
                    "${refNum(a)}°",
                    refNum(bendSetback(r, a)),
                    refNum(scaleMeasuredGain(sp.gain, a)),
                    refNum(bendArcLength(r, a)),
                    refNum(scaleTakeUp(sp.takeUp, r, a)),
                  ],
              ],
              footer:
                  "※ 테이크업은 90° 값의 반경 몫만 tan(각/2)로 줄인 것 — 계산기가 45° 마킹을 찍을 때 쓰는 식입니다.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 4. 오프셋 계수
        refCard(
          title: "4. 오프셋 계수 (빗변·수축·직진)",
          subtitle:
              "단차 높이 H에 곱하는 숫자. 퀵 킥·오프셋·새들 계산기가 같은 식(1/sin, tan(각/2), 1/tan)을 씁니다.",
          icon: Icons.call_made,
          iconColor: Colors.orange,
          children: [
            refDataRow("빗변", "H ÷ sin(각) — 두 마킹 사이 거리"),
            refDataRow("수축", "H × tan(각/2) — 단차 때문에 줄어드는 직진 길이(자를 때 더한다)"),
            refDataRow("직진", "H ÷ tan(각) — 단차가 차지하는 수평 길이"),
            const SizedBox(height: 12),
            refTable(
              headers: ["각도", "빗변\n× H", "수축\n× H", "직진\n× H"],
              rows: [
                for (final a in _angles.where((a) => a < 90))
                  [
                    "${refNum(a)}°",
                    "× ${(1 / math.sin(a * math.pi / 180)).toStringAsFixed(3)}",
                    "× ${math.tan(a * math.pi / 360).toStringAsFixed(3)}",
                    "× ${(1 / math.tan(a * math.pi / 180)).toStringAsFixed(3)}",
                  ],
              ],
            ),
            const SizedBox(height: 12),
            refSectionTitle("보기: 45° 오프셋"),
            refTable(
              headers: ["단차 H", "빗변(마킹 간격)", "수축(더할 길이)"],
              rows: [
                for (final h in const [50.0, 100.0, 150.0, 200.0, 300.0])
                  [
                    "${refNum(h)} mm",
                    "${refNum(h / math.sin(math.pi / 4))} mm",
                    "${refNum(h * math.tan(math.pi / 8))} mm",
                  ],
              ],
              footer:
                  "※ 새들(장애물 넘기)은 가운데 벤드 양옆에 이 빗변만큼 마킹을 띄우고, 수축은 양쪽 몫을 더합니다.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 5. U벤드
        refCard(
          title: "5. 180° U벤드가 차지하는 자리",
          subtitle:
              "고른 규격(${_size.label}, R ${refNum(r)})로 셈. 벽·장애물 간섭은 센터가 아니라 바깥 폭으로 봅니다.",
          icon: LucideIcons.cornerUpLeft,
          iconColor: Colors.deepPurple,
          children: [
            refTable(
              headers: [
                "규격",
                "센터 간격\n2R (mm)",
                "바깥 폭\n2R+OD (mm)",
                "곡선 길이\nπR (mm)",
              ],
              rows: [
                for (final s in _inchSizes)
                  if (FittingData.getBenderSpec('Swagelok', s.key)
                      case final x?)
                    [
                      s.label,
                      refNum(2 * x.bendRadius),
                      refNum(2 * x.bendRadius + s.od),
                      refNum(math.pi * x.bendRadius),
                    ],
              ],
              footer: "※ 계산기 입력에서 180°는 '한 번에 꺾기'로 넣으면 U자 시작 마킹 하나만 찍습니다.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 6. 스프링백
        refCard(
          title: "6. 스프링백 참고값",
          subtitle: "목표 각도보다 더 꺾어야 하는 각. 설정의 '스프링백 [°]'에 넣으면 마킹 각도에 더해 보여 줍니다.",
          icon: LucideIcons.refreshCcw,
          iconColor: Colors.pinkAccent,
          children: [
            refTable(
              headers: [
                "규격",
                "동관",
                "SUS 316L\n0.035~0.049T",
                "SUS 316L\n0.065T 이상",
              ],
              rows: const [
                ['1/4"', "+0.5~1°", "+1.5~2°", "+2~3°"],
                ['3/8"', "+1°", "+2~2.5°", "+3~4°"],
                ['1/2"', "+1~1.5°", "+2.5~3°", "+3.5~5°"],
                ['3/4"', "+1.5°", "+3~3.5°", "+4~5°"],
              ],
              footer:
                  "※ 두께가 두꺼울수록, 굵을수록 더 펴집니다. 한 번 꺾어 각도기로 재서 내 값을 설정에 넣어 두십시오.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 7. 컷팅 계산기 부속 공제값
        refExpandCard(
          title: "7. 튜브 컷팅 부속 공제값 (앱 자료)",
          subtitle: "컷팅 계산기가 부속을 고르면 구간에서 빼는 값. 제조사·규격별.",
          icon: LucideIcons.scissors,
          iconColor: Colors.teal,
          children: [
            for (final maker in SmartFittingDB.makers) ...[
              refSectionTitle(maker),
              refTable(
                headers: ["규격", "부속", "공제\n(mm)"],
                flex: const [2, 5, 2],
                rows: [
                  for (final f in SmartFittingDB.allFittings)
                    if (f.maker == maker && !f.isCustom)
                      [f.tubeOD, f.name, refNum(f.deduction)],
                ],
              ),
              const SizedBox(height: 12),
            ],
            refTipBox("목록에 없는 부속은 컷팅 계산기에서 '직접 입력(삽입 깊이)'을 고르고 카탈로그 값을 넣으십시오."),
          ],
        ),
        const SizedBox(height: 16),

        // 8. 허용 압력
        refCard(
          title: "8. 튜브 두께별 최대 허용 압력",
          subtitle: "SUS 316L 심리스 튜브, 상온 기준(제조사 표 참고값)",
          icon: LucideIcons.gauge,
          iconColor: Colors.redAccent,
          children: [
            refDataRow("0.035T (0.89mm)", "가장 흔한 일반 저·중압용"),
            refDataRow("0.049T (1.24mm) 이상", "수소·고압 가스 등 특수 라인용"),
            const SizedBox(height: 12),
            refTable(
              headers: [
                "규격",
                "0.035T\n(0.89mm)",
                "0.049T\n(1.24mm)",
                "0.065T\n(1.65mm)",
              ],
              rows: const [
                [
                  '1/4"',
                  "5,100 psi\n(350 bar)",
                  "7,500 psi\n(510 bar)",
                  "10,200 psi\n(700 bar)",
                ],
                [
                  '3/8"',
                  "3,300 psi\n(220 bar)",
                  "4,800 psi\n(330 bar)",
                  "6,500 psi\n(440 bar)",
                ],
                [
                  '1/2"',
                  "2,600 psi\n(170 bar)",
                  "3,700 psi\n(250 bar)",
                  "5,100 psi\n(350 bar)",
                ],
                ['3/4"', "—", "2,400 psi\n(165 bar)", "3,300 psi\n(225 bar)"],
                ['1"', "—", "1,800 psi\n(120 bar)", "2,400 psi\n(165 bar)"],
              ],
              footer: "※ 같은 두께면 굵을수록 견디는 압력이 낮습니다. 라인 압력은 도면·사양서로 확인.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 9. NPT
        refCard(
          title: "9. NPT 나사 규격",
          subtitle: "호칭과 실제 나사 바깥지름은 다릅니다(1/2\" 밸브 나사는 12.7이 아니라 21.3mm).",
          icon: LucideIcons.settings,
          iconColor: Colors.blueGrey,
          children: [
            refTable(
              headers: ["호칭", "나사 외경\n(mm)", "산 수\n(TPI)", "테프론\n감는 횟수"],
              rows: const [
                ['1/8"', "10.3", "27", "2~3 바퀴"],
                ['1/4"', "13.7", "18", "3~4 바퀴"],
                ['3/8"', "17.1", "18", "3~4 바퀴"],
                ['1/2"', "21.3", "14", "4~5 바퀴"],
                ['3/4"', "26.7", "14", "5~6 바퀴"],
                ['1"', "33.4", "11.5", "6~7 바퀴"],
              ],
              footer:
                  "※ 테프론은 끝에서 두 번째 산부터, 조이는 방향(시계 방향)으로 감습니다. 첫 산에 감기면 배관 안으로 들어갑니다.",
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 10. 현장 지침
        refCard(
          title: "10. 현장에서 지키는 것",
          subtitle: "실수하면 튜브를 버리게 되는 것들",
          icon: LucideIcons.alertTriangle,
          iconColor: Colors.redAccent,
          children: [
            refDataRow(
              "먼저 자르지 않기",
              "도면 합계대로 미리 자르면 게인만큼 짧아진다. 다 꺾고 마지막에 자른다(계산기의 '총 절단 길이'는 게인·톱날 손실을 넣은 값).",
            ),
            refGap(),
            refDataRow(
              "마킹선 굵기",
              "네임펜 1~1.5mm. 선의 가운데를 0점에 맞추는지 늘 같게. 네 번 꺾으면 6mm 차이.",
            ),
            refGap(),
            refDataRow(
              "화살표 방향",
              "마킹을 뒤집어 물리면 각도·길이가 다 틀어진다. 벤더 화살표와 관의 진행 방향 확인.",
            ),
            refGap(),
            refDataRow(
              "허공 시늉",
              "3D 벤딩은 꺾기 전 손으로 방향을 허공에 그려 본다. 반대로 꺾는 실수가 제일 흔하다.",
            ),
            refGap(),
            refDataRow(
              "끝 직선",
              "마지막 벤드 뒤 튜브 끝은 표 2의 '피팅 최소 직선' 이상 곧아야 너트가 물린다.",
            ),
            refGap(),
            refDataRow("일정한 속도", "급하게 당기면 관이 타원으로 눌린다(오벌리티). 지그시 한 번에."),
            refGap(),
            refDataRow("옷걸이 철사", "복잡한 3D 라인은 얇은 철사로 먼저 접어 보고 그대로 꺾는다."),
            refGap(),
            refDataRow(
              "내 값 재기",
              "자투리 300mm에 100mm 간격 마킹 → 90° → 실제 늘어난 값을 재서 설정의 게인에 넣는다.",
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
