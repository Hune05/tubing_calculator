import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';

/// 보관함 저장 창(튜브·전선관)이 같이 쓰는 부품.
/// 작업 이름을 매번 새로 치면 "A동 보일러실"과 "A동보일러실"처럼 조금만 달라도 폴더가 갈라지므로,
/// 이미 쓴 이름을 칩으로 보여 주고 누르면 입력칸에 넣는다.

/// 저장할 때 이름을 안 적어 자동으로 들어간 이름. 칩으로 보여 줄 가치가 없다.
const Set<String> _placeholderNames = {'프로젝트 미지정', '미지정 프로젝트', '미분류 도면'};

/// [names]에서 빈 것·자동 이름·중복을 빼고 처음 나온 순서 그대로 최대 [max]개.
/// 넘겨 주는 쪽이 새것이 먼저 오게 정렬해 두면 "최근 쓴 이름"이 된다.
List<String> recentDistinctNames(Iterable<String> names, {int max = 6}) {
  final out = <String>[];
  final seen = <String>{};
  for (final raw in names) {
    final n = raw.trim();
    if (n.isEmpty || _placeholderNames.contains(n)) continue;
    if (!seen.add(n)) continue;
    out.add(n);
    if (out.length >= max) break;
  }
  return out;
}

/// 저장 창 맨 위에 보여 줄 한 줄 요약: "굽힘 3개 · 총 530mm · 꼬리 25mm · 피팅 시작·끝".
String saveSummaryText({
  required List<dynamic> bends,
  required double totalCut,
  double tail = 0,
  bool startFit = false,
  bool endFit = false,
}) {
  var count = 0;
  for (final b in bends) {
    if (b is! Map) continue;
    final a = double.tryParse(b['angle']?.toString() ?? '0') ?? 0.0;
    if (a > 0) count++;
  }
  String mm(double v) =>
      '${v.round()}mm';
  final parts = <String>['굽힘 $count개', '총 ${mm(totalCut)}'];
  if (tail > 0) parts.add('꼬리 ${mm(tail)}');
  if (startFit && endFit) {
    parts.add('피팅 시작·끝');
  } else if (startFit) {
    parts.add('피팅 시작');
  } else if (endFit) {
    parts.add('피팅 끝');
  }
  return parts.join(' · ');
}

/// 요약 한 줄 상자.
class SaveSummaryBox extends StatelessWidget {
  final String text;
  const SaveSummaryBox(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('save_summary'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 이미 쓴 작업 이름 칩. 누르면 [controller]에 그 이름이 들어간다. 이름이 없으면 아무것도 안 그린다.
class SaveNameChips extends StatelessWidget {
  final List<String> names;
  final TextEditingController controller;

  const SaveNameChips({
    super.key,
    required this.names,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final current = value.text.trim();
          return Wrap(
            key: const Key('save_name_chips'),
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final n in names)
                ChoiceChip(
                  label: Text(n, overflow: TextOverflow.ellipsis),
                  selected: current == n,
                  selectedColor: AppColors.brand,
                  backgroundColor: AppColors.background,
                  showCheckmark: false,
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    color: current == n ? Colors.white : AppColors.textSub,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  onSelected: (_) {
                    controller.value = TextEditingValue(
                      text: n,
                      selection: TextSelection.collapsed(offset: n.length),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
