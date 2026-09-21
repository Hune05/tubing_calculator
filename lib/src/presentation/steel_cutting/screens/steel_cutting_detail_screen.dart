import 'dart:async';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
import 'dart:io';
import 'dart:typed_data';

import '../../../core/utils/pdf_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HapticFeedback;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/steel_cutting_project_model.dart';
import '../../../data/models/steel_shape_db.dart';
import '../../tube_cutting/cutting_action_bar.dart';
import '../../tube_cutting/cutting_diagram_pdf.dart' show keepTogether;
import '../../tube_cutting/cutting_leftovers.dart';
import '../../tube_cutting/cutting_math.dart' show fmtMm, safeFileName;
import '../../tube_cutting/cutting_optimizer.dart';
import '../../tube_cutting/cutting_pending_banner.dart';
import '../../tube_cutting/cutting_stock_deduct.dart';
import '../../tube_cutting/cutting_plan_rows.dart';
import '../../tube_cutting/cutting_result_logic.dart';
import '../../tube_cutting/cutting_result_view.dart';
import '../../tube_cutting/cutting_theme.dart';
import '../../tube_cutting/widgets/cutting_optimization_sheet.dart';
import '../steel_group_ops.dart';
import '../steel_result_logic.dart';
import '../steel_weight.dart';
import '../steel_shape_icons.dart';
import '../widgets/steel_item_sheet.dart';
import 'steel_cutting_history_page.dart';
import 'steel_pdf_preview_page.dart';

// 🚀 [형강 컷팅 신규] 찬넬/앵글처럼 피팅 없이 그냥 "규격 - 길이 - 수량"만
// 있는 단순 절단 작업 전용 화면. 튜브 컷팅 계산기와 달리 라인(구간)을
// 조립할 필요가 없어서, 목록에 항목을 추가하고 바로 재단 계획·지시서
// 출력으로 넘어가는 훨씬 짧은 흐름으로 만들었다. 재단 계획는 튜브
// 컷팅과 완전히 같은 다중 규격 조합 FFD 빈 패킹(cutting_optimizer.dart)을
// 공용 시트(cutting_optimization_sheet.dart)로 그대로 재사용한다.
class SteelCuttingDetailScreen extends StatefulWidget {
  final SteelCuttingProject project;

  const SteelCuttingDetailScreen({super.key, required this.project});

  @override
  State<SteelCuttingDetailScreen> createState() =>
      _SteelCuttingDetailScreenState();
}

class _SteelCuttingDetailScreenState extends State<SteelCuttingDetailScreen>
    with SingleTickerProviderStateMixin {
  late List<SteelCutItem> _items;
  late double _stockLength;
  late int _setMultiplier;
  double _bladeKerf = 0.0;
  String _categoryFilter = '전체';
  // 결과 탭에서 "잘랐음"으로 표시한 줄(프로젝트마다 이 폰에 저장한다).
  final Set<String> _doneKeys = {};
  // 아이콘 이름: 처음 쓰기 전에는 보이고, 써 본 뒤에는 "?"로 다시 볼 수 있다(튜브 컷팅과 같은 설정을 함께 쓴다).
  static const String _kIconsUsedKey = 'cutting_result_icons_used';
  bool _iconsUsed = true;
  bool _labelsPinned = false;
  // 접어 둔 규격 묶음(프로젝트마다 이 폰에 기억한다).
  final Set<String> _collapsed = {};
  String get _collapsedKey => 'steel_collapsed_${widget.project.id}';
  // 결과 탭에서 접어 둔 규격(입력 탭 접기와 따로 기억한다 — 입력은 고치는 중, 결과는 자르는 중이다).
  final Set<String> _resultFolded = {};
  String get _resultFoldedKey => 'steel_result_folded_${widget.project.id}';
  // 이 작업의 저장이 아직 서버로 못 올라갔는지(통신 없는 현장에서 쓴 것이 남아 있는지).
  bool _pendingSave = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _pendingWatch;

  // 재단 계획에서 "여러 길이 섞어 쓰기"로 고른 가장 긴 원자재(0이면 안 씀). 긴 항목 경고 기준에 쓴다.
  double _mixMax = 0;
  // 카드에서 개수를 바꾸면 화면은 바로 고치고, 저장(과 변경 기록)은 손을 뗀 뒤 한 번만 한다.
  final Map<String, Timer> _qtyTimers = {};

  // 🚀 [튜브 컷팅에 준한 페이지 구성] 튜브 컷팅 계산기와 같은 방식으로
  // 넓은 화면(태블릿/폴더블 펼침)에서는 입력/결과를 좌우 2단으로 동시에
  // 보여주고, 좁은 화면(폰)에서는 "입력"/"결과" 탭으로 나눠 한 화면에
  // 하나씩 전체 폭을 쓰게 한다. 형강은 배치도(다이어그램) 개념이 없어서
  // 튜브의 3탭(입력/배치도/결과)이 아니라 2탭만 쓴다.
  late final TabController _tabController;

  // 🚀 톱날 손실은 어차피 같은 톱으로 자르는 같은 물리 현상이라, 튜브
  // 컷팅 화면(cutting_main_screen.dart)과 같은 SharedPreferences 키를
  // 그대로 공유한다 - 톱을 바꾸지 않는 한 두 화면에서 각각 새로 입력할
  // 필요가 없다.
  static const String _kerfPrefsKey = 'cutting_blade_kerf';
  // 칩: 전체 + 지금 항목에 있는 종류만(없는 종류 칩은 두지 않는다).
  List<String> get _categories {
    final present = <String>{};
    for (final i in _items) {
      present.add(SteelShapeDB.categoryLabel(i.category));
    }
    final ordered = <String>[
      for (final c in SteelShapeDB.categories)
        if (present.contains(c.label)) c.label,
      if (present.contains(SteelShapeDB.customCategory.label))
        SteelShapeDB.customCategory.label,
      if (present.contains('기타')) '기타',
    ];
    return ['전체', ...ordered];
  }

  String get _doneKey => 'steel_done_${widget.project.id}';
  // 잔재를 저장한 때의 결과 줄 모양(줄 열쇠를 이은 글). 지금 줄과 같으면 "이 결과의 잔재는 이미 저장함".
  String get _leftoverKey => 'steel_leftover_saved_${widget.project.id}';
  String _leftoverSavedSig = '';
  // 재고에서 뺀 원자재 본수를 적어 둔다. 재단 계획 창을 닫았다 다시 열어도
  // 같은 본수를 두 번 빼지 않게 막는다.
  String get _stockDeductKey => 'steel_stock_deducted_${widget.project.id}';
  String _stockDeductedSig = '';

  String get _linesSig => _resultLines().map((l) => l.key).join('|');
  bool get _leftoversSaved =>
      _leftoverSavedSig.isNotEmpty && _leftoverSavedSig == _linesSig;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _items = List.of(widget.project.items);
    _stockLength = widget.project.stockLength;
    _setMultiplier = widget.project.setMultiplier;
    _loadBladeKerf();
    _loadDone();
    _loadIconsUsed();
    _loadSortWeight();
    _loadFoldDone();
    _loadHideDone();
    _loadCollapsed();
    _loadMixMax();
    _watchPending();
  }

  // 통신이 없어 못 올라간 저장이 있으면 입력 탭 위에 알려 준다.
  void _watchPending() {
    try {
      _pendingWatch = _docRef.snapshots(includeMetadataChanges: true).listen((
        snap,
      ) {
        final p = snap.metadata.hasPendingWrites;
        if (mounted && p != _pendingSave) {
          setState(() => _pendingSave = p);
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  Future<void> _loadCollapsed() async {
    try {
      final p = await SharedPreferences.getInstance();
      final saved = p.getStringList(_collapsedKey) ?? const <String>[];
      final savedResult = p.getStringList(_resultFoldedKey) ?? const <String>[];
      if (mounted && (saved.isNotEmpty || savedResult.isNotEmpty)) {
        setState(() {
          _collapsed.addAll(saved);
          _resultFolded.addAll(savedResult);
        });
      }
    } catch (_) {}
  }

  // 결과 탭의 규격 머리글을 눌렀을 때: 그 규격 줄을 접고 편다.
  void _toggleResultFold(String spec) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_resultFolded.remove(spec)) _resultFolded.add(spec);
    });
    SharedPreferences.getInstance()
        .then((p) => p.setStringList(_resultFoldedKey, _resultFolded.toList()))
        .catchError((_) => false);
  }

  void _toggleCollapse(String shape) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_collapsed.remove(shape)) _collapsed.add(shape);
    });
    SharedPreferences.getInstance()
        .then((p) => p.setStringList(_collapsedKey, _collapsed.toList()))
        .catchError((_) => false);
  }

  Future<void> _loadMixMax() async {
    try {
      final mix = await loadMixLengths(kSteelMixPrefsKey);
      final m = mix.isEmpty ? 0.0 : mix.reduce((a, b) => a > b ? a : b);
      if (mounted && m != _mixMax) setState(() => _mixMax = m);
    } catch (_) {}
  }

  // 긴 항목 경고에 쓰는 원자재 길이: 기준 길이와 섞어 쓰기 길이 중 가장 긴 것.
  double get _maxStock => _stockLength > _mixMax ? _stockLength : _mixMax;

  Future<void> _loadDone() async {
    try {
      final p = await SharedPreferences.getInstance();
      final saved = p.getStringList(_doneKey) ?? const <String>[];
      final sig = p.getString(_leftoverKey) ?? '';
      final deducted = p.getString(_stockDeductKey) ?? '';
      if (!mounted) return;
      setState(() {
        _doneKeys.addAll(saved);
        _leftoverSavedSig = sig;
        _stockDeductedSig = deducted;
      });
      _pruneDone();
      await _autoRestartIfFinished();
    } catch (_) {}
  }

  // 지난번에 다 자르고 잔재까지 저장한 작업을 다시 열면 스스로 새로 시작한다(잘랐음 표시와 접어 둔
  // 규격을 지운다. 잔재 저장 기록은 남겨 둔다 — 같은 잔재를 두 번 저장하지 않게 막는 장치다). 사용자가 "잘랐음 지우기"를 누를 일을 없앤다. 아직 다 자르지 않았거나 잔재를
  // 저장하지 않은 작업은 그대로 둔다 — 하던 일을 이어서 해야 하기 때문이다.
  Future<void> _autoRestartIfFinished() async {
    if (_doneKeys.isEmpty || !_leftoversSaved) return;
    final lines = _resultLines();
    if (lines.isEmpty) return;
    if (!lines.every((l) => _doneKeys.contains(l.key))) return;
    if (!mounted) return;
    setState(() {
      _doneKeys.clear();
      _resultFolded.clear();
    });
    await _saveDone();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_resultFoldedKey, const []);
    } catch (_) {}
    if (!mounted) return;
    showCuttingSnack(context, "지난번에 다 잘랐으니 잘랐음 표시를 새로 시작합니다.");
  }

  Future<void> _saveDone() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_doneKey, _doneKeys.toList());
    } catch (_) {}
  }

  // 항목을 고치거나 세트 수를 바꿔서 없어진 줄의 "잘랐음" 표시는 버린다.
  void _pruneDone() {
    final live = {for (final l in _resultLines()) l.key};
    final before = _doneKeys.length;
    _doneKeys.removeWhere((k) => !live.contains(k));
    if (_doneKeys.length != before) {
      setState(() {});
      _saveDone();
    }
  }

  Future<void> _loadIconsUsed() async {
    try {
      final used =
          (await SharedPreferences.getInstance()).getBool(_kIconsUsedKey) ??
          false;
      if (mounted && !used) setState(() => _iconsUsed = false);
    } catch (_) {}
  }

  void _markIconsUsed() {
    if (_labelsPinned) setState(() => _labelsPinned = false);
    if (_iconsUsed) return;
    setState(() => _iconsUsed = true);
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_kIconsUsedKey, true))
        .catchError((_) => false);
  }

  // 결과를 무게가 큰 규격부터 보여 줄지(이 폰에 기억한다).
  static const String _kSortWeightKey = 'steel_result_sort_weight';
  bool _sortByWeight = false;
  // 다 자른 규격을 접어 둘지(기본 켬). 튜브 컷팅과 따로 두지 않고 형강 결과 탭에서만 쓴다.
  static const String _kFoldDoneKey = 'steel_result_fold_done';
  bool _foldDone = true;
  // 잘랐음으로 표시한 줄을 감출지(기본 끔 — 처음에는 전체를 보는 편이 안전하다).
  static const String _kHideDoneKey = 'steel_result_hide_done';
  bool _hideDone = false;

  List<ResultLine> _resultLines() {
    final lines = buildSteelResultLines(_items, _setMultiplier);
    return _sortByWeight ? sortLinesByWeight(lines) : lines;
  }

  Future<void> _loadSortWeight() async {
    try {
      final on =
          (await SharedPreferences.getInstance()).getBool(_kSortWeightKey) ??
          false;
      if (mounted && on) setState(() => _sortByWeight = true);
    } catch (_) {}
  }

  void _toggleSortWeight() {
    HapticFeedback.selectionClick();
    setState(() => _sortByWeight = !_sortByWeight);
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_kSortWeightKey, _sortByWeight))
        .catchError((_) => false);
  }

  void _toggleDone(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_doneKeys.remove(key)) _doneKeys.add(key);
    });
    _saveDone();
    // 이 줄로 그 규격을 다 잘랐으면 접어 둔다(켜 두었을 때만). 방금 누른 규격만 접어서, 손으로 다시 펴 둔
    // 다른 규격이 제멋대로 닫히지 않게 한다.
    if (!_foldDone || !_doneKeys.contains(key)) return;
    final lines = _resultLines();
    final spec = lines
        .firstWhere((l) => l.key == key, orElse: () => lines.first)
        .spec;
    if (fullyDoneSpecs(lines, _doneKeys).contains(spec)) _foldSpecs([spec]);
  }

  // 규격을 접어 두고 이 폰에 기억한다(손으로 접는 것과 같은 자리에 적는다).
  void _foldSpecs(Iterable<String> specs) {
    final added = specs.where((s) => !_resultFolded.contains(s)).toList();
    if (added.isEmpty) return;
    setState(() => _resultFolded.addAll(added));
    SharedPreferences.getInstance()
        .then((p) => p.setStringList(_resultFoldedKey, _resultFolded.toList()))
        .catchError((_) => false);
  }

  Future<void> _loadFoldDone() async {
    try {
      final on =
          (await SharedPreferences.getInstance()).getBool(_kFoldDoneKey) ??
          true;
      if (mounted && !on) setState(() => _foldDone = false);
    } catch (_) {}
  }

  Future<void> _loadHideDone() async {
    try {
      final on =
          (await SharedPreferences.getInstance()).getBool(_kHideDoneKey) ??
          false;
      if (mounted && on) setState(() => _hideDone = true);
    } catch (_) {}
  }

  void _toggleHideDone() {
    HapticFeedback.selectionClick();
    setState(() => _hideDone = !_hideDone);
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_kHideDoneKey, _hideDone))
        .catchError((_) => false);
  }

  // 잘랐음 표시를 한꺼번에 지운다(같은 작업을 다시 자를 때).
  // 잘랐음 표시를 한꺼번에 지운다. 표시만 지우는 일이라 확인 창 없이 바로 하고 되돌리기를 준다.
  Future<void> _clearDone() async {
    final before = Set<String>.of(_doneKeys);
    final beforeFolded = Set<String>.of(_resultFolded);
    setState(() {
      _doneKeys.clear();
      _resultFolded.clear();
    });
    await _saveDone();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_resultFoldedKey, const []);
    } catch (_) {}
    if (!mounted) return;
    showCuttingUndoSnack(
      context,
      "${before.length}줄의 잘랐음 표시를 지웠습니다.",
      onUndo: () {
        setState(() {
          _doneKeys.addAll(before);
          _resultFolded.addAll(beforeFolded);
        });
        _saveDone();
        SharedPreferences.getInstance()
            .then(
              (p) => p.setStringList(_resultFoldedKey, _resultFolded.toList()),
            )
            .catchError((_) => false);
      },
    );
  }

  void _toggleFoldDone() {
    HapticFeedback.selectionClick();
    setState(() => _foldDone = !_foldDone);
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_kFoldDoneKey, _foldDone))
        .catchError((_) => false);
    // 켤 때는 이미 다 자른 규격을 바로 접는다. 끌 때는 접어 둔 것을 그대로 두고(머리글을 누르면 펴진다)
    // 앞으로만 접지 않는다.
    if (_foldDone) _foldSpecs(fullyDoneSpecs(_resultLines(), _doneKeys));
  }

  @override
  void dispose() {
    _pendingWatch?.cancel();
    if (_qtyTimers.isNotEmpty) {
      for (final t in _qtyTimers.values) {
        t.cancel();
      }
      _qtyTimers.clear();
      try {
        _docRef
            .update({'items': _items.map((e) => e.toMap()).toList()})
            .catchError((_) {});
      } catch (_) {}
    }
    _tabController.dispose();
    super.dispose();
  }

  // 한 규격만 보기(묶음 ⋮ 메뉴에서 켠다). 빈 글자면 전체.
  String _specFilter = '';

  List<SteelCutItem> get _filteredItems {
    var out = _items;
    if (_specFilter.isNotEmpty) {
      out = out.where((i) => i.shapeLabel == _specFilter).toList();
    }
    if (_categoryFilter == '전체') return out;
    return out
        .where((i) => SteelShapeDB.categoryLabel(i.category) == _categoryFilter)
        .toList();
  }

  Future<void> _loadBladeKerf() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_kerfPrefsKey);
    if (saved != null && mounted) setState(() => _bladeKerf = saved);
  }

  Future<void> _showKerfDialog() async {
    final result = await showBladeKerfDialog(context, _bladeKerf);
    if (result != null) {
      setState(() => _bladeKerf = result);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kerfPrefsKey, result);
    }
  }

  DocumentReference<Map<String, dynamic>> get _docRef => FirebaseFirestore
      .instance
      .collection(kSteelCuttingProjectsCollection)
      .doc(widget.project.id);

  Future<void> _persistItems() async {
    _pruneDone();
    await _docRef.update({'items': _items.map((e) => e.toMap()).toList()});
  }

  Future<void> _persistStockLength(double v) async {
    await _docRef.update({'stockLength': v});
  }

  Future<void> _persistSetMultiplier(int v) async {
    _pruneDone();
    await _docRef.update({'setMultiplier': v});
  }

  // 🚀 [형강 컷팅 기록 신규] 항목을 추가/수정/삭제/복제할 때마다 자동으로
  // 남기는 변경 기록. 되돌리기(실행 취소)로 다시 사라지는 항목까지
  // 기록하면 노이즈만 늘어나므로, 사용자가 의도적으로 한 정방향 동작만
  // 남기고 실행 취소 자체는 별도로 기록하지 않는다.
  // 변경 기록 남기기. 기록이 실패해도 항목 저장까지 망치지 않도록 여기서 삼킨다(기록은 참고용이다).
  Future<void> _logChange(String action, SteelCutItem item) async {
    try {
      await _docRef
          .collection(kSteelChangeLogSubcollection)
          .add(
            SteelChangeLogEntry(
              id: '',
              action: action,
              category: item.category,
              shapeLabel: item.shapeLabel,
              length: item.length,
              qty: item.qty,
              note: item.note,
              timestamp: DateTime.now(),
            ).toMap(),
          );
    } catch (_) {}
  }

  // 🚀 [규격별 분리] 앵글과 찬넬처럼 서로 다른 규격은 같은 원자재(본)에서
  // 나올 수 없으니, 재단 계획는 규격(shapeLabel)별로 따로 계산해야
  // 실제로 현장에서 그대로 따라 할 수 있는 지시서가 나온다.
  Map<String, List<double>> _collectPiecesByShape() {
    final Map<String, List<double>> byShape = {};
    for (final item in _items) {
      final list = byShape.putIfAbsent(item.shapeLabel, () => []);
      for (int k = 0; k < item.qty * _setMultiplier; k++) {
        list.add(item.length);
      }
    }
    return byShape;
  }

  void _addItem() {
    HapticFeedback.lightImpact();
    showSteelItemSheet(
      context,
      onSave: (item) {
        setState(() => _items.add(item));
        _persistItems();
        _logChange('ADD', item);
      },
    );
  }

  void _editItem(SteelCutItem item) {
    showSteelItemSheet(
      context,
      existing: item,
      onSave: (updated) {
        setState(() {
          final idx = _items.indexWhere((e) => e.id == item.id);
          if (idx >= 0) _items[idx] = updated;
        });
        _persistItems();
        _logChange('EDIT', updated);
      },
    );
  }

  void _duplicateItem(SteelCutItem item) {
    final copy = SteelCutItem(
      id: '${DateTime.now().millisecondsSinceEpoch}_dup',
      category: item.category,
      shapeLabel: item.shapeLabel,
      length: item.length,
      qty: item.qty,
      note: item.note,
    );
    setState(() => _items.add(copy));
    _persistItems();
    _logChange('DUPLICATE', copy);
    showCuttingUndoSnack(
      context,
      "'${item.shapeLabel}' 항목을 복제했습니다.",
      onUndo: () {
        setState(() => _items.removeWhere((e) => e.id == copy.id));
        _persistItems();
      },
    );
  }

  // ── 카드에서 바로 개수 바꾸기 ──
  void _bumpQty(SteelCutItem item, int delta) {
    final idx = _items.indexWhere((e) => e.id == item.id);
    if (idx < 0) return;
    final cur = _items[idx];
    final next = (cur.qty + delta).clamp(1, 9999);
    if (next == cur.qty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _items[idx] = SteelCutItem(
        id: cur.id,
        category: cur.category,
        shapeLabel: cur.shapeLabel,
        length: cur.length,
        qty: next,
        note: cur.note,
      );
    });
    _qtyTimers[cur.id]?.cancel();
    _qtyTimers[cur.id] = Timer(const Duration(milliseconds: 800), () {
      _flushQty(cur.id);
    });
  }

  Future<void> _flushQty(String id) async {
    _qtyTimers.remove(id);
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final item = _items[idx];
    try {
      await _persistItems();
      await _logChange('EDIT', item);
    } catch (e) {
      if (!mounted) return;
      showCuttingSnack(context, "저장하지 못했습니다: $e", isError: true);
    }
  }

  // ── 규격 묶음 작업(머리글의 ⋮ 메뉴) ──
  Future<void> _changeGroupShape(String shape) async {
    final to = await pickSteelShape(context);
    if (to == null || !mounted) return;
    if (to.label == shape) {
      showCuttingSnack(context, "같은 규격입니다.", isError: true);
      return;
    }
    final before = List<SteelCutItem>.of(_items);
    final next = changeShapeOfGroup(_items, shape, to);
    final changed = [
      for (final i in next)
        if (i.shapeLabel == to.label &&
            before.any((b) => b.id == i.id && b.shapeLabel == shape))
          i,
    ];
    setState(() => _items = next);
    _persistItems();
    for (final i in changed) {
      _logChange('EDIT', i);
    }
    showCuttingUndoSnack(
      context,
      "'$shape' ${changed.length}건을 '${to.label}'(으)로 바꿨습니다.",
      onUndo: () {
        setState(() => _items = before);
        _persistItems();
      },
    );
  }

  Future<void> _copyGroup(String shape) async {
    final to = await pickSteelShape(context);
    if (to == null || !mounted) return;
    final copies = duplicateGroupTo(
      _items,
      shape,
      to,
      idPrefix: '${DateTime.now().millisecondsSinceEpoch}_grp',
    );
    if (copies.isEmpty) return;
    setState(() => _items.addAll(copies));
    _persistItems();
    for (final c in copies) {
      _logChange('DUPLICATE', c);
    }
    final ids = {for (final c in copies) c.id};
    showCuttingUndoSnack(
      context,
      "'$shape' ${copies.length}건을 '${to.label}'에 복제했습니다.",
      onUndo: () {
        setState(() => _items.removeWhere((e) => ids.contains(e.id)));
        _persistItems();
      },
    );
  }

  // ── 같은 규격·같은 길이 합치기 ──
  void _mergeAll() {
    final r = mergeSameItems(_items);
    if (r.removed.isEmpty) return;
    final before = List<SteelCutItem>.of(_items);
    setState(() => _items = r.items);
    _persistItems();
    for (final k in r.kept) {
      _logChange('EDIT', k);
    }
    for (final d in r.removed) {
      _logChange('DELETE', d);
    }
    showCuttingUndoSnack(
      context,
      "${r.removed.length + r.kept.length}건을 ${r.kept.length}건으로 합쳤습니다.",
      onUndo: () {
        setState(() => _items = before);
        _persistItems();
      },
    );
  }

  void _deleteItem(SteelCutItem item) {
    final index = _items.indexOf(item);
    setState(() => _items.removeWhere((e) => e.id == item.id));
    _persistItems();
    _logChange('DELETE', item);
    showCuttingUndoSnack(
      context,
      "'${item.shapeLabel}' ${item.length.toStringAsFixed(0)}mm 항목을 삭제했습니다.",
      onUndo: () {
        setState(() => _items.insert(index.clamp(0, _items.length), item));
        _persistItems();
      },
    );
  }

  // 재단 계획에서 "잘랐습니다"를 눌러 잔재를 저장했을 때: 결과의 모든 줄을 "잘랐음"으로 맞추고, 이 결과의
  // 잔재는 저장했다고 적어 둔다(항목이나 세트를 바꾸면 저절로 "아직 저장 안 함"으로 돌아간다).
  // 저장 직전의 "잘랐음" 표시(되돌리기용).
  Set<String>? _doneBeforeSave;

  void _onLeftoversSaved() {
    if (!mounted) return;
    setState(() {
      _doneBeforeSave = {..._doneKeys};
      _doneKeys.addAll(_resultLines().map((l) => l.key));
      _leftoverSavedSig = _linesSig;
    });
    _saveDone();
    SharedPreferences.getInstance()
        .then((p) => p.setString(_leftoverKey, _leftoverSavedSig))
        .catchError((_) => false);
  }

  // 재단 계획 창에서 저장을 되돌렸을 때: 잘랐음 표시와 "저장함" 기록을 저장 전으로 돌린다.
  void _onLeftoversSaveUndone() {
    if (!mounted) return;
    setState(() {
      _doneKeys
        ..clear()
        ..addAll(_doneBeforeSave ?? const <String>{});
      _leftoverSavedSig = '';
      _doneBeforeSave = null;
    });
    _pruneDone();
    _saveDone();
    SharedPreferences.getInstance()
        .then((p) => p.remove(_leftoverKey))
        .catchError((_) => false);
  }

  Future<void> _showOptimization() async {
    await showCuttingOptimizationSheet(
      context,
      groupedPieces: _collectPiecesByShape(),
      initialStockLength: _stockLength,
      kerf: _bladeKerf,
      mixPrefsKey: kSteelMixPrefsKey,
      onLeftoversSaved: _onLeftoversSaved,
      onLeftoversSaveUndone: _onLeftoversSaveUndone,
      leftoversAlreadySaved: _leftoversSaved,
      deductedBarsSig: _stockDeductedSig,
      onUndoDeductStock: _undoDeductStock,
      onStockDeducted: (sig) {
        _stockDeductedSig = sig;
        SharedPreferences.getInstance()
            .then((p) => p.setString(_stockDeductKey, sig))
            .catchError((_) => false);
      },
      leftoverLogSource: '형강 컷팅 · ${widget.project.name}',
      jobLogName: '형강 컷팅 · ${widget.project.name}',
      title: "재단 계획 (원자재 몇 본 드는지)",
      onDeductStock: _deductStock,
      onStockLengthChanged: (v) {
        setState(() => _stockLength = v);
        _persistStockLength(v);
      },
    );
    _loadMixMax();
  }

  /// 재단 계획 창에서 "재고에서 빼기"를 눌렀을 때. 규격별 새 원자재 본수를 받아
  /// 창고 재고에서 뺀다. 재고는 자재 이름으로 찾으므로, 자재 목록에 있는 형강
  /// 이름(예: 찬넬 75x40x5)과 규격 이름이 같아야 찾힌다.
  Future<bool> _deductStock(Map<String, int> barsBySpec) async {
    final takes = <StockTake>[
      for (final e in barsBySpec.entries)
        if (e.value > 0 && e.key.trim().isNotEmpty)
          StockTake(name: e.key.trim(), qty: e.value, unit: '본'),
    ];
    if (takes.isEmpty) return false;

    final lines = [for (final t in takes) "${t.name} ${t.qty}본"].join('\n');
    // 창고에 모자란 자재를 알려 준다.
    final stock = await loadStockInfo();
    final warning = shortStockWarning(takes, stock.qtyByName);
    if (!mounted) return false;
    final ok = await showCuttingConfirmDialog(
      context,
      title: "재고에서 빼겠습니까?",
      message: warning.isEmpty
          ? "$lines\n\n창고 재고에서 위 수량을 빼고 자재 기록에 남깁니다."
          : "$lines\n\n창고 재고에서 위 수량을 빼고 자재 기록에 남깁니다.\n\n$warning",
      confirmLabel: "빼기",
      icon: Icons.inventory_2_outlined,
    );
    if (!ok) return false;

    try {
      final result = await deductStockTakes(
        takes,
        projectName: '형강 컷팅 · ${widget.project.name}',
        action: '형강 재단',
        projectId: widget.project.id,
      );
      if (!mounted) return result.done.isNotEmpty;
      showCuttingSnack(context, result.message, isError: !result.allDone);
      return result.done.isNotEmpty;
    } catch (_) {
      if (!mounted) return false;
      showCuttingSnack(context, "재고에서 빼지 못했습니다.", isError: true);
      return false;
    }
  }

  /// 재단 계획 창에서 "되돌리기"를 눌렀을 때. 방금 뺀 본수를 도로 넣는다.
  Future<bool> _undoDeductStock(Map<String, int> barsBySpec) async {
    final takes = <StockTake>[
      for (final e in barsBySpec.entries)
        if (e.value > 0 && e.key.trim().isNotEmpty)
          StockTake(name: e.key.trim(), qty: e.value, unit: '본'),
    ];
    if (takes.isEmpty) return false;

    final lines = [for (final t in takes) "${t.name} ${t.qty}본"].join('\n');
    final ok = await showCuttingConfirmDialog(
      context,
      title: "뺀 것을 도로 넣겠습니까?",
      message: "$lines\n\n창고 재고에 위 수량을 도로 넣고 자재 기록에 남깁니다.",
      confirmLabel: "도로 넣기",
      icon: Icons.undo,
    );
    if (!ok) return false;

    try {
      await undoStockTakes(
        takes,
        projectName: '형강 컷팅 · ${widget.project.name}',
        projectId: widget.project.id,
      );
      if (!mounted) return true;
      showCuttingSnack(context, "재고에 도로 넣었습니다.");
      return true;
    } catch (_) {
      if (!mounted) return false;
      showCuttingSnack(context, "도로 넣지 못했습니다.", isError: true);
      return false;
    }
  }

  Future<void> _sharePdf(Uint8List bytes, String fileName) async {
    try {
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/$fileName");
      await file.writeAsBytes(bytes);
      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(file.path),
      ], text: "${widget.project.name} 형강 컷팅 지시서입니다.");
    } catch (e) {
      if (!mounted) return;
      showCuttingSnack(context, "내보내기 실패: $e", isError: true);
    }
  }

  // 지시서 PDF: 자를 길이 표(1개 길이 × 개수 = 합계) + 규격별 원자재 배치. 잔재와 여러 길이 섞어 쓰기
  // 설정도 재단 계획 화면과 같게 반영한다.
  Future<void> _exportInstructionSheet() async {
    final lines = _resultLines();
    if (lines.isEmpty) {
      showCuttingSnack(
        context,
        "내보낼 항목이 없습니다. 먼저 절단 항목을 추가하십시오.",
        isError: true,
      );
      return;
    }

    try {
      final pdfFonts = await loadKoreanPdfFonts();
      final koreanFont = pdfFonts.regular;
      final koreanBold = pdfFonts.bold;
      final pdf = pw.Document(theme: pdfFonts.theme);

      final now = DateTime.now();
      final dateStr =
          "${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} "
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      pw.Widget table(List<String> headers, List<List<String>> data) =>
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: data,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              font: koreanBold,
            ),
            cellStyle: pw.TextStyle(font: koreanFont),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          );

      // 1) 자를 길이 표 — 규격마다 소계 줄을 넣는다.
      final bool showHow = _setMultiplier > 1;
      final subs = shapeSubtotals(lines);
      final weights = weightTotals(lines);
      final bool weightKnown = weights.total != null;
      final headers = [
        "규격",
        "1개 길이(mm)",
        "개수",
        if (showHow) "개수 구성",
        "합계 길이(mm)",
        if (weightKnown) "중량(kg)",
        "비고",
      ];
      final rows = <List<String>>[];
      for (final sub in subs) {
        for (final l in lines.where((x) => x.spec == sub.shape)) {
          rows.add([
            l.spec,
            fmtMm(l.cutMm),
            "${l.count}",
            if (showHow) "${l.baseCount}개 × ${l.sets}세트",
            fmtMm(l.totalMm),
            if (weightKnown)
              steelWeightKg(l.spec, l.totalMm) == null
                  ? "-"
                  : "약 ${fmtKg(steelWeightKg(l.spec, l.totalMm)!)}",
            l.detail,
          ]);
        }
      }
      final grandTotal = lines.fold(0.0, (a, l) => a + l.totalMm);

      // 2) 규격별 원자재 배치(잔재·섞어 쓰기 반영).
      final leftovers = await loadLeftovers();
      final mixLengths = await loadMixLengths(kSteelMixPrefsKey);
      final piecesByShape = _collectPiecesByShape();
      final planWidgets = <pw.Widget>[];
      var totalBars = 0;
      var totalWaste = 0.0;
      var totalOversized = 0;
      for (final e in piecesByShape.entries) {
        final groupLeftovers = [
          for (final l in leftovers)
            if (l.label == e.key) l.length,
        ];
        final r = mixLengths.isNotEmpty
            ? optimizeCuttingMixed(
                pieces: e.value,
                stockLengths: mixLengths,
                kerf: _bladeKerf,
                leftovers: groupLeftovers,
              )
            : optimizeCutting(
                pieces: e.value,
                stockLength: _stockLength,
                kerf: _bladeKerf,
                leftovers: groupLeftovers,
              );
        totalBars += r.barCount;
        totalWaste += r.totalWaste;
        totalOversized += r.oversizedPieces.length;
        final usage = r.totalStock > 0
            ? (r.totalUsed / r.totalStock * 100).toStringAsFixed(1)
            : '0.0';
        // 제목·요약·표를 한 덩어리로 묶어 쪽 경계에서 표 머리만 따로 남지 않게 한다.
        planWidgets.addAll(
          keepTogether([
            pw.SizedBox(height: 12),
            pw.Text(
              e.key,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                font: koreanBold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              "${planSummary(r)} · 로스 ${r.totalWaste.toStringAsFixed(0)}mm · 사용률 $usage%",
            ),
            pw.SizedBox(height: 6),
            if (r.bars.isNotEmpty || r.leftoverBars.isNotEmpty)
              table(kPlanHeaders, planRows(r)),
            if (r.oversizedPieces.isNotEmpty)
              pw.Text(
                "원자재(${r.stockLength.toStringAsFixed(0)}mm)보다 길어 배치하지 못한 항목 ${r.oversizedPieces.length}건",
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.red),
              ),
          ], rows: r.bars.length + r.leftoverBars.length),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text(
              "형강 컷팅 지시서",
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text("프로젝트: ${widget.project.name}"),
            pw.Text("작성 날짜: $dateStr"),
            pw.Text(
              "원자재 기준 길이: ${_stockLength.toStringAsFixed(0)}mm    세트 수: $_setMultiplier SET"
              "${_bladeKerf > 0 ? '    톱날 손실: ${_bladeKerf.toStringAsFixed(1)}mm/회' : ''}",
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              "1. 자를 길이",
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            table(headers, rows),
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                _setMultiplier > 1
                    ? "총 절단 길이: 1세트 ${fmtMm(grandTotal / _setMultiplier)} mm × $_setMultiplier세트 = ${fmtMm(grandTotal)} mm"
                    : "총 절단 길이: ${fmtMm(grandTotal)} mm",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            if (weightKnown)
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "총 중량: 약 ${fmtKg(weights.total!)} kg (이론값"
                  "${weights.unknownSpecs > 0 ? ', 중량을 모르는 규격 ${weights.unknownSpecs}종 제외' : ''}"
                  ", 실제와 다를 수 있음)",
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            pw.SizedBox(height: 20),
            pw.Text(
              "2. 원자재별 배치 (재단 계획, 총 $totalBars본 - 규격별로 각각 계산됨)",
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            ...planWidgets,
            if (totalOversized > 0) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                "원자재보다 긴 항목 총 $totalOversized건은 배치에서 제외됨 - 원자재 기준 길이를 확인하십시오.",
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.red),
              ),
            ],
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                "총 로스: ${totalWaste.toStringAsFixed(0)} mm",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      if (!mounted) return;
      final fileName = "${safeFileName(widget.project.name)}_형강컷팅지시서.pdf";
      // 바로 공유하지 않고 미리보기를 먼저 보여 준다. 공유는 미리보기의 버튼으로.
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SteelPdfPreviewPage(
            bytes: bytes,
            fileName: fileName,
            onShare: () => _sharePdf(bytes, fileName),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showCuttingSnack(context, "내보내기 실패: $e", isError: true);
    }
  }

  // 🚀 [튜브 컷팅에 준한 페이지 구성] 튜브 컷팅 계산기(cutting_main_screen.dart)의
  // AppBar와 똑같이 브랜드 틸 색 배경 + 흰 글씨, 제목은 "프로젝트: 이름"
  // 형식으로 맞췄다. 다른 컷팅 관련 화면들이 최근 흰 배경 AppBar로
  // 통일됐지만, 실제로 매일 쓰는 계산기 화면(cutting_main_screen)만은
  // 이 틸 색 헤더를 그대로 쓰고 있어서 - 사용자가 "마음에 든다"고 콕
  // 짚은 게 바로 이 화면이었다.
  @override
  Widget build(BuildContext context) {
    return CuttingTheme(
      child: Scaffold(
        backgroundColor: CuttingColors.background,
        appBar: AppBar(
          backgroundColor: CuttingColors.primary,
          foregroundColor: CuttingColors.surface,
          elevation: 0,
          title: Text(
            "프로젝트: ${widget.project.name}",
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          actions: [
            IconButton(
              tooltip: "변경 기록",
              icon: const Icon(Icons.history_rounded),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SteelCuttingHistoryPage(project: widget.project),
                  ),
                );
              },
            ),
            IconButton(
              tooltip: "톱날 손실(커프) 설정",
              icon: const AppIcon(AppGlyph.tubeCut),
              onPressed: _showKerfDialog,
            ),
          ],
        ),
        body: Builder(
          builder: (context) {
            final bool isWide = MediaQuery.of(context).size.shortestSide >= 600;
            return isWide ? _buildWideBody() : _buildNarrowBody();
          },
        ),
      ),
    );
  }

  // 🚀 넓은 화면(태블릿/폴더블 펼침) - 입력과 결과를 좌우 2단으로 동시에
  // 보여준다. 튜브 컷팅 계산기의 좌우 2단(flex 4/5)과 같은 비율.
  Widget _buildWideBody() {
    return Row(
      children: [
        Expanded(flex: 4, child: _buildInputPane()),
        Container(width: 1, color: Colors.black12),
        Expanded(flex: 5, child: _buildResultPane()),
      ],
    );
  }

  // 🚀 좁은 화면(폰) - 좌우로 욱여넣는 대신 "입력"/"결과" 탭으로 나눠서
  // 한 화면에 한 섹션씩 전체 폭을 다 쓴다.
  Widget _buildNarrowBody() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: CuttingColors.primary,
          unselectedLabelColor: Colors.grey.shade600,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          indicatorColor: CuttingColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "입력"),
            Tab(text: "결과"),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildInputPane(), _buildResultPane()],
          ),
        ),
      ],
    );
  }

  // 입력 창: 항목 추가 버튼 + 종류 칩 + 규격별로 묶은 목록(머리글에 건수·길이 소계).
  Widget _buildInputPane() {
    final filteredItems = _filteredItems;
    // 규격이 처음 나온 순서대로 묶는다(같은 규격의 항목은 붙어 보인다).
    final shapeOrder = <String>[];
    final byShape = <String, List<SteelCutItem>>{};
    for (final it in filteredItems) {
      if (!byShape.containsKey(it.shapeLabel)) shapeOrder.add(it.shapeLabel);
      byShape.putIfAbsent(it.shapeLabel, () => []).add(it);
    }
    final over = overLengthItems(_items, _maxStock);
    final mergeGroups = findMergeGroups(_items);
    final rows = <Widget>[
      if (_pendingSave) const PendingWritesBanner(count: 1),
      if (_specFilter.isNotEmpty) _buildSpecFilterBanner(),
      if (over.isNotEmpty) _buildOverBanner(over.length),
      if (mergeGroups.isNotEmpty) _buildMergeBanner(mergeGroups.length),
      for (final shape in shapeOrder) ...[
        _buildShapeHeader(shape, byShape[shape]!),
        if (!_collapsed.contains(shape))
          for (final it in byShape[shape]!) _buildItemCard(it),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "절단 항목",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: CuttingColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "규격을 선택하고 길이·수량을 입력하십시오",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('steel_add_item'),
              onPressed: _addItem,
              style: ElevatedButton.styleFrom(
                backgroundColor: CuttingColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add, color: CuttingColors.surface),
              label: const Text(
                "항목 추가",
                style: TextStyle(
                  color: CuttingColors.surface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (_items.isNotEmpty && _categories.length > 2) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildCategoryFilterChip(c),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.view_week_outlined,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "추가된 절단 항목이 없습니다.",
                            style: TextStyle(
                              color: CuttingColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "위 '항목 추가' 버튼으로 규격과 길이를 추가해 보십시오.",
                            style: TextStyle(
                              color: CuttingColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : (filteredItems.isEmpty
                      ? Center(
                          child: Text(
                            "'$_categoryFilter'에 맞는 항목이 없습니다.",
                            style: const TextStyle(
                              color: CuttingColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView(padding: EdgeInsets.zero, children: rows)),
          ),
          if (_items.isNotEmpty) _buildInputSummary(),
        ],
      ),
    );
  }

  // 입력 탭 맨 아래 고정 요약: 결과 탭으로 가지 않아도 총량이 보인다(세트 수를 곱한 값).
  Widget _buildInputSummary() {
    final lines = _resultLines();
    final pieces = lines.fold<int>(0, (s, l) => s + l.count);
    final mm = lines.fold<double>(0, (s, l) => s + l.totalMm);
    final w = weightTotals(lines);
    return Container(
      key: const Key('steel_input_summary'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CuttingColors.primarySoft.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CuttingColors.primary.withValues(alpha: 0.3)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            "항목 ${_items.length}건 · 총 $pieces개"
            "${_setMultiplier > 1 ? ' ($_setMultiplier세트)' : ''}",
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: CuttingColors.textPrimary,
            ),
          ),
          Text(
            "${(mm / 1000).toStringAsFixed(2)}m",
            key: const Key('steel_input_summary_len'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: CuttingColors.primaryDark,
            ),
          ),
          if (w.total != null)
            Text(
              "약 ${fmtKg(w.total!)}kg${w.unknownSpecs > 0 ? ' 이상' : ''}",
              key: const Key('steel_input_summary_kg'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: CuttingColors.primaryDark,
              ),
            ),
        ],
      ),
    );
  }

  // 규격 머리글: 눌러서 접고 펴는 종류 아이콘 + 규격 이름 + "3건 · 1250mm" + ⋮ 메뉴(규격 바꾸기·다른 규격으로 복제).
  Widget _buildShapeHeader(String shape, List<SteelCutItem> items) {
    final mm = items.fold(0.0, (a, i) => a + i.totalLength);
    final folded = _collapsed.contains(shape);
    return Padding(
      key: Key('steel_group_$shape'),
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: Key('steel_group_toggle_$shape'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => _toggleCollapse(shape),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                child: Row(
                  children: [
                    Icon(
                      folded
                          ? Icons.chevron_right_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                      color: CuttingColors.textSecondary,
                    ),
                    anyIcon(
                      iconForSteel(items.first.category),
                      size: 18,
                      color: CuttingColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        shape,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: CuttingColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "${items.length}건 · ${fmtMm(mm)}mm",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: CuttingColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            key: Key('steel_group_menu_$shape'),
            tooltip: '규격 묶음 작업',
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 20,
              color: CuttingColors.textSecondary,
            ),
            padding: EdgeInsets.zero,
            onSelected: (v) {
              if (v == 'change') _changeGroupShape(shape);
              if (v == 'copy') _copyGroup(shape);
              if (v == 'order') _reorderGroup(shape);
              if (v == 'only') {
                setState(() => _specFilter = _specFilter == shape ? '' : shape);
              }
              if (v == 'pick') _pickItemsInGroup(shape);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'change',
                child: Text('규격 바꾸기 (길이 그대로)'),
              ),
              const PopupMenuItem(value: 'copy', child: Text('다른 규격으로 복제')),
              const PopupMenuItem(value: 'order', child: Text('순서 바꾸기')),
              const PopupMenuItem(value: 'pick', child: Text('여러 항목 고르기')),
              PopupMenuItem(
                value: 'only',
                child: Text(_specFilter == shape ? '전체 규격 보기' : '이 규격만 보기'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 원자재(6000mm 등)보다 긴 항목이 있을 때: 배치에서 빠지므로 미리 알린다.
  Widget _buildOverBanner(int count) {
    return Container(
      key: const Key('steel_over_banner'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CuttingColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CuttingColors.danger.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "원자재(${fmtMm(_maxStock)}mm)보다 긴 항목 $count건 — 배치에서 빠집니다.",
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: CuttingColors.danger,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('steel_edit_stock'),
              onPressed: _showStockDialog,
              style: TextButton.styleFrom(
                foregroundColor: CuttingColors.danger,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.straighten_rounded, size: 16),
              label: const Text(
                "원자재 길이 바꾸기",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 카드를 길게 누르면 길이만 빨리 고친다(규격·개수·비고는 그대로. 창을 다 열지 않아도 된다).
  Future<void> _editLength(SteelCutItem item) async {
    HapticFeedback.selectionClick();
    final ctrl = TextEditingController(text: fmtMm(item.length));
    void bump(double d) {
      final cur = double.tryParse(ctrl.text.trim()) ?? 0;
      final next = cur + d;
      ctrl.text = fmtMm(next < 0 ? 0 : next);
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
    }

    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CuttingColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            cuttingDialogIcon(Icons.straighten_rounded),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                "길이 고치기",
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: CuttingColors.textPrimary,
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
            Text(
              "${item.shapeLabel} · ${item.qty}개",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('steel_len_field'),
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: CuttingColors.textPrimary,
              ),
              decoration: InputDecoration(
                suffixText: 'mm',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (s) => Navigator.pop(ctx, double.tryParse(s.trim())),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final d in const [-100.0, -10.0, 10.0, 100.0])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        key: Key('steel_len_step_${d.toStringAsFixed(0)}'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => bump(d),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: CuttingColors.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            d > 0
                                ? "+${d.toStringAsFixed(0)}"
                                : d.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: CuttingColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            key: const Key('steel_len_save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: CuttingColors.primary,
            ),
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(ctrl.text.trim())),
            child: const Text(
              "저장",
              style: TextStyle(color: CuttingColors.surface),
            ),
          ),
        ],
      ),
    );
    if (!mounted || v == null) return;
    if (v <= 0) {
      showCuttingSnack(context, "길이를 숫자로 적으십시오.", isError: true);
      return;
    }
    if (v == item.length) return;
    final updated = SteelCutItem(
      id: item.id,
      category: item.category,
      shapeLabel: item.shapeLabel,
      length: v,
      qty: item.qty,
      note: item.note,
    );
    setState(() {
      final idx = _items.indexWhere((e) => e.id == item.id);
      if (idx >= 0) _items[idx] = updated;
    });
    try {
      await _persistItems();
      await _logChange('EDIT', updated);
    } catch (e) {
      if (mounted) showCuttingSnack(context, "저장하지 못했습니다: $e", isError: true);
      return;
    }
    if (!mounted) return;
    showCuttingSnack(context, "길이를 ${fmtMm(v)}mm로 고쳤습니다.");
  }

  // 끝까지 기다리지 않는 자리에서 쓰는 저장(실패하면 알려만 준다).
  void _saveItems() {
    _persistItems().catchError((e) {
      if (mounted) showCuttingSnack(context, "저장하지 못했습니다: $e", isError: true);
    });
  }

  // 묶음에서 여러 항목을 골라 한꺼번에 지우거나 규격을 바꾼다(⋮ 메뉴 → 여러 항목 고르기).
  Future<void> _pickItemsInGroup(String shape) async {
    final group = _items.where((e) => e.shapeLabel == shape).toList();
    if (group.isEmpty) return;
    final picked = <String>{};
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CuttingColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    cuttingDialogIcon(Icons.checklist_rounded),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "여러 항목 고르기",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: CuttingColors.textPrimary,
                            ),
                          ),
                          Text(
                            shape,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      key: const Key('steel_pick_all'),
                      onPressed: () => setSheet(() {
                        if (picked.length == group.length) {
                          picked.clear();
                        } else {
                          picked
                            ..clear()
                            ..addAll(group.map((e) => e.id));
                        }
                      }),
                      child: Text(
                        picked.length == group.length ? "모두 지우기" : "모두 고르기",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final it in group)
                        CheckboxListTile(
                          key: Key('steel_pick_${it.id}'),
                          value: picked.contains(it.id),
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: CuttingColors.primary,
                          onChanged: (v) => setSheet(() {
                            if (v == true) {
                              picked.add(it.id);
                            } else {
                              picked.remove(it.id);
                            }
                          }),
                          title: Text(
                            "${fmtMm(it.length)} mm · ${it.qty}개"
                            "${it.note.isEmpty ? '' : ' · ${it.note}'}",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: CuttingColors.textPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('steel_pick_change'),
                        onPressed: picked.isEmpty
                            ? null
                            : () => Navigator.pop(ctx, 'change'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CuttingColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text("규격 바꾸기 (${picked.length})"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('steel_pick_delete'),
                        onPressed: picked.isEmpty
                            ? null
                            : () => Navigator.pop(ctx, 'delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CuttingColors.danger,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          "지우기 (${picked.length})",
                          style: const TextStyle(color: CuttingColors.surface),
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
    if (action == null || picked.isEmpty || !mounted) return;
    final before = List<SteelCutItem>.of(_items);
    final targets = _items.where((e) => picked.contains(e.id)).toList();
    if (action == 'delete') {
      setState(() => _items.removeWhere((e) => picked.contains(e.id)));
      _saveItems();
      for (final i in targets) {
        _logChange('DELETE', i);
      }
      showCuttingUndoSnack(
        context,
        "'$shape' ${targets.length}건을 지웠습니다.",
        onUndo: () {
          setState(() => _items = before);
          _saveItems();
        },
      );
      return;
    }
    final to = await pickSteelShape(context);
    if (to == null || !mounted) return;
    if (to.label == shape) {
      showCuttingSnack(context, "같은 규격입니다.", isError: true);
      return;
    }
    final next = [
      for (final i in _items)
        if (picked.contains(i.id))
          SteelCutItem(
            id: i.id,
            category: to.category,
            shapeLabel: to.label,
            length: i.length,
            qty: i.qty,
            note: i.note,
          )
        else
          i,
    ];
    setState(() => _items = next);
    _saveItems();
    for (final i in next.where((e) => picked.contains(e.id))) {
      _logChange('EDIT', i);
    }
    showCuttingUndoSnack(
      context,
      "${targets.length}건을 '${to.label}' 규격으로 바꿨습니다.",
      onUndo: () {
        setState(() => _items = before);
        _saveItems();
      },
    );
  }

  // 한 규격만 보고 있을 때 위에 뜨는 줄(전체로 돌아가는 단추).
  Widget _buildSpecFilterBanner() {
    return Container(
      key: const Key('steel_spec_filter'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: CuttingColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "'$_specFilter'만 보고 있습니다.",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: CuttingColors.primaryDark,
              ),
            ),
          ),
          TextButton(
            key: const Key('steel_spec_filter_clear'),
            onPressed: () => setState(() => _specFilter = ''),
            child: const Text("전체 보기"),
          ),
        ],
      ),
    );
  }

  // 한 규격 묶음의 항목을 끌어서 자를 순서대로 놓는다(⋮ 메뉴 → 순서 바꾸기).
  Future<void> _reorderGroup(String shape) async {
    final work = _items.where((e) => e.shapeLabel == shape).toList();
    if (work.length < 2) {
      showCuttingSnack(context, "항목이 둘 이상이어야 순서를 바꿉니다.", isError: true);
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CuttingColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    cuttingDialogIcon(Icons.swap_vert_rounded),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "순서 바꾸기",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: CuttingColors.textPrimary,
                            ),
                          ),
                          Text(
                            shape,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "행을 길게 눌러 끌면 자르는 순서가 바뀝니다.",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ReorderableListView.builder(
                    key: const Key('steel_reorder_list'),
                    shrinkWrap: true,
                    buildDefaultDragHandles: true,
                    itemCount: work.length,
                    onReorder: (o, n) => setSheet(() {
                      var ni = n;
                      if (ni > o) ni -= 1;
                      final moved = work.removeAt(o);
                      work.insert(ni, moved);
                    }),
                    itemBuilder: (_, i) {
                      final it = work[i];
                      return Container(
                        key: ValueKey(it.id),
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: CuttingColors.border),
                        ),
                        child: Row(
                          children: [
                            Text(
                              "${i + 1}",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "${fmtMm(it.length)} mm · ${it.qty}개"
                                "${it.note.isEmpty ? '' : ' · ${it.note}'}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: CuttingColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('steel_reorder_save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CuttingColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text(
                      "저장",
                      style: TextStyle(
                        color: CuttingColors.surface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true || !mounted) return;
    setState(() => _items = applyShapeOrder(_items, shape, work));
    try {
      await _persistItems();
    } catch (e) {
      if (mounted) showCuttingSnack(context, "저장하지 못했습니다: $e", isError: true);
      return;
    }
    if (!mounted) return;
    showCuttingSnack(context, "'$shape' 순서를 바꿨습니다.");
  }

  // 원자재 기준 길이를 입력 탭에서 바로 고친다(재단 계획 창까지 들어가지 않아도 된다).
  Future<void> _showStockDialog() async {
    final ctrl = TextEditingController(text: _stockLength.toStringAsFixed(0));
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CuttingColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            cuttingDialogIcon(Icons.straighten_rounded),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                "원자재 기준 길이",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: CuttingColors.textPrimary,
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
            Text(
              "자재 한 본의 길이입니다. 재단 계획 배치와 긴 항목 경고가 이 길이를 씁니다.",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('steel_stock_field'),
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: CuttingColors.textPrimary,
              ),
              decoration: InputDecoration(
                suffixText: 'mm',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, double.tryParse(v.trim())),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            key: const Key('steel_stock_save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: CuttingColors.primary,
            ),
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(ctrl.text.trim())),
            child: const Text(
              "저장",
              style: TextStyle(color: CuttingColors.surface),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (v == null || v <= 0) {
      if (v != null) {
        showCuttingSnack(context, "길이를 숫자로 적으십시오.", isError: true);
      }
      return;
    }
    setState(() => _stockLength = v);
    try {
      await _persistStockLength(v);
    } catch (e) {
      if (mounted) showCuttingSnack(context, "저장하지 못했습니다: $e", isError: true);
      return;
    }
    if (!mounted) return;
    showCuttingSnack(context, "원자재 기준 길이를 ${fmtMm(v)}mm로 바꿨습니다.");
  }

  // 같은 규격·같은 길이가 여러 건으로 나뉘어 있을 때 합치기를 권한다(결과는 어차피 합쳐 계산되지만 목록이 깔끔해진다).
  Widget _buildMergeBanner(int groups) {
    return Container(
      key: const Key('steel_merge_banner'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: CuttingColors.primarySoft.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "같은 규격·같은 길이가 나뉜 항목이 $groups묶음 있습니다.",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: CuttingColors.primaryDark,
              ),
            ),
          ),
          TextButton(
            key: const Key('steel_merge_all'),
            onPressed: _mergeAll,
            style: TextButton.styleFrom(
              foregroundColor: CuttingColors.primaryDark,
            ),
            child: const Text(
              "합치기",
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  // 카드의 개수 −/+ 버튼(맨손으로 누르는 폰이라 34dp, 복제 버튼과 간격을 둔다).
  Widget _qtyButton(Key key, IconData icon, VoidCallback? onTap) {
    return Material(
      color: onTap == null ? Colors.grey.shade100 : CuttingColors.primarySoft,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 20,
            color: onTap == null
                ? Colors.grey.shade400
                : CuttingColors.primaryDark,
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(SteelCutItem item) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: CuttingColors.danger,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _deleteItem(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: CuttingColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: InkWell(
          key: Key('steel_item_${item.id}'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => _editItem(item),
          onLongPress: () => _editLength(item),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              children: [
                // 큰 글씨는 1개 길이, 개수와 합계는 오른쪽 작은 글씨(튜브 컷팅과 같은 구조).
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${fmtMm(item.length)} mm",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: CuttingColors.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                      if (item.length > _maxStock && _maxStock > 0)
                        Text(
                          "원자재보다 깁니다",
                          key: Key('steel_over_${item.id}'),
                          style: const TextStyle(
                            color: CuttingColors.danger,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      if (item.note.isNotEmpty)
                        Text(
                          item.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: CuttingColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _qtyButton(
                          Key('qty_dec_${item.id}'),
                          Icons.remove_rounded,
                          item.qty > 1 ? () => _bumpQty(item, -1) : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            "${item.qty}개",
                            key: Key('qty_text_${item.id}'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: CuttingColors.textPrimary,
                            ),
                          ),
                        ),
                        _qtyButton(
                          Key('qty_inc_${item.id}'),
                          Icons.add_rounded,
                          () => _bumpQty(item, 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "= ${fmtMm(item.totalLength)} mm",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: CuttingColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _duplicateItem(item),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 20,
                      color: CuttingColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 지시서 글(복사·카카오톡이 함께 쓴다). 항목이 없으면 null.
  String? _instructionText() {
    final lines = _resultLines();
    if (lines.isEmpty) return null;
    return buildSteelInstructionText(
      projectName: widget.project.name,
      date: DateTime.now(),
      sets: _setMultiplier,
      lines: lines,
      stockLength: _stockLength,
      kerfMm: _bladeKerf,
    );
  }

  Future<void> _copyInstruction() async {
    final text = _instructionText();
    if (text == null) {
      showCuttingSnack(
        context,
        "복사할 항목이 없습니다. 먼저 절단 항목을 추가하십시오.",
        isError: true,
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showCuttingSnack(context, "지시서를 글로 복사했습니다. 메신저에 붙여넣으십시오.");
  }

  Future<void> _sendToKakao() async {
    final text = _instructionText();
    if (text == null) {
      showCuttingSnack(
        context,
        "보낼 항목이 없습니다. 먼저 절단 항목을 추가하십시오.",
        isError: true,
      );
      return;
    }
    if (await kakaoSender(text)) return;
    if (!mounted) return;
    try {
      await textSharer(text);
      if (!mounted) return;
      showCuttingSnack(context, "카카오톡을 찾지 못해 공유창으로 보냈습니다.");
    } catch (e) {
      if (!mounted) return;
      showCuttingSnack(context, "보내기 실패: $e", isError: true);
    }
  }

  // 결과 창: 제목줄 아이콘(재단 계획·PDF·카톡·글 복사) + 세트 수 + 규격별로 묶은 자를 길이 목록.
  Widget _buildResultPane() {
    final lines = _resultLines();
    final weights = weightTotals(lines);
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "재단 결과",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: CuttingColors.textPrimary,
                    ),
                  ),
                ),
              ),
              CutActionBar(
                showLabels: !_iconsUsed || _labelsPinned,
                onToggleLabels: _iconsUsed
                    ? () {
                        HapticFeedback.selectionClick();
                        setState(() => _labelsPinned = !_labelsPinned);
                      }
                    : null,
                actions: [
                  CutActionSpec(
                    key: const Key('steel_btn_optimize'),
                    label: "재단 계획",
                    icon: const CutBarIcon(size: 21),
                    onPressed: () {
                      _markIconsUsed();
                      if (_items.isEmpty) {
                        showCuttingSnack(
                          context,
                          "절단 항목을 먼저 추가하십시오.",
                          isError: true,
                        );
                        return;
                      }
                      _showOptimization();
                    },
                  ),
                  CutActionSpec(
                    key: const Key('steel_btn_export'),
                    label: "PDF 공유",
                    icon: const Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 19,
                      color: CuttingColors.primary,
                    ),
                    onPressed: () {
                      _markIconsUsed();
                      _exportInstructionSheet();
                    },
                  ),
                  CutActionSpec(
                    key: const Key('steel_btn_kakao'),
                    label: "카톡 보내기",
                    icon: const Icon(
                      Icons.chat_bubble_rounded,
                      size: 19,
                      color: CuttingColors.primary,
                    ),
                    onPressed: () {
                      _markIconsUsed();
                      _sendToKakao();
                    },
                  ),
                  CutActionSpec(
                    key: const Key('steel_btn_copy'),
                    label: "글 복사",
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 19,
                      color: CuttingColors.primary,
                    ),
                    onPressed: () {
                      _markIconsUsed();
                      _copyInstruction();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "세트 수 (전체 수량 배수)",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildSetStepper(),
            ],
          ),
          if (lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (shapeSubtotals(lines).length > 1)
                    _buildResultChip(
                      key: const Key('steel_fold_done'),
                      icon: Icons.unfold_less_rounded,
                      label: "다 자른 규격 접기",
                      on: _foldDone,
                      onTap: _toggleFoldDone,
                    ),
                  _buildResultChip(
                    key: const Key('steel_hide_done'),
                    icon: Icons.visibility_off_rounded,
                    label: "자른 줄 감추기",
                    on: _hideDone,
                    onTap: _toggleHideDone,
                  ),
                  if (shapeSubtotals(lines).length > 1)
                    _buildResultChip(
                      key: const Key('steel_sort_weight'),
                      icon: Icons.swap_vert_rounded,
                      label: "중량 큰 규격부터",
                      on: _sortByWeight,
                      onTap: _toggleSortWeight,
                    ),
                  // 잘랐음 표시가 하나라도 있을 때만 지우는 단추를 둔다.
                  if (_doneKeys.isNotEmpty)
                    _buildResultChip(
                      key: const Key('steel_clear_done'),
                      icon: Icons.restart_alt_rounded,
                      label: "잘랐음 지우기",
                      on: false,
                      onTap: _clearDone,
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: CuttingColors.surface,
                border: Border.all(color: CuttingColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CuttingResultView(
                lines: lines,
                summary: summarizeResult(lines, _doneKeys),
                orders: const [],
                done: _doneKeys,
                onToggle: _toggleDone,
                setMultiplier: _setMultiplier,
                specHeaders: true,
                // 잔재는 재단 계획 창에서만 다룬다(결과 탭에서 "저장했습니다"라고만 하면
                // 어디에 저장됐는지 알 수 없어 혼선만 생겼다).
                allDoneText: "모두 잘랐습니다.",
                specWeights: weights.bySpec,
                unknownWeightSpecs: weights.unknownSpecs,
                emptyMessage: "절단 항목을 먼저 추가하십시오.",
                collapsedSpecs: _resultFolded,
                onToggleSpec: _toggleResultFold,
                hideDoneLines: _hideDone,
                stockNote: _stockNote(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 새 자재만으로 자를 때 몇 본이 드는지. 재단 계획 창과 같은 계산(FFD)을 규격별로 돌려
  // 본수를 더한다. 잔재는 넣지 않는다 — 잔재를 쓰면 창에서 더 줄어든다.
  // 조각이 너무 많으면(수백 개) 계산을 건너뛰고 아무 글도 보여 주지 않는다.
  String _stockNote() {
    if (_stockLength <= 0) return '';
    final byShape = _collectPiecesByShape();
    var pieces = 0;
    for (final list in byShape.values) {
      pieces += list.length;
    }
    if (pieces == 0 || pieces > 400) return '';
    var bars = 0;
    for (final list in byShape.values) {
      final r = optimizeCutting(
        pieces: list,
        stockLength: _stockLength,
        kerf: _bladeKerf,
      );
      bars += r.barCount;
    }
    if (bars == 0) return '';
    return "새 원자재 ${fmtMm(_stockLength)} $bars본";
  }

  // 결과 탭 제목줄 아래의 켜고 끄는 칩(다 자른 규격 접기 · 자른 줄 감추기 · 중량 큰 규격부터).
  Widget _buildResultChip({
    required Key key,
    required IconData icon,
    required String label,
    required bool on,
    required VoidCallback onTap,
  }) {
    final fg = on ? Colors.white : Colors.grey.shade700;
    // 아이콘 줄과 같은 규칙: 처음 쓰는 동안은 이름을 붙여 주고, 써 본 뒤에는 아이콘만 둔다("?"로 다시 본다).
    final showLabel = !_iconsUsed || _labelsPinned;
    return Tooltip(
      message: label,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: showLabel
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
              : const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: on ? CuttingColors.primary : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: showLabel ? 16 : 20, color: fg),
              if (showLabel) ...[
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetStepper() {
    return Container(
      decoration: BoxDecoration(
        color: CuttingColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CuttingColors.primary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('steel_set_minus'),
            icon: const Icon(Icons.remove, color: CuttingColors.primary),
            onPressed: () {
              if (_setMultiplier <= 1) return;
              HapticFeedback.selectionClick();
              setState(() => _setMultiplier--);
              _persistSetMultiplier(_setMultiplier);
            },
          ),
          Text(
            "$_setMultiplier SET",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: CuttingColors.textPrimary,
            ),
          ),
          IconButton(
            key: const Key('steel_set_plus'),
            icon: const Icon(Icons.add, color: CuttingColors.primary),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _setMultiplier++);
              _persistSetMultiplier(_setMultiplier);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip(String label) {
    final bool selected = _categoryFilter == label;
    return Material(
      color: selected ? CuttingColors.primary : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _categoryFilter = label),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
