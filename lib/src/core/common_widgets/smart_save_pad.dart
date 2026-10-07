import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:tubing_calculator/src/core/utils/app_settings_controller.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/data/tube_drawing_specs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/common_widgets/save_name_chips.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/history_card_info.dart';

/// 마지막으로 저장한 작업(프로젝트) 이름. 다음 저장 때 미리 채운다.
const String kTubeLastProjectKey = 'tube_last_project';

const Color makitaTeal = AppColors.brand;
const Color _slate900 = AppColors.text;
const Color _slate600 = AppColors.textSub;
const Color _slate100 = AppColors.background;
const Color _pureWhite = Color(0xFFFFFFFF);

class SmartSavePad extends StatefulWidget {
  final double totalCut;
  final List<dynamic> bendList;
  final bool includeStart;
  final bool includeEnd;
  final double tailLength;
  final String startDir;

  // 🚀 프로젝트 관리(자재 누적)로 쏠 콜백 함수
  final Function(double totalCut, List<Map<String, dynamic>> fittings)?
  onSaveCallback;

  /// 저장 알림의 "보관함 보기"가 보관함 탭으로 옮겨 준다(없으면 단추가 안 붙는다).
  final VoidCallback? onOpenArchive;

  /// 보관함에서 불러와 고친 도면이면 그 도면("이 도면에 덮어쓰기"의 대상). 없으면 늘 새 도면으로 저장한다.
  final HistoryOverwriteTarget? overwriteTarget;

  const SmartSavePad({
    super.key,
    required this.totalCut,
    required this.bendList,
    required this.includeStart,
    required this.includeEnd,
    required this.tailLength,
    required this.startDir,
    this.onSaveCallback,
    this.onOpenArchive,
    this.overwriteTarget,
  });

  @override
  State<SmartSavePad> createState() => _SmartSavePadState();
}

class _SmartSavePadState extends State<SmartSavePad> {
  String _selectedSize = '1/2"';

  /// 지금 설정(장비 제원)의 관 크기 칩. 덮어쓸 원본 규격과 다르면 알린다.
  String? _settingsSize;

  final TextEditingController _projectController = TextEditingController();
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  final List<String> _inchSizes = [
    '1/4"',
    '5/16"',
    '3/8"',
    '1/2"',
    '5/8"',
    '3/4"',
    '7/8"',
    '1"',
  ];
  final List<String> _mmSizes = ['8mm', '10mm', '12mm', '20mm', '25mm'];

  // 이미 보관함에 있는 작업 이름(최근 것 먼저)
  List<String> _recentNames = [];
  // 저장이 끝나기 전에 또 눌러 두 건이 저장되는 것을 막는다.
  bool _saving = false;

  // 불러온 도면이 있으면 덮어쓰기를 먼저 고른다("새 도면으로 저장"으로 바꿀 수 있다).
  late bool _overwrite = widget.overwriteTarget != null;

  /// 마지막 작업 이름을 미리 채우고, 보관함에 이미 있는 작업 이름을 칩으로 보여 준다.
  Future<void> _loadNames() async {
    String last = '';
    var names = <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      last = prefs.getString(kTubeLastProjectKey) ?? '';
    } catch (_) {}
    try {
      final rows = await TubeHistoryDb.load();
      final all = <String>[];
      for (final row in rows) {
        try {
          final p = jsonDecode(row['p_to_p']?.toString() ?? '{}')['project'];
          if (p != null) all.add(p.toString());
        } catch (_) {}
      }
      names = recentDistinctNames(all);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _recentNames = names;
      // 아직 아무것도 안 쳤을 때만 채운다(사용자가 먼저 치기 시작했으면 건드리지 않는다).
      if (widget.overwriteTarget == null &&
          _projectController.text.isEmpty &&
          last.trim().isNotEmpty) {
        _projectController.value = TextEditingValue(
          text: last,
          selection: TextSelection(baseOffset: 0, extentOffset: last.length),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadNames();
    final target = widget.overwriteTarget;
    if (target != null) {
      _projectController.text = target.project == '프로젝트 미지정'
          ? ''
          : target.project;
      _fromController.text = target.from == '모름' ? '' : target.from;
      _toController.text = target.to == '모름' ? '' : target.to;
      _noteController.text = target.note;
    }
    // 🚀 [고침] 예전에는 늘 1/2"로 저장됐다. 설정의 관 크기를 먼저 고른다.
    final s = AppSettingsController();
    if (s.tubeOD > 0) {
      final odMm = s.isInch ? s.tubeOD * 25.4 : s.tubeOD;
      final chip = sizeChipForOd(odMm, [..._inchSizes, ..._mmSizes]);
      if (chip != null) {
        _selectedSize = chip;
      } else {
        // 목록에 없는 크기(6mm 등)는 칩을 하나 더 만든다.
        String n(double v) =>
            v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
        _selectedSize = s.isInch ? '${n(s.tubeOD)}"' : '${n(s.tubeOD)}mm';
        (s.isInch ? _inchSizes : _mmSizes).insert(0, _selectedSize);
      }
    }
    _settingsSize = _selectedSize;
    if (target != null) {
      final ps = '${target.row['pipe_size'] ?? ''}'.trim();
      if (ps.isNotEmpty) {
        if (!_inchSizes.contains(ps) && !_mmSizes.contains(ps)) {
          (ps.endsWith('mm') ? _mmSizes : _inchSizes).insert(0, ps);
        }
        _selectedSize = ps;
      }
    }
  }

  @override
  void dispose() {
    _projectController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // 흰 배경·회색 채움·청록 강조 — 앱 나머지 화면(app_dialog.dart의
  // appFieldDecoration)과 같은 톤으로(2026-09-28, 예전엔 이 창만 어두운
  // 바탕에 노란 강조라 폰 색감과 안 맞았다).
  Widget _buildFieldInput(
    String label,
    TextEditingController controller, {
    IconData? icon,
    TextInputAction action = TextInputAction.next,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      textInputAction: action,
      maxLines: maxLines,
      style: const TextStyle(
        color: _slate900,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _slate600, fontSize: 13),
        alignLabelWithHint: maxLines > 1,
        prefixIcon: icon != null
            ? Icon(icon, color: _slate600.withValues(alpha: 0.6), size: 18)
            : null,
        filled: true,
        fillColor: _slate100,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: makitaTeal, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildModeChip(Key key, String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      key: key,
      label: SizedBox(
        width: double.infinity,
        child: Text(label, textAlign: TextAlign.center),
      ),
      selected: selected,
      selectedColor: makitaTeal,
      backgroundColor: _slate100,
      showCheckmark: false,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      labelStyle: TextStyle(
        color: selected ? _pureWhite : _slate600,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildSizeChip(String size) {
    bool isSel = _selectedSize == size;
    return ChoiceChip(
      label: Text(size),
      selected: isSel,
      selectedColor: makitaTeal,
      backgroundColor: _slate100,
      showCheckmark: false,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      labelStyle: TextStyle(
        color: isSel ? _pureWhite : _slate600,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
      onSelected: (v) => setState(() => _selectedSize = size),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 24,
      ),
      decoration: const BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "보관함에 저장",
              style: TextStyle(
                color: _slate900,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SaveSummaryBox(
              saveSummaryText(
                bends: widget.bendList,
                totalCut: widget.totalCut,
                tail: widget.tailLength,
                startFit: widget.includeStart,
                endFit: widget.includeEnd,
              ),
            ),
            if (widget.overwriteTarget != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildModeChip(
                      const Key('save_mode_overwrite'),
                      '이 도면에 덮어쓰기',
                      _overwrite,
                      () => setState(() => _overwrite = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildModeChip(
                      const Key('save_mode_new'),
                      '새 도면으로 저장',
                      !_overwrite,
                      () => setState(() => _overwrite = false),
                    ),
                  ),
                ],
              ),
              if (_overwrite)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '덮어쓸 도면: ${widget.overwriteTarget!.title} · ${widget.overwriteTarget!.dateText}',
                    key: const Key('save_overwrite_target'),
                    style: const TextStyle(
                      color: _slate600,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            _buildFieldInput(
              "프로젝트 이름 (예: A동 보일러실)",
              _projectController,
              icon: Icons.business,
            ),
            SaveNameChips(names: _recentNames, controller: _projectController),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildFieldInput(
                    "시작점",
                    _fromController,
                    icon: Icons.login,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_forward_rounded, color: _slate600),
                ),
                Expanded(
                  child: _buildFieldInput(
                    "도착점",
                    _toController,
                    icon: Icons.logout,
                    action: TextInputAction.done,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildFieldInput(
              "무엇을 했는지 (메모, 선택)",
              _noteController,
              icon: Icons.edit_note,
              action: TextInputAction.done,
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            const Text(
              "튜브 규격 (inch)",
              style: TextStyle(
                color: _slate600,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              children: _inchSizes.map((size) => _buildSizeChip(size)).toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              "튜브 규격 (mm)",
              style: TextStyle(
                color: _slate600,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              children: _mmSizes.map((size) => _buildSizeChip(size)).toList(),
            ),
            // 10-07: 덮어쓸 때 규격 칩은 원본 도면 규격이지만, 함께 저장되는 장비 값·총 길이는 지금 설정이다.
            // 둘이 다르면 알린다(골라 둔 규격과 마킹 값이 어긋나지 않게).
            if (widget.overwriteTarget != null &&
                _settingsSize != null &&
                _selectedSize != _settingsSize)
              Padding(
                key: const Key('save_size_mismatch'),
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '고른 규격($_selectedSize)과 지금 설정($_settingsSize)이 다릅니다. 마킹 값은 지금 설정으로 셈한 것입니다.',
                  style: const TextStyle(
                    color: Color(0xFFB45309),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: makitaTeal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        // 창이 닫힌 뒤에도 알림·이동에 쓸 수 있게 먼저 잡아 둔다.
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        final openArchive = widget.onOpenArchive;
                        final target = widget.overwriteTarget;
                        final overwriting = _overwrite && target != null;
                        try {
                          Map<String, dynamic> pToPData = {
                            "project": _projectController.text.isEmpty
                                ? "프로젝트 미지정"
                                : _projectController.text,
                            "from": _fromController.text.isEmpty
                                ? "모름"
                                : _fromController.text,
                            "to": _toController.text.isEmpty
                                ? "모름"
                                : _toController.text,
                            "start_fit": widget.includeStart,
                            "end_fit": widget.includeEnd,
                            "tail": widget.tailLength,
                            "start_dir": widget.startDir,
                            // 무엇을 했는지 짧은 메모 — 빠른 실행 "작업 히스토리"에도 그대로 보여준다.
                            "note": _noteController.text,
                            // 다시 열 때 같은 값으로 마킹을 셈하도록 장비 값을 남긴다.
                            kTubeDrawingSpecsKey: tubeSpecsSnapshot(
                              MachineSpecs(),
                            ),
                          };

                          final now = DateTime.now().toString().substring(0, 16);
                          if (overwriting) {
                            // 불러온 도면에 덮어쓴다. 저장해 둔 다른 칸은 그대로 두고 고친 칸만 바꾼다.
                            final noteText = _noteController.text.trim();
                            final merged = historyPToPWith(target.pToP, {
                              ...pToPData,
                              // 비우면 QR이 안 열려서 "프로젝트 미지정"으로(10-07).
                              'project':
                                  (pToPData['project'] as String).trim().isEmpty
                                  ? '프로젝트 미지정'
                                  : (pToPData['project'] as String).trim(),
                              'note': noteText,
                              'memo': noteText,
                            });
                            await TubeHistoryDb.update(target.id, {
                              'date': now,
                              'p_to_p': jsonEncode(merged),
                              'pipe_size': _selectedSize,
                              'total_length': widget.totalCut,
                              'bend_data': jsonEncode(widget.bendList),
                            });
                          } else {
                            // 1. 비동기 작업 대기 (DB 저장)
                            final newId = await TubeHistoryDb.insert({
                              'date': now,
                              'p_to_p': jsonEncode(pToPData),
                              'pipe_size': _selectedSize,
                              'total_length': widget.totalCut,
                              'bend_data': jsonEncode(widget.bendList),
                            });
                            // 다음 저장의 덮어쓰기 대상은 방금 새로 저장한 도면(처음 불러온 원본이 아니다).
                            if (newId != null) MobileBendDataManager().moveSourceTo(newId);
                          }
                        } catch (e) {
                          // 저장이 안 됐으면 창을 그대로 두고 다시 누를 수 있게 한다.
                          debugPrint('보관함 저장 실패: $e');
                          if (mounted) setState(() => _saving = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text('저장하지 못했습니다. 다시 시도하십시오.'),
                              backgroundColor: Colors.redAccent.shade400,
                            ),
                          );
                          return;
                        }

                        // 다음 저장 때 같은 작업 이름을 미리 채운다.
                        final savedName = _projectController.text.trim();
                        if (savedName.isNotEmpty) {
                          try {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString(
                              kTubeLastProjectKey,
                              savedName,
                            );
                          } catch (_) {}
                        }

                        // 2. 콜백 실행 (동기 작업)
                        if (!overwriting && widget.onSaveCallback != null) {
                          List<Map<String, dynamic>> usedFittings = [];

                          if (widget.includeStart) {
                            usedFittings.add({
                              'db_name':
                                  '[SWAGELOK] $_selectedSize Union (Start)',
                              'maker': 'SWAGELOK',
                              'spec': _selectedSize,
                              'name': 'Union',
                              'qty': 1,
                            });
                          }
                          if (widget.includeEnd) {
                            usedFittings.add({
                              'db_name':
                                  '[SWAGELOK] $_selectedSize Union (End)',
                              'maker': 'SWAGELOK',
                              'spec': _selectedSize,
                              'name': 'Union',
                              'qty': 1,
                            });
                          }

                          widget.onSaveCallback!(widget.totalCut, usedFittings);
                        }

                        // 🚀 3. 비동기/콜백 처리가 모두 끝난 후 UI 조작 전 반드시 체크!
                        if (!mounted) return;

                        // 4. 안전하게 UI 조작 (경고 100% 소멸)
                        navigator.pop();

                        // 프로젝트에 연결해 저장할 때(콜백이 있을 때)만 프로젝트 자재에도 들어간다.
                        if (overwriting) {
                          // 덮어쓴 것은 바로 되돌릴 수 있게 이전 값을 들고 있는다.
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('도면을 덮어썼습니다: ${target.title}'),
                              backgroundColor: makitaTeal,
                              action: SnackBarAction(
                                label: '되돌리기',
                                textColor: Colors.white,
                                onPressed: () {
                                  TubeHistoryDb.update(target.id, {
                                    'date': target.row['date'],
                                    'p_to_p': target.row['p_to_p'],
                                    'pipe_size': target.row['pipe_size'],
                                    'total_length': target.row['total_length'],
                                    'bend_data': target.row['bend_data'],
                                  });
                                },
                              ),
                            ),
                          );
                          return;
                        }
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              widget.onSaveCallback != null
                                  ? "보관함과 프로젝트 자재에 저장했습니다."
                                  : "보관함에 저장했습니다.",
                            ),
                            backgroundColor: makitaTeal,
                            action: openArchive == null
                                ? null
                                : SnackBarAction(
                                    label: '보관함 보기',
                                    textColor: Colors.white,
                                    onPressed: openArchive,
                                  ),
                          ),
                        );
                      },
                child: Text(
                  _overwrite && widget.overwriteTarget != null ? "덮어쓰기" : "저장",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _pureWhite,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
