import 'package:flutter/material.dart';
import 'dart:ui'; // 반투명 블러 효과 패키지

const Color makitaTeal = Color(0xFF007580);
const Color numpadBg = Color(0xFF1E1E1E);
const Color btnColor = Color(0xFF2A2A2A);

class MakitaNumpadGlass extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onApply;
  final String title;

  const MakitaNumpadGlass({
    super.key,
    required this.controller,
    this.onApply,
    this.title = "수치 입력",
  });

  static void show(
    BuildContext context, {
    required TextEditingController controller,
    required String title,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
            child: Container(
              width: 320,
              height: 420,
              decoration: BoxDecoration(
                color: numpadBg.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: makitaTeal.withOpacity(0.7),
                  width: 2,
                ),
              ),
              child: MakitaNumpadGlass(
                controller: controller,
                title: title,
                onApply: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<MakitaNumpadGlass> createState() => _MakitaNumpadGlassState();
}

class _MakitaNumpadGlassState extends State<MakitaNumpadGlass> {
  // 💡 패드가 열리고 '첫 번째'로 누르는 버튼인지 확인하는 플래그
  bool _isFirstPress = true;

  void _onKeyPressed(String value) {
    if (value == 'C') {
      widget.controller.text = '';
      _isFirstPress = false; // 수동으로 지웠으므로 첫 터치 해제
    } else if (value == 'DEL') {
      final text = widget.controller.text;
      if (text.isNotEmpty) {
        widget.controller.text = text.substring(0, text.length - 1);
      }
      _isFirstPress = false; // 수동으로 지웠으므로 첫 터치 해제
    } else {
      // 💡 [핵심 수정] 패드가 열리고 처음 누르는 숫자/소수점이라면, 기존 값을 싹 비우고 새로 시작!
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
        if (text == '0') {
          widget.controller.text = value;
        } else {
          widget.controller.text = text + value;
        }
      }
    }
  }

  Widget _buildButton(
    String label, {
    Color? color,
    Color? textColor,
    int flex = 1,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: (color ?? btnColor).withOpacity(0.9),
            foregroundColor: textColor ?? Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.white.withOpacity(0.08)),
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
              // 💡 글자 크기 조건에 C와 DEL을 반영
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
      color: Colors.transparent,
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
              SizedBox(
                height: 24,
                width: 24,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white38,
                    size: 20,
                  ),
                  onPressed: widget.onApply, // 적용과 동일하게 닫기 처리
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: makitaTeal.withOpacity(0.5)),
            ),
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, child) {
                return Text(
                  widget.controller.text.isEmpty ? '0' : widget.controller.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
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
                      // 🔥 '초기화' -> 'C' 로 변경
                      _buildButton('C', color: Colors.orange[800]),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('4'),
                      _buildButton('5'),
                      _buildButton('6'),
                      // 🔥 '지우기' -> 'DEL' 로 변경
                      _buildButton('DEL', color: Colors.red[800]),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('1'),
                      _buildButton('2'),
                      _buildButton('3'),
                      _buildButton('.', color: Colors.blueGrey[800]),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('0', flex: 2), // 0 버튼 확장
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
