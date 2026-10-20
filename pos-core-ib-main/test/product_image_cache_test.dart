import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../lib/backend_setup.dart';
import '../lib/product_data_importer.dart';
import '../lib/product_image_cache.dart';
import '../lib/product_repository.dart';
import '../lib/sqflite_ffi_io.dart';
import '../lib/store_models.dart';

void main() {
  const scope = StoreScope(orgId: 'org', storeId: 'store');
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=',
  );
  late Directory temp;
  late Database db;
  late HttpServer server;
  late Uri base;
  late ProductImageCache cache;
  late int requests;
  late int status;
  late String contentType;
  late List<String?> validators;
  late String etag;
  late List<int> responseBytes;

  Future<void> importImage(String url) =>
      ProductDataImporter(db).importFromJsonData({
        'data': [
          {
            'id': 1,
            'name': 'Food',
            'product_variants': [
              {
                'id': 2,
                'product_name': 'Rice',
                'product_variant_name': '1 kg',
                'product_variant_logo': url,
                'sell_price': '10',
              },
            ],
          },
        ],
      }, scope: scope);

  Future<Map<String, Object?>> row() async => (await db.query(
    'product_variants',
    where: 'orgId = ?',
    whereArgs: ['org'],
  )).single;

  setUp(() async {
    sqfliteFfiInit();
    temp = await Directory.systemTemp.createTemp('pos-image-test-');
    db = await databaseFactoryFfi.openDatabase('${temp.path}/catalogue.db');
    await BackendSetup.createTablesForTest(db);
    cache = ProductImageCache(db);
    requests = 0;
    status = 200;
    contentType = 'image/png';
    validators = [];
    etag = '"v1"';
    responseBytes = png;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = Uri.parse(
      'http://${server.address.host}:${server.port}/products/import',
    );
    server.listen((request) async {
      requests++;
      validators.add(request.headers.value('if-none-match'));
      request.response.statusCode = status;
      if (status == 200) {
        request.response.headers.set('content-type', contentType);
        request.response.headers.set('etag', etag);
        request.response.add(responseBytes);
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await db.close();
    await temp.delete(recursive: true);
  });

  test(
    'download persists across database restart and works without internet',
    () async {
      await importImage('/image.png?X-Amz-Signature=first');
      await cache.sync(scope, base);
      final path = (await row())['local_image_path'] as String;
      expect(await File(path).readAsBytes(), png);
      expect(path, startsWith(temp.path));
      await db.close();
      await server.close(force: true);
      db = await databaseFactoryFfi.openDatabase('${temp.path}/catalogue.db');
      final records = await ProductRepository(db).searchProductVariants(scope);
      final record = StoreProductVariantRecord.fromRow(records.single);
      expect(record.imagePath, path);
      // Reading the local catalogue must not make a second HTTP request.
      expect(requests, 1);
      expect(await File(record.imagePath).readAsBytes(), png);
    },
  );

  test(
    'rotating signed URL revalidates cached object and 304 keeps bytes',
    () async {
      await importImage('/image.png?X-Amz-Signature=first');
      await cache.sync(scope, base);
      final first = await row();
      await importImage('/image.png?X-Amz-Signature=second');
      expect((await row())['local_image_path'], first['local_image_path']);
      status = 304;
      await cache.sync(scope, base);
      expect(validators, [null, '"v1"']);
      expect((await row())['local_image_path'], first['local_image_path']);
    },
  );

  test(
    'a missing cached file is fetched again without conditional headers',
    () async {
      await importImage('/image.png');
      await cache.sync(scope, base);
      await File((await row())['local_image_path'] as String).delete();
      await cache.sync(scope, base);
      expect(validators, [null, null]);
      expect(
        await File((await row())['local_image_path'] as String).exists(),
        isTrue,
      );
    },
  );

  test('updated object bytes get a new local file and ETag', () async {
    await importImage('/image.png');
    await cache.sync(scope, base);
    final first = await row();
    responseBytes = [...png, 0];
    etag = '"v2"';
    await cache.sync(scope, base);
    final updated = await row();
    expect(updated['local_image_path'], isNot(first['local_image_path']));
    expect(updated['image_etag'], '"v2"');
    expect(
      await File(updated['local_image_path'] as String).readAsBytes(),
      responseBytes,
    );
    expect(await File(first['local_image_path'] as String).exists(), isTrue);
  });

  test(
    'image size limit rejects bytes above 20 MB without publishing a file',
    () async {
      await importImage('/oversized.png');
      responseBytes = List<int>.filled(20 * 1024 * 1024 + 1, 0);
      await expectLater(cache.sync(scope, base), throwsStateError);
      expect((await row())['local_image_path'], isNull);
      expect(await cache.directory.exists(), isFalse);
    },
  );

  test(
    'changed URL downloads a replacement and failure keeps prior image',
    () async {
      await importImage('/image.png');
      await cache.sync(scope, base);
      final first = await row();
      await importImage('/replacement.png?X-Amz-Signature=private');
      status = 403;
      await expectLater(
        cache.sync(scope, base),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Previous images are kept'),
              isNot(contains('private')),
            ),
          ),
        ),
      );
      expect((await row())['local_image_path'], first['local_image_path']);
      status = 200;
      await cache.sync(scope, base);
      expect(validators.last, isNull);
      expect((await row())['image_cache_source'], contains('/replacement.png'));
    },
  );

  test('non-image responses never replace a working image', () async {
    await importImage('/image.png');
    await cache.sync(scope, base);
    final first = await row();
    contentType = 'text/html';
    await expectLater(cache.sync(scope, base), throwsStateError);
    expect((await row())['local_image_path'], first['local_image_path']);
  });

  test(
    'S3 binary content type is accepted only for recognizable image bytes',
    () async {
      await importImage('/image.png');
      contentType = 'application/octet-stream';
      await cache.sync(scope, base);
      final first = await row();
      expect(
        await File(first['local_image_path'] as String).readAsBytes(),
        png,
      );
      responseBytes = utf8.encode('<html>Not an image</html>');
      await expectLater(cache.sync(scope, base), throwsStateError);
      expect((await row())['local_image_path'], first['local_image_path']);
    },
  );

  test(
    'removed image clears the local reference without a network request',
    () async {
      await importImage('/image.png');
      await cache.sync(scope, base);
      await importImage('');
      await cache.sync(scope, base);
      expect((await row())['local_image_path'], isNull);
      expect(StoreProductVariantRecord.fromRow(await row()).imagePath, '');
      expect(requests, 1);
    },
  );

  test('other stores and deleted variants are not downloaded', () async {
    await importImage('/image.png');
    await cache.sync(const StoreScope(orgId: 'other', storeId: 'store'), base);
    expect(requests, 0);
    await db.update('product_variants', {'deleted': 1});
    await cache.sync(scope, base);
    expect(requests, 0);
  });

  test(
    'schema 51 upgrades cache columns without losing catalogue data',
    () async {
      await importImage('/image.png');
      for (final column in [
        'local_image_path',
        'image_cache_source',
        'image_etag',
        'image_last_modified',
      ]) {
        await db.execute('ALTER TABLE product_variants DROP COLUMN $column');
      }
      await BackendSetup.upgradeTablesForTest(db, 51, 52);
      expect((await row())['product_name'], 'Rice');
      await cache.sync(scope, base);
      expect((await row())['local_image_path'], isNotEmpty);
    },
  );
}
