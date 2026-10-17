// 전선관 보관함 도면 보기(10-18): 튜브 보관함처럼 먼저 아이소·마킹을 보고 맞으면 계산기로 불러온다.
// 예전에는 카드의 [계산기로 불러오기]만 있어서 어떤 도면인지 보지 않고 지금 입력 목록을 바꿨다.
// 이 화면은 보기만 한다(입력 목록·설정은 안 바뀐다). [계산기로 불러오기]를 누르면 true로 닫힌다.
import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../data/conduit_drawings.dart';
import '../../calculator/widgets/mobile_pipe_visualizer.dart';
import '../../field/field_marking.dart';
import '../conduit_field_data.dart';
import '../conduit_marking_logic.dart';
import 'conduit_settings_page.dart' show globalBenderSettings;

class ConduitDrawingViewPage extends StatelessWidget {
  final ConduitDrawing drawing;
  const ConduitDrawingViewPage({super.key, required this.drawing});

  /// 저장 때 장비 값(없는 칸은 지금 설정).
  Map<String, dynamic> get _settings => {
    ...globalBenderSettings.value,
    ...drawing.settings,
  };

  bool get _savedSettings => drawing.settings.isNotEmpty;

  String _mm(double v) => v.round().toString();

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    final useCoupling =
        (drawing.settings[kConduitDrawingCouplingKey] as bool?) ??
        conduitUseCoupling.value;
    final startDir =
        (drawing.settings[kConduitDrawingStartDirKey] as String?) ?? 'RIGHT';
    final marks = calculateConduitMarkings(
      drawing.bends,
      s,
      useCoupling: useCoupling,
    );
    final spec = [
      '${s['conduitType'] ?? ''} ${s['conduitSize'] ?? ''}'.trim(),
      if ((s['manufacturer'] ?? '').toString().isNotEmpty)
        '${s['manufacturer']}',
    ].where((e) => e.isNotEmpty).join(' · ');

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            drawing.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.large),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('총 절단 길이', style: AppText.sub),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: _mm(drawing.totalCut),
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: AppColors.text,
                          ),
                        ),
                        const TextSpan(
                          text: ' mm',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (spec.isNotEmpty) spec,
                      '${drawing.segmentCount}구간',
                      useCoupling ? '커플링 체결' : '커플링 미체결',
                      drawing.date,
                    ].join(' · '),
                    style: AppText.sub,
                  ),
                  if (drawing.notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(drawing.notes, style: AppText.sub),
                  ],
                  if (!_savedSettings) ...[
                    const SizedBox(height: 6),
                    const Text(
                      '저장 때 장비 값이 없는 예전 도면이라 지금 설정으로 보입니다.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.caution,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const TabBar(
              tabs: [
                Tab(text: '아이소 (3D)'),
                Tab(text: '마킹'),
              ],
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  MobilePipeVisualizer(
                    key: const Key('conduit_view_iso'),
                    bendList: drawing.bends,
                    initialStartDir: startDir,
                    useSavedDirection: false,
                    // 보기 화면에서 방향을 돌려 봐도 계산기 시작 방향은 안 바뀌게 따로 적는다.
                    startDirPrefKey: 'conduit_view_start_dir',
                    bendRadius: (s['clr'] as num?)?.toDouble() ?? 0.0,
                    outerDiameter: conduitDrawOuterDiameterMm(s),
                    fittingDepth:
                        (s['couplingDepth'] as num?)?.toDouble() ?? 0.0,
                    showDimControl: true,
                    allowMeasureMode: false,
                  ),
                  _MarkList(marks: marks, totalCut: drawing.totalCut),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              key: const Key('conduit_view_load'),
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.download_rounded),
              label: const Text('계산기로 불러오기'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkList extends StatelessWidget {
  final List<Map<String, dynamic>> marks;
  final double totalCut;
  const _MarkList({required this.marks, required this.totalCut});

  @override
  Widget build(BuildContext context) {
    String n(num? v) => (v ?? 0).round().toString();
    return ListView(
      key: const Key('conduit_view_marks'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('마킹 위치 (줄자 0점 기준)', style: AppText.sub),
        ),
        for (final m in marks)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    (m['markNo'] as int? ?? 0) > 0 ? '${m['markNo']}' : '-',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (m['angle'] as num? ?? 0) > 0
                            ? '${n(m['angle'] as num?)}° · '
                                  '${fieldDirectionLabel((m['rotation'] as num?)?.toDouble() ?? 0)}'
                            : '직관',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if ((m['note'] ?? '').toString().isNotEmpty)
                        Text('${m['note']}', style: AppText.sub),
                    ],
                  ),
                ),
                Text(
                  '${n(m['mark'] as num?)} mm',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '절단 길이',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${totalCut.round()} mm',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
