import 'package:flutter/material.dart';
import 'dart:ui'; // 반투명 블러 효과 패키지

const Color makitaTeal = Color(0xFF007580);
const Color numpadBg = Color(0xFF121212); // 조금 더 깊고 깨끗한 다크톤

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
      barrierColor: Colors.black.withOpacity(0.4), // 바깥쪽 배경을 살짝 더 투명하게
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24), // 좌우 여백 확보
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32), // 더 둥글고 부드러운 모서리
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 24.0,
              sigmaY: 24.0,
            ), // 블러 강도 Up (더 영롱하게)
            child: Container(
              width: 340,
              height: 520, // 여백을 위해 높이를 살짝 키움
              decoration: BoxDecoration(
                color: numpadBg.withOpacity(0.65), // 유리를 더 투명하게
                borderRadius: BorderRadius.circular(32),
                // 촌스러운 테두리(Border) 제거, 여백으로만 승부
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
  bool _isFirstPress = true; // 첫 터치 덮어쓰기 로직

  void _onKeyPressed(String value) {
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
          return; // 0일때 00 입력 무시
        } else {
          widget.controller.text = text + value;
        }
      }
    }
  }

  // 🔥 토스 스타일의 미니멀한 버튼 빌더
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
        padding: const EdgeInsets.all(6.0), // 버튼 간 여백 확보
        child: isPrimary
            ? ElevatedButton(
                // '적용' 버튼 스타일 (알약 형태)
                style: ElevatedButton.styleFrom(
                  backgroundColor: makitaTeal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () {
                  widget.onApply?.call();
                },
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
                // 일반 숫자 및 보조 액션 버튼 (배경 없음, 텍스트 강조)
                style: TextButton.styleFrom(
                  foregroundColor: textColor ?? Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: EdgeInsets.zero,
                ),
                onPressed: () {
                  _onKeyPressed(label);
                },
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isAction ? 20 : 28, // 숫자는 엄청 크게, 액션은 적당히
                    fontWeight: isAction ? FontWeight.w600 : FontWeight.w400,
                    fontFamily: isAction
                        ? null
                        : 'monospace', // 숫자는 고정폭 폰트로 깔끔하게
                  ),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28), // 전체 패딩 넉넉하게
      child: Column(
        children: [
          // 🚀 헤더 영역 (타이틀 & 닫기)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              if (widget.onApply != null)
                GestureDetector(
                  onTap: widget.onApply,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),

          const Spacer(flex: 1), // 위쪽 여백
          // 🚀 입력된 숫자 표시 영역 (박스 버리고 타이포그래피로만 승부)
          AnimatedBuilder(
            animation: widget.controller,
            builder: (context, child) {
              return Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  widget.controller.text.isEmpty ? '0' : widget.controller.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48, // 압도적인 크기
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

          const Spacer(flex: 1), // 박스와 키패드 사이 여백
          // 🚀 키패드 영역 (여백 빵빵하게)
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
                        textColor: Colors.orange.shade400,
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
                        textColor: Colors.red.shade400,
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
                      _buildButton(
                        '.',
                        textColor: Colors.white54,
                        isAction: true,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('00'),
                      _buildButton('0'),
                      _buildButton('적용', isPrimary: true, flex: 2), // 적용 버튼 강조
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
