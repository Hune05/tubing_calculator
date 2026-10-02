// 장비 설명서 붙이기: 제조사가 배포한 설명서 PDF를 한 번 골라 두면 이 폰에 보관하고(도면 보기 보관함),
// 장비 대장·장비 사용법 어디서든 같은 설명서를 연다. 통신 없이 열린다.
// 설명서 내용은 앱이 옮겨 적지 않는다 — 제조사 원본 파일을 그대로 보관해 연다.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_tokens.dart';
import '../drawing_viewer/drawing_models.dart';
import '../drawing_viewer/drawing_store.dart';
import '../drawing_viewer/drawing_viewer_page.dart';
import '../drawing_viewer/dxf_reader.dart';

/// 제조사가 설명서를 올려 둔 곳(내려받기 주소). 모델 열쇠 → 주소.
const Map<String, String> kOfficialManualUrls = {
  'REMS|Amigo 2': 'https://www.rems.de/dlbatv2/536003R',
  'REMS|Tiger SR': 'https://www.rems.de/dlbatv2/566008RX',
  'UE|J120': 'https://www.ueonline.com/wp-content/uploads/IMP120.pdf',
};

/// 같은 장비면 같은 설명서를 쓰도록 제조사·모델로 열쇠를 만든다. 모델이 없으면 장비 하나에만.
String manualKeyFor({String maker = '', String model = '', String id = ''}) {
  final m = maker.trim(), n = model.trim();
  if (n.isNotEmpty) return '${m.toUpperCase() == 'REMS' ? 'REMS' : m}|$n';
  return 'id:$id';
}

class EquipManuals {
  static String _prefKey(String key) => 'equip_manual_$key';

  static Future<String?> docId(String key) async => (await SharedPreferences.getInstance()).getString(_prefKey(key));

  static Future<void> setDocId(String key, String? id) async {
    final p = await SharedPreferences.getInstance();
    if (id == null) {
      await p.remove(_prefKey(key));
    } else {
      await p.setString(_prefKey(key), id);
    }
  }

  /// 붙여 둔 설명서(보관함에서 지워졌으면 null).
  static Future<DrawingDoc?> doc(String key) async {
    final id = await docId(key);
    if (id == null) return null;
    return DrawingStore.get(id);
  }
}

/// 설명서를 연다. 붙여 둔 것이 없으면 받는 곳과 고르는 법을 보여 준다.
Future<void> openEquipManual(BuildContext context, {required String key, required String title}) async {
  final doc = await EquipManuals.doc(key);
  if (!context.mounted) return;
  if (doc != null) {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => DrawingViewerPage(doc: doc)));
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ManualSheet(manualKey: key, title: title),
  );
}

class _ManualSheet extends StatefulWidget {
  final String manualKey;
  final String title;
  const _ManualSheet({required this.manualKey, required this.title});

  @override
  State<_ManualSheet> createState() => _ManualSheetState();
}

class _ManualSheetState extends State<_ManualSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _pick() async {
    final res = await FilePicker.pickFiles(type: FileType.any);
    if (res == null || res.files.isEmpty || res.files.first.path == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final f = res.files.first;
      var doc = await DrawingStore.importFile(f.path!, name: f.name);
      doc = doc.copyWith(title: '${widget.title} 설명서');
      await DrawingStore.put(doc);
      await EquipManuals.setDocId(widget.manualKey, doc.id);
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop();
      await nav.push(MaterialPageRoute<void>(builder: (_) => DrawingViewerPage(doc: doc)));
    } on DxfError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '열지 못했습니다: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = kOfficialManualUrls[widget.manualKey];
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.title} 설명서', style: AppText.title),
            const SizedBox(height: 6),
            const Text(
              '제조사 설명서 PDF를 한 번 골라 두면 이 폰에 보관되어 통신 없이도 열립니다. '
              '장비 대장과 장비 사용법에서 같은 설명서를 엽니다.',
              style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSub),
            ),
            if (url != null) ...[
              const SizedBox(height: 10),
              const Text('제조사 내려받기 주소 (통신될 때 받아 두십시오)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSub)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: SelectableText(url, key: const Key('manual_url'), style: const TextStyle(fontSize: 13, color: AppColors.brand))),
                  TextButton(
                    key: const Key('manual_copy'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('주소를 복사했습니다. 인터넷 창에 붙여 넣어 받으십시오.')));
                    },
                    child: const Text('복사'),
                  ),
                ],
              ),
            ],
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('manual_pick'),
              onPressed: _busy ? null : _pick,
              icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('받아 둔 설명서 PDF 고르기'),
            ),
          ],
        ),
      ),
    );
  }
}
