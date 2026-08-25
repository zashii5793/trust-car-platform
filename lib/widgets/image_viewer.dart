import 'package:flutter/material.dart';

import '../core/constants/colors.dart';

/// Full-screen photo viewer with pinch-zoom and swipe between images.
///
/// Post and comment thumbnails are small on purpose so the text stays
/// readable — but the photos that matter most ("the scratch is here") are
/// exactly the ones that get lost at that size. Tapping opens this.
class ImageViewer extends StatefulWidget {
  const ImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multiple = widget.imageUrls.length > 1;

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.imageUrls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    widget.imageUrls[index],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textTertiary,
                            size: 48,
                          ),
                          SizedBox(height: 8),
                          Text(
                            '画像を読み込めませんでした',
                            style: TextStyle(color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // 閉じる
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                key: const Key('image_viewer_close'),
                tooltip: '閉じる',
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),

          // 何枚目か。1枚しかないときは出さない（黒画面に余計な文字を置かない）。
          if (multiple)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  key: const Key('image_viewer_counter'),
                  padding: const EdgeInsets.only(right: 16, top: 12),
                  child: Text(
                    '${_index + 1} / ${widget.imageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Opens [ImageViewer] full screen. No-op when there is nothing to show.
Future<void> showImageViewer(
  BuildContext context, {
  required List<String> imageUrls,
  int initialIndex = 0,
}) {
  if (imageUrls.isEmpty) return Future<void>.value();

  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        body: ImageViewer(imageUrls: imageUrls, initialIndex: initialIndex),
      ),
    ),
  );
}
