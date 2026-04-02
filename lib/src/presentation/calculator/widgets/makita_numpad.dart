// lib/src/presentation/calculator/widgets/makita_numpad.dart
import 'package:flutter/material.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate200 = Color(0xFFE2E8F0);
const Color slate100 = Color(0xFFF1F5F9); // 🚀 이 줄을 추가해 주세요!
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
          height: 500, // 여백을 위해 높이를 살짝 확보
          decoration: const BoxDecoration(
            color: pureWhite, // 토스 스타일의 깨끗한 퓨어 화이트
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(32),
            ), // 더 둥근 모서리
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
  bool _isFirstPress = true;

  @override
  void didUpdateWidget(covariant MakitaNumpad oldWidget) {
    super.didUpdateWidget(oldWidget);
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
        _isFirstPress = false;
      } else {
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

  // 🔥 토스/애플 스타일의 평면적이고 세련된 버튼 빌더
  Widget _buildButton(
    String label, {
    Color? textColor,
    bool isAction = false,
    bool isPrimary = false,
    int flex = 1,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(6.0), // 버튼 간 여유 공간
        child: isPrimary
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: makitaTeal,
                  foregroundColor: pureWhite,
                  elevation: 0, // 그림자 완전 제거
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24), // 세련된 알약 모양
                  ),
                ),
                onPressed: () => widget.onApply?.call(),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              )
            : TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: textColor ?? slate900, // 기본 숫자 색상 (다크)
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: EdgeInsets.zero,
                ),
                onPressed: () => _onKeyPressed(label),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isAction ? 20 : 28, // 숫자는 거대하게
                    fontWeight: isAction ? FontWeight.w600 : FontWeight.w400,
                    fontFamily: isAction ? null : 'monospace', // 숫자는 깔끔한 고정폭
                  ),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        children: [
          // 🚀 헤더 영역
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: slate900, // 너무 튀지 않게 진한 차콜색으로
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              if (widget.onApply != null)
                GestureDetector(
                  onTap: widget.onApply,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: slate100, // 은은한 회색 원형 배경
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: slate600, size: 18),
                  ),
                ),
            ],
          ),

          const Spacer(flex: 1),

          // 🚀 입력 결과 텍스트 (박스 걷어내고 여백 위에 띄움)
          AnimatedBuilder(
            animation: widget.controller,
            builder: (context, child) {
              return Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  widget.controller.text.isEmpty ? '0' : widget.controller.text,
                  style: const TextStyle(
                    color: slate900,
                    fontSize: 48, // 압도적인 크기로 가독성 극대화
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.5,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),

          const Spacer(flex: 1),

          // 🚀 키패드 영역
          Expanded(
            flex: 10,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('7'),
                      _buildButton('8'),
                      _buildButton('9'),
                      _buildButton(
                        'C',
                        textColor: Colors.orange.shade600,
                        isAction: true,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('4'),
                      _buildButton('5'),
                      _buildButton('6'),
                      _buildButton(
                        'DEL',
                        textColor: Colors.red.shade500,
                        isAction: true,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('1'),
                      _buildButton('2'),
                      _buildButton('3'),
                      _buildButton('.', textColor: slate600, isAction: true),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('00'),
                      _buildButton('0'),
                      _buildButton(
                        '적용',
                        isPrimary: true,
                        flex: 2,
                      ), // 확 눈에 띄는 알약 버튼
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
