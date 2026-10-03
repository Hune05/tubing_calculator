// 전선관 특수 벤딩 시트(킥·분할 90°·백투백 90°·스터브업)가 오프셋·새들·롤링 오프셋 시트와 같은 모양이 되게 하는
// 공용 부품. 틀(머리 줄·그림·입력 칸·6축 방향·결과 상자·경고 창)을 오프셋 시트(mobile_offset_bottom_sheet.dart)와
// 똑같이 맞춰 두었다. 모양을 바꿀 때는 오프셋 시트와 함께 바꾼다.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';

const Color csTeal = AppColors.brand;
const Color csInk = AppColors.text;
const Color csSub = AppColors.textSub;
const Color csBg = AppColors.background;
const Color csWhite = Color(0xFFFFFFFF);

/// 꺾는 방향 여섯 축(값은 꺾은 뒤 관이 향할 절대 방향). 오프셋 시트와 같은 순서·이름.
const List<(String, double, IconData)> kCsDirections = [
  ('UP', 0.0, Icons.arrow_upward),
  ('FRONT', 360.0, Icons.call_made),
  ('LEFT', 270.0, AppIcons.back),
  ('RIGHT', 90.0, Icons.arrow_forward),
  ('DOWN', 180.0, Icons.arrow_downward),
  ('BACK', 450.0, Icons.call_received),
];

String csFmt(double v, [int d = 1]) {
  final s = v.toStringAsFixed(d);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

double? csRead(TextEditingController c) =>
    double.tryParse(c.text.trim().replaceAll(',', '.'));

/// 오프셋 시트와 같은 바깥 틀: 흰 바탕 둥근 위쪽, 머리 줄(계산기 아이콘 + 제목 + 닫기), 그림, 내용.
class CsFrame extends StatelessWidget {
  final String title;
  final Widget guide;
  final List<Widget> children;
  const CsFrame({
    super.key,
    required this.title,
    required this.guide,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: csWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(LucideIcons.calculator, color: csTeal, size: 28),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: csInk,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: csSub),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              guide,
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// 입력 칸 위 작은 제목(오프셋 시트의 "장애물 높이/깊이 (H)" 같은 것).
class CsLabel extends StatelessWidget {
  final String text;
  const CsLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(color: csSub, fontSize: 13, fontWeight: FontWeight.bold),
    ),
  );
}

/// 숫자 칸. 눌러서 숫자판(MakitaNumpadGlass)으로 넣는다. 오프셋 시트의 `_buildTextField`와 같다.
class CsField extends StatelessWidget {
  final Key? fieldKey;
  final TextEditingController ctrl;
  final String hint;
  const CsField({super.key, this.fieldKey, required this.ctrl, required this.hint});

  @override
  Widget build(BuildContext context) => TextField(
    key: fieldKey,
    controller: ctrl,
    readOnly: true,
    onTap: () => MakitaNumpadGlass.show(context, controller: ctrl, title: hint),
    style: const TextStyle(
      color: csTeal,
      fontSize: 20,
      fontWeight: FontWeight.w900,
      fontFamily: 'monospace',
    ),
    decoration: InputDecoration(
      filled: true,
      fillColor: csWhite,
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: csTeal, width: 2),
      ),
    ),
  );
}

/// −5·+5 같은 값 조정 단추.
class CsQuickBtn extends StatelessWidget {
  final TextEditingController ctrl;
  final double amount;
  final String label;
  const CsQuickBtn({super.key, required this.ctrl, required this.amount, required this.label});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () {
      final double next = ((csRead(ctrl) ?? 0) + amount).clamp(0, double.infinity);
      ctrl.text = next.toStringAsFixed(next % 1 == 0 ? 0 : 1);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: csWhite,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(label, style: const TextStyle(color: csInk, fontWeight: FontWeight.bold)),
    ),
  );
}

/// 빠른 각도 단추(22.5° 같은).
class CsQuickAngleBtn extends StatelessWidget {
  final TextEditingController ctrl;
  final double value;
  const CsQuickAngleBtn({super.key, required this.ctrl, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: InkWell(
      onTap: () => ctrl.text = value.toStringAsFixed(value % 1 == 0 ? 0 : 1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: csWhite,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          value % 1 == 0 ? '${value.toInt()}°' : '$value°',
          style: const TextStyle(color: csInk, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    ),
  );
}

/// 고르는 단추(방향 칸과 같은 모양). 선택하면 청록 바탕.
class CsChoice extends StatelessWidget {
  final Key? choiceKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  const CsChoice({
    super.key,
    this.choiceKey,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    key: choiceKey,
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? csTeal : csBg,
        border: Border.all(color: selected ? csTeal : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: selected ? csWhite : csSub),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: selected ? csWhite : csInk,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 꺾는 방향(6축) 고르기. 오프셋 시트와 같은 3칸 격자, 안 고르면 빨간 "*필수".
class CsDirectionSelector extends StatelessWidget {
  final double? value;
  final ValueChanged<double> onPick;
  final String title;
  const CsDirectionSelector({
    super.key,
    required this.value,
    required this.onPick,
    this.title = '꺾는 방향 (6축)',
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: value == null ? Colors.redAccent : csSub,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (value == null)
            Flexible(
              child: Text(
                ' *필수',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2.5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: kCsDirections.length,
        itemBuilder: (context, index) {
          final d = kCsDirections[index];
          final bool sel = value == d.$2;
          return InkWell(
            key: Key('cs_dir_${d.$2.toInt()}'),
            onTap: () => onPick(d.$2),
            child: Container(
              decoration: BoxDecoration(
                color: sel ? csTeal : csBg,
                border: Border.all(color: sel ? csTeal : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(d.$3, size: 16, color: sel ? csWhite : csSub),
                  const SizedBox(width: 4),
                  Text(
                    d.$1,
                    style: TextStyle(
                      color: sel ? csWhite : csInk,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );
}

/// 오프셋 시트의 "장애물 앞 시작 거리" 상자와 같은 모양: 왼쪽 설명, 오른쪽 숫자 칸.
class CsInfoBox extends StatelessWidget {
  final String title;
  final String note;
  final Widget field;
  const CsInfoBox({super.key, required this.title, required this.note, required this.field});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.blueGrey.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.blueGrey.shade200),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: csInk, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(note, style: const TextStyle(color: csSub, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(width: 120, child: field),
      ],
    ),
  );
}

/// 결과 상자(오프셋 시트와 같다): 왼쪽 제목·큰 값, 오른쪽 "목록에 넣기", 아래 가는 줄 뒤 보조 값들.
class CsResultBox extends StatelessWidget {
  final String title;
  final String? value; // null이면 "입력 필요"
  final String btnText;
  final VoidCallback onPressed;
  final List<Widget> details;
  const CsResultBox({
    super.key,
    required this.title,
    required this.value,
    required this.onPressed,
    this.btnText = '목록에 넣기',
    this.details = const [],
  });

  @override
  Widget build(BuildContext context) {
    final bool ok = value != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: csTeal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: csTeal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: csSub, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        ok ? value! : '입력 필요',
                        style: TextStyle(
                          color: ok ? csTeal : Colors.redAccent,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                key: const Key('cs_add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: csTeal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onPressed: onPressed,
                child: Text(
                  btnText,
                  style: const TextStyle(color: csWhite, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (ok && details.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.black12, height: 1),
            const SizedBox(height: 12),
            ...details,
          ],
        ],
      ),
    );
  }
}

/// 결과 상자 안 보조 값 한 줄(오프셋의 "수평 거리 (Run)"처럼 제목 + 큰 값 + 작은 설명).
class CsDetail extends StatelessWidget {
  final String label;
  final String value;
  final String? note;
  const CsDetail({super.key, required this.label, required this.value, this.note});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: csSub)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: csInk,
            fontFamily: 'monospace',
          ),
        ),
        if (note != null)
          Text(note!, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ],
    ),
  );
}

/// 결과 상자 맨 아래 줄: 왼쪽 빨강(축소값), 오른쪽 주황(게인) 두 칸. 오프셋 시트와 같다.
class CsShrinkGainRow extends StatelessWidget {
  final String? shrink; // null이면 이 칸은 빈다
  final String? shrinkNote;
  final String gainLabel;
  final String gain;
  const CsShrinkGainRow({
    super.key,
    this.shrink,
    this.shrinkNote,
    required this.gainLabel,
    required this.gain,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (shrink != null) ...[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '축소값 (Shrink)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent),
              ),
              const SizedBox(height: 2),
              Text(
                shrink!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                  fontFamily: 'monospace',
                ),
              ),
              if (shrinkNote != null)
                Text(shrinkNote!, style: const TextStyle(fontSize: 10, color: Colors.black54)),
            ],
          ),
        ),
        Container(width: 1, height: 30, color: Colors.black12),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              gainLabel,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
            ),
            const SizedBox(height: 2),
            Text(
              gain,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800,
                fontFamily: 'monospace',
              ),
            ),
            const Text('(총 절단 길이에서 뺌)', style: TextStyle(fontSize: 10, color: Colors.black54)),
          ],
        ),
      ),
    ],
  );
}

/// 방향을 안 골랐을 때 오프셋 시트와 같은 가운데 경고 창.
void csShowDirectionWarning(BuildContext context) => showDialog(
  context: context,
  builder: (ctx) => AlertDialog(
    backgroundColor: csWhite,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: const Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
        SizedBox(width: 8),
        Text('경고', style: TextStyle(fontWeight: FontWeight.bold, color: csInk)),
      ],
    ),
    content: const Text(
      '꺾는 방향(6축)을 먼저 선택해 주십시오.',
      style: TextStyle(color: csInk, fontSize: 15),
    ),
    actions: [
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepOrange,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => Navigator.pop(ctx),
        child: const Text('확인', style: TextStyle(color: csWhite)),
      ),
    ],
  ),
);

/// 값이 모자라 못 넣을 때 알림(오프셋 시트의 주황 알림 줄).
void csSnackMissing(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        key: const Key('cs_missing'),
        content: Text(msg),
        backgroundColor: Colors.deepOrange,
      ),
    );
}

/// 목록에 넣은 뒤 알림(오프셋 시트와 같은 청록 알림 줄).
void csSnackAdded(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: csTeal),
  );
}
