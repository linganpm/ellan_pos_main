import 'dart:io' show Directory;

import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> configureSqfliteDatabasesPath(DatabaseFactory factory) async {
  final appSupportDir = await getApplicationSupportDirectory();
  final dbDir = Directory('${appSupportDir.path}/databases');
  if (!await dbDir.exists()) {
    await dbDir.create(recursive: true);
  }
  await factory.setDatabasesPath(dbDir.path);
}
