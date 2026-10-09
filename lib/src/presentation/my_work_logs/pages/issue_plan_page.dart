// 이슈를 도면에서 보기(10-10): 프로젝트 도면 위에 이슈 위치 핀을 번호로 한꺼번에 보이고,
// 핀이나 아래 목록을 누르면 이슈 상세로 간다. 이슈에 이미 찍어 둔 위치 핀(locationPinDx/Dy)을 쓴다.
import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../models/plan_pin.dart';

class IssuePlanPage extends StatefulWidget {
  final Map<String, dynamic> log;
  final Future<void> Function(Map<String, dynamic> punch) onOpenPunch;

  const IssuePlanPage({super.key, required this.log, required this.onOpenPunch});

  /// 이 프로젝트에 도면에서 볼 이슈가 있는지(도면이 있고 핀 찍은 이슈가 하나 이상).
  static bool hasPins(Map<String, dynamic> log) =>
      (log['floor_plan_image_path']?.toString() ?? '').isNotEmpty &&
      (log['punch_lists'] as List? ?? []).whereType<Map>().any(
        (p) => p['locationPinDx'] != null && p['locationPinDy'] != null,
      );

  @override
  State<IssuePlanPage> createState() => _IssuePlanPageState();
}

class _IssuePlanPageState extends State<IssuePlanPage> {
  bool _openOnly = true;
  Size? _image;

  String get _plan => widget.log['floor_plan_image_path']?.toString() ?? '';

  List<Map<String, dynamic>> get _all => [
    for (final p in (widget.log['punch_lists'] as List? ?? []).whereType<Map>())
      Map<String, dynamic>.from(p),
  ];

  bool _done(Map p) => p['is_completed'] == true;

  @override
  void initState() {
    super.initState();
    planImageSize(_plan).then((s) {
      if (mounted) setState(() => _image = s);
    });
  }

  Color _color(Map p) {
    if (_done(p)) return AppColors.idle;
    return switch (p['priority']?.toString()) {
      '긴급' => AppColors.danger,
      '여유' => AppColors.textSub,
      _ => AppColors.brand,
    };
  }

  Future<void> _open(Map<String, dynamic> p) async {
    // 목록에서 꺼낸 사본이 아니라 프로젝트에 든 그 이슈를 넘긴다(상세에서 고친 것이 남게).
    final list = (widget.log['punch_lists'] as List? ?? []);
    final real = list.whereType<Map<String, dynamic>>().firstWhere(
      (e) => e['id'] != null && e['id'] == p['id'],
      orElse: () => p,
    );
    await widget.onOpenPunch(real);
    if (mounted) setState(() {});
  }

  Widget _badge(int no, Map p, {double size = 26}) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _color(p),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
    ),
    child: Text(
      '$no',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final shown = [
      for (final p in all)
        if (!_openOnly || !_done(p)) p,
    ];
    final pinned = [
      for (final p in shown)
        if (p['locationPinDx'] != null && p['locationPinDy'] != null) p,
    ];
    final noPin = shown.length - pinned.length;
    final openCount = all.where((p) => !_done(p)).length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${widget.log['name'] ?? ''} · 이슈 도면'),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                ChoiceChip(
                  key: const Key('issue_plan_open'),
                  label: Text('미해결 $openCount'),
                  selected: _openOnly,
                  onSelected: (_) => setState(() => _openOnly = true),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  key: const Key('issue_plan_all'),
                  label: Text('전체 ${all.length}'),
                  selected: !_openOnly,
                  onSelected: (_) => setState(() => _openOnly = false),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.white,
              child: InteractiveViewer(
                maxScale: 6,
                child: PlanPinsView(
                  imagePath: _plan,
                  imageSize: _image,
                  pins: [
                    if (_image != null)
                      for (int i = 0; i < pinned.length; i++)
                        if (pinOnImageOf(pinned[i], _image) case final at?)
                          PlanPin(
                            at,
                            GestureDetector(
                              key: Key('issue_plan_pin_${i + 1}'),
                              onTap: () => _open(pinned[i]),
                              child: _badge(i + 1, pinned[i]),
                            ),
                            markerSize: const Size(26, 26),
                            anchor: Alignment.center,
                          ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                if (pinned.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('도면에 위치를 찍은 이슈가 없습니다.'),
                  ),
                for (int i = 0; i < pinned.length; i++)
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      key: Key('issue_plan_row_${i + 1}'),
                      leading: _badge(i + 1, pinned[i], size: 30),
                      title: Text(
                        pinned[i]['content']?.toString() ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          decoration: _done(pinned[i])
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Text(
                        [
                          pinned[i]['location']?.toString() ?? '',
                          pinned[i]['priority']?.toString() ?? '',
                          if (_done(pinned[i])) '처리됨',
                        ].where((e) => e.isNotEmpty).join(' · '),
                      ),
                      onTap: () => _open(pinned[i]),
                    ),
                  ),
                if (noPin > 0)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '위치를 안 찍은 이슈 $noPin건은 이슈 목록에만 있습니다.',
                      style: const TextStyle(color: AppColors.textSub),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
