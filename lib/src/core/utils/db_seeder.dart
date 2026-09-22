import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class SmartFittingDBSeeder {
  // 🚀 [피팅 고도화] 국내 현장에서 자주 쓰는 국산 대표 피팅 브랜드
  // DK-Lok을 추가했다. 기존 3개 브랜드는 그대로 두고 하나만 늘렸다.
  static const List<String> makers = ["Swagelok", "Parker", "Hy-Lok", "DK-Lok"];

  // 🚀 [피팅 고도화] Male/Female 커넥터류(나사 결합)는 관경마다 대응하는
  // 표준 나사 규격이 있다. Swagelok 계열 카탈로그에서 널리 쓰이는
  // 대응표를 따랐는데, 브랜드/생산 시기에 따라 미세한 차이가 있을 수
  // 있으니 실제 발주 전엔 카탈로그로 재확인이 필요하다(정밀 공학
  // 데이터가 아니라 검색/분류용 근사치).
  static const Map<String, String> _inchToNptSize = {
    '1/4': '1/8',
    '3/8': '1/4',
    '1/2': '1/4',
    '3/4': '1/2',
    '1': '3/4',
  };
  static const Map<String, String> _metricToNptSize = {
    '8mm': '1/8',
    '10mm': '1/4',
    '12mm': '1/4',
    '20mm': '1/2',
    '25mm': '3/4',
  };

  static Future<void> uploadInitialData() async {
    final firestore = FirebaseFirestore.instance;
    final collectionRef = firestore.collection('fittings');

    try {
      // 🚀 [피팅 고도화] 커넥터가 NPT/BSPT 두 개로 늘어나고 리듀서가
      // 사이즈쌍 기준으로 바뀌는 등 카탈로그 구성 자체가 바뀌면, 예전
      // id 체계로 만들어진 문서는 새 목록에 없어서 그대로 남아 고아
      // 데이터가 된다. 매번 컬렉션을 통째로 비우고 다시 올려서 항상
      // 지금 카탈로그 정의와 정확히 일치하게 한다 - 이 컬렉션엔 커스텀
      // 부속(현장에서 직접 입력한 것)이 저장되지 않으니 안전하다.
      await _deleteAllDocs(collectionRef);

      var batch = firestore.batch();
      List<Map<String, dynamic>> massiveData = _generateProfessionalCatalog();

      int count = 0;
      for (var data in massiveData) {
        DocumentReference docRef = collectionRef.doc(data['id']);
        batch.set(docRef, data);

        count++;
        if (count % 450 == 0) {
          await batch.commit();
          batch = firestore.batch();
        }
      }
      await batch.commit();
      debugPrint("✅ [진짜 최종 DB 구축 완료] 총 ${massiveData.length}개의 정밀 데이터 업로드!");
    } catch (e) {
      debugPrint("❌ 업로드 실패: $e");
    }
  }

  static Future<void> _deleteAllDocs(
    CollectionReference<Map<String, dynamic>> ref,
  ) async {
    while (true) {
      final snap = await ref.limit(450).get();
      if (snap.docs.isEmpty) break;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  static List<Map<String, dynamic>> _generateProfessionalCatalog() {
    List<Map<String, dynamic>> result = [];

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
      final Map<String, String> threadMap = unit == 'inch'
          ? _inchToNptSize
          : _metricToNptSize;

      for (var maker in makers) {
        sizes.forEach((size, base) {
          String safeId = size.replaceAll('/', '_').replaceAll(' ', '_');

          // 🚀 [피팅 고도화] Male/Female 나사 결합류 + 포트 콘넥터는
          // 나사산 타입(NPT/BSPT)에 따라 실제로 다른 부품이라, 관경당
          // 하나씩만 있던 걸 두 나사산 버전으로 나눠서 각각 검색/선택
          // 가능하게 했다.
          void addThreaded(String cat, String name, double ded, String icon) {
            final String? threadSize = threadMap[size];
            if (threadSize == null) return;
            for (final threadType in ['NPT', 'BSPT']) {
              _add(
                result,
                maker,
                'FITTING',
                size,
                safeId,
                cat,
                name,
                ded,
                icon,
                unit,
                threadType: threadType,
                threadSize: threadSize,
              );
            }
          }

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
          // 🚀 [피팅 고도화] 예전엔 "Reducing Union"이 같은 규격 안에서
          // 존재해서 실제로 뭘 뭘로 줄이는지 표현이 안 됐다. 이제
          // processSizes 루프가 끝난 뒤 _addReducingUnions에서 규격
          // 쌍(예: 1/2 x 3/8)으로 따로 만든다.
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

          // --- [FITTING] 나사산 결합류 (Male/Female, NPT/BSPT 각각) ---
          addThreaded(
            'M_CONN',
            'Male Connector',
            base * 0.9,
            'settings_input_hdmi',
          );
          addThreaded(
            'F_CONN',
            'Female Connector',
            base * 0.85,
            'settings_input_hdmi',
          );
          addThreaded('M_EL90', 'Male Elbow', base * 1.0, 'turn_right');
          addThreaded('F_EL90', 'Female Elbow', base * 1.1, 'turn_right');
          addThreaded('M_RUN_TEE', 'Male Run Tee', base * 1.0, 'call_split');
          addThreaded('F_RUN_TEE', 'Female Run Tee', base * 1.1, 'call_split');
          addThreaded('M_BRN_TEE', 'Male Branch Tee', base * 1.0, 'call_split');
          addThreaded(
            'F_BRN_TEE',
            'Female Branch Tee',
            base * 1.1,
            'call_split',
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

        // 🚀 [피팅 고도화] 리듀서는 규격 하나가 아니라 "큰 규격 → 작은
        // 규격" 조합이라, 위 per-size 루프가 끝난 뒤 그 단위(inch/metric)
        // 안의 모든 규격 쌍에 대해 따로 만든다.
        _addReducingUnions(result, maker, sizes, unit);
      }
    }

    processSizes(inchSizes, 'inch');
    processSizes(metricSizes, 'metric');

    return result;
  }

  // 🚀 [피팅 고도화] "1/2 x 3/8 Reducing Union"처럼 서로 다른 두 규격을
  // 잇는 리듀서를 같은 단위계 안의 모든 규격 조합으로 생성한다. 큰
  // 규격 쪽을 tubeOD로 둬서, "1/2 규격" 목록을 볼 때 이 리듀서가 같이
  // 뜨게 한다(현장에서 "1/2 라인에서 뭘로 줄일까" 찾는 방식과 일치).
  static void _addReducingUnions(
    List<Map<String, dynamic>> list,
    String maker,
    Map<String, double> sizes,
    String unit,
  ) {
    final entries = sizes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (int i = 0; i < entries.length; i++) {
      for (int j = i + 1; j < entries.length; j++) {
        final String bigSize = entries[i].key;
        final String smallSize = entries[j].key;
        final double base = (entries[i].value + entries[j].value) / 2;
        final String safeBig = bigSize.replaceAll('/', '_');
        final String safeSmall = smallSize.replaceAll('/', '_');

        double finalDeduction = base * 0.85;
        if (maker == 'Parker') finalDeduction *= 1.02;
        if (maker == 'Hy-Lok') finalDeduction *= 0.98;
        if (maker == 'DK-Lok') finalDeduction *= 0.99;

        list.add({
          'id': '${maker.toLowerCase()}_fitting_${safeBig}_x_${safeSmall}_red',
          'maker': maker,
          'group': 'FITTING',
          'tubeOD': bigSize,
          'tubeOD2': smallSize,
          'category': 'RED',
          'name': '$maker $bigSize x $smallSize Reducing Union',
          'displayName': '$bigSize x $smallSize Reducing Union',
          'deduction': double.parse(finalDeduction.toStringAsFixed(1)),
          'iconString': 'trending_down',
          'unit': unit,
        });
      }
    }
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
    String unit, {
    String threadType = '',
    String threadSize = '',
  }) {
    double finalDeduction = ded;
    if (maker == 'Parker') finalDeduction *= 1.02;
    if (maker == 'Hy-Lok') finalDeduction *= 0.98;
    if (maker == 'DK-Lok') finalDeduction *= 0.99;

    final String threadIdSuffix = threadType.isEmpty
        ? ''
        : '_${threadType.toLowerCase()}';
    final String threadNameSuffix = threadType.isEmpty
        ? ''
        : ' ($threadType $threadSize)';

    list.add({
      'id':
          '${maker.toLowerCase()}_${group.toLowerCase()}_${safeId}_${cat.toLowerCase()}$threadIdSuffix',
      'maker': maker,
      'group': group,
      'tubeOD': size,
      'category': cat,
      'name': '$maker $size $name$threadNameSuffix',
      'displayName': '$name$threadNameSuffix',
      'deduction': double.parse(finalDeduction.toStringAsFixed(1)),
      'iconString': icon,
      'unit': unit,
      if (threadType.isNotEmpty) 'threadType': threadType,
      if (threadType.isNotEmpty) 'threadSize': threadSize,
    });
  }
}
