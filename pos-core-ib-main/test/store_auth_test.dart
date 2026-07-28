import 'dart:io';

import 'package:test/test.dart';

import '../lib/store.dart';
import '../lib/store_config.dart';
import '../lib/store_exceptions.dart';
import 'test_store_helper.dart';

void main() {
  test('Store requires login before protected operations', () async {
    final store = await openTestStore(
      productJson: 'fixtures/product_data.json',
      customerJson: 'fixtures/customer_data.json',
    );
    addTearDown(store.close);

    expect(() => store.products.listNames(store.scope), throwsA(isA<StoreAuthException>()));
  });

  test('Store login persists and can expire based on session duration', () async {
    final config = await loadTestConfig();
    const metadata = StoreConfig.defaultTestStoreMetadata;
    final tempDir = await Directory.systemTemp.createTemp('store_auth_expiry_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final store = await Store.openPersistent(
      orgId: metadata.orgId,
      orgName: metadata.orgName,
      orgCode: metadata.orgCode,
      storeId: metadata.storeId,
      serviceInstanceId: metadata.serviceInstanceId,
      storeName: 'Auth Store',
      logo: metadata.logo,
      uniqueId: '13572468',
      contactEmail: 'auth@store.com',
      phone: metadata.phone,
      contactPerson: 'Auth User',
      status: metadata.status,
      serviceVariantType: metadata.serviceVariantType,
      customerJson: config.assetPaths.customers,
      databasePath: tempDir.path,
      config: config,
    );
    addTearDown(store.close);

    await loginAsDefaultTestUser(store, config: config);
    expect(await store.auth.isLoggedIn(), true);

    final reopened = await Store.reopenPersistent(
      orgId: metadata.orgId,
      storeId: metadata.storeId,
      uniqueId: '13572468',
      databasePath: tempDir.path,
      config: config,
    );
    addTearDown(reopened.close);
    expect(await reopened.auth.isLoggedIn(), true);
    expect(reopened.organisationRemoteId, metadata.orgId);
    expect(reopened.storeRemoteId, metadata.storeId);

    final expired = await Store.reopenPersistent(
      orgId: metadata.orgId,
      storeId: metadata.storeId,
      uniqueId: '13572468',
      databasePath: tempDir.path,
      sessionDuration: Duration.zero,
      config: config,
    );
    addTearDown(expired.close);
    expect(
      () => expired.products.listNames(expired.scope),
      throwsA(isA<StoreSessionExpiredException>()),
    );
    expect(await expired.auth.isLoggedIn(), false);

    await reopened.auth.logout();
    expect(await reopened.auth.isLoggedIn(), false);
  });

  test('Store grants admin-only imports only to admin users', () async {
    final store = await openTestStore(
      customerJson: 'fixtures/customer_data.json',
    );
    addTearDown(store.close);

    await loginAsDefaultTestUser(store);
    expect(await store.auth.hasOrganisationRole('member'), true);
    expect(await store.auth.hasOrganisationRole('admin'), false);
    expect(await store.auth.hasStoreRole('member'), true);
    expect(await store.auth.hasStoreRole('admin'), false);

    await expectLater(
      store.orders.importFromJsonFile(store.scope, 'fixtures/order_list.json'),
      throwsA(isA<StoreAuthorizationException>()),
    );

    await store.auth.logout();

    await loginAsAdmin(store);
    expect(await store.auth.hasOrganisationRole('admin'), true);
    expect(await store.auth.hasStoreRole('admin'), true);

    await store.orders.importFromJsonFile(store.scope, 'fixtures/order_list.json');
    final orders = await store.orders.listSummaries(store.scope);
    expect(orders.isNotEmpty, true);
  });

  test('Store supports changing and resetting passwords', () async {
    final store = await openTestStore(
      customerJson: 'fixtures/customer_data.json',
    );
    addTearDown(store.close);

    await loginAsDefaultTestUser(store);

    await store.auth.changePassword(
      currentPassword: 'alicepass',
      newPassword: 'alicepass2',
    );
    await store.auth.logout();

    final oldPasswordSession = await loginWithCredentials(
      store,
      email: 'alice@example.com',
      password: 'alicepass',
    );
    expect(oldPasswordSession, isNull);

    final newPasswordSession = await loginWithCredentials(
      store,
      email: 'alice@example.com',
      password: 'alicepass2',
    );
    expect(newPasswordSession != null, true);
    await store.auth.logout();

    await loginAsAdmin(store);
    await store.auth.resetCustomerPasswordByEmail(
      email: 'alice@example.com',
      newPassword: 'alicepass3',
    );
    await store.auth.logout();

    final resetPasswordSession = await loginWithCredentials(
      store,
      email: 'alice@example.com',
      password: 'alicepass3',
    );
    expect(resetPasswordSession != null, true);
  });
}