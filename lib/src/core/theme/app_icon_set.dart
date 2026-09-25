// 아이콘 한 벌(UI 디자인 제안 D-E).
//
// 예전에는 Material(채움·굵기 여러 가지), Lucide(가는 선), 자체 그림(AppGlyph)이 한 화면에 섞였다.
// 규칙:
//  - 흔한 동작(뒤로·닫기·찾기·더보기·추가·고치기·지우기·보내기·기록·설정·새로 고침 …)은
//    여기 이름(AppIcons.x)으로 쓴다. 모양은 Lucide 가는 선 한 벌.
//  - 벤딩·피팅·줄자처럼 Lucide에 없는 현장 그림은 자체 그림(AppGlyph, app_icons.dart).
//  - 방향 단추(UP·FRONT…)의 화살표는 그대로 둔다(현장에서 익숙한 모양).
// 아직 옮기지 않은 화면은 Material이 남아 있다. 화면을 고칠 때 이 이름으로 옮긴다.
library;

import 'package:flutter/widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

abstract final class AppIcons {
  // 이동
  static const IconData back = LucideIcons.chevronLeft;
  static const IconData forward = LucideIcons.chevronRight; // 목록 오른쪽 화살표
  static const IconData close = LucideIcons.x;
  static const IconData more = LucideIcons.moreVertical;
  static const IconData moreHorizontal = LucideIcons.moreHorizontal;

  // 동작
  static const IconData search = LucideIcons.search;
  static const IconData add = LucideIcons.plus;
  static const IconData edit = LucideIcons.pencil;
  static const IconData editNote = LucideIcons.fileEdit;
  static const IconData delete = LucideIcons.trash2;
  static const IconData share = LucideIcons.share2;
  static const IconData send = LucideIcons.send;
  static const IconData save = LucideIcons.save;
  static const IconData download = LucideIcons.download;
  static const IconData upload = LucideIcons.uploadCloud;
  static const IconData print = LucideIcons.printer;
  static const IconData copy = LucideIcons.copy;
  static const IconData refresh = LucideIcons.refreshCw;
  static const IconData undo = LucideIcons.undo2;
  static const IconData redo = LucideIcons.redo2;
  static const IconData check = LucideIcons.check;
  static const IconData filter = LucideIcons.filter;
  static const IconData openFile = LucideIcons.folderOpen;

  // 보기·정보
  static const IconData history = LucideIcons.history;
  static const IconData settings = LucideIcons.settings;
  static const IconData calendar = LucideIcons.calendarDays;
  static const IconData calendarEdit = LucideIcons.calendarPlus;
  static const IconData stats = LucideIcons.barChart3;
  static const IconData list = LucideIcons.list;
  static const IconData help = LucideIcons.helpCircle;
  static const IconData info = LucideIcons.info;
  static const IconData warning = LucideIcons.alertTriangle;
  static const IconData show = LucideIcons.eye;
  static const IconData hide = LucideIcons.eyeOff;
  static const IconData bell = LucideIcons.bell;
  static const IconData camera = LucideIcons.camera;
  static const IconData scan = LucideIcons.scanLine;
  static const IconData qr = LucideIcons.qrCode;
  static const IconData user = LucideIcons.user;
  static const IconData logout = LucideIcons.logOut;
  static const IconData pdf = LucideIcons.fileText;
}
