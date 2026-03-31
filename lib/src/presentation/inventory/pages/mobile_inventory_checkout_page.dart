import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileInventoryCheckoutPage extends StatefulWidget {
  final String docId;
  final String itemName;
  final int currentQty;
  final bool isCheckout;
  final String workerName;
  final String unit;
  final String? checkoutDocId;
  final String? checkoutReason;

  const MobileInventoryCheckoutPage({
    super.key,
    required this.docId,
    required this.itemName,
    required this.currentQty,
    required this.isCheckout,
    required this.workerName,
    this.unit = 'EA',
    this.checkoutDocId,
    this.checkoutReason,
  });

  @override
  State<MobileInventoryCheckoutPage> createState() =>
      _MobileInventoryCheckoutPageState();
}

class _MobileInventoryCheckoutPageState
    extends State<MobileInventoryCheckoutPage> {
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;

  // 실시간 수량 및 에러 상태 관리를 위한 변수
  int _currentInputQty = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _qtyController.text = widget.isCheckout ? '' : widget.currentQty.toString();
    _currentInputQty = int.tryParse(_qtyController.text) ?? 0;

    if (!widget.isCheckout && widget.checkoutReason != null) {
      _reasonController.text = widget.checkoutReason!;
    }

    // 텍스트 필드 입력 감지 리스너 추가
    _qtyController.addListener(_validateQuantity);
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  // 실시간 수량 검증
  void _validateQuantity() {
    setState(() {
      _currentInputQty = int.tryParse(_qtyController.text) ?? 0;

      if (_currentInputQty < 0) {
        _errorMessage = "수량은 0보다 커야 합니다.";
      } else if (_currentInputQty > widget.currentQty) {
        _errorMessage = widget.isCheckout ? "보유 재고를 초과했습니다." : "불출한 수량보다 많습니다.";
      } else {
        _errorMessage = null;
      }
    });
  }

  // +/- 버튼을 위한 수량 조절 함수
  void _updateQuantity(int change) {
    int newQty = _currentInputQty + change;
    if (newQty < 0) newQty = 0;

    _qtyController.text = newQty.toString();
    // 커서를 항상 맨 끝으로 유지
    _qtyController.selection = TextSelection.fromPosition(
      TextPosition(offset: _qtyController.text.length),
    );
  }

  Future<void> _submit({bool unpinOnly = false}) async {
    // 에러가 떠있는 상태면 제출 막기
    if (_errorMessage != null) {
      _showSnackBar(_errorMessage!, Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (unpinOnly && widget.checkoutDocId != null) {
        await FirebaseFirestore.instance
            .collection('checkouts')
            .doc(widget.checkoutDocId)
            .delete();

        await FirebaseFirestore.instance.collection('inventory_logs').add({
          'material_name': widget.itemName,
          'type': 'OUT',
          'qty': widget.currentQty,
          'worker_name': widget.workerName,
          'project_name': "현장 전량 소진",
          'unit': widget.unit,
          'device': 'Mobile',
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        _showSnackBar("현장 소진 처리되어 목록에서 삭제되었습니다.", makitaTeal);
        Navigator.pop(context);
        return;
      }

      int amount = int.tryParse(_qtyController.text) ?? 0;
      if (amount <= 0) {
        _showSnackBar("수량을 1개 이상 입력해주세요.", Colors.redAccent);
        setState(() => _isLoading = false);
        return;
      }

      String reasonText = _reasonController.text.trim();
      if (reasonText.isEmpty) {
        _showSnackBar(
          widget.isCheckout ? "불출 사유를 입력해주세요." : "반납 사유를 입력해주세요.",
          Colors.redAccent,
        );
        setState(() => _isLoading = false);
        return;
      }

      int changeValue = widget.isCheckout ? -amount : amount;
      await FirebaseFirestore.instance
          .collection('inventory')
          .doc(widget.docId)
          .update({
            'qty': FieldValue.increment(changeValue),
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      if (widget.isCheckout) {
        await FirebaseFirestore.instance.collection('checkouts').add({
          'itemId': widget.docId,
          'itemName': widget.itemName,
          'unit': widget.unit,
          'workerName': widget.workerName,
          'checkoutQty': amount,
          'reason': reasonText,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else if (widget.checkoutDocId != null) {
        if (amount == widget.currentQty) {
          await FirebaseFirestore.instance
              .collection('checkouts')
              .doc(widget.checkoutDocId)
              .delete();
        } else {
          await FirebaseFirestore.instance
              .collection('checkouts')
              .doc(widget.checkoutDocId)
              .update({
                'checkoutQty': FieldValue.increment(-amount),
                'reason': reasonText,
              });
        }
      }

      await FirebaseFirestore.instance.collection('inventory_logs').add({
        'material_name': widget.itemName,
        'type': widget.isCheckout ? 'OUT' : 'IN',
        'qty': amount,
        'worker_name': widget.workerName,
        'project_name': reasonText,
        'unit': widget.unit,
        'device': 'Mobile',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSnackBar(
        widget.isCheckout ? "불출 처리되었습니다." : "반납 처리되었습니다.",
        makitaTeal,
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("오류가 발생했습니다: $e", Colors.redAccent);
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.bold, color: pureWhite),
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 주황색 테마를 제거하고, 모든 화면에서 마키타 틸(makitaTeal) 적용
    Color themeColor = makitaTeal;
    bool hasError = _errorMessage != null;

    return Scaffold(
      backgroundColor: slate100,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: themeColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: pureWhite),
        title: Text(
          widget.isCheckout ? "자재 불출" : "자재 반납 / 완료",
          style: const TextStyle(fontWeight: FontWeight.bold, color: pureWhite),
        ),
      ),
      // [UX 개선] 여백 터치 시 키보드 자동으로 내려가게 하기
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 상단 정보 카드
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: pureWhite,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: slate100, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: slate900.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  widget.itemName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: slate900,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  widget.isCheckout ? '현재 창고 재고' : '현재 내 불출 수량',
                                  style: const TextStyle(
                                    color: slate600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.currentQty} ${widget.unit}',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w900,
                                    color: themeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // [UX 개선] 수량 입력 타이틀 및 에러/예상 결과 인라인 표시
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "수량 입력",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: slate600,
                                  fontSize: 16,
                                ),
                              ),
                              if (hasError)
                                Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                )
                              // [UX 개선] 불출(Checkout)일 때만 처리 후 예상 재고 보여줌
                              else if (widget.isCheckout &&
                                  _currentInputQty > 0)
                                Text(
                                  "예상 재고: ${widget.currentQty - _currentInputQty}",
                                  style: TextStyle(
                                    color: themeColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // [UX 개선] + / - 버튼이 추가된 수량 입력 컨트롤러
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => _updateQuantity(-1),
                                icon: Icon(
                                  Icons.remove_circle_outline,
                                  color: themeColor,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _qtyController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: hasError
                                        ? Colors.redAccent
                                        : themeColor,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "0",
                                    filled: true,
                                    fillColor: pureWhite,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    // 에러 발생 시 테두리 색상을 빨간색으로 변경
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: hasError
                                          ? const BorderSide(
                                              color: Colors.redAccent,
                                              width: 2,
                                            )
                                          : BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: hasError
                                            ? Colors.redAccent
                                            : themeColor,
                                        width: 2,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: hasError
                                          ? const BorderSide(
                                              color: Colors.redAccent,
                                              width: 2,
                                            )
                                          : BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _updateQuantity(1),
                                icon: Icon(
                                  Icons.add_circle_outline,
                                  color: themeColor,
                                  size: 36,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          Text(
                            widget.isCheckout ? "불출 사유" : "반납 사유",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: slate600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _reasonController,
                            minLines: 1,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: widget.isCheckout
                                  ? "어디에 사용하시나요? (필수)"
                                  : "반납 사유를 적어주세요 (예: 작업완료, 불량 등)",
                              filled: true,
                              fillColor: pureWhite,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: themeColor,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),

                          const Spacer(),
                          const SizedBox(height: 24),

                          // [하단] 버튼 영역
                          if (!widget.isCheckout) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Colors.redAccent.shade200,
                                    width: 2,
                                  ),
                                  foregroundColor: Colors.redAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _isLoading
                                    ? null
                                    : () => _submit(unpinOnly: true),
                                icon: const Icon(Icons.remove_circle_outline),
                                label: const Text(
                                  "반납할 자재 없음 (전량 소진 완료)",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          SizedBox(
                            width: double.infinity,
                            height: 64,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeColor,
                                foregroundColor: pureWhite,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                // 에러 상태일 경우 버튼을 약간 투명하게 하여 비활성 느낌 부여 (선택적)
                                disabledBackgroundColor: themeColor.withOpacity(
                                  0.5,
                                ),
                              ),
                              onPressed: (_isLoading || hasError)
                                  ? null
                                  : () => _submit(),
                              icon: _isLoading
                                  ? const SizedBox.shrink()
                                  : Icon(
                                      widget.isCheckout
                                          ? Icons.outbox_outlined
                                          : Icons.check_circle_outline,
                                      size: 28,
                                    ),
                              label: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: pureWhite,
                                    )
                                  : Text(
                                      widget.isCheckout ? '불 출' : '반납 / 완료',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
