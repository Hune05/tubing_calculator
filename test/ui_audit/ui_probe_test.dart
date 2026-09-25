// UI 점검 도구: 화면마다 폰 폭·글자 크기를 바꿔 띄우고, 넘침·겹침·가려진 단추·
// 화면 밖 단추·너무 작은 단추·겹친 글자를 찾아 적는다. 찾기만 하고 실패시키지는 않는다.
// 평소 테스트에서는 건너뛴다. 돌릴 때:
//   UI_AUDIT=1 UI_AUDIT_OUT=결과.json UI_AUDIT_SHOTS=사진폴더 flutter test test/ui_audit/ui_probe_test.dart
// (서버·센서가 없는 화면은 서버 오류로 "실패"가 찍히지만 점검 결과는 남는다.)
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart'
    show setupFirebaseCoreMocks;
import 'package:firebase_core/firebase_core.dart';
import 'package:tubing_calculator/src/presentation/field_tools/tilt_sensor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/common_widgets/app_frame.dart';
import 'package:tubing_calculator/src/core/theme/app_theme.dart';
import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/data/models/steel_cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_input_tab.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_remote_page.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_settings_tab.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/main_navigation_page.dart';
import 'package:tubing_calculator/src/presentation/field_tools/level_page.dart';
import 'package:tubing_calculator/src/presentation/field_tools/protractor_page.dart';
import 'package:tubing_calculator/src/presentation/menu/page/menu_screen.dart';
import 'package:tubing_calculator/src/presentation/menu/page/mobile_menu_page.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/mobile_my_schedule_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/app_status_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/daily_report_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/notification_check_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/punch_list_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/storage_management_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/weekly_report_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/screens/work_log_main_screen.dart';
import 'package:tubing_calculator/src/presentation/profile/pages/mobile_profile_edit_page.dart';
import 'package:tubing_calculator/src/presentation/profile/pages/mobile_profile_page.dart';
import 'package:tubing_calculator/src/presentation/project/project_management_page.dart';
import 'package:tubing_calculator/src/presentation/reference/page/tube_reference_page.dart';
import 'package:tubing_calculator/src/presentation/settings/screens/settings_screen.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/screens/steel_cutting_detail_screen.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_leftovers.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_main_screen.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_login.dart';
import 'package:tubing_calculator/src/presentation/history/screens/history_screen.dart';

class Cfg {
  final String name;
  final Size size;
  final double scale;
  const Cfg(this.name, this.size, this.scale);
}

const phoneCfgs = [
  Cfg('작은폰 320', Size(320, 640), 1.0),
  Cfg('보통폰 360 글씨1.3', Size(360, 760), 1.3),
  Cfg('큰폰 412', Size(412, 915), 1.0),
];
const tabletCfgs = [
  Cfg('PC 가로 1280', Size(1280, 800), 1.0),
  Cfg('PC 세로 800', Size(800, 1280), 1.0),
];

final screens = <String, (Widget Function(), List<Cfg>)>{
  '폰 홈': (() => const MobileMenuPage(currentWorker: '홍길동'), phoneCfgs),
  'PC 홈': (() => const MenuScreen(), tabletCfgs),
  '튜브 계산기(탭 틀)': (() => const MobileCalculatorPage(), phoneCfgs),
  '튜브 입력 탭': (() => const Scaffold(body: MobileInputTab()), phoneCfgs),
  '튜브 마킹 탭': (
    () => const Scaffold(body: MobileResultTab(startDir: 'RIGHT')),
    phoneCfgs,
  ),
  '튜브 보기 탭': (
    () => const Scaffold(body: MobileViewerTab(startDir: 'RIGHT')),
    phoneCfgs,
  ),
  '튜브 설정 탭': (() => const Scaffold(body: MobileSettingsTab()), phoneCfgs),
  '전선관 계산기': (() => const ConduitMainNavigation(), phoneCfgs),
  '전선관 설정': (() => const ConduitSettingsPage(), phoneCfgs),
  '리모컨': (() => const MobileRemotePage(), phoneCfgs),
  '수평계': (
    () => LevelPage(
      source: () => Stream<TiltSample>.value((x: 0.0, y: 9.81, z: 0.0)),
    ),
    phoneCfgs,
  ),
  '각도기': (
    () => ProtractorPage(
      source: () => Stream<TiltSample>.value((x: 0.0, y: 9.81, z: 0.0)),
    ),
    phoneCfgs,
  ),
  '현장 자료': (() => const TubeReferencePage(), [...phoneCfgs, ...tabletCfgs]),
  '튜브 컷팅': (
    () => CuttingMainScreen(
      project: CuttingProject(
        id: 'p',
        name: '루마',
        createdAt: DateTime(2026, 9, 1),
      ),
    ),
    [...phoneCfgs, tabletCfgs.first],
  ),
  '형강 컷팅': (
    () => SteelCuttingDetailScreen(
      project: SteelCuttingProject(
        id: 's',
        name: '전선관 지지대',
        createdAt: DateTime(2026, 9, 1),
        items: [
          SteelCutItem(
            id: 'i1',
            category: 'ANGLE',
            shapeLabel: '앵글 40x40x3',
            length: 1250,
            qty: 4,
            note: '기둥',
          ),
        ],
      ),
    ),
    [...phoneCfgs, tabletCfgs.first],
  ),
  '작업 일지 메인': (
    () => const WorkLogMainScreen(),
    [...phoneCfgs, tabletCfgs.first],
  ),
  '작업 일지 쓰기': (() => const DailyReportPage(), phoneCfgs),
  '이슈 등록': (() => const PunchListPage(), phoneCfgs),
  '주간 보고': (() => const WeeklyReportPage(logs: []), phoneCfgs),
  '알림 점검': (() => const NotificationCheckPage(), phoneCfgs),
  '앱 상태': (() => const AppStatusPage(), phoneCfgs),
  '저장 공간·백업': (() => const StorageManagementPage(logs: []), phoneCfgs),
  '내 일정': (
    () => const MobileMyScheduleScreen(currentWorker: '홍길동'),
    [...phoneCfgs, tabletCfgs.first],
  ),
  '프로필': (() => const MobileProfilePage(currentWorker: '홍길동'), phoneCfgs),
  '프로필 수정': (() => const MobileProfileEditPage(initialName: '홍길동'), phoneCfgs),
  '재고 로그인': (() => const MobileInventoryLoginScreen(), phoneCfgs),
  'PC 프로젝트 관리': (() => const ProjectManagementPage(), tabletCfgs),
  'PC 설정': (() => const SettingsScreen(), tabletCfgs),
  'PC 보관함': (() => const HistoryScreen(), tabletCfgs),
};

class Finding {
  final String screen, cfg, kind, detail;
  Finding(this.screen, this.cfg, this.kind, this.detail);
  Map<String, String> toJson() => {
    'screen': screen,
    'cfg': cfg,
    'kind': kind,
    'detail': detail,
  };
}

final findings = <Finding>[];

final bool kAuditOn = Platform.environment['UI_AUDIT'] == '1';

String describe(Element e) {
  String? text;
  void visit(Element c) {
    if (text != null) return;
    final w = c.widget;
    if (w is Text) {
      text = w.data ?? w.textSpan?.toPlainText();
    } else if (w is Icon) {
      text = 'icon:${w.icon?.codePoint.toRadixString(16)}';
    } else if (w is Tooltip) {
      text = 'tooltip:${w.message}';
    }
    c.visitChildren(visit);
  }

  visit(e);
  final w = e.widget;
  final key = w.key == null ? '' : ' ${w.key}';
  return '${w.runtimeType}$key "${(text ?? '').replaceAll('\n', ' ')}"';
}

bool isTappable(Widget w) {
  if (w is InkResponse) return w.onTap != null || w.onLongPress != null;
  if (w is ButtonStyleButton) return w.onPressed != null;
  if (w is IconButton) return w.onPressed != null;
  if (w is GestureDetector) return w.onTap != null;
  if (w is Switch || w is Checkbox || w is Radio) return true;
  if (w is RawChip) return w.onPressed != null || w.onSelected != null;
  return false;
}

Future<void> audit(WidgetTester tester, String name, Cfg cfg) async {
  final errors = <String>[];
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    final where = RegExp(
      r'file:///[^\s]*?/lib/([^\s]*?:\d+)',
    ).firstMatch(d.toString())?.group(1);
    errors.add(
      '${d.exceptionAsString().split('\n').first}${where == null ? '' : ' @ $where'}',
    );
  };
  try {
    // 시험 환경은 그림자 대신 검은 선을 그린다(debugDisableShadows). 그래서 떠 있는 단추가
    // 검정 두꺼운 테두리처럼 찍혔다. 스크린샷은 실제 앱처럼 그림자로 그린다.
    debugDisableShadows = false;
    tester.view.physicalSize = cfg.size * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 72, bottom: 48);
    await tester.pumpWidget(
      MaterialApp(
        // 앱과 같은 테마로 띄운다(예전: 기본 밝은 테마라 실제 앱과 달랐다).
        theme: buildAppTheme(),
        builder: (context, child) => AppFrame(
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(cfg.scale)),
            child: child!,
          ),
        ),
        home: RepaintBoundary(key: shotKey, child: screens[name]!.$1()),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  } catch (e) {
    errors.add('pump: ${e.toString().split('\n').first}');
  } finally {
    FlutterError.onError = old;
  }
  final ex = tester.takeException();
  if (ex != null) errors.add('exception: ${ex.toString().split('\n').first}');
  for (final e in errors.toSet()) {
    final kind = e.contains('overflowed')
        ? '넘침'
        : (e.contains('Firebase') ||
              e.contains('no-app') ||
              e.contains('MissingPlugin'))
        ? '서버없음(건너뜀)'
        : '오류';
    findings.add(Finding(name, cfg.name, kind, e));
  }

  final screen = Offset.zero & cfg.size;
  final tappables = <(Element, Rect)>[];
  void walk(Element e) {
    final ro = e.renderObject;
    if (isTappable(e.widget) && ro is RenderBox && ro.attached && ro.hasSize) {
      final r = MatrixUtils.transformRect(
        ro.getTransformTo(null),
        Offset.zero & ro.size,
      );
      tappables.add((e, r));
    }
    e.debugVisitOnstageChildren(walk);
  }

  final root = tester.binding.rootElement;
  if (root == null) return;
  walk(root);

  for (final (e, r) in tappables) {
    final ro = e.renderObject as RenderBox;
    final label = describe(e);
    // 스크롤 안에서 화면(보이는 칸) 밖에 있는 것은 넘긴다.
    final vp = RenderAbstractViewport.maybeOf(ro);
    Rect? vpRect;
    if (vp is RenderBox) {
      final vb = vp as RenderBox;
      vpRect = MatrixUtils.transformRect(
        vb.getTransformTo(null),
        Offset.zero & vb.size,
      );
    }
    final visibleArea = vpRect == null ? screen : vpRect.intersect(screen);
    if (!visibleArea.overlaps(r)) continue;
    if (r.width < 1 || r.height < 1) continue;
    // 화면 옆으로 삐져나감(스크롤 없이)
    if (vpRect == null && (r.right > cfg.size.width + 1 || r.left < -1)) {
      findings.add(
        Finding(
          name,
          cfg.name,
          '화면 밖',
          '$label ${r.left.toStringAsFixed(0)}~${r.right.toStringAsFixed(0)}',
        ),
      );
    }
    // 너무 작음
    if (r.width < 40 || r.height < 40) {
      final big = r.width >= 40 ? 'h' : 'w';
      findings.add(
        Finding(
          name,
          cfg.name,
          '작은 단추',
          '$label ${r.width.toStringAsFixed(0)}x${r.height.toStringAsFixed(0)} ($big)',
        ),
      );
    }
    // 가운데를 눌렀을 때 다른 것이 받는가(겹침·가려짐)
    final c = r.center;
    if (!visibleArea.contains(c)) continue;
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, c, tester.view.viewId);
    final hit =
        result.path.any((entry) => entry.target == ro) ||
        result.path.any((entry) {
          final t = entry.target;
          if (t is! RenderObject) return false;
          RenderObject? p = t;
          while (p != null) {
            if (p == ro) return true;
            p = p.parent;
          }
          return false;
        });
    if (!hit) {
      final top = result.path.isEmpty
          ? '없음'
          : result.path.first.target.runtimeType.toString();
      findings.add(Finding(name, cfg.name, '가려진 단추', '$label (가운데를 누르면 $top)'));
    }
  }

  // 겹친 글자
  final paras = <(Element, Rect)>[];
  void walkText(Element e) {
    final ro = e.renderObject;
    if (e.widget is RichText &&
        ro is RenderParagraph &&
        ro.attached &&
        ro.hasSize) {
      var r = MatrixUtils.transformRect(
        ro.getTransformTo(null),
        Offset.zero & ro.size,
      );
      // 스크롤 안의 글은 보이는 칸으로 자른다(위로 밀려 올라간 글은 가려진 것이지 겹침이 아니다).
      RenderObject? p = ro.parent;
      while (p != null) {
        if (p is RenderAbstractViewport && p is RenderBox) {
          final vb = p as RenderBox;
          final vr = MatrixUtils.transformRect(
            vb.getTransformTo(null),
            Offset.zero & vb.size,
          );
          r = r.intersect(vr);
          if (r.width <= 0 || r.height <= 0) break;
        }
        p = p.parent;
      }
      r = r.intersect(screen);
      if (r.width > 2 && r.height > 2) paras.add((e, r));
    }
    e.debugVisitOnstageChildren(walkText);
  }

  walkText(root);
  checkTextOverlap(paras, name, cfg, '겹친 글자');

  await shot(tester, name, cfg, 'top');

  // 스크롤을 끝까지 내려도 겹치면(맨 아래 내용이 고정 단추 밑에 남음) 진짜 문제다.
  var scrolled = false;
  void walkScroll(Element e) {
    if (e is StatefulElement && e.state is ScrollableState) {
      final pos = (e.state as ScrollableState).position;
      if (pos.hasContentDimensions &&
          pos.maxScrollExtent > 0 &&
          pos.axis == Axis.vertical) {
        pos.jumpTo(pos.maxScrollExtent);
        scrolled = true;
      }
    }
    e.debugVisitOnstageChildren(walkScroll);
  }

  walkScroll(root);
  if (scrolled) {
    await tester.pump(const Duration(milliseconds: 300));
    paras.clear();
    walkText(root);
    checkTextOverlap(paras, name, cfg, '끝까지 내려도 겹침');
    await shot(tester, name, cfg, 'end');
  }
}

final shotKey = GlobalKey();

Future<void> shot(WidgetTester tester, String name, Cfg cfg, String tag) async {
  final dir = Platform.environment['UI_AUDIT_SHOTS'];
  if (dir == null) return;
  final ro = shotKey.currentContext?.findRenderObject();
  if (ro is! RenderRepaintBoundary) return;
  await tester.runAsync(() async {
    final img = await ro.toImage(pixelRatio: 1.0);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final safe = '${name}_${cfg.name}_$tag'.replaceAll(
      RegExp(r'[^0-9A-Za-z가-힣]+'),
      '_',
    );
    File('$dir/$safe.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void checkTextOverlap(
  List<(Element, Rect)> paras,
  String name,
  Cfg cfg,
  String kind,
) {
  for (var i = 0; i < paras.length; i++) {
    for (var j = i + 1; j < paras.length; j++) {
      final a = paras[i].$2, b = paras[j].$2;
      final inter = a.intersect(b);
      if (inter.width > 4 && inter.height > 4) {
        String t(Element e) =>
            ((e.widget as RichText).text.toPlainText()).replaceAll('\n', ' ');
        final ta = t(paras[i].$1), tb = t(paras[j].$1);
        if (ta.trim().isEmpty || tb.trim().isEmpty) continue;
        findings.add(Finding(name, cfg.name, kind, '"$ta" ↔ "$tb"'));
      }
    }
  }
}

void main() {
  setUpAll(() async {
    if (!kAuditOn) return;
    Future<void> font(String family, String path) async {
      final f = File(path);
      if (!f.existsSync()) return;
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
      await loader.load();
    }

    // 서버(Firebase)는 켜진 것처럼만 한다. 읽기·쓰기는 실패하고 화면은 빈 상태로 뜬다.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    const kr = 'assets/fonts/NotoSansKR-Regular.ttf';
    await font('Roboto', kr);
    // 앱 테마 글꼴(굵기가 바뀌는 가변 글꼴).
    await font('NotoSansKR', 'assets/fonts/NotoSansKR-VariableFont_wght.ttf');
    await font(
      'MaterialIcons',
      '/opt/flutter-sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    final home = Platform.environment['HOME'];
    await font(
      'packages/lucide_icons/Lucide',
      '$home/.pub-cache/hosted/pub.dev/lucide_icons-0.257.0/assets/lucide.ttf',
    );
    leftoverStore = PrefsLeftoverStore();
    TestWidgetsFlutterBinding.ensureInitialized();
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final tmp = Directory.systemTemp.createTempSync('ui_audit').path;
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => tmp,
    );
    m.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (_) async => const StandardMessageCodec().encodeMessage(<Object?>[]),
    );
  });
  setUp(
    () => SharedPreferences.setMockInitialValues({'user_real_name': '홍길동'}),
  );

  for (final e in screens.entries) {
    for (final cfg in e.value.$2) {
      testWidgets('${e.key} · ${cfg.name}', skip: !kAuditOn, (tester) async {
        try {
          await audit(tester, e.key, cfg);
        } finally {
          // 시험 틀이 끝에 이 값이 켜져 있는지 확인한다.
          debugDisableShadows = true;
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        tester.view.reset();
      });
    }
  }

  tearDownAll(() {
    final out = Platform.environment['UI_AUDIT_OUT'];
    if (out != null) {
      File(out).writeAsStringSync(
        const JsonEncoder.withIndent(
          ' ',
        ).convert([for (final f in findings) f.toJson()]),
      );
    }
  });
}
