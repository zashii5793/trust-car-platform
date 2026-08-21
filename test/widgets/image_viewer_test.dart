// 画像の拡大表示。
//
// 投稿とコメントに写真が載るようになったが、一覧のサムネイルは小さく、
// 「傷のこの部分」を見せたい写真ほど潰れて読めない。タップで全画面に開き、
// ピンチで寄れるようにする。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/widgets/image_viewer.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ImageViewer — 表示', () {
    testWidgets('画像をピンチ・パンできる', (tester) async {
      await tester.pumpWidget(_host(
        const ImageViewer(imageUrls: ['https://example.com/a.jpg']),
      ));

      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('閉じるボタンがある', (tester) async {
      await tester.pumpWidget(_host(
        const ImageViewer(imageUrls: ['https://example.com/a.jpg']),
      ));

      expect(find.byKey(const Key('image_viewer_close')), findsOneWidget);
    });

    testWidgets('1枚のときは枚数表示を出さない', (tester) async {
      await tester.pumpWidget(_host(
        const ImageViewer(imageUrls: ['https://example.com/a.jpg']),
      ));

      expect(find.byKey(const Key('image_viewer_counter')), findsNothing);
    });

    testWidgets('複数枚のときは現在位置を表示する', (tester) async {
      await tester.pumpWidget(_host(
        const ImageViewer(imageUrls: [
          'https://example.com/a.jpg',
          'https://example.com/b.jpg',
          'https://example.com/c.jpg',
        ]),
      ));

      expect(find.byKey(const Key('image_viewer_counter')), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('指定した番号の画像から開く', (tester) async {
      await tester.pumpWidget(_host(
        const ImageViewer(
          imageUrls: [
            'https://example.com/a.jpg',
            'https://example.com/b.jpg',
          ],
          initialIndex: 1,
        ),
      ));

      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets('横スワイプで次の画像に進む', (tester) async {
      await tester.pumpWidget(_host(
        const ImageViewer(imageUrls: [
          'https://example.com/a.jpg',
          'https://example.com/b.jpg',
        ]),
      ));

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets('読み込みに失敗しても代替表示でクラッシュしない', (tester) async {
      await tester.pumpWidget(_host(
        const ImageViewer(imageUrls: ['https://example.com/broken.jpg']),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('ImageViewer — 開く', () {
    testWidgets('showImageViewer で全画面に開ける', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showImageViewer(
                context,
                imageUrls: const ['https://example.com/a.jpg'],
              ),
              child: const Text('開く'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();

      expect(find.byType(ImageViewer), findsOneWidget);
    });

    testWidgets('閉じるボタンで戻れる', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showImageViewer(
                context,
                imageUrls: const ['https://example.com/a.jpg'],
              ),
              child: const Text('開く'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('image_viewer_close')));
      await tester.pumpAndSettle();

      expect(find.byType(ImageViewer), findsNothing);
    });

    testWidgets('画像が空のときは開かない', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showImageViewer(context, imageUrls: const []),
              child: const Text('開く'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();

      expect(find.byType(ImageViewer), findsNothing);
    });
  });
}
