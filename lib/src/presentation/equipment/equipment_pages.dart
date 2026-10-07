// 장비 관리 대장 화면: 목록(요약·검색·걸러 보기), 등록·수정, 상세(점검 기한·이력), QR 라벨.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/common_widgets/swipe_to_delete.dart';
import '../../core/theme/app_icon_set.dart';
import '../../core/theme/app_tokens.dart';
import '../inventory/pages/barcode_scan.dart';
import '../steel_cutting/screens/steel_pdf_preview_page.dart';
import '../tube_cutting/cutting_action_bar.dart' show kakaoSender, textSharer;
import 'equipment_manual.dart';
import 'equipment_model.dart';
import 'equipment_pdf.dart';
import 'equipment_reminders.dart';
import 'equipment_store.dart';
import '../trash/trash_kinds.dart';

Future<void> _defaultShare(String text) async {
  if (await kakaoSender(text)) return;
  await textSharer(text);
}

/// 고르는 칩: 선택하면 청록 바탕에 흰 글씨(앱의 다른 화면과 같은 모양).
class _Choice extends StatelessWidget {
  final Key? chipKey;
  final Widget label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  const _Choice({
    Key? key,
    required this.label,
    required this.selected,
    this.onSelected,
    bool showCheckmark = false,
  }) : chipKey = key;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    key: chipKey,
    label: label,
    selected: selected,
    showCheckmark: false,
    selectedColor: AppColors.brand,
    backgroundColor: AppColors.surface,
    side: BorderSide(color: selected ? AppColors.brand : AppColors.line),
    labelStyle: TextStyle(
      fontWeight: FontWeight.w700,
      color: selected ? Colors.white : AppColors.text,
    ),
    onSelected: onSelected,
  );
}

/// 누르면 바로 실행하는 칩(예시 고르기): 테두리가 있어 눌러지는 것으로 보인다.
class _Action extends StatelessWidget {
  final Key? chipKey;
  final Widget label;
  final VoidCallback? onPressed;
  const _Action({Key? key, required this.label, this.onPressed}) : chipKey = key;

  @override
  Widget build(BuildContext context) => ActionChip(
    key: chipKey,
    label: label,
    backgroundColor: AppColors.surface,
    side: const BorderSide(color: AppColors.line),
    labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
    onPressed: onPressed,
  );
}

Color dueColor(DueState s) => switch (s) {
  DueState.overdue => AppColors.danger,
  DueState.soon => AppColors.caution,
  DueState.ok => AppColors.ok,
  DueState.none => AppColors.textFaint,
};

// ───────────────────────── 목록 ─────────────────────────

class EquipmentLedgerPage extends StatefulWidget {
  final LedgerView initialView;
  final Future<void> Function(String text) share;
  final Future<String?> Function(BuildContext context) scan;
  final DateTime Function()? now;
  const EquipmentLedgerPage({
    super.key,
    this.initialView = LedgerView.all,
    this.share = _defaultShare,
    this.scan = scanBarcode,
    this.now,
  });

  @override
  State<EquipmentLedgerPage> createState() => _EquipmentLedgerPageState();
}

class _EquipmentLedgerPageState extends State<EquipmentLedgerPage> {
  List<Equipment> _all = [];
  bool _loaded = false;
  late LedgerView _view = widget.initialView;
  EquipCategory? _category;
  final _search = TextEditingController();

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _reload(syncFirst: true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload({bool syncFirst = false}) async {
    var list = await EquipmentStore.load();
    if (mounted) {
      setState(() {
        _all = list;
        _loaded = true;
      });
    }
    if (syncFirst) {
      // 다른 폰에서 올린 것을 받아 온다(통신이 없으면 조용히 넘어간다).
      try {
        await EquipmentStore.sync.syncNow();
        list = await EquipmentStore.load();
        if (mounted) setState(() => _all = list);
      } catch (_) {}
    }
    rescheduleEquipmentReminders(list);
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _open(Equipment e) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => EquipmentDetailPage(id: e.id, share: widget.share, now: widget.now),
      ),
    );
    _reload();
  }

  Future<void> _add({String? presetName}) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => EquipmentEditPage(now: widget.now, presetName: presetName)),
    );
    _reload();
  }

  Future<void> _scan() async {
    final code = await widget.scan(context);
    if (code == null || !mounted) return;
    final e = EquipmentStore.findByCode(_all, code);
    if (e == null) {
      _toast('이 QR·바코드와 맞는 장비가 없습니다');
      return;
    }
    _open(e);
  }

  Future<void> _export(String what) async {
    final now = _now;
    try {
      switch (what) {
        case 'due':
          await widget.share(buildDueText(_all, now));
        case 'csv':
          final dir = await getTemporaryDirectory();
          final f = File('${dir.path}/장비대장_${now.millisecondsSinceEpoch}.csv');
          await f.writeAsString(buildLedgerCsv(_all, now));
          // ignore: deprecated_member_use
          await Share.shareXFiles([XFile(f.path)], text: '장비 관리 대장 (엑셀)');
        case 'pdf':
          final bytes = await buildLedgerPdf(_all, now);
          if (!mounted) return;
          await _preview(bytes, '장비관리대장_${dateLabel(now)}.pdf', '장비 관리 대장');
        case 'labels':
          final bytes = await buildLabelsPdf(sortLedger(_all, now).where((e) => !e.isRetired).toList());
          if (!mounted) return;
          await _preview(bytes, 'QR라벨_${dateLabel(now)}.pdf', 'QR 라벨');
      }
    } catch (e) {
      _toast('만들지 못했습니다: $e');
    }
  }

  Future<void> _preview(Uint8List bytes, String fileName, String title) {
    return Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SteelPdfPreviewPage(
          bytes: bytes,
          fileName: fileName,
          title: title,
          onShare: () async {
            final dir = await getTemporaryDirectory();
            final f = File('${dir.path}/$fileName');
            await f.writeAsBytes(bytes);
            // ignore: deprecated_member_use
            await Share.shareXFiles([XFile(f.path)], text: title);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final s = summarize(_all, now);
    final list = filterLedger(_all, now, query: _search.text, category: _category, view: _view);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('장비 관리 대장'),
        actions: [
          IconButton(
            key: const Key('equip_scan'),
            tooltip: 'QR·바코드로 찾기',
            icon: const Icon(AppIcons.scan),
            onPressed: _scan,
          ),
          PopupMenuButton<String>(
            key: const Key('equip_more'),
            icon: const Icon(AppIcons.more),
            onSelected: _export,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'due', child: Text('기한 지난·임박 장비 (카톡)')),
              PopupMenuItem(value: 'csv', child: Text('엑셀로 내보내기')),
              PopupMenuItem(value: 'pdf', child: Text('관리 대장 PDF')),
              PopupMenuItem(value: 'labels', child: Text('QR 라벨 인쇄용 PDF')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('equip_add'),
        onPressed: () => _add(),
        icon: const Icon(AppIcons.add),
        label: const Text('장비 등록'),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _summaryStrip(s),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: TextField(
                    key: const Key('equip_search'),
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(AppIcons.search),
                      hintText: '이름·관리번호·시리얼',
                      filled: true,
                      fillColor: AppColors.surface,
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _chip('전체', _category == null, () => setState(() => _category = null)),
                      for (final c in EquipCategory.values)
                        _chip(c.label, _category == c, () => setState(() => _category = c)),
                    ],
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? _empty()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          itemCount: list.length,
                          itemBuilder: (_, i) => _card(list[i], now),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
    child: _Choice(
      label: Text(label),
      selected: sel,
      showCheckmark: false,
      onSelected: (_) => onTap(),
    ),
  );

  Widget _summaryStrip(LedgerSummary s) {
    Widget stat(String key, String label, int n, Color color, LedgerView v) {
      final sel = _view == v;
      return Expanded(
        child: InkWell(
          key: Key(key),
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _view = sel && v != LedgerView.all ? LedgerView.all : v),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? color.withValues(alpha: 0.14) : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? color : Colors.transparent, width: 1.5),
            ),
            child: Column(
              children: [
                Text('$n', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
              ],
            ),
          ),
        ),
      );
    }

    // "기한" 칸은 만료+임박을 합쳐 한 번에 보게 한다.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          stat('equip_stat_all', '전체', s.total, AppColors.text, LedgerView.all),
          const SizedBox(width: 8),
          stat('equip_stat_due', '기한 지남·임박', s.overdue + s.soon, s.overdue > 0 ? AppColors.danger : AppColors.caution, LedgerView.due),
        ],
      ),
    );
  }

  Widget _empty() {
    if (_all.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(AppIcons.list, size: 44, color: AppColors.textFaint),
          const SizedBox(height: 12),
          const Text(
            '등록한 장비가 없습니다',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            '아래 예시를 누르면 이름과 점검 주기가 채워진 채로 등록 화면이 열립니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSub),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final p in kEquipPresets)
                _Action(
                  key: Key('equip_preset_${p.name}'),
                  label: Text(p.name),
                  onPressed: () => _add(presetName: p.name),
                ),
            ],
          ),
        ],
      );
    }
    return const Center(
      child: Text('조건에 맞는 장비가 없습니다', key: Key('equip_none'), style: AppText.sub),
    );
  }

  Widget _card(Equipment e, DateTime now) {
    final st = e.dueState(now);
    final color = dueColor(st);
    final label = dueLabel(e, now);
    return SwipeToDelete(
      itemKey: ValueKey('equip_swipe_${e.id}'),
      onDelete: () => _delete(e),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        color: AppColors.surface,
        child: InkWell(
          key: Key('equip_card_${e.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(e),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 5, height: 46, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [if (e.assetNo.isNotEmpty) e.assetNo, e.name].join('  '),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: e.isRetired ? AppColors.textFaint : AppColors.text,
                          decoration: e.isRetired ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          e.category.label,
                          [e.maker, e.model].where((v) => v.isNotEmpty).join(' '),
                          if (e.location.isNotEmpty) e.location,
                        ].where((v) => v.isNotEmpty).join(' · '),
                        style: const TextStyle(fontSize: 13, color: AppColors.textSub),
                      ),
                      if (e.status != EquipStatus.ok)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _badge(e.status.label, AppColors.textSub),
                        ),
                    ],
                  ),
                ),
                if (label.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
                      Text(
                        e.nextDue == null ? '' : dateLabel(e.nextDue!),
                        style: const TextStyle(fontSize: 11, color: AppColors.textFaint),
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

  /// 목록에서 곧바로 빼고 휴지통으로 옮긴다(알림 예약도 취소). "되돌리기"를 누르면 휴지통에서
  /// 같은 장비(이력 포함)를 되살리고 알림도 다시 잡는다(10-02).
  void _delete(Equipment e) {
    setState(() => _all = [..._all]..removeWhere((x) => x.id == e.id));
    final done = trashEquipment(e);
    showTrashUndo(
      context,
      [if (e.assetNo.isNotEmpty) e.assetNo, e.name].join(' '),
      done,
      onRestored: () async {
        final all = await EquipmentStore.load();
        if (mounted) setState(() => _all = all);
      },
    );
  }

  Widget _badge(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
    child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c)),
  );
}

// ───────────────────────── 등록·수정 ─────────────────────────

class EquipmentEditPage extends StatefulWidget {
  final Equipment? existing;
  final String? presetName;
  final DateTime Function()? now;
  const EquipmentEditPage({super.key, this.existing, this.presetName, this.now});

  @override
  State<EquipmentEditPage> createState() => _EquipmentEditPageState();
}

class _EquipmentEditPageState extends State<EquipmentEditPage> {
  late final _name = TextEditingController(text: widget.existing?.name ?? widget.presetName ?? '');
  late final _assetNo = TextEditingController(text: widget.existing?.assetNo ?? '');
  late final _maker = TextEditingController(text: widget.existing?.maker ?? kEquipPresetDetails[widget.presetName]?.maker ?? '');
  late final _model = TextEditingController(text: widget.existing?.model ?? kEquipPresetDetails[widget.presetName]?.model ?? '');
  late final _serial = TextEditingController(text: widget.existing?.serial ?? '');
  late final _location = TextEditingController(text: widget.existing?.location ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  // 제원 줄(항목·값). 예시를 골랐으면 그 제원으로 채운다.
  late final List<(TextEditingController, TextEditingController)> _specs = [
    for (final s in widget.existing?.specs ?? kEquipPresetDetails[widget.presetName]?.specs ?? const <(String, String)>[])
      (TextEditingController(text: s.$1), TextEditingController(text: s.$2)),
  ];
  late EquipCategory _category = widget.existing?.category ?? _presetCategory();
  late int _interval = widget.existing?.intervalMonths ?? _presetMonths();
  late DateTime? _lastDone = widget.existing?.lastDone;
  String? _error;

  DateTime get _now => (widget.now ?? DateTime.now)();

  EquipCategory _presetCategory() {
    for (final p in kEquipPresets) {
      if (p.name == widget.presetName) return p.category;
    }
    return EquipCategory.work;
  }

  int _presetMonths() {
    for (final p in kEquipPresets) {
      if (p.name == widget.presetName) return p.months;
    }
    return 1; // 정기 점검 월 1회
  }

  @override
  void dispose() {
    for (final c in [_name, _assetNo, _maker, _model, _serial, _location, _note]) {
      c.dispose();
    }
    for (final r in _specs) {
      r.$1.dispose();
      r.$2.dispose();
    }
    super.dispose();
  }

  /// 제원 줄을 곧바로 빼고, "되돌리기"를 누르면 같은 글로 같은 자리에 다시 넣는다.
  void _removeSpec(int i) {
    if (i < 0 || i >= _specs.length) return;
    final r = _specs[i];
    final name = r.$1.text, value = r.$2.text;
    setState(() => _specs.removeAt(i));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      r.$1.dispose();
      r.$2.dispose();
    });
    showDeleteUndo(
      context,
      [name.trim(), value.trim()].where((v) => v.isNotEmpty).join(' '),
      onUndo: () {
        if (!mounted) return;
        setState(() => _specs.insert(
              i.clamp(0, _specs.length),
              (TextEditingController(text: name), TextEditingController(text: value)),
            ));
      },
    );
  }

  Future<void> _pickDate() async {
    final now = _now;
    final d = await showDatePicker(
      context: context,
      initialDate: _lastDone ?? now,
      firstDate: DateTime(2000),
      // 점검 기록 창은 10년 뒤까지 고를 수 있어, 그 날짜도 범위 안에 들게 한다(10-07).
      lastDate: DateTime(now.year + 10, 12, 31),
    );
    if (d != null) setState(() => _lastDone = d);
  }

  bool _saving = false;

  // 저장 중에 다시 누르면 같은 장비가 두 대 생기고 목록 화면까지 닫혔다(10-07).
  Future<void> _save() async {
    if (_saving) return;
    _saving = true;
    try {
      await _saveOnce();
    } finally {
      _saving = false;
    }
  }

  Future<void> _saveOnce() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '장비 이름을 적어 주십시오');
      return;
    }
    // 같은 관리번호가 이미 있으면 막는다(QR로 찾을 때 헷갈리지 않게).
    final no = _assetNo.text.trim();
    if (no.isNotEmpty) {
      final all = await EquipmentStore.load();
      final dup = all.any(
        (e) => e.id != widget.existing?.id && e.assetNo.trim().toLowerCase() == no.toLowerCase(),
      );
      if (dup) {
        setState(() => _error = '같은 관리번호($no)가 이미 있습니다');
        return;
      }
    }
    final base = widget.existing ??
        Equipment(id: EquipmentStore.newId(_now), name: name, createdAt: _now);
    final saved = base.copyWith(
      name: name,
      assetNo: no,
      category: _category,
      maker: _maker.text.trim(),
      model: _model.text.trim(),
      serial: _serial.text.trim(),
      location: _location.text.trim(),
      intervalMonths: _interval,
      lastDone: _lastDone,
      // 마지막 점검일·주기를 바꾸면 전에 직접 정한 다음 기한은 버린다(10-07: 화면은 새 기한을 보여 주고
      // 저장 뒤 목록·알림은 옛 날짜에 머물렀다).
      dueOverride: widget.existing != null &&
              (widget.existing!.intervalMonths != _interval || widget.existing!.lastDone != _lastDone)
          ? null
          : widget.existing?.dueOverride,
      note: _note.text.trim(),
      specs: [
        for (final r in _specs)
          if (r.$1.text.trim().isNotEmpty) (r.$1.text.trim(), r.$2.text.trim()),
      ],
    );
    await EquipmentStore.put(saved);
    rescheduleEquipmentReminders(await EquipmentStore.load());
    if (mounted && ModalRoute.of(context)?.isCurrent == true) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    Widget field(String key, TextEditingController c, String label, {String? hint, int lines = 1}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        key: Key(key),
        controller: c,
        maxLines: lines,
        decoration: InputDecoration(labelText: label, hintText: hint, filled: true, fillColor: AppColors.surface),
      ),
    );
    final due = _interval > 0 && _lastDone != null ? addMonths(dayOnly(_lastDone!), _interval) : null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.existing == null ? '장비 등록' : '장비 정보 수정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          field('equip_name', _name, '장비 이름', hint: '예: 고속절단기'),
          if (widget.existing == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final p in kEquipPresets)
                    _Action(
                      label: Text(p.name, style: const TextStyle(fontSize: 12)),
                      onPressed: () => setState(() {
                        _name.text = p.name;
                        _category = p.category;
                        _interval = p.months;
                        // 제조사·모델·제원이 있는 예시면 빈 칸만 채운다
                        final d = kEquipPresetDetails[p.name];
                        if (d != null) {
                          if (_maker.text.trim().isEmpty) _maker.text = d.maker;
                          if (_model.text.trim().isEmpty) _model.text = d.model;
                          if (_specs.every((r) => r.$1.text.trim().isEmpty && r.$2.text.trim().isEmpty)) {
                            _specs
                              ..clear()
                              ..addAll([for (final s in d.specs) (TextEditingController(text: s.$1), TextEditingController(text: s.$2))]);
                          }
                        }
                      }),
                    ),
                ],
              ),
            ),
          field('equip_assetno', _assetNo, '관리번호 (QR 라벨에 들어갑니다)', hint: '예: CT-001'),
          Wrap(
            spacing: 8,
            children: [
              for (final c in EquipCategory.values)
                _Choice(
                  key: Key('equip_cat_${c.id}'),
                  label: Text(c.label),
                  selected: _category == c,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _category = c),
                ),
            ],
          ),
          const SizedBox(height: 12),
          field('equip_maker', _maker, '제조사'),
          field('equip_model', _model, '모델'),
          field('equip_serial', _serial, '시리얼 번호'),
          field('equip_location', _location, '보관 위치', hint: '예: 계장 공구함 2번'),
          const SizedBox(height: 4),
          const Text('정기 점검', style: AppText.title),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final m in const [0, 1, 3, 6, 12])
                _Choice(
                  key: Key('equip_interval_$m'),
                  label: Text(intervalLabel(m)),
                  selected: _interval == m,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _interval = m),
                ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('equip_lastdone'),
            onPressed: _pickDate,
            icon: const Icon(AppIcons.calendar, size: 18),
            label: Text(_lastDone == null ? '마지막 점검일 고르기' : '마지막 점검일 ${dateLabel(_lastDone!)}'),
          ),
          if (due != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '다음 점검은 ${dateLabel(due)}입니다 (마지막 점검일 + $_interval개월)',
                key: const Key('equip_due_preview'),
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.brand),
              ),
            )
          // 주기만 정하고 점검일을 안 고르면 기한·7일 전 알림이 생기지 않는다(10-07: 알려 주지 않았다).
          else if (_interval > 0 && _lastDone == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '마지막 점검일을 고르면 다음 점검 기한과 7일 전 알림이 생깁니다.',
                key: Key('equip_due_hint'),
                style: TextStyle(color: AppColors.textSub, fontSize: 13),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Text('제원', style: AppText.title)),
              TextButton.icon(
                key: const Key('equip_spec_add'),
                onPressed: () => setState(() => _specs.add((TextEditingController(), TextEditingController()))),
                icon: const Icon(AppIcons.add, size: 18),
                label: const Text('줄 더하기'),
              ),
            ],
          ),
          if (_specs.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('전동기 출력·중량·작업 범위처럼 장비의 제원을 줄마다 적습니다.', style: AppText.sub),
            ),
          // 줄은 번호를 잡고 왼쪽으로 밀어 지운다(글 칸은 밀기를 먹는다). 지운 뒤 "되돌리기"(10-02).
          for (var i = 0; i < _specs.length; i++)
            SwipeToDelete(
              itemKey: ObjectKey(_specs[i].$1),
              radius: 8,
              onDelete: () => _removeSpec(i),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      key: Key('equip_spec_no_$i'),
                      width: 28,
                      child: Text(
                        '${i + 1}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSub),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: TextField(
                        key: Key('equip_spec_name_$i'),
                        controller: _specs[i].$1,
                        decoration: const InputDecoration(labelText: '항목', hintText: '예: 전동기', isDense: true, filled: true, fillColor: AppColors.surface),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: Key('equip_spec_value_$i'),
                        controller: _specs[i].$2,
                        decoration: const InputDecoration(labelText: '값', hintText: '예: 1700 W', isDense: true, filled: true, fillColor: AppColors.surface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_specs.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('지울 줄은 번호를 잡고 왼쪽으로 끝까지 미십시오.', key: Key('equip_spec_hint'), style: AppText.caption),
            ),
          const SizedBox(height: 8),
          field('equip_note', _note, '메모', lines: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
            ),
          FilledButton(key: const Key('equip_save'), onPressed: _save, child: const Text('저장')),
        ],
      ),
    );
  }
}

// ───────────────────────── 상세 ─────────────────────────

class EquipmentDetailPage extends StatefulWidget {
  final String id;
  final Future<void> Function(String text) share;
  final DateTime Function()? now;
  const EquipmentDetailPage({super.key, required this.id, this.share = _defaultShare, this.now});

  @override
  State<EquipmentDetailPage> createState() => _EquipmentDetailPageState();
}

class _EquipmentDetailPageState extends State<EquipmentDetailPage> {
  Equipment? _e;
  bool _loaded = false;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final all = await EquipmentStore.load();
    Equipment? found;
    for (final e in all) {
      if (e.id == widget.id) found = e;
    }
    if (mounted) {
      setState(() {
        _e = found;
        _loaded = true;
      });
    }
  }

  Future<void> _put(Equipment e) async {
    await EquipmentStore.put(e);
    rescheduleEquipmentReminders(await EquipmentStore.load());
    await _reload();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _inspect() async {
    final e = _e!;
    final result = await showModalBottomSheet<Equipment>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _InspectSheet(equipment: e, now: _now),
    );
    if (result != null) {
      await _put(result);
      _toast('점검을 기록했습니다');
    }
  }

  Future<void> _edit() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => EquipmentEditPage(existing: _e, now: widget.now)),
    );
    _reload();
  }

  Future<void> _more(String action) async {
    final e = _e!;
    switch (action) {
      case 'share':
        await widget.share(buildEquipmentText(e, _now));
      case 'repair':
        await _put(recordRepair(e, at: _now));
      case 'usable':
        await _put(markUsable(e, at: _now));
      case 'retire':
        if (await _confirm('이 장비를 폐기 처리하시겠습니까?', '기록은 남고, 기한 알림은 더 오지 않습니다.')) {
          await _put(retire(e, at: _now));
        }
      case 'delete':
        if (await _confirm('이 장비를 대장에서 지우시겠습니까?', '기록과 함께 휴지통으로 옮깁니다. 30일 안에는 휴지통에서 되살릴 수 있습니다.')) {
          await trashEquipment(e);
          if (mounted) Navigator.pop(context);
        }
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            key: const Key('equip_confirm_yes'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (e == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('장비를 찾을 수 없습니다')));
    }
    final now = _now;
    final st = e.dueState(now);
    final color = dueColor(st);
    final label = dueLabel(e, now);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(e.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            key: const Key('equip_edit'),
            tooltip: '정보 수정',
            icon: const Icon(AppIcons.edit),
            onPressed: _edit,
          ),
          PopupMenuButton<String>(
            key: const Key('equip_detail_more'),
            icon: const Icon(AppIcons.more),
            onSelected: _more,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'share', child: Text('카톡으로 보내기')),
              if (e.status == EquipStatus.ok && !e.isRetired) const PopupMenuItem(value: 'repair', child: Text('수리·점검 중으로')),
              if (e.status == EquipStatus.repair) const PopupMenuItem(value: 'usable', child: Text('다시 사용 가능으로')),
              if (!e.isRetired) const PopupMenuItem(value: 'retire', child: Text('폐기 처리')),
              const PopupMenuItem(value: 'delete', child: Text('대장에서 지우기')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            key: const Key('equip_due_card'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.isRetired
                            ? '폐기한 장비'
                            : (e.nextDue == null ? '점검 기한 없음' : '다음 점검 ${dateLabel(e.nextDue!)}'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          e.status.label,
                          if (e.lastDone != null) '마지막 점검 ${dateLabel(e.lastDone!)}',
                        ].join(' · '),
                        style: const TextStyle(fontSize: 13, color: AppColors.textSub),
                      ),
                    ],
                  ),
                ),
                if (label.isNotEmpty)
                  Text(label, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!e.isRetired)
            FilledButton.icon(
              key: const Key('equip_inspect'),
              onPressed: _inspect,
              icon: const Icon(AppIcons.check, size: 18),
              label: const Text('점검 기록'),
            ),
          const SizedBox(height: 16),
          _info('관리번호', e.assetNo),
          _info('분류', e.category.label),
          _info('제조사·모델', [e.maker, e.model].where((v) => v.isNotEmpty).join(' ')),
          _info('시리얼', e.serial),
          _info('보관 위치', e.location),
          _info('점검 주기', intervalLabel(e.intervalMonths)),
          if (e.specs.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('제원', style: AppText.title),
            const SizedBox(height: 4),
            for (final s in e.specs) _info(s.$1, s.$2),
          ],
          _info('메모', e.note),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('equip_qr'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => EquipmentQrPage(equipment: e)),
            ),
            icon: const Icon(AppIcons.qr, size: 18),
            label: const Text('QR 라벨'),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            key: const Key('equip_manual'),
            onPressed: () => openEquipManual(
              context,
              key: manualKeyFor(maker: e.maker, model: e.model, id: e.id),
              title: e.model.isNotEmpty ? '${e.maker} ${e.model}'.trim() : e.name,
            ),
            icon: const Icon(AppIcons.pdf, size: 18),
            label: const Text('제조사 설명서'),
          ),
          const SizedBox(height: 20),
          const Text('점검·수리 기록', style: AppText.title),
          const SizedBox(height: 8),
          if (e.events.isEmpty)
            const Text('아직 기록이 없습니다', style: AppText.sub)
          else
            for (final ev in e.events) _event(ev),
        ],
      ),
    );
  }

  Widget _info(String k, String v) => v.trim().isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 100, child: Text(k, style: const TextStyle(fontSize: 13, color: AppColors.textSub))),
              Expanded(child: Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
            ],
          ),
        );

  Widget _event(EquipEvent ev) {
    final fail = ev.result == kResultFail;
    final c = fail ? AppColors.danger : AppColors.textSub;
    final title = [
      ev.type.label,
      if (ev.result.isNotEmpty) ev.result,
    ].join(' · ');
    final sub = [
      if (ev.by.isNotEmpty) ev.by,
      if (ev.certNo.isNotEmpty) '성적서 ${ev.certNo}',
      if (ev.note.isNotEmpty) ev.note,
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      color: AppColors.surface,
      child: ListTile(
        dense: true,
        leading: Icon(_eventIcon(ev.type), color: c, size: 20),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: fail ? AppColors.danger : AppColors.text)),
        subtitle: sub.isEmpty ? null : Text(sub),
        trailing: Text(dateLabel(ev.at), style: const TextStyle(fontSize: 12, color: AppColors.textFaint)),
      ),
    );
  }

  IconData _eventIcon(EventType t) => switch (t) {
    EventType.cal => AppIcons.check,
    EventType.check => AppIcons.scan,
    EventType.repair => AppIcons.settings,
    EventType.out => AppIcons.send,
    EventType.back => AppIcons.undo,
    EventType.align => AppIcons.filter,
    EventType.note => AppIcons.info,
  };
}

// ── 점검 기록 창 ──

class _InspectSheet extends StatefulWidget {
  final Equipment equipment;
  final DateTime now;
  const _InspectSheet({required this.equipment, required this.now});

  @override
  State<_InspectSheet> createState() => _InspectSheetState();
}

class _InspectSheetState extends State<_InspectSheet> {
  String _result = kResultPass;
  late DateTime _date = dayOnly(widget.now);
  DateTime? _nextDue;
  final _by = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _by.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool next}) async {
    final d = await showDatePicker(
      context: context,
      initialDate: next ? (_nextDue ?? addMonths(_date, widget.equipment.intervalMonths == 0 ? 1 : widget.equipment.intervalMonths)) : _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(widget.now.year + 10, 12, 31),
    );
    if (d != null) setState(() => next ? _nextDue = d : _date = d);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.equipment;
    final auto = e.intervalMonths > 0 ? addMonths(_date, e.intervalMonths) : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('점검 기록', style: AppText.title),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final r in [kResultPass, kResultFail])
                  _Choice(
                    key: Key('inspect_result_$r'),
                    label: Text(r),
                    selected: _result == r,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _result = r),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('inspect_date'),
              onPressed: () => _pick(next: false),
              icon: const Icon(AppIcons.calendar, size: 18),
              label: Text('점검일 ${dateLabel(_date)}'),
            ),
            const SizedBox(height: 8),
            TextField(key: const Key('inspect_by'), controller: _by, decoration: const InputDecoration(labelText: '점검자 (선택)')),
            TextField(key: const Key('inspect_note'), controller: _note, decoration: const InputDecoration(labelText: '메모 (선택)')),
            const SizedBox(height: 8),
            if (_result != kResultFail)
              OutlinedButton.icon(
                key: const Key('inspect_next'),
                onPressed: () => _pick(next: true),
                icon: const Icon(AppIcons.calendarEdit, size: 18),
                label: Text(
                  _nextDue != null
                      ? '다음 점검 ${dateLabel(_nextDue!)} (직접 정함)'
                      : (auto != null ? '다음 점검 ${dateLabel(auto)} (${intervalLabel(e.intervalMonths)} 자동)' : '다음 점검일 정하기 (선택)'),
                ),
              )
            else
              const Text('불량이면 "수리·점검 중"으로 바뀌고 기한은 그대로 둡니다.', style: TextStyle(fontSize: 13, color: AppColors.danger)),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('inspect_save'),
              onPressed: () => Navigator.pop(
                context,
                recordInspection(
                  e,
                  at: _date,
                  result: _result,
                  by: _by.text,
                  note: _note.text,
                  nextDue: _nextDue,
                ),
              ),
              child: const Text('기록 저장'),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── QR 라벨 ─────────────────────────

class EquipmentQrPage extends StatelessWidget {
  final Equipment equipment;
  const EquipmentQrPage({super.key, required this.equipment});

  @override
  Widget build(BuildContext context) {
    final e = equipment;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('QR 라벨')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrCodeView(key: const Key('equip_qr_view'), data: e.qrText, size: 220),
              const SizedBox(height: 16),
              Text(
                [if (e.assetNo.isNotEmpty) e.assetNo, e.name].join('  '),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              SelectableText(e.qrText, style: const TextStyle(fontSize: 13, color: AppColors.textSub)),
              const SizedBox(height: 16),
              const Text(
                '이 QR을 라벨로 인쇄해 장비에 붙이면, 대장 화면의 스캔 단추로 찍어 바로 이 장비를 열 수 있습니다. '
                '인쇄는 대장 화면 오른쪽 위 더보기의 "QR 라벨 인쇄용 PDF"에서 한꺼번에 만듭니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSub),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Clipboard.setData(ClipboardData(text: e.qrText)),
                child: const Text('QR 글 복사'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
