// 벤딩 실측 기록: 계산한 값과 실제로 잰 값을 남기고, 같은 규격·장비·같은 종류의 지난 차이를 본다.
// 10-13 개편(상용 검사 앱과 비교, 사용자 "추천대로, 허용은 2mm"):
// - 위: 묶음(규격·장비) 고르기, 종류 칩(90° 구간 길이·절단 길이…)
// - 요약: 평균 차이·합격 건수·표준편차, 점 그림(허용 띠 ±2mm), 최근 3번 연달아 한쪽으로 허용 밖이면 알림
//   + 장비 설정(시험 벤딩)으로 가는 단추
// - 아래: 날짜별 목록(합격/불합격), 입력은 "+ 실측 기록" 아래 창(큰 숫자, 차이·합격 바로 보임)
// 계산 결과는 바뀌지 않는다(참고만).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/common_widgets/app_components.dart';
import '../../core/common_widgets/record_sync_line.dart';
import '../../core/common_widgets/swipe_to_delete.dart';
import '../../core/theme/app_icon_set.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/field_view.dart' show NormalViewTheme;
import '../../core/utils/settings_cloud.dart';
import '../../data/record_sync.dart';
import '../calculator/screens/mobile_settings_tab.dart';
import '../common/number_text.dart';
import '../conduit/screens/conduit_settings_page.dart';
import '../trash/trash_kinds.dart';
import '../tube_cutting/cutting_action_bar.dart' show kakaoSender, textSharer;
import 'bend_check_model.dart';

Future<void> _defaultShare(String text) async {
  if (await kakaoSender(text)) return;
  await textSharer(text);
}

/// 장비 설정(시험 벤딩이 있는 곳)을 연다. [source]는 'conduit'·'tube'.
void _defaultOpenSettings(BuildContext context, String source) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => source == 'conduit'
          ? const ConduitSettingsPage(isActive: true)
          : Scaffold(
              appBar: AppBar(title: const Text('튜브 장비 설정')),
              body: const NormalViewTheme(child: MobileSettingsTab()),
            ),
    ),
  );
}

String _fmt(double v) {
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble() ? r.round().toString() : r.toStringAsFixed(1);
}

/// 합격·불합격 색(옅은 바탕 + 진한 글).
Color _passBg(bool ok) => ok
    ? AppColors.ok.withValues(alpha: 0.12)
    : AppColors.danger.withValues(alpha: 0.10);
Color _passFg(bool ok) => ok ? AppColors.ok : AppColors.danger;

class BendCheckPage extends StatefulWidget {
  final Future<void> Function(String text) share;
  final DateTime Function()? now;

  /// 치우침 알림의 "시험 벤딩으로 다시 잡기"(장비 설정 열기). 시험에서 바꿔 끼운다.
  final void Function(BuildContext context, String source) openSettings;
  const BendCheckPage({
    super.key,
    this.share = _defaultShare,
    this.now,
    this.openSettings = _defaultOpenSettings,
  });

  @override
  State<BendCheckPage> createState() => _BendCheckPageState();
}

class _BendCheckPageState extends State<BendCheckPage> {
  List<BendCheck> _all = [];
  bool _loaded = false;
  RecordSyncStatus? _sync;

  /// 보고 있는 묶음(규격·장비 한 줄).
  String _group = '';

  /// 고른 종류(null이면 이 묶음에서 가장 최근에 쓴 종류).
  String? _kind;

  /// 허용 범위(± mm).
  double _tol = kBendTolDefault;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _reload();
    _syncWithServer();
    loadBendTolerance().then((v) {
      if (mounted) setState(() => _tol = v);
    });
  }

  /// 서버의 내 실측 기록을 받아 합치고, 폰에만 있는 것을 올린다. 통신이 없으면 폰 것만 보인다.
  Future<void> _syncWithServer() async {
    try {
      final s0 = await bendCheckSync.status();
      if (mounted) setState(() => _sync = s0);
      final s = await bendCheckSync.syncNow();
      if (mounted) setState(() => _sync = s);
      await _reload();
    } catch (_) {}
  }

  /// 저장·지운 것이 서버에 올라간 뒤 상태 줄을 고친다.
  Future<void> _refreshSync() async {
    await RecordSync.idle();
    final s = await bendCheckSync.status();
    if (mounted) setState(() => _sync = s);
  }

  Future<void> _reload() async {
    final all = await loadBendChecks();
    if (!mounted) return;
    setState(() {
      _all = all;
      _loaded = true;
      // 처음에는 가장 최근에 쓴 묶음을 보여 준다.
      if (_group.isEmpty && all.isNotEmpty) _group = groupNames(all).first;
    });
  }

  /// 이 묶음에서 고를 수 있는 종류: 90° 구간 길이·절단 길이는 늘, 쓴 각도는 더한다(큰 각도가 앞).
  List<String> get _kinds {
    final ks = <String>{bendKindKey(kBendKindLeg, 90), 'cut'};
    for (final c in _all) {
      if (c.counted && c.group == _group) ks.add(c.kindKey);
    }
    double rank(String k) {
      if (k == 'cut') return 1000;
      if (k.startsWith('leg:')) {
        return -(double.tryParse(k.substring(4)) ?? -999);
      }
      return 2000;
    }

    return ks.toList()..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  String get _kindKey {
    if (_kind != null) return _kind!;
    BendCheck? last;
    for (final c in _all) {
      if (!c.counted || c.group != _group) continue;
      if (last == null || c.at.isAfter(last.at)) last = c;
    }
    return last?.kindKey ?? bendKindKey(kBendKindLeg, 90);
  }

  // ── 묶음 ──

  Future<void> _pickGroup() async {
    final names = groupNames(_all);
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text('묶음 고르기', style: AppText.subtitle),
            ),
            for (final n in names)
              ListTile(
                key: Key('bendcheck_pick_$n'),
                title: Text(n),
                trailing: n == _group
                    ? const Icon(Icons.check_rounded, color: AppColors.brand)
                    : null,
                onTap: () => Navigator.pop(ctx, n),
              ),
            ListTile(
              key: const Key('bendcheck_group_new'),
              leading: const Icon(Icons.add_rounded, color: AppColors.brand),
              title: const Text('새 묶음 적기'),
              onTap: () => Navigator.pop(ctx, ''),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final g = picked.isEmpty ? await _askNewGroup() : picked;
    if (g == null || g.isEmpty || !mounted) return;
    setState(() {
      _group = g;
      _kind = null;
    });
  }

  Future<String?> _askNewGroup() => showDialog<String>(
    context: context,
    builder: (_) => const _NewGroupDialog(),
  );

  // ── 허용 범위 ──

  Future<void> _editTol() async {
    final v = await showDialog<double>(
      context: context,
      builder: (_) => _TolDialog(initial: _tol),
    );
    if (v == null || !mounted) return;
    await saveBendTolerance(v);
    // 다른 기기에도 같은 허용 범위(설정 서버, 로그인했을 때만).
    SettingsCloudSync.instance.backup();
    if (mounted) setState(() => _tol = v);
  }

  // ── 넣기·지우기 ──

  Future<void> _openAdd() async {
    if (_group.isEmpty) {
      final g = await _askNewGroup();
      if (g == null || g.isEmpty || !mounted) return;
      setState(() {
        _group = g;
        _kind = null;
      });
    }
    final c = await showModalBottomSheet<BendCheck>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
      builder: (_) => _AddSheet(
        group: _group,
        kindKey: _kindKey,
        all: _all,
        tol: _tol,
        now: _now,
      ),
    );
    if (c == null || !mounted) return;
    await addBendCheck(c);
    HapticFeedback.lightImpact();
    await _reload();
    if (!mounted) return;
    setState(() => _kind = c.kindKey);
    _refreshSync();
    showAppSnack(context, '저장했습니다');
  }

  /// 목록에서 곧바로 빼고 휴지통으로 옮긴다. "되돌리기"를 누르면 휴지통에서 복원한다(10-02).
  void _delete(BendCheck c) {
    setState(() => _all = [..._all]..removeWhere((e) => e.id == c.id));
    final title = '${c.at.month}/${c.at.day} ${c.group}';
    final done = trashBendCheck(c, title: title);
    done.then((_) => _refreshSync(), onError: (_) {});
    showTrashUndo(
      context,
      title,
      done,
      onRestored: () async {
        await _reload();
        _refreshSync();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final kindKey = _kindKey;
    final setup = _group.isEmpty ? null : latestSetup(_all, _group, kindKey);
    // 참고에 넣는 것(같은 종류, 마지막 장비 값이나 손 기록) — 오래된 것이 앞.
    final used = _group.isEmpty
        ? <BendCheck>[]
        : statRecords(_all, _group, kindKey, setup: setup);
    final usedIds = {for (final c in used) c.id};
    // 목록: 같은 종류 전부(최근 것이 앞), 옛 기록은 따로.
    final shown = [
      for (final c in _all)
        if (c.counted && c.group == _group && c.kindKey == kindKey) c,
    ]..sort((a, b) => b.at.compareTo(a.at));
    final old = [
      for (final c in _all)
        if (!c.counted && c.group == _group) c,
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('벤딩 실측 기록'),
        actions: [
          IconButton(
            key: const Key('bendcheck_share'),
            tooltip: '카톡으로 보내기',
            icon: const Icon(AppIcons.share),
            onPressed: _all.isEmpty
                ? null
                : () => widget.share(
                    buildBendCheckText(
                      _all,
                      group: _group.isEmpty ? null : _group,
                      tol: _tol,
                    ),
                  ),
          ),
          PopupMenuButton<String>(
            key: const Key('bendcheck_menu'),
            tooltip: '설정',
            onSelected: (v) {
              if (v == 'tol') _editTol();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                key: const Key('bendcheck_menu_tol'),
                value: 'tol',
                child: Text('허용 범위 (지금 ±${_fmt(_tol)} mm)'),
              ),
            ],
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _groupTile(),
                if (_group.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      '벤딩한 뒤 잰 구간 길이(앞 꺾이는 점에서 이 꺾이는 점까지)나 절단 길이를 계산과 견줘 남기면, '
                      '같은 규격·장비·같은 각도의 지난 차이를 모아 보여 줍니다. 마킹 계산 결과는 바뀌지 않습니다.',
                      style: AppText.sub,
                    ),
                  )
                else ...[
                  const SizedBox(height: 10),
                  _kindChips(kindKey),
                  const SizedBox(height: 12),
                  _summary(used, kindKey, setup),
                  const SizedBox(height: 20),
                  const Text('지난 기록', style: AppText.subtitle),
                  const SizedBox(height: 6),
                  RecordSyncLine(_sync, key: const Key('bendcheck_sync')),
                  if (shown.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('이 종류는 아직 기록이 없습니다', style: AppText.sub),
                    )
                  else
                    ..._dated(shown, usedIds),
                  if (old.isNotEmpty) _oldSection(old),
                ],
              ],
            ),
      bottomNavigationBar: !_loaded
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: AppButton(
                key: const Key('bendcheck_add'),
                label: '실측 기록',
                icon: Icons.add_rounded,
                expand: true,
                onPressed: _openAdd,
              ),
            ),
    );
  }

  Widget _groupTile() => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadius.medium),
    child: InkWell(
      key: const Key('bendcheck_group'),
      borderRadius: BorderRadius.circular(AppRadius.medium),
      onTap: _pickGroup,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('규격·장비', style: AppText.caption),
                  const SizedBox(height: 2),
                  Text(
                    _group.isEmpty ? '묶음을 고르십시오' : _group,
                    key: const Key('bendcheck_group_name'),
                    style: AppText.body.copyWith(
                      fontWeight: AppText.medium,
                      color: _group.isEmpty
                          ? AppColors.textSub
                          : AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: AppColors.textSub),
          ],
        ),
      ),
    ),
  );

  Widget _kindChips(String selected) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final k in _kinds)
        ChoiceChip(
          key: Key('bendcheck_kind_$k'),
          label: Text(bendKindLabel(k)),
          selected: k == selected,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
          ),
          onSelected: (_) => setState(() => _kind = k),
        ),
    ],
  );

  /// 요약: 평균 차이·합격·표준편차, 점 그림, 치우침 알림.
  Widget _summary(List<BendCheck> used, String kindKey, String? setup) {
    final label = bendKindLabel(kindKey);
    if (used.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Text(
          '아직 $label 기록이 없습니다. 아래 "실측 기록"으로 남기면 평균과 흐름이 여기에 나옵니다.',
          style: AppText.sub,
        ),
      );
    }
    final st = statsFor(_all, _group, kindKey: kindKey, setup: setup)!;
    final pass = used.where((c) => bendWithinTol(c.diff, _tol)).length;
    final meanOk = bendWithinTol(st.mean, _tol);
    final drift = bendDrift(used, _tol);
    final isCut = kindKey == 'cut';
    final source = sourceOf(_all, _group);
    final notes = [
      '지난 실측 ${st.n}건',
      if (setup != null) '장비 값 $setup',
      if (st.n < kBendReliableCount) '건수가 적어 참고만',
    ].join(' · ');
    final what = isCut
        ? '자르는 자리와 톱날 두께를 확인하십시오.'
        : '장비 설정의 시험 벤딩으로 ${source == 'tube' ? '반경·게인' : '테이크업·게인'}을 다시 잡아 보십시오.';
    return Container(
      key: const Key('bendcheck_reference'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _metric(
                  'bendcheck_mean',
                  '평균 차이',
                  signedMm(st.mean).replaceAll(' mm', ''),
                  meanOk ? AppColors.text : AppColors.caution,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  'bendcheck_pass',
                  '합격',
                  '$pass / ${used.length}',
                  pass == used.length ? AppColors.ok : AppColors.text,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  'bendcheck_spread',
                  '표준편차',
                  st.n > 1 ? '±${_fmt(st.spread)}' : '—',
                  AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('$label · $notes', style: AppText.sub),
          const SizedBox(height: 10),
          SizedBox(
            key: const Key('bendcheck_chart'),
            height: 140,
            width: double.infinity,
            child: CustomPaint(
              painter: _DiffChartPainter(
                points: used.length > 20
                    ? used.sublist(used.length - 20)
                    : used,
                tol: _tol,
              ),
            ),
          ),
          if (drift != 0) ...[
            const SizedBox(height: 10),
            Container(
              key: const Key('bendcheck_drift'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.caution.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '최근 $kBendDriftRun번 연달아 ${drift > 0 ? '길게' : '짧게'} 나왔습니다'
                    '(허용 ±${_fmt(_tol)} mm 밖). $what',
                    style: AppText.body.copyWith(fontWeight: AppText.medium),
                  ),
                  if (!isCut && source.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: TextButton.icon(
                        key: const Key('bendcheck_calibrate'),
                        onPressed: () => widget.openSettings(context, source),
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: const Text('시험 벤딩으로 다시 잡기'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(String key, String label, String value, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.caption),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                key: Key(key),
                style: AppText.number.copyWith(fontSize: 22, color: color),
              ),
            ),
          ],
        ),
      );

  /// 날짜마다 머리 줄을 넣은 목록.
  List<Widget> _dated(List<BendCheck> newestFirst, Set<String> usedIds) {
    final out = <Widget>[];
    String? day;
    for (final c in newestFirst) {
      final d = '${c.at.month}월 ${c.at.day}일';
      if (d != day) {
        day = d;
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(d, style: AppText.caption),
          ),
        );
      }
      out.add(_recordTile(c, inStats: usedIds.contains(c.id)));
    }
    return out;
  }

  Widget _recordTile(BendCheck c, {required bool inStats, bool old = false}) {
    final d = c.diff;
    final ok = bendWithinTol(d, _tol);
    final sub = [
      '계산 ${_fmt(c.calc)} → 실측 ${_fmt(c.actual)}',
      if (c.note.isNotEmpty) c.note,
      // 10-13 전 기록: 견준 값이 달라(줄자 마킹 눈금) 참고 통계에서 뺀다.
      if (old) '옛 기록 · 참고에서 뺌',
      if (!old && !inStats) '예전 장비 값(${c.setup})',
    ].join(' · ');
    return SwipeToDelete(
      itemKey: ValueKey('bendcheck_swipe_${c.id}'),
      bottomMargin: 6,
      onDelete: () => _delete(c),
      child: Container(
        key: Key('bendcheck_record_${c.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.what.isNotEmpty
                        ? c.what
                        : (c.counted ? bendKindLabel(c.kindKey) : c.group),
                    style: AppText.body.copyWith(fontWeight: AppText.medium),
                  ),
                  const SizedBox(height: 2),
                  Text(sub, style: AppText.sub),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: old ? AppColors.fill : _passBg(ok),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Text(
                old
                    ? signedMm(d)
                    : '${signedMm(d).replaceAll(' mm', '')} ${ok ? '합격' : '불합격'}',
                key: Key('bendcheck_badge_${c.id}'),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: old ? AppColors.textSub : _passFg(ok),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _oldSection(List<BendCheck> old) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const Key('bendcheck_old'),
        tilePadding: EdgeInsets.zero,
        title: Text(
          '옛 기록 ${old.length}건 · 참고에서 뺌',
          style: AppText.sub.copyWith(fontWeight: AppText.medium),
        ),
        children: [
          for (final c in old) _recordTile(c, inStats: false, old: true),
        ],
      ),
    ),
  );
}

/// 차이 점 그림: 허용 띠(±tol)를 옅은 초록으로, 점은 합격 초록·불합격 빨강, 오래된 것이 왼쪽.
class _DiffChartPainter extends CustomPainter {
  final List<BendCheck> points;
  final double tol;
  _DiffChartPainter({required this.points, required this.tol});

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0, right = 10.0, top = 8.0, bottom = 20.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    final maxAbs = math.max(
      tol * 2,
      points.fold<double>(0, (m, c) => math.max(m, c.diff.abs())) * 1.15,
    );
    double y(double v) => top + (1 - (v + maxAbs) / (2 * maxAbs)) * h;
    double x(int i) =>
        left + (points.length == 1 ? w / 2 : i * w / (points.length - 1));

    // 허용 띠
    canvas.drawRect(
      Rect.fromLTRB(left, y(tol), left + w, y(-tol)),
      Paint()..color = AppColors.ok.withValues(alpha: 0.12),
    );
    // 0 선(점선)
    final zero = Paint()
      ..color = AppColors.textFaint
      ..strokeWidth = 1;
    for (double xx = left; xx < left + w; xx += 8) {
      canvas.drawLine(
        Offset(xx, y(0)),
        Offset(math.min(xx + 4, left + w), y(0)),
        zero,
      );
    }
    final tp = TextPainter(textDirection: TextDirection.ltr);
    void label(String t, Offset o, {bool alignRight = false}) {
      tp.text = TextSpan(
        text: t,
        style: AppText.caption.copyWith(fontSize: 11),
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(alignRight ? o.dx - tp.width : o.dx, o.dy - tp.height / 2),
      );
    }

    label('+${_fmt(tol)}', Offset(left - 4, y(tol)), alignRight: true);
    label('-${_fmt(tol)}', Offset(left - 4, y(-tol)), alignRight: true);
    label('0', Offset(left - 4, y(0)), alignRight: true);

    // 잇는 선과 점
    if (points.length > 1) {
      final path = Path()..moveTo(x(0), y(points[0].diff));
      for (var i = 1; i < points.length; i++) {
        path.lineTo(x(i), y(points[i].diff));
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = AppColors.textFaint.withValues(alpha: 0.6),
      );
    }
    for (var i = 0; i < points.length; i++) {
      final ok = bendWithinTol(points[i].diff, tol);
      final o = Offset(x(i), y(points[i].diff));
      canvas.drawCircle(o, 5.5, Paint()..color = Colors.white);
      canvas.drawCircle(o, 4.5, Paint()..color = _passFg(ok));
    }
    // 첫·마지막 날짜
    String md(DateTime d) => '${d.month}/${d.day}';
    final yb = size.height - bottom / 2;
    label(md(points.first.at), Offset(left, yb));
    if (points.length > 1) {
      label(md(points.last.at), Offset(left + w, yb), alignRight: true);
    }
  }

  @override
  bool shouldRepaint(covariant _DiffChartPainter old) =>
      old.points != points || old.tol != tol;
}

/// 실측 넣는 아래 창: 종류(구간 길이·절단 길이)·각도, 계산과 잰 값을 큰 숫자로, 차이·합격을 바로.
class _AddSheet extends StatefulWidget {
  final String group;
  final String kindKey;
  final List<BendCheck> all;
  final double tol;
  final DateTime now;
  const _AddSheet({
    required this.group,
    required this.kindKey,
    required this.all,
    required this.tol,
    required this.now,
  });

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  late bool _isCut = widget.kindKey == 'cut';
  late final _angle = TextEditingController(
    text: widget.kindKey.startsWith('leg:') && widget.kindKey.length > 4
        ? widget.kindKey.substring(4)
        : '90',
  );
  final _what = TextEditingController();
  final _calc = TextEditingController();
  final _actual = TextEditingController();
  final _note = TextEditingController();
  String? _err;

  @override
  void dispose() {
    for (final c in [_angle, _what, _calc, _actual, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) => parseNumberText(c.text);

  double? get _angleValue {
    final a = _num(_angle);
    return (a != null && a > 0 && a <= 180) ? a : null;
  }

  String get _kindKey => _isCut
      ? bendKindKey(kBendKindCut, null)
      : bendKindKey(kBendKindLeg, _angleValue);

  Future<void> _save() async {
    final calc = _num(_calc);
    final actual = _num(_actual);
    if (calc == null || actual == null || calc <= 0 || actual <= 0) {
      setState(() => _err = '계산값과 실측값을 0보다 큰 숫자로 넣으십시오.');
      return;
    }
    final angle = _angleValue;
    if (!_isCut && angle == null) {
      setState(() => _err = '벤드 각도를 숫자로 넣으십시오.');
      return;
    }
    final diff = actual - calc;
    // 400을 4000으로 넣는 것 같은 실수를 한 번 묻는다(평균을 크게 흔든다).
    if (diff.abs() > 30) {
      final ok = await showAppConfirm(
        context,
        title: '차이가 큽니다',
        message: '차이가 ${signedMm(diff)}입니다. 숫자를 맞게 넣었습니까?',
        okText: '그대로 저장',
        cancelText: '다시 보기',
        okKey: const Key('bendcheck_big_ok'),
      );
      if (!ok || !mounted) return;
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      BendCheck(
        id: widget.now.millisecondsSinceEpoch.toString(),
        at: widget.now,
        group: widget.group,
        what: _what.text.trim(),
        calc: calc,
        actual: actual,
        note: _note.text.trim(),
        kind: _isCut ? kBendKindCut : kBendKindLeg,
        angle: _isCut ? null : angle,
      ),
    );
  }

  Widget _chip(String key, String label, bool cut) {
    final selected = _isCut == cut;
    return ChoiceChip(
      key: Key(key),
      label: Text(label),
      selected: selected,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
      ),
      onSelected: (_) => setState(() => _isCut = cut),
    );
  }

  Widget _bigField(String key, TextEditingController c, String label) =>
      TextField(
        key: Key(key),
        controller: c,
        onChanged: (_) => setState(() => _err = null),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: AppText.number.copyWith(fontSize: 26),
        decoration: InputDecoration(
          labelText: label,
          suffixText: 'mm',
          filled: true,
          fillColor: AppColors.fill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.small),
            borderSide: BorderSide.none,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final calc = _num(_calc);
    final actual = _num(_actual);
    final live = (calc != null && actual != null) ? actual - calc : null;
    final liveOk = live != null && bendWithinTol(live, widget.tol);
    final kindKey = _kindKey;
    final setup = latestSetup(widget.all, widget.group, kindKey);
    final st = statsFor(
      widget.all,
      widget.group,
      kindKey: kindKey,
      setup: setup,
    );
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('실측 기록', style: AppText.title),
              const SizedBox(height: 2),
              Text(widget.group, style: AppText.sub),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _chip('bendcheck_add_leg', '구간 길이', false),
                  _chip('bendcheck_add_cut', '절단 길이', true),
                  if (!_isCut)
                    SizedBox(
                      width: 110,
                      child: TextField(
                        key: const Key('bendcheck_angle'),
                        controller: _angle,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '각도 (°)',
                          isDense: true,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _isCut
                    ? '자른 관 길이를 재서 계산한 절단 길이와 견줍니다.'
                    : '앞 꺾이는 점(첫 벤드는 관 끝)에서 이 꺾이는 점까지 잰 길이를 입력한 길이와 견줍니다.',
                style: AppText.sub,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _bigField(
                      'bendcheck_calc',
                      _calc,
                      _isCut ? '계산 절단 길이' : '입력 길이',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _bigField('bendcheck_actual', _actual, '실제로 잰 값'),
                  ),
                ],
              ),
              if (live != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _passBg(liveOk),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Text(
                    '차이 ${signedMm(live)} · '
                    '${liveOk ? '합격' : '허용 ±${_fmt(widget.tol)} mm 밖(불합격)'}',
                    key: const Key('bendcheck_live'),
                    style: AppText.body.copyWith(
                      fontWeight: AppText.bold,
                      color: _passFg(liveOk),
                    ),
                  ),
                ),
              ],
              if (st != null) ...[
                const SizedBox(height: 8),
                Text(
                  '지난 ${bendKindLabel(kindKey)} 실측 ${st.n}건 평균 ${signedMm(st.mean)}',
                  key: const Key('bendcheck_add_reference'),
                  style: AppText.sub,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                key: const Key('bendcheck_what'),
                controller: _what,
                decoration: const InputDecoration(
                  labelText: '측정 위치 (선택)',
                  hintText: '예: 1번 구간 길이',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('bendcheck_note'),
                controller: _note,
                decoration: const InputDecoration(labelText: '메모 (선택)'),
              ),
              if (_err != null) ...[
                const SizedBox(height: 10),
                Text(
                  _err!,
                  key: const Key('bendcheck_error'),
                  style: AppText.sub.copyWith(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: '취소',
                      expand: true,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      key: const Key('bendcheck_save'),
                      label: '저장',
                      expand: true,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 새 묶음 이름 창. 입력 컨트롤러를 이 창이 스스로 만들고 없앤다(닫히는 동안에도 안전하게).
/// 현장 탭이 붙이는 이름과 같은 꼴로 적게 예시를 보인다.
class _NewGroupDialog extends StatefulWidget {
  const _NewGroupDialog();

  @override
  State<_NewGroupDialog> createState() => _NewGroupDialogState();
}

class _NewGroupDialogState extends State<_NewGroupDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('새 묶음'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('bendcheck_group_input'),
          controller: _c,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '규격·장비',
            hintText: '12.7mm SUS · Swagelok 수동 (Hand)',
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '현장 탭에서 남긴 기록은 묶음 이름이 저절로 붙습니다. 같은 이름끼리 모아 셉니다.',
          style: AppText.sub,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      TextButton(
        key: const Key('bendcheck_group_ok'),
        onPressed: () => Navigator.pop(context, _c.text.trim()),
        child: const Text('확인'),
      ),
    ],
  );
}

/// 허용 범위 설정 창(± mm). 입력 컨트롤러를 이 창이 스스로 만들고 없앤다.
class _TolDialog extends StatefulWidget {
  final double initial;
  const _TolDialog({required this.initial});

  @override
  State<_TolDialog> createState() => _TolDialogState();
}

class _TolDialogState extends State<_TolDialog> {
  late final _c = TextEditingController(text: _fmt(widget.initial));
  String? _err;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('실측 기록 설정'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('bendcheck_tol_input'),
          controller: _c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: '허용 범위',
            prefixText: '± ',
            suffixText: 'mm',
            errorText: _err,
          ),
          onChanged: (_) {
            if (_err != null) setState(() => _err = null);
          },
        ),
        const SizedBox(height: 8),
        const Text(
          '실측 − 계산이 이 범위 안이면 합격입니다. 구간 길이·절단 길이에 같이 씁니다.',
          style: AppText.sub,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      TextButton(
        key: const Key('bendcheck_tol_ok'),
        onPressed: () {
          final x = parseNumberText(_c.text);
          if (x == null || !x.isFinite || x <= 0 || x > 100) {
            setState(() => _err = '0보다 크고 100 이하인 숫자로 넣으십시오.');
            return;
          }
          Navigator.pop(context, x);
        },
        child: const Text('확인'),
      ),
    ],
  );
}
