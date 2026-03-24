import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 🎨 화이트 & 마키타 테마 컬러
const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A); // 진한 텍스트 (입력값)
const Color slate600 = Color(0xFF475569); // 서브 텍스트 (라벨)
const Color slate100 = Color(0xFFF1F5F9); // 연한 회색 (읽기 전용창 배경)
const Color pureWhite = Color(0xFFFFFFFF); // 퓨어 화이트 (입력창 배경)

class RemoteReadOnlyField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final Color textColor;

  const RemoteReadOnlyField({
    super.key,
    required this.label,
    required this.ctrl,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      enabled: false,
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 14,
          color: slate600,
          fontWeight: FontWeight.bold,
        ),
        filled: true,
        fillColor: slate100, // 💡 읽기 전용은 연한 회색으로 입력창과 구분
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none, // 💡 테두리 없이 깔끔하게
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}

class RemoteTextField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final FocusNode currentFocus;
  final Color focusColor;
  final bool showQuickAngles;
  final bool isOptional;
  final FocusNode? nextFocus;

  const RemoteTextField({
    super.key,
    required this.label,
    required this.ctrl,
    required this.currentFocus,
    required this.focusColor,
    this.showQuickAngles = false,
    this.isOptional = false,
    this.nextFocus,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          focusNode: currentFocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          textInputAction: nextFocus != null
              ? TextInputAction.next
              : TextInputAction.done,
          onSubmitted: (_) {
            if (nextFocus != null) {
              FocusScope.of(context).requestFocus(nextFocus);
            } else {
              FocusScope.of(context).unfocus();
            }
          },
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: slate900, // 💡 진한 글씨로 시인성 극대화
          ),
          decoration: InputDecoration(
            labelText: isOptional ? label : "$label *",
            labelStyle: const TextStyle(
              fontSize: 14,
              color: slate600,
              fontWeight: FontWeight.bold,
            ),
            filled: true,
            fillColor: pureWhite, // 💡 새하얀 배경
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.shade300, // 💡 연한 회색 테두리
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: focusColor, width: 2.5),
            ),
          ),
        ),
        if (showQuickAngles) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [22.5, 30, 45, 60]
                .map(
                  (angle) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          ctrl.text = angle.toString();
                          if (nextFocus == null) {
                            FocusScope.of(context).unfocus();
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          foregroundColor: slate900, // 💡 텍스트 색상
                          backgroundColor: pureWhite, // 💡 배경 색상
                          side: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          "$angle°",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class InnerTabSelector extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final Color activeColor;
  final Function(int) onTabSelected;

  const InnerTabSelector({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.activeColor,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(tabs.length, (i) {
        bool isSelected = selectedIndex == i;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onTabSelected(i);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? pureWhite
                    : Colors.transparent, // 💡 선택 시 흰색 카드 형태
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? activeColor : Colors.grey.shade300,
                    width: isSelected ? 3 : 1,
                  ),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                tabs[i],
                style: TextStyle(
                  color: isSelected ? activeColor : slate600,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class DirectionSelector extends StatelessWidget {
  final String selectedDir;
  final Color modeColor;
  final Function(String) onDirSelected;

  const DirectionSelector({
    super.key,
    required this.selectedDir,
    required this.modeColor,
    required this.onDirSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: ["UP", "DOWN", "LEFT", "RIGHT", "FRONT", "BACK"].map((dir) {
        bool isSelected = selectedDir == dir;
        return InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onDirSelected(dir);
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected ? modeColor : pureWhite, // 💡 비활성 시 흰색
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? modeColor
                    : Colors.grey.shade300, // 💡 비활성 시 연한 테두리
                width: 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: modeColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              dir,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? pureWhite : slate600, // 💡 텍스트 대비 향상
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
