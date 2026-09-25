import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const Color _makitaTeal = Color(0xFF007580);
const Color _slate900 = Color(0xFF191F28);
const Color _slate500 = Color(0xFF5F6B78);
const Color _pureWhite = Color(0xFFFFFFFF);

// 🚀 [신규] 기본 Material 시계판(다이얼) 대신, 갤럭시 캘린더처럼 시/분/
// 오전·오후를 휠(스피너)로 돌려서 고르는 바텀시트형 시간 선택기.
// 앱 전체(작업 일지 연장근무, 일정 관리, 자재 발주, 차량 이용) 시간
// 입력을 전부 이걸로 통일한다.
//
// 🚀 [수정] CupertinoDatePicker(.time)는 내부 폭이 고정돼 있어 넓은
// 폰 화면에서 세 칸이 가운데로 몰려 보였다 - 시/분/오전오후를 각각
// CupertinoPicker로 직접 만들어 화면 폭 전체에 고르게 펼치고,
// 숫자도 훨씬 크게 키워서 시원한 느낌으로 바꿨다.
Future<TimeOfDay?> showMakitaTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String title = "시간 설정",
}) async {
  TimeOfDay tempPicked = initialTime;

  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      final double screenWidth = MediaQuery.of(context).size.width;
      return SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: _pureWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D6DB),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "취소",
                        style: TextStyle(
                          color: _slate500,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _slate900,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, tempPicked),
                      child: const Text(
                        "확인",
                        style: TextStyle(
                          color: _makitaTeal,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF2F4F6)),
              SizedBox(
                width: screenWidth,
                height: 280,
                child: _WheelTimePicker(
                  initial: initialTime,
                  onChanged: (t) => tempPicked = t,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    },
  );
}

class _WheelTimePicker extends StatefulWidget {
  final TimeOfDay initial;
  final ValueChanged<TimeOfDay> onChanged;

  const _WheelTimePicker({required this.initial, required this.onChanged});

  @override
  State<_WheelTimePicker> createState() => _WheelTimePickerState();
}

class _WheelTimePickerState extends State<_WheelTimePicker> {
  static const double _itemExtent = 64;
  static const TextStyle _numberStyle = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: _slate900,
  );
  static const TextStyle _dimNumberStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w500,
    color: _slate500,
  );

  late int _hour12; // 1~12
  late int _minute; // 0~59
  late bool _isPM;

  // 🚀 [수정] build()마다 새로 만들면 스크롤 컨트롤러가 매번 재생성돼
  // 낭비였다 - initState에서 한 번만 만들어 재사용한다.
  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minuteCtrl;
  late final FixedExtentScrollController _ampmCtrl;

  @override
  void initState() {
    super.initState();
    final int h24 = widget.initial.hour;
    _isPM = h24 >= 12;
    _hour12 = h24 % 12 == 0 ? 12 : h24 % 12;
    _minute = widget.initial.minute;
    _hourCtrl = FixedExtentScrollController(initialItem: _hour12 - 1);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
    _ampmCtrl = FixedExtentScrollController(initialItem: _isPM ? 1 : 0);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _ampmCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    int h24 = _hour12 % 12;
    if (_isPM) h24 += 12;
    widget.onChanged(TimeOfDay(hour: h24, minute: _minute));
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required int selected,
    required String Function(int index) labelFor,
    required ValueChanged<int> onSelected,
  }) {
    return CupertinoPicker(
      itemExtent: _itemExtent,
      scrollController: controller,
      selectionOverlay: const SizedBox.shrink(),
      onSelectedItemChanged: onSelected,
      children: List.generate(itemCount, (i) {
        final bool isSelected = i == selected;
        return Center(
          child: Text(
            labelFor(i),
            style: isSelected ? _numberStyle : _dimNumberStyle,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 🚀 가운데 선택 줄을 은은하게 표시해서 캘린더 앱들처럼
        // "지금 고른 값"이 시각적으로 딱 보이게 한다.
        Container(
          height: _itemExtent,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: _makitaTeal.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _wheel(
                controller: _hourCtrl,
                itemCount: 12,
                selected: _hour12 - 1,
                labelFor: (i) => "${i + 1}",
                onSelected: (i) => setState(() {
                  _hour12 = i + 1;
                  _notify();
                }),
              ),
            ),
            const Text(
              ":",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: _slate500,
              ),
            ),
            Expanded(
              child: _wheel(
                controller: _minuteCtrl,
                itemCount: 60,
                selected: _minute,
                labelFor: (i) => i.toString().padLeft(2, '0'),
                onSelected: (i) => setState(() {
                  _minute = i;
                  _notify();
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _wheel(
                controller: _ampmCtrl,
                itemCount: 2,
                selected: _isPM ? 1 : 0,
                labelFor: (i) => i == 0 ? "오전" : "오후",
                onSelected: (i) => setState(() {
                  _isPM = i == 1;
                  _notify();
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
