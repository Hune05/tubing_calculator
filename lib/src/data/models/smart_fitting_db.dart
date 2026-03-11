import 'package:flutter/material.dart';
import 'fitting_item.dart';

class SmartFittingDB {
  static const List<String> makers = ["Swagelok", "Hy-Lok", "Parker"];
  static const List<String> tubeSizes = [
    "1/4\"",
    "3/8\"",
    "1/2\"",
    "3/4\"",
    "1\"",
  ];

  // 🚀 현장 기준 대분류 적용 완료
  static final List<FittingItem> allFittings = [
    // ---------------------------------------------------------
    // 🌟 치트키 (만능 커스텀 박스)
    // ---------------------------------------------------------
    const FittingItem(
      id: "custom_input",
      maker: "CUSTOM",
      tubeOD: "ALL",
      category: "커스텀",
      name: "직접 입력 (삽입 깊이)",
      deduction: 0.0,
      insertionDepth: 0.0,
      icon: Icons.edit_note,
      isCustom: true,
    ),
    const FittingItem(
      id: "none",
      maker: "ALL",
      tubeOD: "ALL",
      category: "직관",
      name: "없음 (직관)",
      deduction: 0.0,
      icon: Icons.horizontal_rule,
    ),

    // ---------------------------------------------------------
    // 🔗 유니온(Union) 류 - 엘보우, 티, 크로스 모두 포함!
    // ---------------------------------------------------------
    const FittingItem(
      id: "sw_uu_12",
      maker: "Swagelok",
      tubeOD: "1/2\"",
      category: "Union",
      name: "Straight Union (일자)",
      deduction: 12.0,
      icon: Icons.linear_scale,
    ),
    const FittingItem(
      id: "sw_ue_12",
      maker: "Swagelok",
      tubeOD: "1/2\"",
      category: "Union",
      name: "Union Elbow (90도)",
      deduction: 25.9,
      icon: Icons.turn_right,
    ),
    const FittingItem(
      id: "sw_ut_12",
      maker: "Swagelok",
      tubeOD: "1/2\"",
      category: "Union",
      name: "Union Tee (T자)",
      deduction: 25.9,
      icon: Icons.call_split,
    ),
    const FittingItem(
      id: "sw_uc_12",
      maker: "Swagelok",
      tubeOD: "1/2\"",
      category: "Union",
      name: "Union Cross (십자)",
      deduction: 25.9,
      icon: Icons.add,
    ),
    const FittingItem(
      id: "sw_ru_12_38",
      maker: "Swagelok",
      tubeOD: "1/2\"",
      category: "Union",
      name: "Reducing Union",
      deduction: 13.5,
      icon: Icons.compress,
    ),
    const FittingItem(
      id: "sw_bu_12",
      maker: "Swagelok",
      tubeOD: "1/2\"",
      category: "Union",
      name: "Bulkhead Union",
      deduction: 22.0,
      icon: Icons.view_sidebar,
    ),

    // ---------------------------------------------------------
    // 🔌 아답터(Adapter) 류
    // ---------------------------------------------------------
    const FittingItem(
      id: "sw_ta_12",
      maker: "Swagelok",
      tubeOD: "1/2\"",
      category: "Adapter",
      name: "Tube Adapter",
      deduction: 18.0,
      icon: Icons.electrical_services,
    ),
    const FittingItem(
      id: "sw_ma_12",
      maker: "Swagelok",
      tubeOD: "1/2\"",
      category: "Adapter",
      name: "Male Adapter",
      deduction: 24.5,
      icon: Icons.settings_input_component,
    ),
    const FittingItem(
      id: "sw_fa_12",
      maker: "Swagelok",
      tubeOD: "1/2\"",
      category: "Adapter",
      name: "Female Adapter",
      deduction: 21.0,
      icon: Icons.settings_input_hdmi,
    ),
    const FittingItem(
      id: "sw_ea_12",
      maker: "Swagelok",
      tubeOD: "1/2\"",
      category: "Adapter",
      name: "Elbow Adapter",
      deduction: 29.5,
      icon: Icons.keyboard_return,
    ),

    // ---------------------------------------------------------
    // ⚙️ 커넥터(Connector) 류
    // ---------------------------------------------------------
    const FittingItem(
      id: "sw_mc_12",
      maker: "Swagelok",
      tubeOD: "1/2\"",
      category: "Connector",
      name: "Male Connector",
      deduction: 22.1,
      icon: Icons.power,
    ),
    const FittingItem(
      id: "sw_fc_12",
      maker: "Swagelok",
      tubeOD: "1/2\"",
      category: "Connector",
      name: "Female Connector",
      deduction: 22.1,
      icon: Icons.power_off,
    ),

    // ---------------------------------------------------------
    // 🚰 밸브(Valve) 류
    // ---------------------------------------------------------
    const FittingItem(
      id: "sw_nv_12",
      maker: "Swagelok",
      tubeOD: "1/2\"",
      category: "Valve",
      name: "Needle Valve",
      deduction: 32.5,
      icon: Icons.tune,
    ),
    const FittingItem(
      id: "sw_bv_12",
      maker: "Swagelok",
      tubeOD: "1/2\"",
      category: "Valve",
      name: "Ball Valve",
      deduction: 48.0,
      icon: Icons.circle_outlined,
    ),
    const FittingItem(
      id: "sw_cv_12",
      maker: "Swagelok",
      tubeOD: "1/2\"",
      category: "Valve",
      name: "Check Valve",
      deduction: 28.5,
      icon: Icons.arrow_right_alt,
    ),
  ];

  // (아래 헬퍼 함수들은 그대로 둡니다)
  static List<FittingItem> getByMakerAndSize(String maker, String tubeOD) {
    return allFittings
        .where(
          (item) =>
              (item.maker == maker ||
                  item.maker == "ALL" ||
                  item.maker == "CUSTOM") &&
              (item.tubeOD == tubeOD || item.tubeOD == "ALL"),
        )
        .toList();
  }

  static List<FittingItem> getFilteredItems(String category) {
    return allFittings.where((item) => item.category == category).toList();
  }

  static FittingItem getById(String id) {
    return allFittings.firstWhere(
      (item) => item.id == id,
      orElse: () => allFittings.first,
    );
  }
}
