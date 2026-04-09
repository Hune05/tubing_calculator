import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);
const Color purpleBadge = Color(0xFF8A2BE2);

class MobileSchedulePage extends StatefulWidget {
  final bool isAdmin;
  final String currentUser;

  const MobileSchedulePage({
    super.key,
    required this.isAdmin,
    required this.currentUser,
  });

  @override
  State<MobileSchedulePage> createState() => _MobileSchedulePageState();
}

class _MobileSchedulePageState extends State<MobileSchedulePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  // 시간(시, 분, 초)을 절사하여 날짜 단위로만 비교하기 위한 함수
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[_normalizeDate(day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tossGrey,
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slate900),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "회사 행사 및 일정",
          style: TextStyle(
            color: slate900,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('company_events')
            .orderBy('date', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _events.clear();
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id; // 삭제 기능을 위한 ID 저장

              if (data['date'] != null) {
                DateTime date = (data['date'] as Timestamp).toDate();
                DateTime normalizedDate = _normalizeDate(date);

                if (_events[normalizedDate] == null) {
                  _events[normalizedDate] = [];
                }
                _events[normalizedDate]!.add(data);
              }
            }
          }

          return Column(
            children: [
              Container(
                color: pureWhite,
                padding: const EdgeInsets.only(bottom: 16),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: _getEventsForDay,
                  startingDayOfWeek: StartingDayOfWeek.sunday,
                  headerStyle: HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                    titleTextStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: slate900,
                    ),
                    leftChevronIcon: const Icon(
                      Icons.chevron_left,
                      color: slate900,
                    ),
                    rightChevronIcon: const Icon(
                      Icons.chevron_right,
                      color: slate900,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: tossBlue.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: const TextStyle(
                      color: tossBlue,
                      fontWeight: FontWeight.bold,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: tossBlue,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: warningRed,
                      shape: BoxShape.circle,
                    ),
                    weekendTextStyle: const TextStyle(color: warningRed),
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    if (!isSameDay(_selectedDay, selectedDay)) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      HapticFeedback.lightImpact();
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildEventList()),
            ],
          );
        },
      ),
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _showAddEventBottomSheet(context);
              },
              backgroundColor: tossBlue,
              icon: const Icon(Icons.add, color: pureWhite),
              label: const Text(
                "일정 추가",
                style: TextStyle(fontWeight: FontWeight.bold, color: pureWhite),
              ),
            )
          : null,
    );
  }

  Widget _buildEventList() {
    final events = _getEventsForDay(_selectedDay!);

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.calendarX,
              size: 48,
              color: slate600.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              "이 날은 등록된 일정이 없습니다.",
              style: TextStyle(color: slate600, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        bool isUrgent = event['isUrgent'] ?? false; // 긴급(대시보드 표시) 여부

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isUrgent
                  ? warningRed.withValues(alpha: 0.3)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isUrgent
                      ? warningRed.withValues(alpha: 0.1)
                      : tossBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isUrgent ? LucideIcons.bellRing : LucideIcons.calendarCheck,
                  color: isUrgent ? warningRed : tossBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isUrgent)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: warningRed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "메인 공지",
                              style: TextStyle(
                                color: pureWhite,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            event['title'] ?? "제목 없음",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: slate900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.clock,
                          size: 14,
                          color: slate600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          event['time'] ?? "시간 미정",
                          style: const TextStyle(fontSize: 13, color: slate600),
                        ),
                      ],
                    ),
                    // 🚀 추가된 일정 내용 표시 UI
                    if (event['description'] != null &&
                        event['description'].toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tossGrey,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          event['description'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: slate900,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.isAdmin)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
                  onPressed: () => _deleteEvent(event['id']),
                ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // 🛠️ 관리자용: 일정 추가 및 대시보드 연동
  // ==========================================
  void _showAddEventBottomSheet(BuildContext context) {
    final titleCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final descCtrl = TextEditingController(); // 🚀 추가: 일정 내용 컨트롤러
    bool isUrgent = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85, // 높이를 살짝 늘림
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "새 일정 등록",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: slate900,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: slate600),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 🚀 스크롤 가능한 영역 (키보드가 올라와도 가려지지 않음)
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: slate100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.calendarDays,
                                color: tossBlue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "선택된 날짜: ${DateFormat('yyyy년 MM월 dd일').format(_selectedDay ?? DateTime.now())}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: slate900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "일정 제목",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: slate600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: titleCtrl,
                          decoration: InputDecoration(
                            hintText: "예: 전 직원 회식, A동 검사일",
                            filled: true,
                            fillColor: tossGrey,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "시간",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: slate600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: timeCtrl,
                          decoration: InputDecoration(
                            hintText: "예: 18:00 (오후 6시)",
                            filled: true,
                            fillColor: tossGrey,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 🚀 새로 추가된 일정 내용 (메모) 입력 필드
                        const Text(
                          "일정 내용 (선택)",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: slate600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: descCtrl,
                          maxLines: 3, // 여러 줄 입력 가능
                          decoration: InputDecoration(
                            hintText: "참석자, 장소, 준비물 등 상세 내용을 적어주세요.",
                            filled: true,
                            fillColor: tossGrey,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isUrgent
                                ? warningRed.withValues(alpha: 0.05)
                                : pureWhite,
                            border: Border.all(
                              color: isUrgent ? warningRed : slate100,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SwitchListTile(
                            title: const Text(
                              "앱 메인 화면에 알림 띄우기",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: const Text(
                              "체크 시 모든 사용자의 첫 화면에 이 일정이 강조되어 표시됩니다.",
                              style: TextStyle(fontSize: 12),
                            ),
                            value: isUrgent,
                            activeColor: warningRed,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) {
                              setModalState(() => isUrgent = val);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tossBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      if (titleCtrl.text.isEmpty) return;

                      HapticFeedback.heavyImpact();

                      // 1. 캘린더 DB에 저장 (내용 포함)
                      await FirebaseFirestore.instance
                          .collection('company_events')
                          .add({
                            'title': titleCtrl.text.trim(),
                            'time': timeCtrl.text.trim().isEmpty
                                ? "종일"
                                : timeCtrl.text.trim(),
                            'description': descCtrl.text.trim(), // 🚀 내용 저장
                            'date': Timestamp.fromDate(
                              _selectedDay ?? DateTime.now(),
                            ),
                            'isUrgent': isUrgent,
                            'author': widget.currentUser,
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                      // 2. 대시보드 알림 연동
                      if (isUrgent) {
                        var oldNotices = await FirebaseFirestore.instance
                            .collection('announcements')
                            .where('isActive', isEqualTo: true)
                            .get();
                        for (var doc in oldNotices.docs) {
                          doc.reference.update({'isActive': false});
                        }

                        await FirebaseFirestore.instance
                            .collection('announcements')
                            .add({
                              'title': titleCtrl.text.trim(),
                              'badge': "오늘의 중요 일정",
                              'isActive': true,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: const Text(
                      "일정 저장하기",
                      style: TextStyle(
                        color: pureWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _deleteEvent(String docId) async {
    await FirebaseFirestore.instance
        .collection('company_events')
        .doc(docId)
        .delete();
  }
}
