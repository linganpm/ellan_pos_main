import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

export 'package:sqflite_common_ffi/sqflite_ffi.dart' hide sqfliteFfiInit;

/// Initialize FFI loader for sqflite_common_ffi (no platform overrides needed).
void sqfliteFfiInit() {
  ffi.sqfliteFfiInit();
}
