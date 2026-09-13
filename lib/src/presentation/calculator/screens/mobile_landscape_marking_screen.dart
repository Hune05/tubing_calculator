import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart'
    show computeLandscapeMarkingData;

// 🚀 [추가] 전선관 벤딩 마킹 계산기의 "현장" 탭(가로 모드 줄자 화면)을
// 일반 벤딩 마킹 계산기 쪽에도 그대로 적용한 것. 구현은
// conduit/screens/main_navigation_page.dart의 LandscapeMarkingScreen과
// 거의 동일하다.
// 🚀 [버그 수정] 처음엔 MobileResultTab이 계산한 값을 전역 ValueNotifier에
// 밀어넣고 이 화면이 구독하는 방식이었는데, IndexedStack 안에서 두 위젯의
// 빌드 타이밍이 어긋나 "현장" 탭이 텅 빈 초기값을 보여줄 때가 있었다.
// 이제 이 화면이 MobileBendDataManager를 직접 구독해서 매번 스스로
// computeLandscapeMarkingData()를 호출해 최신값을 계산한다 - 다른 탭이
// 먼저 빌드됐는지 여부와 완전히 무관해졌다.
const Color _paperBg = Color(0xFFF2F0E9);
const Color _strokeColor = Color(0xFF2D2D2D);
const Color _accentRed = Color(0xFFD32F2F);
const Color _tableHeaderGray = Color(0xFFDFDDD3);
const Color _highlightColor = Colors.deepOrange;

class BendingLandscapeMarkingScreen extends StatefulWidget {
  final VoidCallback? onCloseTab;
  // 🚀 IndexedStack 안에서 이 화면이 실제로 보이고 있을 때만(isActive)
  // 가로 고정 + 뒤로가기 가로채기를 하도록 하는 값 (전선관 계산기와 동일한
  // 방식 - main_navigation_page.dart의 같은 이름 필드 주석 참고).
  final bool isActive;

  const BendingLandscapeMarkingScreen({
    super.key,
    this.onCloseTab,
    this.isActive = true,
  });

  @override
  State<BendingLandscapeMarkingScreen> createState() =>
      _BendingLandscapeMarkingScreenState();
}

class _BendingLandscapeMarkingScreenState
    extends State<BendingLandscapeMarkingScreen> {
  final ScrollController _mainScrollController = ScrollController();
  final double mmToPixel = 2.0;
  int? _selectedIndex;

  final List<Map<String, dynamic>> _directions = [
    {"label": "UP (위)", "val": 0.0},
    {"label": "RIGHT (우)", "val": 90.0},
    {"label": "DOWN (아래)", "val": 180.0},
    {"label": "LEFT (좌)", "val": 270.0},
    {"label": "FRONT (앞)", "val": 360.0},
    {"label": "BACK (뒤)", "val": 450.0},
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

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _setLandscapeMode();
    }
  }

  @override
  void didUpdateWidget(covariant BendingLandscapeMarkingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _setLandscapeMode();
    } else if (!widget.isActive && oldWidget.isActive) {
      _restorePortraitMode();
    }
  }

  void _setLandscapeMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _restorePortraitMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _restorePortraitMode();
    _mainScrollController.dispose();
    super.dispose();
  }

  void _handleClose(BuildContext context) {
    _restorePortraitMode();
    if (widget.onCloseTab != null) {
      widget.onCloseTab!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MobileBendDataManager(),
      builder: (context, child) {
        final data = computeLandscapeMarkingData();
        final totalCutLength = data.totalCutLength;
        final markings = data.markings;

        if (markings.isEmpty) {
          return PopScope(
            canPop: !widget.isActive,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop && widget.isActive) _handleClose(context);
            },
            child: Scaffold(
              backgroundColor: _paperBg,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      data.error != null
                          ? Icons.error_outline_rounded
                          : Icons.straighten_rounded,
                      size: 64,
                      color: data.error != null
                          ? Colors.red.shade400
                          : _strokeColor.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      data.error != null ? "이 도면은 계산할 수 없습니다" : "데이터를 입력해주세요",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: _strokeColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        data.error ??
                            "입력 탭에서 배관 형태와 길이를 추가하면 현장 도면이 생성됩니다.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: _strokeColor.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        double contentWidth = (totalCutLength * mmToPixel) + 150;

        return PopScope(
          canPop: !widget.isActive,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && widget.isActive) _handleClose(context);
          },
          child: Scaffold(
            backgroundColor: _paperBg,
            body: SafeArea(
              child: Column(
                children: [
                  _buildResponsiveOverviewBar(
                    context,
                    totalCutLength,
                    markings,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _mainScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: SizedBox(
                        width: contentWidth,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: 160,
                              left: 50,
                              right: 50,
                              height: 30,
                              child: _buildPipeBody(),
                            ),
                            Positioned(
                              top: 190,
                              left: 50,
                              child: SizedBox(
                                width: totalCutLength * mmToPixel,
                                height: 50,
                                child: CustomPaint(
                                  painter: _MetricTapeMeasurePainter(
                                    mmToPixel,
                                  ),
                                ),
                              ),
                            ),
                            ...markings.asMap().entries.map(
                              (entry) =>
                                  _buildMarkingPoint(entry.value, entry.key),
                            ),
                            ...markings.asMap().entries.map((entry) {
                              int index = entry.key;
                              double positionMm = (entry.value['mark'] as num)
                                  .toDouble();
                              double xPos = 50 + (positionMm * mmToPixel);
                              bool isSelected = _selectedIndex == index;

                              return Positioned(
                                left: xPos,
                                top: 155,
                                height: 40,
                                child: Container(
                                  width: isSelected ? 2.5 : 1.5,
                                  color: isSelected
                                      ? _highlightColor
                                      : _strokeColor.withValues(alpha: 0.4),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildBottomDataTable(markings),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResponsiveOverviewBar(
    BuildContext context,
    double totalCutLength,
    List<Map<String, dynamic>> markings,
  ) {
    return Container(
      height: 60,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: _strokeColor.withValues(alpha: 0.2)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double mapWidth = constraints.maxWidth - 200;
          if (mapWidth < 100) mapWidth = 100;

          return Row(
            children: [
              Text(
                "TOTAL: ${totalCutLength.toInt()}mm",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _strokeColor,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: mapWidth,
                height: 20,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 4,
                      width: mapWidth,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    ...markings.asMap().entries.map((entry) {
                      int index = entry.key;
                      Map<String, dynamic> m = entry.value;
                      double pos = (m['mark'] as num).toDouble();
                      double dotPos = totalCutLength > 0
                          ? (pos / totalCutLength) * mapWidth
                          : 0;
                      bool isSelected = _selectedIndex == index;

                      return Positioned(
                        left: dotPos - (isSelected ? 4 : 3),
                        child: Container(
                          width: isSelected ? 8 : 6,
                          height: isSelected ? 8 : 6,
                          decoration: BoxDecoration(
                            color: isSelected ? _highlightColor : _accentRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: _strokeColor,
                  size: 28,
                ),
                onPressed: () => _handleClose(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPipeBody() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey[600]!, Colors.grey[300]!, Colors.grey[800]!],
        ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _strokeColor, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 4),
        ],
      ),
    );
  }

  Widget _buildMarkingPoint(Map<String, dynamic> item, int index) {
    double positionMm = (item['mark'] as num).toDouble();
    double angle = (item['angle'] as num).toDouble();
    double rotation = (item['rotation'] as num).toDouble();
    bool isStraight = angle == 0.0;
    String title = isStraight ? "직관 연장" : "${angle.toInt()}° 벤딩";
    String rotText = _getDirectionText(rotation);

    double xPos = 50 + (positionMm * mmToPixel);
    bool isEven = index % 2 == 0;
    double topPosition = isEven ? 20 : 80;
    bool isSelected = _selectedIndex == index;

    return Positioned(
      left: xPos - 60,
      top: topPosition,
      width: 120,
      child: AnimatedScale(
        scale: isSelected ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.bottomCenter,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _strokeColor, width: 1.5),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(2, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "${positionMm.toInt()}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _strokeColor,
                    ),
                  ),
                  if (!isStraight)
                    Text(
                      "↺ $rotText",
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -4),
              child: Icon(
                Icons.arrow_drop_down,
                color: isSelected
                    ? _highlightColor
                    : _strokeColor.withValues(alpha: 0.7),
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomDataTable(List<Map<String, dynamic>> markings) {
    return Container(
      height: 85,
      color: _tableHeaderGray,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: markings.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final m = markings[index];
          double positionMm = (m['mark'] as num).toDouble();
          bool isSelected = _selectedIndex == index;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedIndex = (_selectedIndex == index) ? null : index;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 130,
              margin: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? _highlightColor.withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? _highlightColor : _strokeColor,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "STEP ${index + 1}",
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? _highlightColor : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${positionMm.toInt()} mm",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? _highlightColor : _strokeColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MetricTapeMeasurePainter extends CustomPainter {
  final double scale;
  _MetricTapeMeasurePainter(this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _strokeColor
      ..strokeWidth = 1.0;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (double i = 0; i <= size.width; i += (1 * scale)) {
      double mmValue = i / scale;
      double tickHeight = 0;

      if (mmValue % 100 == 0) {
        tickHeight = 22;
        _drawText(
          canvas,
          textPainter,
          "${(mmValue / 10).toInt()}cm",
          i,
          24,
          isBold: true,
        );
      } else if (mmValue % 50 == 0) {
        tickHeight = 15;
      } else if (mmValue % 10 == 0) {
        tickHeight = 10;
      }
      if (tickHeight > 0) {
        canvas.drawLine(Offset(i, 0), Offset(i, tickHeight), paint);
      }
    }
  }

  void _drawText(
    Canvas canvas,
    TextPainter tp,
    String text,
    double x,
    double y, {
    bool isBold = false,
  }) {
    tp.text = TextSpan(
      text: text,
      style: TextStyle(
        color: _strokeColor,
        fontSize: 11,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      ),
    );
    tp.layout();
    double dx = x - (tp.width / 2);
    if (dx < 0) dx = 0;
    tp.paint(canvas, Offset(dx, y));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
