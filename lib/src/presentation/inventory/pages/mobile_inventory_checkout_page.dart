import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

// 🎨 미니멀 감성을 위한 색상 정의
const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF191F28); // 토스 스타일의 부드러운 검정
const Color slate600 = Color(0xFF8B95A1); // 토스 스타일의 세련된 회색
const Color slate100 = Color(0xFFF2F4F6); // 토스 스타일의 배경 회색
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

    _qtyController.addListener(_validateQuantity);
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _validateQuantity() {
    setState(() {
      _currentInputQty = int.tryParse(_qtyController.text) ?? 0;

      if (_currentInputQty < 0) {
        _errorMessage = "수량은 0보다 커야 해요";
      } else if (_currentInputQty > widget.currentQty) {
        _errorMessage = widget.isCheckout ? "창고에 있는 재고보다 많아요" : "불출했던 수량보다 많아요";
      } else {
        _errorMessage = null;
      }
    });
  }

  void _updateQuantity(int change) {
    HapticFeedback.lightImpact();
    int newQty = _currentInputQty + change;
    if (newQty < 0) newQty = 0;

    _qtyController.text = newQty.toString();
    _qtyController.selection = TextSelection.fromPosition(
      TextPosition(offset: _qtyController.text.length),
    );
  }

  Future<void> _submit({bool unpinOnly = false}) async {
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
        _showSnackBar("현장 소진 처리되어 목록에서 삭제됐어요", slate900);
        Navigator.pop(context);
        return;
      }

      int amount = int.tryParse(_qtyController.text) ?? 0;
      if (amount <= 0) {
        _showSnackBar("수량을 1개 이상 입력해주세요", Colors.redAccent);
        setState(() => _isLoading = false);
        return;
      }

      String reasonText = _reasonController.text.trim();
      if (reasonText.isEmpty) {
        _showSnackBar(
          widget.isCheckout ? "어디에 사용하시는지 적어주세요" : "반납하시는 이유를 적어주세요",
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
      HapticFeedback.mediumImpact();
      _showSnackBar(
        widget.isCheckout ? "성공적으로 불출되었어요" : "성공적으로 반납되었어요",
        makitaTeal,
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("오류가 발생했어요: $e", Colors.redAccent);
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.w600, color: pureWhite),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 🚀 토스 스타일의 동그란 +/- 버튼 위젯
  Widget _buildCircleBtn(IconData icon, VoidCallback onTap, bool isDisabled) {
    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: slate100, shape: BoxShape.circle),
        child: Icon(
          icon,
          color: isDisabled ? slate600.withOpacity(0.3) : slate900,
          size: 28,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasError = _errorMessage != null;

    return Scaffold(
      backgroundColor: pureWhite, // 전체 배경을 새하얗게 변경
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0, // 스크롤 시 배경색 변하는 현상 방지
        iconTheme: const IconThemeData(color: slate900),
        centerTitle: true,
        title: Text(
          widget.isCheckout ? "자재 불출" : "자재 반납",
          style: const TextStyle(
            color: slate900,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // 🌟 토스 스타일의 큼직한 타이틀
                      Text(
                        widget.itemName,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: slate900,
                          height: 1.3,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.isCheckout
                            ? '현재 창고에 ${widget.currentQty} ${widget.unit} 남았어요'
                            : '내가 가져간 수량은 ${widget.currentQty} ${widget.unit} 이에요',
                        style: const TextStyle(
                          color: slate600,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 56),

                      // 🌟 미니멀한 수량 입력부 (테두리 없음)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildCircleBtn(
                            Icons.remove,
                            () => _updateQuantity(-1),
                            _currentInputQty <= 0,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _qtyController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                color: hasError ? Colors.redAccent : makitaTeal,
                                letterSpacing: -1,
                              ),
                              decoration: const InputDecoration(
                                hintText: "0",
                                hintStyle: TextStyle(color: slate600),
                                border: InputBorder.none, // 테두리 완벽 제거
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          _buildCircleBtn(
                            Icons.add,
                            () => _updateQuantity(1),
                            false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 에러 또는 안내 메시지
                      Center(
                        child: AnimatedOpacity(
                          opacity:
                              (hasError ||
                                  (widget.isCheckout && _currentInputQty > 0))
                              ? 1.0
                              : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            hasError
                                ? _errorMessage!
                                : "불출 후 ${widget.currentQty - _currentInputQty} ${widget.unit} 남아요",
                            style: TextStyle(
                              color: hasError ? Colors.redAccent : slate600,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // 🌟 사유 입력 (깔끔한 회색 박스)
                      const Text(
                        "사유",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: slate900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reasonController,
                        minLines: 1,
                        maxLines: 3,
                        style: const TextStyle(
                          fontSize: 16,
                          color: slate900,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: widget.isCheckout
                              ? "어디에 사용하시나요?"
                              : "반납 사유를 적어주세요 (예: 불량, 남음)",
                          hintStyle: TextStyle(
                            color: slate600.withOpacity(0.6),
                            fontWeight: FontWeight.normal,
                          ),
                          filled: true,
                          fillColor: slate100, // 토스 특유의 배경색
                          contentPadding: const EdgeInsets.all(20),
                          // 거슬리는 테두리 선 모두 제거
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // 🌟 하단 고정 버튼 영역
              Container(
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: 24,
                  top: 12,
                ),
                decoration: const BoxDecoration(
                  color: pureWhite, // 버튼 영역도 하얗게
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!widget.isCheckout) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: slate100,
                            foregroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _isLoading
                              ? null
                              : () => _submit(unpinOnly: true),
                          child: const Text(
                            "현장에서 전량 소진했어요",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: makitaTeal,
                          foregroundColor: pureWhite,
                          disabledBackgroundColor: slate100,
                          disabledForegroundColor: slate600,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16), // 둥근 모서리
                          ),
                        ),
                        onPressed:
                            (_isLoading || hasError || _currentInputQty == 0)
                            ? null
                            : () => _submit(),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: slate600,
                                  strokeWidth: 3,
                                ),
                              )
                            : Text(
                                widget.isCheckout ? '불출하기' : '반납하기',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
