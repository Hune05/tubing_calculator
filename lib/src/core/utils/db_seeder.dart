import 'package:cloud_firestore/cloud_firestore.dart';

class SmartFittingDBSeeder {
  static Future<void> uploadInitialData() async {
    final firestore = FirebaseFirestore.instance;
    var batch = firestore.batch();
    final collectionRef = firestore.collection('fittings');

    List<Map<String, dynamic>> massiveData = _generateProfessionalCatalog();

    try {
      int count = 0;
      for (var data in massiveData) {
        DocumentReference docRef = collectionRef.doc(data['id']);
        batch.set(docRef, data);

        count++;
        if (count % 490 == 0) {
          await batch.commit();
          batch = firestore.batch();
        }
      }
      await batch.commit();
      print("✅ [진짜 최종 DB 구축 완료] 총 ${massiveData.length}개의 정밀 데이터 업로드!");
    } catch (e) {
      print("❌ 업로드 실패: $e");
    }
  }

  static List<Map<String, dynamic>> _generateProfessionalCatalog() {
    List<Map<String, dynamic>> result = [];
    final List<String> makers = ["Swagelok", "Parker", "Hy-Lok"];

    final Map<String, double> inchSizes = {
      '1/4': 15.2,
      '3/8': 17.8,
      '1/2': 22.9,
      '3/4': 24.4,
      '1': 31.2,
    };
    final Map<String, double> metricSizes = {
      '8mm': 16.2,
      '10mm': 17.2,
      '12mm': 22.8,
      '20mm': 26.0,
      '25mm': 31.3,
    };

    void processSizes(Map<String, double> sizes, String unit) {
      for (var maker in makers) {
        sizes.forEach((size, base) {
          String safeId = size.replaceAll('/', '_').replaceAll(' ', '_');

          // --- [FITTING] 기본 피팅류 ---
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'UNI',
            'Union',
            base * 0.75,
            'horizontal_rule',
            unit,
          );
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'BLK_UNI',
            'Bulkhead Union',
            base * 1.5,
            'view_agenda',
            unit,
          ); // 벌크헤드
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'EL90',
            '90° Union Elbow',
            base * 1.0,
            'turn_right',
            unit,
          );
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'EL45',
            '45° Union Elbow',
            base * 0.82,
            'turn_slight_right',
            unit,
          );
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'TEE',
            'Union Tee',
            base * 1.0,
            'call_split',
            unit,
          );
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'CRS',
            'Union Cross',
            base * 1.0,
            'add_box',
            unit,
          );
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'RED',
            'Reducing Union',
            base * 0.8,
            'trending_down',
            unit,
          );
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'PORT_CONN',
            'Port Connector',
            base * 0.6,
            'link',
            unit,
          ); // 포트콘넥터
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'ADAPTER',
            'Tube Adapter',
            base * 0.95,
            'compare_arrows',
            unit,
          );

          // --- [FITTING] 나사산 결합류 (Male/Female) ---
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'M_CONN',
            'Male Connector',
            base * 0.9,
            'settings_input_hdmi',
            unit,
          );
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'F_CONN',
            'Female Connector',
            base * 0.85,
            'settings_input_hdmi',
            unit,
          );
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'M_EL90',
            'Male Elbow',
            base * 1.0,
            'turn_right',
            unit,
          );
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'F_EL90',
            'Female Elbow',
            base * 1.1,
            'turn_right',
            unit,
          );
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'M_RUN_TEE',
            'Male Run Tee',
            base * 1.0,
            'call_split',
            unit,
          );
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'F_RUN_TEE',
            'Female Run Tee',
            base * 1.1,
            'call_split',
            unit,
          );
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'M_BRN_TEE',
            'Male Branch Tee',
            base * 1.0,
            'call_split',
            unit,
          );
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'F_BRN_TEE',
            'Female Branch Tee',
            base * 1.1,
            'call_split',
            unit,
          );

          // --- [FITTING] 어저스트류 (Adjustable) ---
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'ADJ_EL90',
            '90° Adjustable Elbow',
            base * 1.2,
            'turn_right',
            unit,
          );
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'ADJ_RUN_TEE',
            'Adjustable Run Tee',
            base * 1.2,
            'call_split',
            unit,
          );
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'ADJ_BRN_TEE',
            'Adjustable Branch Tee',
            base * 1.2,
            'call_split',
            unit,
          );

          // --- [FITTING] 마감류 ---
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'CAP',
            'Cap',
            base * 0.5,
            'block',
            unit,
          );
          _add(
            result,
            maker,
            'FITTING',
            size,
            safeId,
            'PLUG',
            'Plug',
            base * 0.4,
            'stop',
            unit,
          ); // 플러그 추가

          // --- [VALVE] 밸브류 ---
          _add(
            result,
            maker,
            'VALVE',
            size,
            safeId,
            'V_BALL',
            'Ball Valve',
            base * 1.9,
            'settings_input_component',
            unit,
          );
          _add(
            result,
            maker,
            'VALVE',
            size,
            safeId,
            'V_NEEDLE',
            'Needle Valve',
            base * 2.2,
            'settings_input_component',
            unit,
          );
          _add(
            result,
            maker,
            'VALVE',
            size,
            safeId,
            'V_CHECK',
            'Check Valve',
            base * 1.5,
            'verified_user',
            unit,
          );
          _add(
            result,
            maker,
            'VALVE',
            size,
            safeId,
            'V_RELIEF',
            'Relief Valve',
            base * 2.0,
            'settings_input_component',
            unit,
          );
          _add(
            result,
            maker,
            'VALVE',
            size,
            safeId,
            'V_MANI',
            'Manifold Valve',
            base * 2.5,
            'account_tree',
            unit,
          ); // 매니폴드
          _add(
            result,
            maker,
            'VALVE',
            size,
            safeId,
            'V_BLEED',
            'Bleed Valve',
            base * 1.1,
            'opacity',
            unit,
          ); // 블리드 밸브

          // --- [FLANGE] 플랜지류 ---
          _add(
            result,
            maker,
            'FLANGE',
            size,
            safeId,
            'FL_150',
            'ANSI 150# Flange',
            base * 1.7,
            'build_circle',
            unit,
          );
          _add(
            result,
            maker,
            'FLANGE',
            size,
            safeId,
            'FL_300',
            'ANSI 300# Flange',
            base * 1.9,
            'build_circle',
            unit,
          );
          _add(
            result,
            maker,
            'FLANGE',
            size,
            safeId,
            'FL_600',
            'ANSI 600# Flange',
            base * 2.2,
            'build_circle',
            unit,
          );

          // --- [SPECIAL] 기타 정밀 부속 ---
          _add(
            result,
            maker,
            'SPECIAL',
            size,
            safeId,
            'ORI',
            'Orifice Fitting',
            base * 1.1,
            'adjust',
            unit,
          );
          _add(
            result,
            maker,
            'SPECIAL',
            size,
            safeId,
            'FIL_IN',
            'Inline Filter',
            base * 1.4,
            'filter_list',
            unit,
          ); // 인라인 필터
          _add(
            result,
            maker,
            'SPECIAL',
            size,
            safeId,
            'FIL_TEE',
            'Tee-Type Filter',
            base * 1.6,
            'filter_list',
            unit,
          ); // 티 필터
          _add(
            result,
            maker,
            'SPECIAL',
            size,
            safeId,
            'QC',
            'Quick-Connect',
            base * 1.8,
            'power',
            unit,
          ); // 퀵 콘넥터
        });
      }
    }

    processSizes(inchSizes, 'inch');
    processSizes(metricSizes, 'metric');

    return result;
  }

  static void _add(
    List<Map<String, dynamic>> list,
    String maker,
    String group,
    String size,
    String safeId,
    String cat,
    String name,
    double ded,
    String icon,
    String unit,
  ) {
    double finalDeduction = ded;
    if (maker == 'Parker') finalDeduction *= 1.02;
    if (maker == 'Hy-Lok') finalDeduction *= 0.98;

    list.add({
      'id':
          '${maker.toLowerCase()}_${group.toLowerCase()}_${safeId}_${cat.toLowerCase()}',
      'maker': maker,
      'group': group,
      'tubeOD': size,
      'category': cat,
      'name': '$maker $size $name',
      'displayName': name,
      'deduction': double.parse(finalDeduction.toStringAsFixed(1)),
      'iconString': icon,
      'unit': unit,
    });
  }
}
