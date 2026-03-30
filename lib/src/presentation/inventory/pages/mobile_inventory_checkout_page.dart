import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
  final bool isPinned;

  const MobileInventoryCheckoutPage({
    super.key,
    required this.docId,
    required this.itemName,
    required this.currentQty,
    required this.isCheckout,
    required this.workerName,
    this.isPinned = false,
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

  Future<void> _submit({bool unpinOnly = false}) async {
    setState(() => _isLoading = true);

    try {
      if (unpinOnly) {
        await FirebaseFirestore.instance
            .collection('inventory')
            .doc(widget.docId)
            .update({
              'activeWorkers': FieldValue.arrayRemove([widget.workerName]),
            });

        if (!mounted) return;
        _showSnackBar("작업 완료! 목록에서 고정이 해제되었습니다.", makitaTeal);
        Navigator.pop(context);
        return;
      }

      int amount = int.tryParse(_qtyController.text) ?? 0;
      if (amount <= 0) {
        _showSnackBar("수량을 1개 이상 입력해주세요.", Colors.redAccent);
        setState(() => _isLoading = false);
        return;
      }

      if (widget.isCheckout && widget.currentQty < amount) {
        _showSnackBar("보유 재고보다 많이 불출할 수 없습니다.", Colors.redAccent);
        setState(() => _isLoading = false);
        return;
      }

      int changeValue = widget.isCheckout ? -amount : amount;

      dynamic workerAction;
      if (widget.isCheckout) {
        workerAction = FieldValue.arrayUnion([widget.workerName]);
      } else {
        workerAction = FieldValue.arrayRemove([widget.workerName]);
      }

      await FirebaseFirestore.instance
          .collection('inventory')
          .doc(widget.docId)
          .update({
            'qty': FieldValue.increment(changeValue),
            'lastUpdated': FieldValue.serverTimestamp(),
            'activeWorkers': workerAction,
          });

      // 🚀 [완벽 해결] 태블릿이 사용하는 공식 필드명(비밀 언어)으로 로그 전송!
      String projectName = _reasonController.text.trim();
      if (projectName.isEmpty) {
        projectName = widget.isCheckout ? "모바일 현장 불출" : "모바일 현장 반납";
      }

      await FirebaseFirestore.instance.collection('inventory_logs').add({
        'material_name': widget.itemName, // 👈 name 대신 material_name!
        'type': widget.isCheckout ? 'OUT' : 'IN', // 👈 action 대신 type IN/OUT!
        'qty': amount, // 로그에는 양수로 기록
        'worker_name': widget.workerName, // 👈 workerName 대신 worker_name!
        'project_name': projectName, // 👈 사유 대신 project_name!
        'unit': 'EA', // 👈 단위 필수
        'device': 'Mobile',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSnackBar(
        widget.isCheckout ? "불출 및 목록 고정 완료!" : "반납 및 고정 해제 완료!",
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slate100,
      appBar: AppBar(
        backgroundColor: makitaTeal,
        elevation: 0,
        iconTheme: const IconThemeData(color: pureWhite),
        title: Text(widget.isCheckout ? "자재 불출 (가져가기)" : "자재 반납 (작업 완료)"),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: pureWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: makitaTeal.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.itemName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '현재 창고 재고',
                      style: TextStyle(color: slate600, fontSize: 13),
                    ),
                    Text(
                      '${widget.currentQty}',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: makitaTeal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: widget.isCheckout ? '몇 개 가져가시나요?' : '몇 개 반납하시나요?',
                  filled: true,
                  fillColor: pureWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: "프로젝트명 또는 사유 입력",
                  filled: true,
                  fillColor: pureWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const Spacer(),

              if (!widget.isCheckout && widget.isPinned) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.redAccent.shade200,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLoading
                        ? null
                        : () => _submit(unpinOnly: true),
                    child: const Text(
                      "반납할 자재 없음 (전량 소진 / 목록에서 내리기)",
                      style: TextStyle(
                        color: Colors.redAccent,
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
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isCheckout
                        ? makitaTeal
                        : Colors.indigoAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : () => _submit(),
                  child: Text(
                    widget.isCheckout ? '불출 완료 (내 목록에 고정)' : '반납 완료 (목록에서 내리기)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
