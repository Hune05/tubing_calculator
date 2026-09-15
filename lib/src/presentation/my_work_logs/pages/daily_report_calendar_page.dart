import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'daily_report_page.dart';

const Color tossBlue = Color(0xFF007580); // 🚀 마키타 틸로 통일
const Color tossText = Color(0xFF191F28);
const Color tossSubText = Color(0xFF8B95A1);
const Color tossBg = Color(0xFFF2F4F6);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);

// 🚀 [신규] 작업 일지를 날짜별로 한눈에 보고("이번 달에 며칠 빠졌나"),
// 기간 통계(총 포인트/결선/초과근무)를 확인하고, 카카오톡 등에 붙여넣을
// 수 있게 텍스트로 내보내는 화면. 목록/수정 자체는 기존
// DailyReportPage를 그대로 재사용한다(지난 날짜 수정 사유 팝업 포함).
//
// 🚀 [한계] 일지의 date 필드가 "MM/DD" 문자열이라 연도가 없다 - 프로젝트가
// 해를 넘겨 1년 이상 진행되면 같은 달(예: 다른 해의 9월)이 섞여 보일 수
// 있다. 기존 알림 로직(checkDailyReportReminder)도 같은 가정을 쓰고
// 있어서 여기서도 그대로 따른다.
class DailyReportCalendarPage extends StatefulWidget {
  final String projectName;
  final List<Map<String, dynamic>> initialReports;

  const DailyReportCalendarPage({
    super.key,
    required this.projectName,
    required this.initialReports,
  });

  @override
  State<DailyReportCalendarPage> createState() =>
      _DailyReportCalendarPageState();
}

class _DailyReportCalendarPageState extends State<DailyReportCalendarPage> {
  late List<Map<String, dynamic>> _reports;
  bool _changed = false;
  late DateTime _viewedMonth;

  @override
  void initState() {
    super.initState();
    _reports = widget.initialReports
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final now = DateTime.now();
    _viewedMonth = DateTime(now.year, now.month);
  }

  String _mmdd(int month, int day) =>
      "${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')}";

  // 이 달(월 숫자 기준, 연도 정보 없음)에 해당하는 일지만 추린다.
  List<Map<String, dynamic>> get _reportsInViewedMonth {
    final String monthPrefix = _viewedMonth.month.toString().padLeft(2, '0');
    return _reports
        .where((r) => (r['date']?.toString() ?? '').startsWith("$monthPrefix/"))
        .toList();
  }

  Map<String, Map<String, dynamic>> get _byDateInViewedMonth {
    final map = <String, Map<String, dynamic>>{};
    for (final r in _reportsInViewedMonth) {
      final key = r['date'].toString();
      map.putIfAbsent(key, () => r); // 최신 순 리스트라 첫 항목이 최신
    }
    return map;
  }

  // 🚀 [신규] 최근 6개월(실제 현재 달 기준, 달력에서 이동 중인 달과는
  // 무관) 벤딩 포인트 합계를 월별로 모아 추이를 보여준다. 연도 정보가
  // 없는 한계는 달력 뷰와 동일 - 월 숫자만으로 묶는다.
  List<MapEntry<int, int>> get _monthlyPointsTrend {
    final now = DateTime.now();
    final List<MapEntry<int, int>> result = [];
    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i);
      final String prefix = monthDate.month.toString().padLeft(2, '0');
      int total = 0;
      for (final r in _reports) {
        final String date = r['date']?.toString() ?? '';
        if (date.startsWith('$prefix/')) {
          total += (r['points'] as num?)?.toInt() ?? 0;
        }
      }
      result.add(MapEntry(monthDate.month, total));
    }
    return result;
  }

  Widget _buildTrendChart() {
    final trend = _monthlyPointsTrend;
    final int maxVal = trend
        .map((e) => e.value)
        .fold(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.show_chart_rounded, color: tossBlue, size: 18),
              SizedBox(width: 6),
              Text(
                "최근 6개월 벤딩 포인트 추이",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: tossText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: trend.map((e) {
                final double heightFrac = maxVal == 0
                    ? 0.0
                    : (e.value / maxVal).clamp(0.03, 1.0);
                final bool isCurrentMonth = e.key == DateTime.now().month;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          "${e.value}",
                          style: const TextStyle(
                            fontSize: 10,
                            color: tossSubText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 80 * heightFrac,
                          decoration: BoxDecoration(
                            color: isCurrentMonth
                                ? tossBlue
                                : tossBlue.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "${e.key}월",
                          style: TextStyle(
                            fontSize: 11,
                            color: isCurrentMonth ? tossBlue : tossText,
                            fontWeight: isCurrentMonth
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _viewedMonth = DateTime(_viewedMonth.year, _viewedMonth.month + delta);
    });
  }

  Future<void> _openReport(Map<String, dynamic> report) async {
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => DailyReportPage(existingData: report),
      ),
    );
    if (updated == null) return;
    setState(() {
      final idx = _reports.indexOf(report);
      if (idx != -1) _reports[idx] = updated;
      _changed = true;
    });
  }

  void _exportMonth() {
    final byDate = _byDateInViewedMonth;
    final daysInMonth = DateTime(
      _viewedMonth.year,
      _viewedMonth.month + 1,
      0,
    ).day;

    int totalPoints = 0;
    int totalWiring = 0;
    int overtimeDays = 0;
    final buffer = StringBuffer();
    buffer.writeln(
      "📋 [${widget.projectName}] ${_viewedMonth.month}월 작업 일지 요약",
    );
    buffer.writeln("기록일: ${byDate.length}일 / $daysInMonth일");
    buffer.writeln();

    for (int day = 1; day <= daysInMonth; day++) {
      final key = _mmdd(_viewedMonth.month, day);
      final r = byDate[key];
      if (r == null) continue;
      final int pts = (r['points'] as num?)?.toInt() ?? 0;
      final int wiring = (r['wiring_points'] as num?)?.toInt() ?? 0;
      final bool overtime = r['is_overtime'] == true;
      totalPoints += pts;
      totalWiring += wiring;
      if (overtime) overtimeDays++;

      // 🚀 work_type이 복수 선택(List)으로 바뀌어서, 예전 단일 문자열
      // 데이터와 둘 다 안전하게 처리한다.
      final dynamic wt = r['work_type'];
      final String workTypeStr = wt is List ? wt.join('/') : (wt ?? '');

      buffer.writeln(
        "$key ($workTypeStr, ${r['worker_count'] ?? 1}명${overtime ? ', 야간' : ''}) "
        "- 벤딩 ${pts}pt / 결선 $wiring개소",
      );
      final note = r['note']?.toString() ?? '';
      if (note.isNotEmpty && note != '특이사항 없음') {
        buffer.writeln("   ↳ $note");
      }
    }

    buffer.writeln();
    buffer.writeln("총 벤딩 포인트: ${totalPoints}pt");
    buffer.writeln("총 결선: $totalWiring개소");
    buffer.writeln("초과/야간 근무: $overtimeDays일");

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("이번 달 작업 일지 요약이 클립보드에 복사되었습니다."),
        backgroundColor: tossBlue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final byDate = _byDateInViewedMonth;
    final daysInMonth = DateTime(
      _viewedMonth.year,
      _viewedMonth.month + 1,
      0,
    ).day;
    // 1(월)~7(일) 기준으로 1일이 무슨 요일인지 구해, 그 앞을 빈 칸으로 채운다.
    final int leadingBlanks =
        DateTime(_viewedMonth.year, _viewedMonth.month, 1).weekday - 1;

    int totalPoints = 0;
    int totalWiring = 0;
    int overtimeDays = 0;
    for (final r in byDate.values) {
      totalPoints += (r['points'] as num?)?.toInt() ?? 0;
      totalWiring += (r['wiring_points'] as num?)?.toInt() ?? 0;
      if (r['is_overtime'] == true) overtimeDays++;
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: tossBg,
        appBar: AppBar(
          backgroundColor: pureWhite,
          foregroundColor: tossText,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "작업 일지 달력",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              Text(
                widget.projectName,
                style: const TextStyle(
                  fontSize: 12,
                  color: tossSubText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _exportMonth,
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: "이번 달 요약 내보내기",
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 월 이동 + 통계 카드
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: pureWhite,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Text(
                        "${_viewedMonth.year}년 ${_viewedMonth.month}월",
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: tossText,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _changeMonth(1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      _statTile("기록일", "${byDate.length}/$daysInMonth일"),
                      _statTile("벤딩", "${totalPoints}pt"),
                      _statTile("결선", "$totalWiring개소"),
                      _statTile("초과근무", "$overtimeDays일"),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 요일 헤더
            Row(
              children: ["월", "화", "수", "목", "금", "토", "일"]
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            color: tossSubText,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: leadingBlanks + daysInMonth,
              itemBuilder: (context, index) {
                if (index < leadingBlanks) return const SizedBox.shrink();
                final int day = index - leadingBlanks + 1;
                final String key = _mmdd(_viewedMonth.month, day);
                final report = byDate[key];
                final bool hasReport = report != null;
                final bool isAsBuilt = report?['is_as_built'] == true;

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: hasReport
                      ? () => _openReport(report)
                      : () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("이 날짜의 작업 일지가 없습니다.")),
                        ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: hasReport
                          ? tossBlue.withValues(alpha: 0.1)
                          : pureWhite,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "$day",
                          style: TextStyle(
                            fontWeight: hasReport
                                ? FontWeight.w800
                                : FontWeight.normal,
                            color: hasReport ? tossBlue : tossSubText,
                            fontSize: 13,
                          ),
                        ),
                        if (hasReport)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isAsBuilt ? warningRed : tossBlue,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildTrendChart(),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.pop(context, _changed ? _reports : null),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tossText,
                  side: const BorderSide(color: Colors.black12),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "완료",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: tossSubText, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: tossText,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
