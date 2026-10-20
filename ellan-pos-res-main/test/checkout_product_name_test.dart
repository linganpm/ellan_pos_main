import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tablet/bloc/cart/cart_bloc.dart';
import 'package:pos_tablet/bloc/cart/cart_event.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';

PosCatalogProduct product({
  String name = 'Regular',
  String parent = 'Tea',
  String variant = 'Regular',
}) => PosCatalogProduct(
  id: 'tea',
  name: name,
  productName: parent,
  packageName: variant,
  price: 120,
  categoryId: 1,
);

class CatalogueController extends UiStoreController {
  @override
  Future<PosCatalogue> loadCatalogue() async =>
      PosCatalogue(categories: const [], products: [product()]);

  @override
  Future<Map<String, String>> loadProductOfferTags() async => {};
}

void main() {
  test('checkout name includes product and variant with safe fallbacks', () {
    expect(product().checkoutName, 'Tea (Regular)');
    expect(product(parent: ' Tea ', variant: ' Regular ').checkoutName, 'Tea (Regular)');
    expect(product(parent: '').checkoutName, 'Regular');
    expect(product(name: '', variant: '').checkoutName, 'Tea');
    expect(product(variant: 'tea').checkoutName, 'Tea');
    expect(product(variant: '').checkoutName, 'Tea (Regular)');
  });

  test('catalogue mapping keeps the full name in checkout and cart', () async {
    await getIt.reset();
    getIt.registerSingleton<UiStoreController>(CatalogueController());
    final bloc = CartBloc();
    addTearDown(() async {
      await bloc.close();
      await getIt.reset();
    });
    final loaded = bloc.stream.firstWhere((state) => state.products.isNotEmpty);
    bloc.add(const LoadInitialData());
    final state = await loaded;
    expect(state.products.single.name, 'Tea (Regular)');
    expect(state.products.single.productName, 'Tea');
    expect(state.products.single.variantName, 'Regular');
    final added = bloc.stream.firstWhere((state) => state.cartItems.isNotEmpty);
    bloc.add(AddProductToCart(state.products.single));
    expect((await added).cartItems.single.product.name, 'Tea (Regular)');
  });
}
