// 빠른 도구 막대의 "전체" 창에 나오는 세부 기능: 큰 기능(압력 시험·전기 설계 등)의 탭과 단위 분류를
// 하나하나 아이콘으로 나눠, 그 탭을 바로 연 화면으로 들어가게 한다. 막대 전용이라 아이콘은 Lucide 선 아이콘.
// 큰 기능(kQuickTools)은 quick_tool_bar.dart에 있다.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../electrical/electric_calculator_page.dart';
import '../field_tools/formula_calc_page.dart';
import '../field_tools/mini_unit_converter_page.dart';
import '../flow/flow_calc_page.dart';
import '../instrument/signal_calculator_page.dart';
import '../pressure_test/pressure_test_page.dart';
import '../reference/page/tube_reference_page.dart';
import '../unit_converter/unit_converter_page.dart';
import 'quick_tool_bar.dart';

QuickToolDef _sub(
  String id,
  String label,
  IconData icon,
  String group,
  WidgetBuilder builder, {
  String subtitle = '',
}) => QuickToolDef(
  id,
  label,
  null,
  builder,
  icon: icon,
  group: group,
  subtitle: subtitle,
);

QuickToolDef _unit(String id, String cat, String label, IconData icon) => _sub(
  'unit_$id',
  label,
  icon,
  '단위 환산',
  (_) => UnitConverterPage(initialCategory: cat),
  subtitle: '$label 단위를 바로 환산',
);

/// 세부 기능 전부(전체 창에 큰 기능 뒤로 묶음별로 나온다).
final List<QuickToolDef> kQuickSubTools = [
  // ── 공학용 계산기 ──
  _sub(
    'eng_unit',
    '단위 계산기',
    LucideIcons.arrowLeftRight,
    '공학용 계산기',
    (_) => const MiniUnitConverterPage(),
    subtitle: '계산기 안 간단 단위 변환',
  ),
  _sub(
    'eng_formula',
    '공식으로 계산',
    LucideIcons.functionSquare,
    '공학용 계산기',
    (_) => const FormulaCalcPage(),
    subtitle: '전기·유량·유공압 공식 모음',
  ),
  // ── 압력 시험 ──
  _sub(
    'pt_plan',
    '시험 압력',
    LucideIcons.gauge,
    '압력 시험',
    (_) => const PressureTestPage(initialTab: 0),
    subtitle: 'ASME B31.3·B31.1 수압·공압 시험압력',
  ),
  _sub(
    'pt_record',
    '시험 기록',
    LucideIcons.clipboardList,
    '압력 시험',
    (_) => const PressureTestPage(initialTab: 1),
    subtitle: '유지시간 타이머 · 기록서',
  ),
  _sub(
    'pt_decay',
    '압력 강하',
    LucideIcons.trendingDown,
    '압력 시험',
    (_) => const PressureTestPage(initialTab: 2),
    subtitle: '유지 중 압력 떨어짐 판정',
  ),
  _sub(
    'pt_energy',
    '공압 안전거리',
    LucideIcons.shieldAlert,
    '압력 시험',
    (_) => const PressureTestPage(initialTab: 3),
    subtitle: '저장 에너지 · 출입 통제 거리',
  ),
  // ── 전기 설계 계산 ──
  _sub(
    'el_basic',
    '기초 계산',
    LucideIcons.calculator,
    '전기 설계 계산',
    (_) => const ElectricCalculatorPage(initialTab: 0),
    subtitle: '옴의 법칙 · 전력',
  ),
  _sub(
    'el_load',
    '부하 전류',
    LucideIcons.zap,
    '전기 설계 계산',
    (_) => const ElectricCalculatorPage(initialTab: 1),
    subtitle: '전동기·히터 전류',
  ),
  _sub(
    'el_loadsum',
    '부하 합산',
    LucideIcons.sigma,
    '전기 설계 계산',
    (_) => const ElectricCalculatorPage(initialTab: 2),
    subtitle: '여러 부하 합산',
  ),
  _sub(
    'el_cable',
    '전선 굵기',
    LucideIcons.plug,
    '전기 설계 계산',
    (_) => const ElectricCalculatorPage(initialTab: 3),
    subtitle: '허용전류로 전선 선정',
  ),
  _sub(
    'el_vd',
    '전압강하',
    LucideIcons.activity,
    '전기 설계 계산',
    (_) => const ElectricCalculatorPage(initialTab: 4),
    subtitle: '길이·전류별 전압강하',
  ),
  _sub(
    'el_short',
    '단락 전류',
    LucideIcons.alertTriangle,
    '전기 설계 계산',
    (_) => const ElectricCalculatorPage(initialTab: 5),
    subtitle: '변압기·전선 단락 전류',
  ),
  _sub(
    'el_conduit',
    '전선관 (전선 수용)',
    LucideIcons.boxes,
    '전기 설계 계산',
    (_) => const ElectricCalculatorPage(initialTab: 6),
    subtitle: '전선관에 넣을 수 있는 전선 수',
  ),
  _sub(
    'el_bus',
    '부스바',
    LucideIcons.minus,
    '전기 설계 계산',
    (_) => const ElectricCalculatorPage(initialTab: 7),
    subtitle: '부스바 허용전류',
  ),
  _sub(
    'el_pf',
    '역률 개선',
    LucideIcons.percent,
    '전기 설계 계산',
    (_) => const ElectricCalculatorPage(initialTab: 8),
    subtitle: '콘덴서 용량',
  ),
  _sub(
    'el_gen',
    '발전기 용량',
    LucideIcons.fuel,
    '전기 설계 계산',
    (_) => const ElectricCalculatorPage(initialTab: 9),
    subtitle: '비상 발전기 선정',
  ),
  _sub(
    'el_batt',
    '축전지 용량',
    LucideIcons.batteryCharging,
    '전기 설계 계산',
    (_) => const ElectricCalculatorPage(initialTab: 10),
    subtitle: '축전지·충전기 용량',
  ),
  // ── 유량 계산 ──
  _sub(
    'fl_vel',
    '유속·관 굵기',
    LucideIcons.waves,
    '유량 계산',
    (_) => const FlowCalcPage(initialTab: 0),
    subtitle: '유량으로 관 굵기·유속',
  ),
  _sub(
    'fl_dp',
    '압력손실',
    LucideIcons.trendingDown,
    '유량 계산',
    (_) => const FlowCalcPage(initialTab: 1),
    subtitle: '관 마찰 압력손실',
  ),
  _sub(
    'fl_meter',
    '차압 유량계',
    LucideIcons.droplets,
    '유량 계산',
    (_) => const FlowCalcPage(initialTab: 2),
    subtitle: '오리피스 등 차압 유량',
  ),
  _sub(
    'fl_check',
    '유량계 점검',
    LucideIcons.clipboardList,
    '유량 계산',
    (_) => const FlowCalcPage(initialTab: 3),
    subtitle: '유량계 점검 기록',
  ),
  // ── 계기 교정 ──
  _sub(
    'sg_cal',
    '교정 점검',
    LucideIcons.gauge,
    '계기 교정',
    (_) => const SignalCalculatorPage(initialTab: 0),
    subtitle: '지시 오차 판정',
  ),
  _sub(
    'sg_conv',
    '4-20mA',
    LucideIcons.activity,
    '계기 교정',
    (_) => const SignalCalculatorPage(initialTab: 1),
    subtitle: '전류 ↔ 측정값 환산',
  ),
  _sub(
    'sg_temp',
    '온도 센서',
    LucideIcons.thermometer,
    '계기 교정',
    (_) => const SignalCalculatorPage(initialTab: 2),
    subtitle: 'RTD·열전대 환산',
  ),
  _sub(
    'sg_gas',
    '교정 가스',
    LucideIcons.wind,
    '계기 교정',
    (_) => const SignalCalculatorPage(initialTab: 3),
    subtitle: '교정 가스 농도',
  ),
  _sub(
    'sg_loop',
    '루프 전압',
    LucideIcons.plug,
    '계기 교정',
    (_) => const SignalCalculatorPage(initialTab: 4),
    subtitle: '4-20mA 루프 전압',
  ),
  // ── 현장 자료 ──
  _sub(
    'rf_tube',
    '튜브 규격표',
    LucideIcons.table,
    '현장 자료',
    (_) => const TubeReferencePage(initialTab: 0),
    subtitle: '튜브 외경·두께·허용압력',
  ),
  _sub(
    'rf_conduit',
    '전선관 규격표',
    LucideIcons.table,
    '현장 자료',
    (_) => const TubeReferencePage(initialTab: 1),
    subtitle: '전선관 호칭·치수',
  ),
  _sub(
    'rf_steel',
    '형강 규격표',
    LucideIcons.table,
    '현장 자료',
    (_) => const TubeReferencePage(initialTab: 2),
    subtitle: '찬넬·앵글 규격',
  ),
  _sub(
    'rf_unit',
    '단위 환산표',
    LucideIcons.scale,
    '현장 자료',
    (_) => const TubeReferencePage(initialTab: 3),
    subtitle: '자주 쓰는 환산 표',
  ),
  _sub(
    'rf_plant',
    '발전 설비',
    LucideIcons.factory,
    '현장 자료',
    (_) => const TubeReferencePage(initialTab: 4),
    subtitle: '발전 설비 자료',
  ),
  _sub(
    'rf_kec',
    '전기 기준 (KEC)',
    LucideIcons.bookOpen,
    '현장 자료',
    (_) => const TubeReferencePage(initialTab: 5),
    subtitle: '한국전기설비규정',
  ),
  // ── 단위 환산 ──
  _unit('length', 'length', '길이', LucideIcons.ruler),
  _unit('pressure', 'pressure', '압력', LucideIcons.gauge),
  _unit('temp', 'temp', '온도', LucideIcons.thermometer),
  _unit('torque', 'torque', '토크', LucideIcons.wrench),
  _unit('mass', 'mass', '중량', LucideIcons.scale),
  _unit('flow', 'flow', '유량', LucideIcons.droplets),
  _unit('angle', 'angle', '각도·구배', LucideIcons.triangle),
  _unit('wire', 'wire', '전선 굵기', LucideIcons.plug),
  _unit('pipe', 'pipe', '배관 호칭', LucideIcons.ruler),
];

/// 전체 창에 나오는 모든 기능: 큰 기능 뒤에 세부 기능.
List<QuickToolDef> get kQuickAllFeatures => [...kQuickTools, ...kQuickSubTools];
