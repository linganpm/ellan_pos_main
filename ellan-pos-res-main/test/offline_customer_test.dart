import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/utils/user_facing_error.dart';

void main() {
  test('network failures fall back to saving the customer offline', () {
    for (final error in <Object>[
      const SocketException('Failed host lookup'),
      TimeoutException('slow'),
      http.ClientException('Connection closed'),
      const FormatException('<html>'),
    ]) {
      expect(UiStoreController.isGatewayUnreachable(error), isTrue);
    }
  });

  test('gateway validation errors are still shown to the operator', () {
    final rejected = StateError('Enter a valid phone number.');
    expect(UiStoreController.isGatewayUnreachable(rejected), isFalse);
    expect(userFacingError(rejected), contains('valid phone'));
  });
}
