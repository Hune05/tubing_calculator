// 현장 자료·장비 사용법. 탭: 튜브 · 전선관 · 형강 · 장비 사용법 · 앱 사용법.
// 숫자는 계산기가 쓰는 자료(FittingData·benderSpecData·SteelShapeDB 등)에서 바로 읽어
// 설정 기본값과 늘 같다. 예전 화면(벤딩 실무 가이드)은 손으로 적은 표라 설정과 달랐다.
import 'package:flutter/material.dart';

import 'ref_app_tab.dart';
import 'ref_conduit_tab.dart';
import 'ref_machine_tab.dart';
import 'ref_steel_tab.dart';
import 'ref_tube_tab.dart';
import 'reference_widgets.dart';

class TubeReferencePage extends StatelessWidget {
  const TubeReferencePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: refBg,
        appBar: AppBar(
          title: const Text(
            "현장 자료·장비 사용법",
            style: TextStyle(
              color: refTextMain,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          backgroundColor: refWhite,
          elevation: 0,
          centerTitle: false,
          iconTheme: const IconThemeData(color: refTextMain),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: refTextMain,
            indicatorWeight: 3.0,
            labelColor: refTextMain,
            unselectedLabelColor: refTextSub,
            labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: "튜브"),
              Tab(text: "전선관"),
              Tab(text: "형강"),
              Tab(text: "장비 사용법"),
              Tab(text: "앱 사용법"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            RefTubeTab(),
            RefConduitTab(),
            RefSteelTab(),
            RefMachineTab(),
            RefAppTab(),
          ],
        ),
      ),
    );
  }
}
