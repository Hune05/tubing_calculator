import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 앱 전체에서 공통으로 쓸 색상들
const Color darkBg = Color(0xFF1E2124);
const Color inputBg = Color(0xFF2A2E33);
const Color mutedWhite = Color(0xFFD0D4D9);

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
        labelStyle: const TextStyle(fontSize: 14, color: Colors.grey),
        filled: true,
        fillColor: inputBg,
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
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
            color: mutedWhite,
          ),
          decoration: InputDecoration(
            labelText: isOptional ? label : "$label *",
            labelStyle: const TextStyle(fontSize: 14, color: Colors.grey),
            filled: true,
            fillColor: inputBg,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: focusColor, width: 2),
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
                          if (nextFocus == null)
                            FocusScope.of(context).unfocus();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: mutedWhite,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          backgroundColor: inputBg,
                        ),
                        child: Text(
                          "$angle°",
                          style: const TextStyle(fontSize: 14),
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
                color: isSelected ? inputBg : Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? activeColor : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                tabs[i],
                style: TextStyle(
                  color: isSelected ? activeColor : Colors.grey,
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected ? modeColor : inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? modeColor : Colors.transparent,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              dir,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
