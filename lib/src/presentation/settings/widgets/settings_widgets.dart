import 'package:flutter/material.dart';

// 💡 마키타 메인 테마 컬러 설정
const Color makitaTeal = Color(0xFF007580);

class TwoColumnRow extends StatelessWidget {
  final Widget left;
  final Widget right;
  const TwoColumnRow({super.key, required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 16),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class SettingLabel extends StatelessWidget {
  final String text;
  final String? tooltip;
  const SettingLabel({super.key, required this.text, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              color: Colors.blueGrey[800],
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          if (tooltip != null) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: tooltip!,
              triggerMode: TooltipTriggerMode.tap,
              showDuration: const Duration(seconds: 3),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(12),
              textStyle: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: BoxDecoration(
                color: Colors.blueGrey[900]!.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.help_outline,
                size: 16,
                color: Colors.blueGrey[400],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SettingInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? tooltip;
  final ValueChanged<String>? onChanged;

  final bool? isAutoMode;
  final ValueChanged<bool>? onModeChanged;

  const SettingInputField({
    super.key,
    required this.label,
    required this.controller,
    this.tooltip,
    this.onChanged,
    this.isAutoMode,
    this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAuto = isAutoMode ?? true;
    final bool hasMode = isAutoMode != null;

    // 💡 AUTO: 마키타 청록색 / MAN: 강력한 경고 주황색
    final Color textColor = isAuto ? Colors.black87 : Colors.deepOrange[900]!;
    final Color bgColor = isAuto ? Colors.grey[100]! : Colors.orange[50]!;
    final Color borderColor = isAuto ? Colors.grey[300]! : Colors.orange[400]!;
    final Color focusBorderColor = isAuto ? makitaTeal : Colors.deepOrange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.blueGrey[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              if (tooltip != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: tooltip!,
                  triggerMode: TooltipTriggerMode.tap,
                  showDuration: const Duration(seconds: 3),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(12),
                  textStyle: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[900]!.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.help_outline,
                    size: 16,
                    color: Colors.blueGrey[400],
                  ),
                ),
              ],
              if (hasMode) const Spacer(),
              if (hasMode)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isAuto ? Colors.grey[300]! : Colors.orange[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      // AUTO 버튼
                      _buildModeBtn(
                        "AUTO",
                        isAuto,
                        makitaTeal,
                        () => onModeChanged?.call(true),
                        isLeft: true,
                      ),
                      // MAN 버튼 (주황색)
                      _buildModeBtn(
                        "MAN",
                        !isAuto,
                        Colors.deepOrange,
                        () => onModeChanged?.call(false),
                        isLeft: false,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: isAuto ? FontWeight.normal : FontWeight.bold,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            filled: true,
            fillColor: bgColor,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: focusBorderColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeBtn(
    String text,
    bool active,
    Color activeColor,
    VoidCallback onTap, {
    required bool isLeft,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.grey[100],
          borderRadius: isLeft
              ? const BorderRadius.horizontal(left: Radius.circular(3))
              : const BorderRadius.horizontal(right: Radius.circular(3)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: active ? Colors.white : Colors.grey[400],
          ),
        ),
      ),
    );
  }
}

class SettingDropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String? tooltip;
  final String Function(String)? displayMapper;

  const SettingDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.tooltip,
    this.displayMapper,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingLabel(text: label, tooltip: tooltip),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              dropdownColor: Colors.white,
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: Colors.blueGrey[400],
              ),
              items: items.map((item) {
                String displayText = displayMapper != null
                    ? displayMapper!(item)
                    : item;
                return DropdownMenuItem(value: item, child: Text(displayText));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class SettingSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const SettingSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: makitaTeal, size: 20), // 💡 카드 아이콘도 청록색
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[900],
                ),
              ),
            ],
          ),
          Divider(color: Colors.grey[200], height: 24, thickness: 1),
          child,
        ],
      ),
    );
  }
}
