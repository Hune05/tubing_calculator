import 'dart:io' show Platform;

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'cutting_theme.dart';

// ── 카카오톡으로 지시서 글 바로 보내기 ──
// 안드로이드에서 카카오톡 앱을 지정해서 글을 보낸다(대화방을 고르는 화면으로 바로 넘어간다).
// 카카오톡이 없거나 안드로이드가 아니면 false를 돌려주고, 부른 쪽이 일반 공유창으로 대신 보낸다.
// PDF 파일은 이 방식으로 카카오톡에 바로 보낼 수 없어서(파일 권한 문제) 글만 보낸다.
const String kKakaoPackage = 'com.kakao.talk';

typedef KakaoSender = Future<bool> Function(String text);

// 테스트에서 바꿔 끼울 수 있게 전역으로 둔다.
KakaoSender kakaoSender = _defaultKakaoSender;

Future<bool> _defaultKakaoSender(String text) async {
  if (!Platform.isAndroid) return false;
  try {
    final intent = AndroidIntent(
      // 안드로이드의 정식 이름을 써야 한다(줄임말 'action_send'는 못 알아듣고 "열 앱 없음"이 나왔다).
      action: 'android.intent.action.SEND',
      package: kKakaoPackage,
      type: 'text/plain',
      arguments: {'android.intent.extra.TEXT': text},
    );
    // 카카오톡이 없으면 열 때 오류가 나므로 그때 false를 돌려준다.
    await intent.launch();
    return true;
  } catch (e) {
    debugPrint('카카오톡 보내기 실패: $e');
    return false;
  }
}

// 카카오톡이 없을 때 대신 쓰는 일반 공유(글).
typedef TextSharer = Future<void> Function(String text);

TextSharer textSharer = (text) async {
  // ignore: deprecated_member_use
  await Share.share(text);
};

// ── 재단 최적화 아이콘 ──
// 원자재 막대 하나에 조각들이 채워지고 끝에 자투리가 남는 모양. 기본 아이콘 중에는 "원자재를
// 몇 본, 어떻게 자르나"를 뜻하는 것이 없어서 직접 그린다.
class CutBarIcon extends StatelessWidget {
  final double size;
  final Color color;

  const CutBarIcon({
    super.key,
    this.size = 24,
    this.color = CuttingColors.primary,
  });

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size), painter: _CutBarPainter(color));
}

class _CutBarPainter extends CustomPainter {
  final Color color;
  const _CutBarPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..color = color;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeJoin = StrokeJoin.round;

    // 위쪽 막대: 조각 세 개(채움) + 자투리(빈 칸)
    double y = h * 0.14;
    final bh = h * 0.30;
    final gap = w * 0.05;
    final x0 = w * 0.06;
    final total = w * 0.88;
    final pieces = [0.30, 0.22, 0.26];
    var x = x0;
    for (final p in pieces) {
      final pw = total * p;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, pw - gap, bh),
          Radius.circular(w * 0.04),
        ),
        fill,
      );
      x += pw;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, x0 + total - x, bh),
        Radius.circular(w * 0.04),
      ),
      line,
    );

    // 아래쪽 막대: 조각 두 개 + 자투리
    y = h * 0.56;
    x = x0;
    for (final p in [0.46, 0.34]) {
      final pw = total * p;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, pw - gap, bh),
          Radius.circular(w * 0.04),
        ),
        fill,
      );
      x += pw;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, x0 + total - x, bh),
        Radius.circular(w * 0.04),
      ),
      line,
    );
  }

  @override
  bool shouldRepaint(_CutBarPainter old) => old.color != color;
}

// ── 결과 탭 제목줄 오른쪽에 두는 아이콘 버튼 줄 ──
// 아이콘마다 44dp 이상의 누르는 영역, 길게 누르면 이름이 뜬다(tooltip). 처음 쓰는 동안에는
// 아이콘 아래에 이름을 작게 보여 주다가 한 번이라도 쓰면 사라진다([showLabels]).
class CutActionSpec {
  final Key key;
  final String label; // 길게 눌렀을 때와 처음 쓰는 동안 아래에 보이는 이름
  final Widget icon;
  final VoidCallback onPressed;
  final Color? background; // 카카오톡처럼 색이 있는 버튼
  const CutActionSpec({
    required this.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.background,
  });
}

class CutActionBar extends StatelessWidget {
  final List<CutActionSpec> actions;
  final bool showLabels;

  const CutActionBar({
    super.key,
    required this.actions,
    this.showLabels = false,
  });

  static const double target = 46; // 누르는 영역(장갑 낀 손도 누를 수 있게)

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final a in actions)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: a.label,
                  triggerMode: TooltipTriggerMode.longPress,
                  child: Material(
                    color: a.background ?? CuttingColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      key: a.key,
                      borderRadius: BorderRadius.circular(12),
                      onTap: a.onPressed,
                      child: SizedBox(
                        width: target,
                        height: target,
                        child: Center(child: a.icon),
                      ),
                    ),
                  ),
                ),
                if (showLabels)
                  SizedBox(
                    width: target + 4,
                    child: Text(
                      a.label,
                      key: Key('action_label_${a.label}'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: CuttingColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
