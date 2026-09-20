import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../data/models/steel_cutting_project_model.dart';
import '../../tube_cutting/cutting_theme.dart';

const List<String> _kWeekdaysKo = ['월', '화', '수', '목', '금', '토', '일'];

// 🚀 [형강 컷팅 기록 신규] 튜브 컷팅의 "컷팅 기록" 화면(cutting_history_page.dart)과
// 같은 형식(날짜별로 스와이프해서 넘겨보는 하루 단위 화면)을 그대로
// 따랐다. 다만 형강은 "완료" 시점의 절단 세션이 아니라, 항목을
// 추가/수정/삭제/복제할 때마다 자동으로 쌓이는 변경 기록이라 - 개별
// 기록을 지우는 기능은 없다(로그를 사후에 편집하면 이력으로서의
// 의미가 없어지므로).
class SteelCuttingHistoryPage extends StatelessWidget {
  final SteelCuttingProject project;

  const SteelCuttingHistoryPage({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return CuttingTheme(
      child: Scaffold(
        backgroundColor: CuttingColors.surface,
        appBar: AppBar(
          backgroundColor: CuttingColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: const IconThemeData(color: CuttingColors.textPrimary),
          title: Text(
            "변경 기록 · ${project.name}",
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CuttingColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(kSteelCuttingProjectsCollection)
              .doc(project.id)
              .collection(kSteelChangeLogSubcollection)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "기록을 불러오지 못했습니다.\n${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: CuttingColors.textSecondary),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: CuttingColors.primary),
              );
            }
            final entries = (snapshot.data?.docs ?? [])
                .map(
                  (d) => SteelChangeLogEntry.fromMap(
                    d.id,
                    d.data() as Map<String, dynamic>,
                  ),
                )
                .toList();
            return SteelHistoryView(entries: entries);
          },
        ),
      ),
    );
  }
}

// 기록에 나온 규격들(오래된 기록부터 처음 나온 순서). 목록은 최신순으로 들어오므로 거꾸로 훑는다.
List<String> steelHistoryShapes(List<SteelChangeLogEntry> entries) {
  final seen = <String>[];
  for (final e in entries.reversed) {
    if (!seen.contains(e.shapeLabel)) seen.add(e.shapeLabel);
  }
  return seen;
}

// 규격 하나만 남긴다(null이면 전부).
List<SteelChangeLogEntry> filterSteelHistory(
  List<SteelChangeLogEntry> entries,
  String? shape,
) => shape == null
    ? entries
    : [
        for (final e in entries)
          if (e.shapeLabel == shape) e,
      ];

// 기록 화면 본체(규격 칩 + 날짜 넘기기 + 하루 목록). 서버에서 받은 기록을 넘겨 받아 그리기만 한다.
class SteelHistoryView extends StatefulWidget {
  final List<SteelChangeLogEntry> entries;

  const SteelHistoryView({super.key, required this.entries});

  @override
  State<SteelHistoryView> createState() => _SteelHistoryViewState();
}

class _SteelHistoryViewState extends State<SteelHistoryView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  // 규격 하나만 보기(null이면 전부).
  String? _shapeFilter;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatDay(DateTime day) {
    final weekday = _kWeekdaysKo[day.weekday - 1];
    return "${day.month}월 ${day.day}일 ($weekday)";
  }

  ({String label, Color color, IconData icon}) _actionMeta(String action) {
    switch (action) {
      case 'ADD':
        return (
          label: "추가",
          color: CuttingColors.success,
          icon: Icons.add_circle_outline,
        );
      case 'EDIT':
        return (
          label: "수정",
          color: CuttingColors.primary,
          icon: Icons.edit_outlined,
        );
      case 'DUPLICATE':
        return (
          label: "복제",
          color: CuttingColors.primaryDark,
          icon: Icons.copy_outlined,
        );
      case 'DELETE':
        return (
          label: "삭제",
          color: CuttingColors.danger,
          icon: Icons.delete_outline,
        );
      default:
        return (
          label: action,
          color: CuttingColors.textSecondary,
          icon: Icons.circle_outlined,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.entries;
    if (all.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                "아직 변경 기록이 없습니다.",
                style: TextStyle(
                  color: CuttingColors.textSecondary,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "항목을 추가/수정/삭제하면 여기에 자동으로 남습니다.",
                style: TextStyle(
                  color: CuttingColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final shapes = steelHistoryShapes(all);
    // 고른 규격의 기록이 없어졌으면 전체로 돌아간다.
    final String? activeFilter = shapes.contains(_shapeFilter)
        ? _shapeFilter
        : null;
    _shapeFilter = activeFilter;
    final entries = filterSteelHistory(all, activeFilter);

    final Map<DateTime, List<SteelChangeLogEntry>> grouped = {};
    for (final e in entries) {
      final day = DateTime(
        e.timestamp.year,
        e.timestamp.month,
        e.timestamp.day,
      );
      grouped.putIfAbsent(day, () => []).add(e);
    }
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    if (_currentPage >= days.length) {
      _currentPage = 0;
    }

    return Column(
      children: [
        if (shapes.length > 1) _buildShapeFilter(shapes, activeFilter),
        _buildDayNavigator(days),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: days.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, i) {
              final day = days[i];
              final dayEntries = grouped[day]!;
              return _buildDayList(day, dayEntries);
            },
          ),
        ),
      ],
    );
  }

  // 규격이 둘 이상이면 위쪽에 "전체 · 앵글 40x40x3 · 찬넬 …" 칩을 둔다(하나 누르면 그 규격 기록만 보인다).
  Widget _buildShapeFilter(List<String> shapes, String? active) {
    Widget chip(String label, String? value) {
      final selected = active == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: selected ? CuttingColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            key: Key('steel_history_shape_${value ?? 'all'}'),
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                _shapeFilter = value;
                _currentPage = 0;
              });
              if (_pageController.hasClients) _pageController.jumpToPage(0);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: const BoxDecoration(
        color: CuttingColors.surface,
        border: Border(bottom: BorderSide(color: CuttingColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [chip('전체', null), for (final s in shapes) chip(s, s)],
        ),
      ),
    );
  }

  Widget _buildDayNavigator(List<DateTime> days) {
    final day = days[_currentPage];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: CuttingColors.background,
        border: Border(bottom: BorderSide(color: CuttingColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _currentPage < days.length - 1
                ? () => _pageController.nextPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  )
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
            color: _currentPage < days.length - 1
                ? CuttingColors.textPrimary
                : Colors.grey.shade300,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _formatDay(day),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: CuttingColors.textPrimary,
                  ),
                ),
                Text(
                  "${_currentPage + 1} / ${days.length}일 · 좌우로 스와이프",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _currentPage > 0
                ? () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  )
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
            color: _currentPage > 0
                ? CuttingColors.textPrimary
                : Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildDayList(DateTime day, List<SteelChangeLogEntry> dayEntries) {
    final sorted = [...dayEntries]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final Map<String, int> countByAction = {};
    for (final e in sorted) {
      countByAction[e.action] = (countByAction[e.action] ?? 0) + 1;
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CuttingColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            children: countByAction.entries.map((entry) {
              final meta = _actionMeta(entry.key);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(meta.icon, size: 16, color: meta.color),
                  const SizedBox(width: 4),
                  Text(
                    "${meta.label} ${entry.value}건",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: meta.color,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: sorted.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _buildEntryCard(sorted[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildEntryCard(SteelChangeLogEntry e) {
    final meta = _actionMeta(e.action);
    final timeStr = DateFormat('HH:mm').format(e.timestamp);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CuttingColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(meta.icon, size: 13, color: meta.color),
                const SizedBox(width: 4),
                Text(
                  meta.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: meta.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.shapeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: CuttingColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "${e.length.toStringAsFixed(0)}mm × ${e.qty}개"
                  "${e.note.isNotEmpty ? '  ·  ${e.note}' : ''}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            timeStr,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
