// lib/src/presentation/calculator/widgets/makita_numpad.dart
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';

const Color makitaTeal = AppColors.brand;
const Color slate900 = AppColors.text;
const Color slate600 = AppColors.textSub;
const Color slate200 = AppColors.line;
const Color slate100 = AppColors.background; // 🚀 이 줄을 추가해 주세요!
const Color slate50 = Color(0xFFF8FAFC);
const Color pureWhite = Color(0xFFFFFFFF);

class MakitaNumpad extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onApply;

  /// 머리의 X(닫기). 없으면 [onApply]와 같다(태블릿 화면에 붙박은 숫자판).
  final VoidCallback? onCancel;
  final String title;

  /// "적용" 옆의 "추가"(또는 "수정") 단추. 숫자를 넣고 창을 닫으면서 바로 목록에 넣는다.
  /// null이면 단추가 없다. 숫자가 0이거나 비어 있으면 누를 수 없다.
  final VoidCallback? onAdd;
  final String addLabel;

  /// 음수도 받는지(10-09: 기준선 오프셋처럼 앞으로 당기는 값). 켜면 "00" 자리에 "±" 단추.
  final bool allowNegative;

  const MakitaNumpad({
    super.key,
    required this.controller,
    this.onApply,
    this.onCancel,
    this.onAdd,
    this.addLabel = "추가",
    this.title = "수치 입력",
    this.allowNegative = false,
  });

  /// 숫자판 창. "적용"을 눌러야 새 값이 남는다.
  /// 🚀 [고침] 예전에는 누를 때마다 칸이 바뀌고(첫 키에 원래 값을 지움), 머리의 X도
  /// "적용"과 같아서, 잘못 누르고 X·바깥 누르기·뒤로 가기로 닫아도 틀린 값이 남았다.
  /// 이제 X·바깥·뒤로는 열 때 값으로 되돌린다.
  ///
  /// [addLabel]을 주면 "적용" 옆에 "추가" 단추가 생긴다. 그것을 눌러 닫았으면 true를 돌려준다
  /// (값은 적용된 상태). 부르는 쪽이 그때 바로 목록에 넣는다.
  static Future<bool> show(
    BuildContext context, {
    required TextEditingController controller,
    required String title,
    String? addLabel,
    bool allowNegative = false,
  }) async {
    final original = controller.text;
    var applied = false;
    var added = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          height: 500, // 여백을 위해 높이를 살짝 확보
          decoration: BoxDecoration(
            // 연 화면의 보기 색(현장 화면이면 햇빛·야간)을 따른다.
            color: FieldPalette.ofContext(context).surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(32),
            ), // 더 둥근 모서리
          ),
          child: MakitaNumpad(
            controller: controller,
            title: title,
            onApply: () {
              applied = true;
              Navigator.pop(context);
            },
            onCancel: () => Navigator.pop(context),
            addLabel: addLabel ?? "추가",
            allowNegative: allowNegative,
            onAdd: addLabel == null
                ? null
                : () {
                    applied = true;
                    added = true;
                    Navigator.pop(context);
                  },
          ),
        ),
      ),
    );
    if (!applied && controller.text != original) controller.text = original;
    return added;
  }

  @override
  State<MakitaNumpad> createState() => _MakitaNumpadState();
}

class _MakitaNumpadState extends State<MakitaNumpad> {
  // 연 자리의 보기 색(현장 화면이면 햇빛·야간, 아니면 보통).
  FieldPalette get _p => FieldPalette.ofContext(context);

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
      } else if (value == '±') {
        // 부호만 바꾼다(친 숫자는 그대로, 다음 숫자는 뒤에 붙는다).
        // 8차: 숫자판을 열자마자 ±를 누르면 원래 값("0.0")에 이어 붙어 "-0.015"가 됐다 → 칸을 "-"로 비운다.
        final text = _isFirstPress ? '' : widget.controller.text;
        widget.controller.text =
            text.startsWith('-') ? text.substring(1) : '-$text';
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
            widget.controller.text = text.isEmpty ? '0.' : '$text.';
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
                  backgroundColor: _p.brand,
                  foregroundColor: _p.onBrand,
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
                  foregroundColor: textColor ?? _p.text, // 기본 숫자 색상 (다크)
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

  /// "추가"가 있을 때의 "적용": 눈에 덜 띄는 알약.
  Widget _buildQuietApply() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: ElevatedButton(
          key: const Key('numpad_apply'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _p.background,
            foregroundColor: _p.brand,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            padding: EdgeInsets.zero,
          ),
          onPressed: () => widget.onApply?.call(),
          child: const Text(
            '적용',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  /// 값이 0보다 클 때만 누를 수 있는 "추가"(또는 "수정").
  Widget _buildAddButton() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final v = double.tryParse(widget.controller.text) ?? 0.0;
            return ElevatedButton(
              key: const Key('numpad_add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _p.brand,
                foregroundColor: _p.onBrand,
                disabledBackgroundColor: _p.brand.withValues(alpha: 0.3),
                disabledForegroundColor: _p.onBrand.withValues(alpha: 0.8),
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: EdgeInsets.zero,
              ),
              onPressed: v > 0 ? () => widget.onAdd?.call() : null,
              child: Text(
                widget.addLabel,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
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
              // 제목이 길면 두 줄로 내려간다(닫기 단추 자리를 먼저 준다).
              Flexible(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    color: _p.text, // 너무 튀지 않게 진한 차콜색으로
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (widget.onApply != null)
                GestureDetector(
                  key: const Key('numpad_close'),
                  onTap: widget.onCancel ?? widget.onApply,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _p.background, // 은은한 회색 원형 배경
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, color: _p.textSub, size: 18),
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
                  style: TextStyle(
                    color: _p.text,
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
                        textColor: (_p == FieldPalette.normal
                            ? Colors.orange.shade600
                            : _p.caution),
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
                        textColor: (_p == FieldPalette.normal
                            ? Colors.red.shade500
                            : _p.danger),
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
                      _buildButton('.', textColor: _p.textSub, isAction: true),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      widget.allowNegative
                          ? _buildButton('±', textColor: _p.textSub, isAction: true)
                          : _buildButton('00'),
                      _buildButton('0'),
                      if (widget.onAdd == null)
                        _buildButton(
                          '적용',
                          isPrimary: true,
                          flex: 2,
                        ) // 확 눈에 띄는 알약 버튼
                      else ...[
                        _buildQuietApply(),
                        _buildAddButton(),
                      ],
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
