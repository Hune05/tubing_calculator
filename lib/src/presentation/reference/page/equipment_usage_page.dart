// 장비 사용법: 튜브 벤더(수동·전동·NC), 전선관 벤더(수동·유압·시카고),
// 실측 캘리브레이션, 톱·절단기, 계기 확인, 안전.
//
// 예전엔 "현장 자료·장비 사용법" 화면의 탭 하나였다. 규격 자료(치수·중량표)와는
// 성격이 다른(손으로 만지는 물리 장비 조작) 둘째 부류라 2026-09-28에 따로 뺐다.
import 'package:flutter/material.dart';

import '../../../core/theme/field_view.dart';
import 'ref_machine_tab.dart';
import 'reference_widgets.dart';

class EquipmentUsagePage extends StatelessWidget {
  const EquipmentUsagePage({super.key});

  @override
  Widget build(BuildContext context) =>
      FieldViewTheme(child: Builder(builder: _buildPage));

  Widget _buildPage(BuildContext context) {
    return Scaffold(
      backgroundColor: refBg,
      appBar: AppBar(
        title: Text(
          "장비 사용법",
          style: TextStyle(
            color: refTextMain,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: refWhite,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: refTextMain),
      ),
      body: const RefMachineTab(),
    );
  }
}
