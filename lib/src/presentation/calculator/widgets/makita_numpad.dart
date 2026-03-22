// lib/src/presentation/calculator/widgets/makita_numpad.dart
import 'package:flutter/material.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate200 = Color(0xFFE2E8F0);
const Color slate50 = Color(0xFFF8FAFC);
const Color pureWhite = Color(0xFFFFFFFF);

class MakitaNumpad extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onApply;
  final String title;

  const MakitaNumpad({
    super.key,
    required this.controller,
    this.onApply,
    this.title = "수치 입력",
  });

  // 🚀 [Lint 에러 해결] void -> Future<void> 로 변경하고 return 추가
  static Future<void> show(
    BuildContext context, {
    required TextEditingController controller,
    required String title,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          height: 480,
          decoration: BoxDecoration(
            color: slate50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: MakitaNumpad(
            controller: controller,
            title: title,
            onApply: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  @override
  State<MakitaNumpad> createState() => _MakitaNumpadState();
}

class _MakitaNumpadState extends State<MakitaNumpad> {
  // 🚀 첫 터치 시 기존 값을 지우기 위한 상태값
  bool _isFirstPress = true;

  @override
  void didUpdateWidget(covariant MakitaNumpad oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 💡 핵심 수정: 텍스트가 같더라도(예: 1번 라인 100, 2번 라인 100)
    // title("#1 적용" -> "#2 적용")이 바뀌면 무조건 새로운 입력으로 간주하고 초기화합니다.
    if (oldWidget.title != widget.title ||
        oldWidget.controller.text != widget.controller.text) {
      _isFirstPress = true;
    }
  }

  void _onKeyPressed(String value) {
    setState(() {
      if (value == 'C') {
        widget.controller.text = '';
        _isFirstPress = false;
      } else if (value == 'DEL') {
        final text = widget.controller.text;
        if (text.isNotEmpty) {
          widget.controller.text = text.substring(0, text.length - 1);
        }
        // 지우기 버튼을 누르면 이어서 수정하려는 의도이므로 덮어쓰기 해제
        _isFirstPress = false;
      } else {
        // 🚀 첫 터치 시 기존 값을 완전히 지우고 새로 입력
        if (_isFirstPress) {
          widget.controller.text = '';
          _isFirstPress = false;
        }

        final text = widget.controller.text;
        if (value == '.') {
          if (!text.contains('.')) {
            widget.controller.text = text.isEmpty ? '0.' : text + '.';
          }
        } else {
          if (text == '0' && value != '00') {
            widget.controller.text = value;
          } else if (text == '0' && value == '00') {
            return;
          } else {
            widget.controller.text = text + value;
          }
        }
      }
    });
  }

  Widget _buildButton(
    String label, {
    Color? color,
    Color? textColor,
    int flex = 1,
  }) {
    Color bgColor = color ?? pureWhite;
    Color txtColor = textColor ?? (color == null ? slate900 : pureWhite);

    if (label == '.') {
      bgColor = slate200;
      txtColor = slate900;
    }

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: bgColor,
            foregroundColor: txtColor,
            elevation: color == null ? 1 : 2,
            shadowColor: color != null
                ? color.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.zero,
          ),
          onPressed: () {
            if (label == '적용') {
              widget.onApply?.call();
            } else {
              _onKeyPressed(label);
            }
          },
          child: Text(
            label,
            style: TextStyle(
              fontSize: (label == '적용' || label == 'C' || label == 'DEL')
                  ? 16
                  : 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: slate50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: makitaTeal,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              if (widget.onApply != null)
                SizedBox(
                  height: 24,
                  width: 24,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close, color: slate600, size: 20),
                    onPressed: widget.onApply,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: slate200,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, child) {
                return Text(
                  widget.controller.text.isEmpty ? '0' : widget.controller.text,
                  style: const TextStyle(
                    color: slate900,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.right,
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('7'),
                      _buildButton('8'),
                      _buildButton('9'),
                      _buildButton('C', color: Colors.orange.shade600),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('4'),
                      _buildButton('5'),
                      _buildButton('6'),
                      _buildButton('DEL', color: Colors.red.shade500),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('1'),
                      _buildButton('2'),
                      _buildButton('3'),
                      _buildButton('.'),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('00'),
                      _buildButton('0'),
                      _buildButton('적용', color: makitaTeal, flex: 2),
                    ],
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
