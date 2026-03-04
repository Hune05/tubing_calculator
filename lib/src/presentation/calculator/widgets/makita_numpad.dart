import 'package:flutter/material.dart';

// 💡 [테마 컬러] 눈이 편안한 부드러운 슬레이트 톤 추가
const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate200 = Color(0xFFE2E8F0); // 디스플레이(입력창)용 살짝 눌러준 색
const Color slate50 = Color(0xFFF8FAFC); // 패드 전체 배경 (쨍하지 않은 부드러운 화이트)
const Color pureWhite = Color(0xFFFFFFFF); // 버튼용 순백색

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

  // 💡 바텀 시트(팝업)로 띄울 때
  static void show(
    BuildContext context, {
    required TextEditingController controller,
    required String title,
  }) {
    showModalBottomSheet(
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
            color: slate50, // 🔥 전체 배경을 눈이 편안한 slate50으로 톤 다운
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
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
  void _onKeyPressed(String value) {
    final text = widget.controller.text;

    if (value == 'C') {
      widget.controller.text = '';
    } else if (value == 'DEL') {
      if (text.isNotEmpty) {
        widget.controller.text = text.substring(0, text.length - 1);
      }
    } else if (value == '.') {
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

  // 💡 개별 버튼 빌더
  Widget _buildButton(
    String label, {
    Color? color,
    Color? textColor,
    int flex = 1,
  }) {
    // 기본 숫자 버튼: 배경보다 한 단계 밝은 하얀색으로 튀어나오게 연출
    Color bgColor = color ?? pureWhite;
    Color txtColor = textColor ?? (color == null ? slate900 : pureWhite);

    // 소수점 버튼은 약간 회색빛을 주어 보조 버튼임을 암시
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
            elevation: color == null ? 1 : 2, // 일반 버튼은 은은한 그림자
            shadowColor: color != null
                ? color.withOpacity(0.4)
                : Colors.black.withOpacity(0.2), // 화이트 버튼의 은은한 입체감
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              // 보더 대신 입체감(Elevation)으로 형태를 분리하여 깔끔하게 처리
            ),
            padding: EdgeInsets.zero,
          ),
          onPressed: () {
            if (label == '적용' || label == 'ENTER') {
              widget.onApply?.call();
            } else {
              _onKeyPressed(label);
            }
          },
          child: Text(
            label,
            style: TextStyle(
              fontSize:
                  (label == '적용' ||
                      label == 'ENTER' ||
                      label == 'DEL' ||
                      label == 'C')
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slate50, // 🔥 부드러운 오프화이트 배경
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 🔹 헤더 (타이틀 및 닫기 버튼)
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
                IconButton(
                  icon: const Icon(Icons.close, color: slate600),
                  onPressed: widget.onApply,
                ),
            ],
          ),
          const SizedBox(height: 8),

          // 🔹 실시간 입력값 디스플레이 창
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: slate200, // 🔥 디스플레이는 패드 배경보다 살짝 더 어두운 회색으로 눌러줌 (음각 효과)
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300, width: 1.0),
              boxShadow: [
                BoxShadow(
                  // 디스플레이가 안으로 파인 듯한 느낌 (Inner shadow 흉내)
                  color: Colors.black.withOpacity(0.02),
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

          // 🔹 키패드 그리드
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
