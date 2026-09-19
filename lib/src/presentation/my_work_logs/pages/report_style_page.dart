import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../../core/utils/image_picker_helper.dart';
import '../models/report_style.dart';

const Color _teal = Color(0xFF007580);
const Color _text = Color(0xFF191F28);
const Color _sub = Color(0xFF8B95A1);
const Color _bg = Color(0xFFF2F4F6);

// 🚀 [보고서 양식 설정] 회사명·로고·담당자 머리말, 서명란, 포함 항목, PDF 사진 기본값.
class ReportStylePage extends StatefulWidget {
  const ReportStylePage({super.key});

  @override
  State<ReportStylePage> createState() => _ReportStylePageState();
}

class _ReportStylePageState extends State<ReportStylePage> {
  late final ReportStyle _s;
  final _company = TextEditingController();
  final _manager = TextEditingController();
  final _sig1 = TextEditingController();
  final _sig2 = TextEditingController();

  @override
  void initState() {
    super.initState();
    final c = ReportStyle.current;
    _s = ReportStyle.fromJson(c.toJson());
    _company.text = _s.company;
    _manager.text = _s.manager;
    _sig1.text = _s.sig1;
    _sig2.text = _s.sig2;
  }

  @override
  void dispose() {
    _company.dispose();
    _manager.dispose();
    _sig1.dispose();
    _sig2.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final path = await ImagePickerHelper.pickImage(context);
    if (path == null) return;
    try {
      // 로고는 작게 줄여(가로세로 300px 이내) 문서에 같이 저장한다.
      final bytes = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: 300,
        minHeight: 300,
        quality: 80,
        format: path.toLowerCase().endsWith('.png')
            ? CompressFormat.png
            : CompressFormat.jpeg,
      );
      if (bytes == null) return;
      setState(() => _s.logoB64 = base64Encode(bytes));
    } catch (_) {
      final bytes = await File(path).readAsBytes();
      if (bytes.length < 200 * 1024) {
        setState(() => _s.logoB64 = base64Encode(bytes));
      }
    }
  }

  Future<void> _drawSig(bool first) async {
    final b64 = await showDialog<String>(
      context: context,
      builder: (ctx) =>
          _SignatureDialog(title: first ? _sig1.text : _sig2.text),
    );
    if (b64 == null) return;
    setState(() {
      if (first) {
        _s.sig1B64 = b64;
      } else {
        _s.sig2B64 = b64;
      }
    });
  }

  Widget _sigRow(String label, String? b64, bool first) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      children: [
        Container(
          width: 120,
          height: 48,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: b64 == null
              ? const Center(
                  child: Text(
                    "서명 없음",
                    style: TextStyle(color: _sub, fontSize: 11),
                  ),
                )
              : Image.memory(base64Decode(b64), fit: BoxFit.contain),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: () => _drawSig(first),
          child: Text(b64 == null ? "$label 손서명 그리기" : "다시 그리기"),
        ),
        if (b64 != null)
          TextButton(
            onPressed: () => setState(() {
              if (first) {
                _s.sig1B64 = null;
              } else {
                _s.sig2B64 = null;
              }
            }),
            child: const Text("삭제"),
          ),
      ],
    ),
  );

  Future<void> _save() async {
    _s.company = _company.text.trim();
    _s.manager = _manager.text.trim();
    _s.sig1 = _sig1.text.trim().isEmpty ? '작성자' : _sig1.text.trim();
    _s.sig2 = _sig2.text.trim().isEmpty ? '확인자' : _sig2.text.trim();
    await saveReportStyle(_s);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("보고서 양식을 저장했습니다.")));
    Navigator.pop(context);
  }

  Widget _card(String title, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: _text,
          ),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          "보고서 양식 설정",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card("머리말", [
            TextField(
              controller: _company,
              decoration: const InputDecoration(labelText: "회사명 / 현장명"),
            ),
            TextField(
              controller: _manager,
              decoration: const InputDecoration(labelText: "담당자"),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_s.logoB64 != null)
                  Container(
                    width: 64,
                    height: 64,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.memory(
                      base64Decode(_s.logoB64!),
                      fit: BoxFit.contain,
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _pickLogo,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text(_s.logoB64 == null ? "로고 선택" : "로고 변경"),
                ),
                if (_s.logoB64 != null)
                  TextButton(
                    onPressed: () => setState(() => _s.logoB64 = null),
                    child: const Text("삭제"),
                  ),
              ],
            ),
          ]),
          _card("서명란", [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("PDF 맨 끝에 서명란 넣기"),
              value: _s.signature,
              onChanged: (v) => setState(() => _s.signature = v),
            ),
            if (_s.signature)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sig1,
                      decoration: const InputDecoration(labelText: "서명 1 이름"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _sig2,
                      decoration: const InputDecoration(labelText: "서명 2 이름"),
                    ),
                  ),
                ],
              ),
            if (_s.signature) ...[
              _sigRow("서명 1", _s.sig1B64, true),
              _sigRow("서명 2", _s.sig2B64, false),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  "손서명을 저장해 두면 PDF 서명란에 자동으로 들어가요.",
                  style: TextStyle(color: _sub, fontSize: 11),
                ),
              ),
            ],
          ]),
          _card("작업 보고서에 넣을 항목", [
            const Text(
              "꺼 둔 항목은 작업 보고서(텍스트/PDF)에서 빠져요.",
              style: TextStyle(color: _sub, fontSize: 12),
            ),
            for (final k in ReportStyle.optionalSections)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: _teal,
                title: Text(k),
                value: !_s.hiddenSections.contains(k),
                onChanged: (v) => setState(() {
                  v == true
                      ? _s.hiddenSections.remove(k)
                      : _s.hiddenSections.add(k);
                }),
              ),
          ]),
          _card("기본값", [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("PDF 내보낼 때 사진 포함을 기본으로"),
              value: _s.defaultPhotos,
              onChanged: (v) => setState(() => _s.defaultPhotos = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("주간 보고 PDF에 작성일·작성자 줄 넣기"),
              subtitle: const Text("제목 아래에 '작성일 · 작성 담당자' 한 줄이 들어가요."),
              value: _s.weeklyAuthorLine,
              onChanged: (v) => setState(() => _s.weeklyAuthorLine = v),
            ),
          ]),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "저장",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 손으로 서명을 그리는 대화상자. 저장하면 PNG(base64)를 돌려준다.
class _SignatureDialog extends StatefulWidget {
  final String title;
  const _SignatureDialog({required this.title});

  @override
  State<_SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<_SignatureDialog> {
  final List<List<Offset>> _strokes = [];
  static const _w = 300.0, _h = 150.0;

  void _paintStrokes(Canvas c) {
    final p = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final s in _strokes) {
      if (s.length == 1) {
        c.drawPoints(ui.PointMode.points, s, p);
      } else {
        final path = Path()..moveTo(s.first.dx, s.first.dy);
        for (final o in s.skip(1)) {
          path.lineTo(o.dx, o.dy);
        }
        c.drawPath(path, p);
      }
    }
  }

  Future<void> _done() async {
    if (_strokes.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, const Rect.fromLTWH(0, 0, _w, _h));
    _paintStrokes(c);
    final img = await rec.endRecording().toImage(_w.toInt(), _h.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted) return;
    Navigator.pop(context, base64Encode(data!.buffer.asUint8List()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("${widget.title} 손서명"),
      content: Container(
        width: _w,
        height: _h,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: GestureDetector(
          onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
          onPanUpdate: (d) =>
              setState(() => _strokes.last.add(d.localPosition)),
          child: CustomPaint(
            painter: _SigPainter(_strokes),
            size: const Size(_w, _h),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(_strokes.clear),
          child: const Text("지우기"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("취소"),
        ),
        TextButton(onPressed: _done, child: const Text("저장")),
      ],
    );
  }
}

class _SigPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _SigPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.length == 1) {
        canvas.drawPoints(ui.PointMode.points, s, p);
      } else {
        final path = Path()..moveTo(s.first.dx, s.first.dy);
        for (final o in s.skip(1)) {
          path.lineTo(o.dx, o.dy);
        }
        canvas.drawPath(path, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SigPainter old) => true;
}
