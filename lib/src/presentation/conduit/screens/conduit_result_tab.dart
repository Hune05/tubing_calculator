import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/common_widgets/recent_calc_history.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';
import 'package:flutter/services.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_warning_banner.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/step_mark_card.dart';
import 'package:tubing_calculator/src/presentation/common/pick_style.dart';

// 🚀 매니저 임포트: 전선관 전용 매니저
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_field_data.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking_screen.dart';
import 'package:tubing_calculator/src/presentation/field/marking_sheet_pdf.dart';
import 'package:tubing_calculator/src/presentation/conduit/widgets/conduit_save_dialog.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';

final ValueNotifier<Map<String, dynamic>> globalMarkingState = ValueNotifier({
  'totalCutLength': 0.0,
  'markings': <Map<String, dynamic>>[],
});

// 🎨 색상 테마 정의
Color get makitaTeal => fc.brand; // 수동
const Color ramBlue = Colors.blueAccent; // 유압식
const Color chicagoPurple = Colors.deepPurple; // 시카고식

Color get slate900 => fc.text;
Color get slate800 =>
    fieldPick(const Color(0xFF1E293B), sunlight: fc.text, night: fc.text);
Color get slate600 => fc.textSub;
Color get slate400 => fc.textFaint;
Color get slate200 => fc.line;
Color get slate100 => fc.background;
Color get pureWhite => fc.surface;

class ConduitResultTab extends StatefulWidget {
  /// 저장 알림의 "보관함 보기"가 보관함 탭으로 옮겨 준다(없으면 단추가 안 붙는다).
  final VoidCallback? onOpenArchive;

  const ConduitResultTab({super.key, this.onOpenArchive});

  @override
  State<ConduitResultTab> createState() => _ConduitResultTabState();
}

class _ConduitResultTabState extends State<ConduitResultTab>
    with
        AutomaticKeepAliveClientMixin,
        RecentCalcHistoryMixin<ConduitResultTab> {
  @override
  bool get wantKeepAlive => true;

  /// 최근 마킹 기록을 폰에 이틀 동안 남기는 칸(보기만 — 마킹 값은 그때 계산 결과 글 그대로).
  @override
  String? get calcHistoryStorageKey => 'calc_history_conduit_marking';

  // 커플링 체결 여부와 시작 방향은 현장 탭과 같이 쓴다(conduit_field_data.dart).
  bool get _useCoupling => conduitUseCoupling.value;
  set _useCoupling(bool v) => conduitUseCoupling.value = v;

  /// 줄 번호 → 꺾기 전에 굴릴 각도(현장 탭과 같은 셈: 3D 경로 값, 없으면 롤링 시트가 남긴 값).
  /// 10-13: 전선관 마킹 카드에만 굴림 안내가 없어, 마킹 탭만 보고 롤링 오프셋을 굴리지 않고 꺾을 수 있었다.
  Map<int, double> _rolls = const {};

  @override
  void initState() {
    super.initState();
    loadConduitStartDir();
  }

  final List<Map<String, dynamic>> _directions = [
    {"label": "UP (위)", "val": 0.0, "icon": Icons.arrow_upward},
    {"label": "RIGHT (우)", "val": 90.0, "icon": Icons.arrow_forward},
    {"label": "DOWN (아래)", "val": 180.0, "icon": Icons.arrow_downward},
    {"label": "LEFT (좌)", "val": 270.0, "icon": AppIcons.back},
    {"label": "FRONT (앞)", "val": 360.0, "icon": Icons.call_made},
    {"label": "BACK (뒤)", "val": 450.0, "icon": Icons.call_received},
  ];

  String _getDirectionText(double rot) {
    return _directions
        .firstWhere(
          (d) => d['val'] == rot,
          orElse: () => {"label": "${rot.toInt()}°"},
        )['label']
        .toString()
        .split(' ')
        .first;
  }

  // ==========================================
  // 📐 [수학 알고리즘 보정] 임의 각도 게인(Gain) 연산
  // ==========================================
  // 현장 보기(보통·햇빛·야간) 테마로 감싼다(D-D). 탭만 따로 띄워도 같은 색.
  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin
    return FieldViewTheme(child: Builder(builder: _buildPage));
  }

  Widget _buildPage(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ConduitDataManager(),
        globalBenderSettings,
        conduitUseCoupling,
        conduitStartDir,
      ]),
      builder: (context, child) {
        final manager = ConduitDataManager();
        final bendList = manager.bendList;
        final currentSettings = globalBenderSettings.value;

        final String benderType = currentSettings['benderType'] ?? 'hand';

        final markings = calculateConduitMarkings(
          bendList,
          currentSettings,
          useCoupling: _useCoupling,
        );
        // 🚀 [추가] 튜브 마킹 화면처럼 만들 수 없는 형상이면 값 위에 띠를 띄운다.
        final check = conduitBendCheck(
          bendList,
          currentSettings,
          startDir: conduitStartDir.value,
        );
        _rolls = {
          for (var i = 0; i < bendList.length; i++)
            i: ?(check.rollByIndex[i] ?? conduitRollHint(bendList[i])),
        };

        // 총 절단 길이 = 구간 길이 합 − 각도별 게인 합(+ 커플링 끝 여유). 톱날 두께는 더하지 않는다.
        // (+ 커플링 체결이면 끝 여유). 현장 탭과 같은 셈.
        final double totalCut = conduitTotalCut(
          bendList,
          currentSettings,
          useCoupling: _useCoupling,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          globalMarkingState.value = {
            'totalCutLength': totalCut,
            'markings': markings,
          };
        });

        // "최근 마킹값 보기" — 저장하지 않아도 방금 계산한 마킹값을 다시 볼 수 있게
        // 자동으로 쌓는다(2026-09-29, 리모컨 "최근 전송 기록"과 같은 방식).
        if (markings.isNotEmpty && check.warnings.isEmpty) {
          final markText = markings
              .map((m) {
                final angle = (m['angle'] as num).toDouble();
                final mark = (m['mark'] as num).toDouble();
                return angle == 0.0
                    ? '직관 ${mark.toStringAsFixed(0)}mm'
                    : '${_fmtAngle(angle)}° ${mark.toStringAsFixed(0)}mm';
              })
              .join(', ');
          // 기록이 이틀 남으므로 어느 규격 계산인지 제목에 붙인다(규격이 바뀌면 따로 쌓인다).
          final size =
              [
                    currentSettings['conduitType'],
                    conduitSizeLabel(currentSettings['conduitSize']),
                  ]
                  .map((v) => (v ?? '').toString().trim())
                  .where((v) => v.isNotEmpty)
                  .join(' ');
          logCalc(
            size.isEmpty ? '마킹 계산' : '마킹 계산 · $size',
            '총 절단 ${totalCut.toStringAsFixed(0)}mm · $markText',
            dedupeKey:
                '$size|${totalCut.toStringAsFixed(1)}|${markings.map((m) => '${m['mark']}_${m['angle']}').join(',')}',
            // 줄을 이어 넣는 동안은 한 기록을 바꿔 끼운다(10-09).
            growKey: bendList
                .map((b) => '${b['length']}_${b['angle']}_${b['rotation']};')
                .join(),
          );
        }

        // 🚀 [수정] 폴더블 대응으로 넓은 화면에서 입력 탭과 나란히 붙여
        // 보여줄 수 있도록, 자체 Scaffold 대신 배경색만 칠하는 ColoredBox로
        // 바꿨다. SliverAppBar는 Scaffold 없이 CustomScrollView 안에서도
        // 그대로 동작한다.
        return ColoredBox(
          color: slate100,
          child: SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: slate100,
                  elevation: 0,
                  systemOverlayStyle: SystemUiOverlayStyle.dark,
                  title: Text(
                    "마킹 가이드",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: slate900,
                    ),
                  ),
                  centerTitle: false,
                  actions: [
                    if (markings.isNotEmpty)
                      IconButton(
                        key: const Key('conduit_recent_marks'),
                        icon: Icon(Icons.history_rounded, color: slate900),
                        tooltip: "최근 마킹값 보기",
                        onPressed: () => showCalcHistorySheet(
                          context,
                          calcHistory,
                          title: '최근 마킹 기록',
                        ),
                      ),
                    if (markings.isNotEmpty)
                      IconButton(
                        key: const Key('conduit_save_drawing'),
                        icon: Icon(AppIcons.download, color: slate900),
                        tooltip: "보관함에 저장",
                        onPressed: () => showConduitSaveDialog(
                          context,
                          bends: bendList,
                          totalCut: totalCut,
                          settings: currentSettings,
                          onOpenArchive: widget.onOpenArchive,
                        ),
                      ),
                    if (markings.isNotEmpty)
                      IconButton(
                        key: const Key('conduit_marking_sheet'),
                        icon: Icon(
                          Icons.picture_as_pdf_outlined,
                          color: slate900,
                        ),
                        tooltip: "마킹지(PDF)",
                        onPressed: () => openMarkingSheet(
                          context,
                          title: "전선관 벤딩 마킹지",
                          fileBase: "전선관_마킹지",
                          data: computeConduitFieldData(),
                          specs: conduitMarkingSheetSpecs(currentSettings),
                          inputs: bendList,
                        ),
                      ),
                    if (markings.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: IconButton(
                          icon: Icon(
                            Icons.screen_rotation_rounded,
                            color: slate900,
                          ),
                          tooltip: "가로 도면 보기",
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FieldMarkingScreen(
                                  progressKey: 'field_progress_conduit_v1',
                                  listenable: conduitFieldListenable(),
                                  compute: computeConduitFieldData,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: BendWarningBanner(warnings: check.warnings),
                ),
                SliverToBoxAdapter(
                  child: markings.isEmpty
                      ? const SizedBox.shrink()
                      : (benderType == 'ram'
                            ? _buildRamDashboard(totalCut, currentSettings)
                            : benderType == 'chicago'
                            ? _buildChicagoDashboard(totalCut, currentSettings)
                            : _buildHandDashboard(totalCut, currentSettings)),
                ),
                markings.isEmpty
                    ? SliverFillRemaining(child: _buildEmptyState())
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        // 가로로 넓으면 두 줄로 나란히(10-09).
                        sliver: markCardSliver(
                          count: markings.length,
                          build: (index) {
                            var item = markings[index];
                            if (item['benderType'] == 'ram') {
                              return _buildRamMarkingCard(index, item);
                            } else if (item['benderType'] == 'chicago') {
                              return _buildChicagoMarkingCard(index, item);
                            } else {
                              return _buildHandMarkingCard(index, item);
                            }
                          },
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // 🎨 1. 수동 벤더(Hand) UI 위젯
  // ==========================================
  Widget _buildHandDashboard(double totalCut, Map<String, dynamic> settings) {
    return _buildBaseDashboard(
      totalCut: totalCut,
      title: "총 절단 길이 (수동 벤더)",
      icon: AppGlyph.benderHand,
      themeColor: makitaTeal,
      deductionLabel: "설정된 테이크업",
      deductionValue: settings['takeUp'] ?? 0.0,
      couplingAllowance: conduitCouplingAllowance(settings),
    );
  }

  Widget _buildHandMarkingCard(int index, Map<String, dynamic> item) {
    return _buildBaseMarkingCard(index: index, item: item);
  }

  // ==========================================
  // 🎨 2. 유압식(Ram) UI 위젯
  // ==========================================
  Widget _buildRamDashboard(double totalCut, Map<String, dynamic> settings) {
    return _buildBaseDashboard(
      totalCut: totalCut,
      title: "총 절단 길이 (유압식)",
      icon: AppGlyph.benderRam,
      themeColor: makitaTeal,
      // 10-09: 유압은 마킹을 슈 가운데에 맞춘다 — 꺾이는 점에서 게인의 절반 앞.
      deductionLabel: "슈 가운데까지 (90°, 게인 ÷ 2)",
      deductionValue: ramShoeCenterOffset(
        90,
        (settings['gain'] as num?)?.toDouble() ?? 0.0,
      ),
      couplingAllowance: conduitCouplingAllowance(settings),
    );
  }

  Widget _buildRamMarkingCard(int index, Map<String, dynamic> item) {
    double ramTravel = (item['ramTravel'] as num?)?.toDouble() ?? 0.0;
    bool isStraight = (item['angle'] as num).toDouble() == 0.0;

    return _buildBaseMarkingCard(
      index: index,
      item: item,
      // 🚀 [고침] 유압 램은 관 굵기·받침 간격에 따라 실제로 밀어야 하는
      // 양이 달라진다. 이 값은 sin(각/2) 비율로 잡은 어림값이므로,
      // 값 옆에 어림값이라고 적어 한 번 재 보고 쓰게 한다.
      extra: isStraight
          ? null
          : (
              AppIcons.info,
              ramTravel > 0
                  ? "램 이동 (대략) ${ramTravel.toStringAsFixed(1)} mm · 첫 벤드는 실측"
                  : "램 이동: 설정에서 값을 넣으십시오",
              stepNoteTeal,
            ),
    );
  }

  // ==========================================
  // 🎨 3. 시카고식(Chicago) UI 위젯
  // ==========================================
  Widget _buildChicagoDashboard(
    double totalCut,
    Map<String, dynamic> settings,
  ) {
    return _buildBaseDashboard(
      totalCut: totalCut,
      title: "총 절단 길이 (시카고식)",
      icon: AppGlyph.benderChicago,
      themeColor: makitaTeal,
      deductionLabel: "설정된 테이크업",
      deductionValue: settings['takeUp'] ?? 0.0,
      couplingAllowance: conduitCouplingAllowance(settings),
    );
  }

  Widget _buildChicagoMarkingCard(int index, Map<String, dynamic> item) {
    int notches = item['notches'] ?? 0;
    bool isStraight = (item['angle'] as num).toDouble() == 0.0;

    return _buildBaseMarkingCard(
      index: index,
      item: item,
      extra: isStraight
          ? null
          : (
              AppIcons.info,
              // 10-09: 칸 수는 스프링백을 얹은 각도로 셈한다(사용법의 "한두 칸 더"와 겹치지 않게 적는다).
              // 0칸은 각이 한 칸보다 작을 때도 나온다(예전 안내 "설정에서 값을 넣으십시오"는 틀렸다).
              "기어/노치 진행 ${notches > 0
                  ? "$notches 칸 이동${(globalBenderSettings.value['applySpringback'] ?? true) == true ? ' (스프링백 포함)' : ''}"
                  : "한 칸보다 작은 각입니다(설정의 칸당 각도 확인)"}",
              stepNoteTeal,
            ),
    );
  }

  // ==========================================
  // 🧱 공통 UI 빌더
  // ==========================================
  // 10-15 새 모양: 튜브와 같은 총 절단 길이 카드. 벤더 종류는 색(파랑·보라) 대신 제목 옆 글로.
  Widget _buildBaseDashboard({
    required double totalCut,
    required String title,
    required Object icon,
    required Color themeColor,
    required String deductionLabel,
    required double deductionValue,
    required double couplingAllowance,
  }) {
    final m = RegExp(r'\(([^()]+)\)$').firstMatch(title);
    return CutLengthCard(
      totalCut: totalCut,
      tag: m?.group(1),
      under: _useCoupling
          ? Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                "끝 여유 ${couplingAllowance.round()}mm 포함 · 벤딩한 뒤 반대쪽 끝을 맞춰 자르십시오",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: slate600),
              ),
            )
          : null,
      bottom: [
        Row(
          children: [
            Expanded(
              child: CardLabelValue(deductionLabel, "${deductionValue.round()} mm"),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("커플링", style: cardLabelStyle.copyWith(color: slate600)),
                const SizedBox(height: 4),
                // 하나만 고르는 붙은 네모 줄(앱 공통 고르기 모양, ✓)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: pickIdleLine(fc), width: 1.2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildToggleBtn(
                        title: "미체결",
                        isSelected: !_useCoupling,
                        themeColor: themeColor,
                        onTap: () => setState(() => _useCoupling = false),
                      ),
                      Container(width: 1, height: 30, color: pickIdleLine(fc)),
                      _buildToggleBtn(
                        title: "체결",
                        isSelected: _useCoupling,
                        themeColor: themeColor,
                        onTap: () => setState(() => _useCoupling = true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// 입력 탭과 같게: 정수면 정수로, 아니면 소수 한 자리로(22.5° → '22.5').
  String _fmtAngle(double a) =>
      a == a.roundToDouble() ? a.toStringAsFixed(0) : a.toStringAsFixed(1);

  /// 마킹 카드(10-15 새 모양): 튜브와 같은 [StepMarkCard]. 벤더 종류별 덧붙임(램 이동·노치)은
  /// [extra]로 받아 카드 아래 줄에 둔다. 색은 청록 하나(예전: 유압 파랑·시카고 보라).
  Widget _buildBaseMarkingCard({
    required int index,
    required Map<String, dynamic> item,
    StepNote? extra,
  }) {
    double angle = (item['angle'] as num).toDouble();
    double targetAngle = (item['targetAngle'] as num?)?.toDouble() ?? angle;
    double rotation = (item['rotation'] as num).toDouble();
    double mark = (item['mark'] as num).toDouble();
    String note = item['note']?.toString() ?? '';
    bool isStraight = angle == 0.0;
    // 10-09: 번호는 벤드에만(현장 탭·마킹지의 "N번 마킹"과 같은 번호). 예전에는 직관 줄까지 셌다.
    final int markNo = (item['markNo'] as num?)?.toInt() ?? (index + 1);
    // 앞 마킹보다 뒤로 간 벤드. 그 사이 곧은 부분이 벤더에 물릴 만큼 없다.
    final bool isShort = item['short'] == true;
    final double roll = isStraight ? 0 : (_rolls[index] ?? 0);
    return StepMarkCard(
      key: Key('conduit_mark_$index'),
      isStraight: isStraight,
      markNum: markNo,
      mark: mark.round(),
      // "실제 N°"는 스프링백을 얹어 각이 다를 때만(튜브 카드와 같게). 22.5°는 그대로.
      title: isStraight
          ? "직관 연장 마킹"
          : (targetAngle - angle).abs() > 0.05
          ? "${_fmtAngle(angle)}° 벤딩 (실제 ${targetAngle.toStringAsFixed(1)}°)"
          : "${_fmtAngle(angle)}° 벤딩",
      dirIcon: isStraight ? null : Icons.turn_right_rounded,
      dirText: isStraight ? null : _getDirectionText(rotation),
      notes: [
        if (note.isNotEmpty)
          (
            isShort ? AppIcons.warning : AppIcons.info,
            note,
            isShort ? stepNoteAmber : (isStraight ? stepNoteGrey : stepNoteTeal),
          ),
        if (roll > 0.5)
          (
            AppIcons.warning,
            markNo <= 1
                ? "꺾기 전에 관을 ${roll.round()}° 굴려 잡으십시오"
                : "앞 벤드에서 ${roll.round()}° 굴려 물리십시오",
            stepNoteAmber,
          ),
        ?extra,
      ],
    );
  }

  Widget _buildToggleBtn({
    required String title,
    required bool isSelected,
    required Color themeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        color: isSelected ? pickFill(fc) : fc.surface,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[pickCheck(fc, 14), const SizedBox(width: 3)],
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? pickInk(fc) : fc.text,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: slate200, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: slate900.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: slate100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.straighten_rounded,
                  size: 40,
                  color: slate600.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "마킹 값이 없습니다",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: slate900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "입력 탭에서 배관 형태와 길이를 넣으면\n여기에 마킹 자리가 나옵니다.",
                textAlign: TextAlign.center,
                style: TextStyle(color: slate600, height: 1.5, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
