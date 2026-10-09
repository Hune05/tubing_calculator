// 작업 일지 날씨 자동 기록(10-10): 홈 화면이 그날 받은 날씨를 새 일지 날씨 칸에 넣는다.
// 통신이 없어 못 받았거나 다른 날 받은 값이면 비워 두고 손으로 적는다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/weather_note.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_csv.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/daily_report_page.dart';

import 'helpers_text.dart';

String _weatherJson(DateTime at) => jsonEncode(
  WeatherNote(
    desc: '흐림',
    temp: 16.6,
    pm: '나쁨',
    place: '강서구',
    at: at,
  ).toJson(),
);

Future<void> _openAndSave(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 3200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: DailyReportPage()));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('report_points')), '3');
  final save = find.text('작업 일지 저장');
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

void main() {
  test('날씨 줄: 미세먼지를 모르면 뺀다, 그날 받은 값만 쓴다', () {
    final w = WeatherNote(
      desc: '맑음',
      temp: 20,
      pm: '알 수 없음',
      at: DateTime(2026, 10, 10, 7, 30),
    );
    expect(weatherLineOf(w), '맑음 20.0°C');
    expect(weatherLineForDay(w, DateTime(2026, 10, 10)), '맑음 20.0°C');
    expect(weatherLineForDay(w, DateTime(2026, 10, 9)), isNull);
    expect(weatherLineForDay(null, DateTime(2026, 10, 10)), isNull);
  });

  testWidgets('오늘 받은 날씨가 있으면 새 일지 날씨 칸에 들어간다', (tester) async {
    SharedPreferences.setMockInitialValues({
      kLastWeatherKey: _weatherJson(DateTime.now()),
    });
    await _openAndSave(tester);
    expect(findTextContaining('흐림 16.6°C · 미세먼지 나쁨'), findsOneWidget);
  });

  testWidgets('저장한 일지에 날씨 칸이 남고, 고쳐 적을 수 있다', (tester) async {
    SharedPreferences.setMockInitialValues({
      kLastWeatherKey: _weatherJson(DateTime.now()),
    });
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    Map<String, dynamic>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<Map<String, dynamic>>(
                  MaterialPageRoute(builder: (_) => const DailyReportPage()),
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report_weather_line')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('report_weather_field')),
      '비 12°C',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(findTextContaining('비 12°C'), findsOneWidget);
    await _save(tester);
    expect(result?['weather'], '비 12°C');
  });

  testWidgets('어제 받은 날씨뿐이면(통신 없음) 비워 두고 적으라고 알린다', (tester) async {
    SharedPreferences.setMockInitialValues({
      kLastWeatherKey: _weatherJson(
        DateTime.now().subtract(const Duration(days: 1)),
      ),
    });
    await _openAndSave(tester);
    expect(findTextContaining('날씨를 못 받았습니다'), findsOneWidget);
  });

  testWidgets('고치는 일지는 저장된 날씨를 그대로 보인다(오늘 날씨로 바꾸지 않는다)', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      kLastWeatherKey: _weatherJson(DateTime.now()),
    });
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: DailyReportPage(
          existingData: {
            'date':
                "${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}",
            'dateISO': now.toIso8601String().substring(0, 10),
            'points': 1,
            'note': '어제 것',
            'weather': '맑음 8.0°C',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(findTextContaining('맑음 8.0°C'), findsOneWidget);
    expect(findTextContaining('흐림 16.6°C'), findsNothing);
  });

  test('보고서 글·CSV에 날씨가 들어간다', () {
    final log = <String, dynamic>{
      'name': 'TEST',
      'daily_reports': [
        {
          'date': '10/10',
          'dateISO': '2026-10-10',
          'work_type': ['신규 설치'],
          'worker_count': 2,
          'note': '튜브 배관',
          'weather': '흐림 16.6°C',
        },
      ],
    };
    final csv = buildReportsCsv([
      (log, (log['daily_reports'] as List).first as Map),
    ]);
    expect(csv.split('\n').first, contains('날짜,날씨,근태'));
    expect(csv.split('\n')[1], contains('"흐림 16.6°C"'));
    final doc = buildReportDoc(log, DateTime(2026, 10, 1), DateTime(2026, 10, 31));
    final all = doc.sections.expand((s) => s.lines).join('\n');
    expect(all, contains('날씨: 흐림 16.6°C'));
  });
}
