// 홈 화면이 마지막으로 받은 날씨를 폰에 남겨 두고, 작업 일지의 날씨 칸에 넣는다(10-10).
// 발전소처럼 통신이 없는 곳에서는 날씨를 못 받으므로, 그날 받은 값이 있을 때만 쓴다.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 마지막으로 받은 날씨를 적어 두는 폰 저장 키.
const String kLastWeatherKey = 'last_weather_v1';

class WeatherNote {
  final String desc; // 맑음·흐림·비·눈
  final double temp; // 기온 °C
  final String pm; // 미세먼지(좋음·보통·나쁨…), 모르면 빈칸
  final String place; // 시·구 이름, 모르면 빈칸
  final DateTime at; // 받은 때

  const WeatherNote({
    required this.desc,
    required this.temp,
    this.pm = '',
    this.place = '',
    required this.at,
  });

  Map<String, dynamic> toJson() => {
    'desc': desc,
    'temp': temp,
    'pm': pm,
    'place': place,
    'at': at.toIso8601String(),
  };

  static WeatherNote? fromJson(Map<String, dynamic> m) {
    final at = DateTime.tryParse(m['at']?.toString() ?? '');
    final temp = (m['temp'] as num?)?.toDouble();
    final desc = (m['desc'] ?? '').toString().trim();
    if (at == null || temp == null || desc.isEmpty) return null;
    return WeatherNote(
      desc: desc,
      temp: temp,
      pm: (m['pm'] ?? '').toString(),
      place: (m['place'] ?? '').toString(),
      at: at,
    );
  }
}

/// 작업 일지 날씨 칸에 넣는 한 줄. 예: "흐림 16.6°C · 미세먼지 나쁨"
String weatherLineOf(WeatherNote w) {
  final pm = w.pm.trim();
  final usePm = pm.isNotEmpty && pm != '알 수 없음';
  return '${w.desc} ${w.temp.toStringAsFixed(1)}°C${usePm ? ' · 미세먼지 $pm' : ''}';
}

/// [day] 일지에 넣을 날씨 줄: 그날 받은 값일 때만(지난 날짜 일지에 오늘 날씨를 넣지 않는다).
String? weatherLineForDay(WeatherNote? w, DateTime day) {
  if (w == null) return null;
  final sameDay =
      w.at.year == day.year && w.at.month == day.month && w.at.day == day.day;
  return sameDay ? weatherLineOf(w) : null;
}

Future<void> saveLastWeather(WeatherNote w) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(kLastWeatherKey, jsonEncode(w.toJson()));
  } catch (_) {}
}

Future<WeatherNote?> loadLastWeather() async {
  try {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(kLastWeatherKey);
    if (raw == null) return null;
    return WeatherNote.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  } catch (_) {
    return null;
  }
}
