// 입력 탭을 가로(폰 882×300)·세로(344×760)로 봐도 넘치지 않는지.
// 예전에는 방향 칸 높이를 폭에 비례로 잡아 가로에서 281px, 튜브 입력판은
// 스크롤이 없어 80px 넘쳤다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_input_tab.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_input_tab.dart';

void main() {
  final tabs = <String, Widget Function()>{
    '튜브': () => const MobileInputTab(),
    '전선관': () => const ConduitInputTab(),
  };
  for (final size in const [Size(882, 300), Size(344, 760)]) {
    for (final e in tabs.entries) {
      testWidgets('${e.key} ${size.width.toInt()}×${size.height.toInt()}', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        MobileBendDataManager().bendList
          ..clear()
          ..add({'length': 150.0, 'angle': 0.0, 'rotation': 0.0});
        ConduitDataManager().bendList
          ..clear()
          ..add({'length': 150.0, 'angle': 0.0, 'rotation': 0.0});
        final errors = <String>[];
        final old = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(d.exceptionAsString());
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: e.value())));
        await tester.pumpAndSettle();
        // 방향 칸이 나오는 90° 벤딩으로.
        await tester.tap(find.text('90° 벤딩').first, warnIfMissed: false);
        await tester.pumpAndSettle();
        FlutterError.onError = old;
        expect(errors, isEmpty);
      });
    }
  }
}
