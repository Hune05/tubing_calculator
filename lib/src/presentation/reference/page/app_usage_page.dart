// 앱 사용법: 이 앱 화면들(계산기·배치도·일지·일정·자재) 쓰는 순서.
//
// 예전엔 "현장 자료·장비 사용법" 화면의 탭 하나였다. 자재 규격표·물리 장비 조작과는
// 성격이 다른(이 앱 자체 사용설명서) 셋째 부류라 2026-09-28에 따로 뺐다.
import 'package:flutter/material.dart';

import '../../../core/theme/field_view.dart';
import 'ref_app_tab.dart';
import 'reference_widgets.dart';

class AppUsagePage extends StatelessWidget {
  const AppUsagePage({super.key});

  @override
  Widget build(BuildContext context) =>
      FieldViewTheme(child: Builder(builder: _buildPage));

  Widget _buildPage(BuildContext context) {
    return Scaffold(
      backgroundColor: refBg,
      appBar: AppBar(
        title: Text(
          "앱 사용법",
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
      body: const RefAppTab(),
    );
  }
}
