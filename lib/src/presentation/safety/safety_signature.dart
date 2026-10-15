// 작업 전 안전 점검(TBM) 참석자 서명(10-14): 이름·업체를 적고 손가락으로 서명한다.
// 폰을 돌려 가며 받으므로 "저장하고 다음 사람"으로 바로 다음 칸을 연다.
// 서명은 획 좌표(가로 0~1000, 세로 0~400)로 들고 있다가 글로 적는다(safety_check_model.dart).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_tokens.dart';
import 'safety_check_model.dart';

/// 서명 획을 칸 크기에 맞춰 그린다(가운데 맞춤, 비율 그대로).
class SignaturePainter extends CustomPainter {
  final List<List<(double, double)>> strokes;
  final Color color;
  final double width;
  const SignaturePainter(
    this.strokes, {
    this.color = const Color(0xFF111827),
    this.width = 9,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;
    final k = (size.width / kSigW) < (size.height / kSigH)
        ? size.width / kSigW
        : size.height / kSigH;
    final dx = (size.width - kSigW * k) / 2;
    final dy = (size.height - kSigH * k) / 2;
    Offset o((double, double) p) => Offset(dx + p.$1 * k, dy + p.$2 * k);
    final paint = Paint()
      ..color = color
      ..strokeWidth = (width * k).clamp(1.2, 6.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.length == 1) {
        canvas.drawCircle(
          o(s.first),
          paint.strokeWidth / 2,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(o(s.first).dx, o(s.first).dy);
      for (final p in s.skip(1)) {
        final q = o(p);
        path.lineTo(q.dx, q.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePainter old) => true;
}

/// 저장된 서명 작은 그림. 서명이 없으면 "서명 없음".
class SignatureThumb extends StatelessWidget {
  final String sig;
  final double width;
  final double height;
  const SignatureThumb(
    this.sig, {
    super.key,
    this.width = 110,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    final strokes = decodeSignature(sig);
    return SizedBox(
      width: width,
      height: height,
      child: strokes.isEmpty
          ? const Center(
              child: Text(
                '서명 없음',
                style: TextStyle(fontSize: 12, color: AppColors.textSub),
              ),
            )
          : CustomPaint(painter: SignaturePainter(strokes)),
    );
  }
}

/// 참석자 창의 결과: 적은 참석자와 "다음 사람"을 눌렀는지.
typedef AttendeeResult = ({SafetyAttendee attendee, bool next});

/// 참석자 한 명을 적는 창. [initial]이 있으면 고치기(다음 사람 단추 없음).
/// [suggest]: 지난 점검에 나온 이름(누르면 이름·업체가 채워진다). [taken]: 이미 목록에 있는 이름.
Future<AttendeeResult?> showAttendeeSheet(
  BuildContext context, {
  SafetyAttendee? initial,
  List<SafetyAttendee> suggest = const [],
  Set<String> taken = const {},
  // 작업 일지 확인 서명도 이 창을 쓴다(10-14): 제목·둘째 칸 이름을 바꾸고 "다음 사람"은 뺀다.
  String? title,
  String companyLabel = '업체 (선택)',
  bool allowNext = true,
}) => showModalBottomSheet<AttendeeResult>(
  context: context,
  isScrollControlled: true,
  // 서명 칸에서 아래로 그으면 창이 내려가 버린다 → 끌어서 닫기는 끈다.
  enableDrag: false,
  backgroundColor: AppColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
  ),
  builder: (_) => _AttendeeSheet(
    initial: initial,
    title: title,
    companyLabel: companyLabel,
    allowNext: allowNext,
    suggest: [
      for (final a in suggest)
        if (!taken.contains(a.name) && a.name != initial?.name) a,
    ],
  ),
);

class _AttendeeSheet extends StatefulWidget {
  final SafetyAttendee? initial;
  final List<SafetyAttendee> suggest;
  final String? title;
  final String companyLabel;
  final bool allowNext;
  const _AttendeeSheet({
    this.initial,
    required this.suggest,
    this.title,
    this.companyLabel = '업체 (선택)',
    this.allowNext = true,
  });

  @override
  State<_AttendeeSheet> createState() => _AttendeeSheetState();
}

class _AttendeeSheetState extends State<_AttendeeSheet> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _company = TextEditingController(
    text: widget.initial?.company ?? '',
  );
  late final List<List<(double, double)>> _strokes = [
    for (final s in decodeSignature(widget.initial?.sig ?? '')) [...s],
  ];
  bool _nameMissing = false;

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    super.dispose();
  }

  (double, double) _norm(Offset p, Size box) => (
    (p.dx / box.width * kSigW).clamp(0, kSigW),
    (p.dy / box.height * kSigH).clamp(0, kSigH),
  );

  void _finish(bool next) {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameMissing = true);
      return;
    }
    HapticFeedback.lightImpact();
    Navigator.pop<AttendeeResult>(context, (
      attendee: SafetyAttendee(
        name,
        company: _company.text.trim(),
        sig: encodeSignature(_strokes, kSigW, kSigH),
      ),
      next: next,
    ));
  }

  InputDecoration _deco(String label, {String? error}) => InputDecoration(
    labelText: label,
    errorText: error,
    isDense: true,
    filled: true,
    fillColor: AppColors.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide.none,
    ),
  );

  Widget _pad(double w) {
    final h = w * kSigH / kSigW;
    final box = Size(w, h);
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.line),
      ),
      child: Stack(
        children: [
          // 서명 밑줄과 안내 글(서명하면 안내 글은 사라진다).
          Positioned(
            left: 20,
            right: 20,
            bottom: h * 0.22,
            child: Container(height: 1, color: AppColors.line),
          ),
          if (_strokes.isEmpty)
            const Center(
              child: Text(
                '여기에 손가락으로 서명',
                style: TextStyle(fontSize: 15, color: AppColors.textSub),
              ),
            ),
          // 열쇠를 붙여 둔다: 첫 획에서 안내 글이 빠지고 "다시 쓰기"가 생기면 열쇠 없는 칸끼리
          // 자리가 바뀌어 서명 칸이 새로 만들어지고, 긋던 첫 획이 점 하나로 끊겼다(A9+ 확인).
          Positioned.fill(
            key: const ValueKey('safety_sig_pad_area'),
            child: GestureDetector(
              key: const Key('safety_sig_pad'),
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) {
                FocusScope.of(context).unfocus();
                setState(() => _strokes.add([_norm(d.localPosition, box)]));
              },
              onPanUpdate: (d) => setState(
                () => _strokes.last.add(_norm(d.localPosition, box)),
              ),
              child: CustomPaint(painter: SignaturePainter(_strokes)),
            ),
          ),
          if (_strokes.isNotEmpty)
            Positioned(
              right: 4,
              top: 4,
              child: TextButton(
                key: const Key('safety_sig_clear'),
                onPressed: () => setState(_strokes.clear),
                child: const Text('다시 쓰기'),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final editing = widget.initial != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 12 + mq.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, c) {
            // 가로 화면에서도 창이 넘치지 않게 서명 칸 폭을 화면 높이로도 줄인다.
            final byHeight =
                (mq.size.height - mq.viewInsets.bottom - 260) * kSigW / kSigH;
            final w = [
              c.maxWidth,
              560.0,
              byHeight,
            ].reduce((a, b) => a < b ? a : b).clamp(220.0, c.maxWidth);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title ?? (editing ? '참석자 고치기' : '참석자 서명'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        key: const Key('safety_att_name'),
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) {
                          if (_nameMissing) {
                            setState(() => _nameMissing = false);
                          }
                        },
                        decoration: _deco(
                          '이름',
                          error: _nameMissing ? '이름을 적어야 저장됩니다' : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        key: const Key('safety_att_company'),
                        controller: _company,
                        decoration: _deco(widget.companyLabel),
                      ),
                    ),
                  ],
                ),
                if (widget.suggest.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final a in widget.suggest)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              key: Key('safety_att_chip_${a.name}'),
                              label: Text(
                                a.label,
                                style: const TextStyle(fontSize: 13),
                              ),
                              onPressed: () => setState(() {
                                _name.text = a.name;
                                _company.text = a.company;
                                _nameMissing = false;
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Center(child: _pad(w)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                    const SizedBox(width: 8),
                    if (!editing && widget.allowNext) ...[
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('safety_att_next'),
                          onPressed: () => _finish(true),
                          child: const Text('저장하고 다음 사람'),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: FilledButton(
                        key: const Key('safety_att_save'),
                        onPressed: () => _finish(false),
                        child: const Text('저장'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
