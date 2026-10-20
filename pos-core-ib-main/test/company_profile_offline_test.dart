import 'package:test/test.dart';

import '../lib/store.dart';
import '../lib/store_models.dart';
import 'test_store_helper.dart';

StoreDirectoryEntry _serverEntry(Store store) =>
    StoreDirectoryEntry.fromRow({
      'orgId': store.orgId,
      'storeId': store.storeId,
      'remote_id': store.storeRemoteId,
      'uniqueId': store.uniqueId,
      'serviceInstanceId': store.serviceInstanceId,
      'storeName': 'Server Name',
      'logo': 'server-logo.png',
      'contactEmail': 'server@example.com',
      'phone': '9000000000',
      'contactPerson': store.contactPerson,
      'status': store.status,
      'serviceVariantType': store.serviceVariantType,
      'address': 'Server address',
    });

void main() {
  test('company details save offline with a pending flag', () async {
    final store = await openAdminLoggedInTestStore();
    addTearDown(store.close);
    // In-memory test stores skip the store_info row that login writes.
    await store.applyStoreDirectoryEntryForTest(_serverEntry(store));

    await store.saveCompanyProfileLocal(
      storeName: 'Offline Name',
      taxNumber: 'GST-OFF',
      profilePendingSync: true,
    );
    final profile = await store.loadCompanyProfile();
    expect(profile['storeName'], 'Offline Name');
    expect(profile['tax_number'], 'GST-OFF');
    expect(profile['profile_pending_sync'], 1);

    await store.saveCompanyProfileLocal(profilePendingSync: false);
    expect((await store.loadCompanyProfile())['profile_pending_sync'], 0);
  });

  test('a directory refresh keeps company edits that are not synced yet', () async {
    final store = await openAdminLoggedInTestStore();
    addTearDown(store.close);
    // In-memory test stores skip the store_info row that login writes.
    await store.applyStoreDirectoryEntryForTest(_serverEntry(store));

    await store.saveCompanyProfileLocal(
      storeName: 'Offline Name',
      contactEmail: 'offline@example.com',
      address: 'Offline address',
      profilePendingSync: true,
    );
    await store.setCompanyLogoLocal('/tmp/offline-logo.png');
    await store.applyStoreDirectoryEntryForTest(
      _serverEntry(store),
    );

    var profile = await store.loadCompanyProfile();
    expect(profile['storeName'], 'Offline Name');
    expect(profile['contactEmail'], 'offline@example.com');
    expect(profile['address'], 'Offline address');
    expect(profile['logo'], '/tmp/offline-logo.png');
    expect(profile['profile_pending_sync'], 1);
    expect(profile['logo_pending_sync'], 1);

    // Once pushed, the server copy wins again on the next refresh.
    await store.saveCompanyProfileLocal(
      profilePendingSync: false,
      logoPendingSync: false,
    );
    await store.applyStoreDirectoryEntryForTest(
      _serverEntry(store),
    );
    profile = await store.loadCompanyProfile();
    expect(profile['storeName'], 'Server Name');
    expect(profile['contactEmail'], 'server@example.com');
    expect(profile['logo'], 'server-logo.png');
    expect(profile['profile_pending_sync'], 0);
  });
}
