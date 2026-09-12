import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_result_tab.dart';

const Color paperBg = Color(0xFFF2F0E9);
const Color strokeColor = Color(0xFF2D2D2D);
const Color accentRed = Color(0xFFD32F2F);
const Color tapeYellow = Color(0xFFFFD54F);
const Color tableHeaderGray = Color(0xFFDFDDD3);
const Color highlightColor = Colors.deepOrange; // 선택 시 강조될 주황색

class LandscapeMarkingScreen extends StatefulWidget {
  final VoidCallback? onCloseTab;

  const LandscapeMarkingScreen({super.key, this.onCloseTab});

  @override
  State<LandscapeMarkingScreen> createState() => _LandscapeMarkingScreenState();
}

class _LandscapeMarkingScreenState extends State<LandscapeMarkingScreen> {
  final ScrollController _mainScrollController = ScrollController();
  final double mmToPixel = 2.0;

  // 선택된 마킹 포인트의 인덱스를 저장하는 변수
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
    _setLandscapeMode();
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
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: globalMarkingState,
      builder: (context, data, child) {
        final totalCutLength = data['totalCutLength'] as double;
        final markings = data['markings'] as List<Map<String, dynamic>>;

        if (markings.isEmpty) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) _handleClose(context);
            },
            child: Scaffold(
              backgroundColor: paperBg,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.straighten_rounded,
                      size: 64,
                      color: strokeColor.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "데이터를 입력해주세요",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: strokeColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "입력 탭에서 배관 형태와 길이를 추가하면 현장 도면이 생성됩니다.",
                      style: TextStyle(
                        fontSize: 14,
                        color: strokeColor.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        double contentWidth = (totalCutLength * mmToPixel) + 150;

        // 🚀 [개선 3] 선택된 인덱스(_selectedIndex)의 말풍선이 가장 마지막(최상위 레이어)에 오도록 분리
        final unselectedMarkings = markings.asMap().entries.where(
          (e) => e.key != _selectedIndex,
        );
        final selectedMarking =
            _selectedIndex != null && _selectedIndex! < markings.length
            ? markings.asMap().entries.elementAt(_selectedIndex!)
            : null;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _handleClose(context);
          },
          child: Scaffold(
            backgroundColor: paperBg,
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
                          clipBehavior: Clip.none, // 애니메이션 커질 때 잘림 방지
                          children: [
                            // 1. 파이프 바디
                            Positioned(
                              top: 160,
                              left: 50,
                              right: 50,
                              height: 30,
                              child: _buildPipeBody(),
                            ),
                            // 2. 줄자 영역
                            Positioned(
                              top: 190,
                              left: 50,
                              child: SizedBox(
                                width: totalCutLength * mmToPixel,
                                height: 50,
                                child: CustomPaint(
                                  painter: MetricTapeMeasurePainter(mmToPixel),
                                ),
                              ),
                            ),

                            // 3. 실제 마킹 수직선 (선택 안 된 것 먼저, 선택된 것 마지막)
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
                                      ? highlightColor
                                      : strokeColor.withValues(alpha: 0.4),
                                ),
                              );
                            }),

                            // 4. 말풍선 렌더링 (선택되지 않은 마킹들 먼저 렌더링)
                            ...unselectedMarkings.map(
                              (entry) =>
                                  _buildMarkingPoint(entry.value, entry.key),
                            ),

                            // 5. 🚀 선택된 말풍선을 가장 최상위 레이어(Stack 맨 뒤)에 렌더링하여 겹침 방지!
                            if (selectedMarking != null)
                              _buildMarkingPoint(
                                selectedMarking.value,
                                selectedMarking.key,
                              ),
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
          bottom: BorderSide(color: strokeColor.withValues(alpha: 0.2)),
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
                  color: strokeColor,
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
                        left: dotPos - (isSelected ? 4 : 3), // 선택 시 도트 살짝 크게
                        child: Container(
                          width: isSelected ? 8 : 6,
                          height: isSelected ? 8 : 6,
                          decoration: BoxDecoration(
                            color: isSelected ? highlightColor : accentRed,
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
                  color: strokeColor,
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
        border: Border.all(color: strokeColor, width: 1.5),
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

    // 말풍선 높이: 상단(isEven)은 20, 하단(!isEven)은 80
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
                border: Border.all(
                  color: isSelected ? highlightColor : strokeColor,
                  width: isSelected ? 2.0 : 1.5,
                ),
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
                      color: isSelected ? highlightColor : Colors.grey[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "${positionMm.toInt()}",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? highlightColor : strokeColor,
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
                    ? highlightColor
                    : strokeColor.withValues(alpha: 0.7),
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
      color: tableHeaderGray,
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
                if (_selectedIndex == index) {
                  _selectedIndex = null;
                } else {
                  _selectedIndex = index;

                  // 🚀 [개선 2] STEP 터치 시 선택한 마킹 위치가 화면 중앙에 오도록 부드럽게 자동 스크롤!
                  double targetX = (positionMm * mmToPixel) + 50;
                  double screenWidth = MediaQuery.of(context).size.width;

                  double scrollTo = (targetX - (screenWidth / 2)).clamp(
                    0.0,
                    _mainScrollController.position.maxScrollExtent,
                  );

                  _mainScrollController.animateTo(
                    scrollTo,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOutCubic,
                  );
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 130,
              margin: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? highlightColor.withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? highlightColor : strokeColor,
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
                      color: isSelected ? highlightColor : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${positionMm.toInt()} mm",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? highlightColor : strokeColor,
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

class MetricTapeMeasurePainter extends CustomPainter {
  final double scale;
  MetricTapeMeasurePainter(this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = 1.0;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // 🚀 [개선 1] 1mm가 아닌 실제 선을 긋는 최소 단위인 10mm(1cm) 단위로 루프 점프! (연산량 90% 절감)
    final double step = 10.0 * scale;

    for (double i = 0; i <= size.width; i += step) {
      double mmValue = (i / scale).roundToDouble(); // 부동소수점 오차 방지
      double tickHeight = 10; // 기본 10mm 단위 눈꿈선 높이

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
      }

      canvas.drawLine(Offset(i, 0), Offset(i, tickHeight), paint);
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
        color: strokeColor,
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
