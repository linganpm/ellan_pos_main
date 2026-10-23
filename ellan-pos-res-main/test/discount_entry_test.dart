import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tablet/bloc/cart/cart_bloc.dart';
import 'package:pos_tablet/bloc/cart/cart_state.dart';
import 'package:pos_tablet/core/localization/l10n/app_localizations.dart';
import 'package:pos_tablet/presentation/widgets/checkout_footer_buttons.dart';
import 'package:pos_tablet/presentation/widgets/discount_entry.dart';

void main() {
  testWidgets('preset and custom discounts leave the bill button in place', (
    tester,
  ) async {
    final bloc = CartBloc();
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: BlocBuilder<CartBloc, CartState>(
              builder: (context, state) {
                return Column(
                  children: [
                    DiscountEntry(state: state, compact: true),
                    SizedBox(
                      height: 88,
                      child: CheckoutFooterButtons(
                        hasItems: true,
                        onKOT: () {},
                        onBill: () {},
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('5%'), findsOneWidget);
    expect(find.text('10%'), findsOneWidget);
    expect(find.text('15%'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('BILL'), findsOneWidget);
    expect(find.text('Title (Optional)'), findsOneWidget);

    await tester.tap(find.text('10%'));
    await tester.pump();
    expect(bloc.state.discounts.single.percentage, 10);
    expect(bloc.state.discounts.single.title, 'Discount');
    expect(find.text('BILL'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '12.5');
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pump();
    expect(bloc.state.discounts.single.percentage, 12.5);
    expect(find.text('BILL'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Staff');
    await tester.tap(find.text('15%'));
    await tester.pump();
    expect(bloc.state.discounts.length, 2);
    expect(bloc.state.discounts.last.title, 'Staff');
    expect(bloc.state.discounts.last.percentage, 15);
    expect(tester.takeException(), isNull);
  });
}
