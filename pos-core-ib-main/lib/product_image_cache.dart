import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'store_models.dart';

class ProductImageSyncSummary {
  final int totalCount;
  final int successCount;
  final int failureCount;
  final String? failureMessage;

  const ProductImageSyncSummary({
    required this.totalCount,
    required this.successCount,
    required this.failureCount,
    this.failureMessage,
  });
}

class ProductImageCache {
  /// Several photos at once. Catalogue sync does not wait on this work.
  static const int downloadConcurrency = 6;

  final Database db;
  final Directory directory;

  ProductImageCache(this.db, {Directory? directory})
    : directory =
          directory ?? Directory(p.join(p.dirname(db.path), 'product_images'));

  /// Downloads variant photos for offline use.
  ///
  /// [throwOnFailure] stays on for direct callers. The store sync passes
  /// false so a missing photo cannot fail the catalogue import.
  Future<ProductImageSyncSummary> sync(
    StoreScope scope,
    Uri importUri, {
    bool throwOnFailure = true,
    void Function(int processed, int total, int failed)? onProgress,
  }) async {
    final rows = await db.query(
      'product_variants',
      where: 'orgId = ? AND storeId = ? AND deleted = 0',
      whereArgs: [scope.orgId, scope.storeId],
    );
    final pending = List<Map<String, Object?>>.from(rows);
    final total = pending.length;
    var processed = 0;
    var failedCount = 0;
    final failed = <String>[];
    onProgress?.call(0, total, 0);

    final client = http.Client();
    try {
      final workers = total == 0
          ? const <Future<void>>[]
          : List<Future<void>>.generate(math.min(downloadConcurrency, total), (
              _,
            ) async {
              while (pending.isNotEmpty) {
                final row = pending.removeAt(0);
                String? failure;
                try {
                  await _download(client, scope, row, importUri);
                } on http.ClientException {
                  failure = '${row['localId']} (connection)';
                } on TimeoutException {
                  failure = '${row['localId']} (timeout)';
                } on HttpException catch (error) {
                  failure = '${row['localId']} (${error.message})';
                } on IOException {
                  failure = '${row['localId']} (storage or HTTP response)';
                } on FormatException {
                  // Do not log signed URLs; sync history identifies the rows.
                  failure = '${row['localId']} (invalid image)';
                }
                processed += 1;
                if (failure != null) {
                  failedCount += 1;
                  failed.add(failure);
                }
                onProgress?.call(processed, total, failedCount);
              }
            });
      await Future.wait(workers);
    } finally {
      client.close();
    }
    final failureMessage = failed.isEmpty
        ? null
        : 'Catalogue saved, but ${failed.length} product image(s) could not be '
              'downloaded (${failed.take(10).join(', ')}). Previous images are kept. '
              'Check connectivity and image storage access, then sync again.';
    if (failureMessage != null && throwOnFailure) {
      throw StateError(failureMessage);
    }
    return ProductImageSyncSummary(
      totalCount: total,
      successCount: total - failedCount,
      failureCount: failedCount,
      failureMessage: failureMessage,
    );
  }

  Future<void> _download(
    http.Client client,
    StoreScope scope,
    Map<String, Object?> row,
    Uri importUri,
  ) async {
    final raw = '${row['product_variant_logo'] ?? ''}'.trim();
    final whereArgs = [scope.orgId, scope.storeId, row['localId']];
    Future<void> save(Map<String, Object?> values) => db
        .update(
          'product_variants',
          values,
          where: 'orgId = ? AND storeId = ? AND localId = ?',
          whereArgs: whereArgs,
        )
        .then((_) {});
    if (raw.isEmpty) {
      await save({
        'local_image_path': null,
        'image_cache_source': null,
        'image_etag': null,
        'image_last_modified': null,
      });
      return;
    }
    final uri = importUri.resolve(raw);
    if (!['http', 'https'].contains(uri.scheme)) {
      throw FormatException('Product image must use HTTP or HTTPS.');
    }
    // Presigned query strings rotate; validators belong to the underlying object.
    final source = uri
        .replace(
          queryParameters: Map.fromEntries(
            uri.queryParametersAll.entries.where(
              (entry) =>
                  !entry.key.toLowerCase().startsWith('x-amz-') &&
                  ![
                    'awsaccesskeyid',
                    'signature',
                    'expires',
                  ].contains(entry.key.toLowerCase()),
            ),
          ),
          fragment: '',
        )
        .toString();
    final path = '${row['local_image_path'] ?? ''}';
    final hasFile = path.isNotEmpty && await File(path).exists();
    final revalidate = hasFile && row['image_cache_source'] == source;
    final request = http.Request('GET', uri);
    if (revalidate) {
      if ('${row['image_etag'] ?? ''}'.isNotEmpty) {
        request.headers['If-None-Match'] = '${row['image_etag']}';
      }
      if ('${row['image_last_modified'] ?? ''}'.isNotEmpty) {
        request.headers['If-Modified-Since'] = '${row['image_last_modified']}';
      }
    }
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 304 && revalidate) {
      await response.stream.drain<void>().timeout(const Duration(seconds: 30));
      return;
    }
    final contentType = (response.headers['content-type'] ?? '')
        .split(';')
        .first
        .trim()
        .toLowerCase();
    final binaryContent =
        contentType.isEmpty || contentType == 'application/octet-stream';
    if (response.statusCode != 200 ||
        (!contentType.startsWith('image/') && !binaryContent)) {
      await response.stream.drain<void>().timeout(const Duration(seconds: 30));
      throw HttpException('HTTP ${response.statusCode} or non-image response');
    }
    const maxBytes = 20 * 1024 * 1024;
    final bytes = <int>[];
    await (() async {
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        if (bytes.length > maxBytes) {
          throw const FormatException('Product image exceeds 20 MB.');
        }
      }
    })().timeout(const Duration(seconds: 30));
    if (bytes.isEmpty) throw const FormatException('Product image is empty.');
    if (binaryContent) {
      const signatures = [
        [137, 80, 78, 71, 13, 10, 26, 10], // PNG
        [255, 216, 255], // JPEG
        [71, 73, 70, 56], // GIF
        [66, 77], // BMP
        [0, 0, 1, 0], // ICO
      ];
      final raster = signatures.any(
        (signature) =>
            bytes.length >= signature.length &&
            List.generate(
              signature.length,
              (i) => bytes[i] == signature[i],
            ).every((matches) => matches),
      );
      final webp =
          bytes.length >= 12 &&
          ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
          ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP';
      if (!raster && !webp) {
        throw const FormatException(
          'Binary response is not a supported image.',
        );
      }
    }
    final scopeKey = sha256
        .convert(utf8.encode(jsonEncode([scope.orgId, scope.storeId])))
        .toString();
    final folder = Directory(p.join(directory.path, scopeKey));
    await folder.create(recursive: true);
    final file = File(p.join(folder.path, sha256.convert(bytes).toString()));
    if (!await file.exists()) {
      final temporary = File('${file.path}.${const Uuid().v4()}.part');
      try {
        await temporary.writeAsBytes(bytes, flush: true);
        await temporary.rename(file.path);
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
    }
    await save({
      'local_image_path': file.absolute.path,
      'image_cache_source': source,
      'image_etag': response.headers['etag'],
      'image_last_modified': response.headers['last-modified'],
    });
  }
}
