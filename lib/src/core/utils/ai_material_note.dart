// 손으로 쓴 자재 요청 메모 사진을 서버(functions/index.js parseMaterialNote)에 보내 목록으로 받는다.
// 앱에는 키가 없다. 실패하면 이유만 알려 주고, 사용자가 직접 적을 수 있다.
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

import 'ai_polish.dart' show aiPolishErrorMessage;

/// 목록 한 줄. [unsure]는 AI가 글자를 헷갈렸거나 수량이 없다는 뜻(사용자가 확인해야 한다).
class MaterialNoteItem {
  final String name;
  final String spec;
  final double? qty;
  final String unit;
  final bool unsure;

  const MaterialNoteItem({
    required this.name,
    this.spec = '',
    this.qty,
    this.unit = '',
    this.unsure = false,
  });

  MaterialNoteItem copyWith({
    String? name,
    String? spec,
    Object? qty = _keep,
    String? unit,
    bool? unsure,
  }) => MaterialNoteItem(
    name: name ?? this.name,
    spec: spec ?? this.spec,
    qty: identical(qty, _keep) ? this.qty : qty as double?,
    unit: unit ?? this.unit,
    unsure: unsure ?? this.unsure,
  );

  static const Object _keep = Object();

  /// 폰에 임시로 남길 때([fromMap]으로 다시 읽는다).
  Map<String, Object?> toMap() => {
    'name': name,
    'spec': spec,
    'qty': qty,
    'unit': unit,
    'unsure': unsure,
  };

  static MaterialNoteItem? fromMap(Object? m) {
    if (m is! Map) return null;
    final name = (m['name'] ?? '').toString().trim();
    if (name.isEmpty) return null;
    final q = m['qty'];
    final qty = q is num && q > 0 ? q.toDouble() : null;
    return MaterialNoteItem(
      name: name,
      spec: (m['spec'] ?? '').toString().trim(),
      qty: qty,
      unit: (m['unit'] ?? '').toString().trim(),
      unsure: m['unsure'] == true || qty == null,
    );
  }
}

class MaterialNoteResult {
  final List<MaterialNoteItem>? items;
  final String? error;
  final int? remaining;
  const MaterialNoteResult.ok(List<MaterialNoteItem> this.items, {this.remaining})
    : error = null;
  const MaterialNoteResult.fail(String this.error)
    : items = null,
      remaining = null;
  bool get ok => items != null;
}

typedef MaterialNoteCall = Future<MaterialNoteResult> Function(Uint8List jpeg);

/// 실제 서버 호출.
Future<MaterialNoteResult> callParseMaterialNote(Uint8List jpeg) async {
  try {
    final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
        .httpsCallable(
          'parseMaterialNote',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        );
    final res = await callable.call<Map<Object?, Object?>>({
      'image': base64Encode(jpeg),
      'mime': 'image/jpeg',
    });
    final raw = res.data['items'];
    if (raw is! List) return const MaterialNoteResult.fail('AI가 목록을 만들지 못했습니다');
    final items = [
      for (final m in raw) ?MaterialNoteItem.fromMap(m),
    ];
    final rem = res.data['remaining'];
    return MaterialNoteResult.ok(items, remaining: rem is int ? rem : null);
  } on FirebaseFunctionsException catch (e) {
    return MaterialNoteResult.fail(aiPolishErrorMessage(e.code, e.message));
  } catch (_) {
    return const MaterialNoteResult.fail('통신이 되는지 확인해 주십시오');
  }
}
