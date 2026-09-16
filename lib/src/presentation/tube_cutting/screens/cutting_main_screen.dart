import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/cutting_project_model.dart';
import '../../../data/models/fitting_item.dart';
import '../../../data/models/smart_fitting_db.dart';
import '../widgets/smart_fitting_selector_sheet.dart';
import 'cutting_history_page.dart';
import '../cutting_optimizer.dart';
import '../cutting_theme.dart';
import '../../inventory/pages/mobile_inventory_ocr.dart';

// 🚀 [입력 고도화] 라인 템플릿(자주 쓰는 부속 구성)을 저장하는 컬렉션.
// 프로젝트와 무관하게 공유되는 참고 데이터라 fittings 컬렉션과 같은
// 성격으로, 이 화면에서 바로 Firestore를 쓴다.
const String kCuttingLineTemplatesCollection = 'cutting_line_templates';

// 🚀 [UI 고도화] 이 화면만 미묘하게 다른 검정(0xFF1A1A1A)을 따로 쓰고
// 있어서, 목록/기록 화면의 텍스트 색(CuttingColors.textPrimary)과 놓고
// 비교하면 아주 살짝 달랐다. 한 팔레트(cutting_theme.dart)를 그대로
// 참조하도록 바꿔서 컷팅 계산기 전체가 정확히 같은 색을 쓰게 했다.
const Color lightBg = CuttingColors.background;
const Color whiteCard = CuttingColors.surface;
const Color makitaTeal = CuttingColors.primary;
const Color makitaDark = CuttingColors.primaryDark;
const Color textPrimary = CuttingColors.textPrimary;

class CutPoint {
  final String id = UniqueKey().toString();
  FittingItem fitting;
  TextEditingController c2cController;
  // 🚀 [입력 고도화] 길이 입력 후 엔터/완료를 누르면 다음 구간의 길이
  // 필드로 자동으로 넘어가도록 포커스 체인을 걸기 위한 노드.
  final FocusNode c2cFocusNode = FocusNode();
  double calculatedCut;

  CutPoint({required this.fitting})
    : c2cController = TextEditingController(),
      calculatedCut = 0.0;

  void dispose() {
    c2cController.dispose();
    c2cFocusNode.dispose();
  }
}

class CuttingMainScreen extends StatefulWidget {
  final CuttingProject project;

  // 🚀 [자재 관리 연동 핵심] 부모(ProjectManagementPage)로부터 받는 콜백.
  // 🚀 [추가] cutRecords는 선택 인자로 추가했다 - 기존 데스크톱
  // ProjectManagementPage가 넘기는 2개짜리 콜백은 그대로 유효하고,
  // 새 모바일 기록 기능을 쓰는 콜백만 3번째 인자를 받으면 된다.
  final Function(
    double totalTubeLength,
    List<Map<String, dynamic>> fittingsList, [
    List<CutRecord> cutRecords,
  ])?
  onSaveCallback;

  const CuttingMainScreen({
    super.key,
    required this.project,
    this.onSaveCallback,
  });

  @override
  State<CuttingMainScreen> createState() => _CuttingMainScreenState();
}

class _CuttingMainScreenState extends State<CuttingMainScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  String _globalMaker = "Swagelok";
  List<CutPoint> _points = [];
  int _setMultiplier = 1;
  bool _groupSameLengths = false;

  // 🚀 [추가] 톱날 손실(커프) - 원자재를 여러 구간으로 자를 때마다
  // 톱날 두께만큼 소재가 갈려 없어진다. 구간별 설치 길이(calculatedCut)
  // 자체는 정확해야 하니 건드리지 않고, "총 소모량" 누적에만 절단
  // 횟수만큼 더해서 원자재 발주량이 실제와 어긋나지 않게 한다.
  double _bladeKerf = 0.0;
  static const String _kerfPrefsKey = 'cutting_blade_kerf';

  // 🚀 [5번 강화, 추가] 재단 최적화(원자재 소요 계산)에 쓸 원자재 기준
  // 길이. 커프처럼 기기에 저장해두고 다음에 또 쓸 수 있게 한다.
  double _stockLength = 6000.0;
  static const String _stockLengthPrefsKey = 'cutting_stock_length';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSequence();
    _loadDraftState();
    _loadBladeKerf();
    _loadStockLength();
  }

  Future<void> _loadBladeKerf() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_kerfPrefsKey);
    if (saved != null && mounted) {
      setState(() => _bladeKerf = saved);
    }
  }

  Future<void> _loadStockLength() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_stockLengthPrefsKey);
    if (saved != null && mounted) {
      setState(() => _stockLength = saved);
    }
  }

  Future<void> _showBladeKerfDialog() async {
    final ctrl = TextEditingController(
      text: _bladeKerf == 0.0 ? '' : _bladeKerf.toString(),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: whiteCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            cuttingDialogIcon(Icons.content_cut_rounded),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                "톱날 손실(커프) 설정",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "원자재를 여러 구간으로 자를 때 톱날 두께만큼 소재가 갈려 없어집니다. "
              "절단 1회당 손실량을 넣어두면 프로젝트 총 소모량 계산에 자동으로 더해집니다.\n"
              "(구간별 설치 길이 자체엔 영향 없습니다)",
              style: TextStyle(
                fontSize: 13,
                color: CuttingColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
              decoration: InputDecoration(
                suffixText: "mm / 회",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: makitaTeal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx, double.tryParse(ctrl.text) ?? 0.0);
            },
            child: const Text(
              "저장",
              style: TextStyle(color: whiteCard, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _bladeKerf = result);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kerfPrefsKey, result);
    }
  }

  // 🚀 [5번 강화] 현재 입력된 구간들로 실제 필요한 절단 조각 목록을 만든다.
  // 그룹 표시(_groupSameLengths)는 화면에 "보여주는" 방식일 뿐이라, 실제
  // 필요한 조각 수는 항상 "구간마다 세트 수만큼"이 정답이라 여기서
  // 통일해서 뽑는다.
  List<double> _collectRequiredPieces() {
    final List<double> pieces = [];
    for (int i = 0; i < _points.length - 1; i++) {
      final p = _points[i];
      if (p.c2cController.text.isEmpty || p.calculatedCut <= 0) continue;
      for (int k = 0; k < _setMultiplier; k++) {
        pieces.add(p.calculatedCut);
      }
    }
    return pieces;
  }

  Future<void> _showOptimizationDialog() async {
    final pieces = _collectRequiredPieces();
    if (pieces.isEmpty) {
      showCuttingSnack(context, "치수를 먼저 입력하세요.", isError: true);
      return;
    }

    final ctrl = TextEditingController(text: _stockLength.toStringAsFixed(0));
    CuttingOptimizationResult result = optimizeCutting(
      pieces: pieces,
      stockLength: _stockLength,
      kerf: _bladeKerf,
    );

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void recalc() {
            final parsed = double.tryParse(ctrl.text);
            if (parsed == null || parsed <= 0) return;
            setDialogState(() {
              result = optimizeCutting(
                pieces: pieces,
                stockLength: parsed,
                kerf: _bladeKerf,
              );
            });
          }

          return AlertDialog(
            backgroundColor: whiteCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                cuttingDialogIcon(Icons.view_column_outlined),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    "재단 최적화 (원자재 소요 계산)",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ctrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onSubmitted: (_) => recalc(),
                          decoration: InputDecoration(
                            labelText: "원자재 기준 길이",
                            suffixText: "mm",
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: makitaTeal,
                        ),
                        onPressed: recalc,
                        child: const Text(
                          "계산",
                          style: TextStyle(color: whiteCard),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: makitaTeal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildOptStat("필요 원자재", "${result.barCount} 본"),
                        _buildOptStat(
                          "총 로스",
                          "${result.totalWaste.toStringAsFixed(0)} mm",
                        ),
                        _buildOptStat(
                          "사용률",
                          result.totalStock > 0
                              ? "${(result.totalUsed / result.totalStock * 100).toStringAsFixed(1)}%"
                              : "-",
                        ),
                      ],
                    ),
                  ),
                  if (result.oversizedPieces.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      "⚠ 원자재보다 긴 구간 ${result.oversizedPieces.length}개는 계산에서 제외됨",
                      style: const TextStyle(
                        color: CuttingColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    "원자재별 배치",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: result.bars.length,
                      separatorBuilder: (_, __) => const Divider(height: 12),
                      itemBuilder: (context, i) {
                        final bar = result.bars[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 44,
                              child: Text(
                                "#${i + 1}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: makitaTeal,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                bar.pieces
                                    .map((p) => p.toStringAsFixed(0))
                                    .join(" + "),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Text(
                              "잔여 ${bar.wasteLength.toStringAsFixed(0)}mm",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final parsed = double.tryParse(ctrl.text);
                  if (parsed != null && parsed > 0) {
                    setState(() => _stockLength = parsed);
                    SharedPreferences.getInstance().then(
                      (prefs) => prefs.setDouble(_stockLengthPrefsKey, parsed),
                    );
                  }
                  Navigator.pop(ctx);
                },
                child: const Text("닫기"),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOptStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: makitaTeal,
          ),
        ),
      ],
    );
  }

  // 🚀 [4번 강화, 신규] 컷팅 지시서를 PDF로 만들어 공유한다. 예전엔 이
  // 계산기에 내보내기/공유 기능이 아예 없어서, 화면을 캡처하거나 손으로
  // 옮겨 적어야 현장에 지시서를 들고 나갈 수 있었다.
  Future<void> _exportCuttingList() async {
    final List<int> visibleIndices = [];
    for (int i = 0; i < _points.length - 1; i++) {
      if (_points[i].c2cController.text.isEmpty) continue;
      if (_points[i].calculatedCut < 0) continue;
      visibleIndices.add(i);
    }
    if (visibleIndices.isEmpty) {
      showCuttingSnack(context, "내보낼 치수가 없습니다. 먼저 치수를 입력하세요.", isError: true);
      return;
    }

    try {
      final fontData = await rootBundle.load(
        'assets/fonts/NotoSansKR-VariableFont_wght.ttf',
      );
      final koreanFont = pw.Font.ttf(fontData);
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: koreanFont, bold: koreanFont),
      );

      final now = DateTime.now();
      final dateStr =
          "${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} "
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      List<String> headers;
      List<List<String>> rows;
      double grandTotal = 0;

      if (_groupSameLengths) {
        headers = ["길이(mm)", "개수", "합계 길이(mm)"];
        final Map<double, int> grouped = {};
        for (final i in visibleIndices) {
          grouped[_points[i].calculatedCut] =
              (grouped[_points[i].calculatedCut] ?? 0) + 1;
        }
        rows = grouped.entries.map((e) {
          final totalCount = e.value * _setMultiplier;
          final total = e.key * totalCount;
          grandTotal += total;
          return [
            e.key.toStringAsFixed(1),
            "$totalCount",
            total.toStringAsFixed(1),
          ];
        }).toList();
      } else {
        headers = ["구간", "구간 길이(mm)", "수량", "합계 길이(mm)"];
        rows = visibleIndices.map((i) {
          final cutLen = _points[i].calculatedCut;
          final total = cutLen * _setMultiplier;
          grandTotal += total;
          return [
            "PT${i + 1} -> PT${i + 2}",
            cutLen.toStringAsFixed(1),
            "$_setMultiplier",
            total.toStringAsFixed(1),
          ];
        }).toList();
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text(
              "컷팅 지시서",
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text("프로젝트: ${widget.project.name}"),
            pw.Text("작성일시: $dateStr"),
            pw.Text(
              "메이커 고정: $_globalMaker    세트 수: $_setMultiplier SET"
              "${_bladeKerf > 0 ? '    톱날 손실: ${_bladeKerf.toStringAsFixed(1)}mm/회' : ''}",
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: rows,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                font: koreanFont,
              ),
              cellStyle: pw.TextStyle(font: koreanFont),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            ),
            pw.SizedBox(height: 16),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                "총 소요 길이: ${grandTotal.toStringAsFixed(1)} mm",
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/${widget.project.name}_컷팅지시서.pdf");
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(file.path),
      ], text: "${widget.project.name} 컷팅 지시서입니다.");
    } catch (e) {
      if (!mounted) return;
      showCuttingSnack(context, "내보내기 실패: $e", isError: true);
    }
  }

  void _initializeSequence() {
    _points = [
      CutPoint(fitting: SmartFittingDB.getById("none")),
      CutPoint(fitting: SmartFittingDB.getById("none")),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveDraftState();
    for (var point in _points) {
      point.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveDraftState();
    }
  }

  String get _draftKey {
    if (widget.onSaveCallback == null) {
      return 'cutting_draft_standalone_absolute_fixed_key';
    }
    String idStr = widget.project.id.toString();
    if (idStr.isEmpty || idStr == 'null') {
      return 'cutting_draft_fallback_${widget.project.name}';
    }
    return 'cutting_draft_$idStr';
  }

  Future<void> _saveDraftState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateData = {
        'globalMaker': _globalMaker,
        'setMultiplier': _setMultiplier,
        'groupSameLengths': _groupSameLengths,
        'points': _points.map((p) {
          return {
            'fittingId': p.fitting.id,
            'c2c': p.c2cController.text,
            'isCustom': p.fitting.category == 'CUSTOM',
            'customName': p.fitting.name,
            'customDed': p.fitting.deduction,
            'customOD': p.fitting.tubeOD,
          };
        }).toList(),
      };
      await prefs.setString(_draftKey, jsonEncode(stateData));
    } catch (e) {
      debugPrint("임시 저장 실패: $e");
    }
  }

  Future<void> _loadDraftState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_draftKey);

      if (jsonStr != null) {
        final stateData = jsonDecode(jsonStr);
        setState(() {
          _globalMaker = stateData['globalMaker'] ?? "Swagelok";
          _setMultiplier = stateData['setMultiplier'] ?? 1;
          _groupSameLengths = stateData['groupSameLengths'] ?? false;

          if (stateData['points'] != null) {
            for (var p in _points) p.dispose();

            _points = (stateData['points'] as List).map((pData) {
              CutPoint p = CutPoint(fitting: SmartFittingDB.getById("none"));
              if (pData['isCustom'] == true) {
                p.fitting = FittingItem(
                  id: pData['fittingId'] ?? "custom",
                  category: "CUSTOM",
                  name: pData['customName'] ?? "커스텀 부속",
                  tubeOD: pData['customOD'] ?? "미지정",
                  maker: "CUSTOM",
                  deduction: (pData['customDed'] as num?)?.toDouble() ?? 0.0,
                  icon: Icons.extension,
                );
              } else {
                p.fitting = SmartFittingDB.getById(
                  pData['fittingId'] ?? "none",
                );
              }
              p.c2cController.text = pData['c2c'] ?? "";
              return p;
            }).toList();
          }
        });
        _calculate();
      }
    } catch (e) {
      debugPrint("불러오기 실패: $e");
    }
  }

  void _calculate() {
    setState(() {
      for (int i = 0; i < _points.length - 1; i++) {
        if (_points[i].c2cController.text.trim().isEmpty) {
          _points[i].calculatedCut = 0.0;
          continue;
        }

        double c2c = double.tryParse(_points[i].c2cController.text) ?? 0.0;
        double deduction1 = _points[i].fitting.deduction;
        double deduction2 = _points[i + 1].fitting.deduction;

        _points[i].calculatedCut = c2c - deduction1 - deduction2;
      }
    });
    _saveDraftState();
  }

  void _addPoint() {
    setState(() {
      _points.add(CutPoint(fitting: SmartFittingDB.getById("none")));
      _calculate();
    });
  }

  // 🚀 [입력 고도화 4번] 예전엔 "포인트 추가"가 항상 맨 끝에만 붙어서,
  // 중간에 구간을 하나 끼워넣으려면 그 뒤 구간들을 전부 다시 만들어야
  // 했다. 카드 사이의 "여기에 추가" 버튼으로 원하는 위치에 바로
  // 끼워넣을 수 있게 한다.
  void _insertPointAt(int index) {
    setState(() {
      _points.insert(index, CutPoint(fitting: SmartFittingDB.getById("none")));
      _calculate();
    });
  }

  // 🚀 [입력 고도화 4번] 같은 부속·같은 길이의 구간이 반복되는 경우
  // (예: 동일 규격 지지대 여러 개)가 흔해서, 바로 다음 자리에 복제해
  // 넣고 필요하면 길이만 살짝 바꿔 쓸 수 있게 한다.
  void _duplicatePoint(int index) {
    setState(() {
      final source = _points[index];
      final copy = CutPoint(fitting: source.fitting);
      copy.c2cController.text = source.c2cController.text;
      _points.insert(index + 1, copy);
      _calculate();
    });
  }

  void _removePoint(int index) {
    if (_points.length <= 2) return;
    setState(() {
      _points[index].dispose();
      _points.removeAt(index);
      _calculate();
    });
  }

  // 🚀 [입력 고도화 2번] 줄자를 눈으로 읽어 손으로 입력하는 대신, 카메라로
  // 찍으면 인벤토리 라벨 스캔에 이미 쓰던 OCR(OcrService)로 숫자를 읽어
  // 길이 필드에 바로 채워준다. 인식된 텍스트에서 첫 번째 숫자만 뽑는다.
  Future<void> _scanLengthWithCamera(int index) async {
    final text = await OcrService.scanLabelText(context);
    if (text == null || !mounted) return;

    final match = RegExp(r'\d+(\.\d+)?').firstMatch(text.replaceAll(',', ''));
    if (match == null) {
      showCuttingSnack(context, "숫자를 인식하지 못했습니다. 다시 촬영해주세요.", isError: true);
      return;
    }

    setState(() {
      _points[index].c2cController.text = match.group(0)!;
      _calculate();
    });
  }

  // 🚀 [입력 고도화 6번] 자주 쓰는 부속 구성(라인)을 저장해뒀다가 다른
  // 작업에서 바로 불러와 쓰는 기능. 프로젝트에 종속되지 않는 공용
  // 데이터라 fittings 컬렉션처럼 별도 Firestore 컬렉션에 저장한다.
  List<Map<String, dynamic>> _serializePointsForTemplate() {
    return _points.map((p) {
      return {
        'fittingId': p.fitting.id,
        'c2c': p.c2cController.text,
        'isCustom': p.fitting.category == 'CUSTOM',
        'customName': p.fitting.name,
        'customDed': p.fitting.deduction,
        'customOD': p.fitting.tubeOD,
      };
    }).toList();
  }

  Future<void> _promptSaveTemplate() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: whiteCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            cuttingDialogIcon(Icons.bookmark_add_outlined),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                "템플릿으로 저장",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "템플릿 이름 (예: 3단 선반 다리)",
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: makitaTeal),
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text("저장", style: TextStyle(color: whiteCard)),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    await FirebaseFirestore.instance
        .collection(kCuttingLineTemplatesCollection)
        .add({
          'name': name,
          'createdAt': DateTime.now().toIso8601String(),
          'points': _serializePointsForTemplate(),
        });
    if (mounted) showCuttingSnack(context, "'$name' 템플릿으로 저장했습니다.");
  }

  Future<void> _applyTemplateData(
    BuildContext sheetContext,
    Map<String, dynamic> data,
  ) async {
    final pointsData = (data['points'] as List?) ?? [];
    if (pointsData.isEmpty) return;

    final bool hasExistingInput = _points.any(
      (p) => p.fitting.id != 'none' || p.c2cController.text.isNotEmpty,
    );
    if (hasExistingInput) {
      final confirmed = await showCuttingConfirmDialog(
        context,
        title: "템플릿 불러오기",
        message: "현재 입력 중인 라인 구성이 템플릿 내용으로 바뀝니다. 계속할까요?",
        confirmLabel: "불러오기",
        icon: Icons.download_outlined,
      );
      if (!confirmed) return;
    }

    setState(() {
      for (var p in _points) {
        p.dispose();
      }
      _points = pointsData.map((pData) {
        final m = pData as Map;
        CutPoint p = CutPoint(fitting: SmartFittingDB.getById("none"));
        if (m['isCustom'] == true) {
          p.fitting = FittingItem(
            id: m['fittingId'] ?? "custom",
            category: "CUSTOM",
            name: m['customName'] ?? "커스텀 부속",
            tubeOD: m['customOD'] ?? "미지정",
            maker: "CUSTOM",
            deduction: (m['customDed'] as num?)?.toDouble() ?? 0.0,
            icon: Icons.extension,
          );
        } else {
          p.fitting = SmartFittingDB.getById(m['fittingId'] ?? "none");
        }
        p.c2cController.text = m['c2c'] ?? "";
        return p;
      }).toList();
    });
    _calculate();
    if (sheetContext.mounted) Navigator.pop(sheetContext);
    if (mounted) showCuttingSnack(context, "템플릿을 불러왔습니다.");
  }

  Future<void> _deleteTemplate(String docId) async {
    final confirmed = await showCuttingConfirmDialog(
      context,
      title: "템플릿 삭제",
      message: "이 템플릿을 삭제할까요? 되돌릴 수 없습니다.",
      confirmLabel: "삭제",
      danger: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed) {
      await FirebaseFirestore.instance
          .collection(kCuttingLineTemplatesCollection)
          .doc(docId)
          .delete();
    }
  }

  void _showTemplateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: whiteCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "라인 템플릿",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await _promptSaveTemplate();
                    },
                    icon: const Icon(
                      Icons.bookmark_add_outlined,
                      color: makitaTeal,
                    ),
                    label: const Text(
                      "현재 구성을 템플릿으로 저장",
                      style: TextStyle(
                        color: makitaTeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: makitaTeal),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "저장된 템플릿",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(kCuttingLineTemplatesCollection)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: makitaTeal),
                      );
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          "저장된 템플릿이 없습니다.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['name'] as String?) ?? "이름 없음";
                        final count = (data['points'] as List?)?.length ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: lightBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.view_list_outlined,
                                color: makitaTeal,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Text(
                                      "포인트 $count개",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => _applyTemplateData(ctx, data),
                                child: const Text("불러오기"),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: CuttingColors.danger,
                                  size: 20,
                                ),
                                onPressed: () => _deleteTemplate(doc.id),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFittingSelector(int index) async {
    FittingItem? selectedItem = await SmartFittingSelectorSheet.show(
      context,
      _globalMaker,
    );
    if (selectedItem != null) {
      setState(() => _points[index].fitting = selectedItem);
      _calculate();
    }
  }

  void _showCustomFittingDialog(int index) {
    TextEditingController nameCtrl = TextEditingController(text: "커스텀 부속");
    TextEditingController specCtrl = TextEditingController();
    TextEditingController deductionCtrl = TextEditingController();

    Widget buildInputField({
      required String label,
      required String hint,
      required TextEditingController controller,
      bool isNumber = false,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: makitaDark,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: isNumber
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
            cursorColor: makitaTeal,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
              suffixText: isNumber ? "mm" : null,
              suffixStyle: const TextStyle(
                color: makitaTeal,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: makitaTeal, width: 2.5),
              ),
            ),
          ),
        ],
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: whiteCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: makitaTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.extension,
                        color: makitaTeal,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "커스텀 부속 설정",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                buildInputField(
                  label: "품명 (예: 볼 밸브, 체크 밸브)",
                  hint: "품명 입력",
                  controller: nameCtrl,
                ),
                const SizedBox(height: 16),
                buildInputField(
                  label: "규격 (예: 1/2, 3/8, 12mm)",
                  hint: "규격 입력",
                  controller: specCtrl,
                ),
                const SizedBox(height: 16),
                buildInputField(
                  label: "적용할 공제값 (Deduction)",
                  hint: "0.0",
                  controller: deductionCtrl,
                  isNumber: true,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: Colors.grey.shade300,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "취소",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: makitaTeal,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          double customDed =
                              double.tryParse(deductionCtrl.text) ?? 0.0;
                          String specStr = specCtrl.text.trim().isEmpty
                              ? "미지정"
                              : specCtrl.text.trim();

                          setState(() {
                            _points[index].fitting = FittingItem(
                              id: "custom_${DateTime.now().millisecondsSinceEpoch}",
                              category: "CUSTOM",
                              name: nameCtrl.text.trim().isEmpty
                                  ? "커스텀 부속"
                                  : nameCtrl.text.trim(),
                              tubeOD: specStr, // 🚀 규격 정확히 저장
                              maker: "CUSTOM",
                              deduction: customDed,
                              icon: Icons.extension,
                            );
                            _calculate();
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          "적용하기",
                          style: TextStyle(
                            color: whiteCard,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _saveRecord() {
    if (_points.any(
      (p) => p.c2cController.text.isNotEmpty && p.calculatedCut < 0,
    )) {
      showCuttingSnack(context, "간섭이 발생한 구간이 있습니다. 치수를 확인해주세요!", isError: true);
      return;
    }

    double totalOneSet = _points
        .sublist(0, _points.length - 1)
        .fold(
          0.0,
          (sum, point) =>
              sum + (point.calculatedCut > 0 ? point.calculatedCut : 0.0),
        );

    double finalTotal = totalOneSet * _setMultiplier;

    if (finalTotal <= 0) return;

    FocusScope.of(context).unfocus();

    // 🚀 [자재 관리용 완벽 분리] 제조사, 규격, 품명, 수량을 담을 객체 리스트
    Map<String, Map<String, dynamic>> groupedFittings = {};
    int totalFittingCount = 0;

    for (var point in _points) {
      if (point.fitting.id != "none") {
        String maker = point.fitting.category == "CUSTOM"
            ? "CUSTOM"
            : _globalMaker;
        String spec = point.fitting.tubeOD;
        String name = point.fitting.name;

        // 고유 식별 키 (제조사_규격_이름)
        String uniqueKey = "${maker}_${spec}_$name";

        if (groupedFittings.containsKey(uniqueKey)) {
          groupedFittings[uniqueKey]!['qty'] += 1;
        } else {
          groupedFittings[uniqueKey] = {
            'maker': maker,
            'spec': spec,
            'name': name,
            'qty': 1,
            'type': 'FITTING',
          };
        }
      }
    }

    List<Map<String, dynamic>> finalFittingsList = [];
    groupedFittings.forEach((key, data) {
      data['qty'] = (data['qty'] as int) * _setMultiplier;
      totalFittingCount += data['qty'] as int;
      // 🚀 [핵심] InventoryPage에서 필터링하는 방식과 100% 동일하게 db_name 생성!
      data['db_name'] = "[${data['maker']}] ${data['spec']} ${data['name']}";
      finalFittingsList.add(data);
    });

    // 🚀 [추가] "완료" 한 번에 실제로 잘린 구간들을 하나씩 CutRecord로
    // 남겨서, 프로젝트 안의 "기록" 탭에서 날짜/요일별로 되짚어볼 수
    // 있게 한다 (예전엔 총합만 쌓이고 언제 뭘 잘랐는지가 안 남았음).
    final now = DateTime.now();
    List<CutRecord> cutRecords = [];
    for (int i = 0; i < _points.length - 1; i++) {
      final point = _points[i];
      if (point.c2cController.text.isEmpty || point.calculatedCut <= 0) {
        continue;
      }
      final nextFitting = _points[i + 1].fitting;
      cutRecords.add(
        CutRecord(
          id: '',
          projectId: widget.project.id,
          timestamp: now,
          tubeSize: point.fitting.id != "none"
              ? point.fitting.tubeOD
              : nextFitting.tubeOD,
          originalLength: double.tryParse(point.c2cController.text) ?? 0.0,
          startFitting: point.fitting.id == "none" ? "직관" : point.fitting.name,
          endFitting: nextFitting.id == "none" ? "직관" : nextFitting.name,
          cutLength: point.calculatedCut,
          multiplier: _setMultiplier,
          // 🚀 [추가] 나중에 똑같이 재현할 수 있도록 제조사와 양쪽
          // 공제값도 같이 남긴다.
          maker: _globalMaker,
          startDeduction: point.fitting.deduction,
          endDeduction: nextFitting.deduction,
        ),
      );
    }

    // 🚀 [추가] 톱날 손실(커프) 반영 - 구간별 설치 길이(cutRecords에 남긴
    // cutLength)는 정확해야 하니 그대로 두고, "총 소모량" 쪽에만 이번에
    // 실제로 자른 횟수(구간 수 × 세트 수)만큼 커프 손실을 더한다.
    final int cutsThisSave = cutRecords.length * _setMultiplier;
    final double kerfLoss = _bladeKerf * cutsThisSave;
    finalTotal += kerfLoss;

    setState(() {
      try {
        widget.project.recordUsage(
          tubeLengthMm: finalTotal,
          fittings: {},
          multiplier: _setMultiplier,
        );
      } catch (e) {
        debugPrint("단독 모드 에러 무시: $e");
      }

      // 🚀 부모(ProjectManagementPage)의 바구니로 완벽하게 규격화된 데이터를 쏩니다!
      if (widget.onSaveCallback != null) {
        widget.onSaveCallback!(finalTotal, finalFittingsList, cutRecords);
      }

      for (var point in _points) {
        point.c2cController.clear();
        point.calculatedCut = 0.0;
      }
      _setMultiplier = 1;
      _calculate();
    });

    final kerfNote = kerfLoss > 0
        ? " (커프 손실 +${kerfLoss.toStringAsFixed(1)}mm 포함)"
        : "";
    showCuttingSnack(
      context,
      "튜브 총 ${finalTotal.toStringAsFixed(1)}mm$kerfNote 및 피팅 ${totalFittingCount}개 작업 완료!",
    );
  }

  Widget _buildFittingBadge(FittingItem item, bool isNone) {
    bool isCustom = item.category == "CUSTOM";
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isNone
            ? Colors.grey.shade100
            : (isCustom
                  ? Colors.orange.shade50
                  : makitaTeal.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isNone
              ? Colors.grey.shade300
              : (isCustom ? Colors.orange : makitaTeal.withValues(alpha: 0.5)),
        ),
      ),
      child: Text(
        isNone ? "-" : item.category.replaceAll('_', '\n'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: item.category.length > 4 ? 9 : 12,
          fontWeight: FontWeight.w900,
          color: isNone
              ? Colors.grey
              : (isCustom ? Colors.orange.shade800 : makitaTeal),
          height: 1.1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: makitaTeal,
        foregroundColor: whiteCard,
        elevation: 0,
        title: Text(
          "프로젝트: ${widget.project.name}",
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: "톱날 손실(커프) 설정",
            icon: const Icon(Icons.content_cut_rounded),
            onPressed: _showBladeKerfDialog,
          ),
          IconButton(
            tooltip: "컷팅 기록",
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CuttingHistoryPage(project: widget.project),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Builder(
            builder: (context) {
              final bool isWide =
                  MediaQuery.of(context).size.shortestSide >= 600;
              return _buildMakerHeader(isWide);
            },
          ),

          // 🚀 [수정] 이 화면은 원래 데스크톱 프로젝트 관리 화면 안에서만
          // 쓰던 고정 좌우 2단(Row flex:4/5) 레이아웃이라, 좁은 폰 화면에서는
          // 각 칸이 짓눌려 못 쓸 정도였다. 폴더블 대응을 하면서 화면
          // 크기(shortestSide)를 실시간으로 봐서, 넓을 땐 기존 좌우 2단
          // 레이아웃을 그대로 쓰고 좁을 땐 탭으로 나눠 1칼럼으로 보여준다.
          Builder(
            builder: (context) {
              final bool isWide =
                  MediaQuery.of(context).size.shortestSide >= 600;
              return isWide ? _buildWideBody() : _buildNarrowBody();
            },
          ),
        ],
      ),
    );
  }

  // 🚀 [추가] 좁은 화면에서는 "메이커 고정" 라벨과 버튼 3개를 한 줄에
  // 욱여넣으면 넘칠 수 있어서, 좁을 땐 라벨을 위에, 버튼을 아래 줄로 뺀다.
  Widget _buildMakerHeader(bool isWide) {
    final makerButtons = Row(
      children: ["Swagelok", "Parker", "Hy-Lok"].map((maker) {
        bool isSelected = _globalMaker == maker;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _globalMaker = maker);
              _saveDraftState();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? makitaTeal : lightBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? makitaTeal : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                maker,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? whiteCard : textPrimary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );

    const label = Row(
      children: [
        Icon(Icons.precision_manufacturing, size: 24, color: makitaTeal),
        SizedBox(width: 8),
        Text(
          "메이커 고정",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isWide ? 12 : 10,
        horizontal: isWide ? 24 : 16,
      ),
      decoration: BoxDecoration(
        color: whiteCard,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: isWide
          ? Row(
              children: [
                label,
                const SizedBox(width: 24),
                Expanded(child: makerButtons),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [label, const SizedBox(height: 8), makerButtons],
            ),
    );
  }

  // 🚀 [추가] 넓은 화면(태블릿/폴더블 펼침) - 예전부터 있던 좌우 2단
  // 레이아웃 그대로. 왼쪽엔 포인트 리스트, 오른쪽엔 배치도+컷팅 지시서.
  Widget _buildWideBody() {
    return Expanded(
      child: Row(
        children: [
          Expanded(flex: 4, child: _buildPointListPane()),
          Container(width: 1, color: Colors.black12),
          Expanded(
            flex: 5,
            child: Column(
              children: [
                Expanded(flex: 1, child: _buildDiagramPane()),
                const Divider(height: 1, color: Colors.black12, thickness: 2),
                Expanded(flex: 1, child: _buildInstructionsPane()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 [추가] 좁은 화면(폰/폴더블 접힘) - 좌우로 욱여넣는 대신 탭으로
  // 나눠서 한 화면에 한 섹션씩 전체 폭을 다 쓰게 한다.
  Widget _buildNarrowBody() {
    return Expanded(
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              labelColor: makitaTeal,
              unselectedLabelColor: Colors.grey,
              indicatorColor: makitaTeal,
              tabs: [
                Tab(text: "입력"),
                Tab(text: "배치도"),
                Tab(text: "결과"),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPointListPane(),
                  _buildDiagramPane(),
                  _buildInstructionsPane(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🚀 [추가] "배관 라인 구축" - 포인트 추가 버튼 + 드래그 정렬 리스트.
  Widget _buildPointListPane() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  "배관 라인 구축 (드래그로 순서 변경)",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: "라인 템플릿",
                onPressed: _showTemplateSheet,
                icon: const Icon(Icons.bookmark_outline, color: makitaDark),
              ),
              ElevatedButton.icon(
                onPressed: _addPoint,
                icon: const Icon(Icons.add, color: whiteCard, size: 18),
                label: const Text("포인트 추가", style: TextStyle(color: whiteCard)),
                style: ElevatedButton.styleFrom(backgroundColor: makitaDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _points.length,
              proxyDecorator:
                  (Widget child, int index, Animation<double> animation) {
                    return Material(
                      color: Colors.transparent,
                      elevation: 0,
                      child: _buildFittingCard(index),
                    );
                  },
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  List<FittingItem> currentFittings = _points
                      .map((p) => p.fitting)
                      .toList();
                  final movedFitting = currentFittings.removeAt(oldIndex);
                  currentFittings.insert(newIndex, movedFitting);

                  for (int i = 0; i < _points.length; i++) {
                    _points[i].fitting = currentFittings[i];
                  }
                  _calculate();
                  _saveDraftState();
                });
              },
              itemBuilder: (context, index) {
                return Container(
                  key: ValueKey(_points[index].id),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    children: [
                      _buildFittingCard(index),
                      if (index < _points.length - 1) ...[
                        _buildLengthInputCard(index),
                        _buildInsertHereButton(index + 1),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 [입력 고도화 4번] 구간 사이에 끼워넣기 버튼. 평소엔 얇은 점선처럼
  // 존재감을 낮춰뒀다가, 눌렀을 때만 그 자리에 새 포인트가 생긴다.
  Widget _buildInsertHereButton(int insertIndex) {
    return Center(
      child: InkWell(
        onTap: () => _insertPointAt(insertIndex),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 16,
                color: Colors.grey.shade400,
              ),
              const SizedBox(width: 4),
              Text(
                "여기에 구간 추가",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🚀 [추가] "1. 배치도" - 현재 라인 구성의 가로 스크롤 시각화.
  // 🚀 [재구성] 예전엔 아이콘+선을 가로로 이어붙여 스크롤해서 봐야 했는데,
  // 전선관 계산기의 마킹 결과 카드처럼 STEP 번호가 붙은 카드를 세로로
  // 쌓는 형태로 바꿨다. 한 화면에 순서대로 쭉 보이고, 카드 안에 다음
  // 구간까지의 길이도 같이 표시돼서 가로 스크롤 없이 전체 라인을
  // 한눈에 파악할 수 있다.
  Widget _buildDiagramPane() {
    return Container(
      color: whiteCard,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "1. 배치도",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 12),
              itemCount: _points.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _buildDiagramStepCard(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagramStepCard(int index) {
    final item = _points[index].fitting;
    final isNone = item.id == "none";
    final isLast = index == _points.length - 1;
    final hasNext = !isLast;
    final cutLength = hasNext ? _points[index].calculatedCut : 0.0;
    final hasInput = hasNext && _points[index].c2cController.text.isNotEmpty;
    final isInterference = hasInput && cutLength < 0;

    // 🚀 [UI 고도화, 가시성] 간섭이 생긴 구간은 카드 테두리와 왼쪽 번호
    // 배지를 빨간색으로 바꿔서, 전체 배치도를 쭉 훑어볼 때 어느 구간이
    // 문제인지 숫자를 하나하나 읽지 않고도 색으로 바로 짚어낼 수 있게 한다.
    final Color badgeColor = isInterference
        ? CuttingColors.danger
        : (isNone ? Colors.grey.shade200 : makitaDark);
    final Color cardBorderColor = isInterference
        ? CuttingColors.danger
        : (isNone ? Colors.grey.shade300 : makitaTeal.withValues(alpha: 0.4));

    return Container(
      decoration: BoxDecoration(
        color: whiteCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cardBorderColor,
          width: isInterference ? 1.5 : 1,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 52,
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(11),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "PT",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isNone
                          ? Colors.grey.shade500
                          : whiteCard.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    "${index + 1}",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isNone ? Colors.grey.shade600 : whiteCard,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildFittingBadge(item, isNone),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isNone)
                                Text(
                                  "${item.tubeOD} 규격",
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              Text(
                                isNone ? "직관 (부속 없음)" : item.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isNone ? Colors.grey : textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (hasNext) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isInterference
                              ? Colors.red.shade50
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.arrow_downward_rounded,
                              size: 14,
                              color: isInterference
                                  ? Colors.red
                                  : Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isInterference ? "간섭 발생! 치수를 확인하세요" : "다음 지점까지",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isInterference
                                      ? Colors.red.shade700
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            Text(
                              hasInput
                                  ? "${cutLength.toStringAsFixed(1)} mm"
                                  : "치수 미입력",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: isInterference
                                    ? Colors.red
                                    : (hasInput
                                          ? Colors.redAccent
                                          : Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🚀 [추가] "2. 컷팅 지시서" - 세트 수량 조절 + 결과 리스트 + 저장 버튼.
  Widget _buildInstructionsPane() {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "2. 컷팅 지시서",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    "같은 길이 합산",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  Switch(
                    value: _groupSameLengths,
                    activeThumbColor: makitaTeal,
                    onChanged: (val) {
                      setState(() => _groupSameLengths = val);
                      _saveDraftState();
                    },
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: whiteCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: makitaTeal),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: makitaTeal),
                      onPressed: () {
                        setState(() {
                          if (_setMultiplier > 1) {
                            _setMultiplier--;
                            _saveDraftState();
                          }
                        });
                      },
                    ),
                    Text(
                      "$_setMultiplier SET",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: makitaTeal),
                      onPressed: () {
                        setState(() {
                          _setMultiplier++;
                          _saveDraftState();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 🚀 [4·5번 강화] 재단 최적화(원자재 소요 계산)와 컷팅 지시서
          // 내보내기(PDF 공유) - 예전엔 둘 다 이 계산기에 없던 기능이라
          // 화면 캡처나 수기 메모에 의존해야 했다.
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showOptimizationDialog,
                  icon: const Icon(
                    Icons.view_column_outlined,
                    size: 18,
                    color: makitaTeal,
                  ),
                  label: const Text(
                    "재단 최적화",
                    style: TextStyle(
                      color: makitaTeal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: makitaTeal),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportCuttingList,
                  icon: const Icon(
                    Icons.ios_share_rounded,
                    size: 18,
                    color: makitaTeal,
                  ),
                  label: const Text(
                    "내보내기",
                    style: TextStyle(
                      color: makitaTeal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: makitaTeal),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: whiteCard,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildCuttingListRenderer(),
            ),
          ),
          const SizedBox(height: 16),
          // 🚀 [간소화] "N 세트 작업 완료 (저장 및 초기화)"는 글자 수가
          // 많아 좁은 화면에서 부담스러웠다. 세트 수는 바로 위 카운터에
          // 이미 보이므로 버튼엔 짧은 동작 문구만, 무슨 일이 일어나는지는
          // 작은 글씨로 한 줄 덧붙였다.
          ElevatedButton(
            onPressed: _points.any((p) => p.c2cController.text.isNotEmpty)
                ? _saveRecord
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: makitaTeal,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "저장하기",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: whiteCard,
                  ),
                ),
                Text(
                  "$_setMultiplier세트 기록 후 새로 입력",
                  style: TextStyle(
                    fontSize: 11,
                    color: whiteCard.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 [재구성] 예전엔 드래그핸들+순번배지+부속선택+수동입력+삭제가
  // 전부 한 줄에 몰려있어서, 좁은 폰 화면에서 각 요소가 짓눌려 글자가
  // 작아지고 터치하기도 힘들었다. 상단(순번/드래그/삭제)·본문(부속
  // 선택, 카드 전체 너비 사용)·하단(공제값/수동입력) 3단으로 나눠서
  // 요소마다 충분한 터치 영역과 가로 공간을 확보했다.
  Widget _buildFittingCard(int index) {
    FittingItem item = _points[index].fitting;
    bool isNone = item.id == "none";
    bool isCustom = item.category == "CUSTOM";

    return Container(
      decoration: BoxDecoration(
        color: whiteCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNone ? Colors.grey.shade300 : makitaTeal,
          width: isNone ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 드래그 핸들 + 순번 배지 + 삭제
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 0),
            child: Row(
              children: [
                const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isNone ? Colors.grey.shade200 : makitaDark,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "PT${index + 1}",
                    style: TextStyle(
                      color: isNone ? Colors.grey.shade600 : whiteCard,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: "이 구간 복제",
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _duplicatePoint(index),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.copy_all_outlined,
                        color: Colors.grey,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                if (_points.length > 2)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _removePoint(index),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 본문: 부속 선택 - 카드 전체 너비를 다 쓰는 큰 터치 영역
          InkWell(
            onTap: () => _openFittingSelector(index),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  _buildFittingBadge(item, isNone),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isNone)
                          Text(
                            "${item.tubeOD} 규격",
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        Text(
                          isNone ? "탭해서 부속 고르기" : item.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isNone ? Colors.grey : textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              ),
            ),
          ),
          // 하단: 공제값 표시 + 수동 입력 버튼 (부속이 선택된 경우만)
          if (!isNone)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(11),
                ),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isCustom ? "수동 입력값" : "공제값",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isCustom
                            ? "${item.deduction}mm (수동)"
                            : "- ${item.deduction}mm",
                        style: TextStyle(
                          color: isCustom ? Colors.orange.shade800 : makitaDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _showCustomFittingDialog(index),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.edit_rounded,
                            color: Colors.grey.shade500,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 🚀 [입력 고도화 1·5번] 길이 입력 한 칸 - 카메라 인식 버튼, ±1/±10mm
  // 스텝 버튼, "이전 구간과 동일" 복사, 엔터로 다음 칸 자동 이동, 규격
  // 불일치/짧은 절단 길이 주의 안내를 한데 모았다.
  void _stepLength(int index, double delta) {
    final current = double.tryParse(_points[index].c2cController.text) ?? 0.0;
    final next = (current + delta).clamp(0.0, double.infinity);
    setState(() {
      _points[index].c2cController.text = next == next.roundToDouble()
          ? next.toStringAsFixed(0)
          : next.toStringAsFixed(1);
      _calculate();
    });
  }

  Widget _buildStepChip(String label, double delta, int index) {
    return InkWell(
      onTap: () => _stepLength(index, delta),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildLengthInputCard(int index) {
    bool hasInput = _points[index].c2cController.text.trim().isNotEmpty;
    bool isInterference = hasInput && _points[index].calculatedCut < 0;
    bool isSuspiciouslyShort =
        hasInput &&
        !isInterference &&
        _points[index].calculatedCut > 0 &&
        _points[index].calculatedCut < 5;

    final startItem = _points[index].fitting;
    final endItem = _points[index + 1].fitting;
    final bool specMismatch =
        startItem.id != "none" &&
        endItem.id != "none" &&
        startItem.tubeOD.isNotEmpty &&
        endItem.tubeOD.isNotEmpty &&
        startItem.tubeOD != "미지정" &&
        endItem.tubeOD != "미지정" &&
        startItem.tubeOD != endItem.tubeOD;

    final bool canCopyPrevious =
        index > 0 && _points[index - 1].c2cController.text.trim().isNotEmpty;
    final bool isLastSegment = index == _points.length - 2;

    return Padding(
      padding: const EdgeInsets.only(left: 48, top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 2,
            height: isInterference ? 90 : 70,
            color: Colors.grey.shade400,
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _points[index].c2cController,
                        focusNode: _points[index].c2cFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: isLastSegment
                            ? TextInputAction.done
                            : TextInputAction.next,
                        onSubmitted: (_) {
                          if (!isLastSegment) {
                            FocusScope.of(
                              context,
                            ).requestFocus(_points[index + 1].c2cFocusNode);
                          } else {
                            FocusScope.of(context).unfocus();
                          }
                        },
                        onChanged: (_) => _calculate(),
                        cursorColor: makitaTeal,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: "전체 길이 (C to C / End to End)",
                          labelStyle: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: isInterference
                              ? Colors.red.shade50
                              : whiteCard,
                          suffixText: "mm",
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isInterference
                                  ? Colors.red
                                  : Colors.grey.shade300,
                              width: isInterference ? 2 : 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isInterference ? Colors.red : makitaTeal,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: "카메라로 치수 인식",
                      child: InkWell(
                        onTap: () => _scanLengthWithCamera(index),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: makitaTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.camera_alt_outlined,
                            color: makitaTeal,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildStepChip("-10", -10, index),
                    _buildStepChip("-1", -1, index),
                    _buildStepChip("+1", 1, index),
                    _buildStepChip("+10", 10, index),
                    if (canCopyPrevious)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _points[index].c2cController.text =
                                _points[index - 1].c2cController.text;
                            _calculate();
                          });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.content_copy_rounded,
                                size: 12,
                                color: makitaTeal,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                "이전 구간과 동일",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: makitaTeal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (isInterference)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_rounded,
                          color: Colors.red,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "간섭 발생! 입력값이 양쪽 피팅 공제값의 합보다 작습니다.",
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // 🚀 [입력 고도화 5번] 서로 다른 규격(OD)의 부속을 이어 붙인
                // 경우, 실수인지 확인할 수 있게 막지는 않고 알려만 준다.
                if (!isInterference && specMismatch)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: CuttingColors.warning,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "규격이 다른 부속끼리 연결됨: ${startItem.tubeOD} → ${endItem.tubeOD}",
                            style: const TextStyle(
                              color: CuttingColors.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!isInterference && !specMismatch && isSuspiciouslyShort)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: CuttingColors.warning,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            "절단 길이가 매우 짧습니다. 치수를 다시 확인해주세요.",
                            style: TextStyle(
                              color: CuttingColors.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCuttingListRenderer() {
    List<double> validCuts = _points
        .sublist(0, _points.length - 1)
        .where((p) => p.c2cController.text.isNotEmpty && p.calculatedCut > 0)
        .map((p) => p.calculatedCut)
        .toList();

    if (validCuts.isEmpty) {
      bool hasError = _points.any(
        (p) => p.c2cController.text.isNotEmpty && p.calculatedCut < 0,
      );
      return Center(
        child: Text(
          hasError ? "간섭이 발생한 구간을 수정하세요." : "치수를 입력하세요.",
          style: TextStyle(
            color: hasError ? Colors.red : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // 🚀 [재구성] 예전엔 항목 하나에 텍스트 4개를 spaceBetween Row 한
    // 줄에 다 욱여넣어서, 실제 작업대에서 보는 이 화면이 좁은 폰에서
    // 넘치거나 글자가 짓눌릴 위험이 제일 컸다. 카드 형태로 바꿔서
    // 가장 중요한 "최종 필요 길이"를 크고 명확하게, 나머지 정보는
    // 위아래로 배치해 절대 겹치거나 넘치지 않게 했다.
    if (_groupSameLengths) {
      Map<double, int> grouped = {};
      for (var cut in validCuts) {
        grouped[cut] = (grouped[cut] ?? 0) + 1;
      }
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: grouped.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          double length = grouped.keys.elementAt(index);
          int count = grouped[length]!;
          int totalCount = count * _setMultiplier;
          return _buildCutResultCard(
            topLeft: "${length.toStringAsFixed(1)} mm",
            topRight: "총 $totalCount 개",
            subtitle: "기본 $count개 × $_setMultiplier SET",
            totalLabel: "합계 소요 길이",
            totalValue: "${(length * totalCount).toStringAsFixed(1)} mm",
          );
        },
      );
    } else {
      final visibleIndices = List.generate(_points.length - 1, (i) => i).where((
        index,
      ) {
        if (_points[index].c2cController.text.isEmpty) return false;
        return _points[index].calculatedCut >= 0;
      }).toList();

      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: visibleIndices.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, listIndex) {
          final index = visibleIndices[listIndex];
          double cutLen = _points[index].calculatedCut;
          return _buildCutResultCard(
            topLeft: "PT${index + 1} → PT${index + 2}",
            topRight: "× $_setMultiplier 개",
            subtitle: "구간 길이 ${cutLen.toStringAsFixed(1)} mm",
            totalLabel: "합계 소요 길이",
            totalValue: "${(cutLen * _setMultiplier).toStringAsFixed(1)} mm",
          );
        },
      );
    }
  }

  // 🚀 [추가] 컷팅 결과 카드 - 가장 중요한 "합계 소요 길이"를 크고
  // 명확하게 강조하고, 나머지 부가 정보는 작게 위아래로 배치한다.
  Widget _buildCutResultCard({
    required String topLeft,
    required String topRight,
    required String subtitle,
    required String totalLabel,
    required String totalValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: whiteCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  topLeft,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: makitaTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  topRight,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: makitaTeal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                totalLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                totalValue,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
