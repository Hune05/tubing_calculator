import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/utils/settings_manager.dart';
import 'package:tubing_calculator/src/presentation/settings/controllers/settings_controller.dart';
import 'package:tubing_calculator/src/presentation/settings/widgets/settings_widgets.dart';
import 'package:tubing_calculator/src/core/utils/fitting_data.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad.dart';

const Color makitaTeal = Color(0xFF007580);
const Color toolGripBlack = Color(0xFF222222);
const Color hardwareButtonTeal = Color(0xFF005C63);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // --- 상태 변수 ---
  bool _isInch = false;
  bool _useHaptic = true;
  bool _saveHistory = true;

  String _tubeMaterial = "SUS";
  String _benderBrand = "Swagelok";

  String _currentOD = "";

  // 🚀 측정 기준은 이제 C-to-C로 영구 고정됩니다.
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

  String get _unit => _isInch ? "inch" : "mm";
  List<String> get _odList => SettingsController.getOdList(_isInch);

  @override
  void initState() {
    super.initState();
    _currentOD = _odList.contains("12.7") ? "12.7" : _odList.first;
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await SettingsManager.loadSettings();
    setState(() {
      _isInch = data['isInch'] ?? false;
      _useHaptic = data['useHaptic'] ?? true;
      _saveHistory = data['saveHistory'] ?? true;
      _tubeMaterial = data['tubeMaterial'] ?? "SUS";
      _benderBrand = data['benderBrand'] ?? "Swagelok";

      // 🚀 로드할 때도 강제로 C-to-C를 유지합니다.
      // _measurementMode = data['measurementMode'] ?? "C-to-C";
      _defaultRotation = data['defaultRotation'] ?? "CW (시계방향)";
      _fittingType = data['fittingType'] ?? "Twin Ferrule";
      _benderMark = data['benderMark'] ?? "0 (기본/다양한 각도)";

      String loadedOD = (data['tubeOD'] ?? (_isInch ? 0.5 : 12.7)).toString();
      if (!loadedOD.contains('.')) {
        loadedOD += ".0";
      }
      _currentOD = _odList.contains(loadedOD) ? loadedOD : _odList.first;

      _autoStates['radius'] = data['auto_radius'] ?? true;
      _autoStates['takeUp'] = data['auto_takeUp'] ?? true;
      _autoStates['gain'] = data['auto_gain'] ?? true;
      _autoStates['minStraight'] = data['auto_minStraight'] ?? true;
      _autoStates['offset'] = data['auto_offset'] ?? true;
      _autoStates['fittingDepth'] = data['auto_fittingDepth'] ?? true;

      _wtController.text = (data['tubeWT'] ?? 0.0).toString();
      _springbackController.text = (data['springback'] ?? 0.0).toString();
      _markThicknessController.text = (data['markThickness'] ?? 0.0).toString();
      _offsetShrinkController.text = (data['offsetShrink'] ?? 0.0).toString();

      if (_autoStates['radius'] == false) {
        _rController.text = (data['bendRadius'] ?? 0.0).toString();
      }
      if (_autoStates['takeUp'] == false) {
        _takeUpController.text = (data['takeUp'] ?? 0.0).toString();
      }
      if (_autoStates['gain'] == false) {
        _gainController.text = (data['gain'] ?? 0.0).toString();
      }
      if (_autoStates['minStraight'] == false) {
        _minStraightController.text = (data['minStraight'] ?? 0.0).toString();
      }
      if (_autoStates['offset'] == false) {
        _benderOffsetController.text = (data['benderOffset'] ?? 0.0).toString();
      }
      if (_autoStates['fittingDepth'] == false) {
        _fittingDepthController.text = (data['fittingDepth'] ?? 0.0).toString();
      }
    });

    _onSpecsChanged(isInitialLoad: true);
  }

  Future<void> _saveData() async {
    FocusScope.of(context).unfocus();

    await SettingsManager.saveSettings(
      isInch: _isInch,
      useHaptic: _useHaptic,
      saveHistory: _saveHistory,
      tubeMaterial: _tubeMaterial,
      benderBrand: _benderBrand,
      measurementMode: _measurementMode, // 항상 C-to-C 저장
      defaultRotation: _defaultRotation,
      fittingType: _fittingType,
      benderMark: _benderMark,
      tubeOD: double.tryParse(_currentOD) ?? 0.0,
      tubeWT: double.tryParse(_wtController.text) ?? 0.0,
      bendRadius: double.tryParse(_rController.text) ?? 0.0,
      takeUp: double.tryParse(_takeUpController.text) ?? 0.0,
      springback: double.tryParse(_springbackController.text) ?? 0.0,
      gain: double.tryParse(_gainController.text) ?? 0.0,
      minStraight: double.tryParse(_minStraightController.text) ?? 0.0,
      benderOffset: double.tryParse(_benderOffsetController.text) ?? 0.0,
      fittingDepth: double.tryParse(_fittingDepthController.text) ?? 0.0,
      markThickness: double.tryParse(_markThicknessController.text) ?? 0.0,
      offsetShrink: double.tryParse(_offsetShrinkController.text) ?? 0.0,
      cutMargin: 0.0,
      autoRadius: _autoStates['radius'] ?? true,
      autoTakeUp: _autoStates['takeUp'] ?? true,
      autoGain: _autoStates['gain'] ?? true,
      autoMinStraight: _autoStates['minStraight'] ?? true,
      autoOffset: _autoStates['offset'] ?? true,
      autoFittingDepth: _autoStates['fittingDepth'] ?? true,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "설정이 안전하게 저장되었습니다.",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: makitaTeal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      );
    }
  }

  void _onSpecsChanged({bool isInitialLoad = false}) {
    final specs = SettingsController.getStandardSpecs(_benderBrand, _currentOD);

    setState(() {
      if (specs != null) {
        if (_autoStates['radius'] == true) {
          _rController.text = specs.bendRadius.toString();
        }
        if (_autoStates['takeUp'] == true) {
          _takeUpController.text = specs.takeUp.toString();
        }
        if (_autoStates['gain'] == true) {
          _gainController.text = specs.gain.toString();
        }
        if (_autoStates['minStraight'] == true) {
          _minStraightController.text = specs.minStraight.toString();
        }
        if (_autoStates['offset'] == true) {
          _benderOffsetController.text = specs.benderOffset.toString();
        }
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
    super.dispose();
  }

  Widget _buildDropdownWithHelper({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String Function(String)? displayMapper,
    required String helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingDropdownField(
          label: label,
          value: value,
          items: items,
          onChanged: onChanged,
          displayMapper: displayMapper,
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

  // 🚀 [추가] 선택 불가한 "측정 기준 락(Lock)" UI
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
                      "C-to-C (Center Line) 고정",
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
        const SizedBox(height: 6),
        const Text(
          "※ 모든 계산은 중심선 기준입니다.\n끝단 측정 시 우측 보정표(OD/2) 참조",
          style: TextStyle(
            fontSize: 11,
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildNumpadInput(
    String label,
    TextEditingController controller, {
    String? key,
    String? helperText,
  }) {
    return MakitaNumericInput(
      label: label,
      controller: controller,
      helperText: helperText,
      isAutoMode: key != null ? _autoStates[key] : null,
      onModeChanged: key != null
          ? (isAuto) {
              setState(() {
                _autoStates[key] = isAuto;
              });
              if (isAuto) _onSpecsChanged();
            }
          : null,
      onTap: () {
        if (key == null || _autoStates[key] != true) {
          MakitaNumpad.show(context, controller: controller, title: label);
        }
      },
    );
  }

  // 🚀 [완전 개편] 현장 실무 가이드 (연신율 도표 + OD/2 보정 참조표 병합)
  Widget _buildFieldGuideTip() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: makitaTeal.withValues(alpha: 0.05),
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
              Icon(Icons.construction, color: makitaTeal, size: 22),
              SizedBox(width: 8),
              Text(
                "현장 실무 수동 입력 가이드 (Swagelok)",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: makitaTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "• 적용 규격: [Inch] 1/4\" ~ 1\"  /  [mm] 8mm ~ 25mm\n"
            "• 테이크업 (Take-Up): 센터라인 기준이 아닌, 튜브 두께(WT)를 적용하여 보정하세요.",
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Colors.blueGrey[800],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          // 기존 연신율 실측 도표
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
                  decoration: BoxDecoration(color: Colors.grey.shade50),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "규격 (OD)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "연신율 (Gain)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: makitaTeal,
                        ),
                      ),
                    ),
                  ],
                ),
                _buildTableRow("1/4\" (6.35mm)", "approx. 8.5 mm"),
                _buildTableRow("3/8\" (9.52mm)", "approx. 12.5 mm"),
                _buildTableRow("1/2\" (12.7mm)", "approx. 20.0 mm"),
                _buildTableRow("3/4\" (19.05mm)", "approx. 28.5 mm"),
                _buildTableRow("1\" (25.4mm)", "approx. 38.0 mm"),
              ],
            ),
          ),

          const Divider(height: 32, color: Colors.black12),

          // 🚀 [추가됨] 측정 기준 안내 및 보정표 (OD/2)
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                "측정 기준 안내 및 보정표",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "본 계산기는 C-to-C(가상 센터라인) 전용입니다.\n"
            "도면이 끝단(Face) 또는 바깥쪽(Back) 기준이라면, 아래의 보정 참조표(OD/2)를 보고 치수를 직접 가감하여 입력하십시오.\n"
            "※ 잘못된 기준 적용으로 인한 오차는 전적으로 작업자의 책임입니다.",
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Colors.blueGrey[800],
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
                  decoration: BoxDecoration(color: Colors.grey.shade50),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "규격 (OD)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "측정 보정값 (OD/2)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                _buildTableRow(
                  "1/4\" (6.35mm)",
                  "3.17 mm",
                  color: Colors.redAccent,
                ),
                _buildTableRow(
                  "3/8\" (9.52mm)",
                  "4.76 mm",
                  color: Colors.redAccent,
                ),
                _buildTableRow(
                  "1/2\" (12.7mm)",
                  "6.35 mm",
                  color: Colors.redAccent,
                ),
                _buildTableRow(
                  "3/4\" (19.05mm)",
                  "9.52 mm",
                  color: Colors.redAccent,
                ),
                _buildTableRow(
                  "1\" (25.4mm)",
                  "12.7 mm",
                  color: Colors.redAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 테이블 내부 Row 생성 헬퍼 (color 파라미터 추가)
  TableRow _buildTableRow(
    String od,
    String valText, {
    Color color = makitaTeal,
  }) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
          child: Text(
            od,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
          child: Text(
            valText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildLeftGroup() {
    return [
      SettingSection(
        title: "1. 튜브 기본 제원",
        icon: Icons.architecture,
        child: Column(
          children: [
            _buildUnitToggle(),
            const SizedBox(height: 8),
            TwoColumnRow(
              left: _buildDropdownWithHelper(
                label: "외경 (OD) [$_unit]",
                value: _currentOD,
                items: _odList,
                onChanged: (val) {
                  setState(() {
                    _currentOD = val!;
                  });
                  _onSpecsChanged();
                },
                displayMapper: (item) =>
                    SettingsController.getDisplayOD(item, _isInch),
                helperText: "※ 배관의 바깥쪽 지름 (관경)",
              ),
              right: _buildNumpadInput(
                "두께 (WT) [mm]",
                _wtController,
                helperText: "※ 배관 벽의 두께",
              ),
            ),
            const SizedBox(height: 12),
            TwoColumnRow(
              left: _buildDropdownWithHelper(
                label: "튜브 재질",
                value: _tubeMaterial,
                items: const ["SUS", "Copper", "Carbon", "Aluminum"],
                onChanged: (val) => setState(() => _tubeMaterial = val!),
                helperText: "※ 재질별 스프링백 및 연신율 특성",
              ),
              right: _buildDropdownWithHelper(
                label: "피팅 타입",
                value: _fittingType,
                items: const ["Twin Ferrule", "Bite Type", "Flare"],
                onChanged: (val) {
                  setState(() => _fittingType = val!);
                  _onSpecsChanged();
                },
                helperText: "※ 결속 방식에 따른 삽입 깊이 기준",
              ),
            ),
          ],
        ),
      ),
      SettingSection(
        title: "2. 배관 조립 및 마킹 기준",
        icon: Icons.straighten,
        child: Column(
          children: [
            TwoColumnRow(
              // 🚀 [수정됨] 드롭다운 제거 후 Locked UI 배치
              left: _buildLockedMeasurementMode(),
              right: _buildDropdownWithHelper(
                label: "마커 정렬 (Marking)",
                value: _benderMark,
                items: const ["0 (기본/다양한 각도)", "L (90도 정방향)", "R (90도 역방향)"],
                onChanged: (val) => setState(() => _benderMark = val!),
                helperText: "• 0 : 모든 각도 대응\n• L : 90도 정방향\n• R : 90도 역방향",
              ),
            ),
            const SizedBox(height: 12),
            TwoColumnRow(
              left: _buildDropdownWithHelper(
                label: "기본 회전",
                value: _defaultRotation,
                items: const ["CW (시계방향)", "CCW (반시계)"],
                onChanged: (val) => setState(() => _defaultRotation = val!),
                helperText: "※ 도면 기준 벤딩 진행 방향",
              ),
              right: _buildNumpadInput(
                "피팅 삽입 깊이 [mm]",
                _fittingDepthController,
                key: 'fittingDepth',
                helperText: "※ 너트 포함 전체 체결(Pull-up) 기준",
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildRightGroup() {
    return [
      // 🚀 우측 영역 최상단에 현장 실무 가이드 (연신율 + OD/2 참조표) 배치
      _buildFieldGuideTip(),

      SettingSection(
        title: "3. 벤더 장비 제원",
        icon: Icons.build,
        child: Column(
          children: [
            _buildDropdownWithHelper(
              label: "벤더 브랜드",
              value: _benderBrand,
              items: const [
                "Swagelok",
                "Hy-Lok",
                "Parker",
                "Ridgid",
                "Klein",
                "Other",
              ],
              onChanged: (val) {
                setState(() => _benderBrand = val!);
                _onSpecsChanged();
              },
              helperText: "※ 제조사별 공식 데이터 연동",
            ),
            const SizedBox(height: 16),
            TwoColumnRow(
              left: _buildNumpadInput(
                "벤드 반경 (R) [mm]",
                _rController,
                key: 'radius',
                helperText: "※ 다이 중심 ~ 튜브 중심",
              ),
              right: _buildNumpadInput(
                "테이크업 [mm]",
                _takeUpController,
                key: 'takeUp',
                helperText: "※ 90도 벤딩 시 차감 보정치",
              ),
            ),
            const SizedBox(height: 12),
            TwoColumnRow(
              left: _buildNumpadInput(
                "연신율 (Gain) [mm]",
                _gainController,
                key: 'gain',
                helperText: "※ 90도 벤딩 시 늘어나는 총 길이",
              ),
              right: _buildNumpadInput(
                "최소 직선 구간 [mm]",
                _minStraightController,
                key: 'minStraight',
                helperText: "※ 벤더 후크 물림 최소장",
              ),
            ),
            const SizedBox(height: 12),
            TwoColumnRow(
              left: _buildNumpadInput(
                "기준선 오프셋 [mm]",
                _benderOffsetController,
                key: 'offset',
                helperText: "※ 다이 0점과 실제 시작점",
              ),
              right: _buildNumpadInput(
                "스프링백 [°]",
                _springbackController,
                helperText: "※ 탄성 복원 각도 보정치",
              ),
            ),
          ],
        ),
      ),
      SettingSection(
        title: "4. 오차 보정 및 앱 설정",
        icon: Icons.settings_suggest,
        child: Column(
          children: [
            TwoColumnRow(
              left: _buildNumpadInput(
                "마킹선 두께 [mm]",
                _markThicknessController,
                helperText: "※ 마커 펜촉 미세 오차 보정",
              ),
              right: _buildNumpadInput(
                "오프셋 축소 [mm]",
                _offsetShrinkController,
                helperText: "※ 간섭 회피용 여유 축소값",
              ),
            ),
            const Divider(color: Colors.black12, height: 24),
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
          ],
        ),
      ),
    ];
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
        setState(() {
          _isInch = (text == "inch");
          String targetOD = _isInch ? "0.5" : "12.0";
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

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth > 800;

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        shadowColor: Colors.black45,
        backgroundColor: makitaTeal,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "벤딩 및 배관 설정",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              "장비 제원 및 마킹 기준 관리",
              style: TextStyle(
                fontSize: 13,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: 16.0,
              top: 12.0,
              bottom: 12.0,
            ),
            child: ElevatedButton(
              onPressed: _saveData,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: hardwareButtonTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
                side: const BorderSide(color: Color(0xFF004D54), width: 1),
              ),
              child: const Text(
                "적 용",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 4.0,
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: isWideScreen
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Column(children: _buildLeftGroup())),
                        const SizedBox(width: 24),
                        Expanded(child: Column(children: _buildRightGroup())),
                      ],
                    )
                  : Column(
                      children: [..._buildLeftGroup(), ..._buildRightGroup()],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: readOnly ? Colors.grey[200] : Colors.white,
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: readOnly ? Colors.black54 : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
              if (isAutoMode != null && onModeChanged != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => onModeChanged!(!isAutoMode!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isAutoMode! ? makitaTeal : Colors.deepOrange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isAutoMode! ? "AUTO" : "MAN",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (helperText != null) ...[
            const SizedBox(height: 6),
            Text(
              helperText!,
              style: TextStyle(
                fontSize: 11,
                color: Colors.blueGrey[700],
                fontWeight: FontWeight.w600,
                height: 1.4,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
