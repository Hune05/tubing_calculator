import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../tube_cutting/cutting_pending_banner.dart';
import '../../tube_cutting/cutting_theme.dart';
import '../material_catalog.dart';
import 'material_catalog_store.dart';

/// 자재 한 종을 한 장에 모아 보는 화면. 재고·규격·보관 위치·최근 기록을
/// 한 곳에서 보고, 여기서 바로 수량을 고친다.
///
/// 🚀 [고침] 혼자 쓰는 앱이라 불출·반납은 같은 일을 두 번 하게 만들었다.
/// 재고 수량은 재고조사에서 맞춘다.
/// (예전에는 보는 화면[자재 현황]과 고치는 화면[자재 통합 관리]이 갈려 있어서
///  같은 자재를 두 군데서 따로 봐야 했다.)
class InventoryItemPage extends StatelessWidget {
  final String docId;
  final String workerName;

  const InventoryItemPage({
    super.key,
    required this.docId,
    required this.workerName,
  });

  @override
  Widget build(BuildContext context) {
    return CuttingTheme(
      child: Scaffold(
        backgroundColor: CuttingColors.surface,
        appBar: AppBar(
          backgroundColor: CuttingColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: CuttingColors.textPrimary),
          title: const Text(
            "자재",
            style: TextStyle(
              color: CuttingColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(kInventoryCollection)
              .doc(docId)
              .snapshots(includeMetadataChanges: true),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(child: Text("자재를 불러오지 못했습니다. 통신을 확인하십시오."));
            }
            if (!snap.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: CuttingColors.primary),
              );
            }
            final data = snap.data!.data();
            if (data == null) {
              return const Center(
                child: Text(
                  "지워진 자재입니다.",
                  style: TextStyle(
                    color: CuttingColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }
            return _Body(
              docId: docId,
              workerName: workerName,
              data: data,
              // 통신이 없어 아직 서버로 못 올라간 고침이 있으면 알려 준다.
              pending: snap.data!.metadata.hasPendingWrites ? 1 : 0,
            );
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final String docId;
  final String workerName;
  final Map<String, dynamic> data;
  final int pending;

  const _Body({
    required this.docId,
    required this.workerName,
    required this.data,
    this.pending = 0,
  });

  String get _name => (data['name'] ?? '이름 없음').toString();
  String get _unit => (data['unit'] ?? 'EA').toString();
  int get _qty => (data['qty'] as num?)?.toInt() ?? 0;
  int get _minQty =>
      ((data['minQty'] ?? data['min_qty']) as num?)?.toInt() ?? 0;
  // 원자재 한 본의 길이(mm). 컷팅에서 몇 본 드는지 셀 때 쓴다(비었으면 6000).
  int get _barLengthMm => (data['barLengthMm'] as num?)?.toInt() ?? 0;

  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection(kInventoryCollection).doc(docId);

  @override
  Widget build(BuildContext context) {
    final short = _qty <= _minQty && _minQty > 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        if (pending > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PendingWritesBanner(count: pending),
          ),
        Text(
          _name,
          style: const TextStyle(
            color: CuttingColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _tag(materialCategoryLabel(data['category'] as String?)),
            if ((data['maker'] ?? '').toString().trim().isNotEmpty)
              _tag(data['maker'].toString()),
            if ((data['kind'] ?? '').toString().trim().isNotEmpty)
              _tag(data['kind'].toString()),
          ],
        ),
        const SizedBox(height: 20),

        // 재고 카드
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: short
                ? CuttingColors.warningSoft
                : CuttingColors.primarySoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$_qty",
                    style: TextStyle(
                      color: short
                          ? CuttingColors.warning
                          : CuttingColors.primaryDark,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _unit,
                      style: TextStyle(
                        color: short
                            ? CuttingColors.warning
                            : CuttingColors.primaryDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _editQty(context),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text("수량 고치기"),
                  ),
                ],
              ),
              if (short)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    "최소 수량 $_minQty$_unit 아래입니다. 채워 두십시오.",
                    style: const TextStyle(
                      color: CuttingColors.warning,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _sectionTitle("자재 정보"),
        _row(
          context,
          "규격",
          (data['spec'] ?? data['size'] ?? '').toString(),
          'spec',
        ),
        _row(context, "보관 위치", (data['location'] ?? '').toString(), 'location'),
        _row(context, "제조사", (data['maker'] ?? '').toString(), 'maker'),
        _row(context, "재질", (data['material'] ?? '').toString(), 'material'),
        _row(context, "단위", _unit, 'unit'),
        _row(context, "최소 수량", _minQty == 0 ? '' : '$_minQty', 'minQty'),
        // 본으로 세는 자재만. 컷팅에서 "몇 본 드는지"를 이 길이로 나눠 센다.
        if (_unit.trim() == '본')
          _row(
            context,
            "한 본 길이(mm)",
            _barLengthMm == 0 ? '' : '$_barLengthMm',
            'barLengthMm',
          ),
        _row(
          context,
          "프로젝트",
          (data['projectName'] ?? '').toString(),
          'projectName',
        ),

        const SizedBox(height: 24),
        _sectionTitle("최근 기록"),
        _RecentLogs(itemName: _name),
      ],
    );
  }

  Widget _tag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: CuttingColors.background,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: CuttingColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: const TextStyle(
        color: CuttingColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _row(BuildContext context, String label, String value, String field) {
    return InkWell(
      onTap: () => _editField(context, label, value, field),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                label,
                style: const TextStyle(
                  color: CuttingColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value.trim().isEmpty ? '적지 않았습니다' : value,
                style: TextStyle(
                  color: value.trim().isEmpty
                      ? CuttingColors.textSecondary
                      : CuttingColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: CuttingColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editField(
    BuildContext context,
    String label,
    String value,
    String field,
  ) async {
    final ctrl = TextEditingController(text: value);
    final isNumber = field == 'minQty' || field == 'barLengthMm';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("$label 고치기"),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            helperText: field == 'barLengthMm' ? "비워 두면 6000mm로 봅니다." : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CuttingColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("고치기"),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final text = ctrl.text.trim();
    try {
      await _ref.update({
        field: isNumber ? (int.tryParse(text) ?? 0) : text,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      if (field == 'maker') await rememberMaker(text);
      if (!context.mounted) return;
      showCuttingSnack(context, "고쳤습니다.");
    } catch (_) {
      if (!context.mounted) return;
      showCuttingSnack(context, "고치지 못했습니다.", isError: true);
    }
  }

  /// 재고 수량은 창고 숫자를 바꾸는 일이라, 바뀌는 내용을 한 번 보여 주고
  /// 기록(자재 기록)에도 남긴다.
  Future<void> _editQty(BuildContext context) async {
    final ctrl = TextEditingController(text: '$_qty');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("재고 수량"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: CuttingColors.primaryDark,
              ),
              decoration: const InputDecoration(border: InputBorder.none),
            ),
            Text(
              "창고에 실제로 있는 수량을 적습니다. 단위는 $_unit입니다.",
              style: const TextStyle(
                color: CuttingColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CuttingColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("고치기"),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final next = int.tryParse(ctrl.text.trim());
    if (next == null || next < 0) return;
    if (next == _qty) return;
    if (!context.mounted) return;

    final sure = await showCuttingConfirmDialog(
      context,
      title: "재고를 고치겠습니까?",
      message: "$_name — $_qty$_unit → $next$_unit",
      confirmLabel: "고치기",
    );
    if (!sure) return;

    try {
      final diff = next - _qty;
      // 통째로 덮어쓰지 않고 차이만 더하고 뺀다. 창을 띄운 사이 컷팅 차감이 있어도
      // 그것이 지워지지 않는다. 재고와 기록은 한 번에 쓴다.
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.update(_ref, {
        'qty': FieldValue.increment(diff),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      batch.set(db.collection('inventory_logs').doc(), {
        'material_name': _name,
        'type': diff > 0 ? 'IN' : 'OUT',
        'action': '재고 실사',
        'qty': diff.abs(),
        'sign': diff > 0 ? '+' : '-',
        'unit': _unit,
        'worker_name': workerName,
        'project_name': '자재 화면에서 수량 고침',
        'device': 'Mobile',
        'timestamp': FieldValue.serverTimestamp(),
      });
      await batch.commit().timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
      if (!context.mounted) return;
      showCuttingSnack(context, "$next$_unit으로 고쳤습니다.");
    } catch (_) {
      if (!context.mounted) return;
      showCuttingSnack(context, "고치지 못했습니다.", isError: true);
    }
  }
}

/// 이 자재를 내가 가져간 내역. 여기서 바로 반납한다.
class _RecentLogs extends StatelessWidget {
  final String itemName;

  const _RecentLogs({required this.itemName});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('inventory_logs')
          .where('material_name', isEqualTo: itemName)
          // 정렬 없이 20건을 자르면 옛 기록이 나오고 오늘 것이 빠질 수 있다.
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Text("기록을 불러오지 못했습니다."),
          );
        }
        if (!snap.hasData) return const SizedBox(height: 8);
        final docs = snap.data!.docs.toList()
          ..sort((a, b) {
            final ta = a.data()['timestamp'] as Timestamp?;
            final tb = b.data()['timestamp'] as Timestamp?;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              "기록이 없습니다.",
              style: TextStyle(
                color: CuttingColors.textSecondary,
                fontSize: 14,
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final d in docs.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(child: Text(_line(d.data()))),
                    Text(
                      _when(d.data()['timestamp'] as Timestamp?),
                      style: const TextStyle(
                        color: CuttingColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  String _line(Map<String, dynamic> m) {
    final type = (m['type'] ?? '').toString();
    final action = (m['action'] ?? '').toString();
    final qty = (m['qty'] as num?)?.toInt() ?? 0;
    final unit = (m['unit'] ?? 'EA').toString();
    final who = (m['worker_name'] ?? m['workerName'] ?? '').toString();
    final what = action.isNotEmpty
        ? action
        : (type == 'OUT' ? '불출' : (type == 'IN' ? '반납' : '변동'));
    // 재고조사 기록(AUDIT)은 줄었는지 늘었는지를 'sign' 칸에 적는다. 예전엔 이 칸을
    // 안 봐서 재고조사로 줄어든 것도 +로 보였다.
    final signField = (m['sign'] ?? '').toString();
    final sign = signField == '-' || signField == '+'
        ? signField
        : (type == 'OUT' ? '-' : '+');
    return "$what $sign$qty$unit${who.isEmpty ? '' : ' · $who'}";
  }

  String _when(Timestamp? t) {
    if (t == null) return '';
    final d = t.toDate();
    return "${d.month}/${d.day}";
  }
}
