import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'mobile_notification_page.dart';

// 색의 뜻(D-B): 앱의 주 색 하나(청록).
const Color _tossBlue = AppColors.brand;
const Color _slate900 = AppColors.text;
const Color _slate600 = AppColors.textSub;
const Color _pureWhite = Color(0xFFFFFFFF);

/// 홈 머리의 스피커(공지) 아이콘을 누르면 오는 "새소식" 화면 — 탭 3개.
/// "알림"은 기존 [MobileNotificationPage]를 그대로 끼워 넣고(embedded: true),
/// 나머지 둘은 아직 정해지지 않아 자리만 남겨 뒀다(2026-09-28, 자리부터
/// 만들고 내용은 나중에 채우기로 함).
class NewsPage extends StatelessWidget {
  final String currentWorker;
  const NewsPage({super.key, required this.currentWorker});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        key: const Key('news_page'),
        backgroundColor: _pureWhite,
        appBar: AppBar(
          backgroundColor: _pureWhite,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(AppIcons.back, color: _slate900),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "새소식",
            style: TextStyle(
              color: _slate900,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          bottom: const TabBar(
            labelColor: _tossBlue,
            unselectedLabelColor: _slate600,
            indicatorColor: _tossBlue,
            tabs: [
              Tab(text: "알림"),
              Tab(text: "준비 중 1"),
              Tab(text: "준비 중 2"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            MobileNotificationPage(
              currentWorker: currentWorker,
              embedded: true,
            ),
            const _SpareTab(),
            const _SpareTab(),
          ],
        ),
      ),
    );
  }
}

/// 아직 내용을 안 정한 탭 — 억지로 아무거나 채우지 않고, 정직하게
/// "준비 중"이라고만 보여준다(2026-09-28 사용자가 자리만 만들어 두자고 함).
class _SpareTab extends StatelessWidget {
  const _SpareTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hourglass_empty_rounded, size: 40, color: _slate600),
          const SizedBox(height: 12),
          const Text(
            "아직 준비 중입니다",
            style: TextStyle(fontWeight: FontWeight.w700, color: _slate900),
          ),
          const SizedBox(height: 6),
          const Text(
            "나중에 채울 자리입니다.",
            style: TextStyle(fontSize: 13, color: _slate600),
          ),
        ],
      ),
    );
  }
}
