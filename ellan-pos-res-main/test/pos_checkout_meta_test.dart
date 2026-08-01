import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tablet/core/pos_checkout_meta.dart';

void main() {
  test('checkout meta preserves receipt adjustments and previous balance', () {
    const source = PosCheckoutMeta(
      staffName: 'Cashier',
      staffReg: 'EMP-1',
      tips: 5,
      serviceTax: 8,
      discount: 3,
      delivery: 2,
      previousBalance: 40,
    );

    final parsed = PosCheckoutMeta.parse(source.encode());

    expect(parsed.staffName, 'Cashier');
    expect(parsed.staffReg, 'EMP-1');
    expect(parsed.tips, 5);
    expect(parsed.serviceTax, 8);
    expect(parsed.discount, 3);
    expect(parsed.delivery, 2);
    expect(parsed.previousBalance, 40);
  });
}
