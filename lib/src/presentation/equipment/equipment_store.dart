// 장비 관리 대장의 저장: 폰 저장이 먼저이고, 같은 이름으로 쓰는 다른 폰과 서버로 맞춘다(record_sync.dart).
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/record_sync.dart';
import 'equipment_model.dart';

class EquipmentStore {
  static const String key = 'equipment_ledger_v1';

  /// 서버 올리기·받기(모음 equipment_ledger, 주인 = 앱 사용자 이름).
  static final RecordSync sync = RecordSync(
    key: key,
    collection: 'equipment_ledger',
    isValid: _readable,
  );

  static bool _readable(Map<String, dynamic> j) {
    try {
      Equipment.fromJson(j);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 폰에 있는 장비 전부(망가진 한 건은 건너뛴다).
  static Future<List<Equipment>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      final out = <Equipment>[];
      for (final e in list) {
        try {
          out.add(Equipment.fromJson(Map<String, dynamic>.from(e as Map)));
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _write(List<Equipment> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode([for (final e in list) e.toJson()]));
  }

  /// 같은 번호가 있으면 바꾸고 없으면 더한다.
  static Future<void> put(Equipment e) async {
    final list = await load();
    final i = list.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      list[i] = e;
    } else {
      list.add(e);
    }
    await _write(list);
    await sync.saved(e.id);
  }

  static Future<void> delete(String id) async {
    final list = await load();
    list.removeWhere((e) => e.id == id);
    await _write(list);
    await sync.removed(id);
  }

  /// 새 장비 번호(만든 시각).
  static String newId([DateTime? now]) =>
      (now ?? DateTime.now()).microsecondsSinceEpoch.toString();

  /// 관리번호로 장비를 찾는다(QR 글 "FH-EQ:번호"도 된다). 없으면 null.
  static Equipment? findByCode(List<Equipment> all, String code) {
    var c = code.trim();
    if (c.startsWith('FH-EQ:')) c = c.substring(6).trim();
    if (c.isEmpty) return null;
    final lower = c.toLowerCase();
    for (final e in all) {
      if (e.assetNo.trim().toLowerCase() == lower) return e;
    }
    for (final e in all) {
      if (e.id == c) return e;
    }
    for (final e in all) {
      if (e.serial.trim().isNotEmpty && e.serial.trim().toLowerCase() == lower) {
        return e;
      }
    }
    return null;
  }
}
