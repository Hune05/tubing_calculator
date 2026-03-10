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

  // 🚀 3대장 제조사별 기초 핵심 데이터 (나중에 JSON/DB로 10MB 확장할 뼈대)
  // 현장에서 많이 쓰는 1/4", 3/8", 1/2" 위주로 구성 (공제값은 카탈로그 기준 근사치/예시)
  static final List<FittingItem> allFittings = [
    // ---------------------------------------------------------
    // 🔹 기본 공통 (제조사 무관)
    // ---------------------------------------------------------
    const FittingItem(
      id: "none",
      maker: "ALL",
      category: "직관",
      name: "없음 (직관)",
      tubeOD: "ALL",
      deduction: 0.0,
      icon: Icons.horizontal_rule,
    ),

    // ---------------------------------------------------------
    // 🔵 Swagelok (스웨즈락) 데이터 세트
    // ---------------------------------------------------------
    // 1/2" 스웨즈락
    const FittingItem(
      id: "sw_mc_12_npt14",
      maker: "Swagelok",
      category: "Connector",
      name: "Male Connector",
      tubeOD: "1/2\"",
      threadType: "NPT",
      threadSize: "1/4\"",
      deduction: 22.1,
      icon: Icons.settings_input_component,
    ),
    const FittingItem(
      id: "sw_mc_12_npt12",
      maker: "Swagelok",
      category: "Connector",
      name: "Male Connector",
      tubeOD: "1/2\"",
      threadType: "NPT",
      threadSize: "1/2\"",
      deduction: 27.4,
      icon: Icons.settings_input_component,
    ),
    const FittingItem(
      id: "sw_fc_12_npt12",
      maker: "Swagelok",
      category: "Connector",
      name: "Female Connector",
      tubeOD: "1/2\"",
      threadType: "NPT",
      threadSize: "1/2\"",
      deduction: 22.1,
      icon: Icons.settings_input_hdmi,
    ),
    const FittingItem(
      id: "sw_ue_12",
      maker: "Swagelok",
      category: "Elbow",
      name: "Union Elbow",
      tubeOD: "1/2\"",
      deduction: 25.9,
      icon: Icons.turn_right,
    ),
    const FittingItem(
      id: "sw_ut_12",
      maker: "Swagelok",
      category: "Tee",
      name: "Union Tee",
      tubeOD: "1/2\"",
      deduction: 25.9,
      icon: Icons.call_split,
    ),
    const FittingItem(
      id: "sw_uu_12",
      maker: "Swagelok",
      category: "Union",
      name: "Straight Union",
      tubeOD: "1/2\"",
      deduction: 12.0,
      icon: Icons.linear_scale,
    ),

    // 3/8" 스웨즈락
    const FittingItem(
      id: "sw_mc_38_npt14",
      maker: "Swagelok",
      category: "Connector",
      name: "Male Connector",
      tubeOD: "3/8\"",
      threadType: "NPT",
      threadSize: "1/4\"",
      deduction: 19.3,
      icon: Icons.settings_input_component,
    ),
    const FittingItem(
      id: "sw_ue_38",
      maker: "Swagelok",
      category: "Elbow",
      name: "Union Elbow",
      tubeOD: "3/8\"",
      deduction: 23.1,
      icon: Icons.turn_right,
    ),

    // 1/4" 스웨즈락
    const FittingItem(
      id: "sw_mc_14_npt14",
      maker: "Swagelok",
      category: "Connector",
      name: "Male Connector",
      tubeOD: "1/4\"",
      threadType: "NPT",
      threadSize: "1/4\"",
      deduction: 15.2,
      icon: Icons.settings_input_component,
    ),
    const FittingItem(
      id: "sw_ue_14",
      maker: "Swagelok",
      category: "Elbow",
      name: "Union Elbow",
      tubeOD: "1/4\"",
      deduction: 19.6,
      icon: Icons.turn_right,
    ),

    // ---------------------------------------------------------
    // 🔴 Hy-Lok (하이록) 데이터 세트
    // (스웨즈락과 호환되지만 미세하게 공제값이 다를 수 있음)
    // ---------------------------------------------------------
    // 1/2" 하이록
    const FittingItem(
      id: "hl_mc_12_npt12",
      maker: "Hy-Lok",
      category: "Connector",
      name: "Male Connector",
      tubeOD: "1/2\"",
      threadType: "NPT",
      threadSize: "1/2\"",
      deduction: 27.2,
      icon: Icons.settings_input_component,
    ),
    const FittingItem(
      id: "hl_ue_12",
      maker: "Hy-Lok",
      category: "Elbow",
      name: "Union Elbow",
      tubeOD: "1/2\"",
      deduction: 26.0,
      icon: Icons.turn_right,
    ),
    const FittingItem(
      id: "hl_ut_12",
      maker: "Hy-Lok",
      category: "Tee",
      name: "Union Tee",
      tubeOD: "1/2\"",
      deduction: 26.0,
      icon: Icons.call_split,
    ),
    // 하이록 밸브류 (예시)
    const FittingItem(
      id: "hl_bv_12",
      maker: "Hy-Lok",
      category: "Valve",
      name: "Ball Valve (112 Series)",
      tubeOD: "1/2\"",
      deduction: 48.5,
      icon: Icons.gamepad,
    ),

    // ---------------------------------------------------------
    // 🟡 Parker (파커 A-LOK) 데이터 세트
    // ---------------------------------------------------------
    // 1/2" 파커
    const FittingItem(
      id: "pk_mc_12_npt12",
      maker: "Parker",
      category: "Connector",
      name: "Male Connector",
      tubeOD: "1/2\"",
      threadType: "NPT",
      threadSize: "1/2\"",
      deduction: 27.5,
      icon: Icons.settings_input_component,
    ),
    const FittingItem(
      id: "pk_ue_12",
      maker: "Parker",
      category: "Elbow",
      name: "Union Elbow",
      tubeOD: "1/2\"",
      deduction: 26.2,
      icon: Icons.turn_right,
    ),
  ];

  // ============================================================================
  // 🔍 깔때기 필터 엔진 (10MB 데이터가 쌓여도 0.01초 만에 찾아내는 핵심 로직)
  // ============================================================================

  // 1단계: 메이커 & 튜브 규격에 맞는 부속만 가져오기
  static List<FittingItem> getByMakerAndSize(String maker, String tubeOD) {
    return allFittings
        .where(
          (item) =>
              (item.maker == maker || item.maker == "ALL") &&
              (item.tubeOD == tubeOD || item.tubeOD == "ALL"),
        )
        .toList();
  }

  // 2단계: 위 결과에서 카테고리(Elbow, Connector 등) 중복 없이 뽑아내기
  static List<String> getCategories(String maker, String tubeOD) {
    final filtered = getByMakerAndSize(maker, tubeOD);
    return filtered.map((e) => e.category).toSet().toList();
  }

  // 3단계: 최종적으로 바텀 시트에 뿌려줄 리스트
  static List<FittingItem> getFilteredItems(
    String maker,
    String tubeOD,
    String category,
  ) {
    return allFittings
        .where(
          (item) =>
              (item.maker == maker || item.maker == "ALL") &&
              (item.tubeOD == tubeOD || item.tubeOD == "ALL") &&
              item.category == category,
        )
        .toList();
  }

  // ID로 부속 찾기 (안전 장치 포함)
  static FittingItem getById(String id) {
    return allFittings.firstWhere(
      (item) => item.id == id,
      orElse: () => allFittings.first,
    );
  }
}
