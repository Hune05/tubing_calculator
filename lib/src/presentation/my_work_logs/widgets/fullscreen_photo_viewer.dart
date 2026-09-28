// 사진만 풀 화면으로 확대해서 보는 뷰어(제목·설명 없이 사진에만 집중).
// 손가락으로 확대·축소하거나 좌우로 넘기고, 아래 가로 썸네일 줄을 눌러 바로 그 사진으로 넘어갈 수 있다.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/field_view.dart';
import '../models/photo_store.dart';

class FullscreenPhotoViewer extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;

  const FullscreenPhotoViewer({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  static Future<void> show({
    required BuildContext context,
    required List<String> photos,
    int initialIndex = 0,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            FullscreenPhotoViewer(photos: photos, initialIndex: initialIndex),
      ),
    );
  }

  @override
  State<FullscreenPhotoViewer> createState() => _FullscreenPhotoViewerState();
}

class _FullscreenPhotoViewerState extends State<FullscreenPhotoViewer> {
  static const double _thumbSize = 56;
  static const double _thumbGap = 8;

  late final PageController _page;
  late final ScrollController _thumbs;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.photos.length - 1);
    _page = PageController(initialPage: _index);
    _thumbs = ScrollController();
  }

  @override
  void dispose() {
    _page.dispose();
    _thumbs.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    _page.animateToPage(
      i,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    if (!_thumbs.hasClients) return;
    const extent = _thumbSize + _thumbGap;
    final target = extent * i - 100;
    _thumbs.animateTo(
      target.clamp(0.0, _thumbs.position.maxScrollExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final n = photos.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  key: const Key('fpv_close'),
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    n > 1 ? '${_index + 1} / $n' : '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: n,
                onPageChanged: _onPageChanged,
                itemBuilder: (_, i) => InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 5.0,
                  child: Center(
                    child: PhotoImage(photos[i], fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            if (n > 1)
              SizedBox(
                height: _thumbSize + 16,
                child: ListView.separated(
                  key: const Key('fpv_thumbs'),
                  controller: _thumbs,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: n,
                  separatorBuilder: (_, _) => const SizedBox(width: _thumbGap),
                  itemBuilder: (_, i) {
                    final selected = i == _index;
                    return GestureDetector(
                      key: Key('fpv_thumb_$i'),
                      onTap: () => _goTo(i),
                      child: Container(
                        width: _thumbSize,
                        height: _thumbSize,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected ? fc.brand : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: PhotoImage(
                            photos[i],
                            width: _thumbSize,
                            height: _thumbSize,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
