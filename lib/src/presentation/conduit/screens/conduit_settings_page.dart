import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tubing_calculator/src/data/conduit_spec_sets.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
import 'package:tubing_calculator/src/data/models/bender_spec_data.dart';
import 'package:tubing_calculator/src/presentation/conduit/widgets/conduit_calibration_sheet.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate800 = Color(0xFF1E293B);
const Color slate600 = Color(0xFF475569);
const Color slate400 = Color(0xFF94A3B8);
const Color slate200 = Color(0xFFE2E8F0);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

final ValueNotifier<Map<String, dynamic>> globalBenderSettings = ValueNotifier({
  'benderType': 'hand',
  'manufacturer': 'Greenlee',
  'conduitType': 'EMT',
  'conduitSize': '22mm',
  'unitSystem': '미터법 (mm)',
  'fractionPrecision': '1/16"',
  'applyShrink': true,
  'applySpringback': true,
  'springback': 3.0,
  'clr': 114.3,
  'takeUp': 152.4,
  'gain': 81.2,
  'ramTravel': 0.0,
  'setback': 0.0,
  'degPerNotch': 2.5,
  'notchSpacing': 50.8,
  'rollerSize': 38.1,
  'keepScreenOn': true,
  'couplingDepth': 20.0,
  'bladeKerf': 0.0,
  'referenceMark': '화살표 (일반)',
  'bendRadiusWarning': true,
});

const String kConduitSettingsPrefsKey = 'conduit_bender_settings_v1';

/// 폰에 적어 둔 전선관 설정을 읽어 온다.
/// 🚀 [고침] 예전에는 저장 단추를 눌러도 화면에만 남고, 앱을 끄면 Greenlee
/// 22mm 기본값으로 돌아갔다. 테이크업·게인이 바뀌면 마킹 자리가 바뀌는 값이다.
Future<void> loadGlobalBenderSettings() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kConduitSettingsPrefsKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;
    globalBenderSettings.value = {
      ...globalBenderSettings.value,
      ...Map<String, dynamic>.from(decoded),
    };
  } catch (e) {
    debugPrint('전선관 설정 읽기 실패: $e');
  }
}

Future<void> saveGlobalBenderSettings() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    kConduitSettingsPrefsKey,
    jsonEncode(globalBenderSettings.value),
  );
}

/// 단위 칸 도움말. 셈은 늘 mm이고 단위는 현장 탭 표시에만 쓴다.
const String kUnitHelp = "현장 탭(가로 줄자)에서 인치로도 같이 보여 줍니다. 제원 칸과 마킹 탭 값은 늘 mm입니다.";

/// 설정에는 있지만 아직 마킹 셈에 쓰지 않는 칸에 붙이는 말.
const String kNotUsedYet = "아직 마킹 셈에는 쓰지 않습니다.";

/// 유압·시카고 화면의 게인 칸 도움말.
const String kGainHelp =
    "관이 90°로 꺾이며 줄어드는 길이입니다. 총 절단 길이에서 벤드마다 뺍니다. 제조사를 고르면 CLR로 셈한 값이 들어갑니다.";

class ConduitSettingsPage extends StatefulWidget {
  const ConduitSettingsPage({super.key});

  @override
  State<ConduitSettingsPage> createState() => _ConduitSettingsPageState();
}

class _ConduitSettingsPageState extends State<ConduitSettingsPage> {
  late String _selectedTypeId;
  late String _manufacturer;
  late String _conduitType;
  late String _conduitSize;
  late String _unitSystem;
  late String _fractionPrecision;
  late bool _applyShrink;
  late bool _applySpringback;
  late bool _keepScreenOn;
  late bool _bendRadiusWarning;

  late String _referenceMark;
  late double _degPerNotch;

  late TextEditingController _springbackController;
  late TextEditingController _clrController;
  late TextEditingController _takeUpController;
  late TextEditingController _gainController;
  late TextEditingController _ramTravelController;
  late TextEditingController _setbackController;
  late TextEditingController _notchSpacingController;
  late TextEditingController _rollerSizeController;
  late TextEditingController _couplingDepthController;
  late TextEditingController _bladeKerfController;

  final List<String> _koreanConduitSizes = [
    '16mm',
    '22mm',
    '28mm',
    '36mm',
    '42mm',
    '54mm',
  ];

  @override
  void initState() {
    super.initState();
    final s = globalBenderSettings.value;

    _selectedTypeId = s['benderType'];
    _manufacturer = s['manufacturer'];
    _conduitType = s['conduitType'];
    _conduitSize = s['conduitSize'];
    _unitSystem = s['unitSystem'];
    _fractionPrecision = s['fractionPrecision'];
    _applyShrink = s['applyShrink'];
    _applySpringback = s['applySpringback'];
    _keepScreenOn = s['keepScreenOn'];
    _degPerNotch = s['degPerNotch'];
    _referenceMark = s['referenceMark'];
    _bendRadiusWarning = s['bendRadiusWarning'];

    _springbackController = TextEditingController(
      text: s['springback'].toString(),
    );
    _clrController = TextEditingController(text: s['clr'].toString());
    _takeUpController = TextEditingController(text: s['takeUp'].toString());
    _gainController = TextEditingController(text: s['gain'].toString());
    _ramTravelController = TextEditingController(
      text: s['ramTravel'].toString(),
    );
    _setbackController = TextEditingController(text: s['setback'].toString());
    _notchSpacingController = TextEditingController(
      text: s['notchSpacing'].toString(),
    );
    _rollerSizeController = TextEditingController(
      text: s['rollerSize'].toString(),
    );
    _couplingDepthController = TextEditingController(
      text: s['couplingDepth'].toString(),
    );
    _bladeKerfController = TextEditingController(
      text: s['bladeKerf'].toString(),
    );

    // 🚀 [고침] 예전에는 여기서 제조사 표 값으로 칸을 다시 채워서, 손으로 고쳐
    // 저장한 테이크업·게인이 설정을 열 때마다 표 값으로 돌아갔다. 열 때는 저장된
    // 값 그대로 두고, 저장된 고르기가 목록에 없을 때만 표 값을 쓴다.
    if (_fixDropdownChoices()) _loadManufacturerDefaults();
    loadConduitSpecSets().then((sets) {
      if (mounted) _specSets = sets;
    });
  }

  @override
  void dispose() {
    _springbackController.dispose();
    _clrController.dispose();
    _takeUpController.dispose();
    _gainController.dispose();
    _ramTravelController.dispose();
    _setbackController.dispose();
    _notchSpacingController.dispose();
    _rollerSizeController.dispose();
    _couplingDepthController.dispose();
    _bladeKerfController.dispose();
    super.dispose();
  }

  // =========================================================
  // 🚀 목록 동적 생성 (규격 숨김 해제)
  // =========================================================

  List<String> get _availableManufacturers {
    final mfrs = benderSpecData[_selectedTypeId]?.keys.toList() ?? [];
    if (!mfrs.contains('Custom')) {
      mfrs.add('Custom');
    }
    return mfrs;
  }

  List<String> get _availableConduitTypes {
    if (_manufacturer == 'Custom') {
      return ['EMT', 'Rigid', 'PVC', 'Aluminum', 'IMC'];
    }
    return benderSpecData[_selectedTypeId]?[_manufacturer]?.keys.toList() ??
        ['EMT'];
  }

  // 필터링 박살: 무조건 16~54mm 전체 고정
  List<String> get _availableConduitSizes {
    return _koreanConduitSizes;
  }

  /// 벤더 종류·제조사·재질·규격 조합마다 저장해 둔 제원.
  Map<String, Map<String, double>> _specSets = {};

  String get _comboKey => conduitSpecKey(
    benderType: _selectedTypeId,
    manufacturer: _manufacturer,
    conduitType: _conduitType,
    conduitSize: _conduitSize,
  );

  /// 고른 제조사·재질·규격이 목록에 없으면 첫 것으로 맞춘다. 바뀌었으면 true.
  bool _fixDropdownChoices() {
    var changed = false;
    final mfrs = _availableManufacturers;
    if (!mfrs.contains(_manufacturer)) {
      _manufacturer = mfrs.isNotEmpty ? mfrs.first : 'Custom';
      changed = true;
    }

    final types = _availableConduitTypes;
    if (!types.contains(_conduitType)) {
      _conduitType = types.isNotEmpty ? types.first : 'EMT';
      changed = true;
    }

    final sizes = _availableConduitSizes;
    if (!sizes.contains(_conduitSize)) {
      _conduitSize = '22mm';
      changed = true;
    }
    return changed;
  }

  /// 벤더 종류·제조사·재질·규격을 바꿨을 때. 그 조합으로 저장해 둔 값이 있으면
  /// 그것을, 처음 고르는 조합이면 제조사 표 값을 넣는다.
  void _updateDynamicDropdowns() {
    _fixDropdownChoices();
    final saved = _specSets[_comboKey];
    if (saved != null) {
      _applySpecSet(saved);
    } else {
      _loadManufacturerDefaults();
    }
  }

  String _numText(double v) => v.toString();

  void _applySpecSet(Map<String, double> v) {
    if (v['clr'] != null) _clrController.text = _numText(v['clr']!);
    if (v['takeUp'] != null) _takeUpController.text = _numText(v['takeUp']!);
    if (v['gain'] != null) _gainController.text = _numText(v['gain']!);
    if (v['ramTravel'] != null) {
      _ramTravelController.text = _numText(v['ramTravel']!);
    }
    if (v['setback'] != null) _setbackController.text = _numText(v['setback']!);
    if (v['degPerNotch'] != null) _degPerNotch = v['degPerNotch']!;
    if (v['notchSpacing'] != null) {
      _notchSpacingController.text = _numText(v['notchSpacing']!);
    }
    if (v['rollerSize'] != null) {
      _rollerSizeController.text = _numText(v['rollerSize']!);
    }
  }

  Map<String, double> _currentSpecValues() {
    double? d(TextEditingController c) => double.tryParse(c.text);
    return {
      if (d(_clrController) != null) 'clr': d(_clrController)!,
      if (d(_takeUpController) != null) 'takeUp': d(_takeUpController)!,
      if (d(_gainController) != null) 'gain': d(_gainController)!,
      if (d(_ramTravelController) != null)
        'ramTravel': d(_ramTravelController)!,
      if (d(_setbackController) != null) 'setback': d(_setbackController)!,
      'degPerNotch': _degPerNotch,
      if (d(_notchSpacingController) != null)
        'notchSpacing': d(_notchSpacingController)!,
      if (d(_rollerSizeController) != null)
        'rollerSize': d(_rollerSizeController)!,
    };
  }

  // =========================================================

  void _loadManufacturerDefaults() {
    if (_manufacturer == 'Custom') {
      return;
    }

    try {
      final spec =
          benderSpecData[_selectedTypeId]?[_manufacturer]?[_conduitType]?[_conduitSize];

      if (spec != null) {
        if (spec.containsKey('clr')) {
          _clrController.text = spec['clr'].toString();
        }

        if (_selectedTypeId == 'hand') {
          if (spec.containsKey('takeUp')) {
            _takeUpController.text = spec['takeUp'].toString();
          }
          if (spec.containsKey('gain')) {
            _gainController.text = spec['gain'].toString();
          }
        } else if (_selectedTypeId == 'ram') {
          if (spec.containsKey('ramTravel')) {
            _ramTravelController.text = spec['ramTravel'].toString();
          }
          if (spec.containsKey('setback')) {
            _setbackController.text = spec['setback'].toString();
          }
          // 🚀 [버그 수정] 유압식/시카고식은 데이터 파일에 'gain'이 없어서
          // 이전엔 마지막 수동 모드 값이 그대로 남아 총 절단 길이가
          // 틀리게 계산됐음. 선택한 CLR로부터 기하학적 게인을 직접
          // 유도해서 항상 현재 장비와 일치하도록 동기화한다.
          // Gain(90°) = CLR × (2 − π/2)  (호 형상 기준 이론값)
          if (spec.containsKey('clr')) {
            final double clrVal = (spec['clr'] as num).toDouble();
            _gainController.text = (clrVal * (2 - math.pi / 2)).toStringAsFixed(
              1,
            );
          }
        } else if (_selectedTypeId == 'chicago') {
          if (spec.containsKey('degPerNotch')) {
            _degPerNotch = spec['degPerNotch'] as double;
          }
          if (spec.containsKey('notchSpacing')) {
            _notchSpacingController.text = spec['notchSpacing'].toString();
          }
          if (spec.containsKey('rollerSize')) {
            _rollerSizeController.text = spec['rollerSize'].toString();
          }
          // 🚀 [버그 수정] 시카고식도 슈를 감아 굽히는 방식이라 수동
          // 벤더처럼 첫 벤딩 지점에서 테이크업 차감이 필요한데 값이
          // 아예 없었음. 동일 규격 수동 벤더의 테이크업을 근사치로 사용.
          if (spec.containsKey('takeUp')) {
            _takeUpController.text = spec['takeUp'].toString();
          }
          if (spec.containsKey('clr')) {
            final double clrVal = (spec['clr'] as num).toDouble();
            _gainController.text = (clrVal * (2 - math.pi / 2)).toStringAsFixed(
              1,
            );
          }
        }
      }
    } catch (e) {
      debugPrint("제원 데이터 없음: $e");
    }
  }

  void _saveSettings() {
    HapticFeedback.mediumImpact();
    globalBenderSettings.value = {
      'benderType': _selectedTypeId,
      'manufacturer': _manufacturer,
      'conduitType': _conduitType,
      'conduitSize': _conduitSize,
      'unitSystem': _unitSystem,
      'fractionPrecision': _fractionPrecision,
      'applyShrink': _applyShrink,
      'applySpringback': _applySpringback,
      'springback': double.tryParse(_springbackController.text) ?? 3.0,
      'clr': double.tryParse(_clrController.text) ?? 114.3,
      'takeUp': double.tryParse(_takeUpController.text) ?? 152.4,
      'gain': double.tryParse(_gainController.text) ?? 81.2,
      'ramTravel': double.tryParse(_ramTravelController.text) ?? 0.0,
      'setback': double.tryParse(_setbackController.text) ?? 0.0,
      'degPerNotch': _degPerNotch,
      'notchSpacing': double.tryParse(_notchSpacingController.text) ?? 50.8,
      'rollerSize': double.tryParse(_rollerSizeController.text) ?? 38.1,
      'keepScreenOn': _keepScreenOn,
      'couplingDepth': double.tryParse(_couplingDepthController.text) ?? 20.0,
      'bladeKerf': double.tryParse(_bladeKerfController.text) ?? 0.0,
      'referenceMark': _referenceMark,
      'bendRadiusWarning': _bendRadiusWarning,
    };
    saveGlobalBenderSettings();
    // 이 조합으로 넣은 제원을 기억해 둔다(규격을 바꿨다 돌아와도 그대로 나온다).
    final specValues = _currentSpecValues();
    _specSets[_comboKey] = specValues;
    saveConduitSpecSet(_comboKey, specValues);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          "해당 장비의 제원과 설정이 저장되었습니다.",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: makitaTeal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  void _showHelpDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: makitaTeal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
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
            content,
            style: const TextStyle(height: 1.5, fontSize: 14, color: slate800),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                '확인',
                style: TextStyle(
                  color: makitaTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: slate100,
        appBar: AppBar(
          title: const Text(
            '장비 세팅 가이드',
            style: TextStyle(
              color: slate900,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          backgroundColor: pureWhite,
          elevation: 1,
          shadowColor: slate200,
          centerTitle: false,
          iconTheme: const IconThemeData(color: slate900),
        ),
        body: Column(
          children: [
            _buildMainTypeSelector(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 100),
                child: _buildCurrentSettingsView(),
              ),
            ),
          ],
        ),
        bottomSheet: Container(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.of(context).padding.bottom + 12,
          ),
          decoration: const BoxDecoration(
            color: pureWhite,
            border: Border(top: BorderSide(color: slate200, width: 1)),
          ),
          child: ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: makitaTeal,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              "현재 장비 설정 저장",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: pureWhite,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainTypeSelector() {
    return Container(
      color: pureWhite,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "장비 작동 방식 선택",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: slate600,
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () {
                  _showHelpDialog(
                    "작동 방식",
                    "현장에서 사용하는 벤더의 종류(수동, 유압식, 시카고식)를 선택하십시오.\n선택한 장비에 맞춰 데이터 파일에서 제조사와 규격을 불러옵니다.",
                  );
                },
                child: Icon(
                  Icons.help_outline,
                  size: 16,
                  color: slate600.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            decoration: BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: makitaTeal, width: 1.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                dropdownColor: Colors.white,
                isExpanded: true,
                value: _selectedTypeId,
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: makitaTeal,
                  size: 24,
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: makitaTeal,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'hand',
                    child: Row(
                      children: [
                        AppIcon(
                          AppGlyph.benderHand,
                          size: 22,
                          color: makitaTeal,
                        ),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            "수동 벤더 (Hand Bender)",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'ram',
                    child: Row(
                      children: [
                        AppIcon(
                          AppGlyph.benderRam,
                          size: 22,
                          color: makitaTeal,
                        ),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            "유압식 벤더 (Ram Bender)",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'chicago',
                    child: Row(
                      children: [
                        AppIcon(
                          AppGlyph.benderChicago,
                          size: 22,
                          color: makitaTeal,
                        ),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            "시카고식 벤더 (Chicago Bender)",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedTypeId = val;
                      // 강제 규격 변경 로직 싹 다 제거! 무조건 유지.
                      _updateDynamicDropdowns();
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSettingsView() {
    switch (_selectedTypeId) {
      case 'ram':
        return _buildRamSettingsView();
      case 'chicago':
        return _buildChicagoSettingsView();
      case 'hand':
      default:
        return _buildHandSettingsView();
    }
  }

  Widget _buildHandSettingsView() {
    // 🚀 [고침] 제원 칸 값은 늘 mm로 셈한다. 예전에는 단위를 인치로 고르면 칸 뒤
    // 글자만 "로 바뀌어, 인치로 6을 넣으면 6mm로 셈했다.
    const String unit = 'mm';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("수동 장비 프로필"),
        _buildSettingsCard([
          _buildDropdownRow(
            "제조사",
            _availableManufacturers,
            _manufacturer,
            helpText:
                "데이터 파일에 등록된 제조사 목록입니다. 선택 시 해당 장비의 고유 치수(테이크업, 반경 등)가 자동 입력됩니다.",
            (v) {
              if (v != null) {
                setState(() {
                  _manufacturer = v;
                  _updateDynamicDropdowns();
                });
              }
            },
          ),
          _buildDropdownRow(
            "전선관 재질",
            _availableConduitTypes,
            _conduitType,
            helpText: "선택한 제조사에서 지원하는 파이프 재질 목록입니다.",
            (v) {
              if (v != null) {
                setState(() {
                  _conduitType = v;
                  _updateDynamicDropdowns();
                });
              }
            },
          ),
          _buildDropdownRow(
            "규격 사이즈",
            _availableConduitSizes,
            _conduitSize,
            helpText: "작업할 전선관의 외경(KS 규격)을 선택하십시오.",
            (v) {
              if (v != null) {
                setState(() {
                  _conduitSize = v;
                  _updateDynamicDropdowns();
                });
              }
            },
          ),
        ]),
        _buildSectionTitle("제원 수치 (수동)"),
        _buildSettingsCard([
          _buildDropdownRow(
            "현장 탭 단위",
            ['인치 (분수)', '인치 (소수점)', '미터법 (mm)'],
            _unitSystem,
            helpText: kUnitHelp,
            (v) {
              if (v != null) {
                setState(() => _unitSystem = v);
              }
            },
          ),
          if (_unitSystem == '인치 (분수)')
            _buildDropdownRow(
              "줄자 정밀도",
              ['1/8"', '1/16"', '1/32"'],
              _fractionPrecision,
              (v) {
                if (v != null) {
                  setState(() => _fractionPrecision = v);
                }
              },
            ),
          _buildDropdownRow(
            "기본 마킹 기준",
            ['화살표 (일반)', '별 (Back-to-Back)', '노치 (새들 중앙)'],
            _referenceMark,
            helpText: kNotUsedYet,
            (v) {
              if (v != null) {
                setState(() => _referenceMark = v);
              }
            },
          ),
          _buildInputRow(
            "90° 테이크업 (Take-up)",
            _takeUpController,
            suffix: unit,
            helpText: "90°로 세울 때 세울 길이에서 이만큼 빼서 화살표 자리를 찍습니다.",
          ),
          _buildInputRow(
            "벤딩 게인 (Gain)",
            _gainController,
            suffix: unit,
            helpText: "파이프가 직각으로 꺾일 때, 곡선으로 지나가면서 절약되는 배관의 길이입니다.",
          ),
          _buildInputRow(
            "슈 중심선 반경 (CLR)",
            _clrController,
            suffix: unit,
            helpText: "벤더 슈가 그리는 곡선의 반지름입니다.",
          ),
        ]),
        _buildCalibrateButton(),
        ..._buildCommonCorrection(unit),
      ],
    );
  }

  /// 90°로 한 번 꺾어 잰 값으로 테이크업·게인을 잡는 단추(수동·시카고).
  Widget _buildCalibrateButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('conduit_calibrate'),
          style: TextButton.styleFrom(
            foregroundColor: makitaTeal,
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          onPressed: () => ConduitCalibrationSheet.show(
            context,
            currentTakeUp: double.tryParse(_takeUpController.text) ?? 0,
            currentGain: double.tryParse(_gainController.text) ?? 0,
            onApply: (takeUp, gain) {
              setState(() {
                _takeUpController.text = takeUp.toString();
                _gainController.text = gain.toString();
              });
              _saveSettings();
            },
          ),
          icon: const Icon(Icons.straighten, size: 18),
          label: const Text("한 번 꺾어 보고 잡기"),
        ),
      ),
    );
  }

  /// 세 벤더가 같이 쓰는 보정 칸.
  /// 🚀 [고침] 예전에는 스프링백은 유압에만, 수축량 스위치는 시카고에만 있었고
  /// 커플링 깊이·톱날 두께는 어디에도 없었다. 값은 셈에 쓰이는데 고칠 곳이
  /// 없어서, 수동 벤더에서는 "21° (실제 24°)"의 스프링백 3°를 바꿀 수 없었다.
  List<Widget> _buildCommonCorrection(String unit) {
    return [
      _buildSectionTitle("공통 보정"),
      _buildSettingsCard([
        _buildSwitchRow(
          "스프링백 보정",
          _applySpringback,
          helpText:
              "금속관은 꺾은 뒤 조금 펴집니다. 켜면 마킹 화면에 \"실제로 꺾을 각도\"를 이만큼 더해서 보여 줍니다. 마킹 자리는 바뀌지 않습니다.",
          (v) {
            setState(() => _applySpringback = v);
          },
        ),
        if (_applySpringback) _buildInputRow("스프링백 각도", _springbackController),
        _buildSwitchRow(
          "수축량(Shrink) 자동 공제",
          _applyShrink,
          helpText:
              "켜면 오프셋·새들 계산기의 1번 마킹을 \"시작 거리 + 축소값\" 자리에 찍습니다(현장 셈법). 끄면 시작 거리 그대로 찍습니다.",
          (v) {
            setState(() => _applyShrink = v);
          },
        ),
        _buildInputRow(
          "커플링 깊이",
          _couplingDepthController,
          suffix: unit,
          helpText: "마킹 화면에서 \"체결\"을 고르면 관 끝이 커플링에 이만큼 들어간다고 보고 마킹을 당깁니다.",
        ),
        _buildInputRow(
          "톱날 두께",
          _bladeKerfController,
          suffix: unit,
          helpText: "자를 때 톱날에 먹히는 두께입니다. 총 절단 길이에 더합니다.",
        ),
      ]),
    ];
  }

  Widget _buildRamSettingsView() {
    // 🚀 [고침] 제원 칸 값은 늘 mm로 셈한다. 예전에는 단위를 인치로 고르면 칸 뒤
    // 글자만 "로 바뀌어, 인치로 6을 넣으면 6mm로 셈했다.
    const String unit = 'mm';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("유압식 장비 프로필"),
        _buildSettingsCard([
          _buildDropdownRow(
            "제조사",
            _availableManufacturers,
            _manufacturer,
            helpText: "데이터 파일에 등록된 유압식 장비 제조사 목록입니다.",
            (v) {
              if (v != null) {
                setState(() {
                  _manufacturer = v;
                  _updateDynamicDropdowns();
                });
              }
            },
          ),
          _buildDropdownRow("전선관 재질", _availableConduitTypes, _conduitType, (
            v,
          ) {
            if (v != null) {
              setState(() {
                _conduitType = v;
                _updateDynamicDropdowns();
              });
            }
          }),
          _buildDropdownRow("규격 사이즈", _availableConduitSizes, _conduitSize, (
            v,
          ) {
            if (v != null) {
              setState(() {
                _conduitSize = v;
                _updateDynamicDropdowns();
              });
            }
          }),
        ]),
        _buildSectionTitle("유압 실린더 제원"),
        _buildSettingsCard([
          _buildDropdownRow(
            "현장 탭 단위",
            ['인치 (분수)', '인치 (소수점)', '미터법 (mm)'],
            _unitSystem,
            helpText: kUnitHelp,
            (v) {
              if (v != null) {
                setState(() => _unitSystem = v);
              }
            },
          ),
          _buildInputRow(
            "램 이동 거리",
            _ramTravelController,
            suffix: unit,
            helpText:
                "90°로 꺾을 때 램이 나가는 거리입니다. 다른 각도는 이 값에서 셈해 보여 주므로, 최대 스트로크 한계가 아닙니다.",
          ),
          _buildInputRow(
            "셋백 (Setback)",
            _setbackController,
            suffix: unit,
            helpText: "꺾이는 점에서 이만큼 떨어진 자리에 마킹을 찍습니다(벤드마다 뺍니다).",
          ),
          // 🚀 [고침] 게인은 셈에 들어가는데 유압·시카고 화면에는 칸이 없어
          // 보지도 고치지도 못했다.
          _buildInputRow(
            "벤딩 게인 (Gain)",
            _gainController,
            suffix: unit,
            helpText: kGainHelp,
          ),
          _buildInputRow("슈 중심선 반경 (CLR)", _clrController, suffix: unit),
        ]),
        ..._buildCommonCorrection(unit),
      ],
    );
  }

  Widget _buildChicagoSettingsView() {
    // 🚀 [고침] 제원 칸 값은 늘 mm로 셈한다. 예전에는 단위를 인치로 고르면 칸 뒤
    // 글자만 "로 바뀌어, 인치로 6을 넣으면 6mm로 셈했다.
    const String unit = 'mm';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("시카고식 장비 프로필"),
        _buildSettingsCard([
          _buildDropdownRow("제조사", _availableManufacturers, _manufacturer, (v) {
            if (v != null) {
              setState(() {
                _manufacturer = v;
                _updateDynamicDropdowns();
              });
            }
          }),
          _buildDropdownRow("전선관 재질", _availableConduitTypes, _conduitType, (
            v,
          ) {
            if (v != null) {
              setState(() {
                _conduitType = v;
                _updateDynamicDropdowns();
              });
            }
          }),
          _buildDropdownRow("규격 사이즈", _availableConduitSizes, _conduitSize, (
            v,
          ) {
            if (v != null) {
              setState(() {
                _conduitSize = v;
                _updateDynamicDropdowns();
              });
            }
          }),
        ]),
        _buildSectionTitle("노치 및 제원 (시카고)"),
        _buildSettingsCard([
          _buildDropdownRow(
            "현장 탭 단위",
            ['인치 (분수)', '인치 (소수점)', '미터법 (mm)'],
            _unitSystem,
            helpText: kUnitHelp,
            (v) {
              if (v != null) {
                setState(() => _unitSystem = v);
              }
            },
          ),
          _buildSliderRow(
            "노치당 각도",
            _degPerNotch,
            helpText: "전동/시카고 벤더에서 노치(기어) 한 칸을 넘길 때마다 구부러지는 단위 각도입니다.",
            (v) {
              setState(() => _degPerNotch = v);
            },
          ),
          _buildInputRow(
            "90° 테이크업 (Take-up)",
            _takeUpController,
            suffix: unit,
            helpText:
                "꺾이는 점에서 이만큼 빼서 마킹을 찍습니다(벤드마다 뺍니다). 같은 규격 수동 벤더 값을 어림값으로 씁니다.",
          ),
          _buildInputRow(
            "벤딩 게인 (Gain)",
            _gainController,
            suffix: unit,
            helpText: kGainHelp,
          ),
          _buildInputRow(
            "노치 간격",
            _notchSpacingController,
            suffix: unit,
            helpText: "벤더 슈에 새겨진 노치와 노치 사이 거리입니다. $kNotUsedYet",
          ),
          _buildInputRow(
            "롤러 규격",
            _rollerSizeController,
            suffix: unit,
            helpText: "관을 위에서 눌러 주는 롤러(바퀴)의 지름입니다. $kNotUsedYet",
          ),
          _buildInputRow("슈 중심선 반경 (CLR)", _clrController, suffix: unit),
        ]),
        _buildCalibrateButton(),
        ..._buildCommonCorrection(unit),
      ],
    );
  }

  // =====================================
  // 공통 UI 빌더
  // =====================================

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: slate900,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    final validChildren = children.whereType<Widget>().toList();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: slate200, width: 1),
      ),
      child: Column(
        children: validChildren.asMap().entries.map((entry) {
          int idx = entry.key;
          return Column(
            children: [
              entry.value,
              if (idx != validChildren.length - 1)
                const Divider(height: 1, thickness: 1, color: slate100),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLabelWithHelp(String label, String? helpText) {
    // 🚀 [고침] 이름이 한 줄로 고정되어, 폰(폭 344)에서 이름이 긴 칸은 오른쪽
    // 입력칸·스위치와 합쳐 넘쳤다(최대 161px). 길면 두 줄로 내려가게 한다.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: slate800,
            ),
          ),
        ),
        if (helpText != null) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: () {
              _showHelpDialog(label, helpText);
            },
            borderRadius: BorderRadius.circular(10),
            child: Icon(
              Icons.help_outline,
              size: 16,
              color: slate600.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdownRow(
    String label,
    List<String> items,
    String value,
    ValueChanged<String?> onChanged, {
    String? helpText,
  }) {
    final safeValue = items.contains(value) ? value : items.first;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      title: _buildLabelWithHelp(label, helpText),
      // 좁은 화면에서 긴 값(제조사 이름 등)이 줄을 통째로 차지하지 않게 폭을 묶는다.
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: DropdownButton<String>(
          dropdownColor: Colors.white,
          value: safeValue,
          isExpanded: true,
          underline: const SizedBox(),
          icon: const Icon(Icons.keyboard_arrow_down, color: slate600),
          style: const TextStyle(
            fontSize: 15,
            color: makitaTeal,
            fontWeight: FontWeight.bold,
          ),
          selectedItemBuilder: (context) => [
            for (final e in items)
              Align(
                alignment: Alignment.centerRight,
                child: Text(e, overflow: TextOverflow.ellipsis, maxLines: 1),
              ),
          ],
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, overflow: TextOverflow.ellipsis, maxLines: 1),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSwitchRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged, {
    String? helpText,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      title: _buildLabelWithHelp(label, helpText),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: pureWhite,
        activeTrackColor: makitaTeal,
        inactiveThumbColor: pureWhite,
        inactiveTrackColor: slate200,
      ),
    );
  }

  Widget _buildInputRow(
    String label,
    TextEditingController controller, {
    String suffix = "°",
    String? helpText,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      title: _buildLabelWithHelp(label, helpText),
      trailing: SizedBox(
        width: 100,
        child: TextField(
          controller: controller,
          textAlign: TextAlign.end,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: makitaTeal,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            suffixText: " $suffix",
            suffixStyle: const TextStyle(
              color: slate600,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    ValueChanged<double> onChanged, {
    String? helpText,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLabelWithHelp(label, helpText),
              Text(
                "${value.toStringAsFixed(1)}°",
                style: const TextStyle(
                  color: makitaTeal,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: makitaTeal,
              inactiveTrackColor: slate100,
              thumbColor: pureWhite,
              trackHeight: 4.0,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 10.0,
                elevation: 2,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
            ),
            child: Slider(
              value: value,
              min: 1.0,
              max: 10.0,
              divisions: 18,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
