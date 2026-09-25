import 'package:tubing_calculator/src/core/utils/fitting_data.dart';

class SettingsController {
  // 1. 인치/미리 모드에 따른 OD(외경) 드롭다운 리스트 제공
  static List<String> getOdList(bool isInch) {
    if (isInch) {
      return [
        "0.125",
        "0.25",
        "0.3125",
        "0.375",
        "0.5",
        "0.625",
        "0.75",
        "0.875",
        "1.0",
      ];
    } else {
      return [
        "3.0",
        "4.0",
        "6.0",
        "8.0",
        "10.0",
        "12.0",
        "14.0",
        "15.0",
        "16.0",
        "18.0",
        "20.0",
        "22.0",
        "25.0",
      ];
    }
  }

  /// OD 목록에 지금 값([current])이 없으면(12.7 같은 인치 관을 mm로 볼 때) 끼워 넣는다.
  /// 예전엔 목록 첫 값(3.0)으로 떨어져 그대로 저장되어, 관 굵기가 3mm가 됐다.
  /// 폰 설정 탭·태블릿 설정 화면이 같이 쓴다.
  static List<String> odListIncluding(bool isInch, String current) {
    final base = getOdList(isInch);
    if (base.contains(current)) return base;
    final v = double.tryParse(current);
    if (v == null || v <= 0) return base;
    return [...base, current]
      ..sort((a, b) => double.parse(a).compareTo(double.parse(b)));
  }

  // 2. 소수점을 현장에서 쓰는 분수(1/4", 3/8" 등)로 예쁘게 바꿔주는 함수
  static String getDisplayOD(String item, bool isInch) {
    if (!isInch) return "$item mm";
    switch (item) {
      case "0.125":
        return "1/8\"";
      case "0.25":
        return "1/4\"";
      case "0.3125":
        return "5/16\"";
      case "0.375":
        return "3/8\"";
      case "0.5":
        return "1/2\"";
      case "0.625":
        return "5/8\"";
      case "0.75":
        return "3/4\"";
      case "0.875":
        return "7/8\"";
      case "1.0":
        return "1\"";
      default:
        return "$item\"";
    }
  }

  // 🔥 3. 핵심 수정: 엉뚱한 하드코딩 값을 지우고, 방금 만든 '진짜' FittingData를 불러오도록 연결!
  static BenderSpec? getStandardSpecs(String brand, String od) {
    return FittingData.getBenderSpec(brand, od);
  }
}
