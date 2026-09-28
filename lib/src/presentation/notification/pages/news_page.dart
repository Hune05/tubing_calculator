import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'mobile_notification_page.dart';
import 'my_notifications_tab.dart';

// 색의 뜻(D-B): 앱의 주 색 하나(청록).
const Color _tossBlue = AppColors.brand;
const Color _slate900 = AppColors.text;
const Color _slate600 = AppColors.textSub;
const Color _pureWhite = Color(0xFFFFFFFF);

/// 홈 머리의 스피커 아이콘을 누르면 오는 "새소식" 화면 — 탭 3개.
/// "공지"는 관리자가 올리는 기존 [MobileNotificationPage](embedded: true),
/// "내 알림"은 앱이 스스로 아는 사실(오늘 일정·작업 일지 미작성·오프라인
/// 저장 대기)을 알림처럼 보여주고, "지난 알림"은 지운 것들을 다시 본다
/// (2026-09-28 — 확성기가 실제 역할이 없다는 지적을 받아 채워 넣었다).
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
              Tab(text: "공지"),
              Tab(text: "내 알림"),
              Tab(text: "지난 알림"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            MobileNotificationPage(
              currentWorker: currentWorker,
              embedded: true,
            ),
            MyNotificationsTab(currentWorker: currentWorker),
            const PastNotificationsTab(),
          ],
        ),
      ),
    );
  }
}
