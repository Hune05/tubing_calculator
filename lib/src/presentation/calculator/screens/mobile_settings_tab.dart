import 'package:flutter/material.dart';

import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/core/utils/app_settings_controller.dart';
import 'package:tubing_calculator/src/presentation/settings/controllers/settings_controller.dart';
import 'package:tubing_calculator/src/presentation/settings/widgets/settings_widgets.dart';
import 'package:tubing_calculator/src/core/utils/fitting_data.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color pureWhite = Color(0xFFFFFFFF);
const Color toolGripBlack = Color(0xFF222222);
const Color slate100 = Color(0xFFF1F5F9);

// 🚀 [추가] mm <-> inch 변환 계수
const double _mmPerInch = 25.4;

// ==========================================
// 🚀 1. 설정 탭 (MobileSettingsTab)
// ==========================================
class MobileSettingsTab extends StatefulWidget {
  const MobileSettingsTab({super.key});
  @override
  State<MobileSettingsTab> createState() => _MobileSettingsTabState();
}

class _MobileSettingsTabState extends State<MobileSettingsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isInch = false;
  bool _useHaptic = true;
  bool _saveHistory = true;
  bool _keepScreenOn = false;
  bool _warnShoeInterference = true;

  String _tubeMaterial = "SUS";
  String _benderBrand = "Swagelok";
  String _benderType = "수동 (Hand)";
  String _currentOD = "";

  final String _measurementMode = "C-to-C";
  String _defaultRotation = "CW (시계방향)";
  String _fittingType = "Twin Ferrule";
  String _benderMark = "0 (기본/다양한 각도)";

  final Map<String, bool> _autoStates = {
    'radius': true,
    'takeUp': true,
    'gain': true,
    'minStraight': true,
    'offset': true,
    'fittingDepth': true,
  };

  final _wtController = TextEditingController();
  final _rController = TextEditingController();
  final _takeUpController = TextEditingController();
  final _springbackController = TextEditingController();
  final _gainController = TextEditingController();
  final _minStraightController = TextEditingController();
  final _benderOffsetController = TextEditingController();
  final _fittingDepthController = TextEditingController();
  final _markThicknessController = TextEditingController();
  final _offsetShrinkController = TextEditingController();
  final _cutMarginController = TextEditingController();

  String get _unit => _isInch ? "inch" : "mm";
  List<String> get _odList => SettingsController.getOdList(_isInch);
  bool get _isElectric => _benderType == "전동 (Electric)";

  @override
  void initState() {
    super.initState();
    _currentOD = _odList.contains("12.7") ? "12.7" : _odList.first;
    _loadData();
  }

  // 🚀 [수정] SettingsManager/SharedPreferences를 직접 부르는 대신,
  // 앱 전역에서 공유하는 AppSettingsController에서 값을 읽어온다.
  // (이 탭에서 저장하면 AppSettingsController가 notifyListeners()를 호출해서
  //  MobileInputTab/CalculatorPage 등 이걸 구독하는 다른 화면도 즉시 최신값을
  //  반영하게 된다 - 예전에는 각 화면이 따로 로드해서 서로 어긋날 수 있었음)
  Future<void> _loadData() async {
    await AppSettingsController().ensureLoaded();
    final c = AppSettingsController();
    if (mounted) {
      setState(() {
        _isInch = c.isInch;
        _useHaptic = c.useHaptic;
        _saveHistory = c.saveHistory;
        _keepScreenOn = c.keepScreenOn;
        _warnShoeInterference = c.warnShoeInterference;

        _tubeMaterial = c.tubeMaterial;
        _benderBrand = c.benderBrand;
        _benderType = c.benderType;
        _defaultRotation = c.defaultRotation;
        _fittingType = c.fittingType;
        _benderMark = c.benderMark;

        String loadedOD = c.tubeOD.toString();
        if (!loadedOD.contains('.')) {
          loadedOD += ".0";
        }
        _currentOD = _odList.contains(loadedOD) ? loadedOD : _odList.first;

        _autoStates['radius'] = c.autoRadius;
        _autoStates['takeUp'] = c.autoTakeUp;
        _autoStates['gain'] = c.autoGain;
        _autoStates['minStraight'] = c.autoMinStraight;
        _autoStates['offset'] = c.autoOffset;
        _autoStates['fittingDepth'] = c.autoFittingDepth;

        _wtController.text = c.tubeWT.toString();
        _springbackController.text = c.springback.toString();
        _markThicknessController.text = c.markThickness.toString();
        _offsetShrinkController.text = c.offsetShrink.toString();
        _cutMarginController.text = c.cutMargin.toString();

        if (_autoStates['radius'] == false) {
          _rController.text = c.bendRadius.toString();
        }
        if (_autoStates['takeUp'] == false) {
          _takeUpController.text = c.takeUp.toString();
        }
        if (_autoStates['gain'] == false) {
          _gainController.text = c.gain.toString();
        }
        if (_autoStates['minStraight'] == false) {
          _minStraightController.text = c.minStraight.toString();
        }
        if (_autoStates['offset'] == false) {
          _benderOffsetController.text = c.benderOffset.toString();
        }
        if (_autoStates['fittingDepth'] == false) {
          _fittingDepthController.text = c.fittingDepth.toString();
        }
      });
      _onSpecsChanged();

      MobileBendDataManager().updateMachineSpecs(
        takeUp90: double.tryParse(_takeUpController.text) ?? 0.0,
        fittingDepth: double.tryParse(_fittingDepthController.text) ?? 0.0,
        gain90: double.tryParse(_gainController.text) ?? 0.0,
        radius: double.tryParse(_rController.text) ?? 0.0,
        benderOffset: double.tryParse(_benderOffsetController.text) ?? 0.0,
        springback: double.tryParse(_springbackController.text) ?? 0.0,
        cutMargin: double.tryParse(_cutMarginController.text) ?? 0.0,
      );
    }
  }

  // 🚀 [수정] "저장" 버튼을 누르면 이 화면의 임시(초안) 값들을
  // AppSettingsController에 반영한 뒤 controller.save()를 호출한다.
  // controller.save()가 내부적으로 SettingsManager.saveSettings()로 영속
  // 저장하고, notifyListeners()로 이 설정을 구독하는 다른 화면들도 즉시
  // 갱신한다.
  Future<void> _saveData() async {
    FocusScope.of(context).unfocus();

    final c = AppSettingsController();
    c.isInch = _isInch;
    c.useHaptic = _useHaptic;
    c.saveHistory = _saveHistory;
    c.tubeMaterial = _tubeMaterial;
    c.benderBrand = _benderBrand;
    c.measurementMode = _measurementMode;
    c.defaultRotation = _defaultRotation;
    c.fittingType = _fittingType;
    c.benderMark = _benderMark;
    c.benderType = _benderType;
    c.tubeOD = double.tryParse(_currentOD) ?? 0.0;
    c.tubeWT = double.tryParse(_wtController.text) ?? 0.0;
    c.bendRadius = double.tryParse(_rController.text) ?? 0.0;
    c.takeUp = double.tryParse(_takeUpController.text) ?? 0.0;
    c.springback = double.tryParse(_springbackController.text) ?? 0.0;
    c.gain = double.tryParse(_gainController.text) ?? 0.0;
    c.minStraight = double.tryParse(_minStraightController.text) ?? 0.0;
    c.benderOffset = double.tryParse(_benderOffsetController.text) ?? 0.0;
    c.fittingDepth = double.tryParse(_fittingDepthController.text) ?? 0.0;
    c.markThickness = double.tryParse(_markThicknessController.text) ?? 0.0;
    c.offsetShrink = double.tryParse(_offsetShrinkController.text) ?? 0.0;
    c.cutMargin = double.tryParse(_cutMarginController.text) ?? 0.0;
    c.autoRadius = _autoStates['radius'] ?? true;
    c.autoTakeUp = _autoStates['takeUp'] ?? true;
    c.autoGain = _autoStates['gain'] ?? true;
    c.autoMinStraight = _autoStates['minStraight'] ?? true;
    c.autoOffset = _autoStates['offset'] ?? true;
    c.autoFittingDepth = _autoStates['fittingDepth'] ?? true;
    c.keepScreenOn = _keepScreenOn;
    c.warnShoeInterference = _warnShoeInterference;

    await c.save();

    MobileBendDataManager().updateMachineSpecs(
      takeUp90: double.tryParse(_takeUpController.text) ?? 0.0,
      fittingDepth: double.tryParse(_fittingDepthController.text) ?? 0.0,
      gain90: double.tryParse(_gainController.text) ?? 0.0,
      radius: double.tryParse(_rController.text) ?? 0.0,
      benderOffset: double.tryParse(_benderOffsetController.text) ?? 0.0,
      springback: double.tryParse(_springbackController.text) ?? 0.0,
      cutMargin: double.tryParse(_cutMarginController.text) ?? 0.0,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isElectric ? "전동 장비 설정이 저장되었습니다." : "수동 장비 설정이 저장되었습니다.",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: makitaTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // 🚀 [수정] isInitialLoad 파라미터는 실제로 아무 곳에서도 사용되지 않던 죽은 코드라 제거함
  void _onSpecsChanged() {
    final specs = SettingsController.getStandardSpecs(_benderBrand, _currentOD);
    setState(() {
      // 🚀 [수정] specs가 null(해당 브랜드/규격 조합의 표준 제원이 없는 경우)이면
      // 이전 선택에서 남아있던 값을 그대로 보여주지 않고 필드를 비워서
      // "AUTO인데 실제로는 계산 안 됨"이 조용히 숨겨지지 않도록 함
      if (_autoStates['radius'] == true) {
        _rController.text = specs != null ? specs.bendRadius.toString() : "";
      }
      if (_autoStates['takeUp'] == true) {
        _takeUpController.text = specs != null ? specs.takeUp.toString() : "";
      }
      if (_autoStates['gain'] == true) {
        _gainController.text = specs != null ? specs.gain.toString() : "";
      }
      if (_autoStates['minStraight'] == true) {
        _minStraightController.text = specs != null
            ? specs.minStraight.toString()
            : "";
      }
      if (_autoStates['offset'] == true) {
        _benderOffsetController.text = specs != null
            ? specs.benderOffset.toString()
            : "";
      }
      if (_autoStates['fittingDepth'] == true) {
        if (_fittingType == "Twin Ferrule") {
          double depth = FittingData.getInsertionDepth(
            _benderBrand,
            _currentOD,
          );
          _fittingDepthController.text = depth > 0 ? depth.toString() : "";
        } else {
          _fittingDepthController.text = "";
        }
      }
    });
  }

  // 🚀 [추가] mm <-> inch 전환 시 길이 단위를 쓰는 수동 입력값들을 실제로 변환한다.
  // (기존에는 OD 드롭다운만 바뀌고 두께/스프링백/마킹선 두께/오프셋 축소/AUTO OFF 상태의
  //  반경·테이크업·연신율·최소직선·오프셋·피팅깊이 값은 텍스트가 그대로 남아있어서,
  //  숫자는 그대로인데 단위 해석만 바뀌는 심각한 치수 오류가 날 수 있었음)
  void _convertLengthControllers(bool toInch) {
    final controllers = [
      _wtController,
      _rController,
      _takeUpController,
      _gainController,
      _minStraightController,
      _benderOffsetController,
      _fittingDepthController,
      _markThicknessController,
      _offsetShrinkController,
    ];
    for (final c in controllers) {
      final val = double.tryParse(c.text);
      if (val == null || val == 0) continue;
      final converted = toInch ? val / _mmPerInch : val * _mmPerInch;
      String text = converted.toStringAsFixed(toInch ? 4 : 2);
      if (text.contains('.')) {
        text = text.replaceAll(RegExp(r'0+$'), '');
        text = text.replaceAll(RegExp(r'\.$'), '');
      }
      c.text = text;
    }
  }

  @override
  void dispose() {
    _wtController.dispose();
    _rController.dispose();
    _takeUpController.dispose();
    _springbackController.dispose();
    _gainController.dispose();
    _minStraightController.dispose();
    _benderOffsetController.dispose();
    _fittingDepthController.dispose();
    _markThicknessController.dispose();
    _offsetShrinkController.dispose();
    _cutMarginController.dispose();
    super.dispose();
  }

  // ==========================================
  // 💡 헬퍼(도움말) 아이콘을 포함한 텍스트 위젯 생성 함수
  // ==========================================
  Widget _buildLabelWithHelp(
    BuildContext context,
    String label,
    String helpTitle,
    String helpContent,
  ) {
    return Row(
      // 🚀 [원복] 이 함수는 대부분 Column 안(폭이 정해진 안전한 곳)에서
      // 쓰이지만, "물림 길이(간섭) 경고" 스위치 줄처럼 Row(spaceBetween)의
      // 일반 자식으로도 쓰인다. 그런 자리는 Flutter가 자연스러운 크기를
      // 재려고 폭을 무한대로 주는데, 거기서 Flexible을 쓰면 "incoming
      // width constraints are unbounded"로 즉시 크래시하고, 이 화면이
      // IndexedStack으로 항상 미리 빌드되는 구조라 그 크래시가 다른 탭
      // 버튼까지 먹통으로 만드는 심각한 문제로 이어졌다(실기기로 확인).
      // 라벨을 줄여야 하는 자리는 함수 내부가 아니라 그 호출부에서
      // Expanded로 감싸는 방식으로 해결한다.
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: slate600,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: pureWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    const Icon(Icons.help_outline, color: makitaTeal),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        helpTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: slate900,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Text(
                  helpContent,
                  style: const TextStyle(
                    color: slate900,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: makitaTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "이해했습니다!",
                      style: TextStyle(
                        color: pureWhite,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2.0),
            child: Icon(
              Icons.help_outline,
              size: 16,
              color: Colors.blueGrey.shade400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownWithAdvancedHelper({
    required String label,
    required String helpTitle,
    required String helpContent,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String Function(String)? displayMapper,
    required String helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabelWithHelp(context, label, helpTitle, helpContent),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    displayMapper != null ? displayMapper(item) : item,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          helperText,
          style: TextStyle(
            fontSize: 11,
            color: Colors.blueGrey[700],
            fontWeight: FontWeight.w600,
            height: 1.4,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildNumpadInputWithHelp(
    String label,
    String helpTitle,
    String helpContent,
    TextEditingController controller, {
    String? key,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabelWithHelp(context, label, helpTitle, helpContent),
        const SizedBox(height: 6),
        MakitaNumericInput(
          label: "", // 라벨을 위에서 따로 그렸으므로 빈 문자열 전달
          controller: controller,
          helperText: helperText,
          isAutoMode: key != null ? _autoStates[key] : null,
          onModeChanged: key != null
              ? (isAuto) {
                  setState(() => _autoStates[key] = isAuto);
                  if (isAuto) {
                    _onSpecsChanged();
                  }
                }
              : null,
          onTap: () {
            if (key == null || _autoStates[key] != true) {
              MakitaNumpad.show(context, controller: controller, title: label);
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._buildLeftInputSettingsGroup(),
                const SizedBox(height: 24),
                ..._buildRightGuideGroup(),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: pureWhite,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _saveData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: makitaTeal,
                  foregroundColor: pureWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.save),
                label: const Text(
                  "설정 저장 및 적용",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 기존 헬퍼 위젯들
  Widget _machineSpecText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _guideText(String title, String desc, {Color color = Colors.black87}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 12, color: color, height: 1.5),
          children: [
            TextSpan(
              text: "$title: ",
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            TextSpan(text: desc),
          ],
        ),
      ),
    );
  }

  TableRow _buildGuideRow4Col(
    String col1,
    String col2,
    String col3,
    String col4, {
    bool isHighlight = false,
    Color? textColor4,
  }) {
    Color bgColor = isHighlight
        ? Colors.orange.withValues(alpha: 0.1)
        : Colors.transparent;
    return TableRow(
      decoration: BoxDecoration(color: bgColor),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            col1,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.black87,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            col2,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.black87,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            col3,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            col4,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: textColor4 ?? Colors.black87,
              fontWeight: (isHighlight || textColor4 != null)
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildGuideRow3Col(
    String col1,
    String col2,
    String col3, [
    Color color3 = Colors.black87,
  ]) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text(
            col1,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text(
            col2,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text(
            col3,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color3,
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildGuideRow2Col(
    String col1,
    String col2, [
    Color color2 = Colors.black87,
  ]) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text(
            col1,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text(
            col2,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color2,
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildOffsetRow(
    String angle,
    String mult,
    String shrink,
    Color pointColor,
  ) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text(
            angle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text(
            mult,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: pointColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text(
            shrink,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLockedMeasurementMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "측정 기준 (Fixed Mode)",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, size: 16, color: makitaTeal),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "C-to-C 고정",
                      style: TextStyle(
                        color: toolGripBlack,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "가상 센터라인 기준",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SettingLabel(text: label),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: makitaTeal,
          ),
        ],
      ),
    );
  }

  Widget _buildUnitToggle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          const SettingLabel(text: "측정 단위 (Unit)"),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                _buildUnitBtn("mm", !_isInch),
                _buildUnitBtn("inch", _isInch),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitBtn(String text, bool isSelected) {
    return InkWell(
      onTap: () {
        final bool newIsInch = (text == "inch");
        if (newIsInch == _isInch) return; // 이미 선택된 단위면 아무 것도 하지 않음

        // 🚀 [수정] 단위를 실제로 바꾸기 전에, 길이 값을 갖는 수동 입력 필드들을
        // 새 단위로 변환한다 (예전에는 텍스트가 그대로 남아 숫자는 같은데
        // 단위 해석만 바뀌는 심각한 치수 오류가 날 수 있었음).
        _convertLengthControllers(newIsInch);

        setState(() {
          _isInch = newIsInch;
          // 🚀 [수정] mm 기본값이 "12.0"이 아니라 "12.7"이어야
          // 최초 로드 시 기본값(1/2" = 12.7mm)과 일치함
          String targetOD = _isInch ? "0.5" : "12.7";
          _currentOD = _odList.contains(targetOD) ? targetOD : _odList.first;
        });
        _onSpecsChanged();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? makitaTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // 🚀 [수정] 데스크톱 스타일 2칼럼(TwoColumnRow)을 억지로 좁은 폰/폴더블
  // 화면에 우겨넣다 보니 라벨이 조금만 길어도 RenderFlex 오버플로우가
  // 반복적으로 발생했다. 모바일에 맞게 필드 하나가 화면 전체 폭을 쓰는
  // 세로 한 줄 배치로 다시 짠다 - 그러면 폭이 부족해서 넘치는 이 종류의
  // 문제 자체가 구조적으로 생기지 않는다.
  Widget _stackedFields(List<Widget> fields) {
    final visible = fields.where((w) {
      return !(w is SizedBox && w.width == 0 && w.height == 0);
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          visible[i],
        ],
      ],
    );
  }

  List<Widget> _buildLeftInputSettingsGroup() {
    return [
      SettingSection(
        title: "1. 튜브 기본 제원",
        icon: Icons.architecture,
        child: Column(
          children: [
            _buildUnitToggle(),
            const SizedBox(height: 8),
            _stackedFields([
              _buildDropdownWithAdvancedHelper(
                label: "외경 (OD) [$_unit]",
                helpTitle: "외경 (OD: Outside Diameter)",
                helpContent:
                    "파이프의 바깥쪽 지름을 의미합니다.\n튜빙에서 가장 중요한 기준이 되며, 기계의 다이(Die)와 피팅 사이즈를 결정하는 핵심 치수입니다.",
                value: _currentOD,
                items: _odList,
                onChanged: (val) {
                  setState(() => _currentOD = val!);
                  _onSpecsChanged();
                },
                displayMapper: (item) =>
                    SettingsController.getDisplayOD(item, _isInch),
                helperText: "※ 배관의 바깥쪽 지름",
              ),
              _buildNumpadInputWithHelp(
                "두께 (WT) [$_unit]",
                "두께 (WT: Wall Thickness)",
                "파이프 벽의 두께입니다.\n두께가 다르면 연신율(파이프가 늘어나는 정도)이 달라지므로 정밀한 계산을 위해 입력이 필요합니다.",
                _wtController,
                helperText: "※ 배관 벽의 두께",
              ),
            ]),
            const SizedBox(height: 12),
            _stackedFields([
              _buildDropdownWithAdvancedHelper(
                label: "튜브 재질",
                helpTitle: "튜브 재질",
                helpContent:
                    "파이프의 소재입니다.\nSUS(스텐), Copper(구리), Carbon(탄소강) 등 재질에 따라 탄성(스프링백)이 다르기 때문에 벤딩 후 튕겨나오는 각도를 보정할 때 참고합니다.",
                value: _tubeMaterial,
                items: const ["SUS", "Copper", "Carbon", "Aluminum"],
                onChanged: (val) => setState(() => _tubeMaterial = val!),
                helperText: "※ 재질별 특성",
              ),
              _buildDropdownWithAdvancedHelper(
                label: "피팅 타입",
                helpTitle: "피팅 타입",
                helpContent:
                    "파이프를 연결하는 부속의 종류입니다.\nTwin Ferrule(스웨즈락 등) 방식은 튜브가 부속 안으로 일정 깊이만큼 삽입되어야 하므로 이를 계산에 반영합니다.",
                value: _fittingType,
                items: const ["Twin Ferrule", "Bite Type", "Flare"],
                onChanged: (val) {
                  setState(() => _fittingType = val!);
                  _onSpecsChanged();
                },
                helperText: "※ 삽입 깊이 기준",
              ),
            ]),
          ],
        ),
      ),
      SettingSection(
        title: "2. 배관 조립 및 마킹 기준",
        icon: Icons.straighten,
        child: Column(
          children: [
            _stackedFields([
              _buildLockedMeasurementMode(),
              _buildDropdownWithAdvancedHelper(
                label: "기본 회전",
                helpTitle: "기본 회전 방향",
                helpContent:
                    "도면을 그릴 때 기본으로 적용될 파이프의 회전 방향입니다. CW(시계방향) 또는 CCW(반시계)를 설정합니다.",
                value: _defaultRotation,
                items: const ["CW (시계방향)", "CCW (반시계)"],
                onChanged: (val) => setState(() => _defaultRotation = val!),
                helperText: "※ 도면 기준 방향",
              ),
            ]),
            const SizedBox(height: 12),
            _stackedFields([
              _buildNumpadInputWithHelp(
                "피팅 삽입 깊이 [mm]",
                "피팅 삽입 깊이 (Insertion Depth)",
                "파이프 끝이 피팅(부속) 안으로 완전히 삽입되어야 하는 길이입니다.\n이 값을 정확히 입력해야 벤딩 후 피팅을 조립했을 때 전체 기장(C-C)이 짧아지는 불량(누설)을 막을 수 있습니다.\n[AUTO] 모드 시 규격에 맞춰 자동 입력됩니다.",
                _fittingDepthController,
                key: 'fittingDepth',
                helperText: "※ 전체 체결 기준",
              ),
              _isElectric
                  ? const SizedBox.shrink()
                  : _buildDropdownWithAdvancedHelper(
                      label: "마커 정렬",
                      helpTitle: "마커 정렬 기준",
                      helpContent:
                          "벤더기에 파이프를 고정할 때, 그은 선(마킹)을 어디에 맞출지 결정합니다.\n보통 0(기본/Center)을 기준으로 맞춥니다.",
                      value: _benderMark,
                      items: const [
                        "0 (기본/다양한 각도)",
                        "L (90도 정방향)",
                        "R (90도 역방향)",
                      ],
                      onChanged: (val) => setState(() => _benderMark = val!),
                      helperText: "• 0: 기본\n• L/R: 90도 전용",
                    ),
            ]),
          ],
        ),
      ),
      SettingSection(
        title: "3. 벤더 장비 제원",
        icon: Icons.build,
        child: Column(
          children: [
            _stackedFields([
              _buildDropdownWithAdvancedHelper(
                label: "벤더 브랜드",
                helpTitle: "벤더 브랜드",
                helpContent:
                    "사용 중인 벤더 기기의 브랜드입니다.\n브랜드마다 기계의 크기와 반경(Radius)이 다르기 때문에, 이를 선택하면 [AUTO] 모드에서 자동으로 맞는 값을 불러옵니다.",
                value: _benderBrand,
                items: const [
                  "Swagelok",
                  "Hy-Lok",
                  "Parker",
                  "Ridgid",
                  "TRACTO-TECHNIK",
                  "Other",
                ],
                onChanged: (val) {
                  setState(() => _benderBrand = val!);
                  _onSpecsChanged();
                },
                helperText: "※ 브랜드별 가이드",
              ),
              _buildDropdownWithAdvancedHelper(
                label: "장비 타입 선택",
                helpTitle: "장비 타입 (수동/전동)",
                helpContent:
                    "손으로 꺾는 수동(Hand) 벤더인지, 기계가 꺾어주는 전동(Electric) 벤더인지 선택합니다.\n타입에 따라 연신율이나 입력 기준이 달라집니다.",
                value: _benderType,
                items: const ["수동 (Hand)", "전동 (Electric)"],
                onChanged: (val) {
                  setState(() => _benderType = val!);
                  _onSpecsChanged();
                },
                helperText: "※ 수동/전동 가이드",
              ),
            ]),
            const SizedBox(height: 16),
            if (_isElectric) ...[
              _stackedFields([
                _buildNumpadInputWithHelp(
                  "금형 반경 (CLR) [mm]",
                  "금형 반경 (Center Line Radius)",
                  "파이프를 둥글게 꺾어주는 다이(금형)의 중심 반경입니다.\n이 값이 클수록 파이프가 완만하게 꺾이고, 연신율(늘어나는 길이) 계산의 핵심이 됩니다.",
                  _rController,
                  key: 'radius',
                  helperText: "※ 다이 R값",
                ),
                _buildNumpadInputWithHelp(
                  "클램프 물림 길이 [mm]",
                  "클램프 물림 길이 (최소 직선 구간)",
                  "전동 벤더가 파이프를 단단히 잡고 꺾기 위해 필요한 최소한의 직관(일자) 길이입니다.\n이 길이보다 짧게 벤딩을 시도하면 기계에 물리지 않아 작업이 불가능합니다.",
                  _minStraightController,
                  key: 'minStraight',
                  helperText: "※ 최소 구간",
                ),
              ]),
              const SizedBox(height: 12),
              _stackedFields([
                _buildNumpadInputWithHelp(
                  "연신율 (Gain) [mm]",
                  "연신율 (Gain)",
                  "파이프가 곡선으로 꺾이면서 바깥쪽으로 늘어나는 총 길이입니다.\n전체 자를 길이를 이 값만큼 빼주어야 치수 불량이 안 납니다.\n[AUTO] 시 기계 제원 기반으로 계산됩니다.",
                  _gainController,
                  key: 'gain',
                  helperText: "※ 늘어나는 양",
                ),
                _buildNumpadInputWithHelp(
                  "스프링백 보상 [°]",
                  "스프링백 보상 (Springback)",
                  "파이프를 90도로 꺾어도 금속의 탄성 때문에 원래대로 살짝 튕겨 돌아옵니다.\nSUS 파이프 기준 보통 1~3도 정도를 더 꺾어주도록 보정하는 값입니다.",
                  _springbackController,
                  helperText: "※ 보통 1~3° 입력",
                ),
              ]),
              const SizedBox(height: 12),
              _stackedFields([
                _buildNumpadInputWithHelp(
                  "장비 원점 오프셋 [mm]",
                  "장비 원점 오프셋",
                  "기계의 클램프 끝에서 실제 벤딩이 시작되는 0점까지의 물리적인 거리 오차입니다.",
                  _benderOffsetController,
                  key: 'offset',
                  helperText: "※ 클램프 끝 ~ 다이 0점",
                ),
              ]),
            ] else ...[
              _stackedFields([
                _buildNumpadInputWithHelp(
                  "벤드 반경 (R) [mm]",
                  "벤드 반경 (Radius)",
                  "수동 벤더 다이(둥근 롤러)의 중심에서 파이프 중심선까지의 반경입니다.\n이 값으로 연신율과 축소량을 계산합니다.",
                  _rController,
                  key: 'radius',
                  helperText: "※ 다이 중심 ~ 튜브 중심",
                ),
                _buildNumpadInputWithHelp(
                  "테이크업 [mm]",
                  "테이크업 (Take-Up)",
                  "수동 벤딩 시 90도로 꺾을 때 뒤로 후진해야 하는 거리(보정치)입니다.\n이 치수만큼 빼고 마킹해야 정확한 위치에서 꺾입니다.",
                  _takeUpController,
                  key: 'takeUp',
                  helperText: "※ 차감 보정치",
                ),
              ]),
              const SizedBox(height: 12),
              _stackedFields([
                _buildNumpadInputWithHelp(
                  "연신율 (Gain) [mm]",
                  "연신율 (Gain)",
                  "파이프가 곡선으로 꺾이면서 바깥쪽으로 늘어나는 총 길이입니다.\n전체 자를 길이를 이 값만큼 빼주어야 치수 불량이 안 납니다.\n[AUTO] 시 기계 제원 기반으로 자동 계산됩니다.",
                  _gainController,
                  key: 'gain',
                  helperText: "※ 늘어나는 총 길이",
                ),
                _buildNumpadInputWithHelp(
                  "최소 직선 구간 [mm]",
                  "최소 물림 구간 (Minimum Straight)",
                  "벤더기의 후크(고리)가 파이프를 단단히 물어주기 위해 확보되어야 하는 최소한의 직관 길이입니다.\n연속 벤딩 시 이 길이보다 짧으면 기계에 파이프가 걸려 안 꺾입니다.",
                  _minStraightController,
                  key: 'minStraight',
                  helperText: "※ 벤더 후크 물림 최소장",
                ),
              ]),
              const SizedBox(height: 12),
              _stackedFields([
                _buildNumpadInputWithHelp(
                  "기준선 오프셋 [mm]",
                  "기준선 오프셋",
                  "기계의 0점 마크와 파이프에 그은 선이 완벽히 일치하지 않는 기계적/물리적 오차를 교정하는 값입니다.",
                  _benderOffsetController,
                  key: 'offset',
                  helperText: "※ 다이 0점과 실제 시작점",
                ),
                _buildNumpadInputWithHelp(
                  "스프링백 [°]",
                  "스프링백 보상 (Springback)",
                  "파이프를 원하는 각도만큼 꺾어도 탄성으로 다시 펴지는 성질을 보상하는 각도입니다.",
                  _springbackController,
                  helperText: "※ 탄성 복원 각도 보정치",
                ),
              ]),
            ],
          ],
        ),
      ),
      SettingSection(
        title: "4. 오차 보정 및 앱 설정",
        icon: Icons.settings_suggest,
        child: Column(
          children: [
            if (!_isElectric) ...[
              _stackedFields([
                _buildNumpadInputWithHelp(
                  "마킹선 두께 [mm]",
                  "마킹선 두께 보정",
                  "네임펜이나 마커로 파이프에 선을 그을 때, 선의 두께(약 1~2mm) 때문에 생기는 미세 오차를 보정합니다.",
                  _markThicknessController,
                  helperText: "※ 마커 펜촉 미세 보정",
                ),
                _buildNumpadInputWithHelp(
                  "오프셋 축소 [mm]",
                  "오프셋 축소 (간섭 회피 여유)",
                  "연속 S자 벤딩(오프셋)을 할 때, 파이프를 반대로 뒤집어 기계에 넣으면 기존에 꺾인 부위가 기계 몸통(바디/슈)에 닿아 안 들어가는 경우가 생깁니다.\n이를 피하기 위해 빗변 기장을 강제로 살짝 밀어주는 여유 길이입니다.",
                  _offsetShrinkController,
                  helperText: "※ 간섭 회피용 여유 축소값",
                ),
              ]),
              const Divider(color: Colors.black12, height: 24),
            ],
            _stackedFields([
              _buildNumpadInputWithHelp(
                "톱날 손실(커프) [mm]",
                "톱날 손실(커프) 보정",
                "쇠톱이나 절단기로 파이프를 자를 때 톱날 두께만큼 소재가 갈려 없어집니다.\n원자재에서 여러 구간을 잘라 쓸 때 이만큼을 더 확보해두어야 마지막 구간 길이가 부족해지지 않습니다.",
                _cutMarginController,
                helperText: "※ 절단면당 손실량",
              ),
            ]),
            const Divider(color: Colors.black12, height: 24),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 🚀 [수정] _buildLabelWithHelp는 내부에 Flexible을 안 쓰므로
                  // (unbounded Row에서 크래시 방지), 이 자리처럼 폭을
                  // 줄여야 할 필요가 있으면 호출부에서 Expanded로 감싼다.
                  Expanded(
                    child: _buildLabelWithHelp(
                      context,
                      "물림 길이(간섭) 경고",
                      "물림 길이 경고 (초보자 권장)",
                      "파이프 길이가 기계의 '최소 물림 구간'보다 짧게 입력되면 경고창을 띄워 불량을 막아줍니다.\n\n"
                          "경고창이 귀찮거나, 편법으로 아슬아슬하게 물려서 벤딩을 진행하는 숙련자(고인물)는 이 스위치를 끄고 쾌속으로 작업할 수 있습니다.",
                    ),
                  ),
                  Switch(
                    value: _warnShoeInterference,
                    onChanged: (val) =>
                        setState(() => _warnShoeInterference = val),
                    activeThumbColor: Colors.white,
                    activeTrackColor: makitaTeal,
                  ),
                ],
              ),
            ),
            _buildSwitchRow(
              "진동 피드백 (Haptic)",
              _useHaptic,
              (val) => setState(() => _useHaptic = val),
            ),
            _buildSwitchRow(
              "기록 자동 저장 (History)",
              _saveHistory,
              (val) => setState(() => _saveHistory = val),
            ),
            // 🚀 [수정] 토글 즉시 AppSettingsController를 통해서만 wakelock을
            // 적용한다 (다른 화면이 제멋대로 enable()을 부르지 않으므로,
            // 여기서 끄면 계산기 화면에 들어가도 다시 켜지지 않는다).
            _buildSwitchRow("화면 꺼짐 방지", _keepScreenOn, (val) {
              setState(() => _keepScreenOn = val);
              AppSettingsController().setKeepScreenOn(val);
            }),
          ],
        ),
      ),
    ];
  }

  // 가이드 패널
  List<Widget> _buildRightGuideGroup() {
    return [
      if (_isElectric)
        _buildElectricUnifiedGuide()
      else
        _buildManualUnifiedGuide(),
      _buildHoneyJarReferenceCard(),
    ];
  }

  Widget _buildElectricUnifiedGuide() {
    bool isSwagelok = _benderBrand == "Swagelok";
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.precision_manufacturing,
                color: Colors.orange.shade800,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                isSwagelok
                    ? "Swagelok 전동기 가이드 (MS-BTB)"
                    : "TRACTO-TECHNIK 전동기 가이드 (TB20D)",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isSwagelok) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _machineSpecText("모델명 (Type)", "Swagelok MS-BTB Series"),
                  _machineSpecText("적용 규격", "1/2\" ~ 1-1/4\" (주력: 3/4\", 1\")"),
                  _machineSpecText("구동 방식", "전자식 제어 펜던트 & 모터 구동"),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "🔧 제어반(Pendant) 조작 매뉴얼",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            _guideText(
              "1. 툴링 세팅",
              "관경(3/4\" 또는 1\")에 맞는 벤드 슈(Bend Shoe)와 롤러 서포트(Roller Support)를 장착합니다.",
            ),
            _guideText(
              "2. 기기 초기화",
              "전원 스위치를 켜고 펜던트의 [RETURN] 버튼을 눌러 벤드 슈를 0° 원점 위치로 복귀시킵니다.",
            ),
            _guideText(
              "3. 각도/스프링백",
              "펜던트의 [ANGLE] 버튼을 눌러 목표 각도를, [SPRINGBACK] 버튼을 눌러 탄성 보정값(SUS 통상 1.5°~3.0°)을 입력합니다.",
            ),
            _guideText(
              "4. 파이프 고정",
              "파이프를 삽입하고 토글 클램프(Toggle Clamp) 레버를 끝까지 밀어 고정시킵니다.",
            ),
            _guideText(
              "5. 벤딩 실행",
              "펜던트의 [BEND] 버튼을 누르고 있으면 벤딩이 진행됩니다. 벤딩 후 [RETURN]을 눌러 원위치시킵니다.",
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "알루미늄 가이드 롤러에 'Swagelok 전용 윤활유'를 반드시 도포하십시오. 미도포 시 대구경 튜브 찌그러짐(Ovality)이 발생합니다.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "📊 대구경 집중 권장 제원표 (SUS 기준)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                },
                border: TableBorder.symmetric(
                  inside: BorderSide(color: Colors.grey.shade200),
                ),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          "규격 (OD)",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          "표준 R (CLR)",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          "연신율",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          "최소물림",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildGuideRow4Col(
                    "1/2\" (12.7)",
                    "R 38.1 (1.5\")",
                    "약 16.5",
                    "65 mm",
                  ),
                  _buildGuideRow4Col(
                    "3/4\" (19.05)",
                    "R 76.2 (3.0\")",
                    "약 32.5",
                    "85 mm",
                    isHighlight: true,
                  ),
                  _buildGuideRow4Col(
                    "1\" (25.4)",
                    "R 101.6 (4.0\")",
                    "약 43.5",
                    "110 mm",
                    isHighlight: true,
                  ),
                  _buildGuideRow4Col(
                    "1-1/4\" (31.75)",
                    "R 127.0 (5.0\")",
                    "약 55.0",
                    "130 mm",
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _machineSpecText("모델명 (Type)", "TUBOBEND TB20D"),
                  _machineSpecText("일련번호 (Serial)", "286"),
                  _machineSpecText("제작 연도 (Year)", "2020년"),
                  _machineSpecText(
                    "제조사 (Maker)",
                    "TRACTO-TECHNIK GmbH & Co.KG (독일)",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "🔧 제어반(HMI) 조작 매뉴얼",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            _guideText(
              "1. 기기 초기화",
              "전원(Main Switch) 인가 후, 터치패널에서 [HOME] 또는 [RESET] 버튼을 눌러 C축(벤딩 암)을 0° 원점으로 복귀시킵니다.",
            ),
            _guideText(
              "2. 프로그램 입력",
              "화면의 [PROG] 버튼을 눌러 빈 슬롯을 선택합니다.\n• [ANGLE] 칸에 앱에서 계산된 각도를 입력합니다.\n• [SPRINGBACK] 칸에 재질별 탄성 보정값을 입력하고 [ENTER]로 저장합니다.",
            ),
            _guideText(
              "3. 클램핑 조작",
              "다이(Die)에 파이프를 삽입하여 최소 물림 길이 이상 확보한 뒤, 제어반의 [CLAMP] 버튼을 눌러 파이프 고정합니다.",
            ),
            _guideText(
              "4. 벤딩 실행",
              "[MANUAL] 또는 [AUTO] 모드 선택 후, 풋스위치를 끝까지 밟아 벤딩을 실행합니다. 종료 후 [OPEN]을 눌러 파이프를 분리합니다.",
            ),
            const SizedBox(height: 16),
            const Text(
              "📊 규격별 권장 연신율 표 (SUS 기준)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                },
                border: TableBorder.symmetric(
                  inside: BorderSide(color: Colors.grey.shade200),
                ),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          "규격(OD)",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          "표준 금형(CLR)",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          "권장 연신율",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildGuideRow3Col(
                    "1/4\" (6.35)",
                    "R15.0",
                    "7.0 ~ 8.0",
                    Colors.orange.shade900,
                  ),
                  _buildGuideRow3Col(
                    "3/8\" (9.52)",
                    "R22.5",
                    "11.0 ~ 12.5",
                    Colors.orange.shade900,
                  ),
                  _buildGuideRow3Col(
                    "1/2\" (12.7)",
                    "R35.0",
                    "18.0 ~ 20.0",
                    Colors.orange.shade900,
                  ),
                  _buildGuideRow3Col(
                    "25mm",
                    "R75.0",
                    "38.0 ~ 42.0",
                    Colors.orange.shade900,
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 40, color: Colors.black12, thickness: 1),
          Row(
            children: [
              Icon(Icons.calculate, color: Colors.blueGrey.shade800, size: 20),
              const SizedBox(width: 8),
              Text(
                "📐 연신율(Gain) 산출 공식 및 실무 적용",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Colors.blueGrey.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                const Text(
                  "이론상 90° 연신율 공식 (Centerline 기준)",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Gain = (2 × R) - (1.57 × R) = 0.43 × R",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.blueGrey.shade800,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "⚠️ 위 공식은 '관의 중심선'을 기준으로 한 제조사 이론값입니다. 실제 벤딩 시에는 파이프의 외경(OD)과 두께(WT)에 의해 중립축이 안쪽으로 이동하므로, 파이프가 더 길게 늘어납니다. 반드시 시편을 꺾어 실제 기장을 측정한 뒤 [MAN(수동)] 모드에 실측값을 입력하십시오.",
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Divider(height: 40, color: Colors.black12, thickness: 1),
          Row(
            children: [
              Icon(Icons.call_split, color: Colors.orange.shade800, size: 20),
              const SizedBox(width: 8),
              Text(
                "공통 오프셋 (Offset) 벤딩 배수표",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(1.2),
              },
              border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "벤딩 각도",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "마킹 배수 (×)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF007580),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "축소량 (×)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                _buildOffsetRow("15°", "3.86", "0.13", Colors.orange.shade900),
                _buildOffsetRow(
                  "22.5°",
                  "2.61",
                  "0.20",
                  Colors.orange.shade900,
                ),
                _buildOffsetRow("30°", "2.00", "0.27", Colors.orange.shade900),
                _buildOffsetRow("45°", "1.41", "0.41", Colors.orange.shade900),
                _buildOffsetRow("60°", "1.15", "0.58", Colors.orange.shade900),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "※ 마킹 간격(빗변) = 오프셋 높이 × 마킹 배수\n※ 기장 추가분 = 오프셋 높이 × 축소량",
            style: TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualUnifiedGuide() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: makitaTeal.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: makitaTeal.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.construction, color: makitaTeal, size: 28),
              SizedBox(width: 8),
              Text(
                "수동 벤더 실무 조작 가이드",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: makitaTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _guideText("1. 적용 규격", "[Inch] 1/4\" ~ 1\"  /  [mm] 8mm ~ 25mm"),
          _guideText(
            "2. 테이크업 (Take-Up)",
            "가상 센터라인 기준이 아닌, 튜브 두께(WT)를 적용하여 보정해야 정확한 치수가 나옵니다.",
          ),
          _guideText(
            "3. 연신율 (Gain)",
            "90도 벤딩 시 늘어나는 총 길이입니다. 마킹 시 이 값을 고려해야 합니다.",
          ),
          const Divider(height: 32, color: Colors.black12),
          const Text(
            "📊 규격별 권장 연신율 표",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1.2),
              },
              border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "규격 (OD)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "연신율 (Gain)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: makitaTeal,
                        ),
                      ),
                    ),
                  ],
                ),
                _buildGuideRow2Col(
                  "1/4\" (6.35mm)",
                  "approx. 8.5 mm",
                  makitaTeal,
                ),
                _buildGuideRow2Col(
                  "3/8\" (9.52mm)",
                  "approx. 12.5 mm",
                  makitaTeal,
                ),
                _buildGuideRow2Col(
                  "1/2\" (12.7mm)",
                  "approx. 20.0 mm",
                  makitaTeal,
                ),
                _buildGuideRow2Col(
                  "3/4\" (19.05mm)",
                  "approx. 28.5 mm",
                  makitaTeal,
                ),
                _buildGuideRow2Col(
                  "1\" (25.4mm)",
                  "approx. 38.0 mm",
                  makitaTeal,
                ),
              ],
            ),
          ),
          const Divider(height: 32, color: Colors.black12),
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                "측정 기준 안내 및 보정표",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "본 계산기는 C-to-C(가상 센터라인) 전용입니다.\n도면이 끝단(Face) 또는 바깥쪽(Back) 기준이라면, 아래의 보정 참조표(OD/2)를 보고 치수를 직접 가감하여 입력하십시오.",
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1.2),
              },
              border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "규격 (OD)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "측정 보정값 (OD/2)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                _buildGuideRow2Col(
                  "1/4\" (6.35mm)",
                  "3.17 mm",
                  Colors.redAccent,
                ),
                _buildGuideRow2Col(
                  "3/8\" (9.52mm)",
                  "4.76 mm",
                  Colors.redAccent,
                ),
                _buildGuideRow2Col(
                  "1/2\" (12.7mm)",
                  "6.35 mm",
                  Colors.redAccent,
                ),
                _buildGuideRow2Col(
                  "3/4\" (19.05mm)",
                  "9.52 mm",
                  Colors.redAccent,
                ),
                _buildGuideRow2Col("1\" (25.4mm)", "12.7 mm", Colors.redAccent),
              ],
            ),
          ),
          const Divider(height: 32, color: Colors.black12),
          const Row(
            children: [
              Icon(Icons.call_split, color: makitaTeal, size: 20),
              SizedBox(width: 8),
              Text(
                "오프셋 (Offset) 벤딩 계산표",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: makitaTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "장애물 회피 벤딩 시, 두 번째 마킹 위치(빗변)와 총 기장 축소량을 계산하기 위한 곱셈 배수입니다.",
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(1.2),
              },
              border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "벤딩 각도",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "마킹 배수 (×)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF007580),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "축소량 (×)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                _buildOffsetRow("15°", "3.86", "0.13", makitaTeal),
                _buildOffsetRow("22.5°", "2.61", "0.20", makitaTeal),
                _buildOffsetRow("30°", "2.00", "0.27", makitaTeal),
                _buildOffsetRow("45°", "1.41", "0.41", makitaTeal),
                _buildOffsetRow("60°", "1.15", "0.58", makitaTeal),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "※ 마킹 간격(빗변) = 오프셋 높이 × 마킹 배수\n※ 기장 추가분 = 오프셋 높이 × 축소량",
            style: TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoneyJarReferenceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book_rounded,
                color: Colors.blueGrey.shade800,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                "배관 실무 꿀단지 참고표",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Colors.blueGrey.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "🍯 1. 180° U-벤딩 (Return Bend)",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "180도 연속 벤딩 시 90도 연신율의 2배보다 파이프가 더 늘어납니다. (재단 시 더 많이 잘라야 함)",
            style: TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1.2),
                3: FlexColumnWidth(1.2),
              },
              border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "OD",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "표준 R",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "최소 간격(C-C)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "180° 연신율",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                _buildGuideRow4Col(
                  "1/4\"",
                  "R14.2",
                  "28.4 mm",
                  "약 19 mm",
                  textColor4: Colors.redAccent,
                ),
                _buildGuideRow4Col(
                  "3/8\"",
                  "R23.8",
                  "47.6 mm",
                  "약 30 mm",
                  textColor4: Colors.redAccent,
                ),
                _buildGuideRow4Col(
                  "1/2\"",
                  "R38.1",
                  "76.2 mm",
                  "약 49 mm",
                  textColor4: Colors.redAccent,
                ),
                _buildGuideRow4Col(
                  "3/4\"",
                  "R76.2",
                  "152.4 mm",
                  "약 98 mm",
                  textColor4: Colors.redAccent,
                ),
              ],
            ),
          ),
          const Divider(height: 32, color: Colors.black12),
          const Text(
            "🍯 2. 튜브 삽입 깊이 (Insertion Depth)",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Twin Ferrule 피팅 체결 시 튜브가 부속 안으로 들어가는 깊이. (총 기장 계산 시 양쪽 삽입 깊이를 더해야 함)",
            style: TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1.2),
              },
              border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "규격 (OD)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "삽입 깊이 (더함)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Color(0xFF007580),
                        ),
                      ),
                    ),
                  ],
                ),
                _buildGuideRow2Col(
                  "1/4\" (6.35)",
                  "15.2 mm",
                  const Color(0xFF007580),
                ),
                _buildGuideRow2Col(
                  "3/8\" (9.52)",
                  "16.8 mm",
                  const Color(0xFF007580),
                ),
                _buildGuideRow2Col(
                  "1/2\" (12.7)",
                  "22.9 mm",
                  const Color(0xFF007580),
                ),
                _buildGuideRow2Col(
                  "3/4\" (19.05)",
                  "24.4 mm",
                  const Color(0xFF007580),
                ),
                _buildGuideRow2Col(
                  "1\" (25.4)",
                  "31.2 mm",
                  const Color(0xFF007580),
                ),
              ],
            ),
          ),
          const Divider(height: 32, color: Colors.black12),
          const Text(
            "🍯 3. NPT 나사산 체결 깊이 (Engagement)",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "나사 조립 시 피팅이 암나사 안으로 먹어 들어가는 길이. (총 기장 산출 시 이 값을 빼주어야 정확함)",
            style: TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1.2),
              },
              border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "나사 규격",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "체결 깊이 (차감)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ),
                  ],
                ),
                _buildGuideRow2Col("1/4\" NPT", "약 10.0 mm", Colors.deepOrange),
                _buildGuideRow2Col("3/8\" NPT", "약 10.5 mm", Colors.deepOrange),
                _buildGuideRow2Col("1/2\" NPT", "약 13.5 mm", Colors.deepOrange),
                _buildGuideRow2Col("3/4\" NPT", "약 14.0 mm", Colors.deepOrange),
                _buildGuideRow2Col("1\" NPT", "약 17.5 mm", Colors.deepOrange),
              ],
            ),
          ),
          const Divider(height: 32, color: Colors.black12),
          const Text(
            "🍯 4. 인치 분수 ↔ mm 환산표",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1.2),
              },
              border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "분수 (Inch)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "소수점 (Inch)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "mm 환산",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Color(0xFF37474F),
                        ),
                      ),
                    ),
                  ],
                ),
                _buildGuideRow3Col(
                  "1/8\"",
                  "0.125",
                  "3.17 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow3Col(
                  "1/4\"",
                  "0.250",
                  "6.35 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow3Col(
                  "3/8\"",
                  "0.375",
                  "9.52 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow3Col(
                  "1/2\"",
                  "0.500",
                  "12.70 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow3Col(
                  "5/8\"",
                  "0.625",
                  "15.87 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow3Col(
                  "3/4\"",
                  "0.750",
                  "19.05 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow3Col(
                  "7/8\"",
                  "0.875",
                  "22.22 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow3Col(
                  "1\"",
                  "1.000",
                  "25.40 mm",
                  Colors.blueGrey.shade800,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 🚀 2. MakitaNumericInput 위젯 (분리 유지)
// ==========================================
class MakitaNumericInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? helperText;
  final bool? isAutoMode;
  final ValueChanged<bool>? onModeChanged;
  final VoidCallback onTap;

  const MakitaNumericInput({
    super.key,
    required this.label,
    required this.controller,
    this.helperText,
    this.isAutoMode,
    this.onModeChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool readOnly = isAutoMode == true;
    Color getBgColor() {
      if (readOnly) return Colors.grey.shade200;
      if (isAutoMode != null && !isAutoMode!) return Colors.orange.shade50;
      return Colors.white;
    }

    // 🚀 [수정] AUTO/MAN 버튼이 항상 고정 34px라 큰 화면(태블릿, 가로모드)
    // 에서는 답답하게 작아 보였음. 화면 폭 비율로 계산하되, 폴더블 커버
    // 화면처럼 아주 좁은 화면에서 오버플로우 나지 않을 최소값(34)과
    // 너무 커지지 않을 최대값(64) 사이로 clamp한다.
    final double screenWidth = MediaQuery.of(context).size.width;
    final double autoButtonWidth = (screenWidth * 0.11).clamp(34.0, 64.0);
    final double fieldVerticalPadding = (screenWidth * 0.032).clamp(
      10.0,
      16.0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: readOnly ? null : onTap,
                child: AbsorbPointer(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: fieldVerticalPadding,
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: (isAutoMode != null && !isAutoMode!)
                              ? Colors.orange.shade300
                              : Colors.grey.shade400,
                        ),
                      ),
                      filled: true,
                      fillColor: getBgColor(),
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: readOnly ? Colors.black54 : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
            if (isAutoMode != null && onModeChanged != null) ...[
              const SizedBox(width: 4),
              // 🚀 [수정] 폴더블(갤럭시 Z 폴드) 커버 화면처럼 폭이 매우 좁은
              // 기기(약 344dp)에서 이 버튼 때문에 Row 전체가 "RIGHT
              // OVERFLOWED"를 냈음. 폭을 화면 비율로 계산해서 clamp하고
              // FittedBox로 글자를 그 안에 맞춰서, 어떤 화면에서도 안
              // 넘치면서 화면 크기에 비례해 보이게 한다.
              InkWell(
                onTap: () => onModeChanged!(!isAutoMode!),
                child: Container(
                  width: autoButtonWidth,
                  padding: EdgeInsets.symmetric(vertical: fieldVerticalPadding),
                  decoration: BoxDecoration(
                    color: isAutoMode! ? makitaTeal : Colors.deepOrange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isAutoMode! ? "AUTO" : "MAN",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
