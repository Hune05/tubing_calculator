import 'package:flutter/material.dart';
import 'inventory_model.dart';

class InventoryItemCard extends StatelessWidget {
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

  final Color darkBg = const Color(0xFF1E2124);
  final Color cardBg = const Color(0xFF2A2E33);
  final Color mutedWhite = const Color(0xFFD0D4D9);

  @override
  Widget build(BuildContext context) {
    bool hasQty = data.qty > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasQty ? themeColor : Colors.white.withValues(alpha: 0.05),
          width: hasQty ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  itemName,
                  style: TextStyle(
                    color: mutedWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                children: [
                  _buildRoundButton(
                    Icons.remove,
                    () => onUpdateQuantity(-1),
                    false,
                  ),
                  GestureDetector(
                    onTap: onQuantityTap,
                    child: Container(
                      width: 50,
                      alignment: Alignment.center,
                      color: Colors.transparent,
                      child: Text(
                        data.qty.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  _buildRoundButton(Icons.add, () => onUpdateQuantity(1), true),
                ],
              ),
            ],
          ),

          // 수량이 1개 이상일 때만 추가 정보 입력창 표시
          if (hasQty) ...[
            const SizedBox(height: 16),

            // ★ 변경됨: 카테고리(categoryIndex) 제한을 없애고 모든 속성을 개방
            // 1. 보관 위치 (신규 추가)
            _buildFullWidthInputBtn(
              'Location',
              "보관 위치(Location) 입력",
              data.location,
              Icons.location_on,
            ),
            const SizedBox(height: 8),

            // 2. 재질
            _buildFullWidthInputBtn(
              'Material',
              "재질(Material) 선택",
              data.material,
              Icons.category,
            ),
            const SizedBox(height: 8),

            // 3. 제조사
            _buildFullWidthInputBtn(
              'Maker',
              "제조사(Maker) 선택",
              data.maker,
              Icons.factory,
            ),
            const SizedBox(height: 8),

            // 4. 히트 넘버
            _buildFullWidthInputBtn(
              'HeatNo',
              "히트 넘버(Heat No) 입력",
              data.heatNo,
              Icons.tag,
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
      onTap: () => onExtraInfoTap(infoType),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: darkBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEmpty
                ? Colors.redAccent.withValues(alpha: 0.4) // 미입력 시 붉은 테두리
                : Colors.greenAccent.withValues(alpha: 0.4), // 입력 완료 시 녹색 테두리
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isEmpty ? Colors.grey : Colors.greenAccent,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isEmpty ? hint : "$infoType: $value",
                style: TextStyle(
                  color: isEmpty ? Colors.grey.shade500 : Colors.greenAccent,
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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isAdd ? themeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isAdd ? themeColor : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(icon, color: isAdd ? Colors.white : mutedWhite, size: 24),
      ),
    );
  }
}
