// 현장 자료·장비 사용법. 탭: 튜브 · 전선관 · 형강 · 장비 사용법 · 앱 사용법 · 단위 환산 ·
// 발전 설비 · 전기 기준(KEC).
// 숫자는 계산기가 쓰는 자료(FittingData·benderSpecData·SteelShapeDB 등)에서 바로 읽어
// 설정 기본값과 늘 같다. 예전 화면(벤딩 실무 가이드)은 손으로 적은 표라 설정과 달랐다.
//
// 현장자료_보충제안_2026-09-25.md: 이 화면도 벤더 옆·야외에서 펴 보는 화면이라 현장 보기
// (보통/햇빛/야간) 테마를 걸었고(1번), 카드가 40장 넘어 찾기 힘들어 통합 검색을 붙였고(2번),
// 표에 병기만 있던 단위 환산을 계산기로 만들었다(3번).
import 'package:flutter/material.dart';

import '../../../core/theme/app_icon_set.dart';
import '../../../core/theme/field_view.dart';
import 'ref_app_tab.dart';
import 'ref_conduit_tab.dart';
import 'ref_kec_tab.dart';
import 'ref_machine_tab.dart';
import 'ref_plant_tab.dart';
import 'ref_steel_tab.dart';
import 'ref_tube_tab.dart';
import 'ref_unit_tab.dart';
import 'reference_search_index.dart';
import 'reference_widgets.dart';

/// 전기 기준(KEC) 탭 번호(알림에서 바로 연다).
const int kRefKecTabIndex = 7;

class TubeReferencePage extends StatefulWidget {
  /// 처음 열 탭(0=튜브 … 7=전기 기준).
  final int initialTab;
  const TubeReferencePage({super.key, this.initialTab = 0});

  @override
  State<TubeReferencePage> createState() => _TubeReferencePageState();
}

class _TubeReferencePageState extends State<TubeReferencePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 8,
    vsync: this,
    initialIndex: widget.initialTab.clamp(0, 7),
  );
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _jumpTo(int tab) {
    // 자판을 닫는다 — 그대로 두면 넘어간 탭의 아래 절반을 가린다.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _searchCtrl.clear();
      _query = '';
    });
    _tabController.animateTo(tab);
  }

  // 현장 보기(보통·햇빛·야간) 테마로 감싼다: 기본 위젯(입력칸·글씨)도 같은 색(D-D).
  @override
  Widget build(BuildContext context) =>
      FieldViewTheme(child: Builder(builder: _buildPage));

  Widget _buildPage(BuildContext context) {
    return Scaffold(
      backgroundColor: refBg,
      appBar: AppBar(
        title: Text(
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
        iconTheme: IconThemeData(color: refTextMain),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: refTextMain,
          indicatorWeight: 3.0,
          labelColor: refTextMain,
          unselectedLabelColor: refTextSub,
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: "튜브"),
            Tab(text: "전선관"),
            Tab(text: "형강"),
            Tab(text: "장비 사용법"),
            Tab(text: "앱 사용법"),
            Tab(text: "단위 환산"),
            Tab(text: "발전 설비"),
            Tab(text: "전기 기준(KEC)"),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim()),
              style: TextStyle(color: refTextMain),
              decoration: InputDecoration(
                hintText: "규격·부품 이름으로 찾기(예: NPT, 곤질레다, H형강)",
                hintStyle: TextStyle(color: refTextSub, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: refTextSub),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close_rounded, color: refTextSub),
                        onPressed: () => setState(() {
                          _searchCtrl.clear();
                          _query = '';
                        }),
                      ),
                filled: true,
                fillColor: refWhite,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _query.isEmpty
                ? TabBarView(
                    controller: _tabController,
                    children: const [
                      RefTubeTab(),
                      RefConduitTab(),
                      RefSteelTab(),
                      RefMachineTab(),
                      RefAppTab(),
                      RefUnitTab(),
                      RefPlantTab(),
                      RefKecTab(),
                    ],
                  )
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final matches = refSearchIndex.where((e) => e.matches(_query)).toList();
    if (matches.isEmpty) {
      return Center(
        child: Text(
          '"$_query"에 맞는 자료가 없습니다',
          style: TextStyle(color: refTextSub, fontSize: 14),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: matches.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final e = matches[i];
        return InkWell(
          onTap: () => _jumpTo(e.tab),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: refWhite,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        style: TextStyle(
                          color: refTextMain,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${refTabNames[e.tab]} 탭",
                        style: TextStyle(color: refTextSub, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(AppIcons.forward, size: 18, color: refTextSub),
              ],
            ),
          ),
        );
      },
    );
  }
}
