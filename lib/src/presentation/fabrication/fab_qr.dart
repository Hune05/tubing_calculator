import 'package:barcode/barcode.dart' show BarcodeQRCorrectionLevel;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/viewer_only_screen.dart';

/// 제작 지시서 PDF에 붙는 "3D 도면" QR을 만들고 읽는 곳. 만드는 화면 둘(폰·이력)과
/// 읽는 곳 둘(카메라로 열기·홈 스캐너)이 예전엔 각자 따로 만들고 풀어서 서로 어긋났다.
///
/// 형식(v2): tubingapp://view?v=2&p=프로젝트&s=규격&b=길이_각도_회전_마킹~…&sf=..&ef=..&t=꼬리&d=방향&tl=총길이&dt=yyMMddHHmm&c=검사번호
/// - 굽힘 사이는 `~`로 잇는다(예전 `-`는 음수 값과 섞였다).
/// - c는 나머지 값 전체의 CRC32라서, 일부가 깨지거나 바뀌면 열지 않는다.
/// - 예전 형식(v 없음, 굽힘 사이 `-`)은 검사 번호가 없어 "옛 형식" 안내를 붙여 연다.
class FabQr {
  FabQr._();

  static const String scheme = 'tubingapp';
  static const String host = 'view';

  /// 이 글자 수를 넘으면 QR이 촘촘해져 인쇄 상태에 따라 안 읽힐 수 있다.
  static const int denseLength = 700;

  /// 오류 보정 M 단계 QR 한 장의 용량(2331바이트)에서 여유를 둔 한계.
  static const int maxLength = 2000;

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);

  static double _raw(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final val = map[key];
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
    }
    return 0.0;
  }

  static String compressBends(List<Map<String, dynamic>> bends) {
    return bends.map((b) {
      final l = (b['length'] as num?)?.toDouble() ?? 0.0;
      final a = double.tryParse(b['angle']?.toString() ?? '0') ?? 0.0;
      final r = (b['rotation'] as num?)?.toDouble() ?? 0.0;
      final m = _raw(b, ['mark', 'marking', 'marking_point']);
      return '${_fmt(l)}_${_fmt(a)}_${_fmt(r)}_${_fmt(m)}';
    }).join('~');
  }

  static int _crc32(String s) {
    var crc = 0xFFFFFFFF;
    for (final byte in s.codeUnits) {
      crc ^= byte & 0xFF;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
      }
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  static String _check(List<String> parts) =>
      _crc32(parts.join('|')).toRadixString(16).toUpperCase().padLeft(8, '0');

  static String _stamp(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.year % 100)}${two(t.month)}${two(t.day)}${two(t.hour)}${two(t.minute)}';
  }

  static DateTime? _parseStamp(String? s) {
    if (s == null || s.length != 10) return null;
    final n = int.tryParse(s);
    if (n == null) return null;
    final y = 2000 + int.parse(s.substring(0, 2));
    return DateTime(
      y,
      int.parse(s.substring(2, 4)),
      int.parse(s.substring(4, 6)),
      int.parse(s.substring(6, 8)),
      int.parse(s.substring(8, 10)),
    );
  }

  /// PDF에 넣을 QR 주소와 종이에 적을 글(저장 일시·확인 번호)을 만든다.
  static FabQrLink build({
    required String project,
    required String pipeSize,
    required List<Map<String, dynamic>> bends,
    required bool startFit,
    required bool endFit,
    required double tail,
    required String startDir,
    required double totalCut,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final b = compressBends(bends);
    final sf = startFit.toString();
    final ef = endFit.toString();
    final tailS = _fmt(tail);
    final tl = _fmt(totalCut);
    final dt = _stamp(t);
    final c = _check([project, pipeSize, b, sf, ef, tailS, startDir, tl, dt]);
    final url = Uri(
      scheme: scheme,
      host: host,
      queryParameters: {
        'v': '2',
        'p': project,
        's': pipeSize,
        'b': b,
        'sf': sf,
        'ef': ef,
        't': tailS,
        'd': startDir,
        'tl': tl,
        'dt': dt,
        'c': c,
      },
    ).toString();
    return FabQrLink(url: url, code: c.substring(0, 4), savedText: _savedText(t));
  }

  /// 읽은 글을 풀어 본다. 값이 빠졌거나 깨졌으면 [FabQrResult.error]에 이유가 들어 있다.
  static FabQrResult parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != scheme || uri.host != host) {
      return const FabQrResult.fail('이 앱에서 만든 도면 QR이 아닙니다.');
    }
    final q = uri.queryParameters;
    final p = q['p'];
    final s = q['s'];
    final b = q['b'];
    if (p == null || p.isEmpty || s == null || s.isEmpty || b == null || b.isEmpty) {
      return const FabQrResult.fail('QR에 도면 값이 빠져 있습니다. 종이 도면의 숫자로 확인하십시오.');
    }
    final isV2 = q['v'] == '2';
    final sf = q['sf'] ?? '';
    final ef = q['ef'] ?? '';
    final tailS = q['t'] ?? '0';
    final startDir = q['d'] ?? 'RIGHT';
    final tlS = q['tl'];
    final dtS = q['dt'];
    String? code;
    if (isV2) {
      final c = q['c'];
      if (c == null || tlS == null || dtS == null) {
        return const FabQrResult.fail('QR 검사 번호가 없습니다. 종이 도면의 숫자로 확인하십시오.');
      }
      final expect = _check([p, s, b, sf, ef, tailS, startDir, tlS, dtS]);
      if (c != expect) {
        return const FabQrResult.fail(
          'QR이 손상됐거나 값이 바뀌었습니다. 다시 찍거나 종이 도면의 숫자로 확인하십시오.',
        );
      }
      code = c.substring(0, 4);
    }

    final bends = <Map<String, dynamic>>[];
    for (final seg in b.split(isV2 ? '~' : '-')) {
      final parts = seg.split('_');
      if (parts.length < 3 || parts.length > 4) {
        return const FabQrResult.fail('QR의 벤딩 값을 읽을 수 없습니다. 종이 도면의 숫자로 확인하십시오.');
      }
      final nums = parts.map(double.tryParse).toList();
      if (nums.any((n) => n == null || !n.isFinite)) {
        return const FabQrResult.fail('QR의 벤딩 값을 읽을 수 없습니다. 종이 도면의 숫자로 확인하십시오.');
      }
      final length = nums[0]!;
      final angle = nums[1]!;
      if (length < 0 || angle < 0 || angle > 360) {
        return const FabQrResult.fail('QR의 벤딩 값이 범위를 벗어났습니다. 종이 도면의 숫자로 확인하십시오.');
      }
      bends.add({
        'length': length,
        'angle': angle,
        'rotation': nums[2]!,
        'is_straight': angle == 0.0,
        'mark': nums.length >= 4 ? nums[3]! : 0.0,
      });
    }
    final tail = double.tryParse(tailS);
    if (tail == null || !tail.isFinite || tail < 0) {
      return const FabQrResult.fail('QR의 꼬리 길이를 읽을 수 없습니다. 종이 도면의 숫자로 확인하십시오.');
    }
    return FabQrResult.ok(
      FabQrData(
        project: p,
        pipeSize: s,
        bends: bends,
        startFit: sf == 'true',
        endFit: ef == 'true',
        tail: tail,
        startDir: startDir,
        totalCut: tlS == null ? null : double.tryParse(tlS),
        savedAt: _parseStamp(dtS),
        code: code,
        legacy: !isV2,
      ),
    );
  }

  /// PDF 쪽 아래에 붙는 QR(예전 50pt에서 키웠다).
  static pw.Widget pdfWidget(FabQrLink link) {
    if (link.tooLong) {
      // QR 용량을 넘으면 그리는 중에 PDF 만들기가 실패하므로 QR 대신 안내를 넣는다.
      return pw.SizedBox(
        width: 120,
        child: pw.Text(
          '벤딩이 많아 QR을 넣지 못했습니다.',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
        ),
      );
    }
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(
          width: 80,
          height: 80,
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(
              errorCorrectLevel: BarcodeQRCorrectionLevel.medium,
            ),
            data: link.url,
            color: PdfColors.black,
            drawText: false,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          '앱에서 QR 스캔 → 3D 도면',
          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          '${link.savedText} · 확인번호 ${link.code}',
          style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
        ),
      ],
    );
  }

  /// 읽은 QR을 바로 열지 않고, 규격·총 길이 같은 요약을 먼저 보여 준 뒤 연다.
  /// [context]는 Navigator 아래의 것이어야 한다(main.dart는 overlay context를 넘긴다).
  static Future<void> openWithConfirm(BuildContext context, String raw) async {
    final result = parse(raw);
    final data = result.data;
    if (data == null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('QR을 열 수 없습니다'),
          content: Text(result.error ?? 'QR을 읽을 수 없습니다.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인')),
          ],
        ),
      );
      return;
    }
    final bendCount = data.bends.where((b) => b['is_straight'] != true).length;
    final rows = <MapEntry<String, String>>[
      MapEntry('프로젝트', data.project),
      MapEntry('규격', data.pipeSize),
      if (data.totalCut != null) MapEntry('총 길이', '${_fmt(data.totalCut!)} mm'),
      MapEntry('굽힘', '$bendCount개'),
      if (data.tail > 0) MapEntry('꼬리 길이', '${_fmt(data.tail)} mm'),
      MapEntry('시작 방향', data.startDir),
      if (data.savedAt != null)
        MapEntry('저장 일시', _savedText(data.savedAt!)),
      if (data.code != null) MapEntry('확인번호', data.code!),
    ];
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('도면 QR 확인'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 78,
                        child: Text(r.key, style: const TextStyle(color: AppColors.textSub)),
                      ),
                      Expanded(
                        child: Text(r.value, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                data.legacy
                    ? '옛 형식 QR이라 값이 맞는지 검사할 수 없습니다. 종이 도면의 규격과 총 길이를 꼭 대조하십시오.'
                    : '종이 도면의 규격과 총 길이가 같은지 확인한 뒤 여십시오.',
                style: TextStyle(
                  fontSize: 13,
                  color: data.legacy ? AppColors.caution : AppColors.textSub,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('도면 열기')),
        ],
      ),
    );
    if (open != true || !context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewerOnlyScreen(
          project: data.project,
          pipeSize: data.pipeSize,
          bendList: data.bends,
          startFit: data.startFit,
          endFit: data.endFit,
          tailLength: data.tail,
          startDir: data.startDir,
        ),
      ),
    );
  }

  static String _savedText(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}

class FabQrLink {
  final String url;

  /// 종이에 적는 짧은 확인 번호(검사 번호 앞 4자리).
  final String code;

  /// 종이에 적는 저장 일시 "2026-10-05 15:20".
  final String savedText;

  const FabQrLink({required this.url, required this.code, required this.savedText});

  bool get dense => url.length > FabQr.denseLength;

  /// QR 한 장에 담을 수 있는 크기를 넘었는지.
  bool get tooLong => url.length > FabQr.maxLength;
}

class FabQrData {
  final String project;
  final String pipeSize;
  final List<Map<String, dynamic>> bends;
  final bool startFit;
  final bool endFit;
  final double tail;
  final String startDir;
  final double? totalCut;
  final DateTime? savedAt;
  final String? code;
  final bool legacy;

  const FabQrData({
    required this.project,
    required this.pipeSize,
    required this.bends,
    required this.startFit,
    required this.endFit,
    required this.tail,
    required this.startDir,
    required this.totalCut,
    required this.savedAt,
    required this.code,
    required this.legacy,
  });
}

class FabQrResult {
  final FabQrData? data;
  final String? error;

  const FabQrResult.ok(FabQrData d) : data = d, error = null;
  const FabQrResult.fail(String e) : data = null, error = e;
}
