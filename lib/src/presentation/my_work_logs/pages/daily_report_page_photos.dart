// ignore_for_file: invalid_use_of_protected_member
part of 'daily_report_page.dart';

// 🚀 photos 부분(화면 클래스에서 옮겨 온 메서드들, 동작은 그대로).
extension _DailyReportPhotos on _DailyReportPageState {
  Future<void> _editPhoto(int index) async {
    if (_photoNotReady(index)) return;
    final path = _attachedImages[index];
    final ctrl = TextEditingController(text: _imageCaptions[path] ?? '');
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "사진 메모 / 순서",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 2,
              decoration: _dec(hint: "예: B동 3층 배관 취부 후 (치수 확인용)"),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: VoiceInputButton(controller: ctrl),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: index == 0
                        ? null
                        : () => Navigator.pop(ctx, 'left'),
                    icon: const Icon(AppIcons.back, size: 16),
                    label: const Text("앞으로"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: index >= _attachedImages.length - 1
                        ? null
                        : () => Navigator.pop(ctx, 'right'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text("뒤로"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx, 'annotate'),
                icon: const Icon(Icons.draw_rounded, size: 18),
                label: const Text("화살표·동그라미 표시 (사본 추가)"),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'save'),
                style: ElevatedButton.styleFrom(backgroundColor: makitaTeal),
                child: const Text(
                  "저장",
                  style: TextStyle(
                    color: pureWhite,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    if (action == 'annotate') {
      await _annotatePhoto(index, caption: ctrl.text.trim());
      return;
    }
    setState(() {
      final c = ctrl.text.trim();
      if (c.isEmpty) {
        _imageCaptions.remove(path);
      } else {
        _imageCaptions[path] = c;
      }
      if (action == 'left' && index > 0) {
        final t = _attachedImages.removeAt(index);
        _attachedImages.insert(index - 1, t);
      } else if (action == 'right' && index < _attachedImages.length - 1) {
        final t = _attachedImages.removeAt(index);
        _attachedImages.insert(index + 1, t);
      }
    });
  }

  /// 사진 위에 화살표·글자 등을 넣은 사본을 원래 사진 바로 뒤에 붙인다(원본은 그대로).
  Future<void> _annotatePhoto(int index, {String? caption}) async {
    if (_photoNotReady(index)) return;
    final path = _attachedImages[index];
    if (_attachedImages.length >= 10) {
      if (mounted) {
        showSnackOnce(ScaffoldMessenger.of(context),
          SnackBar(content: Text(keepWords("사진은 최대 10장까지 첨부할 수 있습니다."))),
        );
      }
      return;
    }
    if (!mounted) return;
    final np = await Navigator.push<String>(
      context,
      WorkRoute(builder: (_) => PhotoAnnotatePage(path: path)),
    );
    if (np != null && mounted) {
      setState(() {
        _attachedImages.insert(index + 1, np);
        final t = _imageTags[path];
        if (t != null) _imageTags[np] = t;
        final cap = (caption ?? _imageCaptions[path] ?? '').trim();
        _imageCaptions[np] = cap.isEmpty ? '표시 사본' : '$cap (표시)';
      });
    }
  }

  /// 아직 도장·보관 중인 사진이면 잠깐 기다리라고 알리고 true(10-09).
  bool _photoNotReady(int index) {
    if (index >= _attachedImages.length || !_photoBusy(_attachedImages[index])) {
      return false;
    }
    showAppSnack(context, "사진을 정리하는 중입니다. 잠시 뒤에 다시 누르십시오.");
    return true;
  }

  Widget _photoThumb(int index, String path) {
    final tag = _imageTags[path];
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          GestureDetector(
            onLongPress: () => _editPhoto(index),
            onTap: () => PhotoDetailModal.show(
              context: context,
              title: _imageTags[path] ?? "현장 사진",
              content: _imageCaptions[path] ?? "",
              imagePaths: _attachedImages,
              initialIndex: index,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: PhotoImage(path, width: 88, height: 88),
            ),
          ),
          // 도장 찍기·보관 중(사진은 먼저 보이고, 끝나면 이 표시가 사라진다).
          if (_photoBusy(path))
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  key: Key('photo_busy_$index'),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () async {
                if (!await confirmDelete(context, title: "이 사진을 지우시겠습니까?")) {
                  return;
                }
                if (!mounted) return;
                setState(() {
                  _imageTags.remove(path);
                  _imageCaptions.remove(path);
                  _attachedImages.removeAt(index);
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 12),
              ),
            ),
          ),
          if ((_imageCaptions[path] ?? '').isNotEmpty)
            const Positioned(
              left: 4,
              top: 4,
              child: Icon(Icons.notes_rounded, color: Colors.white, size: 16),
            ),
          Positioned(
            right: 4,
            bottom: 4,
            child: GestureDetector(
              key: Key('photo_annotate_$index'),
              onTap: () => _annotatePhoto(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.draw_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
          Positioned(
            left: 4,
            bottom: 4,
            child: GestureDetector(
              onTap: () => _pickTag(path),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: tag == null ? Colors.black54 : makitaTeal,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tag ?? '+ 분류',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoAction(IconData icon, String label, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(right: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: tossInputBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: tossSubText, size: 24),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: tossSubText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _openSketch() async {
    HapticFeedback.lightImpact();
    // 배치도 화면은 하나다. 화면 폭에 맞는 모양은 그 화면이 알아서 고른다.
    final String? capturedPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const LayoutBoardPage(attachToReport: true),
      ),
    );
    if (capturedPath != null && mounted) {
      setState(() => _attachedImages.add(capturedPath));
    }
  }
}
