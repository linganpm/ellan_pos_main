import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tablet/data/models/product_model.dart';
import 'package:pos_tablet/data/models/category_model.dart';
import 'package:pos_tablet/presentation/widgets/category_card.dart';
import 'package:pos_tablet/presentation/widgets/product_image.dart';
import 'package:pos_tablet/presentation/widgets/product_item_card.dart';

Product _product(String id, String name, {String? offer}) => Product(
  id: id,
  name: name,
  description: '',
  price: 120,
  imageUrl: '',
  categoryId: 'c',
  offerTag: offer,
);

Widget _grid(
  List<Product> products, {
  double width = 900,
  double aspect = 0.95,
  bool compact = false,
  Map<String, double> cart = const {},
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: width,
        height: 600,
        child: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: aspect,
          ),
          itemCount: products.length,
          itemBuilder: (_, i) => ProductItemCard(
            product: products[i],
            onTap: () {},
            compact: compact,
            cartQuantity: cart[products[i].id] ?? 0,
          ),
        ),
      ),
    ),
  );
}

void main() {
  final products = [
    _product('1', 'Masala Dosa Special Family Pack', offer: '10% OFF'),
    _product('2', 'Tea'),
    _product('3', 'Cold Coffee'),
  ];

  testWidgets('a few variants start at the top-left of the grid', (
    tester,
  ) async {
    await tester.pumpWidget(_grid(products));
    final first = tester.getTopLeft(find.byType(ProductItemCard).first);
    final second = tester.getTopLeft(find.byType(ProductItemCard).at(1));
    expect(first.dx, lessThan(20));
    expect(first.dy, lessThan(20));
    expect(second.dy, first.dy);
    expect(second.dx, greaterThan(first.dx));
  });

  testWidgets('cards fit tall and short tiles without overflow', (
    tester,
  ) async {
    for (final aspect in [0.7, 0.95, 1.3]) {
      for (final compact in [true, false]) {
        await tester.pumpWidget(
          _grid(
            products,
            aspect: aspect,
            compact: compact,
            width: compact ? 760 : 980,
            cart: {'2': 2},
          ),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'aspect $aspect compact $compact',
        );
      }
    }
  });

  testWidgets('cart quantity badge, initials and offer chip render', (
    tester,
  ) async {
    await tester.pumpWidget(_grid(products, cart: {'2': 2, '3': 1.5}));
    expect(find.text('×2'), findsOneWidget);
    expect(find.text('×1.5'), findsOneWidget);
    expect(find.text('CC'), findsOneWidget);
    expect(find.text('10% OFF'), findsOneWidget);
  });

  test('accent colour is stable per product', () {
    expect(ProductItemCard.accentFor('Tea'), ProductItemCard.accentFor('Tea'));
  });

  testWidgets('product photo stretches to the card width and height', (
    tester,
  ) async {
    final file = (await tester.runAsync(() async {
      final temp = await Directory.systemTemp.createTemp('pos-card-image-');
      addTearDown(() => temp.delete(recursive: true));
      return File('${temp.path}/product.png').writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=',
        ),
      );
    }))!;
    const cardWidth = 160.0;
    const cardHeight = 180.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: ProductItemCard(
              product: Product(
                id: 'photo',
                name: 'Filter Coffee',
                description: '',
                price: 40,
                imageUrl: file.path,
                categoryId: 'c',
                offerTag: '10% OFF',
              ),
              cartQuantity: 1,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.fill);
    final imageSize = tester.getSize(find.byType(ProductImage));
    final cardSize = tester.getSize(find.byType(ProductItemCard));
    expect(imageSize.width, cardSize.width);
    expect(imageSize.height, cardSize.height);
    expect(imageSize.width, cardWidth);
    expect(imageSize.height, cardHeight);
    expect(find.text('Filter Coffee'), findsOneWidget);
    expect(find.text('10% OFF'), findsOneWidget);
    expect(find.text('×1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('product tile adds on tap without a plus button', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 150,
          height: 170,
          child: ProductItemCard(
            product: products[1],
            onTap: () => taps++,
          ),
        ),
      ),
    ));
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    await tester.tap(find.text('Tea'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('product and variant render on separate lines at each density', (tester) async {
    const item = Product(
      id: 'tea',
      name: 'Tea (Regular)',
      productName: 'Tea',
      variantName: 'Regular',
      description: '',
      price: 120,
      imageUrl: '',
      categoryId: 'c',
      offerTag: '10% OFF',
    );
    for (final compact in [true, false]) {
      for (final height in [85.0, 120.0, 180.0]) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 150,
              height: height,
              child: ProductItemCard(
                product: item,
                compact: compact,
                cartQuantity: 2,
                onTap: () {},
              ),
            ),
          ),
        ));
        expect(find.text('Tea'), findsOneWidget);
        expect(find.text('Regular'), findsOneWidget);
        expect(find.text('Tea (Regular)'), findsNothing);
        expect(tester.getTopLeft(find.text('Regular')).dy,
            greaterThan(tester.getTopLeft(find.text('Tea')).dy));
        expect(tester.takeException(), isNull, reason: '$height / $compact');
      }
    }
  });

  testWidgets('category boxes are bold, colorful and show selection', (tester) async {
    var taps = 0;
    for (final selected in [false, true]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              height: 64,
              child: CategoryCard(
                category: const CategoryModel(id: 'tea', name: 'Tea', imageUrl: ''),
                isSelected: selected,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      ));
      final text = tester.widget<Text>(find.text('Tea'));
      expect(text.style!.fontWeight, FontWeight.w800);
      expect(text.style!.color, selected ? Colors.white : ProductItemCard.accentFor('tea'));
      expect(find.byIcon(Icons.check_circle_rounded), selected ? findsOneWidget : findsNothing);
      expect(tester.getSize(find.byType(CategoryCard)).height, greaterThanOrEqualTo(48));
      await tester.tap(find.text('Tea'));
      expect(tester.takeException(), isNull);
    }
    expect(taps, 2);
  });
}
