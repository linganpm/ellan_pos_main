import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> configureSqfliteDatabasesPath(DatabaseFactory factory) async {
  // No-op on web — sqflite_common_ffi_web manages storage itself.
}
