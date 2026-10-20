import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tablet/presentation/widgets/product_image.dart';

void main() {
  testWidgets('renders downloaded bytes using FileImage, not NetworkImage', (
    tester,
  ) async {
    final file = (await tester.runAsync(() async {
      final temp = await Directory.systemTemp.createTemp('pos-widget-image-');
      addTearDown(() => temp.delete(recursive: true));
      return File('${temp.path}/downloaded-image').writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=',
        ),
      );
    }))!;
    await tester.pumpWidget(MaterialApp(home: ProductImage(source: file.path)));
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<FileImage>());
    expect((image.image as FileImage).file.path, file.path);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.inventory_2_outlined), findsNothing);
  });

  testWidgets('missing source shows placeholder without starting a download', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ProductImage(source: '')));
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
  });

  testWidgets('file URI is also loaded locally', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProductImage(source: 'file:///missing/offline-product.png'),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<FileImage>());
    expect(
      (image.image as FileImage).file.path,
      '/missing/offline-product.png',
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
