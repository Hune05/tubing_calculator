// 연간 근태: 한 해를 달마다 근로·연장·야간·휴일·연차 사용으로 한 표에 보여 준다.
library;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';

import '../../my_work_logs/models/attendance.dart';
import '../attendance_calc.dart';
import '../attendance_pay.dart';
import '../attendance_year.dart';

const Color _text = AppColors.text;
const Color _sub = AppColors.textSub;
const Color _brand = AppColors.brand;

typedef YearRangeLoader =
    Future<Map<String, AttendanceRecord>?> Function(DateTime from, DateTime to);

class AttendanceYearPage extends StatefulWidget {
  final int year;
  final AttendanceCalcOptions options;
  final int? hourlyWage;
  final YearRangeLoader loader;
  const AttendanceYearPage({
    super.key,
    required this.year,
    required this.options,
    required this.loader,
    this.hourlyWage,
  });

  @override
  State<AttendanceYearPage> createState() => _AttendanceYearPageState();
}

class _AttendanceYearPageState extends State<AttendanceYearPage> {
  late int _year = widget.year;
  YearSummary? _sum;
  bool _loading = true;
  bool _failed = false;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final r = yearRange(_year);
    Map<String, AttendanceRecord>? m;
    try {
      m = await widget.loader(r.from, r.to);
    } catch (_) {
      m = null;
    }
    if (!mounted || seq != _seq) return;
    setState(() {
      _loading = false;
      _failed = m == null;
      _sum = m == null ? null : summarizeYear(m, _year, widget.options);
    });
  }

  void _move(int delta) {
    setState(() => _year += delta);
    _load();
  }

  Widget _cell(
    String t, {
    bool head = false,
    bool bold = false,
    Color? color,
  }) => Expanded(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        t,
        style: TextStyle(
          color: color ?? (head ? _sub : _text),
          fontSize: head ? 11 : 13,
          fontWeight: bold || head ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    ),
  );

  Widget _row(
    List<String> cells, {
    Key? key,
    bool head = false,
    bool bold = false,
    Color? bg,
  }) => Container(
    key: key,
    color: bg,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    child: Row(
      children: [
        for (var i = 0; i < cells.length; i++)
          _cell(cells[i], head: head, bold: bold || i == 0),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = _sum;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: _text,
        elevation: 0,
        title: const Text(
          "연간 근태",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  key: const Key('att_year_prev'),
                  tooltip: "이전 해",
                  onPressed: () => _move(-1),
                  icon: const Icon(AppIcons.back),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      "$_year년",
                      key: const Key('att_year_title'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _text,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('att_year_next'),
                  tooltip: "다음 해",
                  onPressed: () => _move(1),
                  icon: const Icon(AppIcons.forward),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _failed || s == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "기록을 읽지 못했습니다.",
                          key: Key('att_year_failed'),
                          style: TextStyle(color: AppColors.danger),
                        ),
                        TextButton(
                          onPressed: _load,
                          child: const Text("다시 읽기"),
                        ),
                      ],
                    ),
                  )
                : _table(s),
          ),
        ],
      ),
    );
  }

  Widget _table(YearSummary s) {
    final wage = widget.hourlyWage;
    var payTotal = 0;
    final rows = <Widget>[
      _row(
        const ["월", "근로", "연장", "야간", "휴일", "연차"],
        head: true,
        bg: AppColors.fill,
      ),
    ];
    for (var i = 0; i < 12; i++) {
      final m = s.months[i];
      final empty = m.timedDays == 0 && m.leaveUsed == 0;
      final p = estimateExtraPay(m, wage);
      if (p != null) payTotal += p.total;
      rows.add(
        _row([
          "${i + 1}월",
          empty ? "-" : shortHours(m.work),
          shortHours(m.overtime),
          shortHours(m.night),
          shortHours(m.holiday),
          m.leaveUsed == 0 ? "-" : formatLeaveDays(m.leaveUsed),
        ], key: Key('att_year_row_${i + 1}')),
      );
      rows.add(const Divider(height: 1, color: AppColors.fill));
    }
    rows.add(
      _row(
        [
          "합계",
          shortHours(s.work),
          shortHours(s.overtime),
          shortHours(s.night),
          shortHours(s.holiday),
          s.leaveUsed == 0 ? "-" : formatLeaveDays(s.leaveUsed),
        ],
        key: const Key('att_year_total'),
        bold: true,
        bg: AppColors.brandSoft,
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            color: AppColors.surface,
            child: Column(children: rows),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "시간은 휴게를 뺀 근로 기준이고, 연차는 일수입니다. 연장은 하루 8시간·주 40시간 초과입니다.",
          style: TextStyle(color: _sub, fontSize: 11, height: 1.4),
        ),
        if (s.weeksOver52 > 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              "1주 연장 12시간(주 52시간)을 넘은 주가 ${s.weeksOver52}주 있습니다.",
              key: const Key('att_year_over52'),
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (wage != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              "예상 수당 합계(참고용) 약 ${formatWon(payTotal)}",
              key: const Key('att_year_pay'),
              style: const TextStyle(
                color: _brand,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}
