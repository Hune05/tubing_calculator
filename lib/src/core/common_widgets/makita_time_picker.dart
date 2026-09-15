import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const Color _makitaTeal = Color(0xFF007580);
const Color _slate900 = Color(0xFF191F28);
const Color _slate500 = Color(0xFF8B95A1);
const Color _pureWhite = Color(0xFFFFFFFF);

// 🚀 [신규] 기본 Material 시계판(다이얼) 대신, 갤럭시 캘린더처럼 시/분/
// 오전·오후를 휠(스피너)로 돌려서 고르는 바텀시트형 시간 선택기.
// 앱 전체(작업 일지 연장근무, 일정 관리, 자재 발주, 차량 이용) 시간
// 입력을 전부 이걸로 통일한다.
Future<TimeOfDay?> showMakitaTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String title = "시간 설정",
}) async {
  // CupertinoDatePicker는 DateTime을 다루므로, 임의의 날짜(오늘)에
  // 시/분만 얹어서 사용한다 - 날짜 부분은 버려지고 시간만 쓰인다.
  final DateTime today = DateTime.now();
  DateTime tempPicked = DateTime(
    today.year,
    today.month,
    today.day,
    initialTime.hour,
    initialTime.minute,
  );

  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
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
                      onPressed: () => Navigator.pop(
                        context,
                        TimeOfDay(
                          hour: tempPicked.hour,
                          minute: tempPicked.minute,
                        ),
                      ),
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
                height: 216,
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        fontSize: 20,
                        color: _slate900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: tempPicked,
                    use24hFormat: false,
                    onDateTimeChanged: (dt) => tempPicked = dt,
                  ),
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
