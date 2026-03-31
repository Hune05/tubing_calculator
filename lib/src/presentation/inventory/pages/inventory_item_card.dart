import 'package:flutter/material.dart';
import 'inventory_model.dart';

const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class InventoryItemCard extends StatefulWidget {
  final String itemName;
  final ItemData data;
  final int categoryIndex;
  final Color themeColor;

  final Function(int delta) onUpdateQuantity;
  final VoidCallback onQuantityTap;
  final Function(String infoType) onExtraInfoTap;

  const InventoryItemCard({
    super.key,
    required this.itemName,
    required this.data,
    required this.categoryIndex,
    required this.themeColor,
    required this.onUpdateQuantity,
    required this.onQuantityTap,
    required this.onExtraInfoTap,
  });

  @override
  State<InventoryItemCard> createState() => _InventoryItemCardState();
}

class _InventoryItemCardState extends State<InventoryItemCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    bool hasQty = widget.data.qty > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasQty ? widget.themeColor : Colors.grey.shade300,
          width: hasQty ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: widget.themeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.itemName,
                            style: const TextStyle(
                              color: slate900,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _buildRoundButton(
                        Icons.remove,
                        () => widget.onUpdateQuantity(-1),
                        false,
                      ),
                      GestureDetector(
                        onTap: widget.onQuantityTap,
                        child: Container(
                          width: 44,
                          alignment: Alignment.center,
                          color: Colors.transparent,
                          child: Text(
                            widget.data.qty.toString(),
                            style: TextStyle(
                              color: hasQty ? widget.themeColor : slate900,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      _buildRoundButton(
                        Icons.add,
                        () => widget.onUpdateQuantity(1),
                        true,
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: slate600,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                children: [
                  Divider(color: Colors.grey.shade200),
                  const SizedBox(height: 8),

                  _buildFullWidthInputBtn(
                    'Location',
                    "보관 위치",
                    widget.data.location,
                    Icons.location_on,
                  ),
                  const SizedBox(height: 8),
                  _buildFullWidthInputBtn(
                    'Material',
                    "재질",
                    widget.data.material,
                    Icons.category,
                  ),
                  const SizedBox(height: 8),
                  _buildFullWidthInputBtn(
                    'Maker',
                    "제조사",
                    widget.data.maker,
                    Icons.factory,
                  ),
                  const SizedBox(height: 8),
                  _buildFullWidthInputBtn(
                    'Spec',
                    "규격",
                    widget.data.spec,
                    Icons.straighten,
                  ),
                  const SizedBox(height: 8),

                  // ★ 신규: 담당 부서/팀
                  _buildFullWidthInputBtn(
                    'Department',
                    "담당 부서/팀",
                    widget.data.department,
                    Icons.groups,
                  ),
                  const SizedBox(height: 8),

                  _buildFullWidthInputBtn(
                    'Project',
                    "프로젝트",
                    widget.data.projectName,
                    Icons.assignment,
                  ),
                  const SizedBox(height: 8),
                  _buildFullWidthInputBtn(
                    'MinQty',
                    "최소 유지 수량",
                    widget.data.minQty == 0
                        ? ""
                        : widget.data.minQty.toString(),
                    Icons.security,
                  ),
                  const SizedBox(height: 8),
                  _buildFullWidthInputBtn(
                    'HeatNo',
                    "히트 넘버",
                    widget.data.heatNo,
                    Icons.tag,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFullWidthInputBtn(
    String infoType,
    String hint,
    String value,
    IconData icon,
  ) {
    bool isEmpty = value.isEmpty;
    return InkWell(
      onTap: () => widget.onExtraInfoTap(infoType),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: slate100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEmpty
                ? Colors.grey.shade300
                : widget.themeColor.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isEmpty ? Colors.grey.shade400 : widget.themeColor,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isEmpty ? "$hint 입력" : "$infoType: $value",
                style: TextStyle(
                  color: isEmpty ? Colors.grey.shade500 : slate900,
                  fontSize: 14,
                  fontWeight: isEmpty ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundButton(IconData icon, VoidCallback onPressed, bool isAdd) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isAdd ? widget.themeColor : slate100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isAdd ? widget.themeColor : Colors.grey.shade300,
          ),
        ),
        child: Icon(icon, color: isAdd ? pureWhite : slate600, size: 20),
      ),
    );
  }
}
