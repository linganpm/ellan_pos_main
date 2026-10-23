import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tablet/bloc/cart/cart_bloc.dart';
import 'package:pos_tablet/bloc/cart/cart_state.dart';
import 'package:pos_tablet/core/localization/l10n/app_localizations.dart';
import 'package:pos_tablet/presentation/widgets/checkout_footer_buttons.dart';
import 'package:pos_tablet/presentation/widgets/discount_entry.dart';

void main() {
  testWidgets('discount opens as percent or a flat amount', (tester) async {
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
                    Expanded(
                      child: SingleChildScrollView(
                        child: DiscountEntry(state: state),
                      ),
                    ),
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

    expect(find.text('5%'), findsNothing);
    expect(find.text('10%'), findsNothing);
    expect(find.text('15%'), findsNothing);
    expect(find.text('25%'), findsNothing);
    expect(find.text('50%'), findsNothing);
    expect(find.text('Percentage'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('BILL'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '10');
    await tester.tap(find.widgetWithText(FilledButton, 'Add discount'));
    await tester.pump();
    expect(bloc.state.discounts.single.percentage, 10);
    expect(bloc.state.discounts.single.flatAmount, 0);
    expect(bloc.state.discounts.single.title, 'Discount');
    expect(find.text('BILL'), findsOneWidget);

    await tester.tap(find.text('Amount'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '40');
    await tester.enterText(find.byType(TextField).last, 'Staff');
    await tester.tap(find.widgetWithText(FilledButton, 'Add discount'));
    await tester.pump();
    expect(bloc.state.discounts.last.title, 'Staff');
    expect(bloc.state.discounts.last.flatAmount, 40);
    expect(bloc.state.discounts.last.percentage, 0);
    expect(find.text('BILL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
