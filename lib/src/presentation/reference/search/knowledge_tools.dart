// 자료 통합 검색(10-07): 전기 고장 진단 흐름의 판정(원인·조치)과 계산기·도구 바로가기.
// 진단 내용은 troubleshoot_flows.dart를 그대로 읽어 오므로 진단 화면과 검색 내용이 어긋나지 않는다.
library;

import 'package:flutter/material.dart';

import '../../alignment/alignment_page.dart';
import '../../electrical/busbar_bend_page.dart';
import '../../electrical/busbar_ground_page.dart';
import '../../electrical/cable_tray_page.dart';
import '../../electrical/cable_tray_route_page.dart';
import '../../electrical/electric_calculator_page.dart';
import '../../electrical/panel_design_page.dart';
import '../../electrical/troubleshoot_flows.dart';
import '../../electrical/troubleshoot_page.dart';
import '../../flow/flow_calc_page.dart';
import '../../instrument/signal_calculator_page.dart';
import '../../pressure_test/pressure_test_page.dart';
import 'knowledge_entry.dart';

const String kDiagCategory = '전기 고장 진단';
const String kToolCategory = '계산기 바로가기';

void _push(BuildContext c, Widget page) =>
    Navigator.push(c, MaterialPageRoute<void>(builder: (_) => page));

/// 고장 진단 흐름: 흐름마다 시작 항목 하나, 끝(판정)마다 원인·조치 항목 하나.
/// 고르면 그 흐름을 처음부터 따라가는 화면이 열린다(질문에 답하며 판정까지 간다).
List<KnowledgeEntry> diagnosisKnowledge() {
  final out = <KnowledgeEntry>[];
  for (final f in troubleshootFlows()) {
    final questions = [
      for (final s in f.steps.values)
        if (s is! WizEnd) s.title,
    ];
    void open(BuildContext c) => _push(c, TroubleshootFlowPage(flow: f));
    out.add(
      KnowledgeEntry(
        id: 'diag.${f.id}',
        category: kDiagCategory,
        title: '고장 진단: ${f.title}',
        lines: [
          f.subtitle,
          '질문에 답하고 측정값을 넣으면 원인을 좁혀 갑니다. 질문: ${questions.take(4).join(' / ')}',
        ],
        keywords: [f.title, ...questions],
        sourceLabel: '고장 진단',
        open: open,
        openLabel: '고장 진단 시작',
        priority: 1,
      ),
    );
    for (final s in f.steps.values) {
      if (s is! WizEnd) continue;
      out.add(
        KnowledgeEntry(
          id: 'diag.${f.id}.${s.id}',
          category: kDiagCategory,
          title: '${f.title}: ${s.title}',
          lines: [
            for (final c in s.causes) '원인: $c',
            for (final a in s.actions) '조치: $a',
            if (s.note != null) s.note!,
            '고장 진단 화면에서 질문에 답해 이 판정이 맞는지 확인할 수 있습니다.',
          ],
          keywords: [f.title, for (final (name, _) in s.links) name],
          sourceLabel: '고장 진단 · ${f.title}',
          open: open,
          openLabel: '고장 진단 시작',
          priority: 1,
        ),
      );
    }
  }
  return out;
}

/// 계산기·도구 바로가기 한 줄: (번호, 이름, 설명, 찾기용 말, 여는 화면).
typedef _Tool = (String, String, String, List<String>, Widget Function());

List<_Tool> _tools() => [
  // 전기 설비 계산(탭 안정 번호는 electric_calculator_page.dart kElecSumTab과 같다)
  ('e0', '전기 설비 계산 · 기초 계산', '옴의 법칙·교류 전력·역률·임피던스·Y-Δ·전력량 요금·도체 저항·주파수', ['옴', '전력', 'kw', 'kva', '주파수', 'hz'], () => const ElectricCalculatorPage(initialTab: 0)),
  ('e1', '전기 설비 계산 · 부하 전류', 'kW·HP로 정격 전류와 설계 전류(×1.25) 구하기, 전류 ↔ 전력 환산', ['전류', '암페어', 'a', 'kw', 'hp', '마력'], () => const ElectricCalculatorPage(initialTab: 1)),
  ('e2', '전기 설비 계산 · 부하 합산', '여러 부하의 수용률·부등률로 변압기 용량 정하기', ['변압기', '수용률', '부등률', 'kva'], () => const ElectricCalculatorPage(initialTab: 2)),
  ('e3', '전기 설비 계산 · 전선 굵기', '허용전류·공사 방법·주위 온도로 전선 굵기와 차단기 정하기(KEC)', ['케이블', '전선', 'sq', '허용전류', 'awg', '차단기'], () => const ElectricCalculatorPage(initialTab: 3)),
  ('e4', '전기 설비 계산 · 전압강하', '전선 길이·전류·굵기로 전압강하(%)와 최대 길이 구하기', ['전압강하', '전압 강하', '길이', '케이블'], () => const ElectricCalculatorPage(initialTab: 4)),
  ('e5', '전기 설비 계산 · 단락 전류', '변압기 %Z·케이블로 최대·최소 단락 전류와 차단기 차단용량 확인', ['단락', '쇼트', '차단용량', 'ka', '%z'], () => const ElectricCalculatorPage(initialTab: 5)),
  ('e6', '전기 설비 계산 · 전선관', '전선 가닥 수·굵기로 전선관 굵기 정하기(점유율)', ['전선관', '배관', '점유율', 'conduit'], () => const ElectricCalculatorPage(initialTab: 6)),
  ('e7', '전기 설비 계산 · 부스바', '부스바 규격별 허용전류와 전류 밀도', ['부스바', 'busbar', '동바'], () => const ElectricCalculatorPage(initialTab: 7)),
  ('e8', '전기 설비 계산 · 역률 개선', '목표 역률까지 필요한 콘덴서 kvar·μF', ['역률', '콘덴서', 'kvar', '진상'], () => const ElectricCalculatorPage(initialTab: 8)),
  ('e9', '전동기·발전기 계산 · 발전기 용량', '부하·전동기 기동으로 발전기 용량(GP 방식 KDS 32 20 20)', ['발전기', '비상발전기', 'gp', 'pg', 'kva'], () => const ElectricCalculatorPage(initialTab: 9)),
  ('e10', '전기 설비 계산 · 축전지 용량', '방전 시간·전류로 축전지 Ah 구하기', ['축전지', '배터리', 'ah', 'ups'], () => const ElectricCalculatorPage(initialTab: 10)),
  ('e11', '전기 설비 계산 · 접지', '접지선 굵기·접지 저항·누전차단기·절연저항 기준', ['접지', '접지저항', '접지선', '절연저항', '누전'], () => const ElectricCalculatorPage(initialTab: 11)),
  ('e12', '전동기·발전기 계산 · 전동기 보호', '열동계전기 설정값·차단기 상한(NEC)', ['열동', '과부하', '과열', 'thr', 'ocr', '계전기'], () => const ElectricCalculatorPage(initialTab: 12)),
  ('e13', '전동기·발전기 계산 · 전동기 점검', '절연저항·권선 저항·전압·전류 불평형 판정', ['메거', '절연저항', '권선', '불평형'], () => const ElectricCalculatorPage(initialTab: 13)),
  ('e14', '전동기·발전기 계산 · 전동기 공식', '동기속도·슬립·전류·토크·기동 전류·부하율', ['rpm', '슬립', '토크', '극수', '기동전류'], () => const ElectricCalculatorPage(initialTab: 14)),
  ('e15', '전동기·발전기 계산 · 전동기 선정', '펌프·팬 동력, 상사법칙, 가속 시간', ['펌프', '팬', '동력', '양정', '상사법칙'], () => const ElectricCalculatorPage(initialTab: 15)),
  ('e16', '전동기·발전기 계산 · 콘덴서·단상', '전동기 콘덴서 한도·단상 운전 콘덴서', ['콘덴서', '단상', '스타인메츠'], () => const ElectricCalculatorPage(initialTab: 16)),
  ('e17', '전동기·발전기 계산 · 전동기 구동·효율', '권선 온도 상승·효율 개선 절감·감속비·인버터', ['온도상승', '과열', '권선온도', '효율', '감속비', '인버터', 'vfd'], () => const ElectricCalculatorPage(initialTab: 17)),
  // 분전반·조명
  ('p0', '분전반·조명 계산 · 조명 광속법', '목표 조도·방 크기로 등기구 수와 배치', ['조명', '조도', 'lx', '럭스', '등기구'], () => const PanelDesignPage(initialTab: 0)),
  ('p1', '분전반·조명 계산 · 상 평형', '회로를 R·S·T 상에 나눠 불평형률 맞추기', ['상평형', '불평형', '분전반', 'rst'], () => const PanelDesignPage(initialTab: 1)),
  ('p2', '분전반·조명 계산 · 간선 전압강하', '여러 부하가 달린 간선의 구간별 전압강하', ['간선', '전압강하'], () => const PanelDesignPage(initialTab: 2)),
  ('p3', '분전반·조명 계산 · 분기회로 수', '면적·표준부하로 분기회로 수', ['분기회로', '표준부하'], () => const PanelDesignPage(initialTab: 3)),
  // 그 밖의 도구
  ('ct', '케이블 트레이 규격 선정', '케이블 외경 합으로 트레이 폭 정하기(KEC 232.41)', ['트레이', '점유율', '케이블'], () => const CableTrayPage()),
  ('tr', '케이블 트레이 가공', '넘어가기·옆으로 비켜가기·단 오르내리기·가지 내기 절단 치수', ['트레이', 'v컷', '엘보', '티'], () => const CableTrayRoutePage()),
  ('bb', '부스바 가공', 'L·U·Z 절곡 절단 길이와 절곡 시작선', ['부스바', '절곡', '동바'], () => const BusbarBendPage()),
  ('gb', '접지바 가공', '접지바 구멍 위치·절단 길이·중량', ['접지바', '구멍', '러그'], () => const GroundBarPage()),
  ('pt0', '압력 시험 · 시험압력', '설계압력으로 수압·공압 시험압력 구하기', ['수압', '기밀', '내압', '시험압력', 'b31.3'], () => const PressureTestPage(initialTab: 0)),
  ('pt1', '압력 시험 · 시험 기록', '압력 유지 시간 측정과 시험 기록서', ['기록서', '유지시간', '타이머'], () => const PressureTestPage(initialTab: 1)),
  ('pt2', '압력 시험 · 압력강하', '온도 변화로 생기는 압력 변화와 누설 판정', ['압력강하', '온도보정', '누설'], () => const PressureTestPage(initialTab: 2)),
  ('pt3', '압력 시험 · 공압 안전거리', '공압 시험의 저장 에너지와 안전거리', ['공압', '질소', '안전거리', '저장에너지'], () => const PressureTestPage(initialTab: 3)),
  ('fl0', '유량 계산 · 유속·관경', '유량·관경으로 유속, 권장 유속으로 관경', ['유속', '관경', '유량'], () => const FlowCalcPage(initialTab: 0)),
  ('fl1', '유량 계산 · 압력손실', '배관 길이·부속으로 압력손실', ['압력손실', '마찰', '배관'], () => const FlowCalcPage(initialTab: 1)),
  ('fl2', '유량 계산 · 차압 유량계', '차압 ↔ 유량 환산(제곱근)', ['차압', '오리피스', 'dp'], () => const FlowCalcPage(initialTab: 2)),
  ('fl3', '유량 계산 · 유량계 점검', '유량계 지시값과 mA 점검', ['유량계', '점검', 'ma'], () => const FlowCalcPage(initialTab: 3)),
  ('sg0', '계기 교정 · 교정 점검', '교정점별 기대값과 오차 판정', ['교정', '오차', '캘리브레이션'], () => const SignalCalculatorPage(initialTab: 0)),
  ('sg1', '계기 교정 · 4-20mA', '측정값 ↔ mA·% 환산', ['4-20', 'ma', '환산', '스케일'], () => const SignalCalculatorPage(initialTab: 1)),
  ('sg2', '계기 교정 · 온도 센서', 'RTD(Pt100)·열전대 저항·mV ↔ 온도', ['rtd', 'pt100', '열전대', 'tc', '온도'], () => const SignalCalculatorPage(initialTab: 2)),
  ('sg3', '계기 교정 · 교정 가스', '교정 가스 유량·사용 시간', ['교정가스', '스판가스', '가스'], () => const SignalCalculatorPage(initialTab: 3)),
  ('sg4', '계기 교정 · 루프 전압', '루프 전원·저항으로 계기 최소 전압 확인', ['루프', '전압', 'hart', '배리어'], () => const SignalCalculatorPage(initialTab: 4)),
  ('al', '축 정렬 계산', '모터·펌프 커플링 센터링, 발 심 두께와 좌우 이동량', ['축정렬', '센터링', '커플링', '심', '다이얼'], () => const AlignmentPage()),
];

/// 계산기·도구 바로가기(고르면 그 계산기 탭이 바로 열린다).
List<KnowledgeEntry> toolKnowledge() => [
  for (final (id, title, desc, keys, page) in _tools())
    KnowledgeEntry(
      id: 'tool.$id',
      category: kToolCategory,
      title: title,
      lines: [desc, '누르면 계산기가 바로 열립니다.'],
      keywords: keys,
      sourceLabel: title,
      open: (c) => _push(c, page()),
      openLabel: '계산기 열기',
      direct: true,
    ),
];
